unit chat_sync;

{ Asking the server what changed. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, chat_shared;

procedure SyncNow(WithRooms: boolean = False);
procedure SidebarSoon(Ms: double);
procedure Sync; async;
procedure Start;

implementation

uses chat_sidebar, chat_rooms, chat_panels, chat_private;

type
  // What /api/sync answers.
  TSyncAnswer = class external name 'Object'(TJSObject)
    messages: TJSArray;
    thread: TJSArray;
    typing: TJSArray;
    here: TJSArray;
    more: boolean;
    rev: double;
    rooms: TJSArray;
    dms: TJSArray;
  end;
  // A private conversation in the side list.
  TDmRow = class external name 'Object'(TJSObject)
    name: string;
    seen: double;
  end;
  // The shell counts its syncs in whole numbers.
  TTicks = class external name 'Object'(TJSObject)
    tick: NativeInt;
  end;

// Web's setTimeout takes whole milliseconds only.
function Later(Work: TProc; Ms: double): NativeInt; external name 'window.setTimeout';
function MaxOf(This: JSValue; Values: TJSArray): JSValue; external name 'Math.max.apply';

var
  SyncTimer: NativeInt = 0;
  Syncing: boolean = False;
  Again: boolean = False;
  SidebarTimer: NativeInt = 0;

procedure SyncNow(WithRooms: boolean);
begin
  if WithRooms then RoomsWanted := True;
  window.clearTimeout(SyncTimer);
  Sync;
end;

// The sidebar's counts, asked for a little later, so a busy channel's
// messages do not each send every follower's page to ask at once.
procedure SidebarSoon(Ms: double);
begin
  if Truthy(SidebarTimer) then Exit;
  SidebarTimer := Later(procedure
    begin
      SidebarTimer := 0;
      SyncNow(True);
    end, Ms);
end;

procedure Sync; async;
var
  Generation: double;
  Params: TParams;
  A: TSyncAnswer;
  Dms: TJSArray;
  Shown: JSValue;
  Wait: NativeInt;
begin
  // One at a time; a ring during a sync makes another right after.
  if Syncing then
  begin
    Again := True;
    Exit;
  end;
  Syncing := True;
  Again := False;
  Generation := S.generation;
  Params := TParams.new(new(['since', S.since]));
  // Asked because of a ring: only what changed. Otherwise also say we are
  // here and hear who else is.
  if not FromRing then Params.set_('here', '1');
  FromRing := False;
  if S.view = 'room' then Params.set_('room', S.room);
  if Truthy(S.thread) then Params.set_('thread', S.thread);
  if Truthy(Live.id) then Params.set_('live', Live.id);
  if (Me.name <> '') and (RoomsWanted or (not Truthy(Live.id) and (TTicks(TJSObject(S)).tick mod 5 = 0))) then
    Params.set_('rooms', '1');
  RoomsWanted := False;
  if (S.view = 'room') and not document.hidden and NearBottom and Truthy(S.messages.size) then
    Params.set_('read', MaxOf(nil, TJSArray.from(S.messages.keys)));
  TTicks(TJSObject(S)).tick := TTicks(TJSObject(S)).tick + 1;
  try
    A := await(TSyncAnswer, Get('/api/sync?' + String(JSValue(Params))));
    if Generation = S.generation then
    begin
      if Truthy(A.messages) then AddMessages(A.messages, False);
      if Truthy(A.thread) then AddThread(A.thread);
      if Truthy(A.typing) then NoteTyping(A.typing);
      if Truthy(A.here) then RenderHere(A.here);
      // More than one answer holds: carry on from the last one given.
      if A.more then
      begin
        S.since := TMsg(A.messages[A.messages.length - 1]).rev;
        Again := True;
      end
      else S.since := Max(S.since, A.rev - 3000000);
    end;
    if Truthy(A.rooms) then
    begin
      Dms := A.dms;
      if not Truthy(Dms) then Dms := TJSArray.new;
      NotifyNews(A.rooms, Dms);
      S.rooms := A.rooms;
      if Truthy(A.dms) then S.dms := A.dms else S.dms := TJSArray.new;
      RenderSidebar;
      // The list says how far the open conversation was read, while it is among its newest.
      Shown := False;
      if S.view = 'dm' then
        Shown := S.dms.find(function(X: JSValue; Index: NativeInt; All: TJSArray): boolean
          begin Result := TDmRow(X).name = S.dm; end);
      if Shown then
      begin
        if Truthy(TDmRow(Shown).seen) then S.dmSeen := TDmRow(Shown).seen else S.dmSeen := 0;
        MarkSeen;
      end;
    end;
  except
    // The next one tries again.
  end;
  Syncing := False;
  window.clearTimeout(SyncTimer);
  if Again then
  begin
    Sync;
    Exit;
  end;
  // With a live connection the rings say when; the timer only keeps
  // presence fresh. Without one, ask often.
  if Truthy(Live.id) then Wait := 50000
  else if document.hidden then Wait := 15000
  else Wait := 3000;
  SyncTimer := window.setTimeout(procedure begin Sync; end, Wait);
end;

procedure Start;
begin
  document.addEventListener('visibilitychange', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      if document.hidden then Exit;
      SyncNow(True);
      if Truthy(S.dm) then PollDm(S.generation);
    end));
end;

end.
