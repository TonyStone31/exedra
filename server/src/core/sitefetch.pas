unit SiteFetch;

{ Fetch untrusted HTTP(S) URLs on public hosts and standard ports. Check the
  connected address before sending or starting TLS, including after
  redirects, to prevent DNS rebinding. A watchdog enforces size and time
  caps; tokens go only to the original host over HTTPS. }

{$mode objfpc}{$H+}

interface

uses
  Classes, fphttpclient;

type
  { Ends a fetch that runs past its time.  One per thread that fetches;
    Free it when done (Terminate, WaitFor, Free). }
  TWatchdog = class(TThread)
  protected
    procedure Execute; override;
  public
    Client: TFPHTTPClient;
    Deadline: QWord;
    constructor Create;
  end;

var
  { True only for a test copy on a home network: private addresses allowed. }
  AllowPrivate: boolean = False;

{ Only a public web host on the usual ports, without looking the name up. }
function PublicWebAddress(const Url: string): boolean;
{ The same, and every address the name gives is public: for anything that
  fetches an address a stranger chose. }
function ResolvesPublic(const Url: string): boolean;
{ An IPv4 address on the open internet, as dotted text. }
function PublicV4(const Address: string): boolean;
{ The body at Url, at most Cap bytes, within Seconds or by Ends (a
  GetTickCount64 time), whichever comes first; '' with why in Problem.
  Quiet is how long the far end may say nothing, for hosts that build an
  archive before they send it. }
function SafeGet(Dog: TWatchdog; const Url, Agent: string; Cap: int64; Seconds: integer; Ends: QWord; out Problem: string; Quiet: integer = 10;
  const Bearer: string = ''): rawbytestring;
{ The same, written to Target as it arrives, so a large answer is never
  held in memory.  False with why in Problem; Target may then hold part of
  an answer and is the caller's to throw away. }
function SafeGetTo(Dog: TWatchdog; const Url, Agent: string; Target: TStream; Cap: int64; Seconds: integer; Ends: QWord; out Problem: string;
  Quiet: integer = 10; const Bearer: string = ''): boolean;

implementation

uses
  SysUtils, Math, URIParser, ssockets, Sockets, netdb, SiteTls;

type
  TPublicPeer = class(TSocketHandler)
  public
    function Connect: boolean; override;
  end;

  TPublicPeerTls = class(TSiteTlsHandler)
  public
    function Connect: boolean; override;
  end;

  { Passes on what is written until Cap bytes have gone through. }
  TCappedTarget = class(TStream)
  public
    Target: TStream;
    Cap, Written: int64;
    function Write(const Buffer; Count: longint): longint; override;
    function Seek(const Offset: int64; Origin: TSeekOrigin): int64; override;
  end;

  TFetchHooks = class
    Cap: int64;
    Client: TFPHTTPClient;
    TokenHost: string;
    procedure Receiving(Sender: TObject; const ContentLength, CurrentPos: int64);
    procedure Redirecting(Sender: TObject; const ASrc: string; var ADest: string);
    procedure SocketHandler(Sender: TObject; const UseSSL: boolean; out AHandler: TSocketHandler);
  end;

var
  WatchLock: TRTLCriticalSection;

{ A private, loopback, shared or multicast IPv4 address, by its first two numbers. }
function PrivateV4(A, B: integer): boolean;
begin
  Result := (A < 1) or (A = 10) or (A = 127) or ((A = 169) and (B = 254)) or ((A = 192) and (B = 168)) or ((A = 172) and (B >= 16) and (B <= 31)) or
    ((A = 100) and (B >= 64) and (B <= 127)) or (A >= 224);
end;

{ Only a public web host on the usual ports.  A name without a dot, the
  loopback and private ranges, and IPv6 literals are refused: the server
  must not be talked into reading its own network. }
function PublicWebAddress(const Url: string): boolean;
var
  U: TURI;
  Host: string;
  A, B: integer;
  Parts: TStringArray;
begin
  Result := False;
  U := ParseURI(Url);
  if (U.Protocol <> 'http') and (U.Protocol <> 'https') then
    Exit;
  // plain comparisons: a set stops at 255
  if (U.Port <> 0) and (U.Port <> 80) and (U.Port <> 443) then
    Exit;
  Host := LowerCase(U.Host);
  if (Host = '') or (Pos('.', Host) = 0) or (Pos(':', Host) > 0) or (Host = 'localhost') then
    Exit;
  if Host.EndsWith('.local') or Host.EndsWith('.localhost') or Host.EndsWith('.internal') or Host.EndsWith('.lan') then
    Exit;
  if Host[1] in ['0'..'9'] then
  begin
    Parts := Host.Split(['.']);
    if Length(Parts) <> 4 then
      Exit;
    A := StrToIntDef(Parts[0], -1);
    B := StrToIntDef(Parts[1], -1);
    if PrivateV4(A, B) then
      Exit;
  end;
  Result := True;
end;

{ As PublicWebAddress, and the name looked up: a public name may point
  into the house's network, and every address it gives must be public.
  Asked in the job, before the fetch and at each redirect, so posting is
  not kept waiting. }
function ResolvesPublic(const Url: string): boolean;
var
  Addresses: array[0..15] of THostAddr;
  Host: string;
  I, N: integer;
begin
  Result := PublicWebAddress(Url);
  if not Result then
    Exit;
  Host := LowerCase(ParseURI(Url).Host);
  // an address written as four numbers was checked above and needs no
  // lookup; a name that merely starts with a digit is looked up like any other
  if PublicV4(Host) then
    Exit;
  N := ResolveName(Host, Addresses);
  if N <= 0 then
    Exit(False);
  if N > Length(Addresses) then
    N := Length(Addresses);
  for I := 0 to N - 1 do
    if PrivateV4(Addresses[I].s_bytes[1], Addresses[I].s_bytes[2]) then
      Exit(False);
end;

{ Anything but IPv4 (IPv6 included, which these fetches do not reach) is refused. }
function PublicV4(const Address: string): boolean;
var
  Parts: TStringArray;
  A, B, I: integer;
begin
  Result := False;
  Parts := Address.Split(['.']);
  if Length(Parts) <> 4 then
    Exit;
  for I := 0 to 3 do
    if (StrToIntDef(Parts[I], -1) < 0) or (StrToIntDef(Parts[I], -1) > 255) then
      Exit;
  A := StrToInt(Parts[0]);
  B := StrToInt(Parts[1]);
  Result := not PrivateV4(A, B);
end;

{ The address the socket is connected to, from the system itself; '' for
  anything but IPv4. }
function PeerAddress(Socket: TSocketStream): string;
var
  Addr: TInetSockAddr;
  Len: TSockLen;
begin
  Result := '';
  FillChar(Addr, SizeOf(Addr), 0);
  Len := SizeOf(Addr);
  if (fpGetPeerName(Socket.Handle, @Addr, @Len) = 0) and (Addr.sin_family = AF_INET) then
    Result := NetAddrToStr(Addr.sin_addr);
end;

procedure NeedPublicPeer(Socket: TSocketStream);
begin
  if not AllowPrivate and not PublicV4(PeerAddress(Socket)) then
    raise Exception.Create('not a public address (' + PeerAddress(Socket) + ')');
end;

function TPublicPeer.Connect: boolean;
begin
  NeedPublicPeer(Socket);
  Result := inherited Connect;
end;

function TPublicPeerTls.Connect: boolean;
begin
  // the address before the handshake: nothing goes to a private one
  NeedPublicPeer(Socket);
  Result := inherited Connect;
end;

procedure TFetchHooks.SocketHandler(Sender: TObject; const UseSSL: boolean; out AHandler: TSocketHandler);
begin
  if UseSSL then
    AHandler := TPublicPeerTls.Create
  else
    AHandler := TPublicPeer.Create;
end;

function TCappedTarget.Write(const Buffer; Count: longint): longint;
begin
  if (Count < 0) or (Written + Count > Cap) then
    Abort;
  Result := Target.Write(Buffer, Count);
  Inc(Written, Result);
end;

function TCappedTarget.Seek(const Offset: int64; Origin: TSeekOrigin): int64;
begin
  Result := Target.Seek(Offset, Origin);
end;

procedure TFetchHooks.Receiving(Sender: TObject; const ContentLength, CurrentPos: int64);
begin
  if (CurrentPos > Cap) or (ContentLength > Cap) then
    Abort;
end;

procedure TFetchHooks.Redirecting(Sender: TObject; const ASrc: string; var ADest: string);
begin
  if not AllowPrivate and not PublicWebAddress(ADest) then
    ADest := '';
  // the token was for the first host only, and never travels in the clear
  if (TokenHost <> '') and not (SameText(ParseURI(ADest).Host, TokenHost) and SameText(ParseURI(ADest).Protocol, 'https')) and (Client.IndexOfHeader('Authorization') >= 0) then
    Client.RequestHeaders.Delete(Client.IndexOfHeader('Authorization'));
end;

constructor TWatchdog.Create;
begin
  FreeOnTerminate := False;
  inherited Create(False);
end;

procedure TWatchdog.Execute;
begin
  while not Terminated do
  begin
    Sleep(250);
    EnterCriticalSection(WatchLock);
    try
      if (Client <> nil) and (GetTickCount64 > Deadline) then
        Client.Terminate;
    finally
      LeaveCriticalSection(WatchLock);
    end;
  end;
end;

function SafeGetTo(Dog: TWatchdog; const Url, Agent: string; Target: TStream; Cap: int64; Seconds: integer; Ends: QWord; out Problem: string;
  Quiet: integer = 10; const Bearer: string = ''): boolean;
var
  Client: TFPHTTPClient;
  Capped: TCappedTarget;
  Hooks: TFetchHooks;
begin
  Result := False;
  Problem := '';
  if not AllowPrivate and not PublicWebAddress(Url) then
  begin
    Problem := 'not a public address';
    Exit;
  end;
  if GetTickCount64 >= Ends then
  begin
    Problem := 'out of time';
    Exit;
  end;
  Client := TFPHTTPClient.Create(nil);
  Capped := TCappedTarget.Create;
  Hooks := TFetchHooks.Create;
  try
    Capped.Target := Target;
    Capped.Cap := Cap;
    Hooks.Cap := Cap;
    Client.OnGetSocketHandler := @Hooks.SocketHandler;
    Client.ConnectTimeout := 8000;
    Client.IOTimeout := Quiet * 1000;
    Client.AllowRedirect := True;
    Client.MaxRedirects := 3;
    Client.AddHeader('User-Agent', Agent);
    Client.AddHeader('Accept', 'text/html,*/*');
    if Bearer <> '' then
    begin
      Client.AddHeader('Authorization', 'Bearer ' + Bearer);
      Hooks.Client := Client;
      Hooks.TokenHost := ParseURI(Url).Host;
    end;
    Client.OnDataReceived := @Hooks.Receiving;
    Client.OnRedirect := @Hooks.Redirecting;
    EnterCriticalSection(WatchLock);
    Dog.Client := Client;
    Dog.Deadline := Min(GetTickCount64 + QWord(Seconds) * 1000, Ends);
    LeaveCriticalSection(WatchLock);
    try
      try
        Client.Get(Url, Capped);
        if Client.Terminated then
          Problem := 'too slow'
        else if Client.ResponseStatusCode <> 200 then
          Problem := 'answered ' + IntToStr(Client.ResponseStatusCode)
        else
          Result := True;
      except
        on EAbort do
          Problem := 'too big';
        on E: Exception do
          if Client.Terminated then
            Problem := 'too slow'
          else
            Problem := Copy(E.Message, 1, 120);
      end;
    finally
      EnterCriticalSection(WatchLock);
      Dog.Client := nil;
      LeaveCriticalSection(WatchLock);
    end;
  finally
    Hooks.Free;
    Capped.Free;
    Client.Free;
  end;
end;

function SafeGet(Dog: TWatchdog; const Url, Agent: string; Cap: int64; Seconds: integer; Ends: QWord; out Problem: string; Quiet: integer = 10;
  const Bearer: string = ''): rawbytestring;
var
  Got: TMemoryStream;
begin
  Result := '';
  Got := TMemoryStream.Create;
  try
    if SafeGetTo(Dog, Url, Agent, Got, Cap, Seconds, Ends, Problem, Quiet, Bearer) and (Got.Size > 0) then
    begin
      SetLength(Result, Got.Size);
      Got.Position := 0;
      Got.ReadBuffer(Result[1], Got.Size);
    end;
  finally
    Got.Free;
  end;
end;

initialization
  InitCriticalSection(WatchLock);

finalization
  DoneCriticalSection(WatchLock);
end.
