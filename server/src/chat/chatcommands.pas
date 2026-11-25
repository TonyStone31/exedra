unit ChatCommands;

{ Slash commands shared by the chat and IRC, with the same permission checks
  as the buttons. The page handles /msg and /list itself because private
  messages are encrypted before sending. }

{$mode objfpc}{$H+}

interface

implementation

uses
  Classes, SysUtils, Variants, SiteDb, SiteSql, SiteUsers, ChatRooms, ChatMessages, SiteRoles, SiteBell, SiteWords;

{ The member a command names: its first word, @ or not. }
function Target(const Args: string; out Id: integer; out Name: string): boolean;
begin
  Name := Trim(Copy(Args + ' ', 1, Pos(' ', Args + ' ') - 1));
  if Name.StartsWith('@') then
    Delete(Name, 1, 1);
  Id := MemberId(Name);
  if Id > 0 then
    Name := VarToStr(Value('SELECT name FROM users WHERE id = :u', [Id]));
  Result := Id > 0;
end;

function Info(const Text: string): TCommandResult;
begin
  Result := CommandResult('', Text);
end;

{ Site moderators, admins and the room's owner cannot be pushed around in
  it by others. }
function Untouchable(UserId: integer; const Room: TRoom): boolean;
var
  Roles: string;
begin
  Roles := VarToStr(Value('SELECT roles FROM users WHERE id = :u', [UserId]));
  Result := (UserId = Room.OwnerId) or Shielded(Roles) or HasRole(Roles, 'chat-moderator');
end;

function JoinCommand(const Me: TMember; const Room: TRoom; Parent: integer; const Args: string): TCommandResult;
var
  Other: TRoom;
begin
  Other := FindRoom(LowerCase(Trim(StringReplace(Args, '#', '', []))));
  if not CanRead(Me, Other) then
    Exit(Info(Say('No channel by that name.')));
  Follow(Me.Id, Other.Id);
  Result := CommandResult('', '', '/p/' + Other.Slug);
end;

function PartCommand(const Me: TMember; const Room: TRoom; Parent: integer; const Args: string): TCommandResult;
var
  Other: TRoom;
begin
  Other := Room;
  if Trim(Args) <> '' then
    Other := FindRoom(LowerCase(Trim(StringReplace(Args, '#', '', []))));
  if not IsFollower(Me.Id, Other.Id) then
    Exit(Info(Say('You are not in that channel.')));
  Exec('DELETE FROM follows WHERE user_id = :u AND room_id = :r', [Me.Id, Other.Id]);
  if Other.Private then
    Result := CommandResult('', Say('You left. Someone in it has to invite you back.'), '/')
  else
    Result := CommandResult('', Format(Say('It is out of your sidebar. /join #%s brings it back.'), [Other.Slug]), '/');
end;

function AwayCommand(const Me: TMember; const Room: TRoom; Parent: integer; const Args: string): TCommandResult;
var
  Why: string;
begin
  Why := Copy(Trim(Args), 1, 200);
  if Why = '' then
    Why := 'away';
  Exec('UPDATE users SET away = :a WHERE id = :u', [Why, Me.Id]);
  Result := Info(Format(Say('You are away: %s. People who mention you are told. /back when you return.'), [Why]));
end;

function BackCommand(const Me: TMember; const Room: TRoom; Parent: integer; const Args: string): TCommandResult;
begin
  Exec('UPDATE users SET away = '''' WHERE id = :u', [Me.Id]);
  Result := Info(Say('Welcome back.'));
end;

function WhoisCommand(const Me: TMember; const Room: TRoom; Parent: integer; const Args: string): TCommandResult;
var
  Id: integer;
  Who, Lines: string;
begin
  if not Target(Args, Id, Who) then
    Exit(Info(Say('No member by that name.')));
  with Query('SELECT roles, ' + IsoTime('created') + ', ' + IsoTime('last_seen') + ', away, posts, banned FROM users WHERE id = :u', [Id]) do
  try
    Lines := Who;
    if Fields[0].AsString <> '' then
      Lines := Lines + ' (' + Fields[0].AsString + ')';
    Lines := Lines + #10 + Format(Say('joined %s, last here %s UTC'), [Copy(Fields[1].AsString, 1, 10), StringReplace(Copy(Fields[2].AsString, 1, 16), 'T', ' ', [])]) +
      #10 + SayCount(Fields[4].AsInteger, '%d message', '%d messages');
    if Fields[3].AsString <> '' then
      Lines := Lines + #10 + Format(Say('away: %s'), [Fields[3].AsString]);
    if Fields[5].AsInteger = 1 then
      Lines := Lines + #10 + Say('banned');
  finally
    Free;
  end;
  if IntValue('SELECT COUNT(*) FROM presence WHERE user_id = :u AND seen > ' + SqlAgo('2', suMinute), [Id]) > 0 then
    Lines := Lines + #10 + Say('online now');
  Result := Info(Lines);
end;

function NamesCommand(const Me: TMember; const Room: TRoom; Parent: integer; const Args: string): TCommandResult;
var
  Here: string;
  I: integer;
begin
  Here := '';
  with HereNow(Room.Id) do
  try
    for I := 0 to Count - 1 do
      Here := Here + ' ' + Objects[I].Strings['name'];
  finally
    Free;
  end;
  if Here = '' then
    Result := Info(Say('Nobody else is looking at this channel right now.'))
  else
    Result := Info(Format(Say('Here now: %s'), [Trim(Here)]));
end;

function InviteCommand(const Me: TMember; const Room: TRoom; Parent: integer; const Args: string): TCommandResult;
var
  Id: integer;
  Name: string;
begin
  if not Room.Private then
    Exit(Info(Say('Anyone can /join a public channel. Mention them with @name instead.')));
  if not RoomCan(Me, 'invite', Room) then
    Exit(Info(Say('Inviting is not open to you in this channel.')));
  if not Target(Args, Id, Name) then
    Exit(Info(Say('No member by that name.')));
  if IsFollower(Id, Room.Id) then
    Exit(Info(Format(Say('%s is in here already.'), [Name])));
  Follow(Id, Room.Id);
  RingUser(Id, BellNote(['t', 'me']));
  Result := CommandResult('invited @' + Name, '');
end;

function KickCommand(const Me: TMember; const Room: TRoom; Parent: integer; const Args: string): TCommandResult;
var
  Id: integer;
  Name: string;
begin
  if not Room.Private then
    Exit(Info(Say('A public channel cannot be closed to anyone. /mute them instead.')));
  if not RoomCan(Me, 'kick', Room) then
    Exit(Info(Say('Taking people out is not open to you in this channel.')));
  if not Target(Args, Id, Name) or not IsFollower(Id, Room.Id) then
    Exit(Info(Say('Nobody by that name is in here.')));
  if Untouchable(Id, Room) then
    Exit(Info(Format(Say('%s cannot be taken out of this channel.'), [Name])));
  Exec('DELETE FROM follows WHERE user_id = :u AND room_id = :r', [Id, Room.Id]);
  Exec('DELETE FROM room_roles WHERE user_id = :u AND room_id = :r', [Id, Room.Id]);
  DropUser(Id);
  Result := CommandResult('took ' + Name + ' out of the channel', '');
end;

function OpCommand(const Me: TMember; const Room: TRoom; Parent: integer; const Args: string): TCommandResult;
var
  Id: integer;
  Name: string;
begin
  if not RoomCan(Me, 'set-room-roles', Room) then
    Exit(Info(Say('Naming channel moderators is not open to you here.')));
  if not Target(Args, Id, Name) then
    Exit(Info(Say('No member by that name.')));
  Exec(SqlInsertIgnore('room_roles', 'room_id, user_id, role', ':r, :u, ''room-moderator'''),
    [Room.Id, Id]);
  Result := CommandResult('made @' + Name + ' a moderator of this channel', '');
end;

function DeopCommand(const Me: TMember; const Room: TRoom; Parent: integer; const Args: string): TCommandResult;
var
  Id: integer;
  Name: string;
begin
  if not RoomCan(Me, 'set-room-roles', Room) then
    Exit(Info(Say('Naming channel moderators is not open to you here.')));
  if not Target(Args, Id, Name) then
    Exit(Info(Say('No member by that name.')));
  Exec('DELETE FROM room_roles WHERE room_id = :r AND user_id = :u AND role = ''room-moderator''',
    [Room.Id, Id]);
  Result := Info(Format(Say('%s is no longer a moderator of this channel.'), [Name]));
end;

function MuteCommand(const Me: TMember; const Room: TRoom; Parent: integer; const Args: string): TCommandResult;
var
  Id, Minutes: integer;
  Name: string;
begin
  if not RoomCan(Me, 'mute', Room) then
    Exit(Info(Say('Muting is not open to you here.')));
  if not Target(Args, Id, Name) then
    Exit(Info(Say('No member by that name.')));
  if Untouchable(Id, Room) then
    Exit(Info(Format(Say('%s cannot be muted here.'), [Name])));
  Minutes := StrToIntDef(Trim(Copy(Args, Pos(' ', Args + ' '), MaxInt)), 0);
  // The database's clock decides, as everywhere else.
  Exec(SqlReplace('mutes', 'room_id, user_id, until', ':r, :u, ' + SqlIf(':m > 0', SqlAhead(':m2', suMinute), 'NULL')), [Room.Id, Id, Minutes, Minutes]);
  if Minutes > 0 then
    Result := CommandResult(Format('muted %s here for %d minutes', [Name, Minutes]), '')
  else
    Result := CommandResult('muted ' + Name + ' here', '');
end;

function UnmuteCommand(const Me: TMember; const Room: TRoom; Parent: integer; const Args: string): TCommandResult;
var
  Id: integer;
  Name: string;
begin
  if not RoomCan(Me, 'mute', Room) then
    Exit(Info(Say('Muting is not open to you here.')));
  if not Target(Args, Id, Name) then
    Exit(Info(Say('No member by that name.')));
  Exec('DELETE FROM mutes WHERE room_id = :r AND user_id = :u', [Room.Id, Id]);
  Result := Info(Format(Say('%s can talk here again.'), [Name]));
end;

function BanCommand(const Me: TMember; const Room: TRoom; Parent: integer; const Args: string): TCommandResult;
var
  Id: integer;
  Name, Roles: string;
begin
  if not Can(Me, 'ban') then
    Exit(Info(Say('Banning is for moderators.')));
  if not Target(Args, Id, Name) or (Id = Me.Id) then
    Exit(Info(Say('No member by that name.')));
  Roles := VarToStr(Value('SELECT roles FROM users WHERE id = :u', [Id]));
  if Shielded(Roles) and not HasRole(Me.Roles, 'admin') then
    Exit(Info(Say('Only an admin bans a moderator.')));
  Exec('UPDATE users SET banned = 1 WHERE id = :u', [Id]);
  Exec('DELETE FROM sessions WHERE user_id = :u', [Id]);
  DropUser(Id);
  Log(Me.Name + ' banned ' + Name);
  Result := Info(Format(Say('%s is banned: signed out everywhere, and can only read now.'), [Name]));
end;

function UnbanCommand(const Me: TMember; const Room: TRoom; Parent: integer; const Args: string): TCommandResult;
var
  Id: integer;
  Name: string;
begin
  if not Can(Me, 'ban') then
    Exit(Info(Say('Banning is for moderators.')));
  if not Target(Args, Id, Name) then
    Exit(Info(Say('No member by that name.')));
  Exec('UPDATE users SET banned = 0 WHERE id = :u', [Id]);
  Log(Me.Name + ' lifted the ban on ' + Name);
  Result := Info(Format(Say('%s can talk again.'), [Name]));
end;

function IgnoreCommand(const Me: TMember; const Room: TRoom; Parent: integer; const Args: string): TCommandResult;
var
  Id: integer;
  Name: string;
begin
  if not Target(Args, Id, Name) or (Id = Me.Id) then
    Exit(Info(Say('No member by that name.')));
  Exec(SqlInsertIgnore('ignores', 'user_id, ignored_id', ':u, :o'), [Me.Id, Id]);
  Result := Info(Format(Say('Ignoring %s: their messages fold away, their mentions and private messages do not reach you. /unignore %s undoes it.'), [Name, Name]));
end;

function UnignoreCommand(const Me: TMember; const Room: TRoom; Parent: integer; const Args: string): TCommandResult;
var
  Id: integer;
  Name: string;
begin
  if not Target(Args, Id, Name) then
    Exit(Info(Say('No member by that name.')));
  Exec('DELETE FROM ignores WHERE user_id = :u AND ignored_id = :o', [Me.Id, Id]);
  Result := Info(Format(Say('No longer ignoring %s.'), [Name]));
end;

initialization
  RegisterCommand('join', '/join #channel - go to a channel and follow it', @JoinCommand, True);
  RegisterCommand('part', '/part [#channel] - leave a channel (this one if none is named)', @PartCommand);
  RegisterCommand('away', '/away [why] - mark yourself away', @AwayCommand, True);
  RegisterCommand('back', '/back - you are here again', @BackCommand, True);
  RegisterCommand('whois', '/whois name - who someone is and when they were here', @WhoisCommand, True);
  RegisterCommand('names', '/names - who is looking at this channel', @NamesCommand);
  RegisterCommand('invite', '/invite name - bring someone into this private channel', @InviteCommand);
  RegisterCommand('kick', '/kick name - put someone out of this private channel', @KickCommand);
  RegisterCommand('op', '/op name - make someone a moderator of this channel', @OpCommand);
  RegisterCommand('deop', '/deop name - take the moderator''s role in this channel back', @DeopCommand);
  RegisterCommand('mute', '/mute name [minutes] - stop someone talking in this channel', @MuteCommand);
  RegisterCommand('unmute', '/unmute name - let someone talk in this channel again', @UnmuteCommand);
  RegisterCommand('ban', '/ban name - stop someone talking anywhere (moderators)', @BanCommand, True);
  RegisterCommand('unban', '/unban name - let someone talk again (moderators)', @UnbanCommand, True);
  RegisterCommand('ignore', '/ignore name - fold away what someone says', @IgnoreCommand, True);
  RegisterCommand('unignore', '/unignore name - show what someone says again', @UnignoreCommand, True);
end.
