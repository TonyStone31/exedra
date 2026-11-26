unit SiteRoles;

{ Registered site and room permissions and roles, editable by admins. member
  and guest are implicit; owner and room-moderator apply within a room.
  Modules may register their own roles. Admins always have permission; muted
  members cannot post or react in that room. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, SiteUsers;

procedure RegisterPermission(const Name, Caption, DefaultRoles: string);
{ A site role a module brings, with the permissions it holds at first
  (comma separated).  It is added to them once, when the role is new to
  the site; what an admin changes afterward stays. }
procedure RegisterRole(const Name, Caption, Permissions: string);
{ Whether Me may do Perm, by site roles. }
{ Reads who may do what from the table again: after a restore. }
procedure LoadGrants;
function Can(const Me: TMember; const Perm: string): boolean;
{ Whether Me may do Perm in a room, by site roles and roles in the room. }
function CanIn(const Me: TMember; const Perm: string; RoomId, OwnerId: integer): boolean;
function IsMuted(UserId, RoomId: integer): boolean;
{ The site permissions Me has, for the page to know what to show. }
function SitePermissions(const Me: TMember): TJSONArray;
{ The role shown beside a name: admin, moderator, bot, or ''. }
function Badge(const Roles: string): string;
{ The same inside one module ('forum', 'chat'...), where that module's own
  moderators and admins show as such too. }
function BadgeIn(const Roles, Part: string): string;
{ Whether these roles are staff a moderator cannot ban: an admin, or
  anyone whose role may ban or open the admin page. }
function Shielded(const Roles: string): boolean;
function HasRole(const Roles, Role: string): boolean;
{ Whether Me may do everything the role may: the most a member can hand
  to someone else, or take from them. }
function HoldsAllOf(const Me: TMember; const Role: string): boolean;
{ For the admin page. }
function RolesJSON: TJSONArray;
function PermissionsJSON: TJSONArray;
function IsRole(const Name: string): boolean;
{ Whether a unit registered a permission by this name. }
function IsPermission(const Name: string): boolean;
procedure SetPermissionRoles(const Perm, Roles: string);
procedure AddRole(const Name, Caption, Scope: string);
procedure DeleteRole(const Name: string);

implementation

uses
  StrUtils, SiteDb, SiteSql;

type
  TPermission = record
    Name, Caption, Default: string;
  end;

  TModuleRole = record
    Name, Caption, Permissions: string;
  end;

var
  Defs: array of TPermission;
  ModuleRoles: array of TModuleRole;
  { name=role,role for every permission, as the database has it. }
  Granted: TStringList;
  GrantLock: TRTLCriticalSection;

const
  BuiltIn: array[0..6, 0..2] of string = (
    ('admin', 'Runs the site; may do everything', 'site'),
    ('moderator', 'Keeps the peace everywhere', 'site'),
    ('bot', 'An account a program runs', 'site'),
    ('member', 'Everyone signed in', 'site'),
    ('guest', 'Anyone not signed in, and banned members', 'site'),
    ('owner', 'Opened the channel', 'room'),
    ('room-moderator', 'Named by the channel''s owner', 'room'));
  { What a muted member cannot do in that room. }
  TalkPermissions: array[0..2] of string = ('post', 'react', 'upload');

procedure RegisterPermission(const Name, Caption, DefaultRoles: string);
begin
  SetLength(Defs, Length(Defs) + 1);
  Defs[High(Defs)].Name := Name;
  Defs[High(Defs)].Caption := Caption;
  Defs[High(Defs)].Default := DefaultRoles;
end;

procedure RegisterRole(const Name, Caption, Permissions: string);
begin
  SetLength(ModuleRoles, Length(ModuleRoles) + 1);
  ModuleRoles[High(ModuleRoles)].Name := Name;
  ModuleRoles[High(ModuleRoles)].Caption := Caption;
  ModuleRoles[High(ModuleRoles)].Permissions := Permissions;
end;

function HasRole(const Roles, Role: string): boolean;
begin
  Result := AnsiMatchText(Role, Roles.Split([','], TStringSplitOptions.ExcludeEmpty));
end;

procedure LoadGrants;
begin
  EnterCriticalSection(GrantLock);
  try
    Granted.Clear;
    with Query('SELECT name, roles FROM permissions', []) do
    try
      while not EOF do
      begin
        Granted.Add(Fields[0].AsString + '=' + Fields[1].AsString);
        Next;
      end;
    finally
      Free;
    end;
  finally
    LeaveCriticalSection(GrantLock);
  end;
end;

function RolesFor(const Perm: string): string; forward;

procedure Seed;
var
  I: integer;
  P: TPermission;
  M: TModuleRole;
  Perm, Have: string;
begin
  for I := 0 to High(BuiltIn) do
    Exec(SqlInsertIgnore('roles', 'name, caption, scope, builtin', ':n, :c, :s, 1'),
      [BuiltIn[I, 0], BuiltIn[I, 1], BuiltIn[I, 2]]);
  for P in Defs do
    Exec(SqlInsertIgnore('permissions', 'name, roles', ':n, :r'), [P.Name, P.Default]);
  LoadGrants;
  // a module's role, new to this site, takes its first permissions
  for M in ModuleRoles do
    if not IsRole(M.Name) then
    begin
      Exec('INSERT INTO roles (name, caption, scope, builtin) VALUES (:n, :c, ''site'', 1)', [M.Name, M.Caption]);
      for Perm in M.Permissions.Split([','], TStringSplitOptions.ExcludeEmpty) do
      begin
        Have := RolesFor(Trim(Perm));
        if HasRole(Have, M.Name) then Continue;
        if Have <> '' then Have := Have + ',';
        SetPermissionRoles(Trim(Perm), Have + M.Name);
      end;
    end;
end;

function RolesFor(const Perm: string): string;
var
  I: integer;
begin
  EnterCriticalSection(GrantLock);
  try
    I := Granted.IndexOfName(Perm);
    if I >= 0 then
      Result := Granted.ValueFromIndex[I]
    else
      Result := '';
  finally
    LeaveCriticalSection(GrantLock);
  end;
end;

{ The site roles a member has right now, comma separated. }
function HeldRoles(const Me: TMember): string;
begin
  if (Me.Id = 0) or Me.Banned then
    Result := 'guest'
  else
    Result := Me.Roles + ',member';
end;

function AnyRole(const Have, Need: string): boolean;
var
  R: string;
begin
  Result := False;
  for R in Have.Split([','], TStringSplitOptions.ExcludeEmpty) do
    if HasRole(Need, R) then
      Exit(True);
end;

function IsAdminRole(const Me: TMember): boolean;
begin
  Result := (Me.Id > 0) and not Me.Banned and HasRole(Me.Roles, 'admin');
end;

function Can(const Me: TMember; const Perm: string): boolean;
begin
  Result := IsAdminRole(Me) or AnyRole(HeldRoles(Me), RolesFor(Perm));
end;

function HoldsAllOf(const Me: TMember; const Role: string): boolean;
var
  P: TPermission;
begin
  Result := True;
  for P in Defs do
    if HasRole(RolesFor(P.Name), Role) and not Can(Me, P.Name) then
      Exit(False);
end;

function IsMuted(UserId, RoomId: integer): boolean;
begin
  Result := IntValue('SELECT COUNT(*) FROM mutes WHERE room_id = :r AND user_id = :u' + ' AND (until IS NULL OR until > NOW())', [RoomId, UserId]) > 0;
end;

function CanIn(const Me: TMember; const Perm: string; RoomId, OwnerId: integer): boolean;
var
  Have: string;
begin
  if IsAdminRole(Me) then
    Exit(True);
  Have := HeldRoles(Me);
  if (Me.Id > 0) and not Me.Banned then
  begin
    if AnsiMatchStr(Perm, TalkPermissions) and IsMuted(Me.Id, RoomId) then
      Exit(False);
    if OwnerId = Me.Id then
      Have := Have + ',owner';
    with Query('SELECT role FROM room_roles WHERE room_id = :r AND user_id = :u', [RoomId, Me.Id]) do
    try
      while not EOF do
      begin
        Have := Have + ',' + Fields[0].AsString;
        Next;
      end;
    finally
      Free;
    end;
  end;
  Result := AnyRole(Have, RolesFor(Perm));
end;

function SitePermissions(const Me: TMember): TJSONArray;
var
  P: TPermission;
begin
  Result := TJSONArray.Create;
  for P in Defs do
    if Can(Me, P.Name) then
      Result.Add(P.Name);
end;

function Badge(const Roles: string): string;
begin
  if HasRole(Roles, 'admin') then
    Result := 'admin'
  else if HasRole(Roles, 'moderator') then
    Result := 'moderator'
  else if HasRole(Roles, 'bot') then
    Result := 'bot'
  else
    Result := '';
end;

function BadgeIn(const Roles, Part: string): string;
begin
  Result := Badge(Roles);
  if (Result = 'admin') or (Result = 'moderator') then Exit;
  if HasRole(Roles, Part + '-admin') then
    Result := 'admin'
  else if HasRole(Roles, Part + '-moderator') then
    Result := 'moderator';
end;

function Shielded(const Roles: string): boolean;
begin
  Result := HasRole(Roles, 'admin') or AnyRole(Roles, RolesFor('ban')) or AnyRole(Roles, RolesFor('view-admin'));
end;

function RolesJSON: TJSONArray;
begin
  Result := TJSONArray.Create;
  with Query('SELECT name, caption, scope, builtin FROM roles ORDER BY builtin DESC, scope DESC, name', []) do
  try
    while not EOF do
    begin
      Result.Add(TJSONObject.Create(['name', Fields[0].AsString, 'caption', Fields[1].AsString, 'scope', Fields[2].AsString, 'builtin', Fields[3].AsInteger = 1]));
      Next;
    end;
  finally
    Free;
  end;
end;

function PermissionsJSON: TJSONArray;
var
  P: TPermission;
begin
  Result := TJSONArray.Create;
  for P in Defs do
    Result.Add(TJSONObject.Create(['name', P.Name, 'caption', P.Caption, 'roles', RolesFor(P.Name)]));
end;

function IsRole(const Name: string): boolean;
begin
  Result := IntValue('SELECT COUNT(*) FROM roles WHERE name = :n', [Name]) > 0;
end;

function IsPermission(const Name: string): boolean;
var
  P: TPermission;
begin
  Result := False;
  for P in Defs do
    if P.Name = Name then
      Exit(True);
end;

procedure SetPermissionRoles(const Perm, Roles: string);
begin
  Exec(SqlReplace('permissions', 'name, roles', ':n, :r'), [Perm, Copy(Roles, 1, 500)]);
  LoadGrants;
end;

procedure AddRole(const Name, Caption, Scope: string);
begin
  Exec('INSERT INTO roles (name, caption, scope, builtin) VALUES (:n, :c, :s, 0)',
    [Name, Copy(Caption, 1, 100), Scope]);
end;

procedure DeleteRole(const Name: string);
var
  P: TPermission;
  Left: string;
  R: string;
begin
  // a role the program brings stays, with its members and its permissions
  if IntValue('SELECT COUNT(*) FROM roles WHERE name = :n AND builtin = 0', [Name]) = 0 then
    Exit;
  Exec('DELETE FROM roles WHERE name = :n AND builtin = 0', [Name]);
  Exec('DELETE FROM room_roles WHERE role = :n', [Name]);
  Exec('UPDATE users SET roles = TRIM(BOTH '','' FROM REPLACE(' + SqlConcat([''',''', 'roles', ''',''']) + ', ' + SqlConcat([''',''', ':n', ''',''']) +
    ', '',''))' + ' WHERE FIND_IN_SET(:n2, roles)', [Name, Name]);
  for P in Defs do
    if HasRole(RolesFor(P.Name), Name) then
    begin
      Left := '';
      for R in RolesFor(P.Name).Split([',']) do
        if R <> Name then
          if Left = '' then
            Left := R
          else
            Left := Left + ',' + R;
      SetPermissionRoles(P.Name, Left);
    end;
end;

{ A closed account holds no role in any room. }
procedure ForgetRoomRoles(UserId: integer);
begin
  Exec('DELETE FROM room_roles WHERE user_id = :u', [UserId]);
end;

procedure ForgetOldMutes;
begin
  Exec('DELETE FROM mutes WHERE until < NOW()', []);
end;

initialization
  InitCriticalSection(GrantLock);
  Granted := TStringList.Create;
  RegisterTable('CREATE TABLE IF NOT EXISTS roles (' + ' name VARCHAR(30) PRIMARY KEY, caption VARCHAR(100) NOT NULL DEFAULT '''',' +
    ' scope VARCHAR(4) NOT NULL DEFAULT ''site'', builtin TINYINT NOT NULL DEFAULT 0' + ') CHARACTER SET utf8mb4');
  RegisterTable('CREATE TABLE IF NOT EXISTS permissions (' + ' name VARCHAR(40) PRIMARY KEY, roles VARCHAR(500) NOT NULL DEFAULT ''''' + ') CHARACTER SET utf8mb4');
  RegisterTable('CREATE TABLE IF NOT EXISTS room_roles (' + ' room_id INT NOT NULL, user_id INT NOT NULL, role VARCHAR(30) NOT NULL,' +
    ' PRIMARY KEY (room_id, user_id, role), INDEX (user_id)) CHARACTER SET utf8mb4');
  RegisterTable('CREATE TABLE IF NOT EXISTS mutes (' + ' room_id INT NOT NULL, user_id INT NOT NULL, until DATETIME NULL,' + ' PRIMARY KEY (room_id, user_id))');
  RegisterStartup(@Seed);
  RegisterCloseMemberHook(@ForgetRoomRoles);
  RegisterChore(@ForgetOldMutes, 10);
end.
