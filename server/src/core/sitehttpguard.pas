unit SiteHttpGuard;

{ Built-in HTTP server with temporary uploads, HEAD support and SiteBase
  path handling. Strip the base path before routing and restore it on
  response URLs. SiteGuardRules and SiteGuard supply request checks. }

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, custweb, fphttpapp, custhttpapp, fphttpserver, ssockets, fpsockets, httpdefs;

type
  TGuardApplication = class(THTTPApplication)
  protected
    function InitializeWebHandler: TWebHandler; override;
  end;

  { An uploaded file goes to a temporary file under a random name, and every
    such file is deleted when the request is done with, refused or not. FPC
    numbers them CGI00000.tmp upward and never deletes them: two requests
    could write the same file, and they piled up in a /tmp held in memory. }
  TGuardRequest = class(TFPHTTPConnectionRequest)
  private
    FBaseOff: boolean;
  public
    { Takes the site's base path off the address, once. }
    procedure TakeBaseOff;
    destructor Destroy; override;
    function GetTempUploadFileName(const AName, AFileName: string; ASize: int64): string; override;
  end;

  { A HEAD request is answered as its GET would be, without the words: the
    same handler runs, so the status and the headers (the length among
    them) are the page's own, and the content is not sent.  FPC's router
    knows HEAD only where a route was registered for it, so every page said
    404 to a link checker or a monitor that asked that way. }
  TGuardResponse = class(TFPHTTPConnectionResponse)
  private
    FHeadOnly: boolean;
  protected
    procedure DoSendContent; override;
    procedure CollectHeaders(Headers: TStrings); override;
  end;

  TGuardConnection = class(TFPHTTPConnection)
  protected
    procedure ReadRequestContent(ARequest: TFPHTTPConnectionRequest); override;
    procedure HandleRequestError(E: Exception); override;
  end;

  TGuardHttpServer = class(TEmbeddedHttpServer)
  protected
    function CreateConnection(Data: TSocketStream): TFPHTTPConnection; override;
    function CreateRequest: TFPHTTPConnectionRequest; override;
    function CreateResponse(ARequest: TFPHTTPConnectionRequest): TFPHTTPConnectionResponse; override;
    procedure DoAcceptError(Sender: TObject; ASocket: TFPSocket; E: Exception; var ErrorAction: TAcceptErrorAction); override;
  public
    procedure HandleRequest(var ARequest: TFPHTTPConnectionRequest; var AResponse: TFPHTTPConnectionResponse); override;
  public
    property MaxBodySize;
    property MaxHeaderCount;
    property MaxLineLength;
    property RequestReadTimeout;
    property MaxLiveConnectionCount;
  end;

{ The checks on a multipart body, apart for the tests: '' when it may be
  parsed, else why not. At most MaxParts parts, and no part's header block
  longer than MaxHeader bytes: FPC's parser takes time that grows with the
  square of either. }
function MultipartProblem(const ContentType: string; const Body: TBytes; MaxParts, MaxHeader: integer): string;

implementation

uses StrUtils, SiteDb, SiteGuard, SiteStats, SiteUsers, SiteRoles, SiteBase;

const
  // what anyone may send; more needs a signed-in member (and the route's
  // permission on an admin route), checked before the body is read
  OpenBodyBytes = 64 * 1024;
  MultipartParts = 64;
  MultipartHeaderBytes = 8192;
  // a body has 30 seconds, plus one for each 16 KB it announced
  BodySeconds = 30;
  BodyBytesPerSecond = 16 * 1024;

type
  TGuardHandler = class(TFPHTTPServerHandler)
  protected
    function CreateServer: TEmbeddedHttpServer; override;
  end;

function RefusedWith(Code: integer; const Text: string): EHTTP;
begin
  Result := EHTTP.Create(Text);
  Result.StatusCode := Code;
end;

function TGuardApplication.InitializeWebHandler: TWebHandler;
begin
  Result := TGuardHandler.Create(Self);
end;

function TGuardHandler.CreateServer: TEmbeddedHttpServer;
var
  GuardServer: TGuardHttpServer;
begin
  GuardServer := TGuardHttpServer.Create(Self);
  GuardServer.MaxBodySize := 32 * 1024 * 1024;
  GuardServer.MaxHeaderCount := SettingInt('request_headers', 64);
  if (GuardServer.MaxHeaderCount < 1) or (GuardServer.MaxHeaderCount > 128) then
    GuardServer.MaxHeaderCount := 64;
  GuardServer.MaxLineLength := 8192;
  GuardServer.RequestReadTimeout := SettingInt('request_read_ms', 30000);
  if (GuardServer.RequestReadTimeout < 1) or (GuardServer.RequestReadTimeout > 60000) then
    GuardServer.RequestReadTimeout := 30000;
  // ordinary requests at once; live connections leave this count once upgraded.
  // pfSense's HAProxy holds more than this in its queue (server maxconn).
  GuardServer.MaxLiveConnectionCount := SettingInt('request_connections', 256);
  if (GuardServer.MaxLiveConnectionCount < 16) or (GuardServer.MaxLiveConnectionCount > 2048) then
    GuardServer.MaxLiveConnectionCount := 256;
  // every request handles one file at most
  TUploadedFiles.MaxUploadFiles := 2;
  Result := GuardServer;
end;

{ TGuardRequest }

destructor TGuardRequest.Destroy;
var
  Names: TUploadTemps;
begin
  // the names first: FPC frees the files (and closes their streams) below
  Names := UploadTemps(Files);
  inherited Destroy;
  RemoveUploadTemps(Names);
end;

{ A site under a path of its domain: the path comes off before anything
  reads the address.  Called where a body is read and again where the
  request is handled, since a request without a body skips the first. }
procedure TGuardRequest.TakeBaseOff;
begin
  if FBaseOff or (BasePath = '') then
    Exit;
  FBaseOff := True;
  PathInfo := WithoutBase(PathInfo);
  URI := WithoutBase(URI);
  URL := WithoutBase(URL);
end;

function TGuardRequest.GetTempUploadFileName(const AName, AFileName: string; ASize: int64): string;
begin
  Result := UploadTempName(RequestUploadDir);
end;

{ TGuardHttpServer }

function TGuardHttpServer.CreateConnection(Data: TSocketStream): TFPHTTPConnection;
begin
  Result := TGuardConnection.Create(Self, Data);
end;

function TGuardHttpServer.CreateRequest: TFPHTTPConnectionRequest;
begin
  Result := TGuardRequest.Create;
end;

function TGuardHttpServer.CreateResponse(ARequest: TFPHTTPConnectionRequest): TFPHTTPConnectionResponse;
var
  Answer: TGuardResponse;
begin
  Answer := TGuardResponse.Create(ARequest);
  Answer.FHeadOnly := ARequest.Method = 'HEAD';
  // set on every request, so a client cannot say it for itself: the
  // visitors log still writes HEAD for these
  ARequest.SetCustomHeader(HEAD_MARK, BoolToStr(Answer.FHeadOnly, '1', ''));
  if Answer.FHeadOnly then
    ARequest.Method := 'GET';
  Result := Answer;
end;

{ TGuardResponse }

{ Under a base path every address that leaves starts with it: where a
  redirect goes, and the links of a page or of HTML inside a JSON answer.
  Before the headers are made, so the length sent is the new one. }
procedure TGuardResponse.CollectHeaders(Headers: TStrings);
begin
  if BasePath <> '' then
  begin
    if Location <> '' then
      Location := WithBase(Location);
    if (ContentStream = nil) and (Content <> '') then
      if ContentType.StartsWith('text/html') then
        Content := RebaseHtml(Content)
      else if ContentType.StartsWith('application/json') then
        Content := RebaseJson(Content);
  end;
  inherited CollectHeaders(Headers);
end;

procedure TGuardResponse.DoSendContent;
begin
  if not FHeadOnly then
    inherited DoSendContent;
end;

procedure TGuardHttpServer.HandleRequest(var ARequest: TFPHTTPConnectionRequest; var AResponse: TFPHTTPConnectionResponse);
begin
  if ARequest is TGuardRequest then
    TGuardRequest(ARequest).TakeBaseOff;
  inherited HandleRequest(ARequest, AResponse);
end;

procedure TGuardHttpServer.DoAcceptError(Sender: TObject; ASocket: TFPSocket; E: Exception; var ErrorAction: TAcceptErrorAction);
begin
  // FPC raises out of the accept loop on any failed accept, which ends the
  // program: one connection that could not be taken (files or memory run
  // short, a client gone already) took the whole site down. Skip it instead,
  // with a breath so a lasting shortage does not spin the loop.
  if not Active then
  begin
    ErrorAction := aeaStop;
    Exit;
  end;
  ErrorAction := aeaIgnore;
  try
    Log('A connection could not be accepted: ' + E.Message);
  except
  end;
  Sleep(50);
end;

{ The multipart checks }

function BoundaryOf(const ContentType: string): string;
var
  P, E: integer;
begin
  Result := '';
  P := Pos('boundary=', LowerCase(ContentType));
  if P = 0 then
    Exit;
  Result := Copy(ContentType, P + 9, MaxInt);
  E := Pos(';', Result);
  if E > 0 then
    Result := Copy(Result, 1, E - 1);
  Result := Trim(Result);
  if (Length(Result) >= 2) and (Result[1] = '"') and (Result[Length(Result)] = '"') then
    Result := Copy(Result, 2, Length(Result) - 2);
end;

function MultipartProblem(const ContentType: string; const Body: TBytes; MaxParts, MaxHeader: integer): string;
var
  Text, Marker: rawbytestring;
  At, HeaderEnd, Parts: integer;
begin
  Result := '';
  if not StartsText('multipart/', Trim(ContentType)) then
    Exit;
  Marker := '--' + BoundaryOf(ContentType);
  if Length(Marker) <= 2 then
    Exit;
  SetLength(Text, Length(Body));
  if Length(Body) > 0 then
    Move(Body[0], Text[1], Length(Body));
  Parts := 0;
  At := PosEx(Marker, Text, 1);
  while At > 0 do
  begin
    // the closing marker is followed by '--' and starts no part
    if Copy(Text, At + Length(Marker), 2) = '--' then
      Break;
    Inc(Parts);
    if Parts > MaxParts then
      Exit(Format('more than %d parts', [MaxParts]));
    HeaderEnd := PosEx(#13#10#13#10, Text, At + Length(Marker));
    if HeaderEnd = 0 then
      HeaderEnd := Length(Text);
    if HeaderEnd - At > MaxHeader then
      Exit(Format('a part header longer than %d bytes', [MaxHeader]));
    At := PosEx(Marker, Text, HeaderEnd);
  end;
end;

{ TGuardConnection }

procedure TGuardConnection.ReadRequestContent(ARequest: TFPHTTPConnectionRequest);
var
  Want, Have, Room: int64;
  Got, Ahead: TBytes;
  Deadline, Now64: QWord;
  Got1: integer;
  Me: TMember;
  Permission, Problem: string;
begin
  // before the body's limits are chosen by the address
  if ARequest is TGuardRequest then
    TGuardRequest(ARequest).TakeBaseOff;
  if ARequest.GetFieldByName('Transfer-Encoding') <> '' then
    raise RefusedWith(400, 'Use Content-Length for the request body.');
  if (ARequest.Method <> 'GET') and (ARequest.Method <> 'HEAD') and (ARequest.Method <> 'POST') then
    raise RefusedWith(405, 'Method not allowed.');
  Want := ARequest.ContentLength;
  if (Want > TransportBodyLimit(ARequest.PathInfo)) or ((Server is TGuardHttpServer) and (Want > TGuardHttpServer(Server).MaxBodySize)) then
    raise RefusedWith(413, 'The request body is too large.');
  // a large body only from a member, and on an admin route only from one who
  // may use it: nobody else makes this program store or parse megabytes
  if Want > OpenBodyBytes then
  begin
    CheckConnection;
    Me := SignedInMember(ARequest);
    Permission := AdminRoutePermission(ARequest.PathInfo);
    if (Me.Id = 0) or Me.Banned or ((Permission <> '') and not Can(Me, Permission)) then
      raise RefusedWith(413, 'The request body is too large.');
  end;
  // FPC reads a body with a time limit on each read only, so a client that
  // sends a byte now and then holds the connection for ever; and when the
  // connection ends early it hands on the body with zeros for the missing
  // part. Here the whole body has a deadline and must arrive in full.
  // (Bytes past the body stay unread: this server closes after each request.)
  Ahead := ResidualBytes;
  Have := Length(Ahead);
  if Have > Want then
    Have := Want;
  SetLength(Got, Have);
  if Have > 0 then
    Move(Ahead[0], Got[0], Have);
  Deadline := GetTickCount64 + QWord(BodySeconds + Want div BodyBytesPerSecond) * 1000;
  while Have < Want do
  begin
    Now64 := GetTickCount64;
    if Now64 >= Deadline then
      raise RefusedWith(408, 'The request body came too slowly.');
    if not Socket.CanRead(integer(Deadline - Now64)) then
      raise RefusedWith(408, 'The request body came too slowly.');
    Room := Want - Have;
    if Room > 256 * 1024 then
      Room := 256 * 1024;
    SetLength(Got, Have + Room);
    Got1 := Socket.Read(Got[Have], Room);
    if Got1 <= 0 then
      raise RefusedWith(400, 'The request body ended early.');
    Have := Have + Got1;
    SetLength(Got, Have);
  end;
  Problem := MultipartProblem(ARequest.ContentType, Got, MultipartParts, MultipartHeaderBytes);
  if Problem <> '' then
    raise RefusedWith(400, 'Refused: ' + Problem + '.');
  ARequest.ContentBytes := Got;
end;

procedure TGuardConnection.HandleRequestError(E: Exception);
var
  Code: integer;
  Reply, Text: string;
begin
  Code := 0;
  if E is EHTTP then
    Code := EHTTP(E).StatusCode
  else if E is EHTTPServer then
    Code := E.HelpContext;
  if (Code >= 400) and (Code <= 599) then
  begin
    NoteTransportRefusal;
    Text := 'Request refused.';
    if Code = 413 then
      Text := 'The request body is too large.'
    else if Code = 408 then
      Text := 'The request took too long.';
    Reply := 'HTTP/1.1 ' + IntToStr(Code) + ' Request refused'#13#10 + 'Connection: close'#13#10'Content-Type: text/plain; charset=utf-8'#13#10 +
      'Content-Length: ' + IntToStr(Length(Text)) + #13#10#13#10 + Text;
    if Code = 405 then
      Reply := StringReplace(Reply, 'Connection: close', 'Allow: GET, HEAD, POST'#13#10'Connection: close', []);
    try
      Socket.WriteBuffer(Reply[1], Length(Reply));
    except
      // the client may be gone already
    end;
  end;
  inherited HandleRequestError(E);
  DoneConnection;
end;

end.
