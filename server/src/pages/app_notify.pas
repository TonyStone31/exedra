unit app_notify;

{ The site's page: the app it can be installed as, and its notifications. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, app_helpers;

var
  // The browser says it can install the site as an app: kept to offer it.
  InstallOffer: JSValue = nil;

function Notify(Title, Words: JSValue): JSValue; async;
function SubscribePush: boolean; async;
function NotifyState: string;
function BellButton: TEl;
procedure OfferNotifications;
procedure StartNotify;

implementation

uses app_account;

type
  TPushManager = class external name 'Object'(TJSObject)
    function getSubscription: JSValue;
    function subscribe(Options: TJSObject): JSValue;
  end;
  TRegistration = class external name 'Object'(TJSObject)
    pushManager: TPushManager;
    function showNotification(Title: JSValue; Options: TJSObject): JSValue;
  end;
  TWorkers = class external name 'Object'(TJSObject)
    ready: JSValue;
    function register(const Url: string): TJSPromise;
  end;
  // WebOrWorker's Notification wants a text for a title; the title goes as it was given.
  TNote = class external name 'Notification'(TJSObject)
    constructor new(Title: JSValue; Options: TJSObject);
    class function requestPermission: JSValue;
  end;
  TCodeOf = reference to function(C: string): NativeInt;

var
  Workers: TWorkers; external name 'navigator.serviceWorker';
  Permission: JSValue; external name 'Notification.permission';
  BlockedHelp: string;

function Atob(Value: JSValue): string; external name 'atob';
function BytesFrom(Value: JSValue; Map: TCodeOf): JSValue; external name 'Uint8Array.from';

// ------------------------------------------------- app and notifications

// Phones only show notifications through the service worker.
function Notify(Title, Words: JSValue): JSValue; async;
var
  Reg: TRegistration;
begin
  try
    Reg := await(TRegistration, TJSPromise(Workers.ready));
    await(JSValue, Reg.showNotification(Title, new(['body', Words, 'tag', 'page', 'icon', SiteBase.url('/icon-192.png')])));
  except
    TNote.new(Title, new(['body', Words]));
  end;
end;

// Web Push: the browser's push address goes to the site, which uses it
// when a mention or a private message comes and no page is open.
function SubscribePush: boolean; async;
var
  Reg: TRegistration;
  Key, Bytes, Words: JSValue;
  Raw: string;
  Sub: TJSObject;
begin
  try
    Reg := await(TRegistration, TJSPromise(Workers.ready));
    Key := TJSObject(await(Get('/api/push/key')))['key'];
    Raw := Atob(TJSString(TJSString(Key).replace(TJSRegexp.new('-', 'g'), '+')).replace(TJSRegexp.new('_', 'g'), '/'));
    Bytes := BytesFrom(Raw, function(C: string): NativeInt begin Result := TJSString(C).charCodeAt(0); end);
    Sub := await(TJSObject, Reg.pushManager.getSubscription);
    if not Truthy(Sub) then Sub := await(TJSObject, Reg.pushManager.subscribe(new(['userVisibleOnly', True, 'applicationServerKey', Bytes])));
    await(JSValue, Post('/api/push', new(['endpoint', Sub['endpoint']])));
    Result := True;
  except
    Words := TJSObject(JSExceptValue)['message'];
    if not Truthy(Words) then Words := JSExceptValue;
    Remember('push: ' + String(Words));
    Result := False;
  end;
end;

// What this browser can do about notifications: on, off (not asked yet),
// blocked, or none (no push in this browser).
function NotifyState: string;
var
  State: JSValue;
begin
  if not Has(window, 'Notification') or not Has(window.navigator, 'serviceWorker') or not Has(window, 'PushManager') then
  begin
    Result := 'none';
    Exit;
  end;
  State := new(['granted', 'on', 'denied', 'blocked'])[String(Permission)];
  if Truthy(State) then Result := String(State) else Result := 'off';
end;

procedure TurnOnNotifications; async;
var
  State: string;
  Bar: TEl;
begin
  State := NotifyState;
  if State = 'none' then
  begin
    Toast(T('This browser cannot show notifications from sites.'), 'bad');
    Exit;
  end;
  if State = 'blocked' then
  begin
    Toast(BlockedHelp, 'bad');
    Exit;
  end;
  if not Same(await(JSValue, TNote.requestPermission), 'granted') then Toast(BlockedHelp, 'bad')
  else if await(SubscribePush) then
    Toast(T('Notifications are on: mentions and private messages, when the chat is not in front of you.'))
  else Toast(T('Notifications are allowed, but the browser would not sign up for push messages. In Brave, turn on "Use Google services for push messaging" under Settings, Privacy and security, then tap the bell again.'), 'bad');
  RenderAccount;
  Bar := Find('#notifybar');
  if Truthy(Bar) then Bar.remove;
end;

// The bell beside Sign out: always there, saying how things stand.
function BellButton: TEl;
var
  State: string;
begin
  State := NotifyState;
  Result := IconButton('bell', new(['on', T('Notifications are on'), 'off', T('Turn on notifications for mentions and private messages'),
    'blocked', T('Notifications are blocked: click to see how to allow them'), 'none', T('This browser cannot show notifications')])[State],
    'bell-' + State);
  Result.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      TurnOnNotifications;   // when on, this checks the push sign-up again and says how it went
    end));
end;

// Once, after signing in: ask in plain sight rather than behind a menu,
// or say plainly why notifications cannot be had here.
procedure OfferNotifications;
var
  Asked: JSValue;
  State: string;
  Bar, No, Yes: TEl;
begin
  Asked := '';
  try
    Asked := LocalStore.getItem('notify-asked-2');
    if not Truthy(Asked) then Asked := '';
  except
  end;
  State := NotifyState;
  if not Truthy(Me.name) or Truthy(Asked) or (State = 'on') or Truthy(Find('#notifybar')) then Exit;
  Bar := El('div', 'notifybar');
  Bar.id := 'notifybar';
  if State = 'off' then No := El('button', 'small-link', T('Not now')) else No := El('button', 'small-link', T('OK'));
  No.kind := 'button';
  No.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      try
        LocalStore.setItem('notify-asked-2', '1');
      except
      end;
      Bar.remove;
    end));
  Bar.appendChild(Icon('bell'));
  if State = 'off' then
  begin
    Yes := El('button', 'primary', T('Turn on'));
    Yes.kind := 'button';
    Yes.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin TurnOnNotifications; end));
    Bar.add(El('span', '', T('Get a notification when someone mentions you or sends you a private message?')), Yes);
  end
  else if State = 'blocked' then Bar.appendChild(El('span', '', BlockedHelp))
  else Bar.appendChild(El('span', '', T('This browser cannot show notifications from sites, so mentions and private messages only show here.')));
  Bar.appendChild(No);
  Find('#main').addFirst(Bar);
end;

procedure StartNotify;
begin
  if Has(window.navigator, 'serviceWorker') then
    Workers.register(SiteBase.url('/sw.js')).catch(function(Err: JSValue): JSValue
      begin
        Remember('service worker: ' + String(TJSObject(Err)['message']));
      end);

  window.addEventListener('beforeinstallprompt', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      E.preventDefault;
      InstallOffer := E;
      RenderAccount;
    end));

  // A blocked site cannot ask again; only the browser's settings undo it.
  // The installed app has no address bar, but it shares the browser's.
  if window.matchMedia('(display-mode: standalone)').matches then
    BlockedHelp := T('Notifications are blocked for this site, and the app cannot ask again. Open %s in the browser itself, tap the icon left of the address, Permissions, and allow Notifications (or reset them); the app uses the same setting. In Brave, also turn on "Use Google services for push messaging" under Settings, Privacy and security.', window.location.host)
  else
    BlockedHelp := T('Notifications are blocked for this site. Allow them in the browser''s site settings (the icon left of the address, or Settings, Site settings, Notifications). In Brave, also turn on "Use Google services for push messaging" under Settings, Privacy and security.');
end;

end.
