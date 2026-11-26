unit SiteLive;

{ One fcl-web WebSocket per page at /api/live, carrying change notifications
  and permitted new messages. Clients ping every 25 seconds; 90 seconds of
  silence closes a connection. Connection threads never use the database:
  request handlers set subscriptions and send notifications. }

{$mode objfpc}{$H+}

// the systems whose sockets say how much waits unsent (Backlogged)
{$if defined(linux) or defined(freebsd)}{$define SOCKETQUEUE}{$endif}

interface

uses
  fphttpserver;

procedure StartLive(Server: TFPCustomHttpServer);

implementation

uses
  {$ifdef SOCKETQUEUE} BaseUnix, Sockets, {$endif} Classes, SysUtils, httpdefs, fpwebsocket, fpcustwsserver, wsupgrader, SiteDb,
  SiteUsers, SiteBell, SiteGuard, SiteStats;

type
  TLiveClient = class
    Id: string;
    UserId, RoomId, ThreadId: integer;
    Heard: QWord;
    Hidden: boolean;  // the page is in a background tab or a phone put it away
  end;

  { The upgrader's events are methods, so they live on an object. }
  TLive = class
    Upgrader: TWebsocketUpgrader;
    procedure AllowUpgrade(Sender: TObject; aRequest: TRequest; var aAllow: boolean);
    procedure Connected(Sender: TObject; aConnection: TWSServerConnection);
    procedure Received(Sender: TObject; const aMessage: TWSMessage);
    procedure Error(Sender: TObject; aConnection: TWSServerConnection; aError: Exception);
  end;

  { One ring on its way: who gets it, checked against each connection while
    the connection list is locked. }
  TRing = class
    Kind: (rkAll, rkUser, rkRoom, rkWatch, rkSweep, rkCount, rkDrop);
    Count: integer;
    Target: integer;
    LiveId: string;
    UserId, RoomId, ThreadId: integer;
    Data: string;
    { a sweep that ends every page: the chat is off }
    Closing: boolean;
    procedure Visit(aConnection: TWSServerConnection; var aContinue: boolean);
  end;

threadvar
  { The member of the request being upgraded, from AllowUpgrade to
    Connected; both run on the thread that answered the request. }
  Upgrading: integer;

var
  Live: TLive;

function ClientOf(aConnection: TWSConnection): TLiveClient;
begin
  Result := TLiveClient(aConnection.UserData);
end;

{ Sends hold the connection-list lock, so a slow reader must not stall the
  site. Close sockets whose pending output fills half the buffer;
  KeepSendsShort caps any remaining send wait at two seconds. }
function Backlogged(aConnection: TWSServerConnection; Size: integer): boolean;
{$ifdef SOCKETQUEUE}
const
  // the ioctl that asks: TIOCOUTQ on Linux, FIONWRITE on FreeBSD
  UNSENT = {$ifdef linux}$5411{$else}$40046677{$endif};
var
  Waiting, Room: cint;
  Len: TSockLen;
  Handle: cint;
begin
  Result := False;
  if (aConnection.ServerTransport = nil) or (aConnection.ServerTransport.Socket = nil) then
    Exit;
  Handle := aConnection.ServerTransport.Socket.Handle;
  Waiting := 0;
  Room := 0;
  Len := SizeOf(Room);
  if (FpIOCtl(Handle, UNSENT, @Waiting) = 0) and (fpgetsockopt(Handle, SOL_SOCKET, SO_SNDBUF, @Room, @Len) = 0) and (Room > 0) then
    Result := Waiting + Size > Room div 2;
end;
  {$else}
begin
  Result := False;
end;
{$endif}

procedure KeepSendsShort(aConnection: TWSServerConnection);
{$ifdef SOCKETQUEUE}
var
  Limit: TTimeVal;
begin
  if (aConnection.ServerTransport = nil) or (aConnection.ServerTransport.Socket = nil) then
    Exit;
  Limit.tv_sec := 2;
  Limit.tv_usec := 0;
  fpsetsockopt(aConnection.ServerTransport.Socket.Handle, SOL_SOCKET, SO_SNDTIMEO, @Limit, SizeOf(Limit));
end;
{$else}
begin
end;
{$endif}

procedure TRing.Visit(aConnection: TWSServerConnection; var aContinue: boolean);
var
  Client: TLiveClient;
  Hit: boolean;
begin
  aContinue := True;
  Client := ClientOf(aConnection);
  if Client = nil then
    Exit;
  case Kind of
    rkAll: Hit := True;
    rkUser: Hit := Client.UserId = Target;
    rkRoom: Hit := Client.RoomId = Target;
    rkWatch:
    begin
      if (Client.Id = LiveId) and (Client.UserId = UserId) then
      begin
        Client.RoomId := RoomId;
        Client.ThreadId := ThreadId;
      end;
      Exit;
    end;
    rkCount:
    begin
      if (Client.UserId = Target) and not Client.Hidden then
        Inc(Count);
      Exit;
    end;
    rkDrop:
    begin
      if (Client.UserId = Target) and (aConnection.ServerTransport <> nil) then
        aConnection.ServerTransport.CloseSocket;
      Exit;
    end;
    rkSweep:
    begin
      // A page that stopped pinging is gone.  Closing its socket ends the
      // connection's thread, which removes it from the list.
      // And every page, once the chat was switched off.
      if (Closing or (GetTickCount64 - Client.Heard > 90000)) and (aConnection.ServerTransport <> nil) then
        aConnection.ServerTransport.CloseSocket;
      Exit;
    end;
  end;
  if not Hit or (Client.Heard = 0) then
    Exit;
  if Backlogged(aConnection, Length(Data)) then
  begin
    Client.Heard := 0;
    if aConnection.ServerTransport <> nil then
      aConnection.ServerTransport.CloseSocket;
    Exit;
  end;
  try
    aConnection.Send(Data);
  except
    on E: Exception do
    begin
      // a send that failed or gave up: no more for this page; its socket closes
      Client.Heard := 0;
      if aConnection.ServerTransport <> nil then
        aConnection.ServerTransport.CloseSocket;
    end;
  end;
end;

procedure Deliver(Ring: TRing);
begin
  try
    Live.Upgrader.Foreach(@Ring.Visit);
  finally
    Ring.Free;
  end;
end;

procedure RingAllPages(const Data: string);
var
  Ring: TRing;
begin
  Ring := TRing.Create;
  Ring.Kind := rkAll;
  Ring.Data := Data;
  Deliver(Ring);
end;

function UserHasPages(UserId: integer): boolean;
var
  Ring: TRing;
begin
  Ring := TRing.Create;
  try
    Ring.Kind := rkCount;
    Ring.Target := UserId;
    Live.Upgrader.Foreach(@Ring.Visit);
    Result := Ring.Count > 0;
  finally
    Ring.Free;
  end;
end;

procedure RingUserPages(Target: integer; const Data: string);
var
  Ring: TRing;
begin
  Ring := TRing.Create;
  Ring.Kind := rkUser;
  Ring.Target := Target;
  Ring.Data := Data;
  Deliver(Ring);
end;

procedure RingRoomPages(Target: integer; const Data: string);
var
  Ring: TRing;
begin
  Ring := TRing.Create;
  Ring.Kind := rkRoom;
  Ring.Target := Target;
  Ring.Data := Data;
  Deliver(Ring);
end;

procedure DropUserPages(Target: integer);
var
  Ring: TRing;
begin
  Ring := TRing.Create;
  Ring.Kind := rkDrop;
  Ring.Target := Target;
  Deliver(Ring);
end;

procedure WatchRoom(const LiveId: string; UserId, RoomId, ThreadId: integer);
var
  Ring: TRing;
begin
  Ring := TRing.Create;
  Ring.Kind := rkWatch;
  Ring.LiveId := LiveId;
  Ring.UserId := UserId;
  Ring.RoomId := RoomId;
  Ring.ThreadId := ThreadId;
  Deliver(Ring);
end;

procedure SweepPages;
var
  Ring: TRing;
begin
  Ring := TRing.Create;
  Ring.Kind := rkSweep;
  Ring.Closing := not LiveWanted;
  Deliver(Ring);
end;

procedure TLive.AllowUpgrade(Sender: TObject; aRequest: TRequest; var aAllow: boolean);
var
  Who: TMember;
begin
  if not aAllow then
    Exit;
  try
    aAllow := (aRequest.Method = 'GET') and LiveWanted and not Restoring and not IsBlocked(ClientIp(aRequest));
    if not aAllow then
      Exit;
    CheckConnection;
    try
      aAllow := AllowAttempt(ClientIp(aRequest), 'live', SettingInt('live_tries', 30), 1);
      if not aAllow then
        Exit;
      Who := CurrentMember(aRequest);
      Upgrading := Who.Id;
      if TokenOf(aRequest) <> '' then
        aAllow := Upgrading > 0;
      // a page of another site listens as a guest does, whoever is signed in
      if FromAnotherSite(aRequest) then
        Upgrading := 0;
      // a banned member listens as a guest does: nothing private comes
      if Who.Banned then
        Upgrading := 0;
    finally
      DoneConnection;  // the live connection carries no database connection
    end;
  finally
    NoteWebRequest(aRequest, not aAllow);
    // an upgrade that goes through never reaches the router's after step
    if aAllow then
      AccessLog(aRequest, 101)
    else
      AccessLog(aRequest, 403);
  end;
end;

procedure TLive.Connected(Sender: TObject; aConnection: TWSServerConnection);
var
  Client: TLiveClient;
begin
  Client := TLiveClient.Create;
  Client.Id := RandomHex(16);
  Client.UserId := Upgrading;
  Client.Heard := GetTickCount64;
  aConnection.FreeUserData := True;
  aConnection.UserData := Client;
  KeepSendsShort(aConnection);
  aConnection.Send('{"t":"hello","id":"' + Client.Id + '"}');
end;

procedure TLive.Received(Sender: TObject; const aMessage: TWSMessage);
var
  Client: TLiveClient;
begin
  // Anything a page sends is a ping; "hidden" and "shown" also say whether
  // anyone is looking at it.
  Client := ClientOf(Sender as TWSConnection);
  if Client <> nil then
  begin
    Client.Heard := GetTickCount64;
    if aMessage.AsString = 'hidden' then
      Client.Hidden := True
    else if aMessage.AsString = 'shown' then
      Client.Hidden := False;
  end;
end;

procedure TLive.Error(Sender: TObject; aConnection: TWSServerConnection; aError: Exception);
begin
  // A page that went away without saying so; its thread ends with it.
end;

procedure StartLive(Server: TFPCustomHttpServer);
begin
  Live := TLive.Create;
  Live.Upgrader := TWebsocketUpgrader.Create(nil);
  with Live.Upgrader do
  begin
    Name := 'live';
    WebServer := Server;
    Resource := '/api/live';
    ThreadMode := wtmThread;
    MessageWaitTime := 1000;
    OnAllowUpgrade := @Live.AllowUpgrade;
    OnConnect := @Live.Connected;
    OnMessageReceived := @Live.Received;
    OnError := @Live.Error;
    Active := True;
  end;
  OnRingAll := @RingAllPages;
  OnRingUser := @RingUserPages;
  OnRingWatchers := @RingRoomPages;
  OnWatch := @WatchRoom;
  OnIsLive := @UserHasPages;
  OnDropUser := @DropUserPages;
  RegisterChore(@SweepPages, 1);
end;

initialization
  RegisterSetting('live_tries', 'Live connection attempts per address per minute', '30', 'number', 'Safety');
end.
