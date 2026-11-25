unit DeskStatus;

{$mode objfpc}{$H+}

interface

uses SysUtils;

type
  TConnectionFailure = (cfOther, cfUnreachable, cfServer, cfSignIn);

function ConnectionFailure(Status: integer): TConnectionFailure;
function RetryDelaySeconds(Attempt, Jitter: integer): integer;
function RetrySecondsLeft(Due, NowTick: QWord): integer;
function ServerWords(const Address: string): string;
function ConnectionWords(const Address: string; Status, Seconds: integer): string;
function MemberDate(const Stamp: string): string;
function ChannelPolicy(const Policy: string): string;

implementation

uses DateUtils, Math, URIParser;

function ConnectionFailure(Status: integer): TConnectionFailure;
begin
  case Status of
    0: Result := cfUnreachable;
    401: Result := cfSignIn;
    500..599: Result := cfServer;
    else
      Result := cfOther;
  end;
end;

function RetryDelaySeconds(Attempt, Jitter: integer): integer;
var
  Base: integer;
begin
  Base := Min(60, 4 shl EnsureRange(Attempt, 0, 4));
  // Equal jitter keeps every attempt spread out, including at the cap.
  Result := Base div 2 + EnsureRange(Jitter, 0, 1000) * (Base div 2) div 1000;
end;

function RetrySecondsLeft(Due, NowTick: QWord): integer;
begin
  if Due <= NowTick then Exit(0);
  Result := (Due - NowTick + 999) div 1000;
end;

function ServerWords(const Address: string): string;
var
  URI: TURI;
  URL: string;
begin
  URL := Trim(Address);
  if Pos('://', URL) = 0 then URL := 'https://' + URL;
  URI := ParseURI(URL);
  Result := URI.Host;
  if Result = '' then Exit('the server');
  if (URI.Port <> 0) and not (SameText(URI.Protocol, 'http') and (URI.Port = 80)) and not (SameText(URI.Protocol, 'https') and (URI.Port = 443)) then
    Result := Result + ':' + IntToStr(URI.Port);
end;

function ConnectionWords(const Address: string; Status, Seconds: integer): string;
begin
  if Status = 401 then Exit('Your sign-in has ended.');
  if Status = 503 then
    Result := 'The server is being restored and will be back.'
  else
    Result := 'Lost the connection to ' + ServerWords(Address) + '.';
  if ConnectionFailure(Status) = cfUnreachable then
    Result := Result + ' No network or the server is unreachable.'
  else if (ConnectionFailure(Status) = cfServer) and (Status <> 503) then
    Result := Result + ' The server returned HTTP ' + IntToStr(Status) + '.';
  if Seconds > 0 then
    Result := Result + ' Trying again in ' + IntToStr(Seconds) + ' s.'
  else
    Result := Result + ' Trying again...';
end;

function MemberDate(const Stamp: string): string;
var
  D: TDateTime;
begin
  if Stamp = '' then Exit('Not known');
  if not TryISO8601ToDate(Stamp, D, True) then Exit('Not known');
  Result := FormatDateTime('mmm d, yyyy, h:nn am/pm', UniversalTimeToLocal(D));
end;

function ChannelPolicy(const Policy: string): string;
begin
  if Policy = 'readonly' then Result := 'Read only'
  else
    Result := 'Everyone posts';
end;

end.
