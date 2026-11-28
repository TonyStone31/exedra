unit chat_panels;

{ The side panel: a thread, pinned messages, people, a new channel, and the searches. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, chat_shared;

procedure OpenThread(Id: double); async;
procedure AddThread(Messages: TJSArray);
procedure OpenPins; async;
procedure OpenMembers; async;
procedure Command(const Text: string); async;
procedure NewRoom;
procedure OpenSearchAll;
procedure OpenSearch;

implementation

uses chat_rooms, chat_messages, chat_answer, chat_sync, chat_composer, chat_private;

type
  // Someone in the list of who is here, or of a channel's members.
  TPerson = class external name 'Object'(TJSObject)
    name: string;
    avatar: JSValue;
    away: JSValue;
    online: JSValue;
    owner: JSValue;
    roles: JSValue;
  end;

function ParseJson(Text: JSValue): JSValue; external name 'JSON.parse';

var
  // The words of the search of all chats stay while the reader looks at a hit and comes back.
  AllWords: string = '';

procedure OpenThread(Id: double); async;
var
  Box, List, Area: TEl;
  Messages: TJSArray;
begin
  Box := OpenPanel(T('Thread'), 'thread');
  S.thread := Id;
  S.threadMessages.clear;
  List := El('div', 'threadlist');
  Box.appendChild(List);
  KeepPinned(List);
  if SiteBase.path <> '/m/' + String(JSValue(Id)) then
    window.history.replaceState(TJSObject.new, '', '/m/' + String(JSValue(Id)));
  try
    Messages := await(TJSArray, Get('/api/thread?id=' + String(JSValue(Id))));
    if S.thread <> Id then Exit;
    AddThread(Messages);
  except
    Failed(JSExceptValue);
  end;
  Area := El('div', 'panelcomposer');
  Box.appendChild(Area);
  RenderComposer(Area, Id);
end;

procedure AddThread(Messages: TJSArray);
var
  List, Root, Count: TEl;
  Stick: boolean;
  I: NativeInt;
begin
  List := Find('.threadlist', Panel);
  if not Truthy(List) then Exit;
  Stick := List.pinned or NearBottom(List);
  for I := 0 to Messages.length - 1 do Upsert(TMsg(Messages[I]), List, S.threadMessages, True);
  Root := TEl(List.querySelector('.msg'));
  if Truthy(Root) and not Truthy(Find('.threadcount', List)) then Root.after(El('div', 'threadcount'));
  Count := Find('.threadcount', List);
  if Truthy(Count) then Count.textContent := TN(S.threadMessages.size - 1, '%d replies', '%d replies');
  Regroup(List);
  if Stick then List.scrollTop := List.scrollHeight;
end;

procedure OpenPins; async;
var
  Box, Holder: TEl;
  List: TJSArray;
  I: NativeInt;
begin
  Box := OpenPanel(T('Pinned'), 'pins');
  try
    List := await(TJSArray, Get('/api/pins?room=' + Enc(S.room)));
    if not Truthy(List.length) then
      Box.appendChild(El('p', 'notice',
        T('Nothing is pinned here. The channel''s owner and moderators pin messages that should stay in view.')));
    Holder := El('div', 'threadlist');
    for I := 0 to List.length - 1 do Holder.appendChild(RenderMessage(TMsg(List[I]), True));
    Box.appendChild(Holder);
  except
    Failed(JSExceptValue);
  end;
end;

// A member's standing at a glance: green here, yellow here but away, gray
// not here. The title says it in words for a screen reader.
function StatusDot(Online, Away: JSValue): TEl;
var
  State: string;
begin
  if Online then
  begin
    if Away then State := 'away' else State := 'online';
  end
  else State := 'off';
  Result := El('span', 'dot ' + State);
  if State = 'online' then Result.title := T('Online')
  else if State = 'away' then Result.title := T('Away')
  else Result.title := T('Not here');
end;

function SmallFace(P: TPerson): string;
begin
  if P.away then Result := 'small away' else Result := 'small';
end;

// Who is here now, then who is in a private room (with invite and take-out)
// or holds a role in a public one.
procedure OpenMembers; async;
var
  Info: TRoomInfo;
  Box, Here, List, Form: TEl;
  Name: TJSHTMLInputElement;
  Go: TEl;
  I: NativeInt;

  procedure Show; async; forward;

  procedure AddHere(P: TPerson);
  var
    Who: TJSHTMLAnchorElement;
    Row: TEl;
  begin
    Who := Link('/u/' + Enc(P.name), 'who');
    Who.append(Avatar(P.name, P.avatar, SmallFace(P)), StatusDot(True, P.away), El('span', '', P.name));
    Row := El('div', 'person');
    Row.appendChild(Who);
    if P.away then Row.appendChild(El('span', 'role', T('away')));
    Here.appendChild(Row);
  end;

  procedure AddMember(P: TPerson);
  var
    Who: TJSHTMLAnchorElement;
    Row, Out: TEl;
  begin
    Row := El('div', 'person');
    Who := Link('/u/' + Enc(P.name), 'who');
    Who.append(Avatar(P.name, P.avatar, SmallFace(P)), StatusDot(P.online, P.away), El('span', '', P.name));
    Row.appendChild(Who);
    if P.owner then Row.appendChild(El('span', 'role', T('owner')));
    if P.roles then
      Row.appendChild(El('span', 'role', TJSString(P.roles).replace('room-moderator', T('moderator'))));
    if Info.&private and MayHere('kick') and not Truthy(P.owner) and (P.name <> Me.name) then
    begin
      Out := El('button', 'small-link', T('Take out'));
      TJSHTMLButtonElement(TJSElement(Out))._type := 'button';
      Out.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) async
        begin
          await(Command('/kick ' + P.name));
          Show;
        end));
      Row.appendChild(Out);
    end;
    List.appendChild(Row);
  end;

  procedure Show; async;
  var
    People: TJSArray;
    N: NativeInt;
  begin
    try
      People := await(TJSArray, Get('/api/room/members?room=' + Enc(Info.slug)));
      List.replaceChildren;
      if not Truthy(People.length) then
        if Info.owner then
          List.appendChild(El('p', 'notice', T('%s owns this channel. Nobody else holds a role in it.', Info.owner)))
        else
          List.appendChild(El('p', 'notice', T('Nobody holds a role in this channel. Site moderators look after it.')));
      for N := 0 to People.length - 1 do AddMember(TPerson(People[N]));
    except
      Failed(JSExceptValue);
    end;
  end;

begin
  Info := S.info;
  Box := OpenPanel(T('People'), 'members');
  if Truthy(S.here.length) then Box.appendChild(El('h4', '', T('Here now')))
  else Box.appendChild(El('h4', '', T('Nobody else is here right now')));
  Here := El('div', 'memberlist');
  for I := 0 to S.here.length - 1 do AddHere(TPerson(S.here[I]));
  Box.appendChild(Here);
  if Info.&private then Box.appendChild(El('h4', '', T('In this channel')))
  else Box.appendChild(El('h4', '', T('Channel moderators')));
  List := El('div', 'memberlist');
  Box.appendChild(List);
  await(Show);
  if Info.&private and MayHere('invite') then
  begin
    Form := El('form', 'invite');
    Name := TJSHTMLInputElement(TJSElement(El('input')));
    Name.placeholder := T('Invite someone by name');
    Go := El('button', 'primary', T('Invite'));
    Form.append(Name, Go);
    Form.addEventListener('submit', TJSRawEventHandler(procedure(E: TJSEvent) async
      begin
        E.preventDefault;
        if TJSString(Name.value).trim = '' then Exit;
        await(Command('/invite ' + TJSString(Name.value).trim));
        Name.value := '';
        Show;
      end));
    Box.appendChild(Form);
  end;
  if Info.&private then
    Box.appendChild(El('p', 'hint',
      T('Commands work too: /invite name, /kick name, /op name makes a channel moderator.')))
  else
    Box.appendChild(El('p', 'hint',
      T('The owner names channel moderators with /op name. /mute name [minutes] quiets someone here.')));
end;

// Runs a slash command in the open room, showing its answer as a toast.
procedure Command(const Text: string); async;
var
  Answer: TJSObject;
begin
  try
    Answer := TJSObject(ParseJson(await(JSValue, Post('/api/post', new(['room', S.room, 'body', Text])))));
    if Answer['info'] then Toast(Answer['info']);
    SyncNow;
  except
    Failed(JSExceptValue);
  end;
end;

// Opening a room: public channels for those allowed, private rooms for members.
procedure NewRoom;
var
  Box, Form, NameLabel, TopicLabel, Kind, Go: TEl;
  Name, Topic, Priv: TJSHTMLInputElement;
begin
  Box := OpenPanel(T('Open a channel'), 'newroom');
  Body.classList.remove('menu');
  Form := El('form', 'settings');
  NameLabel := El('label');
  NameLabel.appendChild(El('span', '', T('Name')));
  Name := TJSHTMLInputElement(TJSElement(El('input')));
  Name.placeholder := T('lowercase-with-hyphens');
  Name.maxLength := 40;
  NameLabel.appendChild(Name);
  TopicLabel := El('label');
  TopicLabel.appendChild(El('span', '', T('What it is for')));
  Topic := TJSHTMLInputElement(TJSElement(El('input')));
  TopicLabel.appendChild(Topic);
  Kind := El('label', 'check');
  Priv := TJSHTMLInputElement(TJSElement(El('input')));
  Priv._type := 'checkbox';
  Priv.checked := not May('create-channel');
  Priv.disabled := not May('create-channel') or not May('create-private');
  Kind.append(Priv, document.createTextNode(T(' Private: only people invited see it')));
  Go := El('button', 'primary', T('Open it'));
  Form.append(NameLabel, TopicLabel, Kind, Go);
  Box.appendChild(Form);
  Name.focus;
  Name.addEventListener('input', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      Name.value := TJSString(TJSString(Name.value).toLowerCase).replace(TJSRegexp.new('[^a-z0-9-]+', 'g'), '-');
    end));
  Form.addEventListener('submit', TJSRawEventHandler(procedure(E: TJSEvent) async
    var
      Made: TJSObject;
      Flag: string;
    begin
      E.preventDefault;
      try
        if Priv.checked then Flag := '1' else Flag := '0';
        Made := TJSObject(ParseJson(await(JSValue, Post('/api/room/create', new([
          'slug', TJSString(Name.value).replace(TJSRegexp.new('^-+|-+$', 'g'), ''),
          'topic', Topic.value, 'private', Flag])))));
        RoomsWanted := True;
        Route('/p/' + Enc(Made['slug']), True);
      except
        Failed(JSExceptValue);
      end;
    end));
end;

// A hit of a search opens its message, but for a click on a link or a button in it.
procedure OpensMessage(Node: TEl; M: TMsg);
begin
  Node.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      if Truthy(TJSElement(E.target).closest('a, button')) then Exit;
      Route('/m/' + String(JSValue(M.id)), True);
    end));
end;

// Every channel the reader may read, searched in the main area.
procedure OpenSearchAll;
var
  Head, MenuButton, Results: TEl;
  Input: TJSHTMLInputElement;
  Timer, Asked: NativeInt;

  procedure AddHit(M: TMsg);
  var
    Node, Header: TEl;
  begin
    Node := RenderMessage(M, True);
    Node.classList.add('result');
    // which channel it was said in
    Header := TEl(Node.querySelector('header'));
    if Truthy(Header) then Header.appendChild(El('span', 'where', '#' + M.room));
    OpensMessage(Node, M);
    Results.appendChild(Node);
  end;

  procedure Run; async;
  var
    Q: string;
    Turn, I: NativeInt;
    List: TJSArray;
  begin
    AllWords := TJSString(Input.value).trim;
    Q := AllWords;
    Inc(Asked);
    Turn := Asked;
    if TJSString(Q).length < 2 then
    begin
      Results.replaceChildren;
      Exit;
    end;
    try
      List := await(TJSArray, Get('/api/search?q=' + Enc(Q)));
      if (Turn <> Asked) or not Results.isConnected then Exit;
      Results.replaceChildren;
      if not Truthy(List.length) then Results.appendChild(El('p', 'notice', T('Nothing found.')));
      for I := 0 to List.length - 1 do AddHit(TMsg(List[I]));
    except
      Failed(JSExceptValue);
    end;
  end;

begin
  S.view := 'search';
  S.title := T('Search all chats');
  Head := Find('#roomhead');
  MenuButton := IconButton('menu', T('Channels'), 'menubtn');
  MenuButton.addEventListener('click', ToggleMenu);
  Head.append(MenuButton, El('div', 'titles'));
  Find('.titles', Head).appendChild(El('h1', '', S.title));
  Stream.className := 'findall-view';
  Stream.noPin := True;
  Input := TJSHTMLInputElement(TJSElement(El('input')));
  Input._type := 'search';
  Input.placeholder := T('Words to find');
  Input.value := AllWords;
  Results := El('div', 'findall-hits');
  Stream.append(Input, El('p', 'notice',
    T('Looks in every channel you can read. A private conversation is searched from inside it.')), Results);
  Timer := 0;
  Asked := 0;
  Input.addEventListener('input', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      window.clearTimeout(Timer);
      Timer := window.setTimeout(procedure begin Run; end, 300);
    end));
  Input.focus;
  if AllWords <> '' then Run;
end;

procedure OpenSearch;
var
  Box, Scope, Results: TEl;
  Input, Only: TJSHTMLInputElement;
  InDm: boolean;
  WithName: string;
  Timer: NativeInt;

  procedure AddFound(M, Payload: TJSObject);
  var
    Node: TEl;
  begin
    Node := RenderDm(M, Payload);
    Node.classList.add('result');
    Node.querySelector('.more').remove;
    Node.menu := nil;
    Node.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      var
        There: TEl;
      begin
        if Truthy(TJSElement(E.target).closest('a, button')) then Exit;
        There := TEl(Stream.querySelector('.msg[data-id="' + String(M['id']) + '"]'));
        if not Truthy(There) or (S.dm <> WithName) then
        begin
          Toast(T('That message is further back.'));
          Exit;
        end;
        Flash(There);
      end));
    Results.appendChild(Node);
  end;

  procedure AddHit(M: TMsg);
  var
    Node: TEl;
  begin
    Node := RenderMessage(M, True);
    Node.classList.add('result');
    OpensMessage(Node, M);
    Results.appendChild(Node);
  end;

  procedure Run; async;
  var
    Q, Where: string;
    Found, List: TJSArray;
    I: NativeInt;
    M: TJSObject;
  begin
    Q := TJSString(Input.value).trim;
    if TJSString(Q).length < 2 then
    begin
      Results.replaceChildren;
      Exit;
    end;
    try
      if InDm and Only.checked then
      begin
        Found := await(TJSArray, Get('/api/dm/search?with=' + Enc(WithName) + '&q=' + Enc(Q)));
        Results.replaceChildren;
        if not Truthy(Found.length) then Results.appendChild(El('p', 'notice', T('Nothing found.')));
        Found.reverse;
        for I := 0 to Found.length - 1 do
        begin
          M := TJSObject(Found[I]);
          AddFound(M, await(OpenSealed(M)));
        end;
        Exit;
      end;
      Where := '';
      if Only.checked and not InDm then Where := '&room=' + Enc(S.room);
      List := await(TJSArray, Get('/api/search?q=' + Enc(Q) + Where));
      Results.replaceChildren;
      if not Truthy(List.length) then Results.appendChild(El('p', 'notice', T('Nothing found.')));
      for I := 0 to List.length - 1 do AddHit(TMsg(List[I]));
    except
      Failed(JSExceptValue);
    end;
  end;

begin
  Box := OpenPanel(T('Search'), 'search');
  Input := TJSHTMLInputElement(TJSElement(El('input')));
  Input._type := 'search';
  Input.placeholder := T('Words to find');
  Scope := El('label', 'scope');
  Only := TJSHTMLInputElement(TJSElement(El('input')));
  Only._type := 'checkbox';
  InDm := S.view = 'dm';
  WithName := S.dm;
  Only.checked := (S.view = 'room') or InDm;
  if InDm then Scope.append(Only, document.createTextNode(T(' only in this conversation')))
  else Scope.append(Only, document.createTextNode(T(' only in this channel')));
  Results := El('div', 'threadlist');
  Box.append(Input, Scope, Results);
  // The server finds words only in what it can read.
  if InDm and S.dmLocked then
    Box.insertBefore(El('p', 'notice', T('Locked messages are not searched: the server cannot read them.')), Results);
  Input.focus;
  Timer := 0;
  Input.addEventListener('input', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      window.clearTimeout(Timer);
      Timer := window.setTimeout(procedure begin Run; end, 300);
    end));
  Only.addEventListener('change', TJSRawEventHandler(procedure(E: TJSEvent) begin Run; end));
end;

end.
