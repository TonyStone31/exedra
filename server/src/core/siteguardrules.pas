unit SiteGuardRules;

{ Database-free guard rules: probe paths, obsolete addresses, safe file
  paths, search validation and cached blocks. SiteGuard applies them; the
  HTTP and CGI guards check requests before routing. }

{$mode objfpc}{$H+}

interface

uses Classes;

function CanonicalIp(const Address: string): string;
{ Addresses that had pages once: one who follows a link to them is not
  probing.  Prefix is the start of the path. }
procedure RegisterOldLink(const Prefix: string);
function OldLink(const Path: string): boolean;
function Probing(const Path: string): boolean;
function AdminPath(const Path: string): boolean;
function SafeRequestPath(const Path: string): boolean;
procedure RegisterFileGuard(const Root: string);
function SearchQueryProblem(const Text: string; MaxBytes: integer): string;
function LogText(const Text: string; MaxBytes: integer = 1000): string;
procedure CacheBlock(List: TStrings; const Address, Ends: string; MaxCount: integer);

implementation

uses SysUtils, StrUtils, Sockets, httpdefs;

var
  FileRoots: TStringList;

procedure RegisterFileGuard(const Root: string);
begin
  FileRoots.Add(LowerCase(ExcludeTrailingPathDelimiter(Root)));
end;

procedure CacheBlock(List: TStrings; const Address, Ends: string; MaxCount: integer);
var
  Ip: string;
  I: integer;
begin
  Ip := CanonicalIp(Address);
  if Ip = '' then
    Exit;
  if MaxCount < 1 then
    MaxCount := 1;
  I := List.IndexOfName(Ip);
  if I >= 0 then
    List.Delete(I);
  List.Add(Ip + '=' + Ends);
  while List.Count > MaxCount do
    List.Delete(0);
end;

function CanonicalIp(const Address: string): string;
var
  V4: in_addr;
  V6: in6_addr;
  S: string;
  I: integer;
  Mapped: boolean;
begin
  S := Trim(Address);
  if TryStrToHostAddr(S, V4) then
    Exit(HostAddrToStr(V4));
  if not TryStrToHostAddr6(S, V6) then
    Exit('');
  Mapped := True;
  for I := 0 to 9 do
    if V6.u6_addr8[I] <> 0 then
      Mapped := False;
  if Mapped and (V6.u6_addr8[10] = 255) and (V6.u6_addr8[11] = 255) then
    Exit(Format('%d.%d.%d.%d', [V6.u6_addr8[12], V6.u6_addr8[13], V6.u6_addr8[14], V6.u6_addr8[15]]));
  Result := LowerCase(HostAddrToStr6(V6));
end;

var
  OldLinks: array of string;

procedure RegisterOldLink(const Prefix: string);
begin
  SetLength(OldLinks, Length(OldLinks) + 1);
  OldLinks[High(OldLinks)] := Prefix;
end;

function OldLink(const Path: string): boolean;
var
  Prefix: string;
begin
  Result := False;
  for Prefix in OldLinks do
    if StartsText(Prefix, Path) then
      Exit(True);
end;

const
  { Parts of a path only scanners ask for (pages that are not here). }
  ProbeParts: array[0..33] of string = ('.php', '/.env', '/.git', '/wp-', 'phpmyadmin', '/cgi-bin', '.asp', '/actuator', '/.aws',
    '.jsp', '.axd', '.action', '.cgi', '/.svn', '/.hg', '/.ds_store', '/.vscode', '/.ssh', '/server-status', '/server-info',
    '/console/', '/v2/_catalog', '/sitecore/', '/zabbix/', '___proxy_subdomain', '/aspera/', '/manager/html', '/hnap1',
    '/boaform', '/owa/', '/remote/login', '/geoserver', 'sugar_version', '/solr/');
  { Whole paths that are a sweep for an installed web application. }
  ProbePaths: array[0..2] of string = ('/wp', '/wordpress', '/backup');

function Probing(const Path: string): boolean;
var
  P, Part: string;
begin
  P := LowerCase(HTTPDecode(Path));
  for Part in ProbeParts do
    if AnsiContainsStr(P, Part) then
      Exit(True);
  P := ExcludeTrailingPathDelimiter(P);
  for Part in ProbePaths do
    if P = Part then
      Exit(True);
  Result := False;
end;

function AdminPath(const Path: string): boolean;
var
  P: string;
begin
  P := LowerCase(HTTPDecode(Path));
  // the admin page and its addresses, not a member or a page called Admin
  Result := (P = '/admin') or P.StartsWith('/admin/') or P.StartsWith('/api/admin/') or (P = '/api/admin');
end;

function SafeRequestPath(const Path: string): boolean;
var
  P, Part, Root: string;
  I: integer;
begin
  Result := False;
  P := HTTPDecode(Path);
  // No second decoding, backslashes or control bytes can reach file modules.
  if (Pos('%', P) > 0) or (Pos('\', P) > 0) then
    Exit;
  for I := 1 to Length(P) do
    if (Ord(P[I]) < 32) or (Ord(P[I]) = 127) then
      Exit;
  for Part in P.Split(['/']) do
    if (Part = '..') or (Part = '.') then
      Exit;
  Root := LowerCase(Copy(P, 1, PosEx('/', P + '/', 2) - 1));
  if FileRoots.IndexOf(Root) >= 0 then
    if (Pos('%2f', LowerCase(Path)) > 0) or (Pos('%5c', LowerCase(Path)) > 0) then
      Exit;
  Result := True;
end;

function SearchQueryProblem(const Text: string; MaxBytes: integer): string;
var
  S: string;
begin
  S := Trim(Text);
  if Length(S) > MaxBytes then
    Exit(Format('Search text can be at most %d bytes.', [MaxBytes]));
  if Length(UTF8Decode(S)) < 2 then
    Exit('Enter at least two characters to search.');
  Result := '';
end;

function LogText(const Text: string; MaxBytes: integer): string;
var
  I: integer;
begin
  Result := Copy(Text, 1, MaxBytes);
  for I := 1 to Length(Result) do
    if (Ord(Result[I]) < 32) or (Ord(Result[I]) = 127) then
      Result[I] := ' ';
end;

initialization
  FileRoots := TStringList.Create;
  RegisterFileGuard('/static');
  RegisterFileGuard('/files');
  RegisterFileGuard('/site');

finalization
  FileRoots.Free;
end.
