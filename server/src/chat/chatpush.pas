unit ChatPush;

{ Empty Web Push notifications signed with VAPID (RFC 8292), for mentions
  and private messages when no page is open. The service worker reads
  /api/notes, so message content never passes through the push service. The
  site's key is stored in settings on first use. }

{$mode objfpc}{$H+}

interface

{ Pushes to the member's devices, unless a page of theirs is open and they
  are not away, or they had a push in the last minute.  Mail may follow later
  (ChatMissed). }
procedure NotifyMember(UserId: integer);

implementation

uses
  Classes, SysUtils, Variants, DateUtils, base64, fpjson, httpdefs, httproute, fphttpclient,
  ClpBigInteger, ClpECParameters, ClpIECParameters, ClpIECCommon, ClpISigner, ClpSignerUtilities,
  ClpISecureRandom, ClpSecureRandom, ClpGeneratorUtilities, ClpIAsymmetricCipherKeyPair,
  ClpIAsymmetricCipherKeyPairGenerator,
  SiteDb, SiteSql, SiteUsers, SiteBell, SiteMarkup, ChatMissed, ChatPrivate, SiteTls, SiteNotices, SiteGuard;

type
  { One round of pushes, sent off the request's thread. }
  TPushJob = class(TThread)
  private
    Endpoints: TStringList;
  protected
    procedure Execute; override;
  public
    constructor Create(AEndpoints: TStringList);
  end;

function Base64Url(const Bytes: TBytes): string;
var
  Raw: string;
begin
  SetString(Raw, PChar(@Bytes[0]), Length(Bytes));
  Result := StringReplace(StringReplace(EncodeStringBase64(Raw), '+', '-', [rfReplaceAll]), '/', '_', [rfReplaceAll]);
  Result := Result.TrimRight(['=']);
end;

function Domain: IECDomainParameters;
begin
  Result := TECDomainParameters.LookupName('secp256r1');
end;

{ The site's private key, made the first time it is needed. }
function PrivateKey: TBigInteger;
var
  Pair: IAsymmetricCipherKeyPair;
  Gen: IAsymmetricCipherKeyPairGenerator;
  Hex: string;
begin
  Hex := Setting('vapid_key', '');
  if Hex = '' then
  begin
    Gen := TGeneratorUtilities.GetKeyPairGenerator('ECDSA');
    Gen.Init(TECKeyGenerationParameters.Create(Domain, TSecureRandom.Create() as ISecureRandom) as IECKeyGenerationParameters);
    Pair := Gen.GenerateKeyPair();
    Hex := (Pair.Private as IECPrivateKeyParameters).D.ToString(16);
    SaveSetting('vapid_key', Hex);
  end;
  Result := TBigInteger.Create(Hex, 16);
end;

{ The public key as browsers want it: the uncompressed point, base64url. }
function PublicKey: string;
begin
  Result := Base64Url(Domain.G.Multiply(PrivateKey).Normalize.GetEncoded(False));
end;

{ The Authorization header for one push service (RFC 8292). }
function VapidHeader(const Endpoint: string): string;
var
  Origin, Token: string;
  Signer: ISigner;
  Data: TBytes;
begin
  Origin := Copy(Endpoint, 1, Pos('/', Copy(Endpoint, 9, MaxInt)) + 7);
  Token := Base64Url(TEncoding.UTF8.GetBytes('{"typ":"JWT","alg":"ES256"}')) + '.' + Base64Url(TEncoding.UTF8.GetBytes(
    unicodestring(Format('{"aud":"%s","exp":%d,"sub":"mailto:%s"}', [Origin, DateTimeToUnix(NowUTC) + 12 * 3600, Config.ReadString('mail', 'from', 'nobody@example.com')]))));
  // ES256 wants r and s side by side, which is what PLAIN-ECDSA gives.
  Signer := TSignerUtilities.GetSigner('SHA256withPLAIN-ECDSA');
  Signer.Init(True, TECPrivateKeyParameters.Create(PrivateKey, Domain) as IECPrivateKeyParameters);
  Data := TEncoding.UTF8.GetBytes(unicodestring(Token));
  Signer.BlockUpdate(Data, 0, Length(Data));
  Result := 'vapid t=' + Token + '.' + Base64Url(Signer.GenerateSignature()) + ', k=' + PublicKey;
end;

constructor TPushJob.Create(AEndpoints: TStringList);
begin
  Endpoints := AEndpoints;
  FreeOnTerminate := True;
  inherited Create(False);
end;

procedure TPushJob.Execute;
var
  Endpoint: string;
  Client: TFPHTTPClient;
  Reply: TStringStream;
begin
  Reply := TStringStream.Create('');
  try
    try
      CheckConnection;
      for Endpoint in Endpoints do
      begin
        Client := TFPHTTPClient.Create(nil);
        try
          Client.ConnectTimeout := 5000;
          Client.IOTimeout := 10000;
          Client.AddHeader('Authorization', VapidHeader(Endpoint));
          Client.AddHeader('TTL', '3600');
          Client.AddHeader('Urgency', 'high');
          Client.RequestBody := TStringStream.Create('');
          try
            Reply.Size := 0;
            Client.HTTPMethod('POST', Endpoint, Reply, []);
            // Gone or unknown: the browser dropped it; forget it.
            if (Client.ResponseStatusCode = 404) or (Client.ResponseStatusCode = 410) then
              Exec('DELETE FROM push_subs WHERE endpoint = :e', [Endpoint])
            else if Client.ResponseStatusCode >= 300 then
              Log('Push ' + IntToStr(Client.ResponseStatusCode) + ' from ' + Copy(Endpoint, 1, 60) + ': ' + Copy(Reply.DataString, 1, 200));
          except
            on E: Exception do
              Log('Push to ' + Copy(Endpoint, 1, 60) + ': ' + E.Message);
          end;
        finally
          Client.RequestBody.Free;
          Client.Free;
        end;
      end;
    finally
      Reply.Free;
      Endpoints.Free;
      DoneConnection;
    end;
  except
    on E: Exception do
      Log('Push: ' + E.Message);
  end;
end;

procedure NotifyMember(UserId: integer);
var
  Endpoints: TStringList;
begin
  if UserId = 0 then
    Exit;
  MarkMissed(UserId);
  // An open page or program shows it, but only to someone who is there: a
  // member who went idle or set themselves away gets the push as well.
  if UserIsLive(UserId) and (VarToStr(Value('SELECT away FROM users WHERE id = :u', [UserId])) = '') then
    Exit;
  Endpoints := TStringList.Create;
  with Query('SELECT endpoint FROM push_subs WHERE user_id = :u AND' + ' (last_push IS NULL OR last_push < ' + SqlAgo('1', suMinute) + ')', [UserId]) do
  try
    while not EOF do
    begin
      Endpoints.Add(Fields[0].AsString);
      Next;
    end;
  finally
    Free;
  end;
  if Endpoints.Count = 0 then
  begin
    Endpoints.Free;
    Exit;
  end;
  Exec('UPDATE push_subs SET last_push = NOW() WHERE user_id = :u', [UserId]);
  // a CGI program has no threads (no cthreads in its build): no pushes there
  {$ifdef CGI}
  Endpoints.Free;
  {$else}
  TPushJob.Create(Endpoints);
  {$endif}
end;

{ GET /api/push/key  the site's public key, for subscribing }
{ A closed account's devices are told nothing more. }
procedure ForgetDevices(UserId: integer);
begin
  Exec('DELETE FROM push_subs WHERE user_id = :u', [UserId]);
end;

procedure ShowKey(ARequest: TRequest; AResponse: TResponse);
begin
  CheckConnection;
  SendJSON(AResponse, TJSONObject.Create(['key', PublicKey]));
end;

{ The browsers' push services; the server posts nowhere else. }
function PushService(const Endpoint: string): boolean;
var
  Host: string;
  C: char;
begin
  // the host as the program that connects will read it: letters, digits,
  // dots and hyphens only, so nothing after a # or an @ can stand in for it
  Host := LowerCase(Copy(Endpoint, 9, Pos('/', Copy(Endpoint, 9, MaxInt)) - 1));
  for C in Host do
    if not (C in ['a'..'z', '0'..'9', '.', '-']) then
      Exit(False);
  Result := Endpoint.StartsWith('https://') and ((Host = 'fcm.googleapis.com') or (Host = 'updates.push.services.mozilla.com') or
    Host.EndsWith('.push.apple.com') or Host.EndsWith('.notify.windows.com'));
end;

{ POST /api/push  endpoint, and off=1 to stop }
procedure Subscribe(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Endpoint: string;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  Endpoint := ARequest.ContentFields.Values['endpoint'];
  if FromAnotherSite(ARequest) then
    SendText(AResponse, 403, 'Send this from a page of this site.')
  else if Me.Id = 0 then
    SendText(AResponse, 403, 'Sign in first.')
  else if not PushService(Endpoint) or (Length(Endpoint) > 500) then
    SendText(AResponse, 400, 'That is not a push address.')
  // a member has a handful of devices, not hundreds of addresses to be written to
  else if (ARequest.ContentFields.Values['off'] <> '1') and (IntValue('SELECT COUNT(*) FROM push_subs WHERE user_id = :u AND endpoint <> :e', [Me.Id, Endpoint]) >= 20) then
    SendText(AResponse, 409, 'This account has notifications on twenty devices already. Turn one off first.')
  else
  begin
    // The address is the device's own secret, which the site never shows: who
    // sends it may stop its notifications or take them over, as the next
    // member on a shared browser does.
    if ARequest.ContentFields.Values['off'] = '1' then
      Exec('DELETE FROM push_subs WHERE endpoint = :e', [Endpoint])
    else
      Exec('INSERT INTO push_subs (endpoint, user_id) VALUES (:e, :u)' + SqlOnConflict('endpoint', 'user_id = :u2'),
        [Endpoint, Me.Id, Me.Id]);
    SendText(AResponse, 200, 'ok');
  end;
end;

{ GET /api/notes  what the service worker shows: unread mentions and private
  messages, newest first; a tag each, so a newer push replaces the older.
  A message's words are given on one line without their Markdown, so an
  action reads Ann waves. }
procedure ShowNotes(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  List: TJSONArray;
  Text: string;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  // the service worker takes this as the word to stop this device's pushes
  if Me.Id = 0 then
  begin
    SendText(AResponse, 401, 'Sign in first.');
    Exit;
  end;
  List := TJSONArray.Create;
  with Query('SELECT r.slug, COALESCE(u.name, m.author), m.body, m.id FROM mentions n' + ' JOIN messages m ON m.id = n.message_id JOIN rooms r ON r.id = m.room_id' +
      ' LEFT JOIN users u ON u.id = m.user_id LEFT JOIN follows f ON f.room_id = r.id AND f.user_id = n.user_id' +
      ' WHERE n.user_id = :u AND m.deleted = 0 AND m.id > COALESCE(f.last_read_id, 0)' +
      ' AND (r.private = 0 OR (f.user_id IS NOT NULL AND :b = 0)) AND COALESCE(f.notify, 0) < 2' + ' ORDER BY n.message_id DESC LIMIT 3', [Me.Id, Ord(Me.Banned)]) do
  try
    while not EOF do
    begin
      List.Add(TJSONObject.Create(['title', Fields[1].AsString + ' in #' + Fields[0].AsString, 'body', PlainLine(Fields[2].AsString),
        'tag', 'room-' + Fields[0].AsString, 'url', '/m/' + Fields[3].AsString]));
      Next;
    end;
  finally
    Free;
  end;
  with Query('SELECT u.name, d.iv, d.data FROM dm_peers p JOIN users u ON u.id = p.other_id' +
      ' JOIN dms d ON d.id = p.last_id WHERE p.user_id = :u AND p.last_id > p.last_read_id' + ' AND d.from_id = p.other_id ORDER BY p.last_id DESC LIMIT 3', [Me.Id]) do
  try
    while not EOF do
    begin
      Text := 'A locked message: open it to read.';
      if Fields[1].AsString = '' then
      begin
        Text := DmLine(Fields[0].AsString, Fields[2].AsString);
        if Text = '' then
          Text := 'A file or a beam.';
      end;
      List.Add(TJSONObject.Create(['title', Fields[0].AsString, 'body', Text, 'tag', 'dm-' + Fields[0].AsString, 'url', '/dm/' + Fields[0].AsString]));
      Next;
    end;
  finally
    Free;
  end;
  // what the site itself has to tell the member (SiteNotices)
  with Query('SELECT id, body, link FROM notices WHERE user_id = :u AND seen = 0 ORDER BY id DESC LIMIT 3', [Me.Id]) do
  try
    while not EOF do
    begin
      List.Add(TJSONObject.Create(['title', Setting('name', 'Exedra'), 'body', NoticeCut(Fields[1].AsString, 160), 'tag', 'notice-' +
        Fields[0].AsString, 'url', Fields[2].AsString]));
      Next;
    end;
  finally
    Free;
  end;
  SendJSON(AResponse, List);
end;

initialization
  // a notice from the site reaches the member as a mention does
  OnNoticeSent := @NotifyMember;
  RegisterCloseMemberHook(@ForgetDevices);
  RegisterTable('CREATE TABLE IF NOT EXISTS push_subs (' + ' endpoint VARCHAR(500) NOT NULL PRIMARY KEY, user_id INT NOT NULL,' +
    ' created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, last_push DATETIME NULL, INDEX (user_id))');
  HTTPRouter.RegisterRoute('/api/push/key', rmGet, @ShowKey);
  HTTPRouter.RegisterRoute('/api/push', rmPost, @Subscribe);
  RegisterRequestLimit('push', 'Notification sign-ups', 30, 30, 1);
  LimitRoute('push', '/api/push', 'POST');
  HTTPRouter.RegisterRoute('/api/notes', rmGet, @ShowNotes);
end.
