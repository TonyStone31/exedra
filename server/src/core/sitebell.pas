unit SiteBell;

{ Notify open pages of changes over SiteLive connections. Pages fetch
  details normally; new messages may accompany a notification to readers
  permitted to see them. CGI has no live connections, so clients poll
  instead. }

{$mode objfpc}{$H+}

interface

type
  TRingProc = procedure(const Data: string);
  TRingTargetProc = procedure(Target: integer; const Data: string);
  TWatchProc = procedure(const LiveId: string; UserId, RoomId, ThreadId: integer);
  TLiveFunc = function(UserId: integer): boolean;
  TUserProc = procedure(UserId: integer);

var
  { Set by SiteLive when the server runs; nil in a CGI program. }
  OnRingAll: TRingProc;
  OnRingUser: TRingTargetProc;
  OnRingWatchers: TRingTargetProc;
  OnWatch: TWatchProc;
  OnIsLive: TLiveFunc;
  OnDropUser: TUserProc;
  { Set by the module whose pages are rung (the chat): whether it is on.
    While it is off, or when no module sets this, no live connections are
    kept. }
  LiveOn: function: boolean = nil;

{ Whether live connections are wanted right now. }
function LiveWanted: boolean;

{ Every open page: a public room changed. }
procedure RingAll(const Data: string);
{ The pages of one member. }
procedure RingUser(UserId: integer; const Data: string);
{ The pages showing one room. }
procedure RingWatchers(RoomId: integer; const Data: string);
{ Notes which room (and thread) the page on that live connection shows. }
procedure Watch(const LiveId: string; UserId, RoomId, ThreadId: integer);
{ The member has a page open now (False in a CGI program). }
function UserIsLive(UserId: integer): boolean;
{ Closes the member's live pages after a kick, a ban or a new password; they
  come back with only what the member may see now. }
procedure DropUser(UserId: integer);
{ A ring's text: name, value pairs as JSON. }
function BellNote(const Pairs: array of const): string;

implementation

uses
  fpjson;

function BellNote(const Pairs: array of const): string;
begin
  with TJSONObject.Create(Pairs) do
  try
    Result := AsJSON;
  finally
    Free;
  end;
end;

function LiveWanted: boolean;
begin
  Result := Assigned(LiveOn) and LiveOn();
end;

procedure RingAll(const Data: string);
begin
  if OnRingAll <> nil then
    OnRingAll(Data);
end;

procedure RingUser(UserId: integer; const Data: string);
begin
  if (OnRingUser <> nil) and (UserId > 0) then
    OnRingUser(UserId, Data);
end;

procedure RingWatchers(RoomId: integer; const Data: string);
begin
  if OnRingWatchers <> nil then
    OnRingWatchers(RoomId, Data);
end;

function UserIsLive(UserId: integer): boolean;
begin
  Result := (OnIsLive <> nil) and OnIsLive(UserId);
end;

procedure DropUser(UserId: integer);
begin
  if OnDropUser <> nil then
    OnDropUser(UserId);
end;

procedure Watch(const LiveId: string; UserId, RoomId, ThreadId: integer);
begin
  if (OnWatch <> nil) and (LiveId <> '') then
    OnWatch(LiveId, UserId, RoomId, ThreadId);
end;

end.
