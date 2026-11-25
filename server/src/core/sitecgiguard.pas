unit SiteCgiGuard;

{ CGI request guard: random temporary upload files, deleted after use, and
  the same SiteGuardRules and SiteGuard checks as the built-in server,
  before routing. }

{$mode objfpc}{$H+}

interface

function AcceptCgiRequest: boolean;

implementation

uses SysUtils, StrUtils, custcgi, SiteDb, SiteGuard, SiteGuardRules;

type
  { As the server's TGuardRequest: uploads under random names, deleted
    when the request is freed, which the CGI does after a refusal or an
    exception too. }
  TGuardCgiRequest = class(TCGIRequest)
  public
    destructor Destroy; override;
    function GetTempUploadFileName(const AName, AFileName: string; ASize: int64): string; override;
  end;

destructor TGuardCgiRequest.Destroy;
var
  Names: TUploadTemps;
begin
  Names := UploadTemps(Files);
  inherited Destroy;
  RemoveUploadTemps(Names);
end;

function TGuardCgiRequest.GetTempUploadFileName(const AName, AFileName: string; ASize: int64): string;
begin
  Result := UploadTempName(RequestUploadDir);
end;

function AcceptCgiRequest: boolean;
var
  Method, Path, Env, Reply: string;
  Size: int64;
  Code, Headers, I: integer;
begin
  Method := GetEnvironmentVariable('REQUEST_METHOD');
  Path := GetEnvironmentVariable('PATH_INFO');
  MaxCGIContentLength := TransportBodyLimit(Path);
  Code := 0;
  Headers := 0;
  for I := 1 to GetEnvironmentVariableCount do
  begin
    Env := GetEnvironmentString(I);
    if StartsStr('HTTP_', Env) then
    begin
      Inc(Headers);
      if Length(Env) > 8192 then
        Code := 431;
    end;
  end;
  if Headers > SettingInt('request_headers', 64) then
    Code := 431;
  if not TryStrToInt64(GetEnvironmentVariable('CONTENT_LENGTH'), Size) then
  begin
    Size := 0;
    if GetEnvironmentVariable('CONTENT_LENGTH') <> '' then
      Code := 400;
  end;
  if (Size < 0) or (Size > MaxCGIContentLength) then
    Code := 413;
  if not SafeRequestPath(Path) then
    Code := 404;
  if (Method <> 'GET') and (Method <> 'HEAD') and (Method <> 'POST') then
    Code := 405;
  Result := Code = 0;
  if Result then
    Exit;
  Reply := 'Request refused.';
  if Code = 413 then
    Reply := 'The request body is too large.';
  Write('Status: ', Code, ' Request refused'#13#10'Content-Type: text/plain; charset=utf-8'#13#10);
  if Code = 405 then
    Write('Allow: GET, HEAD, POST'#13#10);
  Write(#13#10, Reply);
end;

initialization
  CGIRequestClass := TGuardCgiRequest;

end.
