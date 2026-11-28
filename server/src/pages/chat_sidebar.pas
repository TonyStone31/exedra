unit chat_sidebar;

{ The side list: channels, private conversations, notices, and the menus opened from it. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, chat_shared;

procedure RenderSidebar;
procedure DeleteDm(const Name: string); async;
procedure NotifyNews(Rooms, Dms: TJSArray);
procedure Start;

implementation

uses weborworker, chat_menu, chat_sync, chat_panels;

type
  // A control's own properties ([] on an element reads and writes attributes).
  TCtl = class external name 'HTMLElement'(TEl)
    &type: string;
    value: string;
  end;
  // A group of the list: its title, which rooms it takes, the sign before each.
  TGroup = class external name 'Object'(TJSObject)
    title: JSValue;
    test: TJSArrayCallBack;
    sigil: JSValue;
    button: TJSObject;
    always: JSValue;
  end;
  // A room as the list has it.
  TRoom = class external name 'Object'(TJSObject)
    slug: string;
    kind: string;
    title: string;
    &private: boolean;
    avatar: JSValue;
    owner: JSValue;
    notify: string;
    mentions: double;
    unread: double;
  end;
  // A private conversation as the list has it.
  TDm = class external name 'Object'(TJSObject)
    name: string;
    avatar: JSValue;
    unread: double;
  end;
  TNotice = class external name 'Object'(TJSObject)
    id: JSValue;
    text: string;
    link: JSValue;
  end;
  // A held finger: where it came down, its timer, the message whose menu it opened.
  THold = class external name 'Object'(TJSObject)
    x: double;
    y: double;
    timer: NativeInt;
    opened: TEl;
  end;

const
  HOLD_MS = 500;
  HOLD_SLIP = 10;

var
  Groups: TJSArray;
  Hold: THold;
  Permission: string; external name 'Notification.permission';

function Hypot(A, B: double): double; external name 'Math.hypot';

procedure SetNotify(R: TRoom; const Mode: string); async; forward;
procedure LeaveRoom(R: TRoom); async; forward;
procedure DeleteRoom(R: TRoom); async; forward;

// A notice links to a page of this site, never elsewhere.
function NoticePath(Path: JSValue): JSValue;
begin
  if (jsTypeOf(Path) = 'string') and (TJSString(Path).charAt(0) = '/') and (TJSString(Path).charAt(1) <> '/') and
    (TJSString(Path).charAt(1) <> '\') then Result := Path
  else Result := '/';
end;

function RoomMenuItems(R: TRoom): TJSArray;
var
  Items: TJSArray;
begin
  Items := TJSArray.new;
  if (Me.name = '') or (R.kind = 'shelf') then Exit(Items);
  if R.notify <> 'none' then Items.push(TJSArray._of(T('Silence channel'), procedure begin SetNotify(R, 'none'); end));
  if R.notify <> 'mentions' then Items.push(TJSArray._of(T('Mentions only'), procedure begin SetNotify(R, 'mentions'); end));
  if Truthy(R.notify) and (R.notify <> 'all') then
    Items.push(TJSArray._of(T('Notify about everything'), procedure begin SetNotify(R, 'all'); end));
  Items.push(TJSArray._of(T('Leave channel'), procedure begin LeaveRoom(R); end));
  if R.&private and Truthy(R.owner) then Items.push(TJSArray._of(T('Delete channel'), procedure begin DeleteRoom(R); end));
  Result := Items;
end;

procedure RenderSidebar;
var
  Nav: TEl;
  Words: string;
  Unread: double;
  List: TJSArray;
  I: NativeInt;
  Head: TEl;
  Name: JSValue;
  Count: string;

  procedure AddRoom(G: TGroup; R: TRoom);
  var
    Href, Badge: string;
    A: TJSHTMLAnchorElement;
    Quiet: boolean;
    Lock, More: TEl;
    Items: TJSArray;
  begin
    if R.kind = 'shelf' then Href := '/u/' + Enc(R.title) else Href := '/p/' + Enc(R.slug);
    A := Link(Href, 'room');
    A.dataset['slug'] := R.slug;
    if R.slug = S.room then A.classList.add('active');
    // a silenced channel keeps quiet: no unread mark and no badge; one on
    // mentions only shows the mention badge alone
    Quiet := R.notify = 'none';
    if Quiet then A.classList.add('quiet');
    if Truthy(R.unread) and not Quiet and (R.notify <> 'mentions') then A.classList.add('unread');
    if R.&private then
    begin
      Lock := El('span', 'sigil');
      Lock.appendChild(Icon('lock'));
      A.appendChild(Lock);
    end
    else if R.avatar then A.appendChild(Avatar(R.title, R.avatar, 'tiny roomicon'))
    else A.appendChild(El('span', 'sigil', G.sigil));
    A.appendChild(El('span', 'name', R.title));
    if Truthy(R.mentions) and not Quiet then A.appendChild(El('span', 'badge mention', '@' + String(JSValue(R.mentions))))
    else if Truthy(R.unread) and not Quiet and (R.notify <> 'mentions') then
    begin
      if R.unread > 99 then Badge := '99+' else Badge := String(JSValue(R.unread));
      A.appendChild(El('span', 'badge', Badge));
    end;
    // The row's own menu: how much it may bother you, leave, and for a
    // private channel of one's own, delete.
    Items := RoomMenuItems(R);
    if Items.length <> 0 then
    begin
      More := IconButton('down', T('More'), 'rowmenu');
      More.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
        begin
          E.preventDefault;
          E.stopPropagation;
          PopMenu(More, Items);
        end));
      A.appendChild(More);
    end;
    Nav.appendChild(A);
    if not Quiet then Unread := Unread + R.mentions;
  end;

  procedure AddGroup(G: TGroup);
  var
    Rooms: TJSArray;
    Head, Add, Extra: TEl;
    Title: JSValue;
    J: NativeInt;
  begin
    Rooms := S.rooms.filter(G.test).filter(function(Room: JSValue; Index: NativeInt; All: TJSArray): boolean
      begin
        Result := (Words = '') or TJSString(TJSString(TRoom(Room).title).toLowerCase).includes(Words) or
          TJSString(TRoom(Room).slug).includes(Words);
      end);
    Head := El('div', 'group');
    if Same(G.title, 'Channels') then Title := T('Channels')
    else if Same(G.title, 'Shelves') then Title := T('Shelves')
    else if Same(G.title, 'Benches') then Title := T('Benches')
    else Title := G.title;
    Head.appendChild(El('span', '', Title));
    if Same(G.title, 'Channels') and (May('create-private') or May('create-channel')) then
    begin
      Add := IconButton('plus', T('Open a channel'));
      Add.classList.add('small');
      Add.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin NewRoom; end));
      Head.appendChild(Add);
    end;
    if Truthy(G.button) then
    begin
      Extra := El('button', 'small-link', G.button['label']);
      TCtl(Extra).&type := 'button';
      Extra.addEventListener('click', G.button['click']);
      Head.appendChild(Extra);
    end;
    if (Rooms.length = 0) and not Truthy(G.always) then Exit;
    Nav.appendChild(Head);
    for J := 0 to Rooms.length - 1 do AddRoom(G, TRoom(Rooms[J]));
  end;

  procedure AddDm(D: TDm);
  var
    A: TJSHTMLAnchorElement;
    More: TEl;
  begin
    if (Words <> '') and not TJSString(TJSString(D.name).toLowerCase).includes(Words) then Exit;
    A := Link('/dm/' + Enc(D.name), 'room person');
    if (S.view = 'dm') and (S.dm = D.name) then A.classList.add('active');
    if Truthy(D.unread) then A.classList.add('unread');
    A.append(Avatar(D.name, D.avatar, 'tiny'), El('span', 'name', D.name));
    if Truthy(D.unread) then A.appendChild(El('span', 'badge mention', String(JSValue(D.unread))));
    More := IconButton('down', T('More'), 'rowmenu');
    More.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        E.preventDefault;
        E.stopPropagation;
        PopMenu(More, TJSArray._of(TJSArray._of(T('Delete conversation'), procedure begin DeleteDm(D.name); end)));
      end));
    A.appendChild(More);
    Nav.appendChild(A);
    Unread := Unread + D.unread;
  end;

  procedure AddNotice(N: TNotice);
  var
    A: TJSHTMLAnchorElement;
  begin
    A := Link(NoticePath(N.link), 'room notice unread');
    A.append(El('span', 'sigil', '!'), El('span', 'name', N.text));
    A.title := N.text;
    A.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      var
        Dest: string;
      begin
        E.preventDefault;
        Dest := A.getAttribute('href');
        Post('/api/notices', new(['id', String(N.id)])).catch(function(Why: JSValue): JSValue begin end)
          ._then(function(Value: JSValue): JSValue begin window.location.assign(Dest); end);
      end));
    Nav.appendChild(A);
  end;

begin
  Nav := Find('#roomlist');
  Words := TJSString(TJSString(TCtl(Find('#jump')).value).toLowerCase).trim;
  Nav.replaceChildren;
  Unread := 0;
  List := TJSArray._of(Groups[0]).concat(Extras.groups, Groups.slice(1));
  for I := 0 to List.length - 1 do AddGroup(TGroup(List[I]));
  if S.dms.length <> 0 then
  begin
    Head := El('div', 'group');
    Head.appendChild(El('span', '', T('Private')));
    Nav.appendChild(Head);
    for I := 0 to S.dms.length - 1 do AddDm(TDm(S.dms[I]));
  end;
  // what the site itself has to tell the member: a release that failed, a claim
  if Truthy(Notices.unseen) then
  begin
    Head := El('div', 'group');
    Head.appendChild(El('span', '', T('Notices')));
    Nav.appendChild(Head);
    for I := 0 to Notices.items.length - 1 do AddNotice(TNotice(Notices.items[I]));
    if Notices.unseen > Notices.items.length then
      Nav.appendChild(El('div', 'hint', TN(Notices.unseen - Notices.items.length, '%d more notice', '%d more notices')));
    Unread := Unread + Notices.unseen;
  end;
  if Truthy(Unread) then Count := '(' + String(JSValue(Unread)) + ') ' else Count := '';
  if S.title then Name := S.title else Name := Site;
  document.title := Count + String(Name) + ' - ' + String(Site);
end;

// How much the channel may bother this member: all, mentions or none. The
// server stops pushing and mailing about a silenced one; the page stops
// badging and announcing it.
procedure SetNotify(R: TRoom; const Mode: string); async;
begin
  try
    await(JSValue, Post('/api/follow/notify', new(['room', R.slug, 'mode', Mode])));
    R.notify := Mode;
    RenderSidebar;
    if Mode = 'none' then Toast(T('%s is silenced.', R.title))
    else if Mode = 'mentions' then Toast(T('Only mentions in %s from now on.', R.title))
    else Toast(T('%s notifies about everything again.', R.title));
  except
    Failed(JSExceptValue);
  end;
end;

// Leaving takes the channel out of the sidebar; a private one asks first,
// since only an invite gets the member back in.
procedure LeaveRoom(R: TRoom); async;
begin
  if R.&private and not window.confirm(T('Leave %s? Only an invite gets you back in.', R.title)) then Exit;
  try
    await(JSValue, Post('/api/follow', new(['room', R.slug, 'on', '0'])));
    S.rooms := S.rooms.filter(function(X: JSValue; Index: NativeInt; All: TJSArray): boolean
      begin Result := TRoom(X).slug <> R.slug; end);
    RenderSidebar;
    if (S.view = 'room') and (S.room = R.slug) then Route('/', True)
    else SyncNow(True);
  except
    Failed(JSExceptValue);
  end;
end;

// The owner's private channel, gone for good with everything in it; the
// other members' pages leave it on the server's ring.
procedure DeleteRoom(R: TRoom); async;
var
  Said: JSValue;
begin
  if not window.confirm(T('Delete %s?'#10#10'Everything said in it and every file goes, for everyone in it. This cannot be undone.', R.title)) then Exit;
  try
    Said := await(JSValue, Post('/api/room/delete', new(['slug', R.slug])));
    S.rooms := S.rooms.filter(function(X: JSValue; Index: NativeInt; All: TJSArray): boolean
      begin Result := TRoom(X).slug <> R.slug; end);
    RenderSidebar;
    if (S.view = 'room') and (S.room = R.slug) then Route('/', True);
    if jsTypeOf(Said) = 'string' then Toast(Said) else Toast(T('Channel deleted.'));
  except
    Failed(JSExceptValue);
  end;
end;

// This member's copy only; the other keeps theirs (/api/dm/delete).
procedure DeleteDm(const Name: string); async;
begin
  if not window.confirm(T('Delete your conversation with %s?'#10#10'Your copy is gone for good. %s keeps theirs. If they write again, a new conversation starts.', Name, Name)) then Exit;
  try
    await(JSValue, Post('/api/dm/delete', new(['with', Name])));
    S.dms := S.dms.filter(function(D: JSValue; Index: NativeInt; All: TJSArray): boolean
      begin Result := TDm(D).name <> Name; end);
    RenderSidebar;
    if (S.view = 'dm') and (S.dm = Name) then Route('/', True);
    Toast(T('Conversation deleted.'));
  except
    Failed(JSExceptValue);
  end;
end;

// Mentions and private messages that arrive while the member looks
// elsewhere become a notification.
procedure NotifyNews(Rooms, Dms: TJSArray);
var
  Seen: TJSObject;
  News: TJSArray;
  R: TRoom;
  D: TDm;
  Key, Sign: string;
  I: NativeInt;
begin
  Seen := S.alerts;
  News := TJSArray.new;
  for I := 0 to Rooms.length - 1 do
  begin
    R := TRoom(Rooms[I]);
    Key := 'r:' + R.slug;
    if not Same(Seen[Key], undefined) and (R.mentions > NumberOf(Seen[Key])) and (R.notify <> 'none') and
      (document.hidden or (R.slug <> S.room)) then
    begin
      if R.kind = 'channel' then Sign := '#' else Sign := '';
      News.push(T('You were mentioned in %s', Sign + R.title));
    end;
    Seen[Key] := R.mentions;
  end;
  for I := 0 to Dms.length - 1 do
  begin
    D := TDm(Dms[I]);
    Key := 'd:' + D.name;
    if not Same(Seen[Key], undefined) and (D.unread > NumberOf(Seen[Key])) and (document.hidden or (S.dm <> D.name)) then
      News.push(T('%s sent you a private message', D.name));
    Seen[Key] := D.unread;
  end;
  if News.length = 0 then Exit;
  if jsIn('Notification', window) and (Permission = 'granted') and document.hidden then Notify(Site, News.join(#10))
  else News.forEach(procedure(N: JSValue; Index: NativeInt; All: TJSArray) begin Toast(N); end);
end;

// Right click, touch hold and the Menu key open the message menu. Links,
// pictures, code, controls, selected text and Shift keep the browser menu.
function MenuHere(Node: TEl; Target: TJSElement): boolean;
var
  Marked: TJSSelection;
begin
  Marked := window.getSelection;
  Result := (Target.closest('a, img, pre, code, button, textarea, input') = nil) and
    (Marked.isCollapsed or not Marked.containsNode(Node, True));
end;

procedure DropHold;
begin
  if Hold <> nil then window.clearTimeout(Hold.timer);
  Hold := nil;
end;

procedure Start;
var
  FindAll: TJSHTMLElement;
begin
  // The left column's button that searches every channel, in the main area.
  FindAll := TJSHTMLElement(document.getElementById('findall'));
  if FindAll <> nil then
  begin
    FindAll.hidden := False;
    TEl(FindAll).prepend(Side.icon('search'));
    FindAll.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        document.body.classList.remove('menu');
        Route('/chat-search', True);
      end));
  end;

  Groups := TJSArray._of(
    new(['title', 'Channels', 'sigil', '#', 'test',
      function(R: JSValue; Index: NativeInt; All: TJSArray): boolean begin Result := TRoom(R).kind = 'channel'; end]),
    // a bench is the channel of a page: listed apart, and only the ones followed
    new(['title', 'Benches', 'sigil', '', 'test',
      function(R: JSValue; Index: NativeInt; All: TJSArray): boolean begin Result := TRoom(R).kind = 'bench'; end]),
    new(['title', 'Shelves', 'sigil', '~', 'test',
      function(R: JSValue; Index: NativeInt; All: TJSArray): boolean begin Result := TRoom(R).kind = 'shelf'; end]));

  Find('#jump').addEventListener('input', TJSRawEventHandler(procedure(E: TJSEvent) begin RenderSidebar; end));
  Find('#jump').addEventListener('keydown', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      First: TEl;
    begin
      if TJSKeyboardEvent(E).key <> 'Enter' then Exit;
      First := Find('#roomlist a.room');
      if First <> nil then
      begin
        Route(SiteBase.strip(First.getAttribute('href')), True);
        TCtl(E.currentTarget).value := '';
        RenderSidebar;
      end;
    end));

  document.addEventListener('contextmenu', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Node: TEl;
      OnArrow: TJSElement;
    begin
      Node := TEl(TJSElement(E.target).closest('.msg'));
      if (Node = nil) or not Node.menu then Exit;
      OnArrow := TJSElement(E.target).closest('.more');
      if (OnArrow = nil) and (TJSMouseEvent(E).shiftKey or not MenuHere(Node, TJSElement(E.target))) then Exit;
      E.preventDefault;
      // a phone sends this for a held finger too: the hold timed below has
      // opened the menu already, or is not waited for
      if (Hold <> nil) and (Hold.opened = Node) then Exit;
      DropHold;
      if OnArrow <> nil then OpenMenu(Node, nil)
      else OpenMenu(Node, new(['x', TJSMouseEvent(E).clientX, 'y', TJSMouseEvent(E).clientY]));
    end));

  // An iPhone sends no contextmenu for a held finger, so the hold is timed
  // here: one finger that stays where it came down opens the menu there.
  // Moving it (scrolling) or lifting it sooner (a tap) does not.
  document.addEventListener('touchstart', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Touches: TJSArray;
      Node: TEl;
      Held: THold;
    begin
      DropHold;
      Touches := TJSArray(JSValue(TJSTouchEvent(E).touches));
      if Touches.length <> 1 then Exit;
      Node := TEl(TJSElement(E.target).closest('.msg'));
      if (Node = nil) or not Node.menu or not MenuHere(Node, TJSElement(E.target)) then Exit;
      Held := THold(new(['x', TJSTouch(Touches[0]).clientX, 'y', TJSTouch(Touches[0]).clientY]));
      Held.timer := window.setTimeout(procedure
        begin
          Held.opened := Node;
          OpenMenu(Node, Held);
        end, HOLD_MS);
      Hold := Held;
    end), TJSEventListenerOptions(new(['passive', True])));
  document.addEventListener('touchmove', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Touches: TJSArray;
    begin
      Touches := TJSArray(JSValue(TJSTouchEvent(E).touches));
      if (Hold <> nil) and not Truthy(Hold.opened) and
        (Hypot(TJSTouch(Touches[0]).clientX - Hold.x, TJSTouch(Touches[0]).clientY - Hold.y) > HOLD_SLIP) then DropHold;
    end), TJSEventListenerOptions(new(['passive', True])));
  // the finger that opened the menu comes up over it: that is no tap on what lies there
  document.addEventListener('touchend', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      if (Hold <> nil) and Truthy(Hold.opened) and E.cancelable then E.preventDefault;
      DropHold;
    end));
  document.addEventListener('touchcancel', TJSRawEventHandler(procedure(E: TJSEvent) begin DropHold; end));
end;

end.
