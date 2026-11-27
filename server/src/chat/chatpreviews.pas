unit ChatPreviews;

{ Fetch the first link's title, description and picture address off the
  request thread, caching it for a week. SiteFetch restricts hosts,
  redirects and size; only text/html is accepted. Completion gives the
  message a new revision. link_previews disables fetching. }

{$mode objfpc}{$H+}

interface

{ A page's own <title> as plain text, its entities read and its whitespace
  collapsed, at most MaxLen characters; '' when it has none. }
function PageTitle(const Page: string; MaxLen: integer): string;

implementation

uses
  SiteFetch, Classes, SysUtils, StrUtils, Variants, fpjson, fphttpclient, netdb, URIParser, sha1, SiteDb, SiteSql,
  ChatMessages, ChatPrivate, SiteGuard;

const
  PREVIEW_DAYS = 7;
  FETCH_CAP = 262144;
  USER_AGENT = 'Mozilla/5.0 (compatible; Exedra/1; link preview)';

type
  TPreviewJob = class(TThread)
  private
    MessageId: integer;
    Url, Hash: string;
    Got: TMemoryStream;
  protected
    procedure Execute; override;
  public
    constructor Create(AMessageId: integer; const AUrl, AHash: string);
  end;

  { ------------------------------------------------------------ the address }

{ The first web link in a message, outside its code, trailing punctuation
  taken off; '' when there is none. }
function FirstLink(const Body: string): string;
var
  Text: string;
  I, J, Start: integer;
  InFence, InTick: boolean;
begin
  Result := '';
  // code stays code: a fenced block or a backticked span is skipped whole
  Text := '';
  InFence := False;
  InTick := False;
  I := 1;
  while I <= Length(Body) do
  begin
    if (Copy(Body, I, 3) = '```') then
    begin
      InFence := not InFence;
      Inc(I, 3);
      Text := Text + ' ';
      Continue;
    end;
    if (Body[I] = '`') and not InFence then
    begin
      InTick := not InTick;
      Text := Text + ' ';
    end
    else if InFence or InTick then
      Text := Text + ' '
    else
      Text := Text + Body[I];
    Inc(I);
  end;
  Start := Pos('https://', Text);
  J := Pos('http://', Text);
  if (J > 0) and ((Start = 0) or (J < Start)) then
    Start := J;
  if Start = 0 then
    Exit;
  // a link written in Markdown has its address in parentheses
  J := Start;
  while (J <= Length(Text)) and not (Text[J] in [' ', #9, #10, #13, '<', '>', '"', '''', ')', ']', '}']) do
    Inc(J);
  Result := Copy(Text, Start, J - Start);
  while (Result <> '') and (Result[Length(Result)] in ['.', ',', ';', ':', '!', '?']) do
    SetLength(Result, Length(Result) - 1);
  if (Length(Result) > 700) or (Length(Result) < 11) then
    Result := '';
end;

{ ------------------------------------------------------------- the page }

function Utf8Of(Code: cardinal): string;
begin
  if Code < $80 then
    Result := Chr(Code)
  else if Code < $800 then
    Result := Chr($C0 or (Code shr 6)) + Chr($80 or (Code and $3F))
  else if Code < $10000 then
    Result := Chr($E0 or (Code shr 12)) + Chr($80 or ((Code shr 6) and $3F)) + Chr($80 or (Code and $3F))
  else if Code <= $10FFFF then
    Result := Chr($F0 or (Code shr 18)) + Chr($80 or ((Code shr 12) and $3F)) + Chr($80 or ((Code shr 6) and $3F)) + Chr($80 or (Code and $3F))
  else
    Result := '';
end;

{ The named and numbered entities a title or description carries, and the
  whitespace of a page collapsed to single spaces. }
function CleanText(const S: string; MaxLen: integer): string;
var
  I, J: integer;
  Name: string;
  Code: cardinal;
  Ok: boolean;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if S[I] = '&' then
    begin
      J := I + 1;
      while (J <= Length(S)) and (J - I < 10) and (S[J] <> ';') and (S[J] <> ' ') and (S[J] <> '&') do
        Inc(J);
      if (J <= Length(S)) and (S[J] = ';') then
      begin
        Name := LowerCase(Copy(S, I + 1, J - I - 1));
        Ok := True;
        if Name = 'amp' then
          Result := Result + '&'
        else if Name = 'lt' then
          Result := Result + '<'
        else if Name = 'gt' then
          Result := Result + '>'
        else if Name = 'quot' then
          Result := Result + '"'
        else if (Name = 'apos') or (Name = '#39') then
          Result := Result + ''''
        else if Name = 'nbsp' then
          Result := Result + ' '
        else if (Name = 'ndash') then
          Result := Result + Utf8Of($2013)
        else if (Name = 'mdash') then
          Result := Result + Utf8Of($2014)
        else if (Name = 'hellip') then
          Result := Result + Utf8Of($2026)
        else if (Length(Name) > 1) and (Name[1] = '#') then
        begin
          if Name[2] = 'x' then
            Code := StrToIntDef('$' + Copy(Name, 3, MaxInt), 0)
          else
            Code := StrToIntDef(Copy(Name, 2, MaxInt), 0);
          if Code >= 32 then
            Result := Result + Utf8Of(Code)
          else
            Ok := False;
        end
        else
          Ok := False;
        if Ok then
        begin
          I := J + 1;
          Continue;
        end;
      end;
    end;
    if S[I] in [#9, #10, #13] then
      Result := Result + ' '
    else
      Result := Result + S[I];
    Inc(I);
  end;
  while Pos('  ', Result) > 0 do
    Result := StringReplace(Result, '  ', ' ', [rfReplaceAll]);
  Result := Trim(Result);
  if Length(Result) > MaxLen then
  begin
    SetLength(Result, MaxLen);
    // not in the middle of a UTF-8 character
    while (Result <> '') and (Ord(Result[Length(Result)]) and $C0 = $80) do
      SetLength(Result, Length(Result) - 1);
    if Result <> '' then
      SetLength(Result, Length(Result) - 1);
    Result := Trim(Result) + Utf8Of($2026);
  end;
end;

{ the value of one attribute of a tag's text, '' when it is not there }
function AttrOf(const Tag, Attr: string): string;
var
  Low: string;
  P, E: integer;
  Q: char;
begin
  Result := '';
  Low := LowerCase(Tag);
  P := Pos(' ' + Attr + '=', Low);
  if P = 0 then
    P := Pos(#10 + Attr + '=', Low);
  if P = 0 then
    Exit;
  P := P + Length(Attr) + 2;
  while (P <= Length(Tag)) and (Tag[P] = ' ') do
    Inc(P);
  if P > Length(Tag) then
    Exit;
  if Tag[P] in ['"', ''''] then
  begin
    Q := Tag[P];
    Inc(P);
    E := P;
    while (E <= Length(Tag)) and (Tag[E] <> Q) do
      Inc(E);
  end
  else
  begin
    E := P;
    while (E <= Length(Tag)) and not (Tag[E] in [' ', '>', '/', #9, #10, #13]) do
      Inc(E);
  end;
  Result := Copy(Tag, P, E - P);
end;

function PageTitle(const Page: string; MaxLen: integer): string;
var
  Low: string;
  P, E: integer;
begin
  Result := '';
  Low := LowerCase(Page);
  P := Pos('<title', Low);
  if P = 0 then
    Exit;
  P := PosEx('>', Low, P);
  E := PosEx('</title', Low, P + 1);
  if (P > 0) and (E > P) then
    Result := CleanText(Copy(Page, P + 1, E - P - 1), MaxLen);
end;

{ What the page says about itself: Open Graph first, the plain tags after. }
procedure ReadPage(const Page, PageUrl: string; out Title, Descr, Image, Site: string);
var
  Low, Tag, Key, Content, OgTitle, OgDescr, MetaDescr: string;
  P, E: integer;
  U: TURI;
begin
  Title := '';
  Descr := '';
  Image := '';
  Site := '';
  OgTitle := '';
  OgDescr := '';
  MetaDescr := '';
  Low := LowerCase(Page);
  Title := PageTitle(Page, 200);
  P := Pos('<meta', Low);
  while P > 0 do
  begin
    E := PosEx('>', Low, P);
    if E = 0 then
      Break;
    Tag := Copy(Page, P, E - P + 1);
    Key := LowerCase(AttrOf(Tag, 'property'));
    if Key = '' then
      Key := LowerCase(AttrOf(Tag, 'name'));
    Content := AttrOf(Tag, 'content');
    if Content <> '' then
    begin
      if (Key = 'og:title') or (Key = 'twitter:title') then
        OgTitle := CleanText(Content, 200)
      else if (Key = 'og:description') or (Key = 'twitter:description') then
        OgDescr := CleanText(Content, 400)
      else if Key = 'description' then
        MetaDescr := CleanText(Content, 400)
      else if ((Key = 'og:image') or (Key = 'og:image:url') or (Key = 'twitter:image')) and (Image = '') then
        Image := Trim(Content)
      else if Key = 'og:site_name' then
        Site := CleanText(Content, 80);
    end;
    P := PosEx('<meta', Low, E);
  end;
  if OgTitle <> '' then
    Title := OgTitle;
  if OgDescr <> '' then
    Descr := OgDescr
  else
    Descr := MetaDescr;
  U := ParseURI(PageUrl);
  if Site = '' then
    Site := U.Host;
  // the picture's address made absolute, and only a web one is kept
  if Image.StartsWith('//') then
    Image := U.Protocol + ':' + Image
  else if Image.StartsWith('/') then
    Image := U.Protocol + '://' + U.Host + Image
  else if not (Image.StartsWith('http://') or Image.StartsWith('https://')) then
    Image := '';
  if (Length(Image) > 700) or (Pos('"', Image) > 0) or (Pos(' ', Image) > 0) then
    Image := '';
  if Length(Title) < 2 then
    Title := '';
end;

{ -------------------------------------------------------------- the job }

const
  { Pages fetched at one time, over the whole site. }
  MAX_JOBS = 8;

var
  Running: longint = 0;

{ Takes a place for one more fetch without waiting; False when all are taken. }
function PlaceFree: boolean;
begin
  Result := InterlockedIncrement(Running) <= MAX_JOBS;
  if not Result then
    InterlockedDecrement(Running);
end;

{ Starts the fetch in the place PlaceFree gave, and gives it back if the thread cannot start. }
procedure StartJob(AMessageId: integer; const AUrl, AHash: string);
begin
  try
    TPreviewJob.Create(AMessageId, AUrl, AHash);
  except
    on E: Exception do
    begin
      InterlockedDecrement(Running);
      Log('Preview: ' + E.Message);
    end;
  end;
end;

constructor TPreviewJob.Create(AMessageId: integer; const AUrl, AHash: string);
begin
  MessageId := AMessageId;
  Url := AUrl;
  Hash := AHash;
  FreeOnTerminate := True;
  inherited Create(False);
end;

procedure TPreviewJob.Execute;
var
  Dog: TWatchdog;
  Page, Problem, Title, Descr, Image, Site: string;
  Fine: boolean;
begin
  Got := TMemoryStream.Create;
  try
    try
      Fine := False;
      Title := '';
      Descr := '';
      Image := '';
      Site := '';
      // SiteFetch reads it: a public address only, checked again once
      // connected and at every redirect, the first FETCH_CAP bytes, and no
      // longer than a quarter of a minute however slowly they come
      Dog := TWatchdog.Create;
      try
        if not SafeGetTo(Dog, Url, USER_AGENT, Got, FETCH_CAP, 8, GetTickCount64 + 15000, Problem) and (Got.Size = 0) then
          Log('Preview of ' + Copy(Url, 1, 80) + ': ' + Problem);
      finally
        Dog.Terminate;
        Dog.WaitFor;
        Dog.Free;
      end;
      // the head is at the front: what came is read, cut short or not
      if Got.Size > 0 then
      begin
        SetLength(Page, Got.Size);
        Got.Position := 0;
        Got.ReadBuffer(Page[1], Got.Size);
        ReadPage(Page, Url, Title, Descr, Image, Site);
        Fine := Title <> '';
      end;
      if Restoring then
        Exit;
      CheckConnection;
      try
        Exec('UPDATE previews SET title = :t, descr = :d, image = :i, site = :s, ok = :o, fetched = NOW() WHERE url_hash = :h',
          [Title, Descr, Image, Site, Ord(Fine), Hash]);
        // a private message's job carries its number below zero
        if Fine and (MessageId < 0) then
          DmChanged(-MessageId)
        else if Fine then
          Touch(MessageId);
      finally
        DoneConnection;
      end;
    except
      on E: Exception do
        Log('Preview: ' + E.Message);
    end;
  finally
    Got.Free;
    InterlockedDecrement(Running);
  end;
end;

{ ------------------------------------------------------------- the hooks }

{ A message posted or edited: its first link noted, fetched when it is new
  to the site or a week old. }
procedure NoteLinks(MessageId: integer; const Body: string);
var
  Url, Hash: string;
  Fresh: boolean;
begin
  Url := '';
  if SettingInt('link_previews', 1) = 1 then
    Url := FirstLink(Body);
  if (Url = '') or not PublicWebAddress(Url) then
  begin
    Exec('DELETE FROM message_previews WHERE message_id = :m', [MessageId]);
    Exit;
  end;
  Hash := SHA1Print(SHA1String(Url));
  Exec('INSERT INTO message_previews (message_id, url_hash) VALUES (:m, :h)' + SqlOnConflict('message_id', 'url_hash = ' + SqlNew('url_hash')), [MessageId, Hash]);
  Fresh := IntValue('SELECT COUNT(*) FROM previews WHERE url_hash = :h AND fetched > ' + SqlAgo(IntToStr(PREVIEW_DAYS), suDay), [Hash]) > 0;
  if Fresh then
    Exit;
  // every place taken: this message goes without, and the address is not marked as tried
  {$ifndef CGI}
  if not PlaceFree then
    Exit;
  {$endif}
  Exec('INSERT INTO previews (url_hash, url, title, descr, image, site, ok, fetched) VALUES (:h, :u, '''', '''', '''', '''', 0, NOW())' +
    SqlOnConflict('url_hash', 'url = ' + SqlNew('url') + ', ok = 0, fetched = NOW()'), [Hash, Url]);
  // a CGI program has no threads (no cthreads in its build): no previews there
  {$ifndef CGI}
  StartJob(MessageId, Url, Hash);
  {$endif}
end;

{ The previews of a page of messages, put on each as "preview". }
procedure AttachPreviews(List: TJSONArray; const Ids: string);
var
  I: integer;
  Item: TJSONObject;
begin
  // Ids is a list of numbers the caller read from the database
  with Query('SELECT mp.message_id, p.url, p.title, p.descr, p.image, p.site FROM message_previews mp' +
      ' JOIN previews p ON p.url_hash = mp.url_hash WHERE p.ok = 1 AND mp.message_id IN (' + Ids + ')', []) do
  try
    while not EOF do
    begin
      for I := 0 to List.Count - 1 do
      begin
        Item := List.Objects[I];
        if Item.Integers['id'] = Fields[0].AsInteger then
          Item.Add('preview', TJSONObject.Create(['url', Fields[1].AsString, 'title', Fields[2].AsString, 'description', Fields[3].AsString,
            'image', Fields[4].AsString, 'site', Fields[5].AsString]));
      end;
      Next;
    end;
  finally
    Free;
  end;
end;

{ An unlocked private message sent or written again: its first link noted
  and fetched like a channel message's.  The job is given the message's
  number below zero, so it knows whom to tell when the page has come. }
procedure NoteDmLinks(DmId: integer; const Text: string);
var
  Url, Hash: string;
begin
  Url := '';
  if SettingInt('link_previews', 1) = 1 then
    Url := FirstLink(Text);
  if (Url = '') or not PublicWebAddress(Url) then
  begin
    Exec('DELETE FROM dm_previews WHERE dm_id = :m', [DmId]);
    Exit;
  end;
  Hash := SHA1Print(SHA1String(Url));
  Exec('INSERT INTO dm_previews (dm_id, url_hash) VALUES (:m, :h)' + SqlOnConflict('dm_id', 'url_hash = ' + SqlNew('url_hash')), [DmId, Hash]);
  if IntValue('SELECT COUNT(*) FROM previews WHERE url_hash = :h AND fetched > ' + SqlAgo(IntToStr(PREVIEW_DAYS), suDay), [Hash]) > 0 then
    Exit;
  {$ifndef CGI}
  if not PlaceFree then
    Exit;
  {$endif}
  Exec('INSERT INTO previews (url_hash, url, title, descr, image, site, ok, fetched) VALUES (:h, :u, '''', '''', '''', '''', 0, NOW())' +
    SqlOnConflict('url_hash', 'url = ' + SqlNew('url') + ', ok = 0, fetched = NOW()'), [Hash, Url]);
  {$ifndef CGI}
  StartJob(-DmId, Url, Hash);
  {$endif}
end;

{ The previews of a page of private messages, put on each as "preview". }
procedure AttachDmPreviews(List: TJSONArray; const Ids: string);
var
  I: integer;
  Item: TJSONObject;
begin
  // Ids is a list of numbers the caller read from the database
  with Query('SELECT mp.dm_id, p.url, p.title, p.descr, p.image, p.site FROM dm_previews mp' +
      ' JOIN previews p ON p.url_hash = mp.url_hash WHERE p.ok = 1 AND mp.dm_id IN (' + Ids + ')', []) do
  try
    while not EOF do
    begin
      for I := 0 to List.Count - 1 do
      begin
        Item := List.Objects[I];
        // a message locked since has no preview to show
        if (Item.Integers['id'] = Fields[0].AsInteger) and (Item.Strings['iv'] = '') then
          Item.Add('preview', TJSONObject.Create(['url', Fields[1].AsString, 'title', Fields[2].AsString, 'description', Fields[3].AsString,
            'image', Fields[4].AsString, 'site', Fields[5].AsString]));
      end;
      Next;
    end;
  finally
    Free;
  end;
end;

procedure ForgetOldPreviews;
begin
  Exec('DELETE FROM dm_previews WHERE NOT EXISTS (SELECT 1 FROM dms d WHERE d.id = dm_previews.dm_id)', []);
  Exec('DELETE FROM previews WHERE fetched < ' + SqlAgo('60', suDay), []);
end;

initialization
  RegisterTable('CREATE TABLE IF NOT EXISTS previews (' + ' url_hash CHAR(40) PRIMARY KEY, url VARCHAR(700) NOT NULL,' +
    ' title VARCHAR(300) NOT NULL DEFAULT '''', descr VARCHAR(600) NOT NULL DEFAULT '''', image VARCHAR(700) NOT NULL DEFAULT '''',' +
    ' site VARCHAR(120) NOT NULL DEFAULT '''', ok TINYINT NOT NULL DEFAULT 0, fetched DATETIME NULL, INDEX (fetched))');
  RegisterTable('CREATE TABLE IF NOT EXISTS message_previews (' + ' message_id INT PRIMARY KEY, url_hash CHAR(40) NOT NULL, INDEX (url_hash))');
  RegisterSetting('link_previews', 'Show a title and picture for the first link in a message', '1', 'yesno', 'Chat');
  RegisterTable('CREATE TABLE IF NOT EXISTS dm_previews (' + ' dm_id INT PRIMARY KEY, url_hash CHAR(40) NOT NULL, INDEX (url_hash))');
  DmTextHook := @NoteDmLinks;
  DmLoadHook := @AttachDmPreviews;
  RegisterMessageHook(@NoteLinks);
  RegisterLoadHook(@AttachPreviews);
  RegisterChore(@ForgetOldPreviews, 24 * 60);
end.
