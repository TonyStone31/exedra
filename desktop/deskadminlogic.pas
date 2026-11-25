unit DeskAdminLogic;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, DeskNet;

type
  TMemberActions = record
    Roles, Ban: boolean;
  end;

function AdminCan(Permissions: TStrings; const Permission: string): boolean;
function MemberActions(Permissions: TStrings; const MyName, Name: string): TMemberActions;
function GiveableRole(Role: TJSONObject): boolean;
function MemberHasRole(const Roles, Role: string): boolean;
function SetMemberRole(const Roles, Role: string; Give: boolean): string;
function AdminMembersPath(const Filter: string; Page: integer): string;
procedure AdminMemberRoles(const Name, Roles: string; Done: TApiDone; Generation: integer);
procedure AdminMemberBan(const Name: string; Banned: boolean; Done: TApiDone; Generation: integer);
procedure AdminChannelSave(const Slug, Topic, Policy: string; Archived: boolean; Done: TApiDone; Generation: integer);

implementation

function AdminCan(Permissions: TStrings; const Permission: string): boolean;
begin
  Result := (Permissions <> nil) and (Permissions.IndexOf(Permission) >= 0);
end;

function MemberActions(Permissions: TStrings; const MyName, Name: string): TMemberActions;
begin
  Result.Roles := (MyName <> '') and (Name <> '') and not SameText(MyName, Name) and AdminCan(Permissions, 'manage-members');
  Result.Ban := (MyName <> '') and (Name <> '') and not SameText(MyName, Name) and AdminCan(Permissions, 'ban');
end;

function GiveableRole(Role: TJSONObject): boolean;
var
  Name: string;
begin
  Result := False;
  if Role = nil then Exit;
  Name := Role.Get('name', '');
  Result := (Role.Get('scope', '') = 'site') and (Name <> '') and (Name <> 'member') and (Name <> 'guest') and (Name <> 'owner') and (Name <> 'room-moderator');
end;

function MemberHasRole(const Roles, Role: string): boolean;
begin
  Result := (Role <> '') and (Pos(',' + Role + ',', ',' + Roles + ',') > 0);
end;

function SetMemberRole(const Roles, Role: string; Give: boolean): string;
var
  Current: string;
begin
  Result := '';
  for Current in Roles.Split([','], TStringSplitOptions.ExcludeEmpty) do
    if Current <> Role then
    begin
      if Result <> '' then Result := Result + ',';
      Result := Result + Current;
    end;
  if Give and (Role <> '') then
  begin
    if Result <> '' then Result := Result + ',';
    Result := Result + Role;
  end;
end;

function AdminMembersPath(const Filter: string; Page: integer): string;
begin
  if Page < 0 then Page := 0;
  Result := '/api/admin/members?' + Query(['q', Trim(Filter), 'sort', '-seen', 'page', IntToStr(Page)]);
end;

procedure AdminMemberRoles(const Name, Roles: string; Done: TApiDone; Generation: integer);
begin
  ApiPostAsync('/api/admin/member', ['name', Name, 'roles', Roles], Done, Generation, '', Name);
end;

procedure AdminMemberBan(const Name: string; Banned: boolean; Done: TApiDone; Generation: integer);
begin
  ApiPostAsync('/api/admin/member', ['name', Name, 'banned', IntToStr(Ord(Banned))], Done, Generation, '', Name);
end;

procedure AdminChannelSave(const Slug, Topic, Policy: string; Archived: boolean; Done: TApiDone; Generation: integer);
begin
  ApiPostAsync('/api/admin/channel', ['slug', Slug, 'topic', Topic, 'policy', Policy, 'archived', IntToStr(Ord(Archived))], Done, Generation, '', Slug);
end;

end.
