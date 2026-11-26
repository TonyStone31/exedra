unit SiteGuard;

{ Block repeated missing paths and wrong passwords; scanner paths count
  extra. Thresholds, block durations and address exemptions are settings.
  Members retain their own limits even on exempt addresses; admins can
  review and lift blocks. See docs/API.md for defaults. }

{$mode objfpc}{$H+}

interface

uses httpdefs, fpjson;

function IsBlocked(const Ip: string): boolean;
{ Shuts an address out: for an hour, or for good once it has been shut out
  block_strikes times. }
procedure Block(const Ip, Reason: string);
{ One more of something that adds up to a block (kind 'miss' or 'password');
  True when this one tipped it over. }
function Strike(const Ip, Kind: string; Count: integer = 1): boolean;
procedure RefuseAdmin(ARequest: TRequest; AResponse: TResponse);
{ Blocked for good by the site itself (unit SiteAbuse: AbuseIPDB's word and
  what the address did here); never a published crawler or an allowed address. }
procedure BlockForGood(const Ip, Reason: string);

type
  { A request that was plainly hostile: Kind probe (a scanner's path), admin
    (an administration page it may not see) or password (locked out for
    wrong passwords), Detail the path. }
  THostileNote = procedure(const Ip, Kind, Detail: string);

var
  { Told of each hostile request when set (unit SiteAbuse). }
  HostileSeen: THostileNote = nil;

type
  { Answers a path no route has, or returns False to leave it alone. }
  TPathAnswer = function(ARequest: TRequest; AResponse: TResponse): boolean;

var
  { Asked before a path nothing answers is refused: an application on top
    can take old addresses this way (the wiki's /File:Name, for one). }
  UnroutedPath: TPathAnswer = nil;

procedure RegisterAdminRoute(const Path, Permission: string);
function AdminRoutePermission(const Path: string): string;
{ An address never blocked or limited: this machine, or one in allowed_ips. }
function NeverBlocked(const Ip: string): boolean;
{ Everything the guard knows about one address, as the admin's address
  panel shows it: its name, whether it is a search engine's crawler,
  allowed or local, its block, and its strikes in the last day by kind. }
function AddressFacts(const Ip: string): TJSONObject;
{ A known search engine's crawler, by its name pointing back to the address. }
function KnownCrawler(const Address: string): boolean;
{ The company whose crawler Agent names when Address is not one of that
  company's, '' otherwise: a pretender, refused on every request. }
function FakeCrawler(const Address, Agent: string): string;

var
  { True while a backup is being restored: everyone but the restoring admin's
    page is asked to come back in a minute. }
  Restoring: boolean = False;
  { requests being answered now; a restore waits for this to reach 0 }
  ActiveRequests: integer = 0;

{ A request counted as under way, and counted off when it is answered. }
procedure RequestCounted;
procedure RequestAnswered;

{ The blocked addresses read again from the table, after a restore. }
procedure LoadBlocks;
procedure RegisterRequestLimit(const Key, Caption: string; PerAddress, PerMember, Minutes: integer; const HigherPermission: string = ''; HigherLimit: integer = 0);
procedure LimitRoute(const Key, Path, Method: string);
procedure RegisterSearchRoute(const Path: string);
procedure RegisterBodyLimit(const Path: string; Bytes: integer);
function RequestBodyLimit(const Path: string): int64;
function TransportBodyLimit(const Path: string): int64;
function AllowAttempt(const Subject, Kind: string; Limit, Minutes: integer): boolean;
function TokenTry(ARequest: TRequest; AResponse: TResponse): boolean;
function RequestShape(ARequest: TRequest; AResponse: TResponse): boolean;
{ Address when it is a page on this site to go back to, '' otherwise.
  Browsers drop tabs and line breaks from an address, so '/<tab>/elsewhere'
  would go to another site: any control character refuses it, as do '//' and
  a backslash at its start. }
function LocalReturn(const Address: string): string;

type
  TUploadTemps = array of string;

{ A new temporary file name for an upload, random, in Dir (the request's
  RequestUploadDir) or the temporary folder. }
function UploadTempName(const Dir: string): string;
{ The temporary files of a request's uploads, taken before the request
  frees them; RemoveUploadTemps deletes them once it is done with, so no
  request leaves one behind, refused or not.  The server and the CGI both. }
function UploadTemps(Files: TUploadedFiles): TUploadTemps;
procedure RemoveUploadTemps(const Names: TUploadTemps);

implementation

uses
  Classes, SysUtils, StrUtils, DateUtils, Variants, httproute, httpprotocol, netdb, sockets, SiteDb, SiteSql, SiteUsers,
  SiteRoles, SiteAdmin, SiteGuardRules, SiteStats, SiteWords, SiteCrawlers;

threadvar
  Counted: boolean;

procedure RequestCounted;
begin
  if not Counted then
  begin
    InterlockedIncrement(ActiveRequests);
    Counted := True;
  end;
end;

procedure RequestAnswered;
begin
  if Counted then
  begin
    InterlockedDecrement(ActiveRequests);
    Counted := False;
  end;
end;

type
  TGuard = class
    procedure Check(ARequest: TRequest; AResponse: TResponse; var aContinue: boolean);
  end;

  TRequestLimit = record
    Key, Caption, HigherPermission: string;
    PerAddress, PerMember, Minutes, HigherLimit: integer;
  end;

  TLimitedRoute = record
    Key, Path, Method: string;
  end;

var
  Blocks: TStringList;     // address=unix time it ends, 0 for good
  BlocksLock: TRTLCriticalSection;
  Guard: TGuard;
  AdminRoutes, SearchRoutes, BodyLimits: TStringList;
  RequestLimits: array of TRequestLimit;
  LimitedRoutes: array of TLimitedRoute;

procedure RegisterAdminRoute(const Path, Permission: string);
begin
  if AdminRoutes = nil then
    AdminRoutes := TStringList.Create;
  AdminRoutes.Values[LowerCase(Path)] := Permission;
end;

function AdminRoutePermission(const Path: string): string;
var
  P: string;
begin
  P := LowerCase(ExcludeTrailingPathDelimiter(HTTPDecode(Path)));
  Result := AdminRoutes.Values[P];
  // an address under a registered one (a file's name after /file/) asks what its parent asks
  while (Result = '') and (LastDelimiter('/', P) > 1) do
  begin
    P := Copy(P, 1, LastDelimiter('/', P) - 1);
    Result := AdminRoutes.Values[P];
  end;
  if (Result = '') and AdminPath(Path) then
    Result := 'view-admin';
end;

procedure RegisterBodyLimit(const Path: string; Bytes: integer);
begin
  BodyLimits.Values[Path] := IntToStr(Bytes);
end;

function RequestBodyLimit(const Path: string): int64;
var
  I: integer;
  Pattern, RequestPath: string;
begin
  RequestPath := LowerCase(ExcludeTrailingPathDelimiter(HTTPDecode(Path)));
  Result := SettingInt('request_body_kb', 64) * 1024;
  for I := 0 to BodyLimits.Count - 1 do
  begin
    Pattern := BodyLimits.Names[I];
    if (Pattern = RequestPath) or (Pattern.EndsWith('/*') and RequestPath.StartsWith(Copy(Pattern, 1, Length(Pattern) - 1))) then
      Result := StrToInt64Def(BodyLimits.ValueFromIndex[I], Result);
  end;
  if (RequestPath = '/api/upload') or (RequestPath = '/api/admin/look') then
    Result := SettingInt('upload_max_mb', 5) * 1024 * 1024 + 65536;
  // Settings cannot remove the transport's upper bound.
  if Result < 1024 then
    Result := 1024;
  if Result > 32 * 1024 * 1024 then
    Result := 32 * 1024 * 1024;
end;

function TransportBodyLimit(const Path: string): int64;
begin
  Result := RequestBodyLimit(Path);
  // a backup in pieces: each as large as its route allows (SiteBackup)
  if LowerCase(ExcludeTrailingPathDelimiter(HTTPDecode(Path))) = '/api/admin/backup/chunk' then
    Exit(RequestBodyLimit(Path));
  // Admin namespaces have one unauthenticated cap, including unknown paths.
  if AdminRoutePermission(Path) <> '' then
  begin
    Result := RequestBodyLimit('/api/upload');
    if Result < 1024 * 1024 then
      Result := 1024 * 1024;
  end;
end;

procedure RegisterSearchRoute(const Path: string);
begin
  SearchRoutes.Add(Path);
end;

procedure RegisterRequestLimit(const Key, Caption: string; PerAddress, PerMember, Minutes: integer; const HigherPermission: string; HigherLimit: integer);
var
  N: integer;
begin
  N := Length(RequestLimits);
  SetLength(RequestLimits, N + 1);
  RequestLimits[N].Key := Key;
  RequestLimits[N].Caption := Caption;
  RequestLimits[N].PerAddress := PerAddress;
  RequestLimits[N].PerMember := PerMember;
  RequestLimits[N].Minutes := Minutes;
  RequestLimits[N].HigherPermission := HigherPermission;
  RequestLimits[N].HigherLimit := HigherLimit;
  RegisterSetting(Key + '_address', Caption + ': tries per address in ' + IntToStr(Minutes) + ' minutes', IntToStr(PerAddress), 'number', 'Safety');
  RegisterSetting(Key + '_member', Caption + ': tries per member in ' + IntToStr(Minutes) + ' minutes', IntToStr(PerMember), 'number', 'Safety');
  if HigherPermission <> '' then
    RegisterSetting(Key + '_higher', Caption + ': tries per member with ' + HigherPermission, IntToStr(HigherLimit), 'number', 'Safety');
end;

procedure LimitRoute(const Key, Path, Method: string);
var
  N: integer;
begin
  // attempts.kind holds ten characters; a longer key fails every request it guards
  if Length(Key) > 10 then
    raise Exception.Create('A request limit''s key is ten characters at most: ' + Key);
  N := Length(LimitedRoutes);
  SetLength(LimitedRoutes, N + 1);
  LimitedRoutes[N].Key := Key;
  LimitedRoutes[N].Path := Path;
  LimitedRoutes[N].Method := Method;
end;

function AllowAttempt(const Subject, Kind: string; Limit, Minutes: integer): boolean;
var
  LockName: string;
begin
  Result := False;
  if Limit < 1 then
    Limit := 1;
  LockName := Sha256Hex('guard:' + Subject + ':' + Kind);
  // The database lock also covers separate CGI processes.
  if IntValue('SELECT ' + SqlLock(':n', 1), [LockName]) <> 1 then
    Exit;
  try
    Result := not TooManyTries(Subject, Kind, Limit, Minutes);
    if Result then
      NoteTry(Subject, Kind);
  finally
    Value('SELECT ' + SqlUnlock(':n'), [LockName]);
  end;
end;

function TokenTry(ARequest: TRequest; AResponse: TResponse): boolean;
begin
  CheckConnection;
  Result := AllowAttempt(ClientIp(ARequest), 'token', SettingInt('token_tries', 30), 1);
  if not Result then
    SendText(AResponse, 429, 'Too many token tries. Try again in a minute.');
end;

procedure NoteHostile(const Ip, Kind, Detail: string);
begin
  if Assigned(HostileSeen) then
  try
    HostileSeen(Ip, Kind, Detail);
  except
    on E: Exception do
      Log('Hostile note for ' + Ip + ' failed: ' + E.Message);
  end;
end;

{ A request the browser made on its own: a picture or another part of a
  page, or anything another site set off.  A page can make any visitor's
  browser send these, so they say nothing about the visitor. }
function BrowsersOwn(ARequest: TRequest): boolean;
var
  Dest: string;
begin
  Dest := LowerCase(ARequest.GetFieldByName('Sec-Fetch-Dest'));
  Result := SameText(ARequest.GetFieldByName('Sec-Fetch-Site'), 'cross-site') or ((Dest <> '') and (Dest <> 'document') and (Dest <> 'empty'));
end;

procedure RefuseAdmin(ARequest: TRequest; AResponse: TResponse);
begin
  if not BrowsersOwn(ARequest) then
  begin
    NoteHostile(ClientIp(ARequest), 'admin', ARequest.PathInfo);
    Strike(ClientIp(ARequest), 'admin');
  end;
  SendText(AResponse, 404, 'Nothing here.');
end;

function RequestShape(ARequest: TRequest; AResponse: TResponse): boolean;
var
  DeclaredLength: int64;
begin
  Result := False;
  if (ARequest.Method <> 'GET') and (ARequest.Method <> 'HEAD') and (ARequest.Method <> 'POST') then
  begin
    AResponse.Allow := 'GET, HEAD, POST';
    SendText(AResponse, 405, 'Method not allowed.');
  end
  else if not SafeRequestPath(ARequest.PathInfo) then
  begin
    if not BrowsersOwn(ARequest) then
    begin
      NoteHostile(ClientIp(ARequest), 'probe', ARequest.PathInfo);
      Strike(ClientIp(ARequest), 'miss', 3);
    end;
    SendText(AResponse, 404, 'Nothing here.');
  end
  else if ARequest.GetHeader(hhTransferEncoding) <> '' then
    SendText(AResponse, 400, 'Use Content-Length for the request body.')
  else if (ARequest.GetHeader(hhContentLength) <> '') and not TryStrToInt64(ARequest.GetHeader(hhContentLength), DeclaredLength) then
    SendText(AResponse, 400, 'Invalid Content-Length.')
  else if (ARequest.ContentLength < 0) or ((AdminRoutePermission(ARequest.PathInfo) = '') and (ARequest.ContentLength > RequestBodyLimit(ARequest.PathInfo))) then
    SendText(AResponse, 413, 'The request body is too large.')
  else
    Result := True;
end;

function LocalReturn(const Address: string): string;
var
  C: char;
begin
  Result := '';
  if (Length(Address) < 1) or (Length(Address) > 1000) or (Address[1] <> '/') then
    Exit;
  if (Length(Address) > 1) and (Address[2] in ['/', '\']) then
    Exit;
  for C in Address do
    if (Ord(C) < 32) or (Ord(C) = 127) or (C = '\') then
      Exit;
  Result := Address;
end;

{ This machine, the addresses an admin vouched for, and a proxy of the
  house that the config file does not name (all its visitors share it). }
function NeverBlocked(const Ip: string): boolean;
var
  Allowed: string;
begin
  Result := Ip.StartsWith('127.') or (Ip = '::1') or (Pos(' ' + Ip + ' ', ' ' + UnlistedProxies + ' ') > 0);
  for Allowed in Setting('allowed_ips', '').Split([',', ' '], TStringSplitOptions.ExcludeEmpty) do
    if Ip = CanonicalIp(Allowed) then
      Result := True;
end;

function CacheLimit: integer;
begin
  Result := SettingInt('block_cache_max', 10000);
  if Result < 1 then
    Result := 1;
  if Result > 100000 then
    Result := 100000;
end;

procedure NormalizeBlocks;
var
  LastAddress, StoredAddress, Address: string;
  BatchCount: integer;
begin
  LastAddress := '';
  repeat
    BatchCount := 0;
    with Query('SELECT ip, blocked_until, times, reason, updated FROM blocks WHERE ip > :i ORDER BY ip LIMIT 500', [LastAddress]) do
    try
      while not EOF do
      begin
        Inc(BatchCount);
        StoredAddress := Fields[0].AsString;
        LastAddress := StoredAddress;
        Address := CanonicalIp(StoredAddress);
        if (Address <> '') and not SameText(Address, StoredAddress) then
        begin
          // Merge old spellings without shortening a block or losing its count.
          Exec('INSERT INTO blocks (ip, blocked_until, times, reason, updated) VALUES (:i, :u, :t, :r, :d)' + SqlOnConflict('ip',
            'blocked_until = ' + SqlIf('blocked_until IS NULL OR :u2 IS NULL', 'NULL', SqlGreatest('blocked_until', ':u3')) + ', times = ' +
            SqlGreatest('times', ':t2') + ', updated = ' + SqlGreatest('updated', ':d2')),
            [Address, Fields[1].Value, Fields[2].Value, Fields[3].Value, Fields[4].Value, Fields[1].Value, Fields[1].Value, Fields[2].Value, Fields[4].Value]);
          Exec('DELETE FROM blocks WHERE ip = :i', [StoredAddress]);
        end;
        Next;
      end;
    finally
      Free;
    end;
  until BatchCount < 500;
end;

procedure LoadBlocks;
begin
  EnterCriticalSection(BlocksLock);
  try
    Blocks.Clear;
    with Query('SELECT ip, COALESCE(' + SqlUnix('blocked_until') + ', 0) FROM (' +
        'SELECT ip, blocked_until, updated FROM blocks WHERE blocked_until IS NULL OR blocked_until > NOW()' +
        ' ORDER BY updated DESC, ip LIMIT :n) recent ORDER BY updated, ip', [CacheLimit]) do
    try
      while not EOF do
      begin
        CacheBlock(Blocks, Fields[0].AsString, Fields[1].AsString, CacheLimit);
        Next;
      end;
    finally
      Free;
    end;
  finally
    LeaveCriticalSection(BlocksLock);
  end;
end;

function IsBlocked(const Ip: string): boolean;
var
  Ends: int64;
  Address: string;
begin
  Address := CanonicalIp(Ip);
  if NeverBlocked(Address) then
    Exit(False);
  EnterCriticalSection(BlocksLock);
  try
    Ends := StrToInt64Def(Blocks.Values[Address], -1);
  finally
    LeaveCriticalSection(BlocksLock);
  end;
  Result := (Ends = 0) or (Ends > DateTimeToUnix(NowUTC));
end;

procedure Block(const Ip, Reason: string);
var
  Times: integer;
  Address, Ends, LockName: string;
begin
  Address := CanonicalIp(Ip);
  if (Address = '') or NeverBlocked(Address) then
    Exit;
  LockName := Sha256Hex('block:' + Address);
  if IntValue('SELECT ' + SqlLock(':n', 1), [LockName]) <> 1 then
    Exit;
  try
    // Concurrent strikes belong to one block, not several permanent strikes.
    if IntValue('SELECT COUNT(*) FROM blocks WHERE ip = :i AND (blocked_until IS NULL OR blocked_until > NOW())', [Address]) = 0 then
    begin
      Times := IntValue('SELECT times FROM blocks WHERE ip = :i', [Address]) + 1;
      if Times >= SettingInt('block_strikes', 3) then
        Exec('INSERT INTO blocks (ip, blocked_until, times, reason) VALUES (:i, ' + SqlAhead(':d', suDay) + ', :t, :r)' +
          SqlOnConflict('ip', 'blocked_until = ' + SqlAhead(':d2', suDay) + ', times = :t2, reason = :r2'),
          [Address, SettingInt('block_days', 30), Times, Copy(Reason, 1, 100), SettingInt('block_days', 30), Times, Copy(Reason, 1, 100)])
      else
        Exec('INSERT INTO blocks (ip, blocked_until, times, reason) VALUES (:i, ' + SqlAhead('1', suHour) + ', :t, :r)' +
          SqlOnConflict('ip', 'blocked_until = ' + SqlAhead('1', suHour) + ', times = :t2, reason = :r2'),
          [Address, Times, Copy(Reason, 1, 100), Times, Copy(Reason, 1, 100)]);
      Log('Blocked ' + Address + ' (' + Reason + ', time ' + IntToStr(Times) + ')');
    end;
    Ends := VarToStr(Value('SELECT COALESCE(' + SqlUnix('blocked_until') + ', 0) FROM blocks WHERE ip = :i', [Address]));
    EnterCriticalSection(BlocksLock);
    try
      CacheBlock(Blocks, Address, Ends, CacheLimit);
    finally
      LeaveCriticalSection(BlocksLock);
    end;
  finally
    Value('SELECT ' + SqlUnlock(':n'), [LockName]);
  end;
end;

var
  CrawlerLock: TRTLCriticalSection;
  CrawlerSeen: TStringList;

{ Whether an address belongs to a search engine's crawler: its reverse name
  ends in one of the engines' domains and that name points back to it.  Only
  asked when a block is about to happen, so a slow lookup costs little; the
  answer is kept for a day. }
function IfThenChar(Yes: boolean): string;
begin
  if Yes then
    Result := 'y'
  else
    Result := 'n';
end;

{ Looks the address up both ways once a day: Crawler says whether a search
  engine's name points back to it, Name is what it resolves to. }
procedure LookUp(const Address: string; out Crawler: boolean; out Name: string);
const
  ENGINES: array[0..6] of string = ('.googlebot.com', '.google.com', '.search.msn.com', '.applebot.apple.com', '.crawl.yahoo.net', '.yandex.ru', '.duckduckgo.com');
var
  Entry: THostEntry;
  Domain, Seen: string;
  Back: THostAddr;
  I: integer;
begin
  Crawler := False;
  Name := '';
  if Pos(':', Address) > 0 then
    Exit;
  EnterCriticalSection(CrawlerLock);
  try
    I := CrawlerSeen.IndexOfName(Address);
    if I >= 0 then
    begin
      // y or n, the time, a space, the name
      Seen := CrawlerSeen.ValueFromIndex[I];
      if Now - StrToFloatDef(Copy(Seen, 2, Pos(' ', Seen + ' ') - 2), 0) < 1 then
      begin
        Crawler := Seen[1] = 'y';
        Name := Copy(Seen, Pos(' ', Seen + ' ') + 1, MaxInt);
        Exit;
      end;
    end;
  finally
    LeaveCriticalSection(CrawlerLock);
  end;
  Back := StrToHostAddr(Address);
  if ResolveHostByAddr(Back, Entry) then
  begin
    Name := LowerCase(Entry.Name);
    for Domain in ENGINES do
      if EndsStr(Domain, '.' + Name) or EndsStr(Domain, Name) then
        // the name must point back to the address, or anyone could claim it;
        // ResolveHostByName hands the address back in network order
        if ResolveHostByName(Name, Entry) and (NetAddrToStr(Entry.Addr) = Address) then
        begin
          Crawler := True;
          Break;
        end;
  end;
  if Crawler then
    Log('Not blocked: ' + Address + ' is ' + Name);
  EnterCriticalSection(CrawlerLock);
  try
    CrawlerSeen.Values[Address] := IfThenChar(Crawler) + FloatToStr(Now) + ' ' + Name;
    while CrawlerSeen.Count > 500 do
      CrawlerSeen.Delete(0);
  finally
    LeaveCriticalSection(CrawlerLock);
  end;
end;

{ A search engine's or an AI company's crawler, which is welcome: by the
  address lists the companies publish (SiteCrawlers' table, IPv6 too), or
  by a name that points back to the address. }
function KnownCrawler(const Address: string): boolean;
var
  Name, Company: string;
begin
  Result := PublishedCrawler(Address, Company) <> '';
  if not Result then
    LookUp(Address, Result, Name);
end;

function FakeCrawler(const Address, Agent: string): string;
var
  Company, Inside, Name: string;
  ByName: boolean;
begin
  Result := '';
  Company := ClaimedCompany(Agent);
  if (Company = '') or NeverBlocked(Address) then
    Exit;
  PublishedCrawler(Address, Inside);
  if (Inside = Company) or not CompanyListsReady(Company) then
    Exit;
  // a search engine's name pointing back to the address still counts as its own
  LookUp(Address, ByName, Name);
  if not ByName then
    Result := Company;
end;

function Strike(const Ip, Kind: string; Count: integer): boolean;
var
  Limit, Minutes, I: integer;
  Address: string;
begin
  Address := CanonicalIp(Ip);
  Result := False;
  if (Address = '') or NeverBlocked(Address) or IsBlocked(Address) then
    Exit;
  CheckConnection;
  Limit := SettingInt('missing_tries', 6);
  Minutes := 1;
  if Kind = 'password' then
  begin
    Limit := SettingInt('password_tries', 10);
    Minutes := 15;
  end;
  if Kind = 'admin' then
    Limit := SettingInt('admin_probe_tries', 3);
  for I := 1 to Count do
    NoteTry(Address, 'g-' + Kind);
  Result := TooManyTries(Address, 'g-' + Kind, Limit, Minutes);
  if Result and KnownCrawler(Address) then
    Exit(False);
  if Result then
  begin
    if Kind = 'miss' then
    begin
      Block(Address, 'asked for pages that are not here');
      // looked up (not reported): blocked for good only when AbuseIPDB
      // already knows it as an abuser
      NoteHostile(Address, 'miss', '');
    end
    else if Kind = 'admin' then
      Block(Address, 'probed administration pages')
    else
    begin
      Block(Address, 'wrong passwords or tokens');
      NoteHostile(Address, 'password', '');
    end;
  end;
end;

procedure TGuard.Check(ARequest: TRequest; AResponse: TResponse; var aContinue: boolean);
var
  Me: TMember;
  Path, Method, Permission, Problem: string;
  Route: TLimitedRoute;
  Rule: TRequestLimit;
  MemberLimit: integer;
  Allowed: boolean;
  Perm: string;
begin
  RequestBegins;
  // the guard answers before the language step runs: in this visitor's
  // language, not whatever this thread served last
  SetRequestLanguage(CookieLanguage(ARequest));
  aContinue := False;
  try
    if not RequestShape(ARequest, AResponse) then
      Exit;
    aContinue := not IsBlocked(ClientIp(ARequest));
    if not aContinue then
    begin
      // what a blocked address still asks for counts: a scanner's telling
      // paths (/.env, /cgi-bin/...) often come after its first misses have
      // blocked it for the hour, and would otherwise never be seen
      if not OldLink(ARequest.PathInfo) and not BrowsersOwn(ARequest) then
        if Probing(ARequest.PathInfo) then
          NoteHostile(ClientIp(ARequest), 'probe', ARequest.PathInfo)
        else if AdminPath(ARequest.PathInfo) then
          NoteHostile(ClientIp(ARequest), 'admin', ARequest.PathInfo);
      SendText(AResponse, 403, 'This address is blocked.');
      Exit;
    end;
    aContinue := False;
    // a browser string that names a crawler the address does not belong to;
    // only that string is refused, since the address may be shared (a VPN exit)
    Problem := FakeCrawler(ClientIp(ARequest), ARequest.UserAgent);
    if Problem <> '' then
    begin
      SendText(AResponse, 403, Format('This browser string names %s''s crawler, and this address is not one of %s''s.', [Problem, Problem]));
      Exit;
    end;
    if Restoring and not StartsText('/api/admin/backup', ARequest.PathInfo) then
    begin
      AResponse.SetCustomHeader('Retry-After', '30');
      SendText(AResponse, 503, 'A backup is being restored. Back in a minute.');
      Exit;
    end;
    // past the gate: a restore that starts now waits for this request
    if not StartsText('/api/admin/backup', ARequest.PathInfo) then
      RequestCounted;
    Path := LowerCase(ExcludeTrailingPathDelimiter(HTTPDecode(ARequest.PathInfo)));
    Permission := AdminRoutePermission(ARequest.PathInfo);
    if Permission <> '' then
    begin
      AResponse.SetCustomHeader('Cache-Control', 'private, no-store');
      CheckConnection;
      Me := CurrentMember(ARequest);
      if (Path = '/admin') or (Path = '/api/admin') then
        Allowed := CanOpenAdmin(Me)
      else
      begin
        Allowed := False;
        for Perm in Permission.Split(['|']) do
          Allowed := Allowed or Can(Me, Perm);
      end;
      if (Me.Id = 0) or Me.Banned or not Allowed then
      begin
        RefuseAdmin(ARequest, AResponse);
        Exit;
      end;
      if ARequest.ContentLength > RequestBodyLimit(ARequest.PathInfo) then
      begin
        SendText(AResponse, 413, 'The request body is too large.');
        Exit;
      end;
    end;
    if TokenOf(ARequest) <> '' then
    begin
      CheckConnection;
      if TooManyTries(ClientIp(ARequest), 'bad-token', SettingInt('token_tries', 30), 1) then
      begin
        SendText(AResponse, 429, 'Too many token tries. Try again in a minute.');
        Exit;
      end;
      Me := CurrentMember(ARequest);
      if Me.Id = 0 then
      begin
        with AResponse.Cookies.Add do
        begin
          Name := 'sid';
          Value := '';
          Path := '/';
          MaxAge := 0;
          Expires := NowUTC - 1;
        end;
        SendText(AResponse, 403, 'That sign-in has expired. Sign in again.');
        Exit;
      end;
    end;
    if SearchRoutes.IndexOf(Path) >= 0 then
    begin
      // The empty HTML search form can be opened without running a query.
      if (ARequest.QueryFields.Values['q'] <> '') or Path.StartsWith('/api/') then
      begin
        Problem := SearchQueryProblem(ARequest.QueryFields.Values['q'], SettingInt('search_query_bytes', 100));
        if Problem <> '' then
        begin
          SendText(AResponse, 400, Problem);
          Exit;
        end;
      end;
    end;
    Method := ARequest.Method;
    if Method = 'HEAD' then
      Method := 'GET';
    for Route in LimitedRoutes do
      if (Route.Method = Method) and ((Route.Path = Path) or (Route.Path.EndsWith('/*') and Path.StartsWith(Copy(Route.Path, 1, Length(Route.Path) - 1)))) then
        for Rule in RequestLimits do
          if Rule.Key = Route.Key then
          begin
            CheckConnection;
            Me := CurrentMember(ARequest);
            MemberLimit := SettingInt(Rule.Key + '_member', Rule.PerMember);
            if (Rule.HigherPermission <> '') and Can(Me, Rule.HigherPermission) then
              MemberLimit := SettingInt(Rule.Key + '_higher', Rule.HigherLimit);
            // the house's own network and the vouched-for addresses have no limit per
            // address; a member there still has the limit per member
            // a published or name-checked crawler is welcome at its own pace
            if not NeverBlocked(ClientIp(ARequest)) and not AllowAttempt(ClientIp(ARequest), Rule.Key, SettingInt(Rule.Key + '_address', Rule.PerAddress), Rule.Minutes) and
              not KnownCrawler(ClientIp(ARequest)) then
            begin
              AResponse.SetCustomHeader('Retry-After', IntToStr(Rule.Minutes * 60));
              SendText(AResponse, 429, Format(Say('%s: too many tries from this address. Try again later.'), [Say(Rule.Caption)]));
              Exit;
            end;
            if (Me.Id > 0) and not AllowAttempt('member ' + IntToStr(Me.Id), Rule.Key, MemberLimit, Rule.Minutes) then
            begin
              AResponse.SetCustomHeader('Retry-After', IntToStr(Rule.Minutes * 60));
              SendText(AResponse, 429, Format(Say('%s: at most %d tries per member in %d minutes. Try again later.'), [Say(Rule.Caption), MemberLimit, Rule.Minutes]));
              Exit;
            end;
          end;
    aContinue := True;
  finally
    NoteWebRequest(ARequest, not aContinue);
  end;
end;

{ Every path nothing else answers. }
procedure NotFound(ARequest: TRequest; AResponse: TResponse);
var
  Count: integer;
begin
  CheckConnection;
  if Assigned(UnroutedPath) and UnroutedPath(ARequest, AResponse) then
    Exit;
  Count := 1;
  // a page that is not here under an address that had pages once is an
  // old link or a crawler following one, not probing (RegisterOldLink)
  if OldLink(ARequest.PathInfo) or BrowsersOwn(ARequest) then
    Count := 0
  else if Probing(ARequest.PathInfo) then
  begin
    Count := 3;
    NoteHostile(ClientIp(ARequest), 'probe', ARequest.PathInfo);
  end;
  if Count > 0 then
    Strike(ClientIp(ARequest), 'miss', Count);
  SendText(AResponse, 404, 'Nothing here.');
end;

{ GET /api/blocks  for admins: who is shut out, and why }
procedure ShowBlocks(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  List: TJSONArray;
begin
  if not NeedPermission(ARequest, AResponse, 'manage-blocks', Me) then
    Exit;
  List := TJSONArray.Create;
  with Query('SELECT ip, ' + IsoTime('blocked_until') + ', blocked_until IS NULL, times, reason, ' + IsoTime('updated') +
      ', blocked_until IS NULL OR blocked_until > NOW() FROM blocks ORDER BY updated DESC LIMIT 200', []) do
  try
    while not EOF do
    begin
      List.Add(TJSONObject.Create(['ip', Fields[0].AsString, 'until', Fields[1].AsString, 'for_good', Fields[2].AsInteger = 1, 'times',
        Fields[3].AsInteger, 'reason', Fields[4].AsString, 'when', Fields[5].AsString, 'active', Fields[6].AsInteger = 1]));
      Next;
    end;
  finally
    Free;
  end;
  SendJSON(AResponse, List);
end;

procedure BlockForGood(const Ip, Reason: string);
var
  Address: string;
begin
  Address := CanonicalIp(Ip);
  if (Address = '') or NeverBlocked(Address) or KnownCrawler(Address) then
    Exit;
  Exec('INSERT INTO blocks (ip, blocked_until, times, reason) VALUES (:i, NULL, 1, :r)' + SqlOnConflict('ip', 'blocked_until = NULL, reason = ' + SqlNew('reason')),
    [Address, Copy(Reason, 1, 100)]);
  Log('Blocked ' + Address + ' for good (' + Reason + ')');
  LoadBlocks;
end;

{ POST /api/blocks  ip, and do: lift (forgiven, the count starts again) or
  forgood }
procedure SaveBlock(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Ip: string;
begin
  if not NeedPermission(ARequest, AResponse, 'manage-blocks', Me) then
    Exit;
  Ip := CanonicalIp(ARequest.ContentFields.Values['ip']);
  if Ip = '' then
  begin
    SendText(AResponse, 400, 'Enter an IP address.');
    Exit;
  end;
  // a crawler is blocked by hand only when the admin was told and said yes
  if ((ARequest.ContentFields.Values['do'] = 'block') or (ARequest.ContentFields.Values['do'] = 'forgood')) and (ARequest.ContentFields.Values['crawler_ok'] <> '1') and
    KnownCrawler(Ip) then
  begin
    SendText(AResponse, 409, 'That address is a published crawler. Block it anyway from its address panel.');
    Exit;
  end;
  if ARequest.ContentFields.Values['do'] = 'lift' then
    Exec('DELETE FROM blocks WHERE ip = :i', [Ip])
  else if ARequest.ContentFields.Values['do'] = 'forgood' then
    Exec('INSERT INTO blocks (ip, blocked_until, times, reason) VALUES (:i, NULL, 1, :r)' + SqlOnConflict('ip', 'blocked_until = NULL'), [Ip, 'blocked by ' + Me.Name])
  else if ARequest.ContentFields.Values['do'] = 'allow' then
  begin
    // never blocked or limited again: the address joins allowed_ips
    Exec('DELETE FROM blocks WHERE ip = :i', [Ip]);
    if not NeverBlocked(Ip) then
      SaveSetting('allowed_ips', Trim(Setting('allowed_ips', '') + ' ' + Ip));
  end
  else if ARequest.ContentFields.Values['do'] = 'block' then
    // by hand, for block_days, with the admin's reason
    Exec('INSERT INTO blocks (ip, blocked_until, times, reason) VALUES (:i, ' + SqlAhead(':d', suDay) + ', 1, :r)' + SqlOnConflict('ip',
      'blocked_until = ' + SqlNew('blocked_until') + ', reason = ' + SqlNew('reason')),
      [Ip, SettingInt('block_days', 30), Copy('blocked by ' + Me.Name + ': ' + Trim(ARequest.ContentFields.Values['reason']), 1, 100)]);
  LoadBlocks;
  SendText(AResponse, 200, 'ok');
end;

function AddressFacts(const Ip: string): TJSONObject;
var
  Name: string;
  Strikes: TJSONArray;
  Crawler: boolean;
  Published, Company: string;
begin
  CheckConnection;
  LookUp(Ip, Crawler, Name);
  Published := PublishedCrawler(Ip, Company);
  Result := TJSONObject.Create(['ip', Ip, 'host', Name, 'crawler', Crawler or (Published <> ''), 'crawler_name', Published, 'company',
    Company, 'allowed', NeverBlocked(Ip), 'local', Ip.StartsWith('127.') or Ip.StartsWith('10.') or Ip.StartsWith('192.168.') or (Ip = '::1')]);
  try
    with Query('SELECT ' + IsoTime('blocked_until') + ', blocked_until IS NULL, times, reason, ' + IsoTime('updated') +
        ', blocked_until IS NULL OR blocked_until > NOW() FROM blocks WHERE ip = :i', [Ip]) do
    try
      if EOF then
        Result.Add('block', TJSONNull.Create)
      else
        Result.Add('block', TJSONObject.Create(['until', Fields[0].AsString, 'for_good', Fields[1].AsInteger = 1, 'times', Fields[2].AsInteger,
          'reason', Fields[3].AsString, 'when', Fields[4].AsString, 'active', Fields[5].AsInteger = 1]));
    finally
      Free;
    end;
    Strikes := TJSONArray.Create;
    Result.Add('strikes', Strikes);
    with Query('SELECT kind, COUNT(*), ' + IsoTime('MAX(at)') + ' FROM attempts WHERE ip = :i AND at > ' + SqlMinus(SqlUtcNow, '1', suDay) +
        ' GROUP BY kind ORDER BY 2 DESC', [Ip]) do
    try
      while not EOF do
      begin
        Strikes.Add(TJSONObject.Create(['kind', Fields[0].AsString, 'count', Fields[1].AsInteger, 'last', Fields[2].AsString]));
        Next;
      end;
    finally
      Free;
    end;
    // what AbuseIPDB said of it, and when we last reported it (unit SiteAbuse)
    with Query('SELECT c.score, c.reports, c.usage_type, c.isp, c.country, ' + IsoTime('c.checked') + ',' + ' (SELECT ' + IsoTime('MAX(r.at)') +
        ' FROM abuse_reports r WHERE r.ip = c.ip) FROM abuse_checks c WHERE c.ip = :i', [Ip]) do
    try
      if not EOF then
        Result.Add('abuse', TJSONObject.Create(['score', Fields[0].AsInteger, 'reports', Fields[1].AsInteger, 'usage', Fields[2].AsString,
          'isp', Fields[3].AsString, 'country', Fields[4].AsString, 'checked', Fields[5].AsString, 'reported', Fields[6].AsString]));
    finally
      Free;
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

{ GET /api/blocks/why?ip=  everything known about one address }
procedure ShowWhy(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Ip: string;
begin
  if not NeedPermission(ARequest, AResponse, 'manage-blocks', Me) then
    Exit;
  Ip := CanonicalIp(ARequest.QueryFields.Values['ip']);
  if Ip = '' then
  begin
    SendText(AResponse, 400, 'Enter an IP address.');
    Exit;
  end;
  SendJSON(AResponse, AddressFacts(Ip));
end;

procedure ForgetOldBlocks;
begin
  Exec('DELETE FROM blocks WHERE blocked_until < ' + SqlAgo('30', suDay), []);
  LoadBlocks;
end;

function UploadTempName(const Dir: string): string;
begin
  if Dir = '' then
    Result := GetTempDir
  else
    Result := Dir;
  Result := IncludeTrailingPathDelimiter(Result) + 'upload-' + RandomHex(16) + '.tmp';
end;

function UploadTemps(Files: TUploadedFiles): TUploadTemps;
var
  I: integer;
begin
  Result := nil;
  SetLength(Result, Files.Count);
  for I := 0 to Files.Count - 1 do
    Result[I] := Files[I].LocalFileName;
end;

procedure RemoveUploadTemps(const Names: TUploadTemps);
var
  Name: string;
begin
  for Name in Names do
    if (Name <> '') and FileExists(Name) and not DeleteFile(Name) then
      Log('Upload temporary file not removed: ' + Name);
end;

initialization
  InitCriticalSection(BlocksLock);
  Blocks := TStringList.Create;
  if AdminRoutes = nil then
    AdminRoutes := TStringList.Create;
  SearchRoutes := TStringList.Create;
  BodyLimits := TStringList.Create;
  Guard := TGuard.Create;
  RegisterTable('CREATE TABLE IF NOT EXISTS blocks (' + ' ip VARCHAR(45) PRIMARY KEY, blocked_until DATETIME NULL, times INT NOT NULL DEFAULT 1,' +
    ' reason VARCHAR(100) NOT NULL DEFAULT '''',' + ' updated DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP)');
  InitCriticalSection(CrawlerLock);
  CrawlerSeen := TStringList.Create;
  RegisterStartup(@NormalizeBlocks);
  RegisterStartup(@LoadBlocks);
  RegisterChore(@ForgetOldBlocks, 60);
  RegisterSetting('allowed_ips', 'Addresses never blocked or limited per address (comma separated; this machine always is)', '', 'longtext',
    'Safety');
  RegisterSetting('block_strikes', 'Automatic blocks before an address is blocked for block_days', '3', 'number', 'Safety');
  RegisterSetting('block_days', 'Days an address stays blocked after that many; only an admin blocks for good', '30', 'number', 'Safety');
  RegisterSetting('block_cache_max', 'Maximum cached blocked addresses (oldest dropped; restart to apply)', '10000', 'number', 'Safety');
  RegisterSetting('admin_probe_tries', 'Refused admin requests per minute before blocking', '3', 'number', 'Safety');
  RegisterSetting('missing_tries', 'Missing-page strikes per minute before blocking (probe paths count three)', '6', 'number', 'Safety');
  RegisterSetting('password_tries', 'Wrong passwords or tokens per address in 15 minutes before blocking', '10', 'number', 'Safety');
  RegisterSetting('signin_tries', 'Sign-in attempts per address per minute, web and IRC together', '10', 'number', 'Safety');
  RegisterSetting('token_tries', 'Token tries per address per minute', '30', 'number', 'Safety');
  RegisterSetting('request_body_kb', 'Largest ordinary request body in KB (restart to apply)', '64', 'number', 'Safety');
  RegisterSetting('request_headers', 'Maximum request headers (restart to apply)', '64', 'number', 'Safety');
  RegisterSetting('request_read_ms', 'Request read timeout in milliseconds (restart to apply)', '30000', 'number', 'Safety');
  RegisterSetting('search_query_bytes', 'Largest search text in bytes', '100', 'number', 'Safety');
  RegisterAdminRoute('/api/blocks', 'manage-blocks');
  RegisterPermission('manage-blocks', 'See and lift blocked addresses', 'admin');
  HTTPRouter.RegisterInterceptor('guard', @Guard.Check);
  // Never matches by itself, so the router only uses it when nothing else does.
  HTTPRouter.RegisterRoute('/-nothing-here-', rmAll, @NotFound, True);
  HTTPRouter.RegisterRoute('/api/blocks', rmGet, @ShowBlocks);
  HTTPRouter.RegisterRoute('/api/blocks', rmPost, @SaveBlock);
  RegisterAdminRoute('/api/blocks/why', 'manage-blocks');
  HTTPRouter.RegisterRoute('/api/blocks/why', rmGet, @ShowWhy);
end.
