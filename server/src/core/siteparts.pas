unit SiteParts;

{ Optional site modules register their paths and scripts. A disabled module
  answers 404 and loads no scripts; its tables stay. The switch is a setting
  named for the module, editable in the admin page or [site] config. }

{$mode objfpc}{$H+}

interface

procedure RegisterPart(const Name, Caption: string; DefaultOn: boolean);
function PartOn(const Name: string): boolean;
{ Whether a part by that name registered itself. }
function PartKnown(const Name: string): boolean;
{ A program built around a part has it on from the start: a site's own unit
  calls this after the part registered itself. }
procedure PartDefaultOn(const Name: string);
{ Addresses that belong to a part: each one itself and everything under it. }
procedure RegisterPartPaths(const Part: string; const Paths: array of string);
{ The part an address belongs to, or ''. }
function PartOfPath(const Path: string): string;
{ A script the site's page loads while the part is on. }
procedure RegisterPartScript(const Part, Src: string);
{ The script that draws a part's tab on the admin page (a file under
  /static).  It is loaded only when the admin page is opened, and only by
  someone who holds one of Permissions (comma separated). }
procedure RegisterPartAdminScript(const Part, Src, Permissions: string);
{ The script tags of the parts that are on; Version goes on each address. }
function PartScriptTags(const Version: string): string;
{ The names of the parts that are on, separated by spaces. }
function PartsOn: string;

type
  TPartProc = procedure;
  TPartLink = function: string;

{ Work a part does when the program starts, after the site is open; it
  runs only while the part is on. }
procedure RegisterPartStart(const Part: string; Start: TPartProc);
procedure StartParts;
{ A part's link in the bar at the top of the site's pages: Make gives the
  whole <a>, or '' for none right now. }
procedure RegisterPartLink(const Part: string; Make: TPartLink);
{ A link of the site's own in the same bar, after the parts' links. }
procedure RegisterSiteLink(Make: TPartLink);
{ The links of the parts that are on, then the site's own. }
function PartLinks: string;
{ Where a part's own front page is.  A site with one part on opens there. }
procedure RegisterPartHome(const Part, Address: string);
{ The front page of the only part that is on; '' with none, several, or
  when that part named no front page. }
function OnlyPartHome: string;

implementation

uses
  SysUtils, httpdefs, httproute, SiteDb, SiteWords, SiteMarkup;

type
  TPart = record
    Name: string;
    DefaultOn: boolean;
  end;

  TPartPath = record
    Part, Path: string;
  end;

  TPartSwitch = class
    procedure Check(R: TRequest; S: TResponse; var ContinueRequest: boolean);
  end;

var
  Parts: array of TPart;
  Paths: array of TPartPath;
  Scripts: array of TPartPath;
  Starts: array of record
    Part: string;
    Start: TPartProc;
    end;
  Homes: array of TPartPath;
  Links: array of record
    Part: string;
    Make: TPartLink;
    end;
  Switch: TPartSwitch;

procedure RegisterPart(const Name, Caption: string; DefaultOn: boolean);
var
  I: integer;
begin
  for I := 0 to High(Parts) do
    if Parts[I].Name = Name then
      raise Exception.Create('Duplicate part: ' + Name);
  SetLength(Parts, Length(Parts) + 1);
  Parts[High(Parts)].Name := Name;
  Parts[High(Parts)].DefaultOn := DefaultOn;
  RegisterSetting(Name, Caption, IntToStr(Ord(DefaultOn)), 'yesno', 'Parts');
end;

procedure PartDefaultOn(const Name: string);
var
  I: integer;
begin
  for I := 0 to High(Parts) do
    if Parts[I].Name = Name then
      Parts[I].DefaultOn := True;
  // the admin page shows the same starting value
  for I := 0 to High(SettingDefs) do
    if (SettingDefs[I].Name = Name) and (SettingDefs[I].Group = 'Parts') then
      SettingDefs[I].Default := '1';
end;

function PartOn(const Name: string): boolean;
var
  I: integer;
begin
  for I := 0 to High(Parts) do
    if Parts[I].Name = Name then
      Exit(Setting(Name, IntToStr(Ord(Parts[I].DefaultOn))) = '1');
  Result := False;
end;

function PartKnown(const Name: string): boolean;
var
  I: integer;
begin
  Result := False;
  for I := 0 to High(Parts) do
    if Parts[I].Name = Name then
      Exit(True);
end;

procedure RegisterPartPaths(const Part: string; const Paths: array of string);
var
  P: string;
begin
  for P in Paths do
  begin
    SetLength(SiteParts.Paths, Length(SiteParts.Paths) + 1);
    SiteParts.Paths[High(SiteParts.Paths)].Part := Part;
    SiteParts.Paths[High(SiteParts.Paths)].Path := LowerCase(P);
  end;
end;

function PartOfPath(const Path: string): string;
var
  I, Best: integer;
  Lower: string;
begin
  Result := '';
  Best := 0;
  Lower := LowerCase(Path);
  // the longest registered address wins, so a part can own one under another's
  for I := 0 to High(Paths) do
    if (Length(Paths[I].Path) > Best) and ((Lower = Paths[I].Path) or Lower.StartsWith(Paths[I].Path + '/')) then
    begin
      Best := Length(Paths[I].Path);
      Result := Paths[I].Part;
    end;
end;

var
  AdminScripts: array of record
    Part, Src, Permissions: string;
    end;

procedure RegisterPartAdminScript(const Part, Src, Permissions: string);
begin
  SetLength(AdminScripts, Length(AdminScripts) + 1);
  AdminScripts[High(AdminScripts)].Part := Part;
  AdminScripts[High(AdminScripts)].Src := Src;
  AdminScripts[High(AdminScripts)].Permissions := Permissions;
end;

{ GET /parts-admin.js  tells the site's page which admin scripts there are,
  of the parts that are on. }
procedure ShowAdminScripts(ARequest: TRequest; AResponse: TResponse);
var
  I: integer;
  Perm, List, Text: string;
begin
  Text := '';
  for I := 0 to High(AdminScripts) do
    if PartOn(AdminScripts[I].Part) then
    begin
      List := '';
      for Perm in AdminScripts[I].Permissions.Split([','], TStringSplitOptions.ExcludeEmpty) do
      begin
        if List <> '' then
          List := List + ',';
        List := List + '"' + Trim(Perm) + '"';
      end;
      Text := Text + 'window.Chat.extras.adminScripts.push({src:"' + AdminScripts[I].Src + '",permissions:[' + List + ']});'#10;
    end;
  AResponse.ContentType := 'application/javascript; charset=utf-8';
  AResponse.SetCustomHeader('Cache-Control', 'private, no-store');
  AResponse.Content := Text;
  AResponse.SendContent;
end;

procedure RegisterPartScript(const Part, Src: string);
begin
  SetLength(Scripts, Length(Scripts) + 1);
  Scripts[High(Scripts)].Part := Part;
  Scripts[High(Scripts)].Path := Src;
end;

function PartScriptTags(const Version: string): string;
var
  I: integer;
begin
  Result := '';
  for I := 0 to High(Scripts) do
    if PartOn(Scripts[I].Part) then
      Result := Result + '<script src="' + Scripts[I].Path + '?v=' + Version + '"></script>'#10;
  // the admin scripts the parts registered, announced by one script of the core's
  if Length(AdminScripts) > 0 then
    Result := Result + '<script src="/parts-admin.js?v=' + Version + '"></script>'#10;
  Result := TrimRight(Result);
end;

function PartsOn: string;
var
  I: integer;
begin
  Result := '';
  for I := 0 to High(Parts) do
    if PartOn(Parts[I].Name) then
      Result := Result + Parts[I].Name + ' ';
  Result := TrimRight(Result);
end;

procedure RegisterPartStart(const Part: string; Start: TPartProc);
begin
  SetLength(Starts, Length(Starts) + 1);
  Starts[High(Starts)].Part := Part;
  Starts[High(Starts)].Start := Start;
end;

procedure StartParts;
var
  I: integer;
begin
  for I := 0 to High(Starts) do
    if PartOn(Starts[I].Part) then
      Starts[I].Start();
end;

procedure RegisterPartLink(const Part: string; Make: TPartLink);
begin
  SetLength(Links, Length(Links) + 1);
  Links[High(Links)].Part := Part;
  Links[High(Links)].Make := Make;
end;

{ The links an admin wrote for the bar: "Name=address, Name=address".
  An address starts with / or http:// or https://; anything else is left out. }
function OwnLinks(const Written: string): string;
var
  Item, Caption, Address: string;
  P: integer;
begin
  Result := '';
  for Item in Written.Split([',']) do
  begin
    P := Pos('=', Item);
    if P = 0 then
      Continue;
    Caption := Trim(Copy(Item, 1, P - 1));
    Address := Trim(Copy(Item, P + 1, MaxInt));
    if (Caption = '') or not (Address.StartsWith('/') or Address.StartsWith('https://') or Address.StartsWith('http://')) then
      Continue;
    Result := Result + '<a href="' + HtmlText(Address) + '">' + HtmlText(Caption) + '</a>';
  end;
end;

function PartLinks: string;
var
  I: integer;
begin
  Result := '';
  for I := 0 to High(Links) do
    if (Links[I].Part <> '') and PartOn(Links[I].Part) then
      Result := Result + Links[I].Make();
  for I := 0 to High(Links) do
    if Links[I].Part = '' then
      Result := Result + Links[I].Make();
  Result := Result + OwnLinks(Setting('side_links', ''));
end;

procedure RegisterSiteLink(Make: TPartLink);
begin
  RegisterPartLink('', Make);
end;

procedure RegisterPartHome(const Part, Address: string);
begin
  SetLength(Homes, Length(Homes) + 1);
  Homes[High(Homes)].Part := Part;
  Homes[High(Homes)].Path := Address;
end;

function OnlyPartHome: string;
var
  I: integer;
  Only: string;
begin
  Result := '';
  Only := PartsOn;
  if (Only = '') or (Pos(' ', Only) > 0) then
    Exit;
  for I := 0 to High(Homes) do
    if Homes[I].Part = Only then
      Exit(Homes[I].Path);
end;

procedure TPartSwitch.Check(R: TRequest; S: TResponse; var ContinueRequest: boolean);
var
  Part: string;
begin
  ContinueRequest := True;
  Part := PartOfPath(HTTPDecode(R.PathInfo));
  if (Part = '') or PartOn(Part) then
    Exit;
  ContinueRequest := False;
  SetRequestLanguage(CookieLanguage(R));
  S.Code := 404;
  S.ContentType := 'text/plain; charset=utf-8';
  S.SetCustomHeader('Cache-Control', 'private, no-store');
  S.Content := Say('Nothing here.');
  S.SendContent;
end;

initialization
  HTTPRouter.RegisterRoute('/parts-admin.js', rmGet, @ShowAdminScripts);
  Switch := TPartSwitch.Create;
  HTTPRouter.RegisterInterceptor('parts', @Switch.Check);

finalization
  HTTPRouter.UnRegisterInterceptor('parts');
  Switch.Free;
end.
