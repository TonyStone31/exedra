unit DeskNet;

{ HTTPS and JSON requests with the sign-in token. Async API requests run in
  order on one worker and return on the UI thread; live connections and
  picture fetches use separate threads. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson;

type
  EApiFailure = class(Exception)
  public
    Status: integer;
    RetryAfter: string;
    ErrorHandled: boolean;
    constructor CreateStatus(const Words: string; AStatus: integer; AHandled: boolean = False);
  end;

  TApiError = procedure(const Words: string) of object;
  TApiSignInEnded = procedure of object;

  TApiTarget = record
    Address, Auth: string;
    Epoch: integer;
  end;

var
  { The site's address, as https://chat.example.org or
    https://example.org/community, without a slash at the end. }
  Server: string = '';
  Token: string = '';
  { Counts ApiForgetAll; an answer from before the count changed is dropped. }
  ApiEpoch: integer = 0;
  { Told when a callback raised; nil shows nothing. }
  ApiOnError: TApiError = nil;
  { Account 401 responses share one UI-thread notification per sign-in. }
  ApiOnSignInEnded: TApiSignInEnded = nil;

function AccountResponse(const URL, Auth, AccountServer, AccountToken: string; Epoch, AccountEpoch: integer): boolean;
function ClaimSignInFailure(Status: integer; OwnAccount: boolean; var Notified: boolean): boolean;
{ 401 for a sign-in the server no longer accepts. Exedra answers an
  expired sign-in with 403 and these words, so they count as 401 too. }
function SignInStatus(Status: integer; const Words: string): integer;
procedure ApiResetSignInFailure;
function ApiErrorHandled(E: Exception): boolean;
function ApiRetryDue: QWord;
function RetryAfterSeconds(const Header: string): integer;
function ApiTarget: TApiTarget;
function ApiTargetCurrent(const Target: TApiTarget): boolean;
{ A root-relative address from the server's HTML without the path the site
  sits under: on a site at https://example.com/community, '/community/p/lobby'
  is '/p/lobby'.  Anything else comes back as it is. }
function SiteLocal(const Address: string): string;

{ Text as a JSON object, which the caller frees; raises when it is anything else. }
function JSONObject(const Text: string): TJSONObject;
{ The fields /api/upload takes beside the file: Sealed for one already
  encrypted for a locked conversation, Avatar for the member's own picture,
  RoomIcon for a channel's.  The caller frees the list. }
function UploadFields(Sealed, Avatar: boolean; const Expire, RoomIcon: string): TStringList;
{ Fields (name, value, name, value...) as a query string or a form's body. }
function Query(const Fields: array of string): string;

type
  { What a read of a private conversation asks for: the newest messages,
    those after or before Id, the one message Id, or those after Id while
    saying that everything up to Id was read. }
  TDmAsk = (daOpen, daAfter, daBefore, daOne, daRead);

{ The path for GET /api/dm.  The server marks what it returns as read
  unless the request peeks: it peeks when the member is not looking, and
  always for one message fetched again. }
function DmPath(const Who: string; Ask: TDmAsk; Id: integer; Looking: boolean): string;

type
  TApiJob = class;
  { Runs on the UI thread once the answer is in, or the request failed. }
  TApiDone = procedure(Job: TApiJob) of object;

  { One request on the worker: what was asked, and what came back. }
  TApiJob = class
  public
    Method, Path, Body: string;
    Data: TBytesStream;
    Payload: TObject;
    Fields: TStringList;
    FileName: string;
    { the caller's own mark, say a room generation: a callback compares it
      with the current one and drops an answer that came too late }
    Tag: integer;
    { jobs with the same key stand in for each other: a new one takes the
      place of one still waiting, so typing notices do not pile up }
    Key: string;
    { The action's original target, independent of queue replacement. }
    Context: string;
    Answer: string;
    { the HTTP status, 0 when no answer came }
    Status: integer;
    RetryAfter: string;
    { '' when the request went through; else the server's words, or the
      connection's }
    Error: string;
    ErrorHandled: boolean;
    Done: TApiDone;
    Auth: string;
    { The account server at submission, for restore backoff. }
    Address: string;
    Epoch: integer;
    destructor Destroy; override;
    procedure Execute; virtual;
    { The answer parsed; raises on failure. }
    function JSON: TJSONData;
    function ObjectJSON: TJSONObject;
    function ArrayJSON: TJSONArray;
  end;

var
  { Observes account requests before their callbacks, including silent polls. }
  ApiOnResult: TApiDone = nil;

{ GET and POST on the worker, Done called back on the UI thread.  Done may
  be nil when nothing waits for the answer. }
{ Submits an owned job whose Execute runs on the worker. }
procedure ApiWorkAsync(Job: TApiJob; Done: TApiDone; Tag: integer = 0; const Key: string = '');
procedure ApiGetAsync(const Path: string; Done: TApiDone; Tag: integer = 0; const Key: string = '');
procedure ApiGetTargetAsync(const Target: TApiTarget; const Path: string; Done: TApiDone);
procedure ApiPostTargetAsync(const Target: TApiTarget; const Path: string; const Fields: array of string; Done: TApiDone);
procedure ApiPostAsync(const Path: string; const Fields: array of string; Done: TApiDone; Tag: integer = 0; const Key: string = ''; const Context: string = '');
{ Upload bytes are copied before submission; the job owns the copy. }
procedure ApiUploadAsync(const FileName: string; Data: TStream; Sealed, Avatar: boolean; const Expire, RoomIcon: string; Done: TApiDone;
  Tag: integer = 0; const Context: string = '');
{ The job owns Payload and releases it after delivery or cancellation. }
procedure ApiBytesAsync(const Path: string; Done: TApiDone; Tag: integer = 0; const Context: string = ''; Payload: TObject = nil);
{ Drops waiting jobs and suppresses old account answers. }
procedure ApiForgetAll;
{ Discards callbacks to a window before it is freed, without dropping
  requests belonging to other windows. Call on the UI thread. }
procedure ApiForgetReceiver(Receiver: TObject);
{ Also removes this receiver's requests that have not started. }
procedure ApiCancelReceiver(Receiver: TObject);
procedure ApiStopWorker;

type
  { Bytes is empty when the download failed. Runs on the main thread. }
  TFetched = procedure(const Path: string; Bytes: TBytes; Tag: integer) of object;

const
  MaxPictureBytes = 8 * 1024 * 1024;
  MaxFetchThreads = 4;
  MaxFetchPending = 512;

{ Downloads through the fetch pool. False means the queue is full. }
function Fetch(const Path: string; Done: TFetched; PublicResource: boolean = False; Tag: integer = 0): boolean;

implementation

uses
  fphttpclient, sslsockets, jsonparser, syncobjs, TlsLibFclNetTls, DateUtils, HTTPProtocol, Math, URIParser;

type
  { Read refusal bodies before reporting upload errors. }
  TResponseClient = class(TFPHTTPClient)
  protected
    function CheckResponseCode(ACode: integer; const AllowedResponseCodes: array of integer): boolean; override;
  end;
  { fphttpclient and fcl-web's WebSocket client both turn certificate
    checks off before they connect; this turns them back on. }
  TCheckedTlsHandler = class(TTlsLibSocketHandler)
  public
    function Connect: boolean; override;
  end;

  TFetchRequest = class
  public
    Path, Rel, Auth, Address: string;
    Bytes: TBytes;
    Done: TFetched;
    Epoch, Status, Tag: integer;
  end;

  TFetchThread = class(TThread)
  private
    Request: TFetchRequest;
    procedure Deliver;
  protected
    procedure Execute; override;
  end;

var
  SignInNotified: boolean = False;
  RestoreLock: TCriticalSection;
  RestoreDue: QWord = 0;
  RestoreEpoch: integer = -1;
  Fetchers, FetchPending: TList;
  FetchLock: TCriticalSection;
  FetchWake: TEventObject;

function TResponseClient.CheckResponseCode(ACode: integer; const AllowedResponseCodes: array of integer): boolean;
begin
  Result := True;
end;

function ApiTarget: TApiTarget;
begin
  Result.Address := Server;
  Result.Auth := Token;
  Result.Epoch := ApiEpoch;
end;

function SiteLocal(const Address: string): string;
var
  Uri: TURI;
  Base: string;
begin
  Result := Address;
  Uri := ParseURI(ApiTarget.Address);
  Base := ExcludeTrailingPathDelimiter(Uri.Path + Uri.Document);
  if (Base <> '') and Address.StartsWith(Base + '/') then
    Result := Copy(Address, Length(Base) + 1, MaxInt);
end;

function ApiTargetCurrent(const Target: TApiTarget): boolean;
begin
  Result := (Target.Epoch = ApiEpoch) and (Target.Address = Server) and (Target.Auth = Token);
end;

function RetryAfterSeconds(const Header: string): integer;
var
  Seconds: int64;
  Stamp: TDateTime;
begin
  if TryStrToInt64(Trim(Header), Seconds) then
    Exit(integer(EnsureRange(Seconds, int64(0), int64(High(integer) div 1000))));
  Result := 0;
  try
    Stamp := ParseHTTPDateTime(Header);
    if Stamp > 0 then
      Result := Max(0, Ceil((Stamp - LocalTimeToUniversal(Now)) * 86400));
  except
    // An invalid header falls back to the normal retry delay.
  end;
end;

function ApiRetryDue: QWord;
begin
  RestoreLock.Enter;
  try
    if RestoreEpoch = ApiEpoch then Result := RestoreDue
    else
      Result := 0;
  finally
    RestoreLock.Leave;
  end;
end;

procedure KeepRetry(Status: integer; const Header: string; Epoch: integer);
var
  Due: QWord;
begin
  if Status <> 503 then Exit;
  if Epoch <> ApiEpoch then Exit;
  Due := GetTickCount64 + QWord(RetryAfterSeconds(Header)) * 1000;
  RestoreLock.Enter;
  try
    if (RestoreEpoch <> Epoch) or (Due > RestoreDue) then RestoreDue := Due;
    RestoreEpoch := Epoch;
  finally
    RestoreLock.Leave;
  end;
end;

constructor EApiFailure.CreateStatus(const Words: string; AStatus: integer; AHandled: boolean);
begin
  inherited Create(Words);
  Status := AStatus;
  ErrorHandled := AHandled;
end;

function AccountResponse(const URL, Auth, AccountServer, AccountToken: string; Epoch, AccountEpoch: integer): boolean;
begin
  Result := (Epoch = AccountEpoch) and (AccountToken <> '') and (Auth = AccountToken) and (AccountServer <> '') and
    (SameText(URL, AccountServer) or SameText(Copy(URL, 1, Length(AccountServer) + 1), AccountServer + '/'));
end;

function ClaimSignInFailure(Status: integer; OwnAccount: boolean; var Notified: boolean): boolean;
begin
  Result := (Status = 401) and OwnAccount and not Notified;
  if Result then Notified := True;
end;

function SignInStatus(Status: integer; const Words: string): integer;
begin
  Result := Status;
  if (Status = 403) and (Trim(Words) = 'That sign-in has expired. Sign in again.') then
    Result := 401;
end;

procedure ApiResetSignInFailure;
begin
  SignInNotified := False;
end;

function ApiErrorHandled(E: Exception): boolean;
begin
  Result := (E is EApiFailure) and EApiFailure(E).ErrorHandled;
end;

function ObserveStatus(Status: integer; const URL, Auth: string; Epoch: integer): boolean;
begin
  Result := (Status = 401) and AccountResponse(URL, Auth, Server, Token, Epoch, ApiEpoch) and Assigned(ApiOnSignInEnded);
  if ClaimSignInFailure(Status, Result, SignInNotified) then ApiOnSignInEnded;
end;

function TCheckedTlsHandler.Connect: boolean;
begin
  VerifyPeerCert := True;
  Result := inherited Connect;
end;

function Query(const Fields: array of string): string;
var
  I: integer;
begin
  Result := '';
  I := 0;
  while I < High(Fields) do
  begin
    if Result <> '' then
      Result := Result + '&';
    Result := Result + EncodeURLElement(Fields[I]) + '=' + EncodeURLElement(Fields[I + 1]);
    Inc(I, 2);
  end;
end;

function DmPath(const Who: string; Ask: TDmAsk; Id: integer; Looking: boolean): string;
begin
  Result := '/api/dm?' + Query(['with', Who]);
  case Ask of
    daOpen: ;
    daAfter: Result := Result + '&after=' + IntToStr(Id);
    daBefore: Result := Result + '&before=' + IntToStr(Id);
    daOne: Result := Result + '&id=' + IntToStr(Id);
    daRead: Result := Result + '&after=' + IntToStr(Id) + '&read=' + IntToStr(Id);
  end;
  if (Ask = daOne) or not Looking then
    Result := Result + '&peek=1';
end;

procedure TFetchThread.Execute;
var
  Data: TBytesStream;
  Words: string;
  Client: TFPHTTPClient;
begin
  while not Terminated do
  begin
    FetchLock.Enter;
    try
      Request := nil;
      if FetchPending.Count > 0 then
      begin
        Request := TFetchRequest(FetchPending[0]);
        FetchPending.Delete(0);
      end;
    finally
      FetchLock.Leave;
    end;
    if Request = nil then
    begin
      FetchWake.WaitFor(100);
      Continue;
    end;
    try
      while not Terminated and (Request.Epoch = ApiEpoch) and (ApiRetryDue > GetTickCount64) do
        FetchWake.WaitFor(100);
      if Terminated or (Request.Epoch <> ApiEpoch) then Continue;
      Data := TBytesStream.Create;
      Client := TFPHTTPClient.Create(nil);
      Client.MaxResponseSize := MaxPictureBytes;
      try
        Client.ConnectTimeout := 10000;
        Client.IOTimeout := 30000;
        if Request.Auth <> '' then Client.AddHeader('Authorization', 'Bearer ' + Request.Auth);
        try
          Client.HTTPMethod('GET', Request.Path, Data, []);
          Request.Status := Client.ResponseStatusCode;
          if SameText(Copy(Request.Path, 1, Length(Request.Address) + 1), Request.Address + '/') then
            KeepRetry(Request.Status, Client.GetHeader(Client.ResponseHeaders, 'Retry-After'), Request.Epoch);
          if (Request.Status >= 400) and (Data.Size > 0) then
          begin
            SetString(Words, pansichar(Data.Memory), Data.Size);
            Request.Status := SignInStatus(Request.Status, Words);
          end;
          if Request.Status = 200 then Request.Bytes := Copy(Data.Bytes, 0, Data.Size);
        except
          Request.Bytes := nil;
        end;
      finally
        Client.Free;
        Data.Free;
      end;
      Synchronize(@Deliver);
    finally
      FetchLock.Enter;
      try
        FreeAndNil(Request);
      finally
        FetchLock.Leave;
      end;
    end;
  end;
end;

procedure TFetchThread.Deliver;
begin
  if (Request.Epoch = ApiEpoch) and Assigned(Request.Done) then
  begin
    ObserveStatus(Request.Status, Request.Path, Request.Auth, Request.Epoch);
    if (Request.Epoch = ApiEpoch) and Assigned(Request.Done) then
      Request.Done(Request.Rel, Request.Bytes, Request.Tag);
  end;
end;

function Fetch(const Path: string; Done: TFetched; PublicResource: boolean; Tag: integer): boolean;
var
  R: TFetchRequest;
  T: TFetchThread;
begin
  Result := False;
  FetchLock.Enter;
  try
    if FetchPending.Count >= MaxFetchPending then Exit;
    R := TFetchRequest.Create;
    R.Rel := Path;
    R.Address := Server;
    if LowerCase(Path).StartsWith('http://') or LowerCase(Path).StartsWith('https://') then R.Path := Path
    else
    begin
      R.Path := Server + Path;
      if not PublicResource and not SignInNotified then R.Auth := Token;
    end;
    R.Done := Done;
    R.Epoch := ApiEpoch;
    R.Tag := Tag;
    FetchPending.Add(R);
    Result := True;
  finally
    FetchLock.Leave;
  end;
  while Fetchers.Count < MaxFetchThreads do
  begin
    T := TFetchThread.Create(True);
    Fetchers.Add(T);
    T.Start;
  end;
  FetchWake.SetEvent;
end;

function UploadFields(Sealed, Avatar: boolean; const Expire, RoomIcon: string): TStringList;
begin
  Result := TStringList.Create;
  Result.Add('expire=' + Expire);
  if Sealed then Result.Add('sealed=1');
  if Avatar then Result.Add('avatar=1');
  if RoomIcon <> '' then Result.Add('room_icon=' + RoomIcon);
end;

function RequireJSON(Data: TJSONData; Kind: TJSONType): TJSONData;
begin
  if Data.JSONType <> Kind then
  begin
    Data.Free;
    raise Exception.Create('The server returned an unexpected JSON value.');
  end;
  Result := Data;
end;

function JSONObject(const Text: string): TJSONObject;
begin
  Result := TJSONObject(RequireJSON(GetJSON(Text), jtObject));
end;

{ ---- the worker ---- }

procedure TApiJob.Execute;
begin
end;

destructor TApiJob.Destroy;
begin
  if Data <> nil then
  begin
    if Data.Size > 0 then FillChar(Data.Memory^, Data.Size, 0);
    Data.Free;
  end;
  Fields.Free;
  Payload.Free;
  if Body <> '' then
  begin
    UniqueString(Body);
    FillChar(Body[1], Length(Body), 0);
  end;
  inherited Destroy;
end;

function TApiJob.JSON: TJSONData;
begin
  if Error <> '' then
    raise EApiFailure.CreateStatus(Error, Status, ErrorHandled);
  Result := GetJSON(Answer);
end;

function TApiJob.ObjectJSON: TJSONObject;
begin
  Result := TJSONObject(RequireJSON(JSON, jtObject));
end;

function TApiJob.ArrayJSON: TJSONArray;
begin
  Result := TJSONArray(RequireJSON(JSON, jtArray));
end;

procedure CheckOpeningAnswer(Job: TApiJob);
var
  Data, Value: TJSONData;
  Item: TJSONEnum;
  Path: string;
begin
  Path := Copy(Job.Path, Pos('/api/', Job.Path), MaxInt);
  if Pos('?', Path) > 0 then Path := Copy(Path, 1, Pos('?', Path) - 1);
  if (Job.Method <> 'GET') or not ((Path = '/api/me') or (Path = '/api/rooms') or (Path = '/api/messages') or (Path = '/api/key') or (Path = '/api/dm')) then Exit;
  Data := Job.JSON;
  try
    if (Path = '/api/rooms') or (Path = '/api/dm') then
    begin
      if not (Data is TJSONArray) then raise Exception.Create('Expected a message or room list.');
      Value := Data;
    end
    else
    begin
      if not (Data is TJSONObject) then raise Exception.Create('Expected an account or room object.');
      Value := nil;
      if Path = '/api/me' then
        if not (TJSONObject(Data).Find('name') is TJSONString) or (TJSONObject(Data).Get('name', '') = '') then
          raise Exception.Create('The account answer has no name.');
      if Path = '/api/messages' then
      begin
        Value := TJSONObject(Data).Find('messages');
        if not (Value is TJSONArray) then raise Exception.Create('The room answer has no messages.');
      end;
    end;
    if Value <> nil then
      for Item in TJSONArray(Value) do
      begin
        if not (Item.Value is TJSONObject) then raise Exception.Create('Expected a list of objects.');
        if Path = '/api/rooms' then
        begin
          if not (TJSONObject(Item.Value).Find('slug') is TJSONString) then raise Exception.Create('A room has no slug.');
        end
        else if not (TJSONObject(Item.Value).Find('id') is TJSONNumber) then
          raise Exception.Create('A message has no id.');
      end;
  finally
    Data.Free;
  end;
end;

type
  TApiWorker = class(TThread)
  private
    Lock: TCriticalSection;
    Pending, DoneJobs, AllJobs: TList;
    Wake: TEventObject;
    Busy: boolean;
    Dispatching: integer;
    Stopping: boolean;
    { on the UI thread: every finished job to its Done, then freed }
    procedure Dispatch; reintroduce;
    procedure Run(var Client: TFPHTTPClient; Job: TApiJob);
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Submit(Job: TApiJob);
    procedure DropPending;
    procedure ForgetReceiver(Receiver: TObject; CancelPending: boolean = False);
  end;

var
  Worker: TApiWorker = nil;
  { Requests to a server named outright (signing in, adding a server) run
    here, so one that never answers cannot hold up the account in use. }
  SideWorker: TApiWorker = nil;

constructor TApiWorker.Create;
begin
  inherited Create(True);
  Lock := TCriticalSection.Create;
  Pending := TList.Create;
  DoneJobs := TList.Create;
  AllJobs := TList.Create;
  Wake := TEventObject.Create(nil, False, False, '');
end;

destructor TApiWorker.Destroy;
var
  I: integer;
begin
  for I := 0 to Pending.Count - 1 do
    TObject(Pending[I]).Free;
  for I := 0 to DoneJobs.Count - 1 do
    TObject(DoneJobs[I]).Free;
  Pending.Free;
  DoneJobs.Free;
  AllJobs.Free;
  Wake.Free;
  Lock.Free;
  inherited Destroy;
end;

procedure TApiWorker.Submit(Job: TApiJob);
var
  I: integer;
begin
  Lock.Enter;
  try
    if Job.Key <> '' then
      for I := Pending.Count - 1 downto 0 do
        if TApiJob(Pending[I]).Key = Job.Key then
        begin
          AllJobs.Remove(Pending[I]);
          TApiJob(Pending[I]).Free;
          Pending.Delete(I);
        end;
    Pending.Add(Job);
    AllJobs.Add(Job);
  finally
    Lock.Leave;
  end;
  Wake.SetEvent;
end;

procedure TApiWorker.DropPending;
var
  I: integer;
begin
  Lock.Enter;
  try
    for I := 0 to Pending.Count - 1 do
    begin
      AllJobs.Remove(Pending[I]);
      TObject(Pending[I]).Free;
    end;
    Pending.Clear;
  finally
    Lock.Leave;
  end;
end;

procedure TApiWorker.ForgetReceiver(Receiver: TObject; CancelPending: boolean);
var
  I: integer;
  Job: TApiJob;
begin
  Lock.Enter;
  try
    if CancelPending then
      for I := Pending.Count - 1 downto 0 do
        if TMethod(TApiJob(Pending[I]).Done).Data = Pointer(Receiver) then
        begin
          AllJobs.Remove(Pending[I]);
          TObject(Pending[I]).Free;
          Pending.Delete(I);
        end;
    // Includes callbacks in Dispatch's local list during a modal dialog.
    for I := 0 to AllJobs.Count - 1 do
    begin
      Job := TApiJob(AllJobs[I]);
      if TMethod(Job.Done).Data = Pointer(Receiver) then
        Job.Done := nil;
    end;
  finally
    Lock.Leave;
  end;
end;

{ The worker's own client, never the UI thread's; made again after a
  failure, since a broken kept connection would fail the next one too. }
procedure TApiWorker.Run(var Client: TFPHTTPClient; Job: TApiJob);
var
  Answer, RequestData: TStringStream;
  Bytes: TBytesStream;
begin
  if Job.Method = 'WORK' then
  begin
    try
      Job.Execute;
    except
      on E: Exception do Job.Error := E.Message;
    end;
    Exit;
  end;
  if Client = nil then
  begin
    Client := TResponseClient.Create(nil);
    Client.KeepConnection := True;
    Client.ConnectTimeout := 10000;
    Client.IOTimeout := 30000;
  end;
  Client.RequestHeaders.Clear;
  if Job.Auth <> '' then
    Client.AddHeader('Authorization', 'Bearer ' + Job.Auth);
  RequestData := nil;
  if Job.Method = 'POST' then
  begin
    Client.AddHeader('Content-Type', 'application/x-www-form-urlencoded');
    RequestData := TStringStream.Create(Job.Body);
  end;
  Client.RequestBody := RequestData;
  Answer := TStringStream.Create('');
  Bytes := nil;
  try
    try
      if Job.Method = 'UPLOAD' then
        Client.StreamFormPost(Job.Path, Job.Fields, 'file', Job.FileName, Job.Data, Answer)
      else if Job.Method = 'BYTES' then
      begin
        Bytes := TBytesStream.Create;
        Client.HTTPMethod('GET', Job.Path, Bytes, []);
      end
      else
        Client.HTTPMethod(Job.Method, Job.Path, Answer, []);
      Job.Status := Client.ResponseStatusCode;
      Job.RetryAfter := Client.GetHeader(Client.ResponseHeaders, 'Retry-After');
      if (Job.Address <> '') and SameText(Copy(Job.Path, 1, Length(Job.Address) + 1), Job.Address + '/') then
        KeepRetry(Job.Status, Job.RetryAfter, Job.Epoch);
      Job.Answer := Answer.DataString;
      if Bytes <> nil then
      begin
        Job.Data := Bytes;
        Bytes := nil;
        if (Job.Status >= 400) and (Job.Data.Size > 0) then
          SetString(Job.Answer, pansichar(Job.Data.Memory), Job.Data.Size);
      end;
      if Job.Status >= 400 then
      begin
        Job.Error := Trim(Job.Answer);
        if Job.Error = '' then
          Job.Error := 'HTTP ' + IntToStr(Job.Status) + ' ' + Client.ResponseStatusText;
      end;
      if Job.Error = '' then
      try
        CheckOpeningAnswer(Job);
      except
        on E: Exception do Job.Error := 'The server returned an invalid answer: ' + E.Message;
      end;
    except
      on E: Exception do
      begin
        Job.Status := 0;
        Job.Error := E.Message;
        FreeAndNil(Client);
      end;
    end;
  finally
    Bytes.Free;
    Answer.Free;
    if Client <> nil then
      Client.RequestBody := nil;
    RequestData.Free;
  end;
end;

procedure TApiWorker.Execute;
var
  Client: TFPHTTPClient;
  Job: TApiJob;
begin
  Client := nil;
  try
    while not Terminated do
    begin
      Wake.WaitFor(INFINITE);
      repeat
        Job := nil;
        Lock.Enter;
      try
        if Pending.Count > 0 then
        begin
          Job := TApiJob(Pending[0]);
          Pending.Delete(0);
          Busy := True;
        end;
      finally
        Lock.Leave;
      end;
        if Job = nil then
          Break;
        while not Terminated and (Job.Epoch = ApiEpoch) and (ApiRetryDue > GetTickCount64) do
          Wake.WaitFor(100);
        if Terminated or (Job.Epoch <> ApiEpoch) then
        begin
          Lock.Enter;
          try
            Job.Done := nil;
            DoneJobs.Add(Job);
            Busy := False;
          finally
            Lock.Leave;
          end;
          Queue(@Dispatch);
          Continue;
        end;
        Run(Client, Job);
        Lock.Enter;
      try
        DoneJobs.Add(Job);
        Busy := False;
      finally
        Lock.Leave;
      end;
        Queue(@Dispatch);
      until Terminated;
    end;
  finally
    Client.Free;
  end;
end;

procedure TApiWorker.Dispatch;
var
  Jobs: TList;
  I: integer;
  Job: TApiJob;
begin
  Inc(Dispatching);
  Jobs := TList.Create;
  try
    Lock.Enter;
    try
      Jobs.Assign(DoneJobs);
      DoneJobs.Clear;
    finally
      Lock.Leave;
    end;
    for I := 0 to Jobs.Count - 1 do
    begin
      Job := TApiJob(Jobs[I]);
      try
        if (Job.Method <> 'WORK') and (Job.Epoch = ApiEpoch) then
          Job.ErrorHandled := ObserveStatus(SignInStatus(Job.Status, Job.Error), Job.Path, Job.Auth, Job.Epoch);
        if (Job.Method <> 'WORK') and (Job.Epoch = ApiEpoch) and Assigned(ApiOnResult) then
          ApiOnResult(Job);
        if (Job.Epoch = ApiEpoch) and Assigned(Job.Done) then
        try
          Job.Done(Job);
        except
          on E: Exception do
            if not ApiErrorHandled(E) and Assigned(ApiOnError) then
              ApiOnError(E.Message);
        end;
      finally
        Lock.Enter;
        try
          AllJobs.Remove(Job);
        finally
          Lock.Leave;
        end;
        Job.Free;
      end;
    end;
  finally
    Jobs.Free;
    Dec(Dispatching);
    if Stopping and (Dispatching = 0) then Free;
  end;
end;

procedure EnsureWorker;
begin
  if Worker = nil then
  begin
    Worker := TApiWorker.Create;
    Worker.Start;
  end;
end;

procedure EnsureSideWorker;
begin
  if SideWorker = nil then
  begin
    SideWorker := TApiWorker.Create;
    SideWorker.Start;
  end;
end;

{ A request addressed to a server other than the account's own goes to the
  side worker; everything else keeps its order on the main one. }
procedure SubmitJob(Job: TApiJob);
begin
  if (Job.Method <> 'WORK') and (Pos('://', Job.Path) > 0) and ((Job.Address = '') or not SameText(Copy(Job.Path, 1, Length(Job.Address) + 1), Job.Address + '/')) then
  begin
    EnsureSideWorker;
    SideWorker.Submit(Job);
  end
  else
  begin
    EnsureWorker;
    Worker.Submit(Job);
  end;
end;

procedure ApiWorkAsync(Job: TApiJob; Done: TApiDone; Tag: integer; const Key: string);
begin
  EnsureWorker;
  Job.Method := 'WORK';
  Job.Epoch := ApiEpoch;
  Job.Done := Done;
  Job.Tag := Tag;
  Job.Key := Key;
  SubmitJob(Job);
end;

function NewJob(const Method, Path, Body: string; Done: TApiDone; Tag: integer; const Key, Context: string): TApiJob;
var
  Job: TApiJob;
begin
  EnsureWorker;
  Job := TApiJob.Create;
  Job.Method := Method;
  Job.Address := Server;
  // Keep the address and credentials from the same account, before queuing.
  if Path.StartsWith('http://') or Path.StartsWith('https://') then
  begin
    Job.Path := Path;
    if (Server <> '') and not SignInNotified and SameText(Copy(Path, 1, Length(Server) + 1), Server + '/') then
      Job.Auth := Token;
  end
  else
  begin
    Job.Path := Server + Path;
    if not SignInNotified then
      Job.Auth := Token;
  end;
  Job.Body := Body;
  Job.Done := Done;
  Job.Tag := Tag;
  Job.Key := Key;
  Job.Context := Context;
  Job.Epoch := ApiEpoch;
  Result := Job;
end;

procedure ApiGetAsync(const Path: string; Done: TApiDone; Tag: integer; const Key: string);
var
  Job: TApiJob;
begin
  Job := NewJob('GET', Path, '', Done, Tag, Key, '');
  SubmitJob(Job);
end;

procedure ApiPostAsync(const Path: string; const Fields: array of string; Done: TApiDone; Tag: integer; const Key, Context: string);
var
  Job: TApiJob;
begin
  Job := NewJob('POST', Path, Query(Fields), Done, Tag, Key, Context);
  SubmitJob(Job);
end;

procedure ApiGetTargetAsync(const Target: TApiTarget; const Path: string; Done: TApiDone);
var
  Job: TApiJob;
begin
  Job := NewJob('GET', Target.Address + Path, '', Done, 0, '', '');
  Job.Path := Target.Address + Path;
  Job.Auth := Target.Auth;
  Job.Epoch := Target.Epoch;
  SubmitJob(Job);
end;

procedure ApiPostTargetAsync(const Target: TApiTarget; const Path: string; const Fields: array of string; Done: TApiDone);
var
  Job: TApiJob;
begin
  Job := NewJob('POST', Target.Address + Path, Query(Fields), Done, 0, '', '');
  Job.Path := Target.Address + Path;
  Job.Auth := Target.Auth;
  Job.Epoch := Target.Epoch;
  SubmitJob(Job);
end;

procedure ApiUploadAsync(const FileName: string; Data: TStream; Sealed, Avatar: boolean; const Expire, RoomIcon: string; Done: TApiDone; Tag: integer; const Context: string);
var
  Job: TApiJob;
begin
  Job := NewJob('UPLOAD', '/api/upload', '', Done, Tag, '', Context);
  try
    Job.FileName := FileName;
    Job.Fields := UploadFields(Sealed, Avatar, Expire, RoomIcon);
    Job.Data := TBytesStream.Create;
    Job.Data.CopyFrom(Data, Data.Size - Data.Position);
    Job.Data.Position := 0;
  except
    Job.Free;
    raise;
  end;
  SubmitJob(Job);
end;

procedure ApiBytesAsync(const Path: string; Done: TApiDone; Tag: integer; const Context: string; Payload: TObject);
var
  Job: TApiJob;
begin
  Job := NewJob('BYTES', Path, '', Done, Tag, '', Context);
  Job.Payload := Payload;
  SubmitJob(Job);
end;

procedure ApiForgetAll;
var
  I: integer;
begin
  Inc(ApiEpoch);
  FetchLock.Enter;
  try
    for I := 0 to FetchPending.Count - 1 do TObject(FetchPending[I]).Free;
    FetchPending.Clear;
  finally
    FetchLock.Leave;
  end;
  if Worker <> nil then
    Worker.DropPending;
  if SideWorker <> nil then
    SideWorker.DropPending;
end;

procedure ApiForgetReceiver(Receiver: TObject);
var
  I: integer;
  R: TFetchRequest;
begin
  FetchLock.Enter;
  try
    for I := FetchPending.Count - 1 downto 0 do
      if TMethod(TFetchRequest(FetchPending[I]).Done).Data = Pointer(Receiver) then
      begin
        TObject(FetchPending[I]).Free;
        FetchPending.Delete(I);
      end;
    for I := 0 to Fetchers.Count - 1 do
    begin
      R := TFetchThread(Fetchers[I]).Request;
      if (R <> nil) and (TMethod(R.Done).Data = Pointer(Receiver)) then R.Done := nil;
    end;
  finally
    FetchLock.Leave;
  end;
  if Worker <> nil then
    Worker.ForgetReceiver(Receiver);
  if SideWorker <> nil then
    SideWorker.ForgetReceiver(Receiver);
end;

procedure ApiCancelReceiver(Receiver: TObject);
begin
  if Worker <> nil then Worker.ForgetReceiver(Receiver, True);
  if SideWorker <> nil then SideWorker.ForgetReceiver(Receiver, True);
  ApiForgetReceiver(Receiver);
end;

procedure StopOne(var Which: TApiWorker);
var
  W: TApiWorker;
begin
  W := Which;
  if W = nil then
    Exit;
  Which := nil;
  W.DropPending;
  W.Terminate;
  W.Wake.SetEvent;
  W.WaitFor;
  TThread.RemoveQueuedEvents(W);
  if W.Dispatching = 0 then W.Free
  else
    W.Stopping := True;
end;

{ Join before the forms and network units are finalized. }
procedure ApiStopWorker;
var
  I: integer;
begin
  ApiForgetAll;
  for I := 0 to Fetchers.Count - 1 do TFetchThread(Fetchers[I]).Terminate;
  for I := 0 to Fetchers.Count - 1 do
  begin
    TFetchThread(Fetchers[I]).WaitFor;
    TFetchThread(Fetchers[I]).Free;
  end;
  Fetchers.Clear;
  StopOne(Worker);
  StopOne(SideWorker);
end;

initialization
  Fetchers := TList.Create;
  FetchPending := TList.Create;
  FetchLock := TCriticalSection.Create;
  FetchWake := TEventObject.Create(nil, False, False, '');
  RestoreLock := TCriticalSection.Create;
  TlsLibFclNetTrustDefaults.UseSystemTrust := True;
  TSSLSocketHandler.SetDefaultHandlerClass(TCheckedTlsHandler);

finalization
  ApiStopWorker;
  Fetchers.Free;
  FetchPending.Free;
  FetchWake.Free;
  FetchLock.Free;
  RestoreLock.Free;
end.
