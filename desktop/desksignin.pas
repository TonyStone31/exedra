unit DeskSignIn;

{ The sign-in window: name and password, or joining; and the sign-ins the
  server offers through GitHub, GitLab and the others, looked up once a
  server has been typed.  Those go through the browser: the window
  listens on a port of 127.0.0.1, the browser comes back to it with a
  one-time grant, and the grant is traded for the token. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Buttons, ButtonPanel, DeskNet, DeskAccountKeys;

type
  TSignInForm = class(TForm)
    Logo: TImage;
    TitleLabel: TLabel;
    SubtitleLabel: TLabel;
    ServerLabel: TLabel;
    ServerEdit: TEdit;
    NameLabel: TLabel;
    NameEdit: TEdit;
    PasswordLabel: TLabel;
    PasswordEdit: TEdit;
    JoinPanel: TPanel;
    RepeatLabel: TLabel;
    RepeatEdit: TEdit;
    EmailLabel: TLabel;
    EmailEdit: TEdit;
    SsoLabel: TLabel;
    SsoPanel: TPanel;
    StatusLabel: TLabel;
    JoinRow: TPanel;
    JoinLabel: TButton;
    ButtonPanel1: TButtonPanel;
    LookupTimer: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
    procedure JoinLabelClick(Sender: TObject);
    procedure ServerEditChange(Sender: TObject);
    procedure LookupTick(Sender: TObject);
  private
    FJoining: boolean;
    FBusy: boolean;
    LookupGen: integer;     // counts lookups; an answer for an older one is dropped
    LookupUrl: string;      // the server the sign-ins shown belong to
    Listener: TObject;      // the TGrantListener waiting for the browser, while one is
    GrantState: string;     // the state made for that sign-in; the grant is traded with it
    ProviderTarget, AccountTarget: TApiTarget;
    FPassword, FName, FToken: string;
    FWrap, FPrivateKey: TBytes;
    KeySetup: TAccountKeySetup;
    procedure SaltDone(Job: TApiJob);
    procedure SignInDone(Job: TApiJob);
    procedure KeysDone(Setup: TAccountKeySetup);
    procedure SignInFailed(const Words: string);
    procedure AcceptSignIn;
    procedure SendPassword(const SaltName: string);
    function ServerUrl: string;
    procedure ProvidersDone(Job: TApiJob);
    procedure ProviderClick(Sender: TObject);
    procedure ProviderGlyph(B: TBitBtn; const Provider: string);
    procedure SetBusy(Busy: boolean);
  public
    { From the listener: the browser is listening for, then came back. }
    procedure ListenerReady(Port: word; const Provider: string);
    procedure GrantArrived(const Code, Failed: string);
  end;

var
  SignInForm: TSignInForm;

implementation

uses
  fpjson, Graphics, LCLIntf, fphttpserver, httpdefs, DeskKeys, DeskContent;

  {$R *.lfm}

type
  { Waits on 127.0.0.1 for the browser to come back from the provider with
    a grant or a failure: one request, a page saying so, and it is done.
    The port is picked by trying; the window is told once listening. }
  TGrantListener = class(TThread)
  private
    Web: TFPHttpServer;
    Form: TSignInForm;
    Provider, Code, Failed, State: string;
    Port: word;
    Told: boolean;
    procedure Request(Sender: TObject; var ARequest: TFPHTTPConnectionRequest; var AResponse: TFPHTTPConnectionResponse);
    procedure Idle(Sender: TObject);
    procedure TellReady;
    procedure Deliver;
  protected
    procedure Execute; override;
  public
    constructor Create(AForm: TSignInForm; const AProvider: string);
  end;

constructor TGrantListener.Create(AForm: TSignInForm; const AProvider: string);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  Form := AForm;
  Provider := AProvider;
  State := CallbackState;
end;

procedure TGrantListener.Execute;
var
  Tries: integer;
begin
  Web := TFPHttpServer.Create(nil);
  try
    Web.Address := '127.0.0.1';
    Web.OnRequest := @Request;
    Web.OnAcceptIdle := @Idle;
    Web.AcceptIdleTimeout := 300;
    // A port nobody has: tried until one binds.  Active blocks until the
    // request came or the window gave up.
    for Tries := 1 to 20 do
    begin
      Port := 41000 + Random(20000);
      Web.Port := Port;
      try
        Web.Active := True;
        Break;
      except
        if Tries = 20 then
          Failed := 'port';
      end;
    end;
  finally
    Web.Free;
  end;
  Synchronize(@Deliver);
end;

{ The accept loop is idle: the first time, it is listening, so the browser
  may be opened; later, the window may have given up. }
procedure TGrantListener.Idle(Sender: TObject);
begin
  if not Told then
  begin
    Told := True;
    Synchronize(@TellReady);
  end;
  if Terminated then
    Web.Active := False;
end;

procedure TGrantListener.TellReady;
begin
  if Form <> nil then
    Form.ListenerReady(Port, Provider);
end;

procedure TGrantListener.Request(Sender: TObject; var ARequest: TFPHTTPConnectionRequest; var AResponse: TFPHTTPConnectionResponse);
const
  Page = '<!doctype html><meta charset="utf-8"><title>Exedra</title>' + '<body style="font-family: sans-serif; margin: 3em; max-width: 36em"><h1>%s</h1><p>%s</p>';
begin
  if not ProviderCallbackAllowed(ARequest.Method, ARequest.PathInfo, ARequest.QueryFields.Values['grant'], ARequest.QueryFields.Values['failed'],
    ARequest.QueryFields.Values['state'], State) then
  begin
    AResponse.Code := 404;
    AResponse.Content := 'Not found';
    Exit;
  end;
  Code := ARequest.QueryFields.Values['grant'];
  Failed := ARequest.QueryFields.Values['failed'];
  AResponse.ContentType := 'text/html; charset=utf-8';
  if (Code <> '') and (Failed = '') then
    AResponse.Content := Format(Page, ['Signed in', 'Exedra on this computer has your sign-in. You can close this tab.'])
  else
    AResponse.Content := Format(Page, ['Not signed in', 'That sign-in did not go through. Go back to Exedra and try again.']);
  AResponse.ContentLength := Length(AResponse.Content);
  // One request is all; the loop ends after it.
  Web.Active := False;
end;

procedure TGrantListener.Deliver;
begin
  if Form <> nil then
    Form.GrantArrived(Code, Failed);
end;

procedure TSignInForm.FormCreate(Sender: TObject);
begin
  Logo.Picture.LoadFromResourceName(HInstance, 'LOGO');
  // The dialog closes itself once the server says yes.
  ButtonPanel1.OKButton.ModalResult := mrNone;
  // The joining fields wait hidden; hiding keeps their order, squeezing
  // them to no height does not.
  JoinPanel.Visible := False;
end;

procedure TSignInForm.FormDestroy(Sender: TObject);
var
  Password: string;
begin
  Password := PasswordEdit.Text;
  PasswordEdit.Clear;
  WipeText(Password);
  Password := RepeatEdit.Text;
  RepeatEdit.Clear;
  WipeText(Password);
  ApiCancelReceiver(Self);
  WipeText(FPassword);
  WipeText(FToken);
  WipeBytes(FWrap);
  WipeBytes(FPrivateKey);
  // A listener still waiting ends on its own; it must not call back here.
  if Listener <> nil then
  begin
    TGrantListener(Listener).Form := nil;
    TGrantListener(Listener).Terminate;
    Listener := nil;
  end;
  // An answer to a lookup may still be on its way.
  Inc(LookupGen);
end;

procedure TSignInForm.FormShow(Sender: TObject);
begin
  if Trim(ServerEdit.Text) <> '' then
    LookupTick(nil);
end;

function TSignInForm.ServerUrl: string;
var
  Why: string;
begin
  if not ServerAddress(ServerEdit.Text, Result, Why) then
    Result := '';
end;

{ ---- the sign-ins the server offers ---- }

procedure TSignInForm.ServerEditChange(Sender: TObject);
begin
  Inc(LookupGen);
  LookupUrl := '';
  SsoPanel.Visible := False;
  SsoLabel.Caption := '';
  // Looked up a moment after the typing stops.
  LookupTimer.Enabled := False;
  LookupTimer.Enabled := True;
end;

procedure TSignInForm.LookupTick(Sender: TObject);
var
  Url: string;
begin
  LookupTimer.Enabled := False;
  Url := ServerUrl;
  Inc(LookupGen);
  SsoPanel.Visible := False;
  if not ((Url.StartsWith('https://') and (Length(Url) > 11)) or (Url.StartsWith('http://') and (Length(Url) > 10))) then
  begin
    SsoLabel.Caption := '';
    Exit;
  end;
  SsoLabel.Caption := 'Looking up the ways to sign in there...';
  LookupUrl := Url;
  ApiGetAsync(Url + '/api/providers', @ProvidersDone, LookupGen);
end;

procedure TSignInForm.ProvidersDone(Job: TApiJob);
var
  List: TJSONArray;
  I: integer;
  B: TBitBtn;
begin
  if Job.Tag <> LookupGen then
    Exit;
  while SsoPanel.ControlCount > 0 do
    SsoPanel.Controls[0].Free;
  if Job.Error <> '' then
  begin
    SsoLabel.Caption := 'No Exedra server answers at that address yet.';
    Exit;
  end;
  List := Job.ArrayJSON;
  try
    if List.Count = 0 then
    begin
      SsoLabel.Caption := 'This server signs members in by name and password.';
      Exit;
    end;
    SsoLabel.Caption := 'or continue with';
    for I := 0 to List.Count - 1 do
    begin
      B := TBitBtn.Create(SsoPanel);
      B.Parent := SsoPanel;
      B.Caption := TJSONObject(List[I]).Get('title', '');
      B.Hint := TJSONObject(List[I]).Get('name', '');
      B.Height := 38;
      B.Layout := blGlyphLeft;
      B.Margin := 14;
      B.Spacing := 12;
      ProviderGlyph(B, TJSONObject(List[I]).Get('name', ''));
      B.OnClick := @ProviderClick;
    end;
    // Shown again it goes by its Top: right under its label.
    SsoPanel.Top := SsoLabel.Top + SsoLabel.Height + 1;
    SsoPanel.Visible := True;
  finally
    List.Free;
  end;
end;

{ The provider's mark from the program's resources (SSO_GITHUB and the
  rest, from the web page's own pictures); GitHub's is black, so a white
  one goes on a dark theme.  None when the resource is missing. }
procedure TSignInForm.ProviderGlyph(B: TBitBtn; const Provider: string);
var
  Png: TPortableNetworkGraphic;
  Res: string;
  Face: longint;
begin
  Res := 'SSO_' + UpperCase(Provider);
  Face := ColorToRGB(clBtnFace);
  if (Provider = 'github') and ((Red(Face) * 299 + Green(Face) * 587 + Blue(Face) * 114) div 1000 < 128) then
    Res := Res + '_LIGHT';
  if FindResource(HInstance, PChar(Res), RT_RCDATA) = 0 then
    Exit;
  Png := TPortableNetworkGraphic.Create;
  try
    Png.LoadFromResourceName(HInstance, Res);
    B.Glyph.Assign(Png);
  finally
    Png.Free;
  end;
end;

procedure TSignInForm.SetBusy(Busy: boolean);
begin
  FBusy := Busy;
  ButtonPanel1.OKButton.Enabled := not Busy;
  JoinLabel.Enabled := not Busy;
  SsoPanel.Enabled := not Busy;
  ServerEdit.Enabled := not Busy;
  NameEdit.Enabled := not Busy;
  PasswordEdit.Enabled := not Busy;
  JoinPanel.Enabled := not Busy;
end;

{ A provider's button: the window listens, then the browser is opened to
  the server, which sends it on to the provider and back. }
procedure TSignInForm.ProviderClick(Sender: TObject);
begin
  if FBusy or (Listener <> nil) or (LookupUrl <> ServerUrl) then
    Exit;
  AccountTarget := ApiTarget;
  ProviderTarget := AccountTarget;
  ProviderTarget.Address := LookupUrl;
  ProviderTarget.Auth := '';
  SetBusy(True);
  StatusLabel.Caption := 'Opening the browser to sign in with ' + TBitBtn(Sender).Caption + '...';
  Listener := TGrantListener.Create(Self, TBitBtn(Sender).Hint);
  TGrantListener(Listener).Start;
end;

procedure TSignInForm.ListenerReady(Port: word; const Provider: string);
begin
  if not ApiTargetCurrent(AccountTarget) then Exit;
  GrantState := TGrantListener(Listener).State;
  OpenURL(ProviderTarget.Address + '/signin-with/' + Provider + '?app=Exedra%20desktop&port=' + IntToStr(Port) + '&state=' + GrantState);
  StatusLabel.Caption := 'Sign in in the browser, then press Allow there (port ' + IntToStr(Port) + ')... Cancel gives up.';
end;

procedure TSignInForm.GrantArrived(const Code, Failed: string);
begin
  Listener := nil;
  if not ApiTargetCurrent(AccountTarget) then Exit;
  if Failed = 'closed' then
    SignInFailed('New accounts are closed on that server for now.')
  else if Failed = 'port' then
    SignInFailed('No port of this computer could be listened on.')
  else if (Failed <> '') or (Code = '') then
    SignInFailed('That sign-in did not go through. Try again.')
  else
    ApiPostTargetAsync(ProviderTarget, '/api/grant', ['code', Code, 'state', GrantState], @SignInDone);
end;

procedure TSignInForm.JoinLabelClick(Sender: TObject);
begin
  if FBusy then
    Exit;
  FJoining := not FJoining;
  // Shown again it goes by its Top: right under the password.
  if FJoining then
    JoinPanel.Top := PasswordEdit.Top + PasswordEdit.Height + 1;
  JoinPanel.Visible := FJoining;
  RepeatEdit.Clear;
  StatusLabel.Caption := '';
  if FJoining then
  begin
    Caption := 'Join';
    SubtitleLabel.Caption := 'Make an account on an Exedra server';
    ButtonPanel1.OKButton.Caption := 'Join';
    ButtonPanel1.OKButton.Hint := 'Create an account and sign in';
    JoinLabel.Caption := 'Have an account? &Sign in';
  end
  else
  begin
    Caption := 'Sign in';
    SubtitleLabel.Caption := 'Sign in to an Exedra server';
    ButtonPanel1.OKButton.Caption := 'Sign in';
    ButtonPanel1.OKButton.Hint := 'Sign in to the server';
    JoinLabel.Caption := 'No account yet? &Join';
  end;
  NameEdit.SetFocus;
end;

procedure TSignInForm.OKButtonClick(Sender: TObject);
var
  Address, Why: string;
begin
  if FBusy then Exit;
  if (Trim(NameEdit.Text) = '') or (PasswordEdit.Text = '') then
  begin
    StatusLabel.Caption := 'Enter your name and password.';
    Exit;
  end;
  if FJoining then
  begin
    if Length(UTF8Decode(PasswordEdit.Text)) < 8 then
    begin
      StatusLabel.Caption := 'A new password needs 8 characters or more.';
      Exit;
    end;
    if PasswordEdit.Text <> RepeatEdit.Text then
    begin
      StatusLabel.Caption := 'The passwords do not match.';
      Exit;
    end;
  end;
  if not ServerAddress(ServerEdit.Text, Address, Why) then
  begin
    StatusLabel.Caption := Why;
    Exit;
  end;
  SetBusy(True);
  StatusLabel.Caption := 'Checking... Cancel gives up.';
  AccountTarget := ApiTarget;
  ProviderTarget := AccountTarget;
  ProviderTarget.Address := Address;
  ProviderTarget.Auth := '';
  FName := Trim(NameEdit.Text);
  FPassword := PasswordEdit.Text;
  PasswordEdit.Clear;
  RepeatEdit.Clear;
  if FJoining then SendPassword(FName)
  else
    ApiGetTargetAsync(ProviderTarget, '/api/auth-name?' + Query(['name', FName]), @SaltDone);
end;

procedure TSignInForm.SaltDone(Job: TApiJob);
var
  Answer: TJSONObject;
begin
  if not ApiTargetCurrent(AccountTarget) then Exit;
  try
    Answer := Job.ObjectJSON;
    try
      SendPassword(Answer.Get('name', FName));
    finally
      Answer.Free;
    end;
  except
    on E: Exception do SignInFailed(E.Message);
  end;
end;

procedure TSignInForm.SendPassword(const SaltName: string);
var
  Auth, Pub, Wrapped: string;
begin
  try
    try
      PasswordKeys(SaltName, FPassword, Auth, FWrap);
      if FJoining then
      begin
        NewAccountKeys(FWrap, FPrivateKey, Pub, Wrapped);
        ApiPostTargetAsync(ProviderTarget, '/api/signup', ['name', FName, 'email', Trim(EmailEdit.Text), 'auth', Auth, 'pub', Pub, 'wrapped',
          Wrapped, 'app', 'Exedra desktop'], @SignInDone);
      end
      else
        ApiPostTargetAsync(ProviderTarget, '/api/signin', ['name', FName, 'auth', Auth, 'app', 'Exedra desktop'], @SignInDone);
    except
      on E: Exception do SignInFailed(E.Message);
    end;
  finally
    WipeText(Auth);
  end;
end;

procedure TSignInForm.SignInDone(Job: TApiJob);
var
  Answer: TJSONObject;
  KeyTarget: TApiTarget;
begin
  if not ApiTargetCurrent(AccountTarget) then Exit;
  try
    Answer := Job.ObjectJSON;
    try
      FToken := Answer.Get('token', '');
      if FToken = '' then raise Exception.Create('The server did not return an app token.');
      if FPassword <> '' then
      begin
        if not FJoining and (Answer.Get('wrapped', '') <> '') then
          FPrivateKey := Unwrap(Answer.Get('wrapped', ''), FWrap);
        if not FJoining and (FPrivateKey = nil) then
        begin
          KeyTarget := ProviderTarget;
          KeyTarget.Auth := FToken;
          KeySetup.Free;
          KeySetup := TAccountKeySetup.Create(Self);
          KeySetup.Start(KeyTarget, Answer.Get('name', FName), FPassword, @KeysDone);
          Exit;
        end;
      end;
      AcceptSignIn;
    finally
      Answer.Free;
    end;
  except
    on E: Exception do SignInFailed(E.Message);
  end;
end;

procedure TSignInForm.KeysDone(Setup: TAccountKeySetup);
begin
  if not ApiTargetCurrent(AccountTarget) then Exit;
  if Setup.Error <> '' then SignInFailed(Setup.Error)
  else
  begin
    FPrivateKey := Setup.TakeKey;
    AcceptSignIn;
  end;
end;

procedure TSignInForm.AcceptSignIn;
begin
  if not ApiTargetCurrent(AccountTarget) then Exit;
  Server := ProviderTarget.Address;
  Token := FToken;
  WipeBytes(MyKey);
  MyKey := FPrivateKey;
  FPrivateKey := nil;
  WipeText(FPassword);
  WipeBytes(FWrap);
  ModalResult := mrOk;
end;

procedure TSignInForm.SignInFailed(const Words: string);
begin
  WipeText(FPassword);
  WipeText(FToken);
  WipeBytes(FWrap);
  WipeBytes(FPrivateKey);
  SetBusy(False);
  StatusLabel.Caption := Words;
end;

end.
