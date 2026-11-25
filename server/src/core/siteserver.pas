unit SiteServer;

{ Starting the server: the config, the command line (see exedra.lpr), the
  web server and the chores.  This unit brings in the shared core only; the
  program names the parts it wants beside it (ChatPart for the chat), and
  each part plugs itself in. }

{$mode objfpc}{$H+}

interface

procedure RunServer;

implementation

uses
  {$ifdef CGI} fpcgi, SiteCgiGuard, {$else} fphttpapp, fphttpserver, SiteHttpGuard, CustApp, SiteLive, {$ifdef unix} SitePoll, {$endif} {$endif}
  SysUtils, httpdefs, httproute, SiteDb, SiteMarkup, SiteUsers, SiteLogins, SiteRoles, SiteFiles,
  SiteAdmin, SiteBugs, SiteGuard, WebPages, SiteStats, SiteBackup, SiteCrawlers, SiteVisitors, SiteAbuse, SiteSecurity, SiteNotices, SiteParts, SiteSearch, SiteVersion;

{$ifndef CGI}
type
  TServerEvents = class
    procedure RequestError(Sender: TObject; E: Exception);
    procedure RequestDone(ARequest: TRequest; AResponse: TResponse; var aContinue: boolean);
  end;

{ HAProxy's health check opens a connection and closes it without asking
  anything, every second; that is not worth a line in the log. }
procedure TServerEvents.RequestError(Sender: TObject; E: Exception);
begin
  if E.Message <> 'Error reading data from the socket' then
    Log('Request: ' + E.Message);
end;

{ Each request gives its database connection back when it is answered: the
  thread it ran on ends with its browser connection. }
procedure TServerEvents.RequestDone(ARequest: TRequest; AResponse: TResponse; var aContinue: boolean);
begin
  RequestAnswered;
  DoneConnection;
end;
{$endif}

{ A page that failed says so plainly, not with the framework's page naming
  the software and the error.  The log gets the addresses too, the failing
  one and its callers, for addr2line against the program. }
procedure ShowError(AResponse: TResponse; AnException: Exception; var Handled: boolean);
var
  Where: string;
  Frames: PCodePointer;
  I: integer;
begin
  Where := ' at ' + HexStr(ExceptAddr);
  Frames := ExceptFrames;
  for I := 0 to ExceptFrameCount - 1 do
    Where := Where + ' ' + HexStr(Frames[I]);
  Log('Error: ' + AnException.Message + Where);
  AResponse.Code := 500;
  AResponse.ContentType := 'text/plain; charset=utf-8';
  AResponse.Content := 'Something went wrong here. It is in the log.';
  if AnException is EHTTP then
    if (EHTTP(AnException).StatusCode >= 400) and (EHTTP(AnException).StatusCode < 500) then
    begin
      AResponse.Code := EHTTP(AnException).StatusCode;
      AResponse.Content := 'Request refused.';
      if AResponse.Code = 413 then
        AResponse.Content := 'The request body is too large.';
      if AResponse.Code = 405 then
        AResponse.Allow := 'GET, HEAD, POST';
    end;
  AResponse.SendContent;
  Handled := True;
  AccessLog(AResponse.Request, AResponse.Code);  // the router's after step is skipped too
  RequestAnswered;
  DoneConnection;  // a failed request skips RequestDone
end;

{ --Name anywhere on the command line. }
function HasSwitch(const Name: string): boolean;
var
  I: integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if ParamStr(I) = '--' + Name then
      Exit(True);
end;

procedure RunServer;
var
  {$ifndef CGI}
  Events: TServerEvents;
  {$endif}
  ConfigFile, Link: string;
  I: integer;
  ForRequest: boolean;
begin
  {$ifndef CGI}
  if CustomApplication = Application then
    CustomApplication := nil;
  Application.Free;
  Application := TGuardApplication.Create(nil);
  CustomApplication := Application;
  {$endif}
  // A CGI program started by a web server gets a query without an = sign
  // as its arguments (CGI/1.1), so a visitor could write --admin in an
  // address.  For a request, nothing on the command line is read.
  {$ifdef CGI}
  ForRequest := GetEnvironmentVariable('REQUEST_METHOD') <> '';
  {$else}
  ForRequest := False;
  {$endif}
  // asked before the site is opened: it needs no config file
  if not ForRequest and HasSwitch('version') then
  begin
    WriteLn('Exedra ', ExedraVersion);
    Exit;
  end;
  ConfigFile := ChangeFileExt(ParamStr(0), '.ini');
  if not ForRequest and (ParamCount > 0) and not ParamStr(1).StartsWith('--') then
    ConfigFile := ParamStr(1)
  // for a request the web server may name the file (SetEnv EXEDRA_CONFIG),
  // so it need not sit in a folder the web serves
  else if ForRequest and (GetEnvironmentVariable('EXEDRA_CONFIG') <> '') then
    ConfigFile := GetEnvironmentVariable('EXEDRA_CONFIG');
  OpenSite(ConfigFile);
  if not ForRequest and FindCmdLineSwitch('measure-storage') then
  begin
    MeasureStorage;
    DoneConnection;
    Exit;
  end;
  {$ifdef CGI}
  if GetEnvironmentVariable('REQUEST_METHOD') <> '' then
    if not AcceptCgiRequest then
      Exit;
  {$endif}
  if not ForRequest then
    for I := 1 to ParamCount do
      if ((ParamStr(I) = '--admin') or (ParamStr(I) = '--password-link') or (ParamStr(I) = '--restore')) and (I = ParamCount) then
      begin
        WriteLn(ParamStr(I), ' needs a name after it.');
        Halt(1);
      end
      else if ParamStr(I) = '--admin' then
      begin
        if MakeAdmin(ParamStr(I + 1)) then
          WriteLn(ParamStr(I + 1), ' is an admin now.')
        else
          WriteLn('No member called ', ParamStr(I + 1), '. They sign up first.');
        Halt;
      end
      else if ParamStr(I) = '--password-link' then
      begin
        Link := MakePasswordLink(ParamStr(I + 1));
        if Link = '' then
          WriteLn('No member called ', ParamStr(I + 1), '.')
        else
          WriteLn(Setting('url', ''), '/password/', Link);
        Halt;
      end
      else if ParamStr(I) = '--restore' then
      begin
        // the service stopped, as its user: the whole site from a backup file
        if CommandLineRestore(ParamStr(I + 1)) then
          Halt(0);
        Halt(1);
      end;
  if not ForRequest and HasSwitch('backup') then
  begin
    if CommandLineBackup(HasSwitch('pictures'), HasSwitch('logs')) then
      Halt(0);
    Halt(1);
  end;
  ApplyUploadLimit;
  LoadTemplates;
  RandomHex(1);  // the random source starts here, not in two threads at once
  {$ifndef CGI}
  Application.Port := Config.ReadInteger('site', 'port', 8099);
  Application.Address := Config.ReadString('site', 'address', '');
  // A thread for each browser connection, sleeping while it is quiet; live
  // connections get one each too (SiteLive).  Not FPC's thread pool: its
  // idle threads never sleep (their wait between looks for work is 0 ms and
  // cannot be set from outside, FPC trunk, 28 Oct 2026), which kept a whole
  // core busy on a quiet site.
  Application.HTTPHandler.HTTPServer.ThreadMode := tmThread;
  {$ifdef unix}
  // Past a thousand open connections FPC's select() waits go blind.
  Application.HTTPHandler.HTTPServer.OnGetSocketHandler := @PollHandlers.GetHandler;
  {$endif}
  Application.QueueSize := 512;
  Events := TServerEvents.Create;
  Application.HTTPHandler.OnRequestError := @Events.RequestError;
  HTTPRouter.RegisterInterceptor('done', @Events.RequestDone, iaAfter);
  StartLive(Application.HTTPHandler.HTTPServer);
  StartChores;
  {$endif}
  StartParts;
  Application.OnShowRequestException := @ShowError;
  Application.Initialize;
  Application.Run;
end;

end.
