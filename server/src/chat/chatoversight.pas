unit ChatOversight;

{ Private channel and conversation administration: who, when and how much,
  never content. Deleting removes messages and files but clears rather than
  removes dm_peers, so a locked conversation stays locked. Permissions and
  requests are in docs/API.md. }

{$mode objfpc}{$H+}

interface

implementation

uses
  Classes, SysUtils, fpjson, httpdefs, httproute, SiteDb, SiteSql, SiteUsers, ChatRooms, SiteFiles, SiteRoles, SiteBell, SiteAdmin, SiteGuard;

{ The members of each private channel, by the channel's id. }
function PrivateMembers: TJSONObject;
var
  Key: string;
begin
  Result := TJSONObject.Create;
  with Query('SELECT f.room_id, u.name FROM follows f JOIN rooms r ON r.id = f.room_id' + ' JOIN users u ON u.id = f.user_id' +
      ' WHERE r.kind = ''channel'' AND r.private = 1 ORDER BY f.room_id, u.name', []) do
  try
    while not EOF do
    begin
      Key := Fields[0].AsString;
      if Result.IndexOfName(Key) < 0 then
        Result.Add(Key, TJSONArray.Create);
      Result.Arrays[Key].Add(Fields[1].AsString);
      Next;
    end;
  finally
    Free;
  end;
end;

function PrivateChannels: TJSONArray;
var
  Members: TJSONObject;
  Key: string;
  Names: TJSONData;
begin
  Result := TJSONArray.Create;
  Members := PrivateMembers;
  try
    with Query('SELECT r.id, r.slug, r.title, COALESCE(u.name, ''''), r.message_count, ' + IsoTime('r.created') + ', ' + IsoTime('r.last_talk') +
        ', r.archived FROM rooms r LEFT JOIN users u ON u.id = r.owner_id' +
        ' WHERE r.kind = ''channel'' AND r.private = 1 ORDER BY COALESCE(r.last_talk, r.created) DESC', []) do
    try
      while not EOF do
      begin
        Key := Fields[0].AsString;
        if Members.IndexOfName(Key) >= 0 then
          Names := Members.Arrays[Key].Clone
        else
          Names := TJSONArray.Create;
        Result.Add(TJSONObject.Create(['slug', Fields[1].AsString, 'title', Fields[2].AsString, 'owner', Fields[3].AsString, 'members',
          Names, 'messages', Fields[4].AsInteger, 'created', Fields[5].AsString, 'last', Fields[6].AsString, 'archived', Fields[7].AsInteger = 1]));
        Next;
      end;
    finally
      Free;
    end;
  finally
    Members.Free;
  end;
end;

{ What is still on the server, so a conversation both sides deleted is not
  listed.  A thousand, the latest first, is far more than one person reads. }
function PrivateConversations: TJSONArray;
begin
  Result := TJSONArray.Create;
  with Query('SELECT ua.name, ub.name, d.n, ' + IsoTime('d.last_at') + ', COALESCE(p.locked, 0) FROM' + ' (SELECT LEAST(from_id, to_id) a, ' +
      SqlGreatest('from_id', 'to_id') + ' b, COUNT(*) n, MAX(created) last_at FROM dms GROUP BY a, b) d' + ' JOIN users ua ON ua.id = d.a JOIN users ub ON ub.id = d.b' +
      ' LEFT JOIN dm_peers p ON p.user_id = d.a AND p.other_id = d.b' + ' ORDER BY d.last_at DESC LIMIT 1000', []) do
  try
    while not EOF do
    begin
      Result.Add(TJSONObject.Create(['a', Fields[0].AsString, 'b', Fields[1].AsString, 'messages', Fields[2].AsInteger, 'last',
        Fields[3].AsString, 'locked', Fields[4].AsInteger = 1]));
      Next;
    end;
  finally
    Free;
  end;
end;

{ GET /api/admin/private }
procedure ShowPrivate(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
begin
  if NeedPermission(ARequest, AResponse, 'manage-private', Me) then
    SendJSON(AResponse, TJSONObject.Create(['channels', PrivateChannels, 'conversations', PrivateConversations]));
end;

{ The ids a query answers, read before anything is changed. }
function IdsFrom(const SQL: string; const Values: array of variant): TStringList;
begin
  Result := TStringList.Create;
  with Query(SQL, Values) do
  try
    while not EOF do
    begin
      Result.Add(Fields[0].AsString);
      Next;
    end;
  finally
    Free;
  end;
end;

procedure DeleteChannel(const Room: TRoom);
var
  Inside, Said: TStringList;
  Id, Icon: string;
begin
  Inside := IdsFrom('SELECT user_id FROM follows WHERE room_id = :r', [Room.Id]);
  Said := IdsFrom('SELECT id FROM messages WHERE room_id = :r', [Room.Id]);
  try
    for Id in Said do
      DeleteFilesOf(StrToInt(Id), 'message');
    Icon := Value('SELECT avatar FROM rooms WHERE id = :r', [Room.Id]);
    if Icon <> '' then
      DeleteFileByToken(Icon);
    Exec('DELETE x FROM reactions x JOIN messages m ON m.id = x.message_id WHERE m.room_id = :r', [Room.Id]);
    Exec('DELETE x FROM mentions x JOIN messages m ON m.id = x.message_id WHERE m.room_id = :r', [Room.Id]);
    Exec('DELETE x FROM message_rooms x JOIN messages m ON m.id = x.message_id WHERE m.room_id = :r', [Room.Id]);
    Exec('DELETE FROM message_rooms WHERE room_id = :r', [Room.Id]);
    Exec('DELETE FROM messages WHERE room_id = :r', [Room.Id]);
    Exec('DELETE FROM follows WHERE room_id = :r', [Room.Id]);
    Exec('DELETE FROM room_roles WHERE room_id = :r', [Room.Id]);
    Exec('DELETE FROM mutes WHERE room_id = :r', [Room.Id]);
    Exec('DELETE FROM presence WHERE room_id = :r', [Room.Id]);
    Exec('DELETE FROM typing WHERE room_id = :r', [Room.Id]);
    Exec('UPDATE users SET last_room = '''' WHERE last_room = :s', [Room.Slug]);
    Exec('DELETE FROM rooms WHERE id = :r', [Room.Id]);
    // Their pages leave it on this; IRC notices at its next check of the
    // member's channels.
    for Id in Inside do
      RingUser(StrToInt(Id), BellNote(['t', 'gone', 'room', Room.Slug]));
  finally
    Inside.Free;
    Said.Free;
  end;
end;

procedure DeleteConversation(UserA, UserB: integer);
var
  Said: TStringList;
  Id: string;
begin
  Said := IdsFrom('SELECT id FROM dms WHERE (from_id = :a AND to_id = :b) OR (from_id = :c AND to_id = :d)', [UserA, UserB, UserB, UserA]);
  try
    for Id in Said do
    begin
      DeleteFilesOf(StrToInt(Id), 'sealed');
      DeleteFilesOf(StrToInt(Id), 'dmfile');
    end;
  finally
    Said.Free;
  end;
  Exec('DELETE FROM dms WHERE (from_id = :a AND to_id = :b) OR (from_id = :c AND to_id = :d)', [UserA, UserB, UserB, UserA]);
  Exec('DELETE FROM dm_reactions WHERE NOT EXISTS (SELECT 1 FROM dms d WHERE d.id = dm_reactions.dm_id)', []);
  Exec('DELETE FROM beams WHERE (from_id = :a AND to_id = :b) OR (from_id = :c AND to_id = :d)', [UserA, UserB, UserB, UserA]);
  Exec('UPDATE dm_peers SET cleared_id = last_id, last_read_id = last_id' + ' WHERE (user_id = :a AND other_id = :b) OR (user_id = :c AND other_id = :d)',
    [UserA, UserB, UserB, UserA]);
  RingUser(UserA, BellNote(['t', 'dm', 'from', MemberById(UserB).Name, 'gone', True]));
  RingUser(UserB, BellNote(['t', 'dm', 'from', MemberById(UserA).Name, 'gone', True]));
end;

{ POST /api/admin/private/delete }
procedure DeletePrivate(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Room: TRoom;
  UserA, UserB: integer;
begin
  if not NeedPermission(ARequest, AResponse, 'manage-private', Me) then
    Exit;
  with ARequest.ContentFields do
    if Values['kind'] = 'channel' then
    begin
      Room := FindRoom(LowerCase(Trim(Values['slug'])));
      if (Room.Id = 0) or (Room.Kind <> 'channel') or not Room.Private then
        SendText(AResponse, 404, 'There is no private channel by that name.')
      else
      begin
        DeleteChannel(Room);
        SendText(AResponse, 200, 'Deleted #' + Room.Slug + '.');
      end;
    end
    else if Values['kind'] = 'conversation' then
    begin
      UserA := MemberId(Values['a']);
      UserB := MemberId(Values['b']);
      if (UserA = 0) or (UserB = 0) then
        SendText(AResponse, 404, 'No member by that name.')
      else
      begin
        DeleteConversation(UserA, UserB);
        SendText(AResponse, 200, 'Deleted the conversation between ' + MemberById(UserA).Name + ' and ' + MemberById(UserB).Name + '.');
      end;
    end
    else
      SendText(AResponse, 400, 'Say what to delete: a channel or a conversation.');
end;

{ POST /api/room/delete  slug - the owner takes a private channel away, whole }
procedure DeleteOwnChannel(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Room: TRoom;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  Room := FindRoom(LowerCase(Trim(ARequest.ContentFields.Values['slug'])));
  if (Room.Id = 0) or (Room.Kind <> 'channel') or not CanRead(Me, Room) then
    SendText(AResponse, 404, 'No channel by that name.')
  else if not Room.Private then
    SendText(AResponse, 403, 'A public channel is not deleted from here. Ask whoever runs the site.')
  else if not RoomCan(Me, 'delete-channel', Room) then
    SendText(AResponse, 403, 'Only the channel''s owner deletes it.')
  else
  begin
    DeleteChannel(Room);
    SendText(AResponse, 200, 'Deleted #' + Room.Slug + ', with everything said in it.');
  end;
end;

initialization
  RegisterAdminRoute('/api/admin/private', 'manage-private');
  RegisterAdminRoute('/api/admin/private/delete', 'manage-private');
  RegisterPermission('manage-private', 'See who has private channels and conversations, and delete them', 'admin');
  RegisterPermission('delete-channel', 'Delete a private channel, with everything in it', 'owner,admin');
  HTTPRouter.RegisterRoute('/api/admin/private', rmGet, @ShowPrivate);
  HTTPRouter.RegisterRoute('/api/admin/private/delete', rmPost, @DeletePrivate);
  HTTPRouter.RegisterRoute('/api/room/delete', rmPost, @DeleteOwnChannel);
end.
