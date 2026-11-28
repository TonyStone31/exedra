unit SidePage;

{ The left column every module shares: the small helpers that draw it, the
  theme button at its top, and at its foot the row that says who is signed
  in, with a menu for the rest (profile, admin, language, signing out).
  The chat's page fills the row itself through Side.account; a page the
  server drew (wiki, forum) has plain links there, which become the row. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web;

type
  TStays = reference to function(A: TJSHTMLAnchorElement): JSValue;

function El(const Tag: string; Cls: JSValue = undefined; Text: JSValue = undefined): TJSHTMLElement;
function Link(Href: JSValue; Cls: JSValue = undefined; Text: JSValue = undefined): TJSHTMLElement;
function Hue(Name: JSValue): NativeInt;
function Avatar(Name: JSValue; Url: JSValue = undefined; Cls: JSValue = undefined): TJSHTMLElement;
function Icon(const Name: string): TJSElement;
function IconButton(const Name, Title: string; Cls: JSValue = undefined): TJSHTMLElement;
procedure Account(Who: TJSObject);
procedure SignOut; async;
procedure NewTabLinks(const Boxes: string; Own: JSValue; Stays: TStays);

implementation

uses PageKit;

type
  // A path read as it is: an unknown name gives undefined, not the word.
  TIcons = class external name 'Object'(TJSObject)
  private
    function GetPath(const Name: string): string; external name '[]';
  public
    property Paths[const Name: string]: string read GetPath; default;
  end;
  TThemeApi = class external name 'Object'(TJSObject)
    function get: string;
    procedure set_(Value: JSValue); external name 'set';
  end;
  TKeysApi = class external name 'Object'(TJSObject)
    function signOut: TJSPromise;
  end;
  TMenu = class external name 'HTMLElement'(TJSHTMLElement)
    procedure close;
  end;
  // What t gives, as it gives it.
  TWords = class external name 'Function'(TJSObject)
    function call(This: JSValue; const Text: string): string; varargs;
  end;

var
  Icons: TIcons;
  Theme: TThemeApi; external name 'window.Theme';
  Keys: TKeysApi; external name 'window.Keys';

function Imul(A, B: NativeInt): NativeInt; external name 'Math.imul';
function Enc(Value: JSValue): string; external name 'encodeURIComponent';
procedure Alert(Text: JSValue); external name 'alert';
// pas2js Web requires a reload argument; the browser permits none.
procedure Reload; external name 'location.reload';

function Find(const S: string; Root: TJSElement = nil): TJSElement;
begin
  if Truthy(Root) then Result := Root.querySelector(S) else Result := document.querySelector(S);
end;

// words.js gives t(); a page without it still gets its words in English
function Say(const Text: string): string;
begin
  if jsTypeOf(TJSObject(window)['t']) = 'function' then
    Result := TWords(TJSObject(window)['t']).call(nil, Text)
  else Result := Text;
end;

function SayWith(const Text: string; Value: JSValue): string;
begin
  if jsTypeOf(TJSObject(window)['t']) = 'function' then
    Result := TWords(TJSObject(window)['t']).call(nil, Text, Value)
  else Result := Text;
end;

function El(const Tag: string; Cls: JSValue; Text: JSValue): TJSHTMLElement;
begin
  Result := TJSHTMLElement(document.createElement(Tag));
  if Truthy(Cls) then TJSObject(Result)['className'] := Cls;
  // isUndefined is also true for null, which is a text here.
  if jsTypeOf(Text) <> 'undefined' then TJSObject(Result)['textContent'] := Text;
end;

function Link(Href: JSValue; Cls: JSValue; Text: JSValue): TJSHTMLElement;
begin
  Result := El('a', Cls, Text);
  TJSObject(Result)['href'] := Href;
end;

function Hue(Name: JSValue): NativeInt;
var
  H, Code: Integer;
  All: TJSArray;
  I: NativeInt;
begin
  // 2166136261 as the 32 bits the arithmetic below keeps
  H := -2128831035;
  // letter by letter, a pair of halves as one
  All := TJSArray.from(Name);
  for I := 0 to All.length - 1 do
  begin
    // Both sides 32-bit, so this is the browser's own ^: rtl.xor drops the sign.
    Code := TJSString(All[I]).charCodeAt(0);
    H := Imul(H xor Code, 16777619);
  end;
  Result := LongWord(H) mod 360;
end;

function Avatar(Name: JSValue; Url: JSValue; Cls: JSValue): TJSHTMLElement;
var
  Img: TJSHTMLElement;
begin
  if not Truthy(Cls) then Cls := '';
  Result := El('span', 'avatar ' + String(Cls));
  if Truthy(Url) then
  begin
    Img := El('img');
    TJSObject(Img)['src'] := Url;
    TJSObject(Img)['alt'] := '';
    TJSObject(Img)['loading'] := 'lazy';
    Result.appendChild(Img);
  end
  else
  begin
    if not Truthy(Name) then Name := '?';
    Result.textContent := TJSString(TJSString(Name).charAt(0)).toUpperCase;
    Result.style.setProperty('--h', String(JSValue(Hue(Name))));
  end;
end;

function Icon(const Name: string): TJSElement;
const
  NS = 'http://www.w3.org/2000/svg';
var
  Path: TJSElement;
begin
  Result := document.createElementNS(NS, 'svg');
  Result.setAttribute('viewBox', '0 0 24 24');
  Result.setAttribute('class', 'icon');
  Path := document.createElementNS(NS, 'path');
  Path.setAttribute('d', Icons[Name]);
  Result.appendChild(Path);
end;

function IconButton(const Name, Title: string; Cls: JSValue): TJSHTMLElement;
begin
  if not Truthy(Cls) then Cls := '';
  Result := El('button', 'iconbtn ' + String(Cls));
  TJSObject(Result)['type'] := 'button';
  Result.title := Title;
  Result.setAttribute('aria-label', Title);
  Result.appendChild(Icon(Name));
end;

// ------------------------------------------------------------------ theme

// The button at the top of the column: auto, light, dark, in turn.
procedure ThemeButton(Button: TJSHTMLElement);

  function Names: TJSObject;
  begin
    Result := new(['auto', Say('auto'), 'light', Say('light'), 'dark', Say('dark')]);
  end;

  procedure Show(E: TJSEvent);
  var
    Now, Name: string;
  begin
    Now := Theme.get;
    if Now = 'light' then Name := 'sun' else if Now = 'dark' then Name := 'moon' else Name := 'auto';
    Button.replaceChildren(Icon(Name));
    Button.title := SayWith('Theme: %s', Names[Now]);
    Button.setAttribute('aria-label', SayWith('Theme: %s. Change theme', Names[Now]));
  end;

begin
  if not Truthy(Button) or not Truthy(Theme) then Exit;
  Button.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      Theme.set_(new(['auto', 'light', 'light', 'dark', 'dark', 'auto'])[Theme.get]);
    end));
  window.addEventListener('themechange', TJSRawEventHandler(@Show));
  Show(nil);
end;

// ---------------------------------------------------------------- account

procedure SignOut; async;
begin
  try
    if Truthy(Keys) then await(Keys.signOut);
    Reload;
  except
    Alert(TJSObject(JSExceptValue)['message']);
  end;
end;

// The menu over the row.  The language choice is the form the server
// drew, kept out of sight in #side-language until the menu shows it.
procedure AccountMenu(Box: TJSHTMLElement; Who: TJSObject);
var
  Open, Holder, Form: TJSElement;
  Menu, Row, Out: TJSHTMLElement;
  Links: TJSArray;
  I: NativeInt;

  procedure Away(E: TJSEvent);
  begin
    // a click on the language choice is not a choice yet
    if Menu.contains(TJSNode(E.target)) and not Truthy(TJSElement(E.target).closest('a')) then Exit;
    TMenu(Menu).close;
  end;

begin
  Open := Find('.accountmenu', Box);
  if Truthy(Open) then begin TMenu(Open).close; Exit; end;
  Menu := El('nav', 'accountmenu');
  if Truthy(Who['name']) then Menu.appendChild(Link('/u/' + Enc(Who['name']), '', Say('Your profile and settings')));
  Links := TJSArray(Who['links']);
  if not Truthy(Links) then Links := TJSArray.new;
  for I := 0 to Links.length - 1 do
    Menu.appendChild(Link(TJSObject(Links[I])['href'], '', TJSObject(Links[I])['title']));
  if Truthy(Who['admin']) then Menu.appendChild(Link('/admin', '', Say('Admin')));
  Holder := Find('#side-language');
  if Truthy(Holder) then Form := Holder.firstElementChild else Form := Holder;
  if Truthy(Form) then
  begin
    Row := El('div', 'accountmenu-language');
    Row.appendChild(Form);
    Menu.appendChild(Row);
  end;
  if Truthy(Who['name']) then
  begin
    Out := Link('#', '', Say('Sign out'));
    Out.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        E.preventDefault;
        if Truthy(Who['signOut']) then TJSFunction(Who['signOut']).call(TJSObject(undefined)) else SignOut;
      end));
    Menu.appendChild(Out);
  end;
  TJSObject(Menu)['close'] := procedure
    begin
      if Truthy(Form) then Holder.appendChild(Form);
      Menu.remove;
      document.removeEventListener('click', TJSRawEventHandler(@Away));
    end;
  Box.appendChild(Menu);
  // With the cast the procedure itself is the listener; without it each @Away is a new wrapper.
  window.setTimeout(procedure begin document.addEventListener('click', TJSRawEventHandler(@Away)); end, 0);
end;

// Draws the row: who.name ('' for a visitor), who.avatar, who.admin,
// who.tools (buttons between the name and the menu's button), who.links
// (more menu entries), who.signOut (in place of the usual one),
// who.unconfirmed (the address still waits for its link to be opened).
procedure Account(Who: TJSObject);
var
  Box, Me, Tools, More: TJSHTMLElement;
  Given: TJSArray;
  I: NativeInt;
begin
  Box := TJSHTMLElement(Find('#account'));
  if not Truthy(Box) then Exit;
  Box.replaceChildren;
  // the way to another link, or to a corrected address, is on the profile
  if Truthy(Who['unconfirmed']) then
    Box.appendChild(Link('/u/' + Enc(Who['name']), 'unconfirmed', Say('Confirm your email')));
  if Truthy(Who['name']) then
  begin
    Me := Link('/u/' + Enc(Who['name']), 'me');
    Me.title := Say('Your profile and settings');
    Me.append(Avatar(Who['name'], Who['avatar'], 'small'), El('span', '', Who['name']));
    Box.appendChild(Me);
  end
  else
    Box.appendChild(Link('/signin', 'button signinbtn', Say('Sign in or join')));
  Tools := El('div', 'tools');
  Given := TJSArray(Who['tools']);
  if not Truthy(Given) then Given := TJSArray.new;
  for I := 0 to Given.length - 1 do Tools.appendChild(TJSNode(Given[I]));
  More := IconButton('up', Say('More'));
  More.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin AccountMenu(Box, Who); end));
  Tools.appendChild(More);
  Box.appendChild(Tools);
end;

// A page the server drew: its plain account links say who this is.
procedure FromLinks;
var
  Box, Me: TJSElement;
  Name: string;
begin
  Box := Find('#account');
  if not Truthy(Box) or not Truthy(Box.children.length) then Exit;
  Me := Find('a.me', Box);
  if Truthy(Me) then Name := TJSString(Me.textContent).trim else Name := '';
  Account(new(['name', Name, 'admin', Truthy(Find('a[href$="/admin"]', Box)), 'unconfirmed', Truthy(Find('a.unconfirmed', Box))]));
end;

procedure Start(E: TJSEvent);
begin
  ThemeButton(TJSHTMLElement(Find('#theme')));
  FromLinks;
end;

// Links in what members wrote (inside boxes, a selector) open a new tab,
// old messages and new alike: those to another site, and with own those
// to this site too, but for the ones stays(a) says the page shows in
// place.  Set as the click arrives, so nothing drawn later is missed.
procedure NewTabLinks(const Boxes: string; Own: JSValue; Stays: TStays);
begin
  document.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      A: TJSHTMLAnchorElement;
    begin
      A := TJSHTMLAnchorElement(TJSElement(E.target).closest('a[href]'));
      // Web names the anchor's protocol with a capital, which the browser does not have.
      if not Truthy(A) or not Truthy(A.closest(Boxes)) or not TJSRegexp.new('^https?:$').test(String(TJSObject(A)['protocol'])) then Exit;
      if (A.origin = window.location.origin) and (not Truthy(Own) or Truthy(Stays(A))) then Exit;
      A.target := '_blank';
      A.relList.add('noopener');
    end), True);
end;

procedure Load;
begin
  Icons := TIcons(new([
    'react', 'M12 22a10 10 0 1 1 0-20 10 10 0 0 1 0 20zm-4-8a4.5 4.5 0 0 0 8 0M9 9.5h.01M15 9.5h.01',
    'reply', 'M21 12a8 8 0 0 1-11.6 7.1L4 21l1.9-5.4A8 8 0 1 1 21 12z',
    'link', 'M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1',
    'edit', 'M4 20h4L19 9l-4-4L4 16v4zM14 6l4 4',
    'trash', 'M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3',
    'pin', 'M9 4h6l-1 6 4 4H6l4-4-1-6zM12 14v7',
    'attach', 'M21 11l-8.5 8.5a5 5 0 0 1-7-7L14 4a3.5 3.5 0 0 1 5 5l-8.5 8.5a2 2 0 0 1-3-3L15 7',
    'code', 'M8 7l-5 5 5 5M16 7l5 5-5 5M14 4l-4 16',
    'beam', 'M4 12h11M11 6l6 6-6 6M20 4v16',
    'close', 'M6 6l12 12M18 6L6 18',
    'menu', 'M4 6h16M4 12h16M4 18h16',
    'search', 'M11 18a7 7 0 1 1 0-14 7 7 0 0 1 0 14zM20 20l-4-4',
    'lock', 'M6 11h12v9H6zM8 11V8a4 4 0 0 1 8 0v3',
    'shelf', 'M4 6h16M4 12h16M4 18h16M6 6v12M18 6v12',
    'bell', 'M6 16V11a6 6 0 0 1 12 0v5l2 2H4l2-2zM10 20a2 2 0 0 0 4 0',
    'sun', 'M12 17a5 5 0 1 0 0-10 5 5 0 0 0 0 10zM12 1v2M12 21v2M4.2 4.2l1.4 1.4M18.4 18.4l1.4 1.4M1 12h2M21 12h2M4.2 19.8l1.4-1.4M18.4 5.6l1.4-1.4',
    'moon', 'M21 13A9 9 0 1 1 11 3a7 7 0 0 0 10 10z',
    'auto', 'M12 21a9 9 0 1 1 0-18 9 9 0 0 1 0 18zM12 3v18',
    'people', 'M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM2 21v-1a6 6 0 0 1 12 0v1M17 11a3 3 0 1 0 0-6M22 21v-1a5 5 0 0 0-4-4.9',
    'plus', 'M12 5v14M5 12h14',
    'copy', 'M8 8h12v12H8zM4 16V4h12',
    'bug', 'M9 7a3 3 0 0 1 6 0M7 10h10v5a5 5 0 0 1-10 0zM12 10v10M4 13h3M17 13h3M5 8l2 2M19 8l-2 2M5 19l2-2M19 19l-2-2',
    'install', 'M12 4v11M7 10l5 5 5-5M5 20h14',
    'up', 'M6 15l6-6 6 6',
    'down', 'M6 9l6 6 6-6',
    // two eyes, looking back at the message they have read
    'seen', 'M3 12a4 5 0 1 0 8 0a4 5 0 1 0-8 0M13 12a4 5 0 1 0 8 0a4 5 0 1 0-8 0M4.6 12.6a1 1 0 1 0 2 0a1 1 0 1 0-2 0M14.6 12.6a1 1 0 1 0 2 0a1 1 0 1 0-2 0']));
  if document.readyState = 'loading' then document.addEventListener('DOMContentLoaded', TJSRawEventHandler(@Start))
  else Start(nil);
  // A forum post, wherever one is shown: its links to this site stay in the
  // tab, as the reader moves through the forum.
  NewTabLinks('.forum-body, .forum-signature', False, nil);
  TJSObject(window)['Side'] := new(['el', @El, 'link', @Link, 'hue', @Hue, 'avatar', @Avatar, 'icons', Icons, 'icon', @Icon,
    'iconButton', @IconButton, 'account', @Account, 'signOut', @SignOut, 'newTabLinks', @NewTabLinks]);
end;

initialization
  Load;
end.
