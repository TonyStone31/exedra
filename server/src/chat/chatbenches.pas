unit ChatBenches;

{ Benches are channels for pages, followed separately from normal channels.
  The corner chat reads public messages; posting needs an account. An
  external page must carry the embed script before its bench can open. See
  docs/API.md for the requests and docs/MODULES.md for page kinds. }

{$mode objfpc}{$H+}

interface

uses
  httpdefs, SiteUsers, ChatRooms;

type
  { What a page of some kind is called and where it lives on this site, for
    the bench opened for it; False when there is no such page. }
  TPageLookup = function(const Key: string; out Title, Url: string): boolean;
  { The one key a page is known by, when several spell the same page (a
    wiki page in each of its languages); '' when it is no page's. }
  TPageKey = function(const Key: string): string;
  { Makes the room for a new bench and answers its number, or 0 with why
    not.  A site's own unit may take this over to keep more about its
    benches than the chat does. }
  TBenchMaker = function(const Me: TMember; const Slug, Title, Address, Summary: string; out Refused: string): integer;
  { The room a bench's row leads to today, for a site that merges benches. }
  TBenchResolve = function(RoomId: integer): integer;

var
  BenchMaker: TBenchMaker = nil;
  BenchResolve: TBenchResolve = nil;

{ A kind of page that can have a bench: 'wiki', 'site', or a module's own.
  Normal may be nil when a page has one key only. }
procedure RegisterPageKind(const Kind: string; Lookup: TPageLookup; Normal: TPageKey = nil);
{ The public channel the corner chat opens on a page without a bench of its
  own: the first one anybody may talk in. }
function TalkChannel: string;
{ The bench a page has, by its kind and key; Id 0 when none. }
function PageBenchRoom(const Kind, Key: string): TRoom;
{ Opens the bench for a page, or finds the one it has: the room back, or Id
  0 with the status and words to answer. }
function OpenPageBench(const Me: TMember; const Kind, Key: string; out Code: integer; out Problem: string): TRoom;
{ Whether this member may open a bench. }
function MayOpenBench(const Me: TMember): boolean;
{ The page a bench was opened for, with the corner chat asked to open. }
function PageBenchReturn(const Kind, Key: string): string;
{ A room anyone may read: there, not private, not archived. }
function OpenToAll(const Room: TRoom): boolean;
{ The corner chat's spot on a page, for a template's live value: the open
  channel it falls back to; the page's kind and key when a bench can be
  opened for it, its bench when it has one, and whether this reader may
  open one (yes, signin, or no).  Kind '' for a page that is no one thing
  (the home page, a list).  ARequest nil: nobody signed in. }
function LiveStrip(ARequest: TRequest; const Kind, Key: string): string;

implementation

uses
  SysUtils, StrUtils, Classes, Variants, fpjson, httproute, SiteDb, SiteRoles, SiteGuard, SiteAdmin,
  SiteWords, WebPages, SiteFetch, SiteSql, SiteParts, SiteMarkup, ChatPreviews;

const
  LIVE_SITE = 8;
  LIVE_ROOM = 5;
  CACHE_SECONDS = 15;

type
  TPageKind = record
    Kind: string;
    Lookup: TPageLookup;
    Normal: TPageKey;
  end;

var
  SiteCache: string;
  SiteCacheMade: TDateTime;
  CacheLock: TRTLCriticalSection;
  PageKinds: array of TPageKind;

procedure RegisterPageKind(const Kind: string; Lookup: TPageLookup; Normal: TPageKey);
begin
  SetLength(PageKinds, Length(PageKinds) + 1);
  PageKinds[High(PageKinds)].Kind := Kind;
  PageKinds[High(PageKinds)].Lookup := Lookup;
  PageKinds[High(PageKinds)].Normal := Normal;
end;

function PageLookup(const Kind: string): TPageLookup;
var
  I: integer;
begin
  Result := nil;
  for I := 0 to High(PageKinds) do
    if PageKinds[I].Kind = Kind then
      Exit(PageKinds[I].Lookup);
end;

{ The key a page's bench is kept under. }
function NormalKey(const Kind, Key: string): string;
var
  I: integer;
begin
  Result := Key;
  for I := 0 to High(PageKinds) do
    if (PageKinds[I].Kind = Kind) and Assigned(PageKinds[I].Normal) then
      Exit(PageKinds[I].Normal(Key));
end;

function MayOpenBench(const Me: TMember): boolean;
begin
  Result := (Me.Id > 0) and Can(Me, 'add-bench') and Me.Verified and not Me.Banned;
end;

function TalkChannel: string;
begin
  Result := VarToStr(Value('SELECT slug FROM rooms WHERE kind = ''channel'' AND private = 0 AND archived = 0 AND post_policy = ''all'' ORDER BY id LIMIT 1', []));
  if Result = '' then
    Result := Setting('start_room', 'lobby');
end;

function OpenToAll(const Room: TRoom): boolean;
begin
  Result := (Room.Id > 0) and not Room.Private and not Room.Archived;
end;

function Here(RoomId: integer): integer;
begin
  if RoomId = 0 then
    Result := IntValue('SELECT COUNT(*) FROM presence WHERE seen > ' + SqlAgo('2', suMinute), [])
  else
    Result := IntValue('SELECT COUNT(*) FROM presence WHERE room_id = :r AND seen > ' + SqlAgo('2', suMinute), [RoomId]);
end;

function LiveJson(RoomId, Count: integer): string;
var
  Items: TJSONArray;
  Answer: TJSONObject;
  SQL: string;
begin
  SQL := 'SELECT m.id, r.slug, r.title, r.kind, COALESCE(u.name, m.author), u.avatar, ' + IsoTime('m.created') + ', m.body' +
    ' FROM messages m JOIN rooms r ON r.id = m.room_id LEFT JOIN users u ON u.id = m.user_id' +
    ' WHERE m.deleted = 0 AND r.private = 0 AND r.archived = 0 AND COALESCE(u.banned, 0) = 0';
  if RoomId > 0 then
    SQL := SQL + ' AND m.room_id = ' + IntToStr(RoomId)
  else
    // the site's own bulletins are not talk
    SQL := SQL + ' AND m.created > ' + SqlAgo('30', suDay);
  SQL := SQL + ' ORDER BY m.id DESC LIMIT ' + IntToStr(Count);
  Items := TJSONArray.Create;
  Answer := TJSONObject.Create(['messages', Items, 'here', Here(RoomId)]);
  if RoomId = 0 then
    Answer.Add('talk', TalkChannel);
  try
    with Query(SQL, []) do
    try
      while not EOF do
      begin
        if Trim(PlainLine(Fields[7].AsString)) <> '' then
          Items.Add(TJSONObject.Create(['id', Fields[0].AsInteger, 'room', Fields[1].AsString, 'title', Fields[2].AsString, 'kind',
            Fields[3].AsString, 'name', Fields[4].AsString, 'avatar', AvatarUrl(Fields[5].AsString), 'at', Fields[6].AsString, 'text', PlainLine(Fields[7].AsString)]));
        Next;
      end;
    finally
      Free;
    end;
    Result := Answer.AsJSON;
  finally
    Answer.Free;
  end;
end;

procedure SendLive(AResponse: TResponse; const Json: string);
begin
  AResponse.ContentType := 'application/json; charset=utf-8';
  AResponse.SetCustomHeader('Cache-Control', 'no-store');
  AResponse.Content := Json;
  AResponse.SendContent;
end;

{ GET /api/live[?room=slug] }
procedure ShowLive(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Room: TRoom;
  Slug, Json: string;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  Slug := ARequest.QueryFields.Values['room'];
  if Slug <> '' then
  begin
    Room := FindRoom(Slug);
    if (Room.Id = 0) or Room.Private or Room.Archived or not CanRead(Me, Room) then
    begin
      SendText(AResponse, 404, Say('No channel by that name.'));
      Exit;
    end;
    SendLive(AResponse, LiveJson(Room.Id, LIVE_ROOM));
    Exit;
  end;
  if not Can(Me, 'view-room') then
  begin
    SendText(AResponse, 404, Say('No channel by that name.'));
    Exit;
  end;
  EnterCriticalSection(CacheLock);
  try
    if (SiteCache <> '') and (Now - SiteCacheMade < CACHE_SECONDS / 86400) then
      Json := SiteCache
    else
      Json := '';
  finally
    LeaveCriticalSection(CacheLock);
  end;
  if Json = '' then
  begin
    Json := LiveJson(0, LIVE_SITE);
    EnterCriticalSection(CacheLock);
    try
      SiteCache := Json;
      SiteCacheMade := Now;
    finally
      LeaveCriticalSection(CacheLock);
    end;
  end;
  SendLive(AResponse, Json);
end;

{ The room a new bench gets when no unit took the making over: a channel
  of kind 'bench' anyone may talk in, followed by who opened it. }
function MakeBench(const Me: TMember; const Slug, Title, Address, Summary: string; out Refused: string): integer;
begin
  if Assigned(BenchMaker) then
    Exit(BenchMaker(Me, Slug, Title, Address, Summary, Refused));
  Refused := '';
  Result := CreateRoom(Slug, 'bench', Title, Summary, 0, 'all');
  Follow(Me.Id, Result);
end;

function PageBenchRoom(const Kind, Key: string): TRoom;
var
  RoomId: integer;
begin
  RoomId := 0;
  if (Kind <> '') and (NormalKey(Kind, Key) <> '') then
    RoomId := IntValue('SELECT room_id FROM page_benches WHERE kind = :k AND pagekey = :p', [Kind, NormalKey(Kind, Key)]);
  if (RoomId > 0) and Assigned(BenchResolve) then
    RoomId := BenchResolve(RoomId);
  Result := RoomById(RoomId);
end;

{ Text cut to Limit characters, for a room's title and topic. }
function Short(const Text: string; Limit: integer): string;
begin
  Result := UTF8Encode(Copy(UTF8Decode(Trim(Text)), 1, Limit));
end;

{ The address for a page's bench: its kind and the letters of its key; one
  already taken gets a number. }
function PageBenchSlug(const Kind, Key: string): string;
var
  I: integer;
  Base: string;
begin
  Base := Kind + '-';
  for I := 1 to Length(Key) do
    if Key[I] in ['a'..'z', 'A'..'Z', '0'..'9'] then
      Base := Base + LowerCase(Key[I])
    else if Base[Length(Base)] <> '-' then
      Base := Base + '-';
  Base := TrimRightSet(Copy(TrimRightSet(Base, ['-']), 1, 36), ['-']);
  Result := Base;
  I := 1;
  while (not ValidSlug(Result)) or (FindRoom(Result).Id > 0) do
  begin
    Inc(I);
    if I > 50 then
      Exit('');
    Result := Base + '-' + IntToStr(I);
  end;
end;

{ Opens the bench for a page, or finds the one it has. }
function OpenPageBench(const Me: TMember; const Kind, Key: string; out Code: integer; out Problem: string): TRoom;
var
  Lookup: TPageLookup;
  PageKey, BenchSlug, Refused, PageTitle, Url: string;
  RoomId: integer;
begin
  Result := RoomById(0);
  Code := 200;
  Problem := '';
  if not MayOpenBench(Me) then
  begin
    Code := 403;
    Problem := Say('This account cannot open a bench.');
    Exit;
  end;
  Lookup := PageLookup(Kind);
  PageKey := NormalKey(Kind, Key);
  if (Lookup = nil) or (PageKey = '') or (Length(PageKey) > 190) or not Lookup(PageKey, PageTitle, Url) then
  begin
    Code := 404;
    Problem := Say('There is no page by this name yet.');
    Exit;
  end;
  // a page of this site is named by its path: the bench keeps its whole address
  if Url.StartsWith('/') then
    Url := ExcludeTrailingPathDelimiter(Setting('url', '')) + Url;
  // one at a time, so two clicks on the same page share one bench, and two
  // pages whose keys spell the same address get one each
  if IntValue('SELECT ' + SqlLock('''page-bench''', 10), []) <> 1 then
  begin
    Code := 503;
    Problem := Say('A bench could not be opened for this page.');
    Exit;
  end;
  try
    Result := PageBenchRoom(Kind, PageKey);
    if (Result.Id > 0) and not OpenToAll(Result) then
    begin
      Result := RoomById(0);
      Code := 409;
      Problem := Say('The bench for this page is closed.');
      Exit;
    end;
    if Result.Id > 0 then
      Exit;
    BenchSlug := PageBenchSlug(Kind, PageKey);
    if BenchSlug = '' then
    begin
      Code := 409;
      Problem := Say('A bench could not be opened for this page.');
      Exit;
    end;
    // the room, the opener following it and the page's link to it, all or none
    Exec('START TRANSACTION', []);
    try
      RoomId := MakeBench(Me, BenchSlug, Short(PageTitle, 100), Url, Short(Format(Say('Talk about %s'), [PageTitle]), 500), Refused);
      if RoomId = 0 then
      begin
        Exec('ROLLBACK', []);
        Code := 409;
        // the maker's own reason, when it gave one
        Problem := Refused;
        if Problem = '' then
          Problem := Say('A bench could not be opened for this page.');
        Exit;
      end;
      Exec('INSERT INTO page_benches (kind, pagekey, room_id) VALUES (:k, :p, :r)', [Kind, PageKey, RoomId]);
      Exec('COMMIT', []);
    except
      Exec('ROLLBACK', []);
      raise;
    end;
    Result := RoomById(RoomId);
  finally
    IntValue('SELECT ' + SqlUnlock('''page-bench'''), []);
  end;
end;

function PageBenchReturn(const Kind, Key: string): string;
var
  Lookup: TPageLookup;
  Title, Url: string;
begin
  Result := '/';
  Lookup := PageLookup(Kind);
  if (Lookup <> nil) and Lookup(NormalKey(Kind, Key), Title, Url) then
    Result := Url;
  if Pos('?', Result) > 0 then
    Result := Result + '&bench=open'
  else
    Result := Result + '?bench=open';
end;

{ POST /page-bench  kind=&key=  (the bubble): room and url, the url being
  the page with the bubble asked to open }
procedure StartPageBench(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Room: TRoom;
  Kind, Key, Problem: string;
  Code: integer;
begin
  CheckConnection;
  if FromAnotherSite(ARequest) then
  begin
    SendText(AResponse, 403, Say('Send this from a page of this site.'));
    Exit;
  end;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  Kind := ARequest.ContentFields.Values['kind'];
  Key := ARequest.ContentFields.Values['key'];
  Room := OpenPageBench(Me, Kind, Key, Code, Problem);
  if Room.Id = 0 then
  begin
    SendText(AResponse, Code, Problem);
    Exit;
  end;
  AResponse.SetCustomHeader('Cache-Control', 'no-store');
  SendJSON(AResponse, TJSONObject.Create(['room', Room.Slug, 'url', PageBenchReturn(Kind, Key)]));
end;

function LiveStrip(ARequest: TRequest; const Kind, Key: string): string;
var
  Room: TRoom;
  Lookup: TPageLookup;
  Title, Url, May: string;
begin
  // the corner chat is the chat's: none while the chat is off
  if not PartOn('chat') then
    Exit('');
  Result := '<aside class="live-strip" data-live-strip data-live-default="' + E(TalkChannel) + '"';
  if Kind <> '' then
  begin
    Room := PageBenchRoom(Kind, Key);
    Lookup := PageLookup(Kind);
    if OpenToAll(Room) then
      Result := Result + ' data-live-room="' + E(Room.Slug) + '"'
    else if (Room.Id = 0) and (Lookup <> nil) and Lookup(NormalKey(Kind, Key), Title, Url) then
    begin
      // a page a bench can be opened for, by a member who may, or after signing in
      May := 'signin';
      if (ARequest <> nil) and (CurrentMember(ARequest).Id > 0) then
        if MayOpenBench(CurrentMember(ARequest)) then
          May := 'yes'
        else
          May := 'no';
      Result := Result + ' data-live-page="' + E(Kind + ':' + Key) + '" data-live-title="' + E(Title) + '" data-live-can-bench="' + May + '"';
    end;
  end;
  Result := Result + ' hidden aria-label="' + E(Say('Live in the chat')) + '"></aside>';
end;

{ ---- the corner chat on other sites ---- }

const
  EMBED_PAGE_CAP = 512 * 1024;
  EMBED_SECONDS = 15;
  EMBED_AGENT = 'Mozilla/5.0 (compatible; Exedra/1; bench check)';

type
  TEmbedCors = class
    procedure Note(ARequest: TRequest; AResponse: TResponse; var aContinue: boolean);
  end;

var
  EmbedCors: TEmbedCors;

{ A page's key for its bench: lowercase host and its path, without scheme,
  query or fragment, index.html dropped; '' for anything but a plain http or
  https address. }
function EmbedKey(const Url: string): string;
var
  U, Host, Path: string;
  P: integer;
  C: char;
begin
  Result := '';
  U := Trim(Url);
  if StartsText('https://', U) then
    Delete(U, 1, 8)
  else if StartsText('http://', U) then
    Delete(U, 1, 7)
  else
    Exit;
  P := Pos('#', U);
  if P > 0 then
    U := Copy(U, 1, P - 1);
  P := Pos('?', U);
  if P > 0 then
    U := Copy(U, 1, P - 1);
  P := Pos('/', U);
  if P = 0 then
  begin
    Host := U;
    Path := '/';
  end
  else
  begin
    Host := Copy(U, 1, P - 1);
    Path := Copy(U, P, MaxInt);
  end;
  Host := LowerCase(Host);
  if (Host = '') or (Pos('@', Host) > 0) or (Pos('\', U) > 0) then
    Exit;
  if EndsText('/index.html', Path) or EndsText('/index.htm', Path) then
    Path := Copy(Path, 1, LastDelimiter('/', Path));
  for C in Host + Path do
    if C <= ' ' then
      Exit;
  if Length(Host + Path) <= 190 then
    Result := Host + Path;
end;

function SiteLookup(const Key: string; out Title, Url: string): boolean;
begin
  Title := '';
  Url := '';
  with Query('SELECT title, url FROM embed_pages WHERE pagekey = :k', [Key]) do
  try
    Result := not EOF;
    if Result then
    begin
      Title := Fields[0].AsString;
      Url := Fields[1].AsString;
    end;
  finally
    Free;
  end;
end;

{ The bench a page on another site has, if any, for embed.js. }
procedure ShowEmbedPage(ARequest: TRequest; AResponse: TResponse);
var
  Key, Title, Url, Slug: string;
  Room: TRoom;
begin
  CheckConnection;
  Key := EmbedKey(ARequest.QueryFields.Values['url']);
  Slug := '';
  Title := '';
  if Key <> '' then
  begin
    Room := PageBenchRoom('site', Key);
    if OpenToAll(Room) then
      Slug := Room.Slug;
    SiteLookup(Key, Title, Url);
  end;
  AResponse.SetCustomHeader('Cache-Control', 'no-store');
  SendJSON(AResponse, TJSONObject.Create(['room', Slug, 'title', Title, 'talk', TalkChannel]));
end;

{ The address this site is reached at, for the line a page must carry. }
function EmbedMark(ARequest: TRequest): string;
var
  Site: string;
begin
  Site := Setting('url', '');
  if Site = '' then
    Site := 'https://' + ARequest.Host;
  Site := ExcludeTrailingPathDelimiter(Site);
  if StartsText('https://', Site) then
    Delete(Site, 1, 8)
  else if StartsText('http://', Site) then
    Delete(Site, 1, 7);
  Result := LowerCase(Site) + '/embed.js';
end;

{ Whether a page carries the line: a script tag whose address is this
  site's embed.js.  The address merely written on the page (in a post, in a
  search that echoes it) does not count.  Lower is the page in lower case. }
function CarriesLine(const Lower, Mark: string): boolean;
var
  P, Tag: integer;
begin
  Result := False;
  P := Pos(Mark, Lower);
  while (P > 0) and not Result do
  begin
    // the tag this address sits in: the last < before it, with no > between
    Tag := RPosEx('<', Lower, P);
    Result := (Tag > 0) and (Copy(Lower, Tag, 7) = '<script') and (PosEx('>', Lower, Tag) > P);
    P := PosEx(Mark, Lower, P + 1);
  end;
end;

{ The start of both /embed/bench requests: False once answered, for an
  address that is no page's and for a page that has its bench already. }
function EmbedPageAsked(AResponse: TResponse; const Url: string; out Key: string): boolean;
var
  Room: TRoom;
begin
  Result := False;
  Key := EmbedKey(Url);
  if Key = '' then
  begin
    SendText(AResponse, 400, Say('That is not the address of a web page.'));
    Exit;
  end;
  Room := PageBenchRoom('site', Key);
  if OpenToAll(Room) then
    SeeOther(AResponse, '/p/' + Room.Slug)
  else
    Result := True;
end;

{ GET /embed/bench?url=: goes to the bench a page on another site has.  When
  it has none, asks a member whether to open one: following a link makes
  nothing. }
procedure AskEmbedBench(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Url, Key: string;
begin
  CheckConnection;
  Url := Trim(ARequest.QueryFields.Values['url']);
  if not EmbedPageAsked(AResponse, Url, Key) then
    Exit;
  Me := CurrentMember(ARequest);
  if Me.Id = 0 then
    SeeOther(AResponse, '/signin?return=' + HTTPEncode('/embed/bench?url=' + HTTPEncode(Url)))
  else if not MayOpenBench(Me) then
    SendText(AResponse, 403, Say('This account cannot open a bench.'))
  else
    SendPage(AResponse, PartPage(ARequest, Me, Say('Open a bench for this page'), '<h1>' + E(Say('Open a bench for this page')) +
      '</h1><p>' + E(Url) + '</p><form method="post" action="/embed/bench"><input type="hidden" name="url" value="' + E(Url) + '"><p>' +
      E(Say('Nobody has opened a bench for this page yet.')) + ' <button type="submit">' + E(Say('Open a bench for this page')) + '</button></p></form>'));
end;

{ POST /embed/bench  url=: opens the bench for a page on another site, after
  seeing that page carry the line, and goes to it. }
procedure OpenEmbedBench(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Url, Key, Problem, Title, Mark, Plain: string;
  C: char;
  Body: rawbytestring;
  Room: TRoom;
  Code: integer;
  Dog: TWatchdog;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  Url := Trim(ARequest.ContentFields.Values['url']);
  if not EmbedPageAsked(AResponse, Url, Key) then
    Exit;
  if not MayOpenBench(Me) then
  begin
    SendText(AResponse, 403, Say('This account cannot open a bench.'));
    Exit;
  end;
  Problem := '';
  Plain := Url;
  for C in ['?', '#'] do
    if Pos(C, Plain) > 0 then
      Plain := Copy(Plain, 1, Pos(C, Plain) - 1);
  Dog := TWatchdog.Create;
  try
    // the page as its key names it: what follows a ? is not part of the page a bench is for
    Body := SafeGet(Dog, Plain, EMBED_AGENT, EMBED_PAGE_CAP, EMBED_SECONDS, GetTickCount64 + EMBED_SECONDS * 1000, Problem);
  finally
    Dog.Terminate;
    Dog.WaitFor;
    Dog.Free;
  end;
  if Problem <> '' then
  begin
    SendText(AResponse, 502, Format(Say('The page could not be read: %s'), [Problem]));
    Exit;
  end;
  Mark := EmbedMark(ARequest);
  if not CarriesLine(LowerCase(Body), Mark) then
  begin
    SendText(AResponse, 409, Format(Say('That page does not carry the chat block (%s), so no bench is opened for it.'), [Mark]));
    Exit;
  end;
  Title := PageTitle(Body, 120);
  if Title = '' then
    Title := Key;
  Exec('INSERT INTO embed_pages (pagekey, url, title, added_by, checked) VALUES (:k, :u, :t, :m, NOW())' + SqlOnConflict('pagekey',
    'url = ' + SqlNew('url') + ', title = ' + SqlNew('title') + ', checked = NOW()'), [Key, Copy(Url, 1, 600), Title, Me.Id]);
  Room := OpenPageBench(Me, 'site', Key, Code, Problem);
  if Room.Id = 0 then
    SendText(AResponse, Code, Problem)
  else
    SeeOther(AResponse, '/p/' + Room.Slug);
end;

{ GET /embed.js: the block's script. }
procedure SendEmbedScript(ARequest: TRequest; AResponse: TResponse);
var
  F: TFileStream;
begin
  if not FileExists(FilesRoot + 'static/embed.js') then
  begin
    SendText(AResponse, 404, 'Not found');
    Exit;
  end;
  AResponse.ContentType := 'text/javascript; charset=utf-8';
  AResponse.SetCustomHeader('Cache-Control', 'public, max-age=3600');
  F := TFileStream.Create(FilesRoot + 'static/embed.js', fmOpenRead or fmShareDenyWrite);
  AResponse.ContentStream := F;
  AResponse.FreeContentStream := True;
  AResponse.ContentLength := F.Size;
  AResponse.SendContent;
end;

{ Reading the corner chat's public answers from another site: GET only, no
  cookies go with those requests, so they answer what a visitor may see. }
procedure TEmbedCors.Note(ARequest: TRequest; AResponse: TResponse; var aContinue: boolean);
begin
  aContinue := True;
  if ((ARequest.Method = 'GET') or (ARequest.Method = 'HEAD')) and (ARequest.GetFieldByName('Origin') <> '') then
    case ARequest.PathInfo of
      '/api/live', '/api/room', '/api/messages', '/api/embed/page':
        AResponse.SetCustomHeader('Access-Control-Allow-Origin', '*');
    end;
end;

{ The corner chat's spot for any template that has a live value and no page of
  its own to name. }
function LivePlain: string;
begin
  Result := LiveStrip(nil, '', '');
end;

initialization
  InitCriticalSection(CacheLock);
  RegisterTable('CREATE TABLE IF NOT EXISTS page_benches (kind VARCHAR(16) NOT NULL, pagekey VARCHAR(190) NOT NULL, room_id INT NOT NULL,' +
    ' PRIMARY KEY (kind, pagekey), INDEX(room_id)) ENGINE=InnoDB CHARACTER SET utf8mb4');
  RegisterTable('CREATE TABLE IF NOT EXISTS embed_pages (pagekey VARCHAR(190) NOT NULL PRIMARY KEY, url VARCHAR(600) NOT NULL,' +
    ' title VARCHAR(200) NOT NULL DEFAULT '''', added_by INT NOT NULL DEFAULT 0, checked DATETIME NOT NULL) ENGINE=InnoDB CHARACTER SET utf8mb4');
  RegisterPermission('add-bench', 'Open a bench for a page', 'member');
  RegisterPageKind('site', @SiteLookup);
  RegisterRequestLimit('live', 'The corner chat reading the latest talk', 120, 240, 1);
  RegisterRequestLimit('pagebench', 'Opening benches for pages', 10, 20, 60);
  LimitRoute('live', '/api/live', 'GET');
  LimitRoute('pagebench', '/page-bench', 'POST');
  LimitRoute('pagebench', '/embed/bench', 'POST');
  // the talk shown on other pages is the chat's: gone when the chat is off
  RegisterPartPaths('chat', ['/api/live', '/page-bench', '/embed/bench', '/api/embed', '/embed.js']);
  RegisterPageValue('live', @LivePlain);
  EmbedCors := TEmbedCors.Create;
  HTTPRouter.RegisterInterceptor('embed-cors', @EmbedCors.Note);
  HTTPRouter.RegisterRoute('/api/live', rmGet, @ShowLive);
  HTTPRouter.RegisterRoute('/page-bench', rmPost, @StartPageBench);
  HTTPRouter.RegisterRoute('/api/embed/page', rmGet, @ShowEmbedPage);
  HTTPRouter.RegisterRoute('/embed/bench', rmGet, @AskEmbedBench);
  HTTPRouter.RegisterRoute('/embed/bench', rmPost, @OpenEmbedBench);
  HTTPRouter.RegisterRoute('/embed.js', rmGet, @SendEmbedScript);

finalization
  DoneCriticalSection(CacheLock);
end.
