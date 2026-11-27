unit SiteLogins;

{ OAuth sign-in with GitHub, GitLab, Codeberg, Google and Microsoft. A
  signed-in member links the provider; a new account has no password.
  Desktop sign-in requires browser approval and a one-time grant tied to the
  app's random state. Requests and the token exchange are in docs/API.md. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

{ The providers set up in the config file, in the order to show them. }
function Providers: TStringArray;
function ProviderTitle(const Name: string): string;
{ A login from elsewhere made into a member name that is free here. }
function FreeName(const Login, Fallback: string): string;
{ Links a provider's account to a member (nothing when it is linked already). }
procedure AddLogin(const Provider, ProviderId, Login: string; UserId: integer);
{ The account's name as the provider gave it at the last sign-in: a renamed
  account keeps its number and gets its new name. }
procedure RefreshLogin(const Provider, ProviderId, Login: string);
{ A one-time code a waiting program trades for Token, good for two minutes
  and only with the State that program started its sign-in with. }
function NewGrant(const Token, State: string): string;
{ The token behind a grant, once; '' when there is none, it is used, or
  State is not the one it was made with.  A wrong State uses the grant up
  all the same. }
function TakeGrant(const Code, State: string): string;
{ A one-time code for the member a waiting program would sign in as, kept
  while the member is asked, ten minutes at most; and the member behind it,
  once (0 when there is none or it was used). }
function NewAppAsk(UserId: integer): string;
function TakeAppAsk(const Code: string): integer;

implementation

uses
  Classes, StrUtils, Variants, SyncObjs, fpjson, jsonparser, httpdefs, httproute, fphttpclient,
  SiteDb, SiteSql, SiteUsers, SiteGuard, SiteTls, SiteSecurity, SiteWords, WebPages;

type
  TProvider = record
    Name, Title, AuthorizeUrl, TokenUrl, UserUrl, Scope, IdField, LoginField: string;
  end;

const
  Names: array[0..4] of string = ('github', 'gitlab', 'codeberg', 'google', 'microsoft');

{ id, secret, on or url for one provider. }
function ProviderValue(const Name, Key: string): string;
begin
  Result := Setting(Name + '_' + Key, '');
end;

function Provider(const Name: string): TProvider;
var
  GitLab, Forgejo: string;
begin
  Result.Name := Name;
  Result.Title := '';
  case Name of
    'github':
    begin
      Result.Title := 'GitHub';
      Result.AuthorizeUrl := 'https://github.com/login/oauth/authorize';
      Result.TokenUrl := 'https://github.com/login/oauth/access_token';
      Result.UserUrl := 'https://api.github.com/user';
      Result.Scope := 'read:user';
      Result.IdField := 'id';
      Result.LoginField := 'login';
    end;
    'gitlab':
    begin
      GitLab := ExcludeTrailingPathDelimiter(Setting('gitlab_url', 'https://gitlab.com'));
      Result.Title := 'GitLab';
      Result.AuthorizeUrl := GitLab + '/oauth/authorize';
      Result.TokenUrl := GitLab + '/oauth/token';
      Result.UserUrl := GitLab + '/api/v4/user';
      Result.Scope := 'read_user';
      Result.IdField := 'id';
      Result.LoginField := 'username';
    end;
    // Codeberg runs Forgejo; codeberg_url points it at another Forgejo or a Gitea.
    'codeberg':
    begin
      Forgejo := ExcludeTrailingPathDelimiter(Setting('codeberg_url', 'https://codeberg.org'));
      Result.Title := 'Codeberg';
      Result.AuthorizeUrl := Forgejo + '/login/oauth/authorize';
      Result.TokenUrl := Forgejo + '/login/oauth/access_token';
      Result.UserUrl := Forgejo + '/api/v1/user';
      Result.Scope := 'read:user';
      Result.IdField := 'id';
      Result.LoginField := 'login';
    end;
    'google':
    begin
      Result.Title := 'Google';
      Result.AuthorizeUrl := 'https://accounts.google.com/o/oauth2/v2/auth';
      Result.TokenUrl := 'https://oauth2.googleapis.com/token';
      Result.UserUrl := 'https://openidconnect.googleapis.com/v1/userinfo';
      Result.Scope := 'openid profile';
      Result.IdField := 'sub';
      Result.LoginField := 'name';
    end;
    // Personal and work accounts alike ("common").
    'microsoft':
    begin
      Result.Title := 'Microsoft';
      Result.AuthorizeUrl := 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize';
      Result.TokenUrl := 'https://login.microsoftonline.com/common/oauth2/v2.0/token';
      Result.UserUrl := 'https://graph.microsoft.com/oidc/userinfo';
      Result.Scope := 'openid profile';
      Result.IdField := 'sub';
      Result.LoginField := 'name';
    end;
  end;
end;

{ Microsoft waits until an admin switches it on. }
function DefaultOn(const Name: string): string;
begin
  Result := '1';
  if Name = 'microsoft' then
    Result := '0';
end;

function Ready(const Name: string): boolean;
begin
  Result := (Provider(Name).Title <> '') and (Setting(Name + '_on', DefaultOn(Name)) = '1') and (ProviderValue(Name, 'id') <> '') and (ProviderValue(Name, 'secret') <> '');
end;

function Providers: TStringArray;
var
  Name: string;
begin
  Result := [];
  for Name in Names do
    if Ready(Name) then
      Result := Concat(Result, [Name]);
end;

function ProviderTitle(const Name: string): string;
begin
  Result := Provider(Name).Title;
end;

function ReturnUrl(ARequest: TRequest; const Name: string): string;
begin
  Result := Setting('url', '');
  if Result = '' then
    if Setting('https', '0') = '1' then
      Result := 'https://' + ARequest.Host
    else
      Result := 'http://' + ARequest.Host;
  Result := ExcludeTrailingPathDelimiter(Result) + '/_oauth/' + Name;
end;

{ ---- grants for programs on the member's computer ---- }

var
  GrantLock: TCriticalSection;
  { code=expiry|kind|what, each good once: a grant (the token and the
    program's own state, two minutes) or an ask (the member a program
    would sign in as, while they are asked) }
  Grants: TStringList;

procedure PruneGrants;
var
  I: integer;
begin
  for I := Grants.Count - 1 downto 0 do
    if StrToFloatDef(Grants.ValueFromIndex[I].Split(['|'])[0], 0) < Now then
      Grants.Delete(I);
end;

function Hold(const Kind, What: string; Minutes: integer): string;
begin
  Result := RandomHex(16);
  GrantLock.Enter;
  try
    PruneGrants;
    Grants.Values[Result] := FloatToStr(Now + Minutes / MinsPerDay) + '|' + Kind + '|' + What;
  finally
    GrantLock.Leave;
  end;
end;

{ What was held under Code, which is used up by this whatever its kind;
  '' when there is nothing of this Kind. }
function TakeHeld(const Kind, Code: string): string;
var
  I: integer;
  Held: string;
begin
  Result := '';
  GrantLock.Enter;
  try
    PruneGrants;
    I := Grants.IndexOfName(Code);
    if I >= 0 then
    begin
      Held := Grants.ValueFromIndex[I];
      // past the expiry
      Held := Copy(Held, Pos('|', Held) + 1, MaxInt);
      if Held.StartsWith(Kind + '|') then
        Result := Copy(Held, Length(Kind) + 2, MaxInt);
      Grants.Delete(I);
    end;
  finally
    GrantLock.Leave;
  end;
end;

function NewGrant(const Token, State: string): string;
begin
  Result := Hold('grant', Token + '|' + State, 2);
end;

function TakeGrant(const Code, State: string): string;
var
  Parts: TStringArray;
begin
  Result := '';
  Parts := TakeHeld('grant', Code).Split(['|']);
  if (Length(Parts) = 2) and (Parts[1] = State) then
    Result := Parts[0];
end;

function NewAppAsk(UserId: integer): string;
begin
  Result := Hold('ask', IntToStr(UserId), 10);
end;

function TakeAppAsk(const Code: string): integer;
begin
  Result := StrToIntDef(TakeHeld('ask', Code), 0);
end;

{ POST /api/grant  code, state; answers token, once }
procedure GiveGrant(ARequest: TRequest; AResponse: TResponse);
var
  Token: string;
begin
  if not TokenTry(ARequest, AResponse) then
    Exit;
  Token := TakeGrant(ARequest.ContentFields.Values['code'], ARequest.ContentFields.Values['state']);
  if Token = '' then
  begin
    SendText(AResponse, 404, 'That sign-in is not waiting here, or was taken already.');
  end
  else
    SendJSON(AResponse, TJSONObject.Create(['token', Token]));
end;

{ GET /api/providers  the sign-ins offered here, for a program to show }
procedure ShowProviders(ARequest: TRequest; AResponse: TResponse);
var
  List: TJSONArray;
  Name: string;
begin
  List := TJSONArray.Create;
  for Name in Providers do
    List.Add(TJSONObject.Create(['name', Name, 'title', ProviderTitle(Name)]));
  SendJSON(AResponse, List);
end;

{ The cookie GoSignIn keeps for a program waiting on the member's computer:
  its name, the port it listens on and the state it made up for this sign-in. }
procedure AppWaiting(ARequest: TRequest; out Name, Port, State: string);
var
  Parts: TStringArray;
begin
  Name := '';
  Port := '';
  State := '';
  Parts := ARequest.CookieFields.Values['oauthapp'].Split(['|']);
  if (Length(Parts) = 3) and (StrToIntDef(Parts[1], 0) > 0) then
  begin
    Name := Parts[0];
    Port := Parts[1];
    State := Parts[2];
  end;
end;

{ Where that program is told the outcome, with its state so it knows the
  answer is to the sign-in it started; '' for a browser sign-in.  Outcome is
  'failed=1', or 'grant=' and a grant. }
function AppReturn(ARequest: TRequest; const Outcome: string): string;
var
  Name, Port, State: string;
begin
  AppWaiting(ARequest, Name, Port, State);
  if Port = '' then
    Result := ''
  else
    Result := 'http://127.0.0.1:' + Port + '/?' + Outcome + '&state=' + State;
end;

{ A cookie for the ten minutes a sign-in at a provider may take. }
procedure KeepCookie(AResponse: TResponse; const CookieName, CookieValue: string);
begin
  with AResponse.Cookies.Add do
  begin
    Name := CookieName;
    Value := CookieValue;
    Path := '/';
    Expires := NowUTC + 10 / MinsPerDay;
    HttpOnly := True;
    SameSite := ssLax;
    Secure := SecureCookies;
  end;
end;

{ The provider has said who this is; the waiting program gets nothing yet.
  A page asks the member whether it may sign in as them, and POST
  /signin-app takes the answer.  Another site can start a sign-in for a
  program of its own choosing in the member's browser, but cannot press
  Allow there. }
procedure AskForApp(ARequest: TRequest; AResponse: TResponse; UserId: integer);
var
  Name, Port, State: string;
begin
  AppWaiting(ARequest, Name, Port, State);
  KeepCookie(AResponse, 'oauthask', NewAppAsk(UserId));
  // the name is the program's own word, so the page also shows the port the answer goes to
  // the answer's form is sent on to the program's port, which the page's policy has to allow
  AResponse.SetCustomHeader('Content-Security-Policy', SecurityPolicy(ARequest.Host, 'http://127.0.0.1:' + Port));
  SendPage(AResponse, PartPage(ARequest, CurrentMember(ARequest), Say('Sign in a program'), '<section class="signin"><h1>' +
    E(Say('Sign in a program')) + '</h1><p>' + Format(E(Say('The program %s on this computer asks to sign in as %s.')),
    ['<b>' + E(Name) + '</b> (127.0.0.1:' + E(Port) + ')', '<b>' + E(MemberById(UserId).Name) + '</b>']) + '</p><p>' +
    E(Say('Allow it only if you started this from that program just now. It will be able to do here what you can.')) +
    '</p><form class="appask" method="post" action="/signin-app"><button class="primary" name="answer" value="allow">' + E(Say('Allow')) +
    '</button> <button name="answer" value="cancel">' + E(Say('Cancel')) + '</button></form></section>'));
end;

{ POST /signin-app  answer (allow, or anything else for no): the member's
  word on the program AskForApp asked about.  The program is told either
  way, so it stops waiting. }
procedure AnswerForApp(ARequest: TRequest; AResponse: TResponse);
var
  Name, Port, State: string;
  UserId: integer;
begin
  CheckConnection;
  if FromAnotherSite(ARequest) then
  begin
    SendText(AResponse, 403, Say('Press it on this site.'));
    Exit;
  end;
  AppWaiting(ARequest, Name, Port, State);
  UserId := TakeAppAsk(ARequest.CookieFields.Values['oauthask']);
  if (Port = '') or (UserId = 0) then
    SendText(AResponse, 410, Say('That sign-in is not waiting here any more. Start it again from the program.'))
  else if ARequest.ContentFields.Values['answer'] = 'allow' then
    SeeOther(AResponse, AppReturn(ARequest, 'grant=' + NewGrant(NewSession(UserId, 'app', Name, AppSessionDays), State)))
  else
    SeeOther(AResponse, AppReturn(ARequest, 'failed=1'));
end;

{ Letters and digits only, 16 to 64 of them: what a program may send as its state. }
function StateOK(const State: string): boolean;
var
  C: char;
begin
  Result := (Length(State) >= 16) and (Length(State) <= 64);
  for C in State do
    if not (C in ['a'..'z', 'A'..'Z', '0'..'9']) then
      Result := False;
end;

{ GET /signin-with/:provider  off to the provider, with a random state that must
  come back in the cookie it is also kept in.  With app and port, a program
  on this computer is waiting for the outcome (see the unit's note). }
procedure GoSignIn(ARequest: TRequest; AResponse: TResponse);
var
  P: TProvider;
  State, App: string;
begin
  P := Provider(ARequest.RouteParams['provider']);
  if not Ready(P.Name) then
  begin
    SendText(AResponse, 404, 'No sign-in by that name here.');
    Exit;
  end;
  State := RandomHex(16);
  KeepCookie(AResponse, 'oauth', State);
  // the page to come back to once signed in, a page on this site only
  KeepCookie(AResponse, 'oauthback', HTTPEncode(LocalReturn(ARequest.QueryFields.Values['return'])));
  App := '';
  // a program that sends no state of its own is not sent the outcome
  if (ARequest.QueryFields.Values['app'] <> '') and (StrToIntDef(ARequest.QueryFields.Values['port'], 0) > 0) and StateOK(ARequest.QueryFields.Values['state']) then
    App := StringReplace(Copy(ARequest.QueryFields.Values['app'], 1, 60), '|', ' ', [rfReplaceAll]) + '|' +
      IntToStr(StrToIntDef(ARequest.QueryFields.Values['port'], 0)) + '|' + ARequest.QueryFields.Values['state'];
  KeepCookie(AResponse, 'oauthapp', App);
  AResponse.SendRedirect(P.AuthorizeUrl + '?response_type=code&client_id=' + HTTPEncode(ProviderValue(P.Name, 'id')) + '&redirect_uri=' +
    HTTPEncode(ReturnUrl(ARequest, P.Name)) + '&scope=' + HTTPEncode(P.Scope) + '&state=' + State);
end;

{ Trades the code for a token, and the token for who it belongs to.  False
  when anything on the way fails; the log says what. }
function WhoIsIt(ARequest: TRequest; const P: TProvider; out Id, Login: string): boolean;
var
  Client: TFPHTTPClient;
  Form: TStringList;
  Answer: TJSONData;
  Token: string;
begin
  Result := False;
  Id := '';
  Login := '';
  Client := TFPHTTPClient.Create(nil);
  Form := TStringList.Create;
  Answer := nil;
  try
    try
      Client.ConnectTimeout := 5000;
      Client.IOTimeout := 8000;
      Client.AddHeader('Accept', 'application/json');
      Client.AddHeader('User-Agent', Setting('name', 'Exedra') + ' chat server');
      Form.AddPair('client_id', ProviderValue(P.Name, 'id'));
      Form.AddPair('client_secret', ProviderValue(P.Name, 'secret'));
      Form.AddPair('code', ARequest.QueryFields.Values['code']);
      Form.AddPair('redirect_uri', ReturnUrl(ARequest, P.Name));
      Form.AddPair('grant_type', 'authorization_code');
      Answer := GetJSON(Client.FormPost(P.TokenUrl, Form));
      Token := TJSONObject(Answer).Get('access_token', '');
      FreeAndNil(Answer);
      if Token = '' then
        raise Exception.Create('no access token');
      Client.AddHeader('Authorization', 'Bearer ' + Token);
      Answer := GetJSON(Client.Get(P.UserUrl));
      Id := TJSONObject(Answer).Get(P.IdField, '');
      if Id = '' then
        Id := IntToStr(TJSONObject(Answer).Get(P.IdField, int64(0)));
      Login := TJSONObject(Answer).Get(P.LoginField, '');
      Result := (Id <> '') and (Id <> '0');
    except
      on E: Exception do
        Log('Sign-in with ' + P.Title + ': ' + E.Message);
    end;
  finally
    Answer.Free;
    Form.Free;
    Client.Free;
  end;
end;

function FreeName(const Login, Fallback: string): string;
var
  Base: string;
  C: char;
  N: integer;
begin
  Base := '';
  for C in Login do
    if C in ['A'..'Z', 'a'..'z', '0'..'9', '_', '-', '.'] then
      Base := Base + C;
  Base := Copy(Base, 1, 20);
  while Pos('..', Base) > 0 do
    Base := StringReplace(Base, '..', '.', [rfReplaceAll]);
  Base := Base.Trim(['.']);
  if Length(Base) < 2 then
    Base := Fallback;
  Result := Base;
  N := 1;
  while MemberExists(Result) or (NameRefusal(Result) <> '') do
  begin
    Inc(N);
    Result := Base + IntToStr(N);
  end;
end;

procedure AddLogin(const Provider, ProviderId, Login: string; UserId: integer);
begin
  Exec(SqlInsertIgnore('logins', 'provider, provider_id, login, user_id', ':p, :i, :l, :u'),
    [Provider, ProviderId, Copy(Login, 1, 100), UserId]);
end;

procedure RefreshLogin(const Provider, ProviderId, Login: string);
begin
  if Login <> '' then
    Exec('UPDATE logins SET login = :l WHERE provider = :p AND provider_id = :i AND login <> :m', [Copy(Login, 1, 100), Provider, ProviderId, Copy(Login, 1, 100)]);
end;

{ GET /_oauth/:provider?code=&state= }
procedure ComeBack(ARequest: TRequest; AResponse: TResponse);
var
  P: TProvider;
  Me: TMember;
  Id, Login, Back: string;
  UserId: integer;
  ForApp: boolean;
begin
  CheckConnection;
  ForApp := AppReturn(ARequest, '') <> '';
  if not TokenTry(ARequest, AResponse) then
    Exit;
  P := Provider(ARequest.RouteParams['provider']);
  if not Ready(P.Name) or (ARequest.QueryFields.Values['state'] = '') or (ARequest.QueryFields.Values['state'] <> ARequest.CookieFields.Values['oauth']) or
    not WhoIsIt(ARequest, P, Id, Login) then
  begin
    if ForApp then
      AResponse.SendRedirect(AppReturn(ARequest, 'failed=1'))
    else
      AResponse.SendRedirect('/signin?failed=1');
    Exit;
  end;
  Me := CurrentMember(ARequest);
  UserId := IntValue('SELECT user_id FROM logins WHERE provider = :p AND provider_id = :i', [P.Name, Id]);
  if UserId > 0 then
    RefreshLogin(P.Name, Id, Login);
  if Me.Id > 0 then
  begin
    if UserId = 0 then
      AddLogin(P.Name, Id, Login, Me.Id);
    // Linked to someone else already: leave it where it is.  A program
    // waiting on this computer gets the member the browser is signed in as.
    if ForApp then
      AskForApp(ARequest, AResponse, Me.Id)
    else
      AResponse.SendRedirect('/u/' + HTTPEncode(Me.Name));
    Exit;
  end;
  if UserId = 0 then
  begin
    if TooManySignups(ClientIp(ARequest)) or not AllowAttempt(ClientIp(ARequest), 'signuptry', SettingInt('signuptry_address', 10), 1) then
    begin
      SendText(AResponse, 429, 'Too many new accounts from here. Try again later.');
      Exit;
    end;
    if Setting('registration', 'open') <> 'open' then
    begin
      if ForApp then
        AResponse.SendRedirect(AppReturn(ARequest, 'failed=closed'))
      else
        AResponse.SendRedirect('/signin?failed=closed');
      Exit;
    end;
    UserId := AddMember(FreeName(Login, P.Name), '', '', '', '', True);
    NoteTry(ClientIp(ARequest), 'signup');
    AddLogin(P.Name, Id, Login, UserId);
  end;
  if ForApp then
  begin
    // The program gets its token through the grant, once the member
    // allows it; the browser is not signed in by this.
    AskForApp(ARequest, AResponse, UserId);
    Exit;
  end;
  StartWebSession(AResponse, UserId);
  Back := LocalReturn(HTTPDecode(ARequest.CookieFields.Values['oauthback']));
  if (Back = '') or StartsText('/signin', Back) then
    Back := '/';
  AResponse.SendRedirect(Back);
end;

{ GET /api/logins  the providers here, and which the member has linked }
procedure ShowLogins(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  List: TJSONArray;
  Name: string;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  List := TJSONArray.Create;
  for Name in Providers do
    List.Add(TJSONObject.Create(['name', Name, 'title', ProviderTitle(Name), 'login',
      VarToStr(Value('SELECT login FROM logins WHERE provider = :p AND user_id = :u', [Name, Me.Id]))]));
  SendJSON(AResponse, TJSONObject.Create(['providers', List, 'password', VarToStr(Value('SELECT auth_hash FROM users WHERE id = :u', [Me.Id])) <> '']));
end;

{ POST /api/logins  unlink=provider, unless it is the only way in left }
procedure Unlink(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  if (VarToStr(Value('SELECT auth_hash FROM users WHERE id = :u', [Me.Id])) = '') and (IntValue('SELECT COUNT(*) FROM logins WHERE user_id = :u', [Me.Id]) <= 1) then
    SendText(AResponse, 409, 'That is your only way in. Set a password first.')
  else
  begin
    Exec('DELETE FROM logins WHERE user_id = :u AND provider = :p',
      [Me.Id, ARequest.ContentFields.Values['unlink']]);
    SendText(AResponse, 200, 'ok');
  end;
end;

{ A closed account is signed in to from nowhere: its sign-ins elsewhere are unlinked. }
procedure UnlinkAll(UserId: integer);
begin
  Exec('DELETE FROM logins WHERE user_id = :u', [UserId]);
end;

{ A site set up before the admin page had these: its config file's apps
  become settings, once. }
procedure TakeIniApps;
var
  Name: string;
begin
  for Name in Names do
    if (Setting(Name + '_id', '') = '') and (Config.ReadString(Name, 'id', '') <> '') then
    begin
      SaveSetting(Name + '_id', Config.ReadString(Name, 'id', ''));
      SaveSetting(Name + '_secret', Config.ReadString(Name, 'secret', ''));
      Log('Sign-in with ' + Name + ': moved from the config file to the settings');
    end;
  if (Setting('gitlab_url', '') = '') and (Config.ReadString('gitlab', 'url', '') <> '') then
    SaveSetting('gitlab_url', Config.ReadString('gitlab', 'url', ''));
end;

initialization
  GrantLock := TCriticalSection.Create;
  Grants := TStringList.Create;
  RegisterStartup(@TakeIniApps);
  RegisterCloseMemberHook(@UnlinkAll);
  RegisterSetting('github_on', 'Offer sign-in with GitHub', '1', 'yesno', 'Sign-in');
  RegisterSetting('github_id', 'GitHub app: client id', '', 'text', 'Sign-in');
  RegisterSetting('github_secret', 'GitHub app: client secret', '', 'secret', 'Sign-in');
  RegisterSetting('gitlab_on', 'Offer sign-in with GitLab', '1', 'yesno', 'Sign-in');
  RegisterSetting('gitlab_id', 'GitLab app: application id', '', 'text', 'Sign-in');
  RegisterSetting('gitlab_secret', 'GitLab app: secret', '', 'secret', 'Sign-in');
  RegisterSetting('gitlab_url', 'GitLab address (another GitLab than gitlab.com)', 'https://gitlab.com', 'text',
    'Sign-in');
  RegisterSetting('codeberg_on', 'Offer sign-in with Codeberg', '1', 'yesno', 'Sign-in');
  RegisterSetting('codeberg_id', 'Codeberg app: client id', '', 'text', 'Sign-in');
  RegisterSetting('codeberg_secret', 'Codeberg app: client secret', '', 'secret', 'Sign-in');
  RegisterSetting('codeberg_url', 'Codeberg address (another Forgejo or Gitea than codeberg.org)', 'https://codeberg.org',
    'text', 'Sign-in');
  RegisterSetting('google_on', 'Offer sign-in with Google', '1', 'yesno', 'Sign-in');
  RegisterSetting('google_id', 'Google OAuth client: client id', '', 'text', 'Sign-in');
  RegisterSetting('google_secret', 'Google OAuth client: client secret', '', 'secret', 'Sign-in');
  RegisterSetting('microsoft_on', 'Offer sign-in with Microsoft', '0', 'yesno', 'Sign-in');
  RegisterSetting('microsoft_id', 'Microsoft app: application (client) id', '', 'text', 'Sign-in');
  RegisterSetting('microsoft_secret', 'Microsoft app: client secret value', '', 'secret', 'Sign-in');
  RegisterTable('CREATE TABLE IF NOT EXISTS logins (' + ' provider VARCHAR(10) NOT NULL, provider_id VARCHAR(64) NOT NULL,' +
    ' login VARCHAR(100) NOT NULL DEFAULT '''', user_id INT NOT NULL,' + ' created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,' +
    ' PRIMARY KEY (provider, provider_id), INDEX (user_id)) CHARACTER SET utf8mb4');
  HTTPRouter.RegisterRoute('/signin-with/:provider', rmGet, @GoSignIn);
  HTTPRouter.RegisterRoute('/_oauth/:provider', rmGet, @ComeBack);
  HTTPRouter.RegisterRoute('/api/providers', rmGet, @ShowProviders);
  HTTPRouter.RegisterRoute('/signin-app', rmPost, @AnswerForApp);
  HTTPRouter.RegisterRoute('/api/grant', rmPost, @GiveGrant);
  HTTPRouter.RegisterRoute('/api/logins', rmGet, @ShowLogins);
  HTTPRouter.RegisterRoute('/api/logins', rmPost, @Unlink);

finalization
  Grants.Free;
  GrantLock.Free;

end.
