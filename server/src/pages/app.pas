unit AppPage;

{ The site's page: account, profiles, the side panel and the admin page,
  moving between them without reloading.  Everything it shows comes from
  the JSON API.  The parts of the suite that live on this page add
  themselves to Chat.parts (chat.js: rooms, threads, private conversations)
  and answer for their own addresses, the side list and the live updates.
  Its sections are units of their own: app_helpers, app_notify,
  app_account, app_router, app_panel, app_profile, app_admin. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, WebOrWorker, app_helpers, app_notify, app_account, app_router, app_panel, app_profile, app_admin;

implementation

// ------------------------------------------------------------------ start

function Start: JSValue; async;
var
  I: NativeInt;
  P: TJSObject;
  Thread: double;
  View, Target: JSValue;
begin
  if Truthy(Me.name) then
    try
      await(LoadMe);
    except
    end;
  I := 0;
  while I < Parts.length do
  begin
    P := TJSObject(Parts[I]);
    if Truthy(P['prepare']) then await(JSValue, TJSFunction(P['prepare']).call(P));
    Inc(I);
  end;
  RenderAccount;
  RenderSide;
  I := 0;
  while I < Parts.length do
  begin
    P := TJSObject(Parts[I]);
    if Truthy(P['start']) then TJSFunction(P['start']).call(P);
    Inc(I);
  end;
  Thread := Number(TJSObject(Body.dataset)['thread']);
  View := TJSObject(Body.dataset)['view'];
  Target := TJSObject(Body.dataset)['target'];
  try
    if Same(View, 'profile') then await(OpenProfile(Target))
    else if Same(View, 'admin') then await(OpenAdmin)
    else
    begin
      I := 0;
      while I < Parts.length do
      begin
        P := TJSObject(Parts[I]);
        if Truthy(P['view']) and Truthy(await(JSValue, TJSFunction(P['view']).call(P, View, Target, Thread))) then break;
        Inc(I);
      end;
    end;
  except
    Stream.appendChild(El('p', 'notice', TJSObject(JSExceptValue)['message']));
  end;
  SyncNow(True);
end;

procedure Load;
begin
  StartHelpers;
  StartNotify;
  StartRouter;
  StartAway;
  StartAdmin;

  // What another script, loaded after this one, can
  // add: sidebar groups ({title, test, sigil, button, always}), things over
  // a room's messages, badges by a name, rooms for # completion and
  // /commands the page runs itself.
  Extras := TExtras(new(['groups', TJSArray.new, 'cards', TJSArray.new, 'badges', TJSArray.new, 'rooms', TJSArray.new, 'commands', TJSObject.new,
    'adminTabs', TJSArray.new, 'adminScripts', TJSArray.new, 'adminOverview', TJSArray.new, 'settingGroups', TJSObject.new,
    'accountLinks', TJSArray.new, 'places', TJSObject.new]));
  TJSObject(window)['Chat'] := new(['extras', Extras, 'me', Me, 'state', S, 'icons', Icons, 'el', SideEl, 'link', SideLink, 'icon', SideIcon, 'get', @Get,
    'post', KeysPost, 'enc', @Enc, 'toast', @Toast, 'failed', @Failed, 'route', @Route, 'openPanel', @OpenPanel, 'ago', @Ago,
    'subTabs', @SubTabs, 'facts', @Facts, 'chip', @Chip, 'waiting', @Waiting, '$', @Find, 'stream', Stream, 'Site', SiteName,
    'iconButton', SideIconButton, 'sizeText', @SizeText, 'syncNow', @SyncNow, 'toggleMenu', @ToggleMenu,
    'locale', Locale, 'clock', @Clock, 'shared', @Shared, 'loadScript', @LoadScript, 'parts', Parts, 'body', Body,
    'panel', Panel, 'avatar', SideAvatar, 'dayLabel', @DayLabel, 'keepPinned', @KeepPinned, 'pinWatch', PinWatch,
    'nearBottom', @NearBottom, 'may', @May, 'mayHere', @MayHere, 'notify', @Notify, 'popMenu', @PopMenu,
    'joinForm', @JoinForm, 'confirmBox', @ConfirmBox, 'layerOpened', @LayerOpened, 'layerClosed', @LayerClosed,
    'offerNotifications', @OfferNotifications, 'subscribePush', @SubscribePush]);

  // the same under the name a module's script should use: this is the site's
  // shell, whatever modules are on; Chat is its name from when the chat was all there was
  TJSObject(window)['Site'] := TJSObject(window)['Chat'];

  // after the page's other scripts (chat.js, extensions) have added themselves
  if document.readyState = 'loading' then
    document.addEventListener('DOMContentLoaded', TJSRawEventHandler(procedure(E: TJSEvent) begin Start; end), TJSEventListenerOptions(new(['once', True])))
  else Start;
end;

initialization
  Load;
end.
