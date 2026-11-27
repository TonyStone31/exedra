unit ChatPart;

{ Chat module registrations, pages, home cards and Channels admin tab.
  start_room can send the home page to a room. Rooms include recent messages
  as plain HTML for readers without scripts. See docs/CODE-MAP.md for the
  units and docs/API.md for requests. }

{$mode objfpc}{$H+}

interface

implementation

uses
  Classes, SysUtils, Variants, fpjson, httpdefs, httproute, SiteDb, SiteSql, SiteParts, SiteUsers, SiteRoles, SiteGuard, SiteGuardRules,
  SiteAdmin, WebPages, ChatRooms, ChatMessages, ChatCommands, ChatPrivate, ChatPreviews, ChatOversight, ChatBenches,
  {$ifndef CGI} ChatIrc, {$endif}
  SiteBell, SiteWords;

// The first public channel's name, escaped for a page: {{first}} in a template.
function FirstChannel: string;
begin
  Result := E(VarToStr(Value('SELECT slug FROM rooms WHERE kind = ''channel'' AND archived = 0 AND private = 0 ORDER BY id LIMIT 1', [])));
end;

{ For SiteBell: open pages are kept connected while the chat is on. }
function ChatIsOn: boolean;
begin
  Result := PartOn('chat');
end;

function OnlineNow: string;
var
  People: integer;
begin
  if not PartOn('chat') then
    Exit('');
  People := IntValue('SELECT COUNT(*) FROM presence WHERE seen > ' + SqlAgo('2', suMinute), []);
  if People = 0 then
    Result := E(Say('Nobody is here right now.') + ' ' + Say('Be the first.'))
  else
    Result := E(SayCount(People, '%d person is here right now.', '%d people are here right now.'));
end;

function ChannelList: string;
var
  Line: string;
begin
  Result := '';
  if not PartOn('chat') then
    Exit;
  with Query('SELECT r.slug, r.topic, (SELECT COUNT(*) FROM presence p WHERE p.room_id = r.id' + ' AND p.seen > ' + SqlAgo('2', suMinute) +
      ') FROM rooms r WHERE r.kind = ''channel'' AND r.archived = 0' + ' AND r.private = 0 ORDER BY r.id', []) do
  try
    while not EOF do
    begin
      Line := Format('<a class="chan" href="/p/%0:s"><b>#%0:s</b><span>%1:s</span>', [E(Fields[0].AsString), E(Fields[1].AsString)]);
      if Fields[2].AsInteger > 0 then
        Line := Line + '<small>' + E(Format(Say('%d here now'), [Fields[2].AsInteger])) + '</small>';
      Result := Result + Line + '</a>';
      Next;
    end;
  finally
    Free;
  end;
end;

function BestHtml: string;
var
  Best: TJSONArray;
  Item: TJSONObject;
  Nobody: TMember;
  I: integer;
begin
  if not PartOn('chat') then
    Exit('');
  Result := '';
  Nobody := MemberById(0);
  Best := BestOfWeek(Nobody);
  try
    for I := 0 to Best.Count - 1 do
    begin
      Item := Best.Objects[I];
      Result := Result + Format('<a class="best" href="/p/%s"><div class="who">%s</div>' + '<div class="body">%s</div></a>',
        [E(Item.Strings['room']), Format(E(Say('%s in #%s')), ['<b>' + E(Item.Strings['name']) + '</b>', E(Item.Strings['room'])]), Item.Strings['html']]);
    end;
  finally
    Best.Free;
  end;
  if Result <> '' then
    Result := '<h2>' + E(Say('Best of the week')) + ' <small>' + E(Say('the messages people reacted to most')) + '</small></h2>' + '<div class="bestrow">' + Result + '</div>';
end;

{ /connect.exedra: a file the desktop client opens to come here.  A
  member passes it on, or a page links to it; the client that gets it
  adds this server to its list and signs in. }
procedure ShowConnect(ARequest: TRequest; AResponse: TResponse);
var
  Url, Host: string;
begin
  CheckConnection;
  Url := ExcludeTrailingPathDelimiter(Setting('url', ''));
  // A site with no url set yet: the address this request came to.
  if Url = '' then
    if ARequest.Host.StartsWith('127.0.0.1') or ARequest.Host.StartsWith('localhost') then
      Url := 'http://' + ARequest.Host
    else
      Url := 'https://' + ARequest.Host;
  Host := StringReplace(StringReplace(Url, 'https://', '', []), 'http://', '', []);
  AResponse.ContentType := 'application/x-exedra';
  AResponse.SetCustomHeader('Content-Disposition', 'attachment; filename="' + Host + '.exedra"');
  AResponse.Content := '[exedra]' + #10 + 'server=' + Url + #10 + 'name=' + Setting('name', 'Exedra') + #10;
  AResponse.SendContent;
end;

{ GET /irc  how to connect an IRC client, with the member's own name in it }
procedure ShowIrc(ARequest: TRequest; AResponse: TResponse);
var
  Host, Name, Channels, JoinList, FirstRoom, Network: string;
  C: char;
begin
  CheckConnection;
  // the name a client keeps the network under: the site's, as one word
  Network := '';
  for C in LowerCase(Setting('name', 'Exedra')) do
    if C in ['a'..'z', '0'..'9'] then
      Network := Network + C;
  if Network = '' then
    Network := 'exedra';
  Host := Setting('url', '');
  Host := Copy(Host, Pos('//', Host) + 2, MaxInt).TrimRight(['/']);
  Name := CurrentMember(ARequest).Name;
  if Name = '' then
    Name := 'YourName';
  Channels := '';
  JoinList := '';
  FirstRoom := '';
  with Query('SELECT slug FROM rooms WHERE kind = ''channel'' AND private = 0 AND archived = 0 ORDER BY id', []) do
  try
    while not EOF do
    begin
      Channels := Channels + Format(' <a href="ircs://%s:%d/%s">#%2:s</a>', [Host, Config.ReadInteger('irc', 'public_port', 6697), Fields[0].AsString]);
      if JoinList = '' then
        FirstRoom := Fields[0].AsString;
      JoinList := JoinList + ',#' + Fields[0].AsString;
      Next;
    end;
  finally
    Free;
  end;
  SendPage(AResponse, FillTemplate('irc', ['title', E(Say('IRC')), 'host', E(Host), 'port', IntToStr(Config.ReadInteger('irc', 'public_port', 6697)),
    'name', E(Name), 'channels', Channels, 'joinlist', Copy(JoinList, 2, MaxInt), 'first', FirstRoom, 'network', Network, 'irc_network',
    E(Format(Say('HexChat menu, Network List, Add, and name it %s.'), [Setting('name', 'Exedra')])), 'irc_server',
    Format(E(Say('Edit it: the server line is %s, and tick %sUse SSL for all the servers on this network%s.')), ['<code>' + E(Host) +
    '/' + IntToStr(Config.ReadInteger('irc', 'public_port', 6697)) + '</code>', '<b>', '</b>']), 'irc_user',
    Format(E(Say('Untick %sUse global user information%s and put %s in Nick name and User name.')), ['<b>', '</b>', '<b>' + E(Name) + '</b>']),
    'irc_login', Format(E(Say('Login method %sSASL (username + password)%s, and your password in Password.')), ['<b>', '</b>']),
    'irc_identify', Format(E(Say('The button works when your client is set to open irc links (HexChat is).') + ' ' + Say('It connects you to read along.') +
    ' ' + Say('To talk, sign in with %s, or set up the network as below so it signs you in every time.')), ['<code>/msg NickServ IDENTIFY password</code>']),
    'irc_register', Format(E(Say('A server password works where SASL does not: set your nick to your name and the server password to your password.') +
    ' ' + Say('No account yet?') + ' ' + Say('Connect, pick a nick and send %s, then open the link mailed to you.')), ['<code>/msg NickServ REGISTER password email</code>']),
    'irc_thread', E(Format(Say('A reply in a thread comes with "%s" and a link to it.'), ['(thread)'])), 'irc_commands',
    E(Format(Say('The page''s commands work as IRC commands: %s, %s, %s, %s and the rest.'), ['/me', '/topic', '/kick', '/invite']))]));
end;

{ The room's recent messages as plain HTML, for readers without scripts. }
function PlainMessages(const Room: TRoom): string;
begin
  Result := '';
  with Query('SELECT COALESCE(u.name, m.author), m.created, m.html FROM message_rooms mr' + ' JOIN messages m ON m.id = mr.message_id LEFT JOIN users u ON u.id = m.user_id' +
      ' WHERE mr.room_id = :r AND m.deleted = 0 ORDER BY mr.message_id DESC LIMIT 50', [Room.Id]) do
  try
    while not EOF do
    begin
      Result := Format('<article><b>%s</b> <time>%s</time>%s</article>'#10, [E(Fields[0].AsString),
        E(ShowDateTime(FormatDateTime('yyyy-mm-dd"T"hh:nn', Fields[1].AsDateTime))), Fields[2].AsString]) + Result;
      Next;
    end;
  finally
    Free;
  end;
end;

procedure ShowRoom(ARequest: TRequest; AResponse: TResponse);
var
  Room: TRoom;
begin
  CheckConnection;
  Room := FindRoom(ARequest.RouteParams['slug']);
  if not CanRead(CurrentMember(ARequest), Room) then
  begin
    // A channel can be deleted while someone has it bookmarked or open.
    AResponse.Code := 404;
    SendPage(AResponse, '<!doctype html><meta charset="utf-8"><title>' + E(Say('No channel')) + '</title>' + '<p>' + E(Say('No channel by that name.')) +
      ' <a href="/">' + E(Say('Back to the chat')) + '</a></p>');
  end
  else
    SendApp(ARequest, AResponse, 'room', Room.Slug, Room.Title,
      '<h1>' + E(Room.Title) + '</h1><p>' + E(Room.Topic) + '</p>' + PlainMessages(Room), 0);
end;

{ GET /chat-search  the page's own search of every channel the reader may read }
procedure ShowChatSearch(ARequest: TRequest; AResponse: TResponse);
begin
  CheckConnection;
  SendApp(ARequest, AResponse, 'search', '', Say('Search all chats'), '<h1>' + E(Say('Search all chats')) + '</h1>', 0);
end;

procedure ShowThreadPage(ARequest: TRequest; AResponse: TResponse);
var
  Id: integer;
  Room: TRoom;
begin
  CheckConnection;
  Id := StrToIntDef(ARequest.RouteParams['id'], 0);
  Room := RoomById(IntValue('SELECT room_id FROM messages WHERE id = :m', [Id]));
  if not CanRead(CurrentMember(ARequest), Room) then
    SendText(AResponse, 404, Say('No such message.'))
  else
  begin
    // A reply opens its whole thread.
    if IntValue('SELECT COALESCE(parent_id, 0) FROM messages WHERE id = :m', [Id]) > 0 then
      Id := IntValue('SELECT parent_id FROM messages WHERE id = :m', [Id]);
    SendApp(ARequest, AResponse, 'room', Room.Slug, Room.Title, PlainMessages(Room), Id);
  end;
end;

procedure ShowDmPage(ARequest: TRequest; AResponse: TResponse);
var
  Name: string;
begin
  CheckConnection;
  Name := NameInPath(ARequest.RouteParams['name']);
  if Name = '' then
    SendText(AResponse, 404, Say('No member by that name.'))
  else
    SendApp(ARequest, AResponse, 'dm', Name, '@' + Name, '', 0);
end;

{ A chat site opens on its chat: a member in the
  channel they were last in, a new member and a visitor in the start room. }
function ChatStart(const Me: TMember): string;
var
  Room: TRoom;
begin
  Result := '';
  if not PartOn('chat') or (Setting('start_room', '') = '') then
    Exit;
  Room := LastRoom(Me);
  if Room.Id > 0 then
    Result := '/p/' + Room.Slug
  else
    Result := '/p/' + Setting('start_room', '');
end;

function ChatLink: string;
begin
  Result := '<a href="/p/' + FirstChannel + '">' + E(Say('Chat')) + '</a>';
end;

{ The public channels, for the admin page's Channels tab. }
procedure AdminChannels(const Me: TMember; Answer: TJSONObject);
var
  List: TJSONArray;
begin
  if not (PartOn('chat') and Can(Me, 'manage-channels')) then
    Exit;
  List := TJSONArray.Create;
  with Query('SELECT slug, title, topic, post_policy, archived, avatar, kind FROM rooms WHERE kind IN (''channel'', ''bench'') AND private = 0 ORDER BY kind <> ''channel'', id',
      []) do
  try
    while not EOF do
    begin
      List.Add(TJSONObject.Create(['slug', Fields[0].AsString, 'title', Fields[1].AsString, 'topic', Fields[2].AsString, 'policy',
        Fields[3].AsString, 'archived', Fields[4].AsInteger = 1, 'avatar', AvatarUrl(Fields[5].AsString), 'kind', Fields[6].AsString]));
      Next;
    end;
  finally
    Free;
  end;
  Answer.Add('channels', List);
end;

{ POST /api/admin/channel  slug, topic, policy, archived }
procedure SaveChannel(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Slug, Policy: string;
  Room: TRoom;
begin
  if not NeedPermission(ARequest, AResponse, 'manage-channels', Me) then
    Exit;
  with ARequest.ContentFields do
  begin
    Slug := LowerCase(Trim(Values['slug']));
    Policy := Values['policy'];
    if Policy <> 'readonly' then
      Policy := 'all';
    if not ValidSlug(Slug) then
    begin
      SendText(AResponse, 400, 'A channel name is 2 to 40 lowercase letters, digits or hyphens.');
      Exit;
    end;
    Room := FindRoom(Slug);
    if Room.Id = 0 then
    begin
      CreateRoom(Slug, 'channel', Slug, Values['topic'], 0, Policy);
      // Everyone follows a new channel; they can leave it.
      Exec(SqlInsertIgnoreSelect('follows', 'user_id, room_id, last_read_id', 'SELECT u.id, r.id, 0' + ' FROM users u, rooms r WHERE r.slug = :s'),
        [Slug]);
    end
    // a bench is looked after here too: made read only, archived, its topic changed
    else if ((Room.Kind <> 'channel') and (Room.Kind <> 'bench')) or Room.Private then
    begin
      SendText(AResponse, 400, 'That name is already in use. Choose another name for the public channel.');
      Exit;
    end
    else
      Exec('UPDATE rooms SET topic = :t, post_policy = :p, archived = :a WHERE id = :r',
        [Copy(Values['topic'], 1, 500), Policy, Ord(Values['archived'] = '1'), Room.Id]);
  end;
  SendText(AResponse, 200, 'Saved.');
end;

initialization
  LiveOn := @ChatIsOn;
  RegisterOldLink('/p/');
  RegisterSetting('start_room', 'New members and visitors land in this channel; a member comes back to the channel they were last in (empty: the home page)', '', 'text', 'Chat');
  RegisterSetting('ice_servers', 'Servers browsers use to find each other for a beam (space separated)',
    'stun:stun.l.google.com:19302', 'longtext', 'Chat');
  RegisterPermission('manage-channels', 'Change public channels', 'admin');
  RegisterPermission('chat-settings', 'Change the chat''s settings', 'admin');
  RegisterSettingsKeeper('Chat', 'chat-settings');
  RegisterRole('chat-moderator', 'Keeps the peace in the chat', 'delete-any,pin,set-topic,invite,kick,mute,set-room-roles');
  RegisterRole('chat-admin', 'Runs the chat: its channels and its moderation',
    'delete-any,pin,set-topic,invite,kick,mute,set-room-roles,manage-channels,create-channel,post-readonly,chat-settings,view-admin');
  RegisterAdminSection('channels', 'Channels', 'manage-channels', 'settings');
  RegisterAdminSection('private', 'Private', 'manage-private', 'channels');
  RegisterAdminRoute('/api/admin/channel', 'manage-channels');
  RegisterAdminPart(@AdminChannels);
  RegisterHomePart('online', @OnlineNow);
  RegisterHomePart('channels', @ChannelList);
  RegisterHomePart('best', @BestHtml);
  RegisterPageValue('first', @FirstChannel);
  HomeStart := @ChatStart;
  RegisterPartLink('chat', @ChatLink);
  RegisterPartStart('chat', @EnsureChannels);
  {$ifndef CGI}
  RegisterPartStart('chat', @StartIrc);
  {$endif}
  HTTPRouter.RegisterRoute('/irc', rmGet, @ShowIrc);
  HTTPRouter.RegisterRoute('/connect.exedra', rmGet, @ShowConnect);
  HTTPRouter.RegisterRoute('/p/:slug', rmGet, @ShowRoom);
  HTTPRouter.RegisterRoute('/m/:id', rmGet, @ShowThreadPage);
  HTTPRouter.RegisterRoute('/chat-search', rmGet, @ShowChatSearch);
  HTTPRouter.RegisterRoute('/dm/:name', rmGet, @ShowDmPage);
  HTTPRouter.RegisterRoute('/api/admin/channel', rmPost, @SaveChannel);
end.
