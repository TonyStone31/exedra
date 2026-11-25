unit SiteStats;

{ Daily visitor counts, access logs and storage totals for administration.
  Counts retain only a daily salted address digest; SiteVisitors reads
  request logs. Storage measurements cover registered folders and tables. }

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, fpjson, contnrs, httpdefs;

const
  { A request header the server itself sets on every request: 1 on one that
    came as HEAD and is handled as its GET. }
  HEAD_MARK = 'X-Exedra-Head';

type
  TTrafficCount = record
    Day, Part: string;
    // People: the visitors that are browsers, the rest being bots
    Requests, Visitors, People, Refused: int64;
  end;
  TTrafficCounts = array of TTrafficCount;

  { Only today's salted digests are held; snapshots contain counts only. }
  TVisitorCounts = class
  private
    FDay, FSalt: string;
    FSeen: TFPHashList;
    FCounts: TTrafficCounts;
    // today's parts, for the address that shows itself a browser after coming to some
    FParts: TStringList;
    FPaths: TStringList;
    FLock: TRTLCriticalSection;
    procedure Rotate(const Day: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Note(const Day, Part, Path, Address: string; Refused: boolean; Proof: integer = 0);
    function Snapshot(const Day: string): TTrafficCounts;
    procedure Subtract(const Counts: TTrafficCounts);
    function Paths(const Day: string): TJSONArray;
  end;

{ Register during unit initialization. Prefixes match a path boundary;
  a trailing '-' also matches a family such as /wiki-pages. Longest wins. }
procedure RegisterVisitorPart(const Part, Prefix: string);
function VisitorPart(const Path: string): string;
function VisitorPath(const Path: string): string;
procedure NoteRequest(const Path, Address: string; Refused: boolean = False);
{ What a request says of its address being a browser: 2 its scripts called
  home (an open tab asking what is new), 1 it took one of the page's files
  (two make a browser), 0 nothing.  The visitor report tells them the same way. }
function BrowserProof(const Path: string): integer;
procedure NoteWebRequest(ARequest: TRequest; Refused: boolean = False);
{ A refusal before the router has a request; no address or path is retained. }
procedure NoteTransportRefusal;
function VisitorsJSON: TJSONObject;
{ Relative folders use the site's files root; a setting may override it. }
procedure RegisterStorageFolder(const Name, Caption, Folder: string; const SettingName: string = '');
procedure RegisterStorageTables(const Name, Caption, Tables: string);
{ The registered folders as name=path, resolved the way measuring does. }
function StorageFolderList: TStringList;

function StorageJSON: TJSONObject;
procedure MeasureStorage;
{ Daily tab-separated access logs under the files root, kept access_log_days
  days (0 disables logging). Mask secrets with VisitorPath and log once
  after the response, when status and elapsed time are known. Field order is
  in docs/CODE-MAP.md. }
procedure AccessLog(ARequest: TRequest; Code: integer);
{ The start of a request on this thread, for the time taken in its log line. }
procedure RequestBegins;

type
  { A day's log line by line, in pieces of a megabyte, up to Limit bytes:
    the size it had when a report first opened it, so a second reading of
    today's growing log sees the same lines.  A last line without its line
    end is left for the next report.  Read without the lock every request
    writes under: a read of a large day would hold up the whole site. }
  TLogReader = class
  private
    FStream: TFileStream;
    FBuffer: string;
    FAt: integer;
    FLeft, FLimit: int64;
    function StampAt(From: int64; out Start: int64): string;
  public
    { Limit below 0: the whole file as it is now. }
    constructor Create(const Path: string; Limit: int64);
    destructor Destroy; override;
    function Next(out Line: string): boolean;
    { Moves to the first line at or after the moment At (yyyy-mm-ddThh:nn:ssZ),
      the lines being in time order; a reader still compares each line's
      time, since a line can sit a second out of order. }
    procedure SeekTo(const At: string);
    property Limit: int64 read FLimit;
  end;

  { A log line's fields: time, address, method, path, referer, browser,
    member, status code, milliseconds; '' where a line is older than a field. }
  TFields = array[0..8] of string;

{ A line's fields into F, the number of them back.  Not Split, whose new
  array for each of a million lines was a quarter of a report's time. }
function SplitLine(const Line: string; var F: TFields): integer;
{ A day's log to read (yyyy-mm-dd), up to Limit bytes, or all of it as it
  is now when Limit is below 0; nil when the day has no log. }
function OpenLog(const Day: string; Limit: int64): TLogReader;
{ A line's fields as the admin's lists want them. }
function LineJSON(const F: TFields; N: integer): TJSONObject;
{ The last Count lines of a day's log (yyyy-mm-dd, today when ''), newest
  first; one address's, or one browser's at it, when given; within FromAt
  to ToAt (moments, yyyy-mm-ddThh:nn:ssZ) when given. }
function AccessLines(const Day: string; Count: integer; const Ip: string = ''; const Agent: string = ''; const FromAt: string = ''; const ToAt: string = ''): TJSONArray;
{ The days that have a log, newest first. }
function AccessLogDays: TStringList;
{ The folder the access logs are in, with its path delimiter. }
function LogsFolder: string;

implementation

uses StrUtils, Math, Variants, {$ifdef unix} Unix, {$endif} httproute, SiteDb, SiteSql, SiteUsers;

type
  TVisitorPrefix = record
    Part, Prefix: string;
  end;

  TStoragePart = record
    Name, Caption, Folder, SettingName, Tables: string;
  end;

var
  Prefixes: array of TVisitorPrefix;
  StorageParts: array of TStoragePart;
  Traffic: TVisitorCounts;

threadvar
  CountedRequest, LoggedRequest: string;
  // when this thread's request came in; each request runs on a thread of its own
  RequestStarted: QWord;

function Today: string;
begin
  Result := FormatDateTime('yyyy-mm-dd', NowUTC);
end;

constructor TVisitorCounts.Create;
begin
  inherited Create;
  InitCriticalSection(FLock);
  FSeen := TFPHashList.Create;
  FPaths := TStringList.Create;
  FPaths.Sorted := True;
  FParts := TStringList.Create;
end;

destructor TVisitorCounts.Destroy;
begin
  FSalt := '';
  FSeen.Free;
  FPaths.Free;
  FParts.Free;
  DoneCriticalSection(FLock);
  inherited Destroy;
end;

procedure TVisitorCounts.Rotate(const Day: string);
begin
  if (FDay <> '') and (Day <= FDay) then
    Exit;
  FSeen.Clear;
  FPaths.Clear;
  FParts.Clear;
  FSalt := RandomHex(32);
  FDay := Day;
end;

procedure TVisitorCounts.Note(const Day, Part, Path, Address: string; Refused: boolean; Proof: integer);
var
  I, Slot: integer;
  Digest, DayKey, Who: string;
  Browser: boolean;

  function SlotOf(const APart: string): integer;
  var
    K: integer;
  begin
    for K := 0 to High(FCounts) do
      if (FCounts[K].Day = DayKey) and (FCounts[K].Part = APart) then
        Exit(K);
    Result := Length(FCounts);
    SetLength(FCounts, Result + 1);
    FCounts[Result].Day := DayKey;
    FCounts[Result].Part := APart;
  end;

  // the address has shown itself a browser: a person in every part it came to today
  procedure Person(const APart: string);
  var
    K: integer;
  begin
    if FSeen.FindIndexOf(APart + ':' + Who) < 0 then
      Exit;
    // the slot first: finding it may move the counts
    K := SlotOf(APart);
    Inc(FCounts[K].People);
  end;

begin
  EnterCriticalSection(FLock);
  try
    DayKey := Day;
    if DayKey = '' then
      DayKey := Today;
    Rotate(DayKey);
    Slot := SlotOf(Part);
    Inc(FCounts[Slot].Requests);
    if Refused then
      Inc(FCounts[Slot].Refused);
    if (Address <> '') and (DayKey = FDay) then
    begin
      Who := Sha256Hex(FSalt + ':' + Address);
      Browser := FSeen.FindIndexOf('browser:' + Who) >= 0;
      Digest := Part + ':' + Who;
      if FSeen.FindIndexOf(Digest) < 0 then
      begin
        if FParts.IndexOf(Part) < 0 then
          FParts.Add(Part);
        FSeen.Add(Digest, Pointer(PtrUInt(1)));
        Inc(FCounts[Slot].Visitors);
        if Browser then
          Inc(FCounts[Slot].People);
      end;
      // a bot with a browser's name takes the bare page; a browser takes the
      // page's files and its scripts call home (12 Nov 2026: one scraper, a
      // page each from 12,661 addresses, had counted as that many visitors)
      if not Browser and (Proof = 1) and (FSeen.FindIndexOf('file:' + Who) < 0) then
      begin
        FSeen.Add('file:' + Who, Pointer(PtrUInt(1)));
        Proof := 0;
      end;
      if not Browser and (Proof > 0) then
      begin
        FSeen.Add('browser:' + Who, Pointer(PtrUInt(1)));
        for I := 0 to FParts.Count - 1 do
          Person(FParts[I]);
      end;
    end;
    if (Path <> '') and (DayKey = FDay) then
    begin
      I := FPaths.IndexOf(Path);
      // Bound memory under probes that use a different path every time.
      if I >= 0 then
        FPaths.Objects[I] := TObject(PtrInt(FPaths.Objects[I]) + 1)
      else if FPaths.Count < 10000 then
        FPaths.AddObject(Path, TObject(PtrInt(1)));
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TVisitorCounts.Snapshot(const Day: string): TTrafficCounts;
begin
  EnterCriticalSection(FLock);
  try
    Rotate(Day);
    Result := Copy(FCounts);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TVisitorCounts.Subtract(const Counts: TTrafficCounts);
var
  I, J: integer;
begin
  EnterCriticalSection(FLock);
  try
    for I := 0 to High(Counts) do
      for J := 0 to High(FCounts) do
        if (Counts[I].Day = FCounts[J].Day) and (Counts[I].Part = FCounts[J].Part) then
        begin
          Dec(FCounts[J].Requests, Counts[I].Requests);
          Dec(FCounts[J].Visitors, Counts[I].Visitors);
          Dec(FCounts[J].People, Counts[I].People);
          Dec(FCounts[J].Refused, Counts[I].Refused);
        end;
    for J := High(FCounts) downto 0 do
      if (FCounts[J].Requests = 0) and (FCounts[J].People = 0) then
      begin
        FCounts[J] := FCounts[High(FCounts)];
        SetLength(FCounts, Length(FCounts) - 1);
      end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TVisitorCounts.Paths(const Day: string): TJSONArray;
var
  I, J, Best: integer;
  Ranked: TStringList;
  N, Highest: int64;
begin
  Result := TJSONArray.Create;
  Ranked := TStringList.Create;
  try
    EnterCriticalSection(FLock);
    try
      Rotate(Day);
      Ranked.Assign(FPaths);
    finally
      LeaveCriticalSection(FLock);
    end;
    for I := 1 to 30 do
    begin
      Best := -1;
      Highest := 0;
      for J := 0 to Ranked.Count - 1 do
      begin
        N := PtrInt(Ranked.Objects[J]);
        if N > Highest then
        begin
          Best := J;
          Highest := N;
        end;
      end;
      if Best < 0 then
        Break;
      Result.Add(TJSONObject.Create(['path', Ranked[Best], 'requests', Highest]));
      Ranked.Delete(Best);
    end;
  finally
    Ranked.Free;
  end;
end;

procedure RegisterVisitorPart(const Part, Prefix: string);
var
  N: integer;
begin
  N := Length(Prefixes);
  SetLength(Prefixes, N + 1);
  Prefixes[N].Part := Part;
  Prefixes[N].Prefix := LowerCase(Prefix);
  if Prefix <> '/' then
    Prefixes[N].Prefix := ExcludeTrailingPathDelimiter(Prefixes[N].Prefix);
end;

function VisitorPath(const Path: string): string;
var
  I: integer;
  Secret: string;
begin
  Result := Copy(Path, 1, Pos('?', Path + '?') - 1);
  Result := Copy(Result, 1, Pos('#', Result + '#') - 1);
  // Links that carry a secret (one-time credentials, mail keys, private file
  // tokens) must not become a path in the statistics.
  for Secret in ['/password/', '/_oauth/', '/verify/', '/mail-off/', '/f/'] do
    if StartsText(Secret, HTTPDecode(Result)) then
      Exit(Secret + '*');
  for I := 1 to Length(Result) do
    if Ord(Result[I]) < 32 then
      Result[I] := '_';
  Result := Copy(Result, 1, 512);
end;

function VisitorPart(const Path: string): string;
var
  Item: TVisitorPrefix;
  P: string;
  Best: integer;
begin
  P := LowerCase(HTTPDecode(VisitorPath(Path)));
  Best := 0;
  Result := 'other';
  for Item in Prefixes do
    if (Length(Item.Prefix) > Best) and ((P = Item.Prefix) or (StartsStr(Item.Prefix, P) and (Item.Prefix.EndsWith('-') or
      ((Length(P) > Length(Item.Prefix)) and (P[Length(Item.Prefix) + 1] = '/'))))) then
    begin
      Best := Length(Item.Prefix);
      Result := Item.Part;
    end;
end;

function BrowserProof(const Path: string): integer;
begin
  if StartsStr('/api/live', Path) or StartsStr('/api/sync', Path) or StartsStr('/ws', Path) then
    Result := 2
  else if StartsStr('/static/', Path) then
    Result := 1
  else
    Result := 0;
end;

procedure NoteRequest(const Path, Address: string; Refused: boolean);
begin
  {$ifndef CGI}
  Traffic.Note('', VisitorPart(Path), VisitorPath(Path), Address, Refused, BrowserProof(Path));
  {$endif}
end;

procedure NoteTransportRefusal;
begin
  NoteRequest('', '', True);
end;

procedure RequestBegins;
begin
  RequestStarted := GetTickCount64;
end;

procedure NoteWebRequest(ARequest: TRequest; Refused: boolean);
begin
  if CountedRequest = ARequest.RequestID then
    Exit;
  CountedRequest := ARequest.RequestID;
  if RequestStarted = 0 then
    RequestBegins;
  NoteRequest(ARequest.PathInfo, ClientIp(ARequest), Refused);
end;

var
  AccessLock: TRTLCriticalSection;

{ Under the data folder, which the service may write to (systemd keeps the
  rest of /opt/exedra read-only for it); the backup takes data along. }
function LogsFolder: string;
begin
  Result := IncludeTrailingPathDelimiter(Setting('files', ExtractFilePath(ParamStr(0)))) + 'data' + PathDelim + 'logs' + PathDelim;
end;

{ A referring address with a secret in its path (a reset or sign-in link
  whose page then asks for its scripts) kept only as far as the secret. }
function SafeReferer(const Url: string): string;
var
  P, Q: integer;
  Rest: string;
begin
  Result := Url;
  P := Pos('://', Url);
  if P = 0 then
    Exit;
  Q := PosEx('/', Url, P + 3);
  if Q = 0 then
    Exit;
  Rest := VisitorPath(Copy(Url, Q, MaxInt));
  if (Rest <> '') and (Rest[Length(Rest)] = '*') then
    Result := Copy(Url, 1, Q - 1) + Rest;
end;

function OneLine(const S: string; Limit: integer): string;
var
  I: integer;
begin
  Result := Copy(S, 1, Limit);
  for I := 1 to Length(Result) do
    if Result[I] in [#0..#31, #127] then
      Result[I] := ' ';
end;

procedure AccessLog(ARequest: TRequest; Code: integer);
var
  F: TextFile;
  Line, Path, Member, Taken, Day, Method: string;
begin
  if (ARequest = nil) or (SettingInt('access_log_days', 14) <= 0) then
    Exit;
  if LoggedRequest = ARequest.RequestID then
    Exit;
  LoggedRequest := ARequest.RequestID;
  Path := VisitorPath(ARequest.PathInfo);
  if (ARequest.QueryString <> '') and (Pos('*', Path) = 0) then
    Path := Path + '?' + ARequest.QueryString;
  // a HEAD request is handled as its GET (SiteHttpGuard), and written as it came
  Method := ARequest.Method;
  if ARequest.GetCustomHeader(HEAD_MARK) = '1' then
    Method := 'HEAD';
  Line := #9 + ClientIp(ARequest) + #9 + Method + #9 + OneLine(Path, 300) + #9 + OneLine(SafeReferer(ARequest.Referer), 200) + #9 + OneLine(ARequest.UserAgent, 200);
  // who is reading: the session the handler looked up, cached for it.  A
  // request without a sign-in is nobody's without asking; one turned away
  // for its pace or size is not looked up either
  Member := '';
  if ((ARequest.Authorization <> '') or (ARequest.CookieFields.Values['sid'] <> '')) and (Code <> 413) and (Code <> 429) and (Code <> 503) then
  try
    Member := CurrentMember(ARequest).Name;
  except
    Member := '';
  end;
  Taken := '';
  if RequestStarted > 0 then
    Taken := IntToStr(GetTickCount64 - RequestStarted);
  RequestStarted := 0;
  Line := Line + #9 + OneLine(Member, 60) + #9 + IntToStr(Code) + #9 + Taken;
  EnterCriticalSection(AccessLock);
  try
    try
      // the time under the lock: the lines stay in time order, which lets a
      // reader seek to a moment instead of reading the day from its start
      Day := Today;
      Line := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', NowUTC) + Line;
      ForceDirectories(LogsFolder);
      AssignFile(F, LogsFolder + 'access-' + Day + '.log');
      if FileExists(LogsFolder + 'access-' + Day + '.log') then
        Append(F)
      else
        Rewrite(F);
      try
        WriteLn(F, Line);
      finally
        CloseFile(F);
      end;
    except
      // a full disk or a folder gone is no reason to fail the request
    end;
  finally
    LeaveCriticalSection(AccessLock);
  end;
end;

type
  { The router's after step: every request it answered, refused by the guard
    or not, is logged here with its status code.  One that failed with an
    exception skips this step; the error page logs it. }
  TAccessLogger = class
    procedure Done(ARequest: TRequest; AResponse: TResponse; var aContinue: boolean);
  end;

procedure TAccessLogger.Done(ARequest: TRequest; AResponse: TResponse; var aContinue: boolean);
begin
  AccessLog(ARequest, AResponse.Code);
end;

var
  AccessLogger: TAccessLogger;

constructor TLogReader.Create(const Path: string; Limit: int64);
begin
  FStream := TFileStream.Create(Path, fmOpenRead or fmShareDenyNone);
  if (Limit < 0) or (Limit > FStream.Size) then
    Limit := FStream.Size;
  FLimit := Limit;
  FLeft := Limit;
  FAt := 1;
end;

destructor TLogReader.Destroy;
begin
  FStream.Free;
  inherited;
end;

function TLogReader.Next(out Line: string): boolean;
var
  P, Got: integer;
  Piece: string;
begin
  Result := False;
  Line := '';
  repeat
    P := PosEx(#10, FBuffer, FAt);
    if P > 0 then
    begin
      Line := Copy(FBuffer, FAt, P - FAt);
      if (Line <> '') and (Line[Length(Line)] = #13) then
        SetLength(Line, Length(Line) - 1);
      FAt := P + 1;
      Exit(True);
    end;
    if FLeft <= 0 then
      Exit;
    SetLength(Piece, Min(FLeft, 1 shl 20));
    Got := FStream.Read(Piece[1], Length(Piece));
    if Got <= 0 then
    begin
      FLeft := 0;
      Exit;
    end;
    SetLength(Piece, Got);
    Dec(FLeft, Got);
    FBuffer := Copy(FBuffer, FAt, MaxInt) + Piece;
    FAt := 1;
  until False;
end;

{ The time (the first twenty bytes) of the first whole line that starts at
  or after From, and in Start where it starts; '' and Start = Limit when no
  line starts before the limit. }
function TLogReader.StampAt(From: int64; out Start: int64): string;
var
  Piece: string;
  Got, P: integer;
begin
  Result := '';
  Start := From;
  if From > 0 then
  begin
    // the line end before the start: looked for from the byte before From,
    // so a From that is itself a line's start is found to be one
    FStream.Position := From - 1;
    P := 0;
    repeat
      SetLength(Piece, 4096);
      Got := FStream.Read(Piece[1], Length(Piece));
      if Got <= 0 then
        Break;
      SetLength(Piece, Got);
      P := Pos(#10, Piece);
      if P > 0 then
        Start := FStream.Position - Got + P;
    until (P > 0) or (FStream.Position >= FLimit);
    if P = 0 then
    begin
      Start := FLimit;
      Exit;
    end;
  end;
  if Start + 20 > FLimit then
  begin
    Start := FLimit;
    Exit;
  end;
  FStream.Position := Start;
  SetLength(Result, 20);
  SetLength(Result, FStream.Read(Result[1], 20));
end;

procedure TLogReader.SeekTo(const At: string);
var
  Lo, Hi, Mid, Start: int64;
  Stamp: string;
begin
  if At = '' then
    Exit;
  // the first line at or after At starts at or past Lo, and at or before
  // the first line that starts at or after Hi
  Lo := 0;
  Hi := FLimit;
  while Lo < Hi do
  begin
    Mid := (Lo + Hi) div 2;
    Stamp := StampAt(Mid, Start);
    if (Stamp = '') or (Stamp >= At) then
      Hi := Mid
    else
      Lo := Start + 1;
  end;
  StampAt(Lo, Start);
  FStream.Position := Start;
  FLeft := FLimit - Start;
  FBuffer := '';
  FAt := 1;
end;

function SplitLine(const Line: string; var F: TFields): integer;
var
  P, Start, I: integer;
begin
  Result := 0;
  Start := 1;
  while Result <= High(F) do
  begin
    P := PosEx(#9, Line, Start);
    if P = 0 then
    begin
      F[Result] := Copy(Line, Start, MaxInt);
      Inc(Result);
      Break;
    end;
    F[Result] := Copy(Line, Start, P - Start);
    Inc(Result);
    Start := P + 1;
  end;
  for I := Result to High(F) do
    F[I] := '';
end;

function OpenLog(const Day: string; Limit: int64): TLogReader;
var
  Path: string;
begin
  Path := LogsFolder + 'access-' + Day + '.log';
  if (Length(Day) <> 10) or not FileExists(Path) then
    Exit(nil);
  Result := TLogReader.Create(Path, Limit);
end;

function LineJSON(const F: TFields; N: integer): TJSONObject;
var
  Path: string;
begin
  Path := F[3];
  if (Path = '') or (Path[1] = '?') then
    Path := '/' + Path;
  Result := TJSONObject.Create(['at', F[0], 'ip', F[1], 'method', F[2], 'path', Path, 'referer', F[4], 'agent', F[5], 'member', F[6]]);
  // the status and the time taken, where the line has them
  if N >= 8 then
    Result.Add('status', StrToIntDef(F[7], 0));
  if (N >= 9) and (F[8] <> '') then
    Result.Add('ms', StrToIntDef(F[8], 0));
end;

function AccessLines(const Day: string; Count: integer; const Ip: string; const Agent: string; const FromAt: string; const ToAt: string): TJSONArray;
var
  Reader: TLogReader;
  Kept: array of string;
  Line, FileName, Mark: string;
  Next, Have, I, N: integer;
  F: TFields;
begin
  Result := TJSONArray.Create;
  FileName := Day;
  if FileName = '' then
    FileName := Today;
  Reader := OpenLog(FileName, -1);
  if Reader = nil then
    Exit;
  // the last Count lines that match, in a ring: a day is read once, streaming
  SetLength(Kept, Max(Count, 1));
  Next := 0;
  Have := 0;
  Mark := #9 + Ip + #9;
  try
    if (FromAt <> '') and (Copy(FromAt, 1, 10) = FileName) then
      Reader.SeekTo(FromAt);
    while Reader.Next(Line) do
    begin
      // the address somewhere in the line is cheap to ask; its own field is checked after
      if (Ip <> '') and (Pos(Mark, Line) = 0) then
        Continue;
      N := SplitLine(Line, F);
      if (N < 6) or ((Ip <> '') and (F[1] <> Ip)) or ((Agent <> '') and (F[5] <> Agent)) then
        Continue;
      if ((FromAt <> '') and (F[0] < FromAt)) or ((ToAt <> '') and (F[0] > ToAt)) then
        Continue;
      Kept[Next] := Line;
      Next := (Next + 1) mod Length(Kept);
      if Have < Length(Kept) then
        Inc(Have);
    end;
  finally
    Reader.Free;
  end;
  for I := 1 to Have do
  begin
    N := SplitLine(Kept[(Next - I + Length(Kept)) mod Length(Kept)], F);
    Result.Add(LineJSON(F, N));
  end;
end;

function NewestFirst(List: TStringList; A, B: integer): integer;
begin
  Result := CompareStr(List[B], List[A]);
end;

function AccessLogDays: TStringList;
var
  Found: TSearchRec;
begin
  Result := TStringList.Create;
  if FindFirst(LogsFolder + 'access-*.log', faAnyFile, Found) = 0 then
  try
    repeat
      if Length(Found.Name) = Length('access-yyyy-mm-dd.log') then
        Result.Add(Copy(Found.Name, 8, 10));
    until FindNext(Found) <> 0;
  finally
    FindClose(Found);
  end;
  // newest first
  Result.CustomSort(@NewestFirst);
end;

{ Logs older than access_log_days go, once an hour with the storage measure. }
procedure PruneAccessLogs;
var
  Info: TSearchRec;
  Days: integer;
begin
  Days := SettingInt('access_log_days', 14);
  if Days < 1 then
    Days := 1;
  if FindFirst(LogsFolder + 'access-*.log', faAnyFile, Info) = 0 then
  try
    repeat
      if Now - Info.TimeStamp > Days then
        DeleteFile(LogsFolder + Info.Name);
    until FindNext(Info) <> 0;
  finally
    FindClose(Info);
  end;
end;

procedure FlushVisitors;
var
  Batch: TTrafficCounts;
  Item: TTrafficCount;
begin
  Batch := Traffic.Snapshot(Today);
  Exec('START TRANSACTION', []);
  try
    for Item in Batch do
      Exec('INSERT INTO visitor_days (day, part, requests, visitors, refused, people) VALUES (:d, :p, :r, :v, :f, :b)' +
        SqlOnConflict('day, part', 'requests = requests + ' + SqlNew('requests') + ',' + ' visitors = visitors + ' + SqlNew('visitors') +
        ', refused = refused + ' + SqlNew('refused') + ', people = people + ' + SqlNew('people')),
        [Item.Day, Item.Part, Item.Requests, Item.Visitors, Item.Refused, Item.People]);
    Exec('DELETE FROM visitor_days WHERE day < ' + SqlMinus('UTC_DATE()', '399', suDay), []);
    Exec('COMMIT', []);
    Traffic.Subtract(Batch);
  except
    Exec('ROLLBACK', []);
    raise;
  end;
end;

function VisitorsJSON: TJSONObject;
var
  Days: TJSONArray;
  Known, Index: TStringList;
  Prefix: TVisitorPrefix;
  PartText, DayText: string;
  DayItem: TJSONObject;
  I, Slot: integer;
begin
  Days := TJSONArray.Create;
  Known := TStringList.Create;
  Index := TStringList.Create;
  try
    Known.Sorted := True;
    Known.Duplicates := dupIgnore;
    Known.Add('other');
    for Prefix in Prefixes do
      Known.Add(Prefix.Part);
    for I := 0 to 29 do
      for PartText in Known do
      begin
        DayText := FormatDateTime('yyyy-mm-dd', NowUTC - I);
        DayItem := TJSONObject.Create(['day', DayText, 'part', PartText, 'requests', int64(0), 'visitors', int64(0), 'people', int64(0), 'refused', int64(0)]);
        Index.AddObject(DayText + ':' + PartText, DayItem);
        Days.Add(DayItem);
      end;
    with Query('SELECT ' + SqlDay('day') + ', part, requests, visitors, refused, people FROM visitor_days' + ' WHERE day >= ' +
        SqlMinus('UTC_DATE()', '29', suDay) + ' ORDER BY day DESC, part', []) do
    try
      while not EOF do
      begin
        Slot := Index.IndexOf(Fields[0].AsString + ':' + Fields[1].AsString);
        if Slot >= 0 then
        begin
          DayItem := TJSONObject(Index.Objects[Slot]);
          DayItem.Int64s['requests'] := Fields[2].AsLargeInt;
          DayItem.Int64s['visitors'] := Fields[3].AsLargeInt;
          DayItem.Int64s['refused'] := Fields[4].AsLargeInt;
          DayItem.Int64s['people'] := Fields[5].AsLargeInt;
        end;
        Next;
      end;
    finally
      Free;
    end;
  finally
    Index.Free;
    Known.Free;
  end;
  Result := TJSONObject.Create(['days', Days, 'paths', Traffic.Paths(Today), 'server', {$ifdef CGI}False{$else}True{$endif}]);
end;

procedure RegisterStorageFolder(const Name, Caption, Folder: string; const SettingName: string);
var
  N: integer;
begin
  N := Length(StorageParts);
  SetLength(StorageParts, N + 1);
  StorageParts[N].Name := Name;
  StorageParts[N].Caption := Caption;
  StorageParts[N].Folder := Folder;
  StorageParts[N].SettingName := SettingName;
end;

procedure RegisterStorageTables(const Name, Caption, Tables: string);
begin
  RegisterStorageFolder(Name, Caption, '');
  StorageParts[High(StorageParts)].Tables := Tables;
end;

function StorageFolderList: TStringList;
var
  Item: TStoragePart;
  Root, Folder: string;
begin
  Result := TStringList.Create;
  Root := IncludeTrailingPathDelimiter(Setting('files', ExtractFilePath(ParamStr(0))));
  for Item in StorageParts do
    if Item.Tables = '' then
    begin
      Folder := Root + Item.Folder;
      if Item.SettingName = 'files_dir' then
        Folder := ExtractFilePath(ParamStr(0)) + 'data/files';
      if Item.SettingName <> '' then
        Folder := Setting(Item.SettingName, Folder);
      Result.Values[Item.Name] := ExcludeTrailingPathDelimiter(Folder);
    end;
end;

function FolderBytes(const Folder: string; var Complete: boolean): int64;
var
  Entry: TSearchRec;
  Code: integer;
begin
  Result := 0;
  if not DirectoryExists(Folder) then
    Exit;
  Code := FindFirst(IncludeTrailingPathDelimiter(Folder) + '*', faAnyFile, Entry);
  if Code <> 0 then
  begin
    Complete := False;
    Exit;
  end;
  try
    repeat
      if (Entry.Name = '.') or (Entry.Name = '..') then
        Continue;
      // Do not follow a link outside the registered folder or into a cycle.
      {$push}
      {$warn 5044 off}
      if (Entry.Attr and faSymLink) <> 0 then
        Continue;
      {$pop}
      if (Entry.Attr and faDirectory) <> 0 then
        Inc(Result, FolderBytes(IncludeTrailingPathDelimiter(Folder) + Entry.Name, Complete))
      else
        Inc(Result, Entry.Size);
    until FindNext(Entry) <> 0;
  finally
    FindClose(Entry);
  end;
end;

procedure MeasureStorage;
var
  Item, Group: TStoragePart;
  Tables, Totals: TStringList;
  Root, Folder, GroupName: string;
  Bytes: int64;
  Complete: boolean;
  I: integer;
begin
  // A database lock and saved time also limit separate maintenance processes.
  if IntValue('SELECT ' + SqlLock('''storage_measure''', 0), []) <> 1 then
    Exit;
  try
    if IntValue('SELECT COUNT(*) FROM storage_sizes WHERE measured > ' + SqlMinus(SqlUtcNow, '1', suHour), []) > 0 then
      Exit;
    Tables := TStringList.Create;
    Totals := TStringList.Create;
    try
      with Query(SqlTableSizes, []) do
      try
        while not EOF do
        begin
          Tables.AddPair(Fields[0].AsString, Fields[1].AsString);
          Next;
        end;
      finally
        Free;
      end;
      for I := 0 to Tables.Count - 1 do
      begin
        GroupName := 'chat';
        for Group in StorageParts do
          if (Group.Tables <> '') and (Pos(',' + Tables.Names[I] + ',', ',' + Group.Tables + ',') > 0) then
            GroupName := Group.Name;
        Totals.Values[GroupName] := IntToStr(StrToInt64Def(Totals.Values[GroupName], 0) + StrToInt64Def(Tables.ValueFromIndex[I], 0));
      end;
      Root := IncludeTrailingPathDelimiter(Setting('files', ExtractFilePath(ParamStr(0))));
      for Item in StorageParts do
      begin
        Complete := True;
        if Item.Tables <> '' then
          Bytes := StrToInt64Def(Totals.Values[Item.Name], 0)
        else
        begin
          Folder := Root + Item.Folder;
          if Item.SettingName = 'files_dir' then
            Folder := ExtractFilePath(ParamStr(0)) + 'data/files';
          if Item.SettingName <> '' then
            Folder := Setting(Item.SettingName, Folder);
          Bytes := FolderBytes(Folder, Complete);
        end;
        Exec(SqlReplace('storage_sizes', 'name, caption, kind, bytes, complete, measured', ':n, :c, :k, :b, :ok, ' + SqlUtcNow),
          [Item.Name, Item.Caption, Ord(Item.Tables <> ''), Bytes, Ord(Complete)]);
      end;
    finally
      Totals.Free;
      Tables.Free;
    end;
  finally
    Value('SELECT ' + SqlUnlock('''storage_measure'''), []);
  end;
end;

{$ifdef unix}
procedure DiskNumbers(out Total, Free: int64);
var
  Stat: TStatFS;
begin
  Total := 0;
  Free := 0;
  if fpStatFS(PChar(Setting('files', ExtractFilePath(ParamStr(0)))), @Stat) = 0 then
  begin
    Total := int64(Stat.bsize) * Stat.blocks;
    Free := int64(Stat.bsize) * Stat.bavail;
  end;
end;
{$else}

procedure DiskNumbers(out Total, Free: int64);
begin
  Total := 0;
  Free := 0;
end;
{$endif}

function StorageJSON: TJSONObject;
var
  DiskTotal, DiskFree: int64;
  Items: TJSONArray;
begin
  Items := TJSONArray.Create;
  with Query('SELECT name, caption, kind, bytes, complete, ' + IsoTime('measured') + ' FROM storage_sizes ORDER BY kind DESC, name', []) do
  try
    while not EOF do
    begin
      Items.Add(TJSONObject.Create(['name', Fields[0].AsString, 'caption', Fields[1].AsString, 'table_group', Fields[2].AsInteger = 1,
        'bytes', Fields[3].AsLargeInt, 'complete', Fields[4].AsInteger = 1, 'measured', Fields[5].AsString]));
      Next;
    end;
  finally
    Free;
  end;
  DiskNumbers(DiskTotal, DiskFree);
  Result := TJSONObject.Create(['items', Items, 'disk_total', DiskTotal, 'disk_free', DiskFree]);
end;

initialization
  Traffic := TVisitorCounts.Create;
  AccessLogger := TAccessLogger.Create;
  // before the server's own after step, which gives the database connection back
  HTTPRouter.RegisterInterceptor('access', @AccessLogger.Done, iaAfter);
  RegisterVisitorPart('chat', '/p');
  RegisterVisitorPart('chat', '/m');
  RegisterVisitorPart('chat', '/u');
  RegisterVisitorPart('chat', '/dm');
  RegisterVisitorPart('chat', '/admin');
  RegisterVisitorPart('chat', '/signin');
  RegisterVisitorPart('chat', '/');
  RegisterVisitorPart('api', '/api');
  RegisterVisitorPart('static', '/static');
  RegisterVisitorPart('static', '/site');
  RegisterVisitorPart('static', '/f');
  RegisterStorageFolder('uploads', 'Uploads', 'data/files', 'files_dir');
  RegisterStorageFolder('site-files', 'Site files', 'data/site');
  RegisterStorageFolder('static-files', 'Static files', 'static');
  RegisterStorageTables('chat', 'Chat tables', '*');
  RegisterStorageTables('statistics', 'Statistics tables', 'visitor_days,storage_sizes');
  RegisterTable('CREATE TABLE IF NOT EXISTS visitor_days (day DATE NOT NULL, part VARCHAR(30) NOT NULL,' +
    ' requests BIGINT NOT NULL DEFAULT 0, visitors BIGINT NOT NULL DEFAULT 0, refused BIGINT NOT NULL DEFAULT 0,' + ' PRIMARY KEY (day, part)) ENGINE=InnoDB');
  RegisterUpgrade('visitor-days-people', 'ALTER TABLE visitor_days ADD COLUMN people BIGINT NOT NULL DEFAULT 0');
  RegisterTable('CREATE TABLE IF NOT EXISTS storage_sizes (name VARCHAR(40) PRIMARY KEY, caption VARCHAR(100) NOT NULL,' +
    ' kind TINYINT NOT NULL, bytes BIGINT NOT NULL, complete TINYINT NOT NULL, measured DATETIME NOT NULL) ENGINE=InnoDB');
  RegisterChore(@FlushVisitors, 1);
  {$ifndef CGI}
  RegisterChore(@MeasureStorage, 60);
  RegisterChore(@PruneAccessLogs, 60);
  InitCriticalSection(AccessLock);
  {$endif}
finalization
  Traffic.Free;
  AccessLogger.Free;
end.
