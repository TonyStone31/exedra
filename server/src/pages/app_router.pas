unit app_router;

{ The site's page: moving between its places without reading the page
  again, and the Back key, which closes what is on top before it leaves. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, app_helpers;

var
  // The parts on this page, each with what it answers for (chat.js).
  Parts: TJSArray;
  // Whether this is the site installed as an app.
  Installed: boolean;

procedure LayerOpened;
procedure LayerClosed(After: JSValue = undefined);
procedure ToggleMenu;
function Route(Path: string; Push: JSValue): JSValue; async;
procedure RenderSide;
procedure SyncNow(WithRooms: JSValue);
procedure StartRouter;

implementation

uses app_panel, app_profile, app_admin;

type
  TDone = reference to procedure;

var
  // Web declares the history's state for one browser only.
  HistoryState: JSValue; external name 'history.state';
  // Back closes what is on top (the room list on a phone, the side panel, a
  // picture) before it leaves the place.  Opening one
  // adds a history entry, so Back has something to take away; closing one
  // some other way takes the entry back out.
  LayerEntry: boolean = False;
  AfterMove: JSValue = nil;   // runs instead of the next popstate's usual work
  // The width at which the room list slides over the chat (site.css).
  Narrow: TJSMediaQueryList;
  Guarded: boolean = False;
  Here: string;   // the place shown, for the guard's entries

function DecodeURIComponent(Value: JSValue): JSValue; external name 'decodeURIComponent';

// ----------------------------------------------------------------- router

function IsAppPath(const Path: string): boolean;
begin
  Result := TJSRegexp.new('^\/(p|m|u|dm)\/|^\/(admin|chat-search)$').test(Path);
end;

// ------------------------------------------------------------ the back key

function OnTop: boolean;
begin
  Result := Body.classList.contains('menu') or not Panel.hidden or not Find('#lightbox').hidden;
end;

procedure LayerOpened;
begin
  if LayerEntry then Exit;
  LayerEntry := True;
  window.history.pushState(TJSObject.new, '', SiteBase.path);
end;

// Takes our entry back out once nothing is on top, then runs After.
procedure LayerClosed(After: JSValue);
begin
  if not LayerEntry or OnTop then
  begin
    if Truthy(After) then TJSFunction(After).call(TJSObject(undefined));
    Exit;
  end;
  LayerEntry := False;
  if Truthy(After) then AfterMove := After else AfterMove := TDone(procedure begin end);
  window.history.back;
end;

// Closes the top one only: a picture over a thread leaves the thread.
procedure CloseTop;
begin
  if not Find('#lightbox').hidden then Find('#lightbox').hidden := True
  else if Body.classList.contains('menu') then Body.classList.remove('menu')
  else if not Panel.hidden then
  begin
    ClosePanel;
    if TJSString(SiteBase.path).startsWith('/m/') and Truthy(S.room) then window.history.replaceState(TJSObject.new, '', '/p/' + Enc(S.room));
  end;
end;

procedure ToggleMenu;
begin
  Body.classList.toggle('menu');
  if Body.classList.contains('menu') then LayerOpened
  else LayerClosed;
end;

procedure ClearView;
var
  AdminNav: TEl;
begin
  Inc(S.generation);
  S.view := '';
  S.room := '';
  S.info := nil;
  S.messages.clear;
  S.thread := 0;
  S.threadMessages.clear;
  S.dm := '';
  S.typers := TJSObject.new;
  window.clearTimeout(S.dmTimer);
  Stream.replaceChildren;
  Stream.className := '';
  Stream.noPin := False;
  Find('#roomhead').replaceChildren;
  Find('#card').replaceChildren;
  Find('#typing').replaceChildren;
  Find('#composer-area').replaceChildren;
  // the admin page's list gives the side back to the parts
  Body.classList.remove('admin-view');
  AdminNav := Find('#adminnav');
  if Truthy(AdminNav) then AdminNav.hidden := True;
  ClosePanel;
end;

function FirstRoom: string;
var
  R: JSValue;
begin
  R := S.rooms.find(function(X: JSValue; Index: NativeInt; List: TJSArray): boolean
    begin
      Result := Same(TJSObject(X)['kind'], 'channel');
    end);
  if Truthy(R) then Result := '/p/' + Enc(TJSObject(R)['slug']) else Result := '/';
end;

// Push is true to add a history entry, 'replace' to take the current one's
// place, false when Back or Forward already moved there.
function Route(Path: string; Push: JSValue): JSValue; async;
var
  Pieces: TJSArray;
  I: NativeInt;
  P: TJSObject;
begin
  if Path = '/' then
  begin
    Path := FirstRoom;
    if Path = '/' then
    begin
      window.location.href := SiteBase.url('/');
      Exit;
    end;
  end;
  // Leaving with something on top: its entry goes first.
  if LayerEntry and Truthy(Push) then
  begin
    LayerEntry := False;
    Result := TJSPromise.new(procedure(Done, Refuse: TJSPromiseResolver)
      begin
        AfterMove := TDone(procedure begin TJSPromise(Route(Path, Push))._then(Done); end);
        window.history.back;
      end);
    Exit;
  end;
  if Same(Push, 'replace') then window.history.replaceState(TJSObject.new, '', Path)
  else if Truthy(Push) then window.history.pushState(TJSObject.new, '', Path);
  Here := Path;
  ClearView;
  Pieces := TJSArray(TJSString(Path).split('/')).map(TJSArrayMapCallback(JSValue(@DecodeURIComponent)));
  try
    if Same(Pieces[1], 'u') then await(OpenProfile(Pieces[2]))
    else if Same(Pieces[1], 'admin') then await(OpenAdmin)
    else
    begin
      I := 0;
      while I < Parts.length do
      begin
        P := TJSObject(Parts[I]);
        if Truthy(P['open']) and Truthy(await(JSValue, TJSFunction(P['open']).call(P, Pieces))) then break;
        Inc(I);
      end;
    end;
  except
    Stream.appendChild(El('p', 'notice', TJSObject(JSExceptValue)['message']));
  end;
  RenderSide;
end;

procedure RenderSide;
var
  I: NativeInt;
  P: TJSObject;
begin
  I := 0;
  while I < Parts.length do
  begin
    P := TJSObject(Parts[I]);
    if Truthy(P['sidebar']) then TJSFunction(P['sidebar']).call(P);
    Inc(I);
  end;
end;

procedure SyncNow(WithRooms: JSValue);
var
  I: NativeInt;
  P: TJSObject;
begin
  I := 0;
  while I < Parts.length do
  begin
    P := TJSObject(Parts[I]);
    if Truthy(P['sync']) then TJSFunction(P['sync']).call(P, WithRooms);
    Inc(I);
  end;
end;

procedure StartRouter;
begin
  document.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      A: TJSHTMLAnchorElement;
      FromList: boolean;
    begin
      A := TJSHTMLAnchorElement(TJSElement(E.target).closest('a[href]'));
      if not Truthy(A) or Truthy(TJSObject(A)['target']) or TJSMouseEvent(E).ctrlKey or TJSMouseEvent(E).metaKey or TJSMouseEvent(E).shiftKey or
        (A.origin <> window.location.origin) then Exit;
      if not IsAppPath(SiteBase.strip(TJSObject(A)['pathname'])) then Exit;
      E.preventDefault;
      // A room picked from the phone's room list takes the place of the one
      // left, so Back leaves the chat once instead of room by room.
      FromList := Body.classList.contains('menu') and Truthy(A.closest('#side'));
      Body.classList.remove('menu');
      if FromList then Route(SiteBase.strip(TJSObject(A)['pathname']), 'replace')
      else Route(SiteBase.strip(TJSObject(A)['pathname']), True);
    end));

  // A link in a message opens a new tab and the conversation stays: all
  // but a picture, shown over the page, and what the router above shows.
  Side.newTabLinks('.msg', True, function(A: TJSElement): boolean
    begin
      Result := A.classList.contains('shot') or IsAppPath(SiteBase.strip(TJSObject(A)['pathname']));
    end);

  Narrow := window.matchMedia('(max-width: 860px)');

  // On a phone, a tap beside the open room list closes it and does nothing
  // else.
  document.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      if not Body.classList.contains('menu') or Truthy(TJSElement(E.target).closest('#side, .menubtn')) then Exit;
      E.preventDefault;
      E.stopPropagation;
      Body.classList.remove('menu');
      LayerClosed;
    end), True);

  // Installed apps keep a guard history entry under the last page: Back
  // asks once, then allows closing; a tap restores the page entry. Create
  // entries on a tap because Chrome skips those added before interaction.
  Installed := window.matchMedia('(display-mode: standalone)').matches;
  Here := SiteBase.path;
  document.addEventListener('pointerdown', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      if not Installed then Exit;
      if not Guarded then
      begin
        Guarded := True;
        window.history.replaceState(new(['guard', True]), '', SiteBase.path);
        window.history.pushState(TJSObject.new, '', SiteBase.path);
      end
      else if Truthy(HistoryState) and Truthy(TJSObject(HistoryState)['guard']) then window.history.pushState(TJSObject.new, '', Here);
    end), True);

  window.addEventListener('popstate', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      After: JSValue;
    begin
      if Truthy(AfterMove) then
      begin
        After := AfterMove;
        AfterMove := nil;
        TJSFunction(After).call(TJSObject(undefined));
      end
      else if Truthy(HistoryState) and Truthy(TJSObject(HistoryState)['guard']) then
      begin
        window.history.replaceState(new(['guard', True]), '', Here);
        Toast(T('Press back again to leave'));
      end
      else if LayerEntry then
      begin
        LayerEntry := False;
        CloseTop;
        if OnTop then LayerOpened;
      end
      else Route(SiteBase.path, False);
    end));

  // Alt+Up and Alt+Down walk the sidebar; Ctrl+K jumps to a room by name.
  document.addEventListener('keydown', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      K: TJSKeyboardEvent;
      Rooms: TJSArray;
      I: NativeInt;
    begin
      K := TJSKeyboardEvent(E);
      if K.ctrlKey and (K.key = 'k') then
      begin
        E.preventDefault;
        if Narrow.matches then
        begin
          Body.classList.add('menu');
          LayerOpened;
        end;
        Find('#jump').focus;
        Exit;
      end;
      if not K.altKey or ((K.key <> 'ArrowUp') and (K.key <> 'ArrowDown')) then Exit;
      Rooms := TJSArray.from(document.querySelectorAll('#roomlist a.room'));
      if Rooms.length = 0 then Exit;
      E.preventDefault;
      I := Rooms.findIndex(function(A: JSValue; Index: NativeInt; List: TJSArray): boolean
        begin
          Result := TJSElement(A).classList.contains('active');
        end);
      if K.key = 'ArrowDown' then I := (I + 1) mod Rooms.length else I := (I + Rooms.length - 1) mod Rooms.length;
      Route(SiteBase.strip(TJSElement(Rooms[I]).getAttribute('href')), True);
    end));

  Parts := TJSArray.new;
end;

end.
