unit chat_rooms;

{ A room: its head, who is here and typing, its messages and how they are grouped. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, chat_shared;

function RoomTitle(Info: TRoomInfo): string;
procedure RenderHead(Info: TRoomInfo; Extra: TJSNode = nil);
procedure RenderHere(List: TJSArray);
procedure NoteTyping(Names: TJSArray);
procedure RenderTyping;
procedure OpenRoom(Slug: JSValue; Thread: double); async;
procedure LoadMessages(Generation: double); async;
function EmptyNote: TEl;
procedure AddMessages(List: TJSArray; Initial: boolean);
procedure Upsert(M: TMsg; Box: TEl; Map: TJSMap; InThread: boolean);
procedure Regroup(Box: TEl);
procedure RenderCard(Info: TRoomInfo);
procedure Start;

implementation

uses chat_messages, chat_sync, chat_panels, chat_composer, chat_private;

type
  // A button's own property ([] on an element reads and writes attributes).
  TCtl = class external name 'HTMLElement'(TEl)
    &type: string;
  end;
  // What /api/messages answers.
  TPage = class external name 'Object'(TJSObject)
    messages: TJSArray;
    last_read: double;
    rev: double;
  end;
  // A message that is drawn: what the server sent and its element.
  TEntry = class external name 'Object'(TJSObject)
    data: TMsg;
    node: TEl;
  end;
  // Someone who is here.
  TPerson = class external name 'Object'(TJSObject)
    name: JSValue;
    avatar: JSValue;
    away: JSValue;
  end;
  TCard = reference to procedure(Info: TRoomInfo; Card: TEl);

var
  Infinity: double; external name 'Infinity';

function RoomTitle(Info: TRoomInfo): string;
begin
  if Info.kind = 'channel' then Exit('#' + Info.title);
  Result := Info.title;
end;

procedure RenderHead(Info: TRoomInfo; Extra: TJSNode);
var
  Head, Menu, Titles, H, Topic, Here, Tools, Follow, People, Pins, Search: TEl;
  Words: JSValue;
  Cls: string;

  procedure SetTopic(E: TJSEvent); async;
  var
    Next, Was: JSValue;
  begin
    if Info.topic then Was := Info.topic else Was := '';
    Next := window.prompt(T('Topic for %s', RoomTitle(Info)), String(Was));
    if Same(Next, nil) then Exit;
    try
      await(JSValue, Post('/api/topic', new(['room', Info.slug, 'topic', Next])));
      Info.topic := Next;
      if Next then Topic.textContent := String(Next) else Topic.textContent := T('Add a topic');
    except
      Failed(JSExceptValue);
    end;
  end;

  procedure SetFollow(E: TJSEvent); async;
  var
    Turn: string;
  begin
    if Info.&private and Info.following and
      not window.confirm(T('Leave %s? Only an invite gets you back in.', Info.title)) then Exit;
    try
      if Info.following then Turn := '0' else Turn := '1';
      await(JSValue, Post('/api/follow', new(['room', Info.slug, 'on', Turn])));
      Info.following := not Info.following;
      if Info.following then Follow.textContent := T('Following') else Follow.textContent := T('Follow');
      Toggle(Follow, 'on', Info.following);
      SyncNow(True);
    except
      Failed(JSExceptValue);
    end;
  end;

begin
  Head := Find('#roomhead');
  Head.replaceChildren;
  Menu := IconButton('menu', T('Channels'), 'menubtn');
  Menu.addEventListener('click', ToggleMenu);
  Head.appendChild(Menu);
  Titles := El('div', 'titles');
  H := El('h1');
  H.appendChild(El('span', 'roomname', RoomTitle(Info)));
  if Info.avatar then H.prepend(Avatar(Info.title, Info.avatar, 'small roomicon'));
  if Info.&private then
  begin
    H.prepend(Icon('lock'));
    H.appendChild(El('span', 'kindtag', T('private')));
  end
  else if Info.kind <> 'channel' then H.appendChild(El('span', 'kindtag', Info.kind));
  Titles.appendChild(H);
  if Info.topic then Words := Info.topic else Words := '';
  Topic := El('p', 'topic', Words);
  if Truthy(Info.can) and Truthy(Info.can['set-topic']) then
  begin
    Topic.title := T('Click to change the topic');
    Topic.classList.add('editable');
    if not Info.topic then Topic.textContent := T('Add a topic');
    Topic.addEventListener('click', TJSRawEventHandler(@SetTopic));
  end;
  Titles.appendChild(Topic);
  Head.appendChild(Titles);
  Here := El('button', 'here');
  TCtl(Here).&type := 'button';
  Here.title := T('Who is here');
  Here.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin OpenMembers; end));
  Head.appendChild(Here);
  Tools := El('div', 'headtools');
  if Extra <> nil then Tools.appendChild(Extra);
  if (Me.name <> '') and (Info.kind <> 'shelf') then
  begin
    if Info.following then Cls := 'on' else Cls := '';
    if Info.following then Words := T('Following') else Words := T('Follow');
    Follow := El('button', 'pill ' + Cls, Words);
    TCtl(Follow).&type := 'button';
    if Info.&private then Follow.title := T('If you leave a private channel, someone must invite you back')
    else Follow.title := T('Followed channels sit in your sidebar with their unread counts');
    Follow.addEventListener('click', TJSRawEventHandler(@SetFollow));
    // Beside the name: it is about this room.
    H.appendChild(Follow);
  end;
  People := IconButton('people', T('People: who is here, and who is in this channel or runs it'));
  People.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin OpenMembers; end));
  Tools.appendChild(People);
  Pins := IconButton('pin', T('Pinned messages'));
  Pins.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin OpenPins; end));
  Search := IconButton('search', T('Search'));
  Search.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin OpenSearch; end));
  Tools.append(Pins, Search);
  Head.appendChild(Tools);
end;

procedure RenderHere(List: TJSArray);
var
  Box, A: TEl;
  Shown: TJSArray;
  P: TPerson;
  I: NativeInt;
  Cls: string;
begin
  Box := Find('#roomhead .here');
  if Box = nil then Exit;
  Box.replaceChildren;
  S.here := List;
  Shown := List.slice(0, 6);
  for I := 0 to Shown.length - 1 do
  begin
    P := TPerson(Shown[I]);
    if P.away then Cls := 'tiny away' else Cls := 'tiny';
    A := Avatar(P.name, P.avatar, Cls);
    if P.away then A.title := T('%s is away: %s', P.name, P.away) else A.title := T('%s is here', P.name);
    Box.appendChild(A);
  end;
  if List.length <> 0 then Box.appendChild(El('span', 'count', TN(List.length, '%d here', '%d here')));
end;

// Who is typing: from the live connection's rings and from each sync, each
// name shown for five seconds after it was last heard.
procedure NoteTyping(Names: TJSArray);
var
  I: NativeInt;
begin
  for I := 0 to Names.length - 1 do
    if not Same(Names[I], Me.name) then S.typers[String(Names[I])] := TJSDate.now + 5000;
  RenderTyping;
end;

procedure RenderTyping;
var
  Box: TEl;
  Now: NativeInt;
  Names: TJSArray;
  N: string;
  I: NativeInt;
  Text: string;
begin
  Box := Find('#typing');
  Now := TJSDate.now;
  Names := TJSArray(TJSObject.keys(S.typers));
  for I := 0 to Names.length - 1 do
  begin
    N := string(Names[I]);
    if NumberOf(S.typers[N]) < Now then JSDelete(S.typers, N);
  end;
  Names := TJSArray(TJSObject.keys(S.typers));
  if Names.length = 0 then
  begin
    Box.replaceChildren;
    Exit;
  end;
  if Names.length = 1 then Text := T('%s is typing', Names[0])
  else if Names.length = 2 then Text := T('%s and %s are typing', Names[0], Names[1])
  else Text := T('Several people are typing');
  Box.replaceChildren(El('span', 'dots'), El('span', '', Text));
end;

procedure OpenRoom(Slug: JSValue; Thread: double); async;
var
  Generation: double;
  Info: TRoomInfo;
begin
  Generation := S.generation;
  Info := await(TRoomInfo, Get('/api/room?slug=' + Enc(Slug)));
  if Generation <> S.generation then Exit;
  S.view := 'room';
  S.room := Info.slug;
  S.info := Info;
  S.title := RoomTitle(Info);
  // the room last used, for the pages around the chat to open their bubble on
  if not Info.&private then
    try
      window.localStorage.setItem('last-room', Info.slug);
    except
    end;
  RenderHead(Info);
  RenderCard(Info);
  await(LoadMessages(Generation));
  RenderComposer(Find('#composer-area'), 0);
  if Truthy(Thread) then OpenThread(Thread);
  SyncNow(True);
end;

procedure LoadMessages(Generation: double); async;
var
  Data: TPage;
  M: TMsg;
  I: NativeInt;
begin
  Data := await(TPage, Get('/api/messages?room=' + Enc(S.room)));
  if Generation <> S.generation then Exit;
  S.lastRead := Data.last_read;
  S.divider := 0;
  S.since := Data.rev - 3000000;
  S.oldest := Infinity;
  S.older := Data.messages.length = 50;
  for I := 0 to Data.messages.length - 1 do
  begin
    M := TMsg(Data.messages[I]);
    if not Truthy(S.divider) and (Me.name <> '') and (M.id > S.lastRead) and (M.name <> Me.name) and (S.lastRead > 0) then
      S.divider := M.id;
  end;
  AddMessages(Data.messages, True);
  if Data.messages.length = 0 then Stream.appendChild(EmptyNote);
end;

function EmptyNote: TEl;
var
  P: TEl;
begin
  P := El('div', 'empty');
  P.appendChild(El('b', '', T('Nothing said here yet.')));
  if Me.name <> '' then P.appendChild(El('span', '', T(' Say hello.')))
  else P.appendChild(El('span', '', T(' Join to say hello.')));
  Result := P;
end;

// Scrolling to the top brings the messages before the oldest one shown.
procedure StreamScrolled(E: TJSEvent); async;
var
  Generation: double;
  Data: TPage;
  Height, I: NativeInt;
begin
  if (Stream.scrollTop <= 80) and (S.view = 'dm') then
  begin
    OlderDms;
    Exit;
  end;
  if (Stream.scrollTop > 80) or not S.older or (S.view <> 'room') or S.loadingOlder then Exit;
  S.loadingOlder := True;
  Generation := S.generation;
  // finally: a room changed meanwhile must not leave the older pages shut
  try
    try
      Data := await(TPage, Get('/api/messages?room=' + Enc(S.room) + '&before=' + String(JSValue(S.oldest))));
      if Generation <> S.generation then Exit;
      Height := Stream.scrollHeight;
      S.older := Data.messages.length = 50;
      for I := 0 to Data.messages.length - 1 do Upsert(TMsg(Data.messages[I]), Stream, S.messages, False);
      Regroup(Stream);
      Stream.scrollTop := Stream.scrollHeight - Height;
    except
      Failed(JSExceptValue);
    end;
  finally
    S.loadingOlder := False;
  end;
end;

procedure AddMessages(List: TJSArray; Initial: boolean);
var
  Stick: boolean;
  Empty: TEl;
  I: NativeInt;
begin
  Stick := Initial or Stream.pinned or NearBottom;
  Empty := Find('.empty', Stream);
  if (Empty <> nil) and (List.length <> 0) then Empty.remove;
  for I := 0 to List.length - 1 do Upsert(TMsg(List[I]), Stream, S.messages, False);
  Regroup(Stream);
  if Stick then
  begin
    Stream.scrollTop := Stream.scrollHeight;
    Stream.pinned := True;
  end;
end;

procedure Upsert(M: TMsg; Box: TEl; Map: TJSMap; InThread: boolean);
var
  Old: TEntry;
  Node, After: TEl;
  Nodes: TJSNodeList;
  I: NativeInt;
begin
  Old := TEntry(Map.get(M.id));
  if Truthy(Old) and (Old.data.rev = M.rev) then Exit;
  Node := RenderMessage(M, InThread);
  if Truthy(Old) then Old.node.replaceWith(Node)
  else
  begin
    After := nil;
    Nodes := Box.querySelectorAll(':scope > .msg');
    for I := Nodes.length - 1 downto 0 do
      if NumberOf(TEl(Nodes[I]).dataset['id']) < M.id then
      begin
        After := TEl(Nodes[I]);
        Break;
      end;
    if After <> nil then After.after(Node)
    else Box.prepend(Node);
  end;
  Map.&set(M.id, new(['data', M, 'node', Node]));
  if (Box = Stream) and (M.id < S.oldest) then S.oldest := M.id;
end;

// Runs of messages by one person close together share one header; days and
// the first unread message get a line.
procedure Regroup(Box: TEl);
var
  Lines, Nodes: TJSNodeList;
  Prev, Node, Line: TEl;
  When: TJSDate;
  Day: string;
  Together: boolean;
  I: NativeInt;
begin
  Lines := Box.querySelectorAll(':scope > .day, :scope > .divider');
  for I := 0 to Lines.length - 1 do TEl(Lines[I]).remove;
  Prev := nil;
  Nodes := Box.querySelectorAll(':scope > .msg');
  for I := 0 to Nodes.length - 1 do
  begin
    Node := TEl(Nodes[I]);
    When := TJSDate.new(Node.dataset['at']);
    Day := When.toDateString;
    if (Prev = nil) or (TJSDate.new(Prev.dataset['at']).toDateString <> Day) then
    begin
      Line := El('div', 'day');
      Line.appendChild(El('span', '', DayLabel(When)));
      Node.before(Line);
      Prev := nil;
    end;
    if (Box = Stream) and Truthy(S.divider) and (NumberOf(Node.dataset['id']) = S.divider) then
    begin
      Line := El('div', 'divider');
      Line.appendChild(El('span', '', T('New')));
      Node.before(Line);
      Prev := nil;
    end;
    Together := (Prev <> nil) and (Prev.dataset['name'] = Node.dataset['name']) and not Prev.classList.contains('system')
      and (When.Time - TJSDate.new(Prev.dataset['at']).Time < 6 * 60000) and not Node.classList.contains('hasthread')
      and not Prev.classList.contains('hasthread');
    Toggle(Node, 'cont', Together);
    Prev := Node;
  end;
  if (Box = Stream) and (S.view = 'dm') then MarkSeen;
end;

// What other scripts show over a room's messages.
procedure RenderCard(Info: TRoomInfo);
var
  Card: TEl;
  Show: TCard;
  I: NativeInt;
begin
  Card := Find('#card');
  Card.replaceChildren;
  for I := 0 to Extras.cards.length - 1 do
  begin
    Show := TCard(Extras.cards[I]);
    Show(Info, Card);
  end;
end;

procedure Start;
begin
  window.setInterval(procedure
    begin
      if Length(TJSObject.keys(S.typers)) <> 0 then RenderTyping;
    end, 1000);
  Stream.addEventListener('scroll', TJSRawEventHandler(@StreamScrolled));
end;

end.
