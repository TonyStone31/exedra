unit ChatRooms;

{ Rooms, membership, following, presence and typing. Following stores the
  last message read for unread counts; new members follow public channels.
  Private rooms are visible only to followers, admitted by invitation.
  Presence and typing record each member's latest location and time. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, httpdefs, SiteUsers;

type
  TRoom = record
    Id: integer;
    Slug: string;
    Kind: string;
    Title: string;
    Topic: string;
    OwnerId: integer;
    Policy: string;      // who starts messages: all, readonly (post-readonly) or owner
    Archived: boolean;
    Private: boolean;
  end;

  { Adds what a module knows about a room to its info. }
  TRoomInfoHook = procedure(const Room: TRoom; const Me: TMember; Info: TJSONObject);

function FindRoom(const Slug: string): TRoom;
function RoomById(Id: integer): TRoom;
{ Public rooms only: names written as #name link to these. }
function RoomExists(const Slug: string): boolean;
function CreateRoom(const Slug, Kind, Title, Topic: string; OwnerId: integer; const Policy: string; IsPrivate: boolean = False): integer;
function IsFollower(UserId, RoomId: integer): boolean;
{ Whether Me may read the room at all. }
function CanRead(const Me: TMember; const Room: TRoom): boolean;
{ The channel a member opened last, while they may still read it; an empty
  room otherwise, and always for someone not signed in. }
function LastRoom(const Me: TMember): TRoom;
{ Whether a message that names a public channel also shows there: the
  cross_post setting, off until it is decided how that should work. }
function CrossPosting: boolean;
{ '' when Me may start a message in Room, otherwise why not. }
function CanStart(const Me: TMember; const Room: TRoom): string;
function RoomCan(const Me: TMember; const Perm: string; const Room: TRoom): boolean;
{ follows.notify: 0 everything, 1 mentions only, 2 nothing - and the words
  the API uses for them }
function NotifyModeOf(const word: string): integer;
function NotifyWord(Mode: integer): string;
{ the member has silenced the channel: no push and no mail about it }
function Silenced(UserId, RoomId: integer): boolean;
procedure Follow(UserId, RoomId: integer);
{ Rings every page that may care that the room changed.  A new message can
  ride along (Message, as anyone may see it), so pages showing the room
  need not ask for it. }
procedure RingRoom(const Room: TRoom; Message: TJSONObject = nil);
procedure TouchPresence(UserId, RoomId: integer);
function TypingNames(RoomId, ExceptUser: integer): TJSONArray;
function HereNow(RoomId: integer): TJSONArray;
function ShelfSlug(const Name: string): string;
procedure EnsureChannels;
procedure RegisterRoomInfoHook(Hook: TRoomInfoHook);

implementation

uses
  Variants, httproute, SiteDb, SiteSql, SiteRoles, SiteBell, SiteFiles, SiteParts, SiteWords;

var
  InfoHooks: array of TRoomInfoHook;

procedure RegisterRoomInfoHook(Hook: TRoomInfoHook);
begin
  SetLength(InfoHooks, Length(InfoHooks) + 1);
  InfoHooks[High(InfoHooks)] := Hook;
end;

const
  RoomColumns = 'SELECT id, slug, kind, title, topic, owner_id, post_policy, archived, private FROM rooms ';

function ReadRoom(const Where: string; const Values: array of variant): TRoom;
begin
  Result.Id := 0;
  Result.Slug := '';
  Result.Kind := '';
  Result.Title := '';
  Result.Topic := '';
  Result.OwnerId := 0;
  Result.Policy := 'all';
  Result.Archived := False;
  Result.Private := False;
  with Query(RoomColumns + Where, Values) do
  try
    if EOF then
      Exit;
    Result.Id := Fields[0].AsInteger;
    Result.Slug := Fields[1].AsString;
    Result.Kind := Fields[2].AsString;
    Result.Title := Fields[3].AsString;
    Result.Topic := Fields[4].AsString;
    Result.OwnerId := Fields[5].AsInteger;
    Result.Policy := Fields[6].AsString;
    Result.Archived := Fields[7].AsInteger = 1;
    Result.Private := Fields[8].AsInteger = 1;
  finally
    Free;
  end;
end;

function FindRoom(const Slug: string): TRoom;
begin
  Result := ReadRoom('WHERE slug = :s', [Slug]);
end;

function RoomById(Id: integer): TRoom;
begin
  Result := ReadRoom('WHERE id = :i', [Id]);
end;

function RoomExists(const Slug: string): boolean;
begin
  Result := IntValue('SELECT id FROM rooms WHERE slug = :s AND private = 0', [Slug]) > 0;
end;

function CreateRoom(const Slug, Kind, Title, Topic: string; OwnerId: integer; const Policy: string; IsPrivate: boolean): integer;
var
  Owner: variant;
begin
  Owner := Null;
  if OwnerId > 0 then
    Owner := OwnerId;
  Exec('INSERT INTO rooms (slug, kind, title, topic, owner_id, post_policy, private)' + ' VALUES (:s, :k, :t, :p, :o, :y, :v)',
    [Slug, Kind, Copy(Title, 1, 100), Copy(Topic, 1, 500), Owner, Policy, Ord(IsPrivate)]);
  Result := LastId;
end;

function IsFollower(UserId, RoomId: integer): boolean;
begin
  Result := (UserId > 0) and (IntValue('SELECT COUNT(*) FROM follows WHERE user_id = :u AND room_id = :r', [UserId, RoomId]) > 0);
end;

function CanRead(const Me: TMember; const Room: TRoom): boolean;
begin
  if Room.Id = 0 then
    Result := False
  else if Room.Private then
    Result := (Me.Id > 0) and not Me.Banned and (IsFollower(Me.Id, Room.Id) or Can(Me, 'view-private'))
  else
    Result := Can(Me, 'view-room');
end;

function RoomCan(const Me: TMember; const Perm: string; const Room: TRoom): boolean;
begin
  Result := CanIn(Me, Perm, Room.Id, Room.OwnerId);
end;

function CanStart(const Me: TMember; const Room: TRoom): string;
begin
  Result := '';
  if Me.Id = 0 then
    Result := Say('Sign in or join first.')
  else if Me.Banned then
    Result := Say('This account cannot talk here.')
  else if not CanRead(Me, Room) then
    Result := Say('No channel by that name.')
  else if Room.Archived then
    Result := Say('This channel is archived.')
  else if IsMuted(Me.Id, Room.Id) then
    Result := Say('You are muted in this channel for now.')
  else if not RoomCan(Me, 'post', Room) then
    Result := Say('Posting is not open to you here.')
  else if (Room.Policy = 'readonly') and not RoomCan(Me, 'post-readonly', Room) then
    Result := Say('This channel is read only. Reply in a thread instead.')
  else if (Room.Policy = 'owner') and (Room.OwnerId <> Me.Id) then
    Result := Say('Only its owner posts here. Reply in a thread instead.');
end;

procedure Follow(UserId, RoomId: integer);
begin
  Exec(SqlInsertIgnoreSelect('follows', 'user_id, room_id, last_read_id', 'SELECT :u, id, last_message_id FROM rooms WHERE id = :r'), [UserId, RoomId]);
end;

procedure RingRoom(const Room: TRoom; Message: TJSONObject);
var
  Note: string;
  Guest: TMember;
  Ring: TJSONObject;
begin
  Guest.Id := 0;
  Guest.Name := '';
  Guest.Roles := '';
  Guest.Banned := False;
  Guest.Verified := False;
  Ring := TJSONObject.Create(['t', 'room', 'room', Room.Slug]);
  try
    // A public room's rings reach every page, so the message goes along
    // only where guests may read it anyway.  A private room's reach only
    // its members.
    if (Message <> nil) and (Room.Private or Can(Guest, 'view-room')) then
      Ring.Add('m', Message.Clone);
    Note := Ring.AsJSON;
  finally
    Ring.Free;
  end;
  if not Room.Private then
    RingAll(Note)
  else
    // not to a member banned since, whose open page would still listen
    with Query('SELECT f.user_id FROM follows f JOIN users u ON u.id = f.user_id WHERE f.room_id = :r AND u.banned = 0', [Room.Id]) do
    try
      while not EOF do
      begin
        RingUser(Fields[0].AsInteger, Note);
        Next;
      end;
    finally
      Free;
    end;
end;

{ Called on every sync, so it writes only when something changed: another
  room, or a minute since the last write. }
procedure TouchPresence(UserId, RoomId: integer);
begin
  Exec('INSERT INTO presence (user_id, room_id, seen) VALUES (:u, :r, NOW())' + SqlOnConflict('user_id', 'seen = ' + SqlIf('room_id <> ' +
    SqlNew('room_id') + ' OR seen < ' + SqlAgo('1', suMinute), 'NOW()', 'seen') + ', room_id = ' + SqlNew('room_id')), [UserId, RoomId]);
  Exec('UPDATE users SET last_seen = NOW() WHERE id = :u' + ' AND (last_seen IS NULL OR last_seen < ' + SqlAgo('5', suMinute) + ')', [UserId]);
end;

function LastRoom(const Me: TMember): TRoom;
begin
  Result := FindRoom('');
  if Me.Id = 0 then
    Exit;
  Result := FindRoom(VarToStr(Value('SELECT last_room FROM users WHERE id = :u', [Me.Id])));
  if (Result.Kind <> 'channel') or Result.Archived or not CanRead(Me, Result) then
    Result := FindRoom('');
end;

function CrossPosting: boolean;
begin
  Result := Setting('cross_post', '0') = '1';
end;

function TypingNames(RoomId, ExceptUser: integer): TJSONArray;
begin
  Result := TJSONArray.Create;
  with Query('SELECT u.name FROM typing t JOIN users u ON u.id = t.user_id' + ' WHERE t.room_id = :r AND t.user_id <> :u AND t.at > ' +
      SqlAgo('5', suSecond), [RoomId, ExceptUser]) do
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

function HereNow(RoomId: integer): TJSONArray;
begin
  Result := TJSONArray.Create;
  with Query('SELECT u.name, u.avatar, u.away FROM presence p JOIN users u ON u.id = p.user_id' + ' WHERE p.room_id = :r AND p.seen > ' +
      SqlAgo('2', suMinute) + ' ORDER BY u.name LIMIT 50', [RoomId]) do
  try
    while not EOF do
    begin
      Result.Add(TJSONObject.Create(['name', Fields[0].AsString, 'avatar', AvatarUrl(Fields[1].AsString), 'away', Fields[2].AsString]));
      Next;
    end;
  finally
    Free;
  end;
end;

function ShelfSlug(const Name: string): string;
begin
  Result := '~' + LowerCase(Name);
end;

{ New members follow every public channel and get a shelf. }
procedure WelcomeMember(UserId: integer);
var
  Name: string;
begin
  Exec(SqlInsertIgnoreSelect('follows', 'user_id, room_id, last_read_id', 'SELECT :u, id, last_message_id FROM rooms WHERE kind = ''channel'' AND archived = 0 AND private = 0'),
    [UserId]);
  Name := VarToStr(Value('SELECT name FROM users WHERE id = :u', [UserId]));
  if IntValue('SELECT COUNT(*) FROM rooms WHERE slug = :s', [ShelfSlug(Name)]) = 0 then
    CreateRoom(ShelfSlug(Name), 'shelf', Name, '', UserId, 'owner');
end;

{ The channels come from the config file's [channels] section, one
  name=topic line each, created when missing.  [policies] can make a
  channel read only (announcements=readonly). }
procedure EnsureChannels;
var
  Names: TStringList;
  I: integer;
  Policy: string;
begin
  Names := TStringList.Create;
  try
    Config.ReadSectionValues('channels', Names);
    if Names.Count = 0 then
      Names.Add('general=Anything goes.');
    for I := 0 to Names.Count - 1 do
      if ValidSlug(Names.Names[I]) and (IntValue('SELECT COUNT(*) FROM rooms WHERE slug = :s', [Names.Names[I]]) = 0) then
      begin
        Policy := Config.ReadString('policies', Names.Names[I], 'all');
        if Policy = 'admins' then
          Policy := 'readonly';
        CreateRoom(Names.Names[I], 'channel', Names.Names[I], Names.ValueFromIndex[I], 0, Policy);
      end;
  finally
    Names.Free;
  end;
end;

{ What Me may do in the room, for the page to show the right buttons. }
function RoomPermissions(const Me: TMember; const Room: TRoom): TJSONObject;
var
  P: string;
begin
  Result := TJSONObject.Create;
  for P in ['react', 'upload', 'pin', 'set-topic', 'delete-any', 'invite', 'kick', 'mute', 'set-room-roles'] do
    Result.Add(P, (Me.Id > 0) and RoomCan(Me, P, Room));
end;

{ GET /api/room?slug=  everything about a room except its messages }
procedure ShowRoom(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Room: TRoom;
  Info: TJSONObject;
  Hook: TRoomInfoHook;
  Why: string;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  Room := FindRoom(ARequest.QueryFields.Values['slug']);
  if not CanRead(Me, Room) then
  begin
    SendText(AResponse, 404, 'No channel by that name.');
    Exit;
  end;
  // The channel a member comes back to next time; written only when it changes.
  if (Me.Id > 0) and (Room.Kind = 'channel') then
    Exec('UPDATE users SET last_room = :s WHERE id = :u AND last_room <> :s2', [Room.Slug, Me.Id, Room.Slug]);
  Why := CanStart(Me, Room);
  Info := TJSONObject.Create(['avatar', AvatarUrl(VarToStr(Value('SELECT avatar FROM rooms WHERE id = :r', [Room.Id]))), 'id', Room.Id,
    'slug', Room.Slug, 'kind', Room.Kind, 'title', Room.Title, 'topic', Room.Topic, 'policy', Room.Policy, 'archived', Room.Archived,
    'private', Room.Private, 'owner', VarToStr(Value('SELECT name FROM users WHERE id = :u', [Room.OwnerId])), 'following',
    IsFollower(Me.Id, Room.Id), 'can_start', Why = '', 'why_not', Why, 'can', RoomPermissions(Me, Room)]);
  for Hook in InfoHooks do
    Hook(Room, Me, Info);
  SendJSON(AResponse, Info);
end;

{ seen on some page in the last two minutes, anywhere on the site }
function OnlineNow: string;
begin
  Result := '(SELECT COUNT(*) FROM presence p WHERE p.user_id = u.id AND p.seen > ' + SqlAgo('2', suMinute) + ')';
end;

{ GET /api/room/members?room=  a private room's members, or the people with
  a role in any room }
procedure ShowMembers(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Room: TRoom;
  List: TJSONArray;
  Q: string;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  Room := FindRoom(ARequest.QueryFields.Values['room']);
  if not CanRead(Me, Room) then
  begin
    SendText(AResponse, 404, 'No channel by that name.');
    Exit;
  end;
  // Owners and room moderators in any room; everyone in a private one.
  if Room.Private then
    Q := 'SELECT u.name, u.avatar, u.away, (SELECT GROUP_CONCAT(role) FROM room_roles x' + ' WHERE x.room_id = f.room_id AND x.user_id = u.id), u.id = :o, ' +
      OnlineNow + ' FROM follows f JOIN users u ON u.id = f.user_id WHERE f.room_id = :r ORDER BY u.name LIMIT 500'
  else
    Q := 'SELECT u.name, u.avatar, u.away, GROUP_CONCAT(x.role), u.id = :o, ' + OnlineNow + ' FROM room_roles x JOIN users u ON u.id = x.user_id WHERE x.room_id = :r' +
      ' GROUP BY u.id ORDER BY u.name';
  List := TJSONArray.Create;
  with Query(Q, [Room.OwnerId, Room.Id]) do
  try
    while not EOF do
    begin
      List.Add(TJSONObject.Create(['name', Fields[0].AsString, 'avatar', AvatarUrl(Fields[1].AsString), 'away', Fields[2].AsString,
        'roles', Fields[3].AsString, 'owner', Fields[4].AsInteger = 1, 'online', Fields[5].AsInteger > 0]));
      Next;
    end;
  finally
    Free;
  end;
  SendJSON(AResponse, List);
end;

{ POST /api/room/create  slug, topic, private (1 or 0) }
procedure NewRoom(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Slug: string;
  IsPrivate: boolean;
  Id: integer;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  Slug := LowerCase(Trim(ARequest.ContentFields.Values['slug']));
  IsPrivate := ARequest.ContentFields.Values['private'] = '1';
  if IsPrivate and not Can(Me, 'create-private') then
    SendText(AResponse, 403, 'Private channels are not open to you here.')
  else if not IsPrivate and not Can(Me, 'create-channel') then
    SendText(AResponse, 403, 'Only some members open public channels here. Try a private channel.')
  else if not ValidSlug(Slug) then
    SendText(AResponse, 400, 'A channel name is 2 to 40 lowercase letters, digits or hyphens.')
  else if IntValue('SELECT COUNT(*) FROM rooms WHERE slug = :s', [Slug]) > 0 then
    SendText(AResponse, 409, 'That name is taken.')
  else if IsPrivate and (IntValue('SELECT COUNT(*) FROM rooms WHERE owner_id = :u AND private = 1', [Me.Id]) >= SettingInt('private_rooms_each', 20)) then
    SendText(AResponse, 400, 'You have opened as many private channels as a member can here.')
  else
  begin
    Id := CreateRoom(Slug, 'channel', Slug, ARequest.ContentFields.Values['topic'], Me.Id, 'all', IsPrivate);
    Follow(Me.Id, Id);
    // Everyone follows a new public channel; they can leave it.
    if not IsPrivate then
    begin
      Exec(SqlInsertIgnoreSelect('follows', 'user_id, room_id, last_read_id', 'SELECT id, :r, 0 FROM users'),
        [Id]);
      RingRoom(RoomById(Id));
    end;
    SendJSON(AResponse, TJSONObject.Create(['slug', Slug]));
  end;
end;

{ POST /api/follow  room, on (1 or 0).  Leaving a private room is for good,
  until someone invites you again. }
function NotifyModeOf(const word: string): integer;
begin
  if word = 'all' then
    Result := 0
  else if word = 'mentions' then
    Result := 1
  else if word = 'none' then
    Result := 2
  else
    Result := -1;
end;

function NotifyWord(Mode: integer): string;
begin
  case Mode of
    1: Result := 'mentions';
    2: Result := 'none';
    else
      Result := 'all';
  end;
end;

function Silenced(UserId, RoomId: integer): boolean;
begin
  Result := IntValue('SELECT COALESCE(MAX(notify), 0) FROM follows WHERE user_id = :u AND room_id = :r', [UserId, RoomId]) = 2;
end;

procedure SetFollow(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Room: TRoom;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  Room := FindRoom(ARequest.ContentFields.Values['room']);
  if not CanRead(Me, Room) then
    SendText(AResponse, 404, 'No channel by that name.')
  else
  begin
    if ARequest.ContentFields.Values['on'] = '1' then
      Follow(Me.Id, Room.Id)
    else
    begin
      Exec('DELETE FROM follows WHERE user_id = :u AND room_id = :r', [Me.Id, Room.Id]);
      // Leaving a room is not asking to come back to it.
      Exec('UPDATE users SET last_room = '''' WHERE id = :u AND last_room = :s', [Me.Id, Room.Slug]);
    end;
    SendText(AResponse, 200, 'ok');
  end;
end;

{ POST /api/follow/notify  room, mode = all, mentions or none.  How much a
  followed channel may bother the member: everything, mentions only, or
  nothing - no badge, no push, no mail.  The channel stays in the sidebar. }
procedure SetNotify(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Room: TRoom;
  Mode: integer;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  Room := FindRoom(ARequest.ContentFields.Values['room']);
  Mode := NotifyModeOf(ARequest.ContentFields.Values['mode']);
  if not CanRead(Me, Room) then
    SendText(AResponse, 404, 'No channel by that name.')
  else if Mode < 0 then
    SendText(AResponse, 400, 'The mode is all, mentions or none.')
  else if IntValue('SELECT COUNT(*) FROM follows WHERE user_id = :u AND room_id = :r', [Me.Id, Room.Id]) = 0 then
    SendText(AResponse, 409, 'Follow the channel first.')
  else
  begin
    Exec('UPDATE follows SET notify = :n WHERE user_id = :u AND room_id = :r', [Mode, Me.Id, Room.Id]);
    SendText(AResponse, 200, 'ok');
  end;
end;

{ POST /api/typing  room }
procedure SetTyping(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Room: TRoom;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  Room := FindRoom(ARequest.ContentFields.Values['room']);
  if CanRead(Me, Room) then
  begin
    Exec('INSERT INTO typing (user_id, room_id, at) VALUES (:u, :r, NOW())' + SqlOnConflict('user_id', 'room_id = ' + SqlNew('room_id') + ', at = NOW()'), [Me.Id, Room.Id]);
    RingWatchers(Room.Id, BellNote(['t', 'typing', 'room', Room.Slug, 'name', Me.Name]));
  end;
  SendText(AResponse, 200, 'ok');
end;

{ POST /api/topic  room, topic }
procedure SetTopic(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Room: TRoom;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  Room := FindRoom(ARequest.ContentFields.Values['room']);
  if not CanRead(Me, Room) or not RoomCan(Me, 'set-topic', Room) then
  begin
    SendText(AResponse, 403, 'Only the channel''s owner or a moderator changes its topic.');
    Exit;
  end;
  Exec('UPDATE rooms SET topic = :t WHERE id = :r',
    [Copy(ARequest.ContentFields.Values['topic'], 1, 500), Room.Id]);
  SendText(AResponse, 200, 'ok');
end;

procedure ForgetOldPresence;
begin
  Exec('DELETE FROM typing WHERE at < ' + SqlAgo('1', suMinute), []);
  Exec('DELETE FROM presence WHERE seen < ' + SqlAgo('1', suDay), []);
end;

{ A member's shelf is named after them, so a new name needs its shelf name free. }
function ShelfNameFree(UserId: integer; const NewName: string): string;
begin
  Result := '';
  if IntValue('SELECT COUNT(*) FROM rooms WHERE slug = :s AND NOT (kind = ''shelf'' AND owner_id = :u)', ['~' + LowerCase(NewName), UserId]) > 0 then
    Result := 'A channel already uses that shelf name.';
end;

procedure RenameShelf(UserId: integer; const OldName, NewName: string);
begin
  Exec('UPDATE rooms SET slug = :s, title = :n WHERE kind = ''shelf'' AND owner_id = :u',
    ['~' + LowerCase(NewName), NewName, UserId]);
  Exec('UPDATE users SET last_room = :n WHERE last_room = :o', ['~' + LowerCase(NewName), '~' + LowerCase(OldName)]);
end;

{ A closed account follows nothing and is nowhere; its messages stay. }
procedure LeaveEverything(UserId: integer);
begin
  Exec('DELETE FROM follows WHERE user_id = :u', [UserId]);
  Exec('DELETE FROM presence WHERE user_id = :u', [UserId]);
  Exec('DELETE FROM typing WHERE user_id = :u', [UserId]);
  Exec('UPDATE users SET last_room = '''' WHERE id = :u', [UserId]);
end;

procedure SaveRoomIcon(const Slug, Token: string);
begin
  Exec('UPDATE rooms SET avatar = :t WHERE slug = :s AND kind = ''channel''', [Token, Slug]);
end;

initialization
  RegisterPart('chat', 'The chat: channels, threads and private conversations (the IRC side follows after a restart)', True);
  RegisterPartPaths('chat', ['/p', '/m', '/dm', '/irc', '/connect.exedra', '/mail-off', '/api/rooms', '/api/room', '/api/commands',
    '/api/messages', '/api/thread', '/api/pins', '/api/search', '/api/sync', '/api/post', '/api/edit', '/api/delete', '/api/react',
    '/api/reacted', '/api/pin', '/api/follow', '/api/typing', '/api/topic', '/api/key', '/api/dm', '/api/beam', '/api/ice', '/api/push',
    '/api/notes', '/api/admin/private', '/api/admin/channel']);
  // what chat.js draws reactions with, and finds emoji by name with
  RegisterPartScript('chat', '/static/reactions.js');
  RegisterPartScript('chat', '/static/emoji-names.js');
  RegisterPartScript('chat', '/static/chat.js');
  RegisterTable('CREATE TABLE IF NOT EXISTS rooms (' + ' id INT AUTO_INCREMENT PRIMARY KEY,' + ' slug VARCHAR(60) NOT NULL UNIQUE,' +
    ' kind VARCHAR(16) NOT NULL,' + ' title VARCHAR(100) NOT NULL,' + ' topic VARCHAR(500) NOT NULL DEFAULT '''',' + ' owner_id INT NULL,' +
    ' post_policy VARCHAR(8) NOT NULL DEFAULT ''all'',' + ' archived TINYINT NOT NULL DEFAULT 0,' + ' private TINYINT NOT NULL DEFAULT 0,' +
    ' created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,' + ' last_talk DATETIME NULL,' + ' last_message_id INT NOT NULL DEFAULT 0,' +
    ' message_count INT NOT NULL DEFAULT 0,' + ' INDEX (kind, last_talk), INDEX (owner_id)' + ') CHARACTER SET utf8mb4');
  // A followed room and the last message read there.  For a private room,
  // being in it.
  // A room's own picture: a file token, as a member's avatar is.
  RegisterUpgrade('rooms-avatar', 'ALTER TABLE rooms ADD COLUMN avatar VARCHAR(40) NOT NULL DEFAULT ''''');
  // The channel each member opened last: where / takes them next time.
  RegisterUpgrade('users-last-room', 'ALTER TABLE users ADD COLUMN last_room VARCHAR(60) NOT NULL DEFAULT ''''');
  RegisterUpgrade('follows-notify', 'ALTER TABLE follows ADD COLUMN notify TINYINT NOT NULL DEFAULT 0');
  RegisterTable('CREATE TABLE IF NOT EXISTS follows (' + ' user_id INT NOT NULL, room_id INT NOT NULL, last_read_id INT NOT NULL DEFAULT 0,' +
    ' PRIMARY KEY (user_id, room_id), INDEX (room_id))');
  RegisterTable('CREATE TABLE IF NOT EXISTS presence (' + ' user_id INT PRIMARY KEY, room_id INT NOT NULL, seen DATETIME NOT NULL, INDEX (room_id, seen))');
  RegisterTable('CREATE TABLE IF NOT EXISTS typing (' + ' user_id INT PRIMARY KEY, room_id INT NOT NULL, at DATETIME NOT NULL, INDEX (room_id))');
  RegisterNewMemberHook(@WelcomeMember);
  RegisterRenameCheck(@ShelfNameFree);
  RegisterRenameMemberHook(@RenameShelf);
  RegisterCloseMemberHook(@LeaveEverything);
  RoomIconSaved := @SaveRoomIcon;
  RegisterChore(@ForgetOldPresence, 10);
  RegisterPermission('view-room', 'Read public channels', 'guest,member');
  RegisterPermission('view-private', 'Read every private channel', 'admin');
  RegisterPermission('post', 'Post messages', 'member');
  RegisterPermission('post-readonly', 'Post in read-only channels', 'admin');
  RegisterPermission('create-channel', 'Open public channels', 'admin');
  RegisterPermission('create-private', 'Open private channels', 'member');
  RegisterPermission('set-topic', 'Change a channel''s topic', 'owner,room-moderator,moderator,admin');
  RegisterPermission('invite', 'Invite members into a private channel', 'owner,room-moderator,moderator,admin');
  RegisterPermission('kick', 'Take members out of a private channel', 'owner,room-moderator,moderator,admin');
  RegisterPermission('mute', 'Mute members in a channel', 'owner,room-moderator,moderator,admin');
  RegisterPermission('set-room-roles', 'Name channel moderators (/op)', 'owner,moderator,admin');
  RegisterSetting('private_rooms_each', 'Private channels one member can open', '20', 'number', 'Chat');
  RegisterSetting('cross_post', 'A message that names a public channel (#name) also shows in that channel', '0', 'yesno', 'Chat');
  HTTPRouter.RegisterRoute('/api/room', rmGet, @ShowRoom);
  HTTPRouter.RegisterRoute('/api/room/members', rmGet, @ShowMembers);
  HTTPRouter.RegisterRoute('/api/room/create', rmPost, @NewRoom);
  HTTPRouter.RegisterRoute('/api/follow', rmPost, @SetFollow);
  HTTPRouter.RegisterRoute('/api/follow/notify', rmPost, @SetNotify);
  HTTPRouter.RegisterRoute('/api/typing', rmPost, @SetTyping);
  HTTPRouter.RegisterRoute('/api/topic', rmPost, @SetTopic);
end.
