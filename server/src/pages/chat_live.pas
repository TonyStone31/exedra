unit chat_live;

{ The live connection and what each of its rings does. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, chat_shared;

procedure LoadNotices(Fresh: boolean); async;
procedure ConnectLive;
procedure Start;

implementation

uses chat_sidebar, chat_rooms, chat_sync, chat_panels, chat_private;

type
  // What the live connection sends: t says what kind of ring it is.
  TNote = class external name 'Object'(TJSObject)
    t: string;
    id: string;
    room: string;
    m: TMsg;
    name: JSValue;
    from: string;
    seen: double;
    gone: boolean;
    deleted: JSValue;
    edited: JSValue;
  end;
  // What /api/notices answers, and one notice of it.
  TNoticeAnswer = class external name 'Object'(TJSObject)
    items: TJSArray;
    unseen: JSValue;
  end;
  TNotice = class external name 'Object'(TJSObject)
    id: JSValue;
    seen: boolean;
    text: JSValue;
  end;
  // A room of the side list.
  TSideRoom = class external name 'Object'(TJSObject)
    slug: string;
    unread: JSValue;
  end;
  // What is kept of a drawn message: {data, node}.
  TEntry = class external name 'Object'(TJSObject)
    data: TMsg;
  end;
  // The socket with its handlers as plain functions.
  TSocket = class external name 'WebSocket'(TJSEventTarget)
    onmessage: TJSRawEventHandler;
    onclose: TJSRawEventHandler;
    constructor new(const Url: string);
  end;

// Web's setTimeout takes whole milliseconds only.
function Later(Work: TProc; Ms: double): NativeInt; external name 'window.setTimeout';
function ParseJson(Text: JSValue): JSValue; external name 'JSON.parse';
// Web's reload asks for an argument the browser does not need.
procedure Reload; external name 'window.location.reload';
// The in operator as a function.
function Has(Target: JSValue; const Key: string): boolean; external name 'Reflect.has';

var
  ReadTimer: NativeInt = 0;
  Leaving: boolean = False;

procedure LeaveChannel(const Why: string);
begin
  if Leaving then Exit;
  Leaving := True;
  Toast(Why);
  window.setTimeout(procedure begin window.location.assign(SiteBase.url('/')); end, 2500);
end;

// A private channel can close under an open page: a kick, or the people
// running the site deleting it. The server drops the live connection
// either way, so this asks again when it comes back.
function LeaveIfGone: JSValue; async;
var
  Slug: string;
  Answer: TJSResponse;
begin
  if (S.view <> 'room') or not Truthy(S.info) or not S.info.&private then Exit(undefined);
  Slug := S.room;
  Answer := await(TJSResponse, window.fetch('/api/room?slug=' + Enc(Slug)));
  if (Answer.status <> 404) or (S.view <> 'room') or (S.room <> Slug) then Exit(undefined);
  LeaveChannel(T('You are no longer in #%s.', Slug));
  Result := undefined;
end;

// Asked when the live connection starts and when it rings with a notice;
// Fresh shows the new ones as a toast too.
procedure LoadNotices(Fresh: boolean); async;
var
  A: TNoticeAnswer;
  Known: TJSSet;
  Items, Unseen: TJSArray;
  Count: JSValue;
begin
  if Me.name = '' then Exit;
  try
    A := await(TNoticeAnswer, Get('/api/notices?unseen=1'));
  except
    Exit;
  end;
  Known := TJSSet.new(Notices.items.map(function(N: JSValue; Index: NativeInt; All: TJSArray): JSValue
    begin Result := TNotice(N).id; end));
  Items := A.items;
  if not Truthy(Items) then Items := TJSArray.new;
  Unseen := Items.filter(function(N: JSValue; Index: NativeInt; All: TJSArray): boolean
    begin Result := not TNotice(N).seen; end);
  Count := A.unseen;
  if not Count then Count := 0;
  Notices := TNotices(new(['unseen', Count, 'items', Unseen.slice(0, 3)]));
  if Fresh then
    Unseen.filter(function(N: JSValue; Index: NativeInt; All: TJSArray): boolean
      begin Result := not Known.has(TNotice(N).id); end).slice(0, 3).forEach(
      procedure(N: JSValue; Index: NativeInt; All: TJSArray) begin Toast(TNotice(N).text); end);
  RenderSidebar;
end;

// A new message that came with its ring: shown without asking. The server
// sends it as anyone sees it, so this page works out what is about this member.
procedure Arrived(M: TMsg);
var
  Lower: string;
  Names, One: TJSArray;
  P: JSValue;
  Data: TMsg;
begin
  Lower := TJSString(Me.name).toLowerCase;
  Names := M.names;
  if not Truthy(Names) then Names := TJSArray.new;
  M.mentions_me := (Me.name <> '') and Names.some(function(N: JSValue; Index: NativeInt; All: TJSArray): boolean
    begin Result := TJSString(N).toLowerCase = Lower; end);
  M.ignored := Me.ignores.indexOf(M.uid) >= 0;
  One := TJSArray.new;
  One.push(M);
  if Truthy(M.parent) then
  begin
    if S.thread = M.parent then AddThread(One);
    P := S.messages.get(M.parent);
    if P then
    begin
      Data := TEntry(P).data;
      Upsert(TMsg(TJSObject.assign(TJSObject.new, Data,
        new(['replies', Data.replies + 1, 'last_reply', M.at, 'rev', Data.rev + 1]))), Stream, S.messages, False);
    end;
  end
  else AddMessages(One, False);
  // Tell the server what was read, a little later, once for a burst.
  if not Truthy(ReadTimer) and (Me.name <> '') then
    ReadTimer := Later(procedure
      begin
        ReadTimer := 0;
        FromRing := True;
        Sync;
      end, 4000 + Random * 6000);
end;

procedure Heard(Note: TNote);
var
  R: JSValue;
  One: TJSArray;
begin
  if Note.t = 'names' then
  begin
    Reload;
    Exit;
  end
  else if Note.t = 'hello' then
  begin
    Live.id := Note.id;
    Live.wait := 1000;
    Live.failures := 0;
    SyncNow(True);
    LoadNotices(False);
    TJSPromise(LeaveIfGone).catch(function(Why: JSValue): JSValue begin end);
  end
  else if Note.t = 'notice' then LoadNotices(True)
  else if Note.t = 'room' then
  begin
    if (Note.room = S.room) and Truthy(Note.m) then Arrived(Note.m)
    else if Note.room = S.room then
      Later(procedure
        begin
          FromRing := True;
          Sync;
        end, Random * 300)
    else
    begin
      R := S.rooms.find(function(X: JSValue; Index: NativeInt; All: TJSArray): boolean
        begin Result := TSideRoom(X).slug = Note.room; end);
      if R then
      begin
        if not TSideRoom(R).unread then
        begin
          TSideRoom(R).unread := 1;
          RenderSidebar;
        end;
        SidebarSoon(2000 + Random * 6000);
      end;
    end;
  end
  else if Note.t = 'typing' then
  begin
    if Note.room = S.room then
    begin
      One := TJSArray.new;
      One.push(Note.name);
      NoteTyping(One);
    end;
  end
  else if Note.t = 'dmtyping' then
  begin
    if (S.view = 'dm') and (Note.from = S.dm) then
    begin
      One := TJSArray.new;
      One.push(Note.from);
      NoteTyping(One);
    end;
  end
  else if Note.t = 'dmseen' then
  begin
    if (S.view = 'dm') and (Note.from = S.dm) then
    begin
      S.dmSeen := Note.seen;
      MarkSeen;
    end;
  end
  else if Note.t = 'me' then SidebarSoon(300)
  else if Note.t = 'gone' then
  begin
    if Note.room = S.room then LeaveChannel(T('This channel was deleted.'));
    SidebarSoon(300);
  end
  else if Note.t = 'dm' then
  begin
    if Note.gone and (S.view = 'dm') and (Note.from = S.dm) then Route(SiteBase.path, False)
    else if Truthy(Note.deleted) and (S.view = 'dm') and (Note.from = S.dm) then DropDm(Note.deleted)
    else if Truthy(Note.edited) and (S.view = 'dm') and (Note.from = S.dm) then RefreshDm(Note.edited)
    else if (S.view = 'dm') and ((Note.from = S.dm) or (Note.from = Me.name)) then
    begin
      if Truthy(S.typers[Note.from]) then
      begin
        JSDelete(S.typers, Note.from);
        RenderTyping;
      end;
      PollNow;
    end;
    SidebarSoon(300);
  end;
end;

procedure ConnectLive;
var
  Ws: TSocket;
  Scheme: string;
begin
  if not Has(window, 'WebSocket') or (Live.failures > 4) then Exit;
  try
    if window.location.protocol = 'https:' then Scheme := 'wss://' else Scheme := 'ws://';
    Ws := TSocket.new(Scheme + window.location.host + SiteBase.url('/api/live'));
  except
    Exit;
  end;
  Live.ws := TJSWebSocket(TJSEventTarget(Ws));
  Ws.onmessage := TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Note: JSValue;
    begin
      try
        Note := ParseJson(TJSMessageEvent(E).data);
      except
        Exit;
      end;
      Heard(TNote(Note));
    end);
  Ws.onclose := TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      // A server without live connections (a CGI site) fails every time;
      // after a few the page settles for asking on a timer.
      if not Truthy(Live.id) then Live.failures := Live.failures + 1;
      Live.id := '';
      Live.ws := nil;
      Later(procedure begin ConnectLive; end, Live.wait);
      Live.wait := Min(Live.wait * 2, 30000);
    end);
end;

procedure Start;
begin
  window.setInterval(procedure
    begin
      if Truthy(Live.ws) and (Live.ws.readyState = 1) then Live.ws.send('ping');
    end, 25000);
  // A page nobody looks at should not keep pushes from coming.
  document.addEventListener('visibilitychange', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      if Truthy(Live.ws) and (Live.ws.readyState = 1) then
        if document.hidden then Live.ws.send('hidden') else Live.ws.send('shown');
    end));
end;

end.
