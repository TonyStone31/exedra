unit SiteIndex;

{ The site's own search index.  A module that registers here gets one index
  under data/search, built from its rows and kept in step through the table
  search_queue.  SiteSearch asks IndexFind and falls back to the module's
  own search whenever it answers False.  The server program keeps the
  indexes; a CGI program keeps none and always answers False. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils, httpdefs, fpjson, SiteUsers, SiteSearch;

type
  { One thing as the index takes it.  Plain text, all of it. }
  TIndexDoc = record
    Title: string;      // what it is called; '' when it has no title
    Names: string;      // other names it goes by: a slug, a short name; not searched now
    Text: string;       // its words as a reader sees them: PlainWords of Markdown
    Group: string;      // who may find it, in the module's own words; '' for everyone
    Language: string;   // two letters, for word forms; '' when not known
    Count: int64;       // how much it is used: links to it, replies, stars
    Time: TDateTime;    // when it last changed, UTC; 0 when not known
  end;

  { Fills Doc from the database.  False when Id is gone or nobody is to find it. }
  TIndexMake = function(const Id: string; var Doc: TIndexDoc): boolean;
  { The ids that follow After ('' at the start), in one fixed order, Count at most. }
  TIndexNext = function(const After: string; Count: integer): TStringArray;
  { The groups Me may find now, beside ''.  Asked on every search. }
  TIndexGroups = function(ARequest: TRequest; const Me: TMember): TStringArray;
  { The hits for Ids that Me may open now, in any order, each with its Id set. }
  TIndexLoad = function(ARequest: TRequest; const Me: TMember; const Ids: TStringArray): TSearchHits;

{ Part is the name given to RegisterSearch.  Without Groups every document
  must have an empty Group.  Open: anyone may read every document of this
  part. }
procedure RegisterIndexed(const Part: string; Make: TIndexMake; Next: TIndexNext; Load: TIndexLoad; Groups: TIndexGroups = nil; Open: boolean = False);
{ Optional.  A Count of CountHalf earns half of a 25 percent raise; an age
  of FreshDays halves a raise of FreshGain.  0 leaves that one out. }
procedure IndexPrefers(const Part: string; CountHalf, FreshDays, FreshGain: double);
{ Row Id of Part was added, changed or removed; '' for the whole part.  Call
  it once the row is right, in the same transaction when there is one. }
procedure SearchChanged(const Part, Id: string);
{ First column of a query as ids, for Next and Groups. }
function IndexIds(const SQL: string; const Values: array of variant): TStringArray;
{ Ids as '3,17,42' for an IN (...); anything that is not a whole number is
  left out, '0' when none. }
function IndexIdList(const Ids: TStringArray): string;

{ What follows is for SiteSearch and the checks, not for a module. }

type
  { What the index answered for one module.  The two Html arrays run beside
    Hits: the engine escaped their text and added <mark> alone; '' where it
    has none. }
  TIndexAnswer = record
    Hits: TSearchHits;
    TitleHtml, ExcerptHtml: TStringArray;
    More: boolean;
    Shown, Meant: string;   // the words searched for in place of the reader's, and words to offer
  end;

var
  { Raised by a release that changes what documents hold: every index is
    then built again. }
  IndexLayout: integer = 2;
  { Room a build wants left on the disk beside the index's own size. }
  IndexSpare: int64 = 500 * 1024 * 1024;

{ False when Part does not answer from its index now: its own search does. }
function IndexFind(ARequest: TRequest; const Me: TMember; const Part, Words: string; Offset, Limit: integer; out Answer: TIndexAnswer): boolean;

type
  { Something to offer while a reader types: a page with its address, or
    words to search for, their Address empty. }
  TIndexOffer = record
    Text, Address: string;
  end;
  TIndexOffers = array of TIndexOffer;

{ Offers for words half typed.  Nothing from a part that is not Open. }
function IndexOffers(ARequest: TRequest; const Me: TMember; const Part, Typed: string; Count: integer): TIndexOffers;
{ What GET /api/admin/search answers. }
function IndexState: TJSONObject;
{$ifndef CGI}
{ The minute's work: builds started, waiting changes applied and saved. }
procedure IndexChore;
{ One part built on the calling thread. }
procedure BuildIndexNow(const Part: string);
{$endif}

implementation

uses
  Classes, DateUtils, DB, sqldb, httproute, SiteDb, SiteAdmin, SiteGuard, SiteBackup, SiteStats, WebPages
  {$ifndef CGI}, SiteWords, Ferret, FerretText, FerretStem{$endif};

type
  TPart = class
    Name: string;
    Make: TIndexMake;
    Next: TIndexNext;
    Load: TIndexLoad;
    Groups: TIndexGroups;
    Open: boolean;
    CountHalf, FreshDays, FreshGain: double;
    {$ifndef CGI}
    Index: TFerretIndex;
    // under StateLock
    Made, Problem, Step: string;
    Built, Failed: TDateTime;
    Building: boolean;
    Refused: int64;
    // under DrainLock: changes applied since the last save, a group already reported
    Unsaved, Warned: boolean;
    // where a build is in the part's ids
    Ids: TStringArray;
    At: integer;
    function NextDoc: TFerretDocument;
    function Progress(Done, Total: int64): boolean;
    {$endif}
  end;

var
  Parts: array of TPart;

function PartNamed(const Name: string): TPart;
var
  P: TPart;
begin
  Result := nil;
  for P in Parts do
    if P.Name = Name then
      Result := P;
end;

procedure RegisterIndexed(const Part: string; Make: TIndexMake; Next: TIndexNext; Load: TIndexLoad; Groups: TIndexGroups; Open: boolean);
var
  P: TPart;
begin
  // the name is a folder's and a column's
  if not ValidSlug(Part) or (Length(Part) > 20) then
    raise Exception.Create('RegisterIndexed: ' + Part + ' cannot name an index');
  P := TPart.Create;
  P.Name := Part;
  P.Make := Make;
  P.Next := Next;
  P.Load := Load;
  P.Groups := Groups;
  P.Open := Open;
  SetLength(Parts, Length(Parts) + 1);
  Parts[High(Parts)] := P;
end;

procedure IndexPrefers(const Part: string; CountHalf, FreshDays, FreshGain: double);
var
  P: TPart;
begin
  P := PartNamed(Part);
  P.CountHalf := CountHalf;
  P.FreshDays := FreshDays;
  P.FreshGain := FreshGain;
end;

{ Whether this program keeps indexes now. }
function Keeping: boolean;
begin
  {$ifdef CGI}
  Result := False;
  {$else}
  Result := Setting('search_engine', 'database') <> 'database';
  {$endif}
end;

procedure SearchChanged(const Part, Id: string);
begin
  if Keeping then
    Exec('INSERT INTO search_queue (part, doc) VALUES (:p, :d)', [Part, Id])
  // nothing follows this change: whoever keeps an index next builds it again
  else if Setting('search_stamp', '') <> '' then
    SaveSetting('search_stamp', '');
end;

function IndexIds(const SQL: string; const Values: array of variant): TStringArray;
var
  Q: TSQLQuery;
begin
  Result := nil;
  Q := Query(SQL, Values);
  try
    while not Q.EOF do
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Q.Fields[0].AsString;
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

function IndexIdList(const Ids: TStringArray): string;
var
  Id: string;
  I: integer;
  Whole: boolean;
begin
  Result := '';
  for Id in Ids do
  begin
    Whole := (Id <> '') and (Length(Id) <= 18);
    for I := 1 to Length(Id) do
      Whole := Whole and (Id[I] in ['0'..'9']);
    if Whole then
      Result := Result + ',' + Id;
  end;
  Delete(Result, 1, 1);
  if Result = '' then
    Result := '0';
end;

{ A restore put the database back: no index matches it. }
procedure BlankStamp;
begin
  SaveSetting('search_stamp', '');
end;

{$ifdef CGI}
function IndexFind(ARequest: TRequest; const Me: TMember; const Part, Words: string; Offset, Limit: integer; out Answer: TIndexAnswer): boolean;
begin
  Answer := Default(TIndexAnswer);
  Result := False;
end;

function IndexOffers(ARequest: TRequest; const Me: TMember; const Part, Typed: string; Count: integer): TIndexOffers;
begin
  Result := nil;
end;

function IndexState: TJSONObject;
begin
  Result := TJSONObject.Create(['engine', 'database', 'cgi', True, 'parts', TJSONArray.Create]);
end;

{$else}

const
  { A part is built whole again this often, for what no call reported. }
  RebuildHours = 24;
  { Rows of the queue read, and changed by their ids, at a time. }
  Batch = 200;

var
  { Whose turn it is to apply the queue, do the start work, switch off or
    begin a build.  Never held during a save, a search or a build. }
  DrainLock: TRTLCriticalSection;
  { The parts' states and what follows; held for a moment only. }
  StateLock: TRTLCriticalSection;
  Started, BuilderRuns: boolean;
  { How often a build was asked for: the thread looks again when it rose. }
  BuildsAsked: integer;

{ Action for the queue's rows with these ids, a batch at a time: never by
  a condition that makes the server look at rows another writer holds. }
procedure QueueRows(const Action: string; const Ids: TStringArray);
var
  At: integer;
begin
  At := 0;
  while At < Length(Ids) do
  begin
    Exec(Action + ' WHERE id IN (' + IndexIdList(Copy(Ids, At, Batch)) + ')', []);
    Inc(At, Batch);
  end;
end;

function IndexFolder: string;
begin
  Result := FilesRoot + 'data' + PathDelim + 'search' + PathDelim;
end;

function Languages: string;
begin
  Result := LowerCase(StringReplace(Setting('search_languages', 'en'), ' ', '', [rfReplaceAll]));
end;

{ What an index's value "made" holds when it fits this program, its
  settings and the database; '' while there is no stamp, which fits none. }
function Expected: string;
begin
  Result := Setting('search_stamp', '');
  if Result <> '' then
    Result := Format('%d %s %s', [IndexLayout, Languages, Result]);
end;

procedure Note(P: TPart; const Text: string);
begin
  Log('Search index (' + P.Name + '): ' + Text);
end;

function Answers(P: TPart): boolean;
var
  Want: string;
begin
  Want := Expected;
  Result := Keeping and (Want <> '');
  EnterCriticalSection(StateLock);
  Result := Result and Started and not P.Building and (P.Problem = '') and (P.Made = Want);
  LeaveCriticalSection(StateLock);
end;

{ Due for a build: not made for what is expected, built a day ago, or
  failed an hour ago. }
function NeedsBuild(P: TPart): boolean;
var
  Want: string;
begin
  Want := Expected;
  EnterCriticalSection(StateLock);
  if (Want = '') or P.Building then
    Result := False
  else if P.Problem <> '' then
    Result := Now - P.Failed > 1 / HoursPerDay
  else
    Result := (P.Made <> Want) or (NowUTC - P.Built > RebuildHours / HoursPerDay);
  LeaveCriticalSection(StateLock);
end;

{ P stops answering until a build: Why is shown to the admin. }
procedure SetFailed(P: TPart; const Why: string);
begin
  EnterCriticalSection(StateLock);
  P.Problem := Why;
  P.Failed := Now;
  P.Building := False;
  LeaveCriticalSection(StateLock);
  Note(P, Why);
end;

{ The store of P refused a write.  Closing it lets the next use open it
  anew; the changes it held in memory wait in the queue again. }
procedure StoreFailed(P: TPart; const Why: string);
begin
  EnterCriticalSection(DrainLock);
  try
    try
      P.Index.Close;
    except
      on EFerret do ;
    end;
    P.Unsaved := False;
    SetFailed(P, Why);
    try
      QueueRows('UPDATE search_queue SET done = 0', IndexIds('SELECT id FROM search_queue WHERE part = :p AND done = 1', [P.Name]));
    except
      // the start work sets them back as well
      on EDatabaseError do ;
    end;
  finally
    LeaveCriticalSection(DrainLock);
  end;
end;

{ Text as the engine takes it: valid UTF-8, put right once when it is not. }
function Sound(const Text: string): string;
begin
  Result := Text;
  try
    UTF8Length(Text);
  except
    on EFerret do
      Result := UTF8Encode(UTF8Decode(Text));
  end;
end;

{ Row Id of P as a document, or nil when it is gone or not to be found. }
function Document(P: TPart; const Id: string): TFerretDocument;
var
  Doc: TIndexDoc;
begin
  Result := nil;
  Doc := Default(TIndexDoc);
  try
    if not P.Make(Id, Doc) then
      Exit;
  except
    on EDatabaseError do
      raise;
    on E: Exception do
    begin
      Note(P, Id + ' is left out: ' + E.Message);
      Exit;
    end;
  end;
  // a part that names no groups is searched without a filter
  if (Doc.Group <> '') and not Assigned(P.Groups) then
  begin
    if not P.Warned then
      Note(P, Id + ' has a group and the part registered none: such rows are left out');
    P.Warned := True;
    Exit;
  end;
  Result := TFerretDocument.Create(Id);
  if Doc.Title <> '' then
    Result.AddField('title', Sound(Doc.Title), 3);
  if Doc.Text <> '' then
    Result.AddField('body', Sound(Doc.Text));
  if Assigned(P.Groups) then
    Result.SetFact('group', Sound(Doc.Group));
  if Doc.Count > 0 then
    Result.SetFact('count', Doc.Count);
  if Doc.Time <> 0 then
    Result.SetDate('time', Doc.Time);
  Result.Language := Sound(LowerCase(Copy(Doc.Language, 1, 2)));
end;

function TPart.NextDoc: TFerretDocument;
begin
  Result := nil;
  repeat
    if At > High(Ids) then
    begin
      if Length(Ids) = 0 then
        Ids := Next('', Batch)
      else
        Ids := Next(Ids[High(Ids)], Batch);
      At := 0;
      if Length(Ids) = 0 then
        Exit;
    end;
    Result := Document(Self, Ids[At]);
    Inc(At);
  until Result <> nil;
end;

function TPart.Progress(Done, Total: int64): boolean;
begin
  if Done mod 100 = 0 then
  begin
    EnterCriticalSection(StateLock);
    Step := Format('%.0n so far', [Done * 1.0]);
    LeaveCriticalSection(StateLock);
  end;
  Result := Keeping and not Restoring;
end;

{ Once in a process, before any part answers: changes the last process
  applied and never saved wait again, what belongs to no part goes, and
  each index is opened.  Then a stamp when there is none.  Under DrainLock. }
procedure Prepare;
var
  P: TPart;
  Entry: TSearchRec;
  Known, Made, Built: string;
  At: TDateTime;
begin
  if not Started then
  begin
    PrivateFolder(IndexFolder);
    QueueRows('UPDATE search_queue SET done = 0', IndexIds('SELECT id FROM search_queue WHERE done = 1', []));
    Known := '''''';
    for P in Parts do
      Known := Known + ', ''' + P.Name + '''';
    QueueRows('DELETE FROM search_queue', IndexIds('SELECT id FROM search_queue WHERE part NOT IN (' + Known + ')', []));
    if FindFirst(IndexFolder + '*', faDirectory, Entry) = 0 then
    try
      repeat
        if (Entry.Name <> '.') and (Entry.Name <> '..') and (PartNamed(Entry.Name) = nil) then
          RemoveFolder(IndexFolder + Entry.Name);
      until FindNext(Entry) <> 0;
    finally
      FindClose(Entry);
    end;
    for P in Parts do
    begin
      if P.Index = nil then
      begin
        P.Index := TFerretIndex.Create(TComponent(nil));
        P.Index.FileName := IndexFolder + P.Name;
        P.Index.CacheLimit := 32 * 1024 * 1024;
      end;
      Made := '';
      Built := '';
      try
        Made := P.Index.ReadValue('made');
        Built := P.Index.ReadValue('built');
      except
        // damaged, or a newer program's: the next use opens an empty one and the part is built
        on E: EFerret do
        begin
          Note(P, 'its files do not open and are made again: ' + E.Message);
          RemoveFolder(IndexFolder + P.Name);
        end;
      end;
      At := 0;
      TryISO8601ToDate(Built, At);
      EnterCriticalSection(StateLock);
      P.Made := Made;
      P.Built := At;
      P.Problem := '';
      LeaveCriticalSection(StateLock);
    end;
    EnterCriticalSection(StateLock);
    Started := True;
    LeaveCriticalSection(StateLock);
  end;
  if Setting('search_stamp', '') = '' then
    SaveSetting('search_stamp', RandomHex(8));
end;

{ Applies up to a batch of P's waiting changes, stopping at Deadline.  True
  when none is left waiting.  Under DrainLock; a database failure is the
  caller's to catch, and leaves the rows waiting. }
function Drain(P: TPart; Deadline: QWord): boolean;
var
  Q: TSQLQuery;
  Rows, Docs: TStringArray;
  Doc: TFerretDocument;
  Seen: TStringList;
  Applied: integer;
begin
  Result := False;
  Rows := nil;
  Docs := nil;
  Q := Query('SELECT id, doc FROM search_queue WHERE part = :p AND done = 0 ORDER BY id LIMIT ' + IntToStr(Batch), [P.Name]);
  try
    while not Q.EOF do
    begin
      SetLength(Rows, Length(Rows) + 1);
      SetLength(Docs, Length(Rows));
      Rows[High(Rows)] := Q.Fields[0].AsString;
      Docs[High(Docs)] := Q.Fields[1].AsString;
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  if Length(Rows) = 0 then
    Exit(True);
  Applied := 0;
  Seen := TStringList.Create;
  try
    try
      while (Applied < Length(Rows)) and (GetTickCount64 < Deadline) do
      begin
        if Docs[Applied] = '' then
        begin
          // the whole part changed: it is built again, and says so on disk too
          P.Index.WriteValue('made', '');
          EnterCriticalSection(StateLock);
          P.Made := '';
          LeaveCriticalSection(StateLock);
        end
        else if Seen.IndexOf(Docs[Applied]) < 0 then
        begin
          Seen.Add(Docs[Applied]);
          Doc := Document(P, Docs[Applied]);
          try
            if Doc <> nil then
              P.Index.Add(Doc)
            else
              P.Index.Remove(Docs[Applied]);
          finally
            Doc.Free;
          end;
        end;
        P.Unsaved := True;
        Inc(Applied);
      end;
    except
      on E: EFerret do
      begin
        StoreFailed(P, E.Message);
        Exit;
      end;
    end;
  finally
    Seen.Free;
  end;
  QueueRows('UPDATE search_queue SET done = 1', Copy(Rows, 0, Applied));
  Result := (Applied = Length(Rows)) and (Length(Rows) < Batch);
end;

{ P built whole from its module's rows, on the calling thread.  Its own
  search answers meanwhile; what is queued during the build is applied by
  the next drain. }
procedure BuildPart(P: TPart);
var
  Target, Words: string;
  Room: int64;
  Done: boolean;
begin
  Target := Expected;
  Words := Languages;
  try
    Room := FreeBytes(IndexFolder);
    if (Room >= 0) and (Room < P.Index.SizeOnDisk + IndexSpare) then
    begin
      SetFailed(P, 'not enough free disk space');
      Exit;
    end;
    EnterCriticalSection(DrainLock);
    try
      EnterCriticalSection(StateLock);
      P.Building := True;
      P.Made := '';
      P.Problem := '';
      P.Step := '';
      LeaveCriticalSection(StateLock);
      // from here the index on disk is not to be trusted until the build is in
      P.Index.WriteValue('made', '');
      P.Index.Commit;
      P.Unsaved := False;
      QueueRows('DELETE FROM search_queue', IndexIds('SELECT id FROM search_queue WHERE part = :p', [P.Name]));
    finally
      LeaveCriticalSection(DrainLock);
    end;
    P.Ids := nil;
    P.At := 0;
    Done := P.Index.Rebuild(Words, @P.NextDoc, @P.Progress);
    if Done then
    begin
      P.Index.WriteValue('made', Target);
      P.Index.WriteValue('built', DateToISO8601(NowUTC));
      P.Index.Commit;
      Note(P, Format('built, %d documents', [P.Index.Count]));
    end;
    EnterCriticalSection(StateLock);
    P.Building := False;
    P.Step := '';
    if Done then
    begin
      P.Made := Target;
      P.Built := NowUTC;
    end;
    LeaveCriticalSection(StateLock);
  except
    on E: Exception do
      StoreFailed(P, E.Message);
  end;
end;

type
  { Builds the parts that are due, one after another, and once more when
    a build was asked for meanwhile. }
  TIndexBuilder = class(TThread)
  protected
    procedure Execute; override;
  end;

procedure TIndexBuilder.Execute;
var
  P: TPart;
  Seen: integer;
  Again: boolean;
begin
  try
    try
      CheckConnection;
      repeat
        Seen := BuildsAsked;
        for P in Parts do
          if NeedsBuild(P) and Keeping and not Restoring then
            BuildPart(P);
        EnterCriticalSection(StateLock);
        Again := BuildsAsked <> Seen;
        BuilderRuns := Again;
        LeaveCriticalSection(StateLock);
      until not Again;
    except
      on E: Exception do
      begin
        Log('Search index: ' + E.Message);
        BuilderRuns := False;
      end;
    end;
  finally
    DoneConnection;
  end;
end;

procedure StartBuilder;
var
  Wanted: boolean;
begin
  EnterCriticalSection(StateLock);
  Inc(BuildsAsked);
  Wanted := not BuilderRuns;
  BuilderRuns := True;
  LeaveCriticalSection(StateLock);
  if Wanted then
    with TIndexBuilder.Create(True) do
    begin
      FreeOnTerminate := True;
      Start;
    end;
end;

procedure BuildIndexNow(const Part: string);
begin
  EnterCriticalSection(DrainLock);
  try
    Prepare;
  finally
    LeaveCriticalSection(DrainLock);
  end;
  BuildPart(PartNamed(Part));
end;

{ The engine is set to the database: once no part builds, the indexes are
  closed and their folder, the queue's rows and the stamp go. }
procedure SwitchOff;
var
  P: TPart;
  Busy: boolean;
begin
  if not DirectoryExists(IndexFolder) and (Setting('search_stamp', '') = '') then
    Exit;
  EnterCriticalSection(DrainLock);
  try
    EnterCriticalSection(StateLock);
    Busy := BuilderRuns;
    for P in Parts do
      Busy := Busy or P.Building;
    if not Busy then
    begin
      Started := False;
      for P in Parts do
        P.Made := '';
    end;
    LeaveCriticalSection(StateLock);
    if Busy then
      Exit;
    // closed and never freed: a request's thread may still hold one
    for P in Parts do
      if P.Index <> nil then
      begin
        try
          P.Index.Close;
        except
          on EFerret do ;
        end;
        P.Unsaved := False;
      end;
    RemoveFolder(IndexFolder);
    QueueRows('DELETE FROM search_queue', IndexIds('SELECT id FROM search_queue', []));
    SaveSetting('search_stamp', '');
  finally
    LeaveCriticalSection(DrainLock);
  end;
end;

{ What P applied since its last save goes to disk, and only then do the
  queue's rows for it go. }
procedure Save(P: TPart);
var
  Applied: TStringArray;
begin
  EnterCriticalSection(DrainLock);
  try
    if not P.Unsaved then
      Exit;
    P.Unsaved := False;
    Applied := IndexIds('SELECT id FROM search_queue WHERE part = :p AND done = 1', [P.Name]);
  finally
    LeaveCriticalSection(DrainLock);
  end;
  try
    P.Index.Commit;
  except
    on E: EFerret do
    begin
      StoreFailed(P, E.Message);
      Exit;
    end;
  end;
  QueueRows('DELETE FROM search_queue', Applied);
end;

procedure IndexChore;
var
  P: TPart;
  Deadline: QWord;
  Due, Caught: boolean;
begin
  if not Keeping then
  begin
    SwitchOff;
    Exit;
  end;
  EnterCriticalSection(DrainLock);
  try
    Prepare;
  finally
    LeaveCriticalSection(DrainLock);
  end;
  Due := False;
  for P in Parts do
    Due := Due or NeedsBuild(P);
  if Due then
    StartBuilder;
  // the lock is given up between batches, so no search waits long
  Deadline := GetTickCount64 + 30000;
  for P in Parts do
    repeat
      Caught := not Answers(P);
      if not Caught then
      begin
        EnterCriticalSection(DrainLock);
        try
          Caught := Drain(P, Deadline);
        finally
          LeaveCriticalSection(DrainLock);
        end;
      end;
    until Caught or (GetTickCount64 >= Deadline);
  for P in Parts do
    Save(P);
end;

{ True when P answers and every committed change of it is in its index.
  Never waits behind another thread's drain: then P answers only when
  nothing waits.  Starts a build P is due for. }
function CaughtUp(P: TPart): boolean;
begin
  Result := False;
  try
    if TryEnterCriticalSection(DrainLock) <> 0 then
    try
      Prepare;
      Result := Answers(P) and Drain(P, GetTickCount64 + 100);
      if NeedsBuild(P) then
        StartBuilder;
    finally
      LeaveCriticalSection(DrainLock);
    end
    else
      Result := Answers(P) and (IntValue('SELECT COUNT(*) FROM search_queue WHERE part = :p AND done = 0', [P.Name]) = 0);
  except
    on E: EDatabaseError do
      Note(P, 'its own search answers this time: ' + E.Message);
  end;
end;

function IndexFind(ARequest: TRequest; const Me: TMember; const Part, Words: string; Offset, Limit: integer; out Answer: TIndexAnswer): boolean;
var
  P: TPart;
  Asked: TFerretQuery;
  Found: TFerretHits;
  Info: TFerretSearchInfo;
  Loaded: TSearchHits;
  Ids, Groups: TStringArray;
  Total, I, J, At, Missing, Count: integer;
begin
  Answer := Default(TIndexAnswer);
  Result := False;
  P := PartNamed(Part);
  if (P = nil) or not Keeping or not CaughtUp(P) then
    Exit;
  // deep pages are not worth their memory
  if Offset + Limit > 1000 then
    Exit(True);
  // a submitted query is complete: the space keeps its last word from matching as a beginning
  Asked := TFerretQuery.Create(StringReplace(StringReplace(StringReplace(Words, '“', '"', [rfReplaceAll]), '”', '"', [rfReplaceAll]), '„', '"', [rfReplaceAll]) + ' ');
  try
    Asked.CorrectSpelling := True;
    Asked.SnippetLength := 220;
    Asked.SnippetHtml := True;
    Asked.MarkTitle := True;
    Asked.OpenMarker := '<mark>';
    Asked.CloseMarker := '</mark>';
    Asked.Offset := Offset;
    Asked.Limit := Limit + 1;
    if Assigned(P.Groups) then
    begin
      Groups := P.Groups(ARequest, Me);
      Insert('', Groups, 0);
      Asked.RequireAny('group', Groups);
    end;
    if P.CountHalf > 0 then
      Asked.PreferHigh('count', P.CountHalf, 0.25);
    if (P.FreshDays > 0) and (P.FreshGain > 0) then
      Asked.PreferRecent('time', P.FreshDays, P.FreshGain, NowUTC);
    try
      Found := P.Index.Search(Asked, Total, Info);
    except
      // words the engine does not take, or files that do not read
      on EFerret do
        Exit;
    end;
  finally
    Asked.Free;
  end;
  SetLength(Ids, Length(Found));
  for I := 0 to High(Found) do
    Ids[I] := Found[I].Id;
  Loaded := nil;
  if Length(Ids) > 0 then
    Loaded := P.Load(ARequest, Me, Ids);
  // the index proposes, the module's rows decide; the hit past the page only says there is more
  Missing := 0;
  for I := 0 to High(Found) do
  begin
    At := -1;
    for J := 0 to High(Loaded) do
      if Loaded[J].Id = Found[I].Id then
        At := J;
    if At < 0 then
      Inc(Missing)
    else if I >= Limit then
      Answer.More := True
    else
    begin
      Count := Length(Answer.Hits);
      SetLength(Answer.Hits, Count + 1);
      SetLength(Answer.TitleHtml, Count + 1);
      SetLength(Answer.ExcerptHtml, Count + 1);
      Answer.Hits[Count] := Loaded[At];
      Answer.ExcerptHtml[Count] := Found[I].Snippet;
      // a title that changed since it was indexed is marked by the page
      if Found[I].Title = Loaded[At].Title then
        Answer.TitleHtml[Count] := Found[I].MarkedTitle;
    end;
  end;
  if Missing > 0 then
  begin
    EnterCriticalSection(StateLock);
    Inc(P.Refused, Missing);
    LeaveCriticalSection(StateLock);
  end
  else if Length(Answer.Hits) > 0 then
    Answer.Shown := Trim(Info.ShowingResultsFor);
  // words already searched for are not offered again
  if P.Open and (Answer.Shown = '') then
    Answer.Meant := Trim(Info.DidYouMean);
  // closed or emptied meanwhile: what was read is not to be trusted
  Result := Answers(P);
end;

function IndexOffers(ARequest: TRequest; const Me: TMember; const Part, Typed: string; Count: integer): TIndexOffers;
var
  P: TPart;
  Scope: TFerretQuery;
  Found: TFerretOffers;
  Ids, Groups: TStringArray;
  Loaded: TSearchHits;
  I, J: integer;

  procedure Add(const Text, Address: string);
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)].Text := Text;
    Result[High(Result)].Address := Address;
  end;

begin
  Result := nil;
  P := PartNamed(Part);
  if (P = nil) or not P.Open or not Keeping or not CaughtUp(P) then
    Exit;
  Scope := TFerretQuery.Create('');
  try
    if Assigned(P.Groups) then
    begin
      Groups := P.Groups(ARequest, Me);
      Insert('', Groups, 0);
      Scope.RequireAny('group', Groups);
    end;
    try
      Found := P.Index.Offers(Typed, Scope, Count);
    except
      on EFerret do
        Exit;
    end;
  finally
    Scope.Free;
  end;
  Ids := nil;
  for I := 0 to High(Found) do
    if (Found[I].Kind = foTitle) and (Found[I].Id <> '') then
    begin
      SetLength(Ids, Length(Ids) + 1);
      Ids[High(Ids)] := Found[I].Id;
    end;
  Loaded := nil;
  if Length(Ids) > 0 then
    Loaded := P.Load(ARequest, Me, Ids);
  // a title is offered only as the page the module still shows this reader
  for I := 0 to High(Found) do
    if Found[I].Kind = foWords then
      Add(Found[I].Text, '')
    else
      for J := 0 to High(Loaded) do
        if Loaded[J].Id = Found[I].Id then
          Add(Loaded[J].Title, Loaded[J].Address);
  if not Answers(P) then
    Result := nil;
end;

function IndexState: TJSONObject;
var
  P: TPart;
  List: TJSONArray;
  Item: TJSONObject;
  State: string;
begin
  List := TJSONArray.Create;
  Result := TJSONObject.Create(['engine', Setting('search_engine', 'database'), 'cgi', False, 'parts', List]);
  for P in Parts do
  begin
    Item := TJSONObject.Create(['part', P.Name, 'documents', 0, 'queued', IntValue('SELECT COUNT(*) FROM search_queue WHERE part = :p AND done = 0', [P.Name])]);
    List.Add(Item);
    if Keeping and (P.Index <> nil) then
      Item.Integers['documents'] := P.Index.Count;
    State := 'off';
    if Answers(P) then
      State := 'ready'
    else if Keeping then
      State := 'waiting';
    EnterCriticalSection(StateLock);
    try
      if (State = 'waiting') and (P.Problem <> '') then
        State := 'failed'
      else if (State = 'waiting') and P.Building then
        State := 'building';
      Item.Add('state', State);
      if P.Built > 0 then
        Item.Add('built', DateToISO8601(P.Built))
      else
        Item.Add('built', '');
      Item.Add('step', P.Step);
      Item.Add('refused', P.Refused);
      Item.Add('problem', P.Problem);
    finally
      LeaveCriticalSection(StateLock);
    end;
  end;
end;

{ The languages are ones the engine has word forms for, written its way. }
function CheckLanguages(Sent: TStrings): string;
var
  I: integer;
  Wanted, Code: string;
begin
  Result := '';
  I := Sent.IndexOfName('search_languages');
  if I < 0 then
    Exit;
  Wanted := LowerCase(StringReplace(Sent.ValueFromIndex[I], ' ', '', [rfReplaceAll]));
  if Wanted <> '' then
    for Code in Wanted.Split([',']) do
      if Pos(',' + Code + ',', ',' + StemLanguages + ',') = 0 then
        Exit(Format(Say('Word forms are known for these languages: %s.'), [StemLanguages]));
  Sent[I] := 'search_languages=' + Wanted;
end;
{$endif}

{ GET /api/admin/search  how each part's index stands }
procedure ShowState(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
begin
  if NeedPermission(ARequest, AResponse, 'manage-settings', Me) then
    SendJSON(AResponse, IndexState);
end;

initialization
  RegisterTable('CREATE TABLE IF NOT EXISTS search_queue (id INT AUTO_INCREMENT PRIMARY KEY, part VARCHAR(20) NOT NULL,' +
    ' doc VARCHAR(250) NOT NULL, done TINYINT NOT NULL DEFAULT 0) CHARACTER SET utf8mb4');
  RegisterSetting('search_engine', 'The site search answers from', 'database', 'choice:database|compare|index', 'Search');
  RegisterSetting('search_languages', 'Languages whose word forms a search matches (en, de, fr ...)', 'en', 'text', 'Search');
  LeaveOutOfBackups('search');
  RegisterStorageFolder('search', 'Search index', 'data/search');
  RegisterAfterRestore(@BlankStamp);
  RegisterAdminRoute('/api/admin/search', 'manage-settings');
  HTTPRouter.RegisterRoute('/api/admin/search', rmGet, @ShowState);
  {$ifndef CGI}
  InitCriticalSection(DrainLock);
  InitCriticalSection(StateLock);
  RegisterSettingsCheck(@CheckLanguages);
  RegisterChore(@IndexChore, 1);
  {$endif}
end.
