unit chat_shared;

{ What the chat's units share: the page's shell as it was when the script
  loaded, the scripts beside it, what the server sends, and the state more
  than one unit keeps. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web;

type
  TProc = reference to procedure;

  // An element with the calls Web lacks and what the chat keeps on one.
  TEl = class external name 'HTMLElement'(TJSHTMLElement)
    isConnected: boolean;
    pinned: boolean;
    noPin: boolean;
    menu: JSValue;
    dm: TJSObject;
    procedure prepend(Node: TJSNode);
    procedure after(Node: TJSNode);
    procedure before(Node: TJSNode); overload;
    procedure replaceWith(Node: TJSNode);
    procedure append(Node: TJSNode); varargs; overload;
    procedure focus(Options: TJSObject); overload;
  end;
  // Web declares toggle with one argument only.
  TTokens = class external name 'DOMTokenList'(TJSDOMTokenList)
    function toggle(const Token: string; Force: boolean): boolean; overload;
  end;
  // Web gives these two to the input and not to the textarea.
  TArea = class external name 'HTMLTextAreaElement'(TJSHTMLTextAreaElement)
    procedure setSelectionRange(SelectionStart, SelectionEnd: NativeInt);
    procedure setRangeText(const Text: string; SelectionStart, SelectionEnd: NativeInt; const Mode: string);
  end;
  // Web declares only the string constructor.
  TParams = class external name 'URLSearchParams'(TJSURLSearchParams)
    constructor new(Data: TJSObject);
    procedure set_(const Name: string; Value: JSValue); external name 'set';
  end;

  // A message of a channel as the server sends it.
  TMsg = class external name 'Object'(TJSObject)
    id: double;
    room: string;
    parent: double;
    uid: JSValue;
    name: string;
    avatar: JSValue;
    badge: JSValue;
    at: string;
    edited: boolean;
    deleted: boolean;
    pinned: boolean;
    replies: double;
    last_reply: JSValue;
    rev: double;
    mentions_me: boolean;
    ignored: boolean;
    body: string;
    html: string;
    reactions: TJSArray;
    files: TJSArray;
    re: TJSObject;
    preview: TJSObject;
    names: TJSArray;
    dm: boolean;
  end;
  // A room as /api/room describes it.
  TRoomInfo = class external name 'Object'(TJSObject)
    slug: string;
    kind: string;
    title: string;
    topic: JSValue;
    avatar: JSValue;
    &private: boolean;
    owner: JSValue;
    following: boolean;
    can: TJSObject;
    can_start: boolean;
    can_reply: JSValue;
    why_not: JSValue;
    as_sent: boolean;
  end;
  // The message being answered and the box it is answered from.
  TAnswer = class external name 'Object'(TJSObject)
    key: string;
    re: TJSObject;
  end;
  // The shell's state (app.js) and what the chat adds to it.
  TChatState = class external name 'Object'(TJSObject)
    view: string;
    room: string;
    info: TRoomInfo;
    messages: TJSMap;
    since: double;
    lastRead: double;
    divider: double;
    oldest: double;
    older: boolean;
    thread: double;
    threadMessages: TJSMap;
    generation: double;
    rooms: TJSArray;
    dms: TJSArray;
    commands: TJSArray;
    typingSent: double;
    tick: double;
    alerts: TJSObject;
    dm: string;
    dmLast: double;
    dmFirst: double;
    dmTimer: NativeInt;
    beams: TJSObject;
    typers: TJSObject;
    here: TJSArray;
    title: JSValue;
    loadingOlder: boolean;
    answer: TAnswer;
    dmAvatar: JSValue;
    dmSeen: double;
    dmOlderDone: boolean;
    dmLocked: boolean;
  end;
  TChatMe = class external name 'Object'(TJSObject)
    name: string;
    avatar: JSValue;
    can: TJSArray;
    ignores: TJSArray;
    reactions: TJSObject;
    wrapped: JSValue;
    verified: boolean;
    password: JSValue;
  end;
  TChatExtras = class external name 'Object'(TJSObject)
    groups: TJSArray;
    cards: TJSArray;
    badges: TJSArray;
    rooms: TJSArray;
    commands: TJSObject;
    accountLinks: TJSArray;
  end;
  TPinWatch = class external name 'ResizeObserver'(TJSObject)
    procedure observe(Node: TJSNode);
  end;
  TChatShell = class external name 'Object'(TJSObject)
    parts: TJSArray;
    pinWatch: TPinWatch;
    procedure subscribePush;
    procedure offerNotifications;
  end;
  // The live connection: its socket, the id the server gave it, the next wait.
  TLive = class external name 'Object'(TJSObject)
    ws: TJSWebSocket;
    id: string;
    wait: double;
    failures: double;
  end;
  TNotices = class external name 'Object'(TJSObject)
    unseen: double;
    items: TJSArray;
  end;
  // The message menu that is open.
  TOpenMenu = class external name 'Object'(TJSObject)
    box: TEl;
    node: TEl;
    arrow: TEl;
  end;

  // The scripts beside this one, as the page publishes them.
  TChatSide = class external name 'Object'(TJSObject)
    function icon(const Name: string): TJSElement;
  end;
  TChatReactions = class external name 'Object'(TJSObject)
    function chips(List: TJSArray; Opts: TJSObject): TJSHTMLElement;
    procedure offer(Box: TJSHTMLElement; Lists, Pick, Resized: JSValue);
    procedure under(Box: TJSHTMLElement; R: JSValue);
  end;
  TChatEmoji = class external name 'Object'(TJSObject)
    function list: TJSPromise;
    function typed(const Text: string; At: NativeInt; Short: boolean): TJSObject;
    function matches(List: TJSArray; const Word: string): TJSArray;
    function named(List: TJSArray; const Word: string): TJSObject;
  end;
  TChatKeys = class external name 'Object'(TJSObject)
    function ready: boolean;
    function myKey: TJSPromise;
    function setupKeys(const Name, Password: string): TJSPromise;
    function unlock(const Name, Password: string; Wrapped: JSValue): TJSPromise;
    function partner(const Name: string): TJSPromise;
    function trust(const Name: string): TJSPromise;
    function seal(const Other: string; Payload: JSValue): TJSPromise;
    function open(const Other: string; Message: JSValue): TJSPromise;
    function sealFile(Other, Data, Expire: JSValue): TJSPromise;
    function openFile(const Other: string; Meta: JSValue): TJSPromise;
    function smaller(Data: JSValue): TJSPromise;
    function beamSend(const Other: string; Data, Progress: JSValue): TJSPromise;
    function beamReceive(Token, Progress: JSValue): TJSPromise;
  end;
  TChatBase = class external name 'Object'(TJSObject)
    function url(const Address: string): string;
    function path: string;
    function strip(const Address: string): string;
  end;

var
  Side: TChatSide; external name 'window.Side';
  Reactions: TChatReactions; external name 'window.Reactions';
  EmojiNames: TChatEmoji; external name 'window.EmojiNames';
  Keys: TChatKeys; external name 'window.Keys';
  SiteBase: TChatBase; external name 'window.SiteBase';

function T(const English: string): string; varargs; external name 'window.t';
function TN(N: JSValue; const One, Many: string): string; varargs; external name 'window.tn';
function DateTimeText(Value: JSValue): string; external name 'window.dateTimeText';

// JavaScript's own truthiness, number and whole number of a value.
function Truthy(Value: JSValue): boolean; external name 'Boolean';
function NumberOf(Value: JSValue): double; external name 'Number';
function ParseInt(Value: JSValue; Radix: NativeInt): double; external name 'parseInt';
function Max(A, B: double): double; external name 'Math.max';
function Min(A, B: double): double; external name 'Math.min';
function Random: double; external name 'Math.random';
// A === B for two values of any kind.
function Same(A, B: JSValue): boolean;
// classList.toggle(name, force)
function Toggle(Node: TJSElement; const Name: string; Force: boolean): boolean;

var
  // The shell's own, taken once when the script loads.
  C: TChatShell;
  Body: TJSHTMLElement;
  Stream: TEl;
  Panel: TEl;
  Site: JSValue;
  Me: TChatMe;
  S: TChatState;
  Extras: TChatExtras;
  // The shell's functions that are handed on as they are.
  ToggleMenu: TJSRawEventHandler;
  FailedFn: JSValue;

  // Kept by more than one unit.
  Notices: TNotices;      // the member's unseen notices from the site, the newest few
  Menu: TOpenMenu;        // the message menu that is open, or nil
  Live: TLive;
  RoomsWanted: boolean;   // the next sync asks for the room list too
  FromRing: boolean;      // the next sync was asked for by a ring

procedure Setup;

function Find(const Selector: string; Root: JSValue = undefined): TEl;
function El(const Tag: string; Cls: JSValue = undefined; Text: JSValue = undefined): TEl;
function Link(Href: JSValue; Cls: JSValue = undefined; Text: JSValue = undefined): TJSHTMLAnchorElement;
function Icon(const Name: string): TJSElement;
function IconButton(const Name, Title: string; Cls: JSValue = undefined): TEl;
function Avatar(Name, Url: JSValue; Cls: JSValue = undefined): TEl;
function Get(const Url: string): TJSPromise;
function Post(const Url: string; Data: JSValue): TJSPromise;
function Enc(Text: JSValue): string;
procedure Toast(Text: JSValue; Kind: JSValue = undefined);
procedure Failed(Err: JSValue);
function Route(const Path: string; Push: JSValue): TJSPromise;
function OpenPanel(const Title, Cls: string): TEl;
function Ago(Iso: JSValue): string;
function Clock(At: JSValue): string;
function DayLabel(Day: TJSDate): string;
function SizeText(N: JSValue): string;
procedure KeepPinned(Box: TJSElement);
function NearBottom(Box: JSValue = undefined): boolean;
function May(const Permission: string): boolean;
function MayHere(const Permission: string): boolean;
procedure Notify(Title, Text: JSValue);
procedure PopMenu(Anchor: TJSElement; Items: TJSArray);
function JoinForm(const Caption: string): TEl;
function ConfirmBox: TEl;
procedure LayerOpened;
procedure LayerClosed;

implementation

type
  TFn0 = reference to function: JSValue;
  TFn1 = reference to function(A: JSValue): JSValue;
  TFn2 = reference to function(A, B: JSValue): JSValue;
  TFn3 = reference to function(A, B, C: JSValue): JSValue;
  TStr1 = reference to function(A: JSValue): string;
  TBool1 = reference to function(A: JSValue): boolean;

var
  FindFn, PostFn, ToastFn, RouteFn, OpenPanelFn, NotifyFn, PopMenuFn: TFn2;
  ElFn, LinkFn, IconButtonFn, AvatarFn: TFn3;
  IconFn, GetFn, FailFn, KeepPinnedFn, JoinFormFn: TFn1;
  EncFn, AgoFn, ClockFn, DayLabelFn, SizeTextFn: TStr1;
  NearBottomFn, MayFn, MayHereFn: TBool1;
  ConfirmBoxFn, LayerOpenedFn, LayerClosedFn: TFn0;

function Same(A, B: JSValue): boolean; assembler;
asm
  return A === B;
end;

function Toggle(Node: TJSElement; const Name: string; Force: boolean): boolean;
begin
  Result := TTokens(Node.classList).toggle(Name, Force);
end;

procedure Setup;
var
  Shell: TJSObject;
begin
  Shell := TJSObject(TJSObject(window)['Chat']);
  C := TChatShell(Shell);
  FindFn := TFn2(Shell['$']);
  Body := TJSHTMLElement(Shell['body']);
  Stream := TEl(Shell['stream']);
  Panel := TEl(Shell['panel']);
  Site := Shell['Site'];
  Me := TChatMe(Shell['me']);
  S := TChatState(Shell['state']);
  Extras := TChatExtras(Shell['extras']);
  ElFn := TFn3(Shell['el']);
  LinkFn := TFn3(Shell['link']);
  IconFn := TFn1(Shell['icon']);
  IconButtonFn := TFn3(Shell['iconButton']);
  GetFn := TFn1(Shell['get']);
  PostFn := TFn2(Shell['post']);
  EncFn := TStr1(Shell['enc']);
  ToastFn := TFn2(Shell['toast']);
  FailFn := TFn1(Shell['failed']);
  FailedFn := Shell['failed'];
  RouteFn := TFn2(Shell['route']);
  OpenPanelFn := TFn2(Shell['openPanel']);
  AgoFn := TStr1(Shell['ago']);
  ClockFn := TStr1(Shell['clock']);
  DayLabelFn := TStr1(Shell['dayLabel']);
  AvatarFn := TFn3(Shell['avatar']);
  SizeTextFn := TStr1(Shell['sizeText']);
  KeepPinnedFn := TFn1(Shell['keepPinned']);
  NearBottomFn := TBool1(Shell['nearBottom']);
  MayFn := TBool1(Shell['may']);
  MayHereFn := TBool1(Shell['mayHere']);
  NotifyFn := TFn2(Shell['notify']);
  PopMenuFn := TFn2(Shell['popMenu']);
  JoinFormFn := TFn1(Shell['joinForm']);
  LayerOpenedFn := TFn0(Shell['layerOpened']);
  LayerClosedFn := TFn0(Shell['layerClosed']);
  ToggleMenu := TJSRawEventHandler(Shell['toggleMenu']);
  ConfirmBoxFn := TFn0(Shell['confirmBox']);
  Notices := TNotices(new(['unseen', 0, 'items', TJSArray.new]));
  Menu := nil;
  Live := TLive(new(['ws', nil, 'id', '', 'wait', 1000, 'failures', 0]));
  RoomsWanted := False;
  FromRing := False;
end;

function Find(const Selector: string; Root: JSValue): TEl;
begin
  Result := TEl(FindFn(Selector, Root));
end;

function El(const Tag: string; Cls: JSValue; Text: JSValue): TEl;
begin
  Result := TEl(ElFn(Tag, Cls, Text));
end;

function Link(Href: JSValue; Cls: JSValue; Text: JSValue): TJSHTMLAnchorElement;
begin
  Result := TJSHTMLAnchorElement(LinkFn(Href, Cls, Text));
end;

function Icon(const Name: string): TJSElement;
begin
  Result := TJSElement(IconFn(Name));
end;

function IconButton(const Name, Title: string; Cls: JSValue): TEl;
begin
  Result := TEl(IconButtonFn(Name, Title, Cls));
end;

function Avatar(Name, Url: JSValue; Cls: JSValue): TEl;
begin
  Result := TEl(AvatarFn(Name, Url, Cls));
end;

function Get(const Url: string): TJSPromise;
begin
  Result := TJSPromise(GetFn(Url));
end;

function Post(const Url: string; Data: JSValue): TJSPromise;
begin
  Result := TJSPromise(PostFn(Url, Data));
end;

function Enc(Text: JSValue): string;
begin
  Result := EncFn(Text);
end;

procedure Toast(Text: JSValue; Kind: JSValue);
begin
  ToastFn(Text, Kind);
end;

procedure Failed(Err: JSValue);
begin
  FailFn(Err);
end;

function Route(const Path: string; Push: JSValue): TJSPromise;
begin
  Result := TJSPromise(RouteFn(Path, Push));
end;

function OpenPanel(const Title, Cls: string): TEl;
begin
  Result := TEl(OpenPanelFn(Title, Cls));
end;

function Ago(Iso: JSValue): string;
begin
  Result := AgoFn(Iso);
end;

function Clock(At: JSValue): string;
begin
  Result := ClockFn(At);
end;

function DayLabel(Day: TJSDate): string;
begin
  Result := DayLabelFn(Day);
end;

function SizeText(N: JSValue): string;
begin
  Result := SizeTextFn(N);
end;

procedure KeepPinned(Box: TJSElement);
begin
  KeepPinnedFn(Box);
end;

function NearBottom(Box: JSValue): boolean;
begin
  Result := NearBottomFn(Box);
end;

function May(const Permission: string): boolean;
begin
  Result := MayFn(Permission);
end;

function MayHere(const Permission: string): boolean;
begin
  Result := MayHereFn(Permission);
end;

procedure Notify(Title, Text: JSValue);
begin
  NotifyFn(Title, Text);
end;

procedure PopMenu(Anchor: TJSElement; Items: TJSArray);
begin
  PopMenuFn(Anchor, Items);
end;

function JoinForm(const Caption: string): TEl;
begin
  Result := TEl(JoinFormFn(Caption));
end;

function ConfirmBox: TEl;
begin
  Result := TEl(ConfirmBoxFn());
end;

procedure LayerOpened;
begin
  LayerOpenedFn();
end;

procedure LayerClosed;
begin
  LayerClosedFn();
end;

end.
