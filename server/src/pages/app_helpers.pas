unit app_helpers;

{ The site's page (app.pas): what the page knows of the member and of the
  place shown, and the helpers every part of it draws and asks with. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web;

type
  // An element, with the properties the page sets under the browser's own names.
  TEl = class external name 'HTMLElement'(TJSHTMLElement)
    placeholder, autocomplete, value, href, rel, target, accept, src: JSValue;
    fieldName: JSValue; external name 'name';
    kind: JSValue; external name 'type';
    whenLoaded: JSValue; external name 'onload';
    whenFailed: JSValue; external name 'onerror';
    maxLength, rows, required, disabled, checked, open, files: JSValue;
    // a list held at its bottom (KeepPinned)
    pinned, noPin: JSValue;
    pinTop: double;
    isConnected: boolean;
    // Web's append takes one node and Web has no prepend; the browser takes nodes and texts.
    procedure add(Node: JSValue); varargs; external name 'append';
    procedure addFirst(Node: JSValue); varargs; external name 'prepend';
    procedure after(Node: TJSNode);
    function pick(Selector: JSValue): TEl; external name 'querySelector';
  end;

  // The member signed in, as /api/me says and the parts read.
  TMe = class external name 'Object'(TJSObject)
    name: string;
    can: TJSArray;
    ignores, reactions, avatar, away, wrapped, verified, email, mailNotes, mailHours, readReceipts, prefs, password, closedNames: JSValue;
    autoAway: double;
  end;

  // The place shown. The parts keep their own things in it too.
  TState = class external name 'Object'(TJSObject)
    view, room, info, thread, dm, typers, title: JSValue;
    messages, threadMessages: TJSMap;
    generation: NativeInt;
    rooms: TJSArray;
    dmTimer: NativeInt;
  end;

  // What another script, loaded after this one, can add.
  TExtras = class external name 'Object'(TJSObject)
    adminTabs, adminScripts, accountLinks: TJSArray;
  end;

  TStays = reference to function(A: TJSElement): boolean;
  TSide = class external name 'Object'(TJSObject)
    procedure account(Who: TJSObject);
    procedure newTabLinks(const Boxes: string; Own: boolean; Stays: TStays);
  end;
  TKeys = class external name 'Object'(TJSObject)
    function joinFrom(Form: TJSNode; Failed: JSValue): JSValue;
    function setupKeys(Name, Password: JSValue): JSValue;
    function signOut: JSValue;
    function changePassword(Name, Current, Password, Wrapped: JSValue): JSValue;
    function passwordProof(Name, Password: JSValue): JSValue;
  end;
  TBase = class external name 'Object'(TJSObject)
    function url(Address: JSValue): string;
    function path: string;
    function strip(Address: JSValue): string;
  end;

  // TJSDate has no constructor for any value, and its texts take no locale.
  TAnyDate = class external name 'Date'(TJSObject)
    constructor new; overload;
    constructor new(Value: JSValue); overload;
    class function now: double;
    function toISOString: string;
    function toDateString: string;
    function getFullYear: NativeInt;
    function toLocaleTimeString(Locale: JSValue; Options: TJSObject): string;
    function toLocaleDateString(Locale: JSValue; Options: TJSObject): string;
  end;

  TWatchCallback = reference to procedure(Entries: TJSArray);
  TResizeWatch = class external name 'ResizeObserver'(TJSObject)
    constructor new(Callback: TWatchCallback);
    procedure observe(Target: TJSNode);
    procedure unobserve(Target: TJSNode);
  end;

  // The part of the page in sight, where the browser says so.
  TViewport = class external name 'VisualViewport'(TJSEventTarget)
    scale, height, offsetTop: double;
  end;

  // Storage as the browser has it: any value as a key, null for nothing kept.
  TStore = class external name 'Storage'(TJSObject)
    function getItem(Key: JSValue): JSValue;
    procedure setItem(Key, Value: JSValue);
  end;

var
  Side: TSide; external name 'window.Side';
  Keys: TKeys; external name 'window.Keys';
  SiteBase: TBase; external name 'window.SiteBase';
  LocalStore: TStore; external name 'localStorage';
  ShownPart: TViewport; external name 'window.visualViewport';
  Infinity: double; external name 'Infinity';

  Body: TEl;
  Me: TMe;
  SiteName: JSValue;
  Stream, Panel: TEl;
  S: TState;
  Extras: TExtras;
  // drawn the same in every module: side.js. Kept as they were when this script was read.
  SideEl, SideLink, SideAvatar, SideIcon, SideIconButton: TJSFunction;
  Icons: JSValue;
  KeysPost: TJSFunction;
  // The last things that went wrong on this page, for a bug report.
  Trail: TJSArray;
  Locale: JSValue;
  PinWatch: TResizeWatch;

function T(const English: string): string; varargs; external name 'window.t';
function TN(N: JSValue; const One, Many: string): string; varargs; external name 'window.tn';
function DateText(Value: JSValue): string; external name 'window.dateText';
// JavaScript's own truth of a value; a Pascal cast to boolean is something else.
function Truthy(Value: JSValue): boolean; external name 'Boolean';
// JavaScript's === but for NaN and the two zeros, where = on two values of any kind is ==.
function Same(A, B: JSValue): boolean; external name 'Object.is';
// JavaScript's "name in thing".
function Has(Thing: JSValue; const Name: string): boolean; external name 'Reflect.has';
// JavaScript's String(value) and Number(value); the Pascal casts are something else.
function Text(Value: JSValue): string; external name 'String';
function Number(Value: JSValue): double; external name 'Number';
function Max(A, B: double): double; external name 'Math.max';
function Min(A, B: double): double; external name 'Math.min';

function Find(Selector: JSValue; Root: JSValue = undefined): TEl;
function May(P: JSValue): boolean;
function MayHere(P: JSValue): boolean;
function El(Tag: JSValue; Cls: JSValue = undefined; Words: JSValue = undefined): TEl;
function Link(Href: JSValue; Cls: JSValue = undefined; Words: JSValue = undefined): TEl;
function Avatar(Name: JSValue; Url: JSValue = undefined; Cls: JSValue = undefined): TEl;
function Icon(Name: JSValue): TJSNode;
function IconButton(Name, Title: JSValue; Cls: JSValue = undefined): TEl;
function Get(const Url: string): JSValue; async;
function Post(Url, Fields: JSValue): JSValue;
procedure Toast(Words: JSValue; Kind: JSValue = undefined);
procedure Remember(const What: string);
procedure Failed(Err: JSValue);
function Clock(At: JSValue): JSValue;
function DayLabel(D: TAnyDate): string;
function Ago(Iso: JSValue): string;
function SizeText(N: double): string;
function NearBottom(Box: TEl = nil): boolean;
procedure KeepPinned(Box: TEl);
function Enc(Value: JSValue): string;
function LoadMe: JSValue; async;
procedure StartHelpers;

implementation

type
  TFinder = class external name 'Object'(TJSObject)
    function querySelector(Selector: JSValue): TEl;
  end;
  // A number cannot be cast to TJSNumber, and its toFixed answers no string.
  TNumber = class external name 'Number'(TJSObject)
    function toFixed(Digits: NativeInt): string;
  end;

function EncodeURIComponent(Value: JSValue): string; external name 'encodeURIComponent';
function GetCanonicalLocales(Tag: JSValue): TJSArray; external name 'Intl.getCanonicalLocales';
function NotANumber(Value: JSValue): boolean; external name 'isNaN';
function MathRound(X: double): double; external name 'Math.round';
function MathAbs(X: double): double; external name 'Math.abs';

function Find(Selector: JSValue; Root: JSValue): TEl;
begin
  if not Truthy(Root) then Root := document;
  Result := TFinder(Root).querySelector(Selector);
end;

// What the member may do anywhere, from /api/me.
function May(P: JSValue): boolean;
begin
  Result := Me.can.indexOf(P) >= 0;
end;

// What the member may do in the open room, from /api/room.
function MayHere(P: JSValue): boolean;
begin
  Result := Truthy(S.info) and Truthy(TJSObject(S.info)['can']) and Truthy(TJSObject(TJSObject(S.info)['can'])[String(P)]);
end;

// ---------------------------------------------------------------- helpers

function El(Tag: JSValue; Cls: JSValue; Words: JSValue): TEl;
begin
  Result := TEl(SideEl.call(TJSObject(undefined), Tag, Cls, Words));
end;

function Link(Href: JSValue; Cls: JSValue; Words: JSValue): TEl;
begin
  Result := TEl(SideLink.call(TJSObject(undefined), Href, Cls, Words));
end;

function Avatar(Name: JSValue; Url: JSValue; Cls: JSValue): TEl;
begin
  Result := TEl(SideAvatar.call(TJSObject(undefined), Name, Url, Cls));
end;

function Icon(Name: JSValue): TJSNode;
begin
  Result := TJSNode(SideIcon.call(TJSObject(undefined), Name));
end;

function IconButton(Name, Title: JSValue; Cls: JSValue): TEl;
begin
  Result := TEl(SideIconButton.call(TJSObject(undefined), Name, Title, Cls));
end;

function Get(const Url: string): JSValue; async;
var
  Answer: TJSResponse;
begin
  Answer := await(TJSResponse, window.fetch(Url));
  if not Answer.ok then raise TJSError.new(await(string, Answer.text()));
  Result := Answer.json();
end;

function Post(Url, Fields: JSValue): JSValue;
begin
  Result := KeysPost.call(TJSObject(undefined), Url, Fields);
end;

procedure Toast(Words: JSValue; Kind: JSValue);
var
  Note: TEl;
begin
  if Truthy(Kind) then Note := El('div', 'toast ' + String(Kind), Words) else Note := El('div', 'toast ', Words);
  Find('#toasts').appendChild(Note);
  window.setTimeout(procedure begin Note.classList.add('going'); end, 4500);
  window.setTimeout(procedure begin Note.remove; end, 5000);
end;

procedure Remember(const What: string);
begin
  Trail.push(TJSString(TAnyDate.new.toISOString).slice(11, 19) + ' ' + What);
  if Trail.length > 15 then Trail.shift;
end;

procedure Failed(Err: JSValue);
var
  Words: JSValue;
begin
  Words := TJSObject(Err)['message'];
  if not Truthy(Words) then Words := Text(Err);
  Remember('shown: ' + String(Words));
  Toast(Words, 'bad');
end;

function Clock(At: JSValue): JSValue;
var
  D: TAnyDate;
begin
  D := TAnyDate.new(At);
  if NotANumber(D) then Result := At
  else Result := D.toLocaleTimeString(Locale, new(['hour', '2-digit', 'minute', '2-digit']));
end;

function DayLabel(D: TAnyDate): string;
var
  Today, Yesterday: TAnyDate;
begin
  Today := TAnyDate.new;
  Yesterday := TAnyDate.new(TAnyDate.now - 86400000);
  if D.toDateString = Today.toDateString then Result := T('Today')
  else if D.toDateString = Yesterday.toDateString then Result := T('Yesterday')
  else if D.getFullYear <> Today.getFullYear then
    Result := D.toLocaleDateString(Locale, new(['weekday', 'long', 'month', 'long', 'day', 'numeric', 'year', 'numeric']))
  else Result := D.toLocaleDateString(Locale, new(['weekday', 'long', 'month', 'long', 'day', 'numeric']));
end;

function Ago(Iso: JSValue): string;
var
  Minutes: double;
begin
  Result := '';
  if not Truthy(Iso) then Exit;
  Minutes := MathRound((TAnyDate.now - Number(TAnyDate.new(Iso))) / 60000);
  if Minutes < 2 then Result := T('just now')
  else if Minutes < 60 then Result := TN(Minutes, '%d min ago', '%d min ago')
  else if Minutes < 48 * 60 then Result := TN(MathRound(Minutes / 60), '%d hours ago', '%d hours ago')
  else Result := TN(MathRound(Minutes / 1440), '%d days ago', '%d days ago');
end;

function SizeText(N: double): string;
begin
  if N < 1024 then Result := T('%d B', N)
  else if N < 1024 * 1024 then Result := T('%d KB', MathRound(N / 1024))
  else if N < 1024 * 1024 * 1024 then Result := T('%s MB', TNumber(JSValue(N / 1024 / 1024)).toFixed(1))
  else if N < 1024 * 1024 * 1024 * 1024 then Result := T('%s GB', TNumber(JSValue(N / 1024 / 1024 / 1024)).toFixed(1))
  else Result := T('%s TB', TNumber(JSValue(N / 1024 / 1024 / 1024 / 1024)).toFixed(2));
end;

function NearBottom(Box: TEl): boolean;
begin
  if not Truthy(Box) then Box := Stream;
  Result := Box.scrollHeight - Box.scrollTop - Box.clientHeight < 160;
end;

// A list read at its bottom stays there when it gets shorter (a phone's
// keyboard opening, the composer growing) or a message in it gets taller
// (a reaction, an edit, a picture arriving): neither sends a scroll
// event.  Watched are the list and each message drawn (chat.js).
procedure Watched(Entries: TJSArray);
var
  I: NativeInt;
  Target, Box: TEl;
begin
  for I := 0 to Entries.length - 1 do
  begin
    Target := TEl(TJSObject(Entries[I])['target']);
    if Has(Target, 'pinned') then Box := Target else Box := TEl(Target.parentNode);
    if not Target.isConnected then PinWatch.unobserve(Target)
    else if Truthy(Box.pinned) and not Truthy(Box.noPin) then
    begin
      Box.scrollTop := Box.scrollHeight;
      Box.pinTop := Box.scrollTop;
    end;
  end;
end;

procedure KeepPinned(Box: TEl);
begin
  Box.pinned := True;
  // The scroll event of the watch's own move comes a frame late: a list
  // still where the watch put it has not been left, however far its bottom now is.
  Box.addEventListener('scroll', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      Box.pinned := not Truthy(Box.noPin) and (NearBottom(Box) or (Box.scrollTop = Box.pinTop));
      Box.pinTop := -1;
    end));
  PinWatch.observe(Box);
end;

// A phone browser that ignores interactive-widget leaves the page its full
// height under the keyboard; the page then takes the height shown.  Not
// while zoomed in, where the shown part is smaller on purpose.
procedure FitShown(E: TJSEvent);
var
  View: TViewport;
  Root: TJSHTMLElement;
begin
  View := ShownPart;
  Root := TJSHTMLElement(document.documentElement);
  if (MathAbs(View.scale - 1) < 0.01) and (View.height < Root.clientHeight - 1) then
  begin
    Root.style.setProperty('--shown-height', String(JSValue(View.height)) + 'px');
    Root.style.setProperty('--shown-top', String(JSValue(View.offsetTop)) + 'px');
  end
  else
  begin
    Root.style.removeProperty('--shown-height');
    Root.style.removeProperty('--shown-top');
  end;
end;

function Enc(Value: JSValue): string;
begin
  Result := EncodeURIComponent(Value);
end;

// What the server knows of the member signed in.
function LoadMe: JSValue; async;
var
  Got: TJSObject;
begin
  Got := TJSObject(await(Get('/api/me')));
  Me.avatar := Got['avatar'];
  Me.can := TJSArray(Got['can']);
  Me.away := Got['away'];
  Me.ignores := Got['ignores'];
  Me.wrapped := Got['wrapped'];
  Me.verified := Got['verified'];
  Me.email := Got['email'];
  Me.mailNotes := Got['mail_notes'];
  TJSObject(Me)['autoAway'] := Got['auto_away'];
  Me.mailHours := Got['mail_hours'];
  Me.readReceipts := Got['read_receipts'];
  Me.prefs := Got['prefs'];
  Me.password := Got['password'];
  Me.closedNames := Got['closed_names'];
  if Truthy(Got['reactions']) then Me.reactions := Got['reactions'];
end;

procedure StartHelpers;
var
  Name, Lang: JSValue;
begin
  Body := TEl(document.body);
  Name := TJSObject(Body.dataset)['me'];
  if not Truthy(Name) then Name := '';
  Me := TMe(new(['name', Name, 'can', TJSArray.new, 'ignores', TJSArray.new, 'reactions', new(['shown', TJSArray.new, 'more', TJSArray.new])]));
  SiteName := TJSObject(Body.dataset)['site'];
  Stream := Find('#stream');
  Panel := Find('#panel');
  S := TState(new(['view', '', 'room', '', 'info', nil, 'messages', TJSMap.new, 'since', 0, 'lastRead', 0, 'divider', 0,
    'oldest', Infinity, 'older', True, 'thread', 0, 'threadMessages', TJSMap.new, 'generation', 0,
    'rooms', TJSArray.new, 'dms', TJSArray.new, 'commands', nil, 'typingSent', 0, 'tick', 0, 'alerts', TJSObject.new,
    'dm', '', 'dmLast', 0, 'dmFirst', 0, 'dmTimer', 0, 'beams', TJSObject.new, 'typers', TJSObject.new, 'here', TJSArray.new]));

  SideEl := TJSFunction(TJSObject(Side)['el']);
  SideLink := TJSFunction(TJSObject(Side)['link']);
  SideAvatar := TJSFunction(TJSObject(Side)['avatar']);
  Icons := TJSObject(Side)['icons'];
  SideIcon := TJSFunction(TJSObject(Side)['icon']);
  SideIconButton := TJSFunction(TJSObject(Side)['iconButton']);
  KeysPost := TJSFunction(TJSObject(Keys)['post']);

  Trail := TJSArray.new;
  window.addEventListener('error', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      Remember('error: ' + String(TJSObject(E)['message']) + ' (' + String(TJSObject(E)['filename']) + ':' + String(TJSObject(E)['lineno']) + ')');
    end));
  window.addEventListener('unhandledrejection', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Reason: JSValue;
    begin
      Reason := TJSObject(E)['reason'];
      if Truthy(Reason) and Truthy(TJSObject(Reason)['message']) then Reason := TJSObject(Reason)['message'];
      Remember('promise: ' + String(Reason));
    end));

  try
    Lang := TJSObject(document.documentElement)['lang'];
    if not Truthy(Lang) then Lang := '';
    Locale := GetCanonicalLocales(Lang)[0];
  except
  end;

  PinWatch := TResizeWatch.new(@Watched);
  KeepPinned(Stream);

  if Truthy(ShownPart) then
  begin
    ShownPart.addEventListener('resize', TJSRawEventHandler(@FitShown));
    ShownPart.addEventListener('scroll', TJSRawEventHandler(@FitShown));
    FitShown(nil);
  end;
end;

end.
