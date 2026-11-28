unit ChatPage;

{ The chat: rooms, threads, private conversations and beams, on the site's
  page, which it adds itself to.  A live connection (/api/live) rings when
  something changes, and the page then asks for it (/api/sync); without
  one, the page asks every few seconds. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

implementation

uses JS, Web, chat_shared, chat_sidebar, chat_rooms, chat_menu, chat_sync, chat_live, chat_panels, chat_composer,
  chat_private;

type
  // The member a profile shows, as /api/user describes them.
  TWho = class external name 'Object'(TJSObject)
    name: string;
    ignored: boolean;
  end;

var
  NotificationPermission: string; external name 'Notification.permission';

// ---------------------------------------------------------------- profile

// A private message and Ignore on someone else's profile
procedure ProfileTools(Who: TWho; Tools: TJSElement);
var
  Ignore: TEl;
begin
  if (Me.name <> '') and (Me.name <> Who.name) then
  begin
    Tools.appendChild(Link('/dm/' + Enc(Who.name), 'primary', T('Private message')));
    if Who.ignored then Ignore := El('button', '', T('Stop ignoring')) else Ignore := El('button', '', T('Ignore'));
    TJSHTMLButtonElement(TJSHTMLElement(Ignore))._type := 'button';
    Ignore.title := T('Their messages fold away, and their mentions and private messages do not reach you');
    Ignore.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) async
      var
        Turn: string;
      begin
        try
          if Who.ignored then Turn := '0' else Turn := '1';
          await(JSValue, Post('/api/ignore', new(['name', Who.name, 'on', Turn])));
          Route(SiteBase.path, False);
        except
          Failed(JSExceptValue);
        end;
      end));
    Tools.appendChild(Ignore);
  end;
end;

// What the member put up to stay, under the profile: a room of their own
procedure ProfileShelf(Who: TWho; Generation: double); async;
var
  ShelfHead, Empty: TEl;
  Info: TRoomInfo;
begin
  ShelfHead := El('div', 'shelfhead');
  ShelfHead.append(Icon('shelf'), El('b', '', T('%s’s shelf', Who.name)),
    El('span', '', T('what they put up to stay: things they made, found or want to keep in view')));
  Find('#card').appendChild(ShelfHead);
  Info := nil;
  try
    Info := await(TRoomInfo, Get('/api/room?slug=' + Enc('~' + TJSString(Who.name).toLowerCase)));
  except
  end;
  if (Generation <> S.generation) or not Truthy(Info) then Exit;
  S.view := 'room';
  S.room := Info.slug;
  S.info := Info;
  Stream.className := 'shelf';
  await(LoadMessages(Generation));
  if not Truthy(S.messages.size) then
  begin
    Empty := Find('.empty', Stream);
    if Truthy(Empty) then
    begin
      if Me.name = Who.name then
        Empty.replaceWith(El('p', 'notice empty', T('Your shelf is empty. Put something here that should stay: a project, a screenshot, a favorite answer.')))
      else
        Empty.replaceWith(El('p', 'notice empty', T('Nothing on the shelf yet.')));
    end;
  end;
  if Me.name = Who.name then RenderComposer(Find('#composer-area'), 0)
  else if Me.name <> '' then Find('#composer-area').appendChild(El('p', 'notice', T('Reply to anything on the shelf in its thread.')));
  SyncNow(True);
end;

// ------------------------------------------------------------------ start

procedure Prepare; async;
begin
  if Me.name = '' then
    try
      S.rooms := await(TJSArray, Get('/api/rooms'));
    except
    end;
end;

procedure StartPart;
begin
  if (Me.name <> '') and jsIn('Notification', window) and (NotificationPermission = 'granted') and jsIn('PushManager', window) then
    C.subscribePush;
  C.offerNotifications;
  ConnectLive;
end;

function ViewPart(const View: string; Target: JSValue; Thread: double): boolean; async;
begin
  if View = 'room' then await(OpenRoom(Target, Thread))
  else if View = 'dm' then await(OpenDm(Target))
  else if View = 'search' then OpenSearchAll
  else Exit(False);
  Result := True;
end;

function OpenPart(Parts: TJSArray): boolean; async;
var
  List: TJSArray;
  First: TMsg;
  Root: double;
begin
  if Same(Parts[1], 'p') then await(OpenRoom(Parts[2], 0))
  else if Same(Parts[1], 'm') then
  begin
    List := await(TJSArray, Get('/api/thread?id=' + Enc(Parts[2])));
    if not Truthy(List.length) then raise TJSError.new(T('That message is gone.'));
    First := TMsg(List[0]);
    if Truthy(First.parent) then Root := First.parent else Root := First.id;
    await(OpenRoom(First.room, Root));
  end
  else if Same(Parts[1], 'dm') then await(OpenDm(Parts[2]))
  else if Same(Parts[1], 'chat-search') then OpenSearchAll
  else Exit(False);
  Result := True;
end;

initialization
  Setup;
  // in the account menu while the chat is on
  Extras.accountLinks.push(new(['href', '/irc', 'title', T('Use your IRC client')]));
  chat_sidebar.Start;
  chat_rooms.Start;
  chat_menu.Start;
  chat_sync.Start;
  chat_live.Start;
  chat_composer.Start;
  C.parts.push(new(['prepare', @Prepare, 'sidebar', @RenderSidebar, 'start', @StartPart, 'sync', @SyncNow,
    'view', @ViewPart, 'open', @OpenPart, 'profileTools', @ProfileTools, 'profile', @ProfileShelf]));
end.
