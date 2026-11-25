unit DeskLive;

{ The live connection (/api/live, docs/API.md, Staying current): a
  WebSocket that only rings; the program then asks /api/sync what changed.
  Rings arrive on the socket's thread and are handed to the main thread. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson;

type
  { Deleted and Edited identify private messages. Gone clears a conversation. }
  TRingEvent = procedure(const Kind, Room, Name: string; Deleted, Edited: integer; Gone: boolean) of object;
  TLiveGoneEvent = procedure of object;

var
  { Called on the main thread. }
  OnRing: TRingEvent;
  OnLiveGone: TLiveGoneEvent;
  { The server said hello: the connection is up, and a sync tells it which
    room this program watches. }
  OnLiveReady: TLiveGoneEvent;

procedure StartLive;
procedure StopLive;
{ Sent every 25 seconds, or the server closes the connection after 90. }
procedure PingLive;
{ Tells the server whether the main window is on screen: the frame 'shown',
  or 'hidden' while it is minimized.  A hidden window does not count as the
  member looking.  The state is sent again after every connect. }
procedure LiveShown(IsShown: boolean);
{ The id the server gave this connection, for /api/sync's live; '' until
  it says hello. }
function LiveId: string;
{ Dispatches one ring on the main thread. Invalid JSON is ignored. }
procedure DispatchRing(const Line: string);

implementation

uses
  SyncObjs, URIParser, jsonparser, ssockets, fpwebsocket, fpwebsocketclient, DeskNet;

type
  TLiveConnection = class;

  TLiveSink = class
  private
    Lock: TCriticalSection;
    Inbox: TStringList;
    Id: string;
    Epoch, Generation: integer;
    Link: TLiveConnection;
    Closed: boolean;
    procedure Got(Sender: TObject; const aMessage: TWSMessage);
    procedure Gone(Sender: TObject);
    procedure Flush;
    procedure TellGone;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Close;
  end;

  TLiveSocket = class(TWebsocketClient)
  private
    Lock: TCriticalSection;
    Stream: TSocketStream;
    Canceled: boolean;
    procedure StreamClosed(Sender: TObject);
  protected
    function CreateClientConnection(ATransport: TWSClientTransport): TWebSocketClientConnection; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Cancel;
  end;

  TLiveConnection = class
  private
    References: longint;
    Target: TApiTarget;
    procedure Handshake(Sender: TObject; aHeaders: TStrings);
  public
    Socket: TLiveSocket;
    Pump: TWSThreadMessagePump;
    Sink: TLiveSink;
    constructor Create(const ATarget: TApiTarget; Generation: integer);
    destructor Destroy; override;
    procedure Connect;
    function TryAddReference: boolean;
    procedure Release;
  end;

  TLiveConnector = class(TThread)
  private
    Link: TLiveConnection;
    Error: string;
    procedure Deliver;
  protected
    procedure Execute; override;
  public
    constructor Create(ALink: TLiveConnection);
    destructor Destroy; override;
  end;

  TLivePingJob = class(TApiJob)
  private
    Link: TLiveConnection;
  public
    constructor Create(ALink: TLiveConnection);
    destructor Destroy; override;
    procedure Execute; override;
  end;

  { Sends the window's state as it is when the job runs. }
  TLiveStateJob = class(TLivePingJob)
  public
    procedure Execute; override;
  end;

  TLiveManager = class
    procedure PingDone(Job: TApiJob);
  end;

var
  Sink: TLiveSink;
  Socket: TWebsocketClient;
  LiveCurrent: TLiveConnection;
  Manager: TLiveManager;
  LiveGeneration: integer;
  Connectors: TList;
  Finalizing: boolean;
  LiveHidden: boolean;

constructor TLiveSocket.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Lock := TCriticalSection.Create;
end;

destructor TLiveSocket.Destroy;
begin
  inherited Destroy;
  Lock.Free;
end;

function TLiveSocket.CreateClientConnection(ATransport: TWSClientTransport): TWebSocketClientConnection;
begin
  ATransport.Socket.IOTimeout := 10000;
  Lock.Enter;
  try
    Stream := ATransport.Socket;
    Stream.OnClose := @StreamClosed;
    if Canceled then Stream.WakeBlockedRead;
  finally
    Lock.Leave;
  end;
  Result := inherited CreateClientConnection(ATransport);
end;

procedure TLiveSocket.StreamClosed(Sender: TObject);
begin
  Lock.Enter;
  try
    if Stream = Sender then Stream := nil;
  finally
    Lock.Leave;
  end;
end;

procedure TLiveSocket.Cancel;
begin
  Lock.Enter;
  try
    Canceled := True;
    if Stream <> nil then Stream.WakeBlockedRead;
  finally
    Lock.Leave;
  end;
  Disconnect(False);
end;

constructor TLiveConnection.Create(const ATarget: TApiTarget; Generation: integer);
begin
  inherited Create;
  References := 1;
  Target := ATarget;
  Sink := TLiveSink.Create;
  Sink.Link := Self;
  Sink.Epoch := Target.Epoch;
  Sink.Generation := Generation;
  Socket := TLiveSocket.Create(nil);
end;

function TLiveConnection.TryAddReference: boolean;
var
  Count: longint;
begin
  repeat
    Count := InterlockedCompareExchange(References, 0, 0);
    if Count = 0 then Exit(False);
  until InterlockedCompareExchange(References, Count + 1, Count) = Count;
  Result := True;
end;

procedure TLiveConnection.Release;
begin
  if InterlockedDecrement(References) = 0 then Free;
end;

destructor TLiveConnection.Destroy;
begin
  Sink.Close;
  try
    FreeAndNil(Socket);
  except
    Socket := nil;
  end;
  try
    if Pump <> nil then Pump.Terminate;
    FreeAndNil(Pump);
  except
    Pump := nil;
  end;
  Sink.Free;
  inherited Destroy;
end;

procedure TLiveConnection.Handshake(Sender: TObject; aHeaders: TStrings);
begin
  aHeaders.Add('Authorization: Bearer ' + Target.Auth);
end;

procedure TLiveConnection.Connect;
var
  Uri: TURI;
begin
  Uri := ParseURI(Target.Address);
  Pump := TWSThreadMessagePump.Create(nil);
  Socket.HostName := Uri.Host;
  Socket.ConnectTimeout := 10000;
  Socket.UseSSL := Uri.Protocol = 'https';
  Socket.Port := Uri.Port;
  if Socket.Port = 0 then
    if Socket.UseSSL then Socket.Port := 443
    else
      Socket.Port := 80;
  // a site under a path of its domain (https://example.com/community) has
  // its live address under that path too
  Socket.Resource := ExcludeTrailingPathDelimiter(Uri.Path + Uri.Document) + '/api/live';
  Socket.MessagePump := Pump;
  Socket.OnMessageReceived := @Sink.Got;
  Socket.OnDisconnect := @Sink.Gone;
  Socket.OnSendHandShake := @Handshake;
  Pump.Execute;
  Socket.Connect;
end;

constructor TLiveConnector.Create(ALink: TLiveConnection);
begin
  inherited Create(True);
  Link := ALink;
  if not Link.TryAddReference then raise Exception.Create('The live connection has closed.');
end;

destructor TLiveConnector.Destroy;
begin
  WaitFor;
  TThread.RemoveQueuedEvents(Self);
  Link.Release;
  inherited Destroy;
end;

procedure TLiveConnector.Execute;
begin
  try
    Link.Connect;
  except
    on E: Exception do Error := E.Message;
  end;
  ForceQueue(@Deliver);
end;

procedure TLiveConnector.Deliver;
begin
  if Finalizing then Exit;
  try
    if (Link = LiveCurrent) and (Link.Target.Epoch = ApiEpoch) then
    begin
      if (Error = '') and Link.Socket.Active then
      begin
        Socket := Link.Socket;
        Sink := Link.Sink;
        Sink.Flush;
      end
      else
      begin
        StopLive;
        if Assigned(OnLiveGone) then OnLiveGone;
      end;
    end;
  finally
    Connectors.Remove(Self);
    Free;
  end;
end;

constructor TLivePingJob.Create(ALink: TLiveConnection);
begin
  inherited Create;
  Link := ALink;
  if not Link.TryAddReference then raise Exception.Create('The live connection has closed.');
end;

destructor TLivePingJob.Destroy;
begin
  Link.Release;
  inherited Destroy;
end;

procedure TLivePingJob.Execute;
begin
  if Link.Socket.Active then Link.Socket.SendMessage('ping');
end;

procedure TLiveStateJob.Execute;
begin
  if not Link.Socket.Active then Exit;
  if LiveHidden then Link.Socket.SendMessage('hidden')
  else
    Link.Socket.SendMessage('shown');
end;

procedure TLiveManager.PingDone(Job: TApiJob);
begin
  if (Job.Tag <> LiveGeneration) or (Job.Error = '') then Exit;
  StopLive;
  if Assigned(OnLiveGone) then OnLiveGone;
end;

constructor TLiveSink.Create;
begin
  Lock := TCriticalSection.Create;
  Inbox := TStringList.Create;
end;

destructor TLiveSink.Destroy;
begin
  Close;
  Inbox.Free;
  Lock.Free;
  inherited Destroy;
end;

procedure TLiveSink.Close;
begin
  Lock.Enter;
  try
    Closed := True;
  finally
    Lock.Leave;
  end;
  TThread.RemoveQueuedEvents(nil, @Flush);
  TThread.RemoveQueuedEvents(nil, @TellGone);
end;

procedure TLiveSink.Got(Sender: TObject; const aMessage: TWSMessage);
begin
  Lock.Enter;
  try
    if Closed then Exit;
    Inbox.Add(aMessage.AsString);
    TThread.ForceQueue(nil, @Flush);
  finally
    Lock.Leave;
  end;
end;

procedure TLiveSink.Gone(Sender: TObject);
begin
  Lock.Enter;
  try
    if not Closed then TThread.ForceQueue(nil, @TellGone);
  finally
    Lock.Leave;
  end;
end;

procedure TLiveSink.TellGone;
begin
  if Closed then Exit;
  if (Self <> Sink) or (Epoch <> ApiEpoch) or (Generation <> LiveGeneration) then Exit;
  if (Socket <> nil) and Socket.Active then Exit;
  Id := '';
  if Assigned(OnLiveGone) then OnLiveGone;
end;

procedure TLiveSink.Flush;
var
  Lines: TStringList;
  Line: string;
  Owner: TLiveConnection;
begin
  Owner := Link;
  if not Owner.TryAddReference then Exit;
  try
    if Closed or (Epoch <> ApiEpoch) or (Generation <> LiveGeneration) then
    begin
      Lock.Enter;
      try
        Inbox.Clear;
      finally
        Lock.Leave;
      end;
      Exit;
    end;
    // A hello may arrive before the connector is delivered.
    if Self <> Sink then Exit;
    Lines := TStringList.Create;
    try
      Lock.Enter;
      try
        Lines.Assign(Inbox);
        Inbox.Clear;
      finally
        Lock.Leave;
      end;
      for Line in Lines do
        if (Epoch = ApiEpoch) and (Generation = LiveGeneration) then DispatchRing(Line);
    finally
      Lines.Free;
    end;
  finally
    Owner.Release;
  end;
end;

{ Queued behind the pings on the worker; dropped when the connection is
  down, and sent again at the next hello. }
procedure SendLiveState;
begin
  if (LiveCurrent <> nil) and (Socket <> nil) and Socket.Active then
    ApiWorkAsync(TLiveStateJob.Create(LiveCurrent), @Manager.PingDone, LiveGeneration, 'live-state');
end;

procedure LiveShown(IsShown: boolean);
begin
  if LiveHidden = not IsShown then Exit;
  LiveHidden := not IsShown;
  SendLiveState;
end;

procedure DispatchRing(const Line: string);
var
  Ring: TJSONData;
begin
  try
    Ring := GetJSON(Line);
  except
    Exit;
  end;
  try
    if Ring is TJSONObject then
      with TJSONObject(Ring) do
        if Get('t', '') = 'hello' then
        begin
          if Sink <> nil then Sink.Id := Get('id', '');
          SendLiveState;
          if Assigned(OnLiveReady) then
            OnLiveReady;
        end
        else if Assigned(OnRing) then
          OnRing(Get('t', ''), Get('room', ''), Get('name', Get('from', '')), Get('deleted', 0), Get('edited', 0), Get('gone', False));
  finally
    Ring.Free;
  end;
end;

procedure StartLive;
var
  Connector: TLiveConnector;
begin
  StopLive;
  LiveCurrent := TLiveConnection.Create(ApiTarget, LiveGeneration);
  Connector := TLiveConnector.Create(LiveCurrent);
  Connectors.Add(Connector);
  Connector.Start;
end;

procedure StopLive;
var
  Old: TLiveConnection;
begin
  Inc(LiveGeneration);
  ApiCancelReceiver(Manager);
  Old := LiveCurrent;
  LiveCurrent := nil;
  Socket := nil;
  Sink := nil;
  if Old = nil then Exit;
  Old.Sink.Close;
  try
    try
      Old.Socket.Cancel;
    except
      // An already closed connection needs no close frame.
    end;
  finally
    Old.Release;
  end;
end;

procedure PingLive;
begin
  if (LiveCurrent <> nil) and (Socket <> nil) and Socket.Active then
    ApiWorkAsync(TLivePingJob.Create(LiveCurrent), @Manager.PingDone, LiveGeneration, 'live-ping');
end;

function LiveId: string;
begin
  if Sink = nil then Result := ''
  else
    Result := Sink.Id;
end;

initialization
  Connectors := TList.Create;
  Manager := TLiveManager.Create;

finalization
  Finalizing := True;
  StopLive;
  while Connectors.Count > 0 do
  begin
    TLiveConnector(Connectors.Last).Link.Socket.Cancel;
    TLiveConnector(Connectors.Last).Free;
    Connectors.Delete(Connectors.Count - 1);
  end;
  Connectors.Free;
  Manager.Free;
end.
