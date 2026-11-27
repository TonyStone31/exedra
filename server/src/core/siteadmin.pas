unit SiteAdmin;

{ Site administration from registered settings and permissions. Each section
  needs its own permission, so a moderator can ban without gaining control
  of settings. }

{$mode objfpc}{$H+}

interface

uses
  Classes, httpdefs, fpjson, SiteUsers;

{ A tab of the admin page; After names the tab it follows, '' puts it last.
  Register during initialization; permissions are registered separately. }
procedure RegisterAdminSection(const Name, Caption, Permission: string; const After: string = '');

type
  TAdminPart = procedure(const Me: TMember; Answer: TJSONObject);

{ What a part adds to the answer of GET /api/admin. }
procedure RegisterAdminPart(Part: TAdminPart);
function AdminSectionsJSON(const Me: TMember): TJSONArray;
function CanOpenAdmin(const Me: TMember): boolean;
function NeedAdmin(ARequest: TRequest; AResponse: TResponse; out Me: TMember): boolean;

{ Uses the same refusal as an unknown page unless the member has permission. }
function NeedPermission(ARequest: TRequest; AResponse: TResponse; const Perm: string; out Me: TMember): boolean;
{ Whoever holds Perm may change the settings under the heading Group, as
  manage-settings may change them all: a module's admin, its own. }
procedure RegisterSettingsKeeper(const Group, Perm: string);

type
  { Sent holds name=value for each setting about to be saved.  The answer
    is why they cannot be, or '' when they can; a value may be put right
    in Sent (Sent[I] := 'name=value'). }
  TSettingsCheck = function(Sent: TStrings): string;

{ A unit's own look at the settings it registered, before they are saved. }
procedure RegisterSettingsCheck(Check: TSettingsCheck);

implementation

uses
  SysUtils, Variants, StrUtils, httproute, SiteDb, SiteSql,
  SiteFiles, SiteRoles, SiteBell, SiteGuard, SiteScan, SiteStats, SiteWords, SiteParts, SiteVersion;

type
  TAdminSection = record
    Name, Caption, Permission: string;
  end;

var
  AdminSections: array of TAdminSection;
  AdminParts: array of TAdminPart;

procedure RegisterAdminPart(Part: TAdminPart);
begin
  SetLength(AdminParts, Length(AdminParts) + 1);
  AdminParts[High(AdminParts)] := Part;
end;

procedure RegisterAdminSection(const Name, Caption, Permission: string; const After: string);
var
  I, Place: integer;
begin
  for I := 0 to High(AdminSections) do
    if AdminSections[I].Name = Name then
      raise Exception.Create('Duplicate admin section: ' + Name);
  if (Name = '') or (Permission = '') then
    raise Exception.Create('An admin section needs a name and permission.');
  SetLength(AdminSections, Length(AdminSections) + 1);
  Place := High(AdminSections);
  for I := 0 to High(AdminSections) - 1 do
    if AdminSections[I].Name = After then
      Place := I + 1;
  for I := High(AdminSections) downto Place + 1 do
    AdminSections[I] := AdminSections[I - 1];
  AdminSections[Place].Name := Name;
  AdminSections[Place].Caption := Caption;
  AdminSections[Place].Permission := Permission;
end;

function AdminSectionsJSON(const Me: TMember): TJSONArray;
var
  Section: TAdminSection;
begin
  Result := TJSONArray.Create;
  if (Me.Id = 0) or Me.Banned then
    Exit;
  for Section in AdminSections do
    if Can(Me, Section.Permission) then
      Result.Add(TJSONObject.Create(['name', Section.Name, 'caption', Say(Section.Caption), 'permission', Section.Permission]));
end;

var
  SettingsKeepers: TStringList = nil;

procedure RegisterSettingsKeeper(const Group, Perm: string);
begin
  if SettingsKeepers = nil then
    SettingsKeepers := TStringList.Create;
  SettingsKeepers.Values[Group] := Perm;
end;

{ Whether Me may see and change the settings under this heading. }
function KeepsSettings(const Me: TMember; const Group: string): boolean;
begin
  Result := Can(Me, 'manage-settings') or ((SettingsKeepers <> nil) and (SettingsKeepers.Values[Group] <> '') and Can(Me, SettingsKeepers.Values[Group]));
end;

function CanOpenAdmin(const Me: TMember): boolean;
var
  Section: TAdminSection;
begin
  Result := False;
  if (Me.Id = 0) or Me.Banned then
    Exit;
  for Section in AdminSections do
    if Can(Me, Section.Permission) then
      Exit(True);
end;

function NeedAdmin(ARequest: TRequest; AResponse: TResponse; out Me: TMember): boolean;
begin
  AResponse.SetCustomHeader('Cache-Control', 'private, no-store');
  Me := Default(TMember);
  if (ARequest.Authorization = '') and (ARequest.CookieFields.Values['sid'] = '') then
  begin
    RefuseAdmin(ARequest, AResponse);
    Exit(False);
  end;
  CheckConnection;
  Me := CurrentMember(ARequest);
  Result := CanOpenAdmin(Me);
  if not Result then
    RefuseAdmin(ARequest, AResponse);
end;

function NeedPermission(ARequest: TRequest; AResponse: TResponse; const Perm: string; out Me: TMember): boolean;
begin
  AResponse.SetCustomHeader('Cache-Control', 'private, no-store');
  Me := Default(TMember);
  if (ARequest.Authorization = '') and (ARequest.CookieFields.Values['sid'] = '') then
  begin
    RefuseAdmin(ARequest, AResponse);
    Exit(False);
  end;
  CheckConnection;
  Me := CurrentMember(ARequest);
  Result := (Me.Id > 0) and not Me.Banned and Can(Me, Perm);
  if not Result then
    RefuseAdmin(ARequest, AResponse)
  // a change sent by another site's page, as members' own forms refuse it
  else if (ARequest.Method <> 'GET') and (ARequest.Method <> 'HEAD') and FromAnotherSite(ARequest) then
  begin
    SendText(AResponse, 403, Say('Press it on this site.'));
    Result := False;
  end;
end;

type
  TValues = array of variant;

{ Q could be the start of an address: digits and dots, or hex and colons. }
function AddressLike(const Q: string): boolean;
var
  C: char;
begin
  Result := (Length(Q) >= 3) and ((Pos('.', Q) > 0) or (Pos(':', Q) > 0));
  for C in Q do
    if not (C in ['0'..'9', 'a'..'f', 'A'..'F', '.', ':']) then
      Exit(False);
end;

{ The members' WHERE: a name prefix, a role ('none' for no role given) and
  banned, closed or neither; the values for its parameters go in Values, in order.
  With Addresses (an admin who may see them), Q also finds the members who
  used an address starting with it. }
function MembersWhere(const Q, Role, State: string; out Values: TValues; Addresses: boolean = False): string;
begin
  if Addresses and AddressLike(Q) then
  begin
    Result := 'WHERE (name LIKE :q OR id IN (SELECT user_id FROM member_addresses WHERE ip LIKE :q2))';
    Values := [LikePrefix(Q), LikePrefix(LowerCase(Q))];
  end
  else
  begin
    Result := 'WHERE name LIKE :q';
    Values := [LikePrefix(Q)];
  end;
  if Role = 'none' then
    Result := Result + ' AND roles = '''''
  else if Role <> '' then
  begin
    Result := Result + ' AND FIND_IN_SET(:r, roles) > 0';
    SetLength(Values, Length(Values) + 1);
    Values[High(Values)] := Role;
  end;
  if State = 'banned' then
    Result := Result + ' AND banned = 1'
  else if State = 'closed' then
    Result := Result + ' AND closed = 1'
  else if State = 'active' then
    Result := Result + ' AND banned = 0 AND closed = 0';
end;

{ Each listed member's addresses, newest first (at most 10 each, with the
  count): only ever for an admin with view-member-addresses. }
procedure AddAddresses(List: TJSONArray; const Ids: string);
var
  I, Id: integer;
  Item: TJSONObject;
  Shown: TJSONArray;
begin
  if Ids = '' then
    Exit;
  // the ids are the list's own integers, joined here, never from the request
  with Query('SELECT user_id, ip, ' + IsoTime('last_seen') + ', hits FROM member_addresses WHERE user_id IN (' + Ids + ')' + ' ORDER BY last_seen DESC', []) do
  try
    while not EOF do
    begin
      Id := Fields[0].AsInteger;
      for I := 0 to List.Count - 1 do
      begin
        Item := List.Objects[I];
        if Item.Get('id', 0) <> Id then
          Continue;
        Shown := Item.Find('addresses') as TJSONArray;
        if Shown = nil then
        begin
          Shown := TJSONArray.Create;
          Item.Add('addresses', Shown);
        end;
        Item.Integers['address_count'] := Item.Get('address_count', 0) + 1;
        if Shown.Count < 10 then
          Shown.Add(TJSONObject.Create(['ip', Fields[1].AsString, 'seen', Fields[2].AsString, 'times', Fields[3].AsInteger]));
        Break;
      end;
      Next;
    end;
  finally
    Free;
  end;
  // the ids were only needed to match the rows
  for I := 0 to List.Count - 1 do
    List.Objects[I].Delete('id');
end;

function MembersJSON(const Q: string; Page: integer; const Sort: string = ''; const Role: string = ''; const State: string = ''; Addresses: boolean = False): TJSONArray;
var
  Order, Where, Ids: string;
  Values: TValues;
  Item: TJSONObject;
begin
  Result := TJSONArray.Create;
  // A name prefix uses the name index; no prefix lists the latest seen.
  // A column asked for wins: name, posts, joined or seen, '-' before it for the other way.
  if Q = '' then
    Order := 'last_seen DESC'
  else
    Order := 'name';
  case Sort of
    'name': Order := 'name';
    '-name': Order := 'name DESC';
    'posts': Order := 'posts, name';
    '-posts': Order := 'posts DESC, name';
    'joined': Order := 'created, name';
    '-joined': Order := 'created DESC, name';
    'seen': Order := 'last_seen, name';
    '-seen': Order := 'last_seen DESC, name';
  end;
  Where := MembersWhere(Q, Role, State, Values, Addresses);
  SetLength(Values, Length(Values) + 1);
  Values[High(Values)] := Page * 50;
  Ids := '';
  with Query('SELECT name, roles, banned, posts, ' + IsoTime('created') + ', ' + IsoTime('last_seen') + ', id, closed, ' + IsoTime('closed_at') +
      ', closed_reason, (SELECT c.name FROM users c WHERE c.id = users.closed_by) FROM users ' + Where + ' ORDER BY ' + Order + ' LIMIT 50 OFFSET :o', Values) do
  try
    while not EOF do
    begin
      Item := TJSONObject.Create(['name', Fields[0].AsString, 'roles', Fields[1].AsString, 'banned', Fields[2].AsInteger = 1, 'posts',
        Fields[3].AsInteger, 'joined', Fields[4].AsString, 'seen', Fields[5].AsString]);
      // a closed account: when, why, and who closed it (its own name: the member left)
      if Fields[7].AsInteger = 1 then
      begin
        Item.Add('closed', Fields[8].AsString);
        Item.Add('closed_reason', Fields[9].AsString);
        Item.Add('closed_by', Fields[10].AsString);
      end;
      if Addresses then
      begin
        Item.Add('id', Fields[6].AsInteger);
        Item.Add('address_count', 0);
        Ids := Ids + IfThen(Ids = '', '', ',') + IntToStr(Fields[6].AsInteger);
      end;
      Result.Add(Item);
      Next;
    end;
  finally
    Free;
  end;
  if Addresses then
    AddAddresses(Result, Ids);
end;

function MembersCount(const Q, Role, State: string; Addresses: boolean = False): int64;
var
  Values: TValues;
  Where: string;
begin
  Where := MembersWhere(Q, Role, State, Values, Addresses);
  Result := IntValue('SELECT COUNT(*) FROM users ' + Where, Values);
end;

{ GET /api/admin  what this member may run, and the lists for it }
procedure ShowAdmin(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  List: TJSONArray;
  Def: TSettingDef;
  Answer: TJSONObject;
  Part: TAdminPart;
begin
  if not NeedAdmin(ARequest, AResponse, Me) then
    Exit;
  Answer := TJSONObject.Create(['can', SitePermissions(Me), 'sections', AdminSectionsJSON(Me)]);
  if Can(Me, 'read-reports') then
    Answer.Add('open_reports', IntValue('SELECT COUNT(*) FROM bug_reports WHERE done = 0', []));
  if Can(Me, 'view-admin') then
  begin
    Answer.Add('members_total', IntValue('SELECT COUNT(*) FROM users WHERE closed = 0', []));
    Answer.Add('version', ExedraVersion);
    Answer.Add('unlisted_proxies', UnlistedProxies);
    Answer.Add('members', MembersJSON('', 0, '', '', '', Can(Me, 'view-member-addresses')));
  end;
  List := TJSONArray.Create;
  // A secret goes out as whether it is set, never as itself.
  for Def in SettingDefs do
    if KeepsSettings(Me, Def.Group) then
    begin
      if Def.Kind = 'secret' then
        List.Add(TJSONObject.Create(['name', Def.Name, 'caption', Def.Caption, 'kind', Def.Kind, 'group', Def.Group, 'value', '', 'set', Setting(Def.Name, '') <> '']))
      else
        List.Add(TJSONObject.Create(['name', Def.Name, 'caption', Def.Caption, 'kind', Def.Kind, 'group', Def.Group, 'value', Setting(Def.Name, Def.Default)]));
    end;
  if List.Count > 0 then
    Answer.Add('settings', List)
  else
    List.Free;
  Answer.Add('parts', PartsOn);
  for Part in AdminParts do
    Part(Me, Answer);
  if Can(Me, 'view-admin') or Can(Me, 'manage-permissions') then
    Answer.Add('roles', RolesJSON);
  if Can(Me, 'manage-permissions') then
    Answer.Add('permissions', PermissionsJSON);
  SendJSON(AResponse, Answer);
end;

procedure ShowVisitors(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
begin
  if NeedPermission(ARequest, AResponse, 'view-visitors', Me) then
    SendJSON(AResponse, VisitorsJSON);
end;

{ GET /api/admin/access?day=yyyy-mm-dd&n=200&ip=&agent=  the latest visits
  from the log, or one address's (one browser's at it); from= and to=
  instead of day=, as days or moments (yyyy-mm-ddThh:nn:ssZ), look through
  a window's logs, newest first, until n lines are found }
procedure ShowAccess(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  N, I, J: integer;
  FromDay, ToDay, Ip, Agent: string;
  Days: TStringList;
  Lines, More: TJSONArray;
begin
  if not NeedPermission(ARequest, AResponse, 'view-visitors', Me) then
    Exit;
  N := StrToIntDef(ARequest.QueryFields.Values['n'], 200);
  if (N < 1) or (N > 2000) then
    N := 200;
  Ip := ARequest.QueryFields.Values['ip'];
  // one browser at that address: a person, as the report counts them
  Agent := ARequest.QueryFields.Values['agent'];
  FromDay := ARequest.QueryFields.Values['from'];
  ToDay := ARequest.QueryFields.Values['to'];
  if (FromDay = '') or (ToDay = '') then
    Lines := AccessLines(ARequest.QueryFields.Values['day'], N, Ip, Agent)
  else
  begin
    // a day given whole is its first or last second
    if Length(FromDay) = 10 then
      FromDay := FromDay + 'T00:00:00Z';
    if Length(ToDay) = 10 then
      ToDay := ToDay + 'T23:59:59Z';
    Lines := TJSONArray.Create;
    Days := AccessLogDays;
    try
      // newest first, as each day's lines come
      for I := 0 to Days.Count - 1 do
        if (Days[I] >= Copy(FromDay, 1, 10)) and (Days[I] <= Copy(ToDay, 1, 10)) and (Lines.Count < N) then
        begin
          More := AccessLines(Days[I], N - Lines.Count, Ip, Agent, FromDay, ToDay);
          try
            for J := 0 to More.Count - 1 do
              Lines.Add(More.Objects[J].Clone);
          finally
            More.Free;
          end;
        end;
    finally
      Days.Free;
    end;
  end;
  SendJSON(AResponse, TJSONObject.Create(['day', ARequest.QueryFields.Values['day'], 'lines', Lines, 'kept_days', SettingInt('access_log_days', 14)]));
end;

procedure ShowStorage(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
begin
  if NeedPermission(ARequest, AResponse, 'view-storage', Me) then
    SendJSON(AResponse, StorageJSON);
end;

{ GET /api/admin/members?q=&page=&sort=&role=&state=  a page of 50 and how many match }
procedure ShowMembers(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Total: int64;
begin
  if NeedPermission(ARequest, AResponse, 'view-admin', Me) then
    with ARequest.QueryFields do
    begin
      // the count first: a list already built would be lost if it failed
      Total := MembersCount(Values['q'], Values['role'], Values['state'], Can(Me, 'view-member-addresses'));
      SendJSON(AResponse, TJSONObject.Create(['members', MembersJSON(Values['q'], StrToIntDef(Values['page'], 0), Values['sort'],
        Values['role'], Values['state'], Can(Me, 'view-member-addresses')), 'total', Total]));
    end;
end;

var
  SettingsChecks: array of TSettingsCheck;

procedure RegisterSettingsCheck(Check: TSettingsCheck);
begin
  SetLength(SettingsChecks, Length(SettingsChecks) + 1);
  SettingsChecks[High(SettingsChecks)] := Check;
end;

{ POST /api/admin/settings  name=value for each setting }
procedure SaveSettings(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Def: TSettingDef;
  Check: TSettingsCheck;
  Sent: TStringList;
  NewValue, Refusal: string;
  I: integer;
begin
  if not NeedAdmin(ARequest, AResponse, Me) then
    Exit;
  if FromAnotherSite(ARequest) then
  begin
    SendText(AResponse, 403, Say('Press it on this site.'));
    Exit;
  end;
  Sent := TStringList.Create;
  try
    // every setting sent has to be one this member keeps, and a value its
    // kind and its unit take, or nothing is saved
    for Def in SettingDefs do
      if ARequest.ContentFields.IndexOfName(Def.Name) >= 0 then
      begin
        NewValue := Trim(ARequest.ContentFields.Values[Def.Name]);
        if not KeepsSettings(Me, Def.Group) then
        begin
          RefuseAdmin(ARequest, AResponse);
          Exit;
        end;
        if (Def.Kind = 'number') and (StrToIntDef(NewValue, -1) < 0) then
        begin
          SendText(AResponse, 400, Def.Caption + ' has to be a number.');
          Exit;
        end;
        if Def.Kind.StartsWith('choice:') and not AnsiMatchStr(NewValue, Copy(Def.Kind, 8, MaxInt).Split(['|'])) then
        begin
          SendText(AResponse, 400, Def.Caption + ' has to be one of its choices.');
          Exit;
        end;
        // An empty secret box keeps the secret.
        if (Def.Kind <> 'secret') or (NewValue <> '') then
          Sent.Add(Def.Name + '=' + NewValue);
      end;
    for Check in SettingsChecks do
    begin
      Refusal := Check(Sent);
      if Refusal <> '' then
      begin
        SendText(AResponse, 400, Refusal);
        Exit;
      end;
    end;
    for I := 0 to Sent.Count - 1 do
      SaveSetting(Sent.Names[I], Copy(Sent.ValueFromIndex[I], 1, 2000));
  finally
    Sent.Free;
  end;
  ApplyUploadLimit;
  SendText(AResponse, 200, 'Saved.');
end;

{ POST /api/admin/member changes roles, ban, name, password link or account
  closure. ban needs ban; other changes need manage-members. Closed accounts
  allow only rename and reopen; callers cannot change their own account
  here. Fields are in docs/API.md. }
procedure SaveMember(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Name, Roles, Clean, R, Current, NewName, Refused, Reason: string;
  Id: integer;
  Strong: boolean;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  if not Can(Me, 'manage-members') and not Can(Me, 'ban') then
  begin
    RefuseAdmin(ARequest, AResponse);
    Exit;
  end;
  if FromAnotherSite(ARequest) then
  begin
    SendText(AResponse, 403, Say('Press it on this site.'));
    Exit;
  end;
  Name := ARequest.ContentFields.Values['name'];
  Id := MemberId(Name);
  Current := VarToStr(Value('SELECT roles FROM users WHERE id = :u', [Id]));
  if Id = 0 then
  begin
    SendText(AResponse, 404, 'No member by that name.');
    Exit;
  end;
  if Id = Me.Id then
  begin
    SendText(AResponse, 400, 'Ask another admin to change your own account.');
    Exit;
  end;
  with ARequest.ContentFields do
    if MemberClosed(Id) and ((IndexOfName('roles') >= 0) or (IndexOfName('banned') >= 0) or (Values['password_link'] = '1')) then
    begin
      SendText(AResponse, 409, 'This account is closed. Reopen it first.');
      Exit;
    end;
  // every right is checked before anything is changed
  if (ARequest.ContentFields.IndexOfName('banned') >= 0) and (not Can(Me, 'ban') or (Shielded(Current) and not HasRole(Me.Roles, 'admin'))) then
  begin
    SendText(AResponse, 403, 'Banning this member is not open to you.');
    Exit;
  end;
  // The account's name, a way into it, its end and its return: on staff for an
  // admin only, and never on someone who may do what the one asking may not.
  with ARequest.ContentFields do
    Strong := (IndexOfName('rename') >= 0) or (Values['password_link'] = '1') or (Values['close'] = '1') or (Values['reopen'] = '1');
  if Strong and not HasRole(Me.Roles, 'admin') then
  begin
    Refused := '';
    if not Can(Me, 'manage-members') or Shielded(Current) then
      Refused := 'x';
    for R in Current.Split([','], TStringSplitOptions.ExcludeEmpty) do
      if not HoldsAllOf(Me, Trim(R)) then
        Refused := 'x';
    if Refused <> '' then
    begin
      SendText(AResponse, 403, 'Changing this member''s account is not open to you.');
      Exit;
    end;
  end;
  if ARequest.ContentFields.IndexOfName('roles') >= 0 then
  begin
    if not Can(Me, 'manage-members') or (Shielded(Current) and not HasRole(Me.Roles, 'admin')) then
    begin
      SendText(AResponse, 403, 'Giving roles is for admins.');
      Exit;
    end;
    Roles := ARequest.ContentFields.Values['roles'];
    Clean := '';
    for R in Roles.Split([','], TStringSplitOptions.ExcludeEmpty) do
      // Only site roles an admin can give: not the automatic ones.
      if IsRole(Trim(R)) and not AnsiMatchText(Trim(R), ['member', 'guest', 'owner', 'room-moderator']) and
        (IntValue('SELECT COUNT(*) FROM roles WHERE name = :n AND scope = ''site''', [Trim(R)]) > 0) then
        if Clean = '' then
          Clean := Trim(R)
        else
          Clean := Clean + ',' + Trim(R);
    if (HasRole(Clean, 'admin') <> HasRole(Current, 'admin')) and not HasRole(Me.Roles, 'admin') then
    begin
      SendText(AResponse, 403, 'Only an admin makes or unmakes an admin.');
      Exit;
    end;
    // nobody hands out, or takes away, more than they may do themselves
    for R in (Clean + ',' + Current).Split([','], TStringSplitOptions.ExcludeEmpty) do
      if (HasRole(Clean, R) <> HasRole(Current, R)) and not HoldsAllOf(Me, R) then
      begin
        SendText(AResponse, 403, 'The role ' + R + ' may do things you may not, so it is not yours to give or take.');
        Exit;
      end;
    Exec('UPDATE users SET roles = :r WHERE id = :u', [Clean, Id]);
    Log(Me.Name + ' set the roles of ' + Name + ' to ' + Clean);
  end;
  if ARequest.ContentFields.IndexOfName('banned') >= 0 then
  begin
    Exec('UPDATE users SET banned = :b WHERE id = :u', [Ord(ARequest.ContentFields.Values['banned'] = '1'), Id]);
    if ARequest.ContentFields.Values['banned'] = '1' then
    begin
      Exec('DELETE FROM sessions WHERE user_id = :u', [Id]);
      DropUser(Id);
    end;
    Log(Me.Name + ' set banned=' + ARequest.ContentFields.Values['banned'] + ' for ' + Name);
  end;
  if ARequest.ContentFields.IndexOfName('rename') >= 0 then
  begin
    NewName := Trim(ARequest.ContentFields.Values['rename']);
    Refused := ChangeMemberName(Id, NewName);
    if Refused <> '' then
    begin
      SendText(AResponse, 400, Refused);
      Exit;
    end;
    Log(Me.Name + ' renamed ' + Name + ' to ' + NewName);
    Name := NewName;
  end;
  if ARequest.ContentFields.Values['close'] = '1' then
  begin
    // one line: it goes to the log too
    Reason := Trim(ARequest.ContentFields.Values['reason'].Replace(#13, ' ').Replace(#10, ' '));
    if Reason = '' then
      Refused := 'Say why the account is closed: the reason is kept with it.'
    else
      Refused := CloseMember(Id, Me.Id, Reason, Setting('closed_names', 'keep') = 'anonymous');
    if Refused <> '' then
    begin
      SendText(AResponse, 400, Refused);
      Exit;
    end;
    Log(Me.Name + ' closed the account of ' + Name + ': ' + Reason);
  end;
  if ARequest.ContentFields.Values['reopen'] = '1' then
  begin
    Refused := ReopenMember(Id);
    if Refused <> '' then
    begin
      SendText(AResponse, 400, Refused);
      Exit;
    end;
    Log(Me.Name + ' reopened the account of ' + Name);
  end;
  if ARequest.ContentFields.Values['password_link'] = '1' then
  begin
    Log(Me.Name + ' made a password link for ' + Name);
    SendText(AResponse, 200, Setting('url', '') + '/password/' + MakePasswordLink(Name));
  end
  else
    SendText(AResponse, 200, 'Saved.');
end;

{ POST /api/admin/permission  name, roles }
procedure SavePermission(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Name, Roles, R: string;
begin
  if not NeedPermission(ARequest, AResponse, 'manage-permissions', Me) then
    Exit;
  Name := ARequest.ContentFields.Values['name'];
  Roles := ARequest.ContentFields.Values['roles'];
  if not IsPermission(Name) then
  begin
    SendText(AResponse, 400, 'There is no permission by that name.');
    Exit;
  end;
  for R in Roles.Split([','], TStringSplitOptions.ExcludeEmpty) do
    if not IsRole(R) then
    begin
      SendText(AResponse, 400, 'There is no role called ' + R + '.');
      Exit;
    end;
  if not Can(Me, Name) then
  begin
    SendText(AResponse, 403, 'You can only hand out a permission you hold yourself.');
    Exit;
  end;
  SetPermissionRoles(Name, Roles);
  Log(Me.Name + ' gave ' + Name + ' to ' + Roles);
  SendText(AResponse, 200, 'Saved.');
end;

{ POST /api/admin/role  name, caption, scope (site or room), or delete=1 }
procedure SaveRole(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Name, Scope: string;
begin
  if not NeedPermission(ARequest, AResponse, 'manage-permissions', Me) then
    Exit;
  Name := LowerCase(Trim(ARequest.ContentFields.Values['name']));
  Scope := ARequest.ContentFields.Values['scope'];
  if Scope <> 'room' then
    Scope := 'site';
  if ARequest.ContentFields.Values['delete'] = '1' then
  begin
    if IntValue('SELECT COUNT(*) FROM roles WHERE name = :n AND builtin = 0', [Name]) = 0 then
    begin
      SendText(AResponse, 400, 'Only a role an admin made can be deleted.');
      Exit;
    end;
    DeleteRole(Name);
    SendText(AResponse, 200, 'Deleted.');
  end
  else if not ValidSlug(Name) or (Length(Name) > 30) then
    SendText(AResponse, 400, 'A role name is 2 to 30 lowercase letters, digits or hyphens.')
  else if IsRole(Name) then
    SendText(AResponse, 409, 'There is a role by that name.')
  else
  begin
    AddRole(Name, ARequest.ContentFields.Values['caption'], Scope);
    SendText(AResponse, 200, 'Saved.');
  end;
end;

initialization
  RegisterAdminRoute('/api/admin/settings', 'manage-settings');
  RegisterAdminRoute('/api/admin/member', 'manage-members|ban');
  RegisterAdminRoute('/api/admin/permission', 'manage-permissions');
  RegisterAdminRoute('/api/admin/role', 'manage-permissions');
  RegisterAdminSection('members', 'Members', 'view-admin');
  RegisterAdminSection('permissions', 'Permissions', 'manage-permissions');
  RegisterAdminSection('settings', 'Settings', 'manage-settings');
  RegisterAdminSection('reports', 'Reports', 'read-reports');
  RegisterAdminSection('blocked', 'Blocked', 'manage-blocks');
  RegisterAdminSection('visitors', 'Visitors', 'view-visitors');
  RegisterAdminSection('storage', 'Storage', 'view-storage');
  RegisterPermission('view-visitors', 'See visitor statistics', 'admin');
  RegisterPermission('view-storage', 'See storage measurements', 'admin');
  RegisterAdminRoute('/api/admin/visitors', 'view-visitors');
  RegisterAdminRoute('/api/admin/access', 'view-visitors');
  RegisterAdminRoute('/api/admin/storage', 'view-storage');
  HTTPRouter.RegisterRoute('/api/admin/visitors', rmGet, @ShowVisitors);
  HTTPRouter.RegisterRoute('/api/admin/access', rmGet, @ShowAccess);
  HTTPRouter.RegisterRoute('/api/admin/storage', rmGet, @ShowStorage);
  RegisterSetting('name', 'The site''s name', 'Exedra', 'text');
  RegisterSetting('access_log_days', 'Days the access log is kept (0: no log)', '14', 'number', 'Safety');
  RegisterSetting('tagline', 'The line under the site''s name', '', 'text');
  RegisterSetting('show_name', 'Show the name beside the logo', '1', 'yesno');
  RegisterSetting('robots', 'Search engines may list the site', '1', 'yesno');
  RegisterSetting('code_language', 'Code blocks that name no language are colored as', 'pascal', 'text');
  RegisterSetting('registration', 'New accounts', 'open', 'choice:open|closed', 'Members');
  RegisterSetting('signups_per_address', 'New accounts allowed from one address in a day', '10', 'number', 'Members');
  RegisterSetting('upload_max_mb', 'Largest file, in MB (32 MB transport cap)', '5', 'number', 'Files');
  RegisterSetting('user_quota_mb', 'Each member''s files together, in MB', '500', 'number', 'Files');
  RegisterSetting('images_only', 'Only pictures in channels', '0', 'yesno', 'Files');
  RegisterSetting('keep_days', 'Delete files after this many days (0 keeps them)', '0', 'number', 'Files');
  // SiteScan's, here so that the group follows Files on the admin page
  RegisterSetting('scan_files', 'Scan every file members upload for viruses', '0', 'yesno', 'File scanning');
  RegisterSetting('scan_command', 'Virus scanner, the file named last (clamscan or clamdscan with plain --options)', DefaultScanCommand,
    'longtext', 'File scanning');
  RegisterSetting('scan_unavailable', 'What a file gets when the scanner cannot be started or fails', 'allow', 'choice:allow|refuse', 'File scanning');
  RegisterSetting('scan_seconds', 'Seconds a scan of one file may take', '120', 'number', 'File scanning');
  RegisterPermission('view-admin', 'Open the admin page', 'moderator,admin');
  RegisterPermission('ban', 'Ban members from the whole site', 'moderator,admin');
  RegisterPermission('manage-members', 'Give members site roles, and make password links for members (as good as an admin over them)', 'admin');
  RegisterPermission('view-member-addresses', 'See the addresses members use', 'admin');
  RegisterPermission('manage-settings', 'Change the site''s settings', 'admin');
  RegisterPermission('manage-permissions', 'Change roles and the permissions the holder has', 'admin');
  HTTPRouter.RegisterRoute('/api/admin', rmGet, @ShowAdmin);
  HTTPRouter.RegisterRoute('/api/admin/members', rmGet, @ShowMembers);
  HTTPRouter.RegisterRoute('/api/admin/settings', rmPost, @SaveSettings);
  HTTPRouter.RegisterRoute('/api/admin/member', rmPost, @SaveMember);
  HTTPRouter.RegisterRoute('/api/admin/permission', rmPost, @SavePermission);
  HTTPRouter.RegisterRoute('/api/admin/role', rmPost, @SaveRole);
end.
