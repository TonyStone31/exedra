unit SiteSecurity;

{ Default response security headers: local scripts and forms, no plugins or
  framing, HTTPS images and inline styles. /csp-report logs browser
  refusals. A route may replace these headers afterward, such as for a
  sandboxed upload. }

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, httpdefs;

{ The Content-Security-Policy for a page answered to Host (as the browser
  sent it): the live connection goes to the same host by ws or wss.
  FormsAlso is one more address a form on the page may be sent on to. }
function SecurityPolicy(const Host: string; const FormsAlso: string = ''): string;
{ One report's line for the log, from the JSON a browser posts; '' when it
  is not a report. }
function ReportLine(const Body: string): string;

implementation

uses StrUtils, fpjson, jsonparser, httproute, SiteDb, SiteUsers;

type
  TSecurityStep = class
    procedure AddHeaders(ARequest: TRequest; AResponse: TResponse; var aContinue: boolean);
  end;

var
  SecurityStep: TSecurityStep;

function CleanHost(const Host: string): string;
var
  C: char;
begin
  Result := '';
  for C in LowerCase(Host) do
    if C in ['a'..'z', '0'..'9', '.', '-', ':', '[', ']'] then
      Result := Result + C
    else
      Exit('');
  if Length(Result) > 255 then
    Result := '';
end;

function SecurityPolicy(const Host: string; const FormsAlso: string): string;
var
  Live, Forms: string;
begin
  Live := '';
  if CleanHost(Host) <> '' then
    Live := ' wss://' + CleanHost(Host) + ' ws://' + CleanHost(Host);
  Forms := '';
  if FormsAlso <> '' then
    Forms := ' ' + FormsAlso;
  Result := 'default-src ''self''; script-src ''self''; style-src ''self'' ''unsafe-inline''; ' +
    'img-src ''self'' data: blob: https:; media-src ''self'' blob:; font-src ''self''; ' + 'connect-src ''self''' + Live +
    '; worker-src ''self''; manifest-src ''self''; frame-src ''none''; object-src ''none''; ' + 'base-uri ''self''; form-action ''self''' +
    Forms + '; frame-ancestors ''self''; report-uri /csp-report';
end;

procedure TSecurityStep.AddHeaders(ARequest: TRequest; AResponse: TResponse; var aContinue: boolean);
begin
  AResponse.SetCustomHeader('Content-Security-Policy', SecurityPolicy(ARequest.Host));
  AResponse.SetCustomHeader('X-Content-Type-Options', 'nosniff');
  AResponse.SetCustomHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  AResponse.SetCustomHeader('X-Frame-Options', 'SAMEORIGIN');
  AResponse.SetCustomHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=(), payment=(), usb=()');
  // browsers keep only what came over https
  AResponse.SetCustomHeader('Strict-Transport-Security', 'max-age=15552000');
end;

function Field(Obj: TJSONObject; const Names: array of string): string;
var
  Name: string;
begin
  Result := '';
  for Name in Names do
    if Obj.Find(Name) is TJSONString then
      Exit(Obj.Get(Name, ''));
end;

function OneLine(const S: string; Limit: integer): string;
var
  C: char;
begin
  Result := '';
  for C in S do
    if Length(Result) >= Limit then
      Break
    else if C < ' ' then
      Result := Result + ' '
    else
      Result := Result + C;
end;

function ReportLine(const Body: string): string;
var
  Data: TJSONData;
  Obj: TJSONObject;
begin
  Result := '';
  if (Body = '') or (Length(Body) > 16384) then
    Exit;
  try
    Data := GetJSON(Body);
  except
    Exit;
  end;
  try
    // the old form wraps it in csp-report; the Reporting API sends a list
    if (Data is TJSONArray) and (TJSONArray(Data).Count > 0) and (TJSONArray(Data)[0] is TJSONObject) then
      Obj := TJSONArray(Data).Objects[0]
    else if Data is TJSONObject then
      Obj := TJSONObject(Data)
    else
      Exit;
    if Obj.Find('csp-report') is TJSONObject then
      Obj := Obj.Objects['csp-report']
    else if Obj.Find('body') is TJSONObject then
      Obj := Obj.Objects['body'];
    Result := OneLine(Field(Obj, ['violated-directive', 'effectiveDirective', 'effective-directive']), 60) + ' blocked ' +
      OneLine(Field(Obj, ['blocked-uri', 'blockedURL']), 200) + ' on ' + OneLine(Field(Obj, ['document-uri', 'documentURL']), 200);
    if Trim(Result) = 'blocked  on' then
      Result := '';
  finally
    Data.Free;
  end;
end;

procedure TakeReport(ARequest: TRequest; AResponse: TResponse);
var
  Line: string;
begin
  // a few a minute from one address are plenty to see a broken page
  if not TooManyTries(ClientIp(ARequest), 'csp-report', 20, 1) then
  begin
    NoteTry(ClientIp(ARequest), 'csp-report');
    Line := ReportLine(ARequest.Content);
    if Line <> '' then
      Log('csp: ' + Line);
  end;
  AResponse.Code := 204;
  AResponse.Content := '';
end;

initialization
  SecurityStep := TSecurityStep.Create;
  HTTPRouter.RegisterInterceptor('security', @SecurityStep.AddHeaders);
  HTTPRouter.RegisterRoute('/csp-report', rmPost, @TakeReport);

finalization
  SecurityStep.Free;
end.
