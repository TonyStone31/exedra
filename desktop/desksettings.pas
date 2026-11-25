unit DeskSettings;

{ The member's own settings the server keeps (/api/prefs): mail about
  missed messages, and when to show as away; and one this computer keeps,
  the size of the text. Account actions take effect immediately. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ButtonPanel, fpjson, DeskNet, DeskAccountKeys;

type
  TSettingsForm = class(TForm)
    Body: TScrollBox;
    Content: TPanel;
    MailCheck: TCheckBox;
    MailHint: TLabel;
    AwayLabel: TLabel;
    AwayBox: TComboBox;
    SizeLabel: TLabel;
    SizeBox: TComboBox;
    EmailLabel: TLabel;
    EmailEdit: TEdit;
    EmailState: TLabel;
    AccountButtons: TPanel;
    VerifyButton: TButton;
    RefreshButton: TButton;
    PasswordPanel: TPanel;
    PasswordHint: TLabel;
    PasswordLabel: TLabel;
    PasswordEdit: TEdit;
    RepeatLabel: TLabel;
    RepeatEdit: TEdit;
    PasswordButton: TButton;
    AccountStatus: TLabel;
    ButtonPanel1: TButtonPanel;
    procedure FormShow(Sender: TObject);
    procedure VerifyButtonClick(Sender: TObject);
    procedure RefreshButtonClick(Sender: TObject);
    procedure PasswordButtonClick(Sender: TObject);
  private
    FCanSavePrefs: boolean;
    Target: TApiTarget;
    KeySetup: TAccountKeySetup;
    InitialRead, Busy: boolean;
    AwayKept: integer;       // the away time the server had, when it is none of the choices
    procedure AccountDone(Job: TApiJob);
    procedure VerifyDone(Job: TApiJob);
    procedure PasswordAccountDone(Job: TApiJob);
    procedure KeysDone(Setup: TAccountKeySetup);
    procedure SaveClick(Sender: TObject);
    procedure SaveDone(Job: TApiJob);
    function AwayToSave: integer;
    procedure SetBusy(Value: boolean);
    procedure ShowAccount(Me: TJSONObject);
    procedure RefreshAccount;
  public
    destructor Destroy; override;
  end;

{ Shows the settings and saves them on OK; AutoAway comes back as the
  minutes now set (0 for never), Scale as the text size in percent. }
procedure EditSettings(var AutoAway, Scale: integer);

implementation

uses
  Dialogs, DeskKeys;

  {$R *.lfm}

const
  { The minutes behind each line of AwayBox. }
  AwayMinutes: array[0..5] of integer = (0, 5, 10, 15, 30, 60);
  { The percent behind each line of SizeBox. }
  Scales: array[0..3] of integer = (90, 100, 115, 135);

procedure TSettingsForm.FormShow(Sender: TObject);
begin
  if Width > Monitor.WorkareaRect.Right - Monitor.WorkareaRect.Left then
    Width := Monitor.WorkareaRect.Right - Monitor.WorkareaRect.Left;
  if Height > Monitor.WorkareaRect.Bottom - Monitor.WorkareaRect.Top then
    Height := Monitor.WorkareaRect.Bottom - Monitor.WorkareaRect.Top;
  if Left < Monitor.WorkareaRect.Left then Left := Monitor.WorkareaRect.Left;
  if Top < Monitor.WorkareaRect.Top then Top := Monitor.WorkareaRect.Top;
  if Left + Width > Monitor.WorkareaRect.Right then Left := Monitor.WorkareaRect.Right - Width;
  if Top + Height > Monitor.WorkareaRect.Bottom then Top := Monitor.WorkareaRect.Bottom - Height;
end;

destructor TSettingsForm.Destroy;
var
  Password: string;
begin
  ApiForgetReceiver(Self);
  Password := PasswordEdit.Text;
  PasswordEdit.Clear;
  WipeText(Password);
  Password := RepeatEdit.Text;
  RepeatEdit.Clear;
  WipeText(Password);
  inherited Destroy;
end;

procedure TSettingsForm.ShowAccount(Me: TJSONObject);
var
  HasPassword, Verified: boolean;
begin
  EmailEdit.Text := Me.Get('email', '');
  Verified := Me.Get('verified', False);
  FCanSavePrefs := Verified and not Me.Get('banned', False);
  EmailEdit.ReadOnly := Verified;
  VerifyButton.Enabled := not Verified;
  if EmailEdit.Text = '' then
    EmailState.Caption := 'No email address.'
  else if Verified then
    EmailState.Caption := 'Email confirmed.'
  else
    EmailState.Caption := 'Email not confirmed. Open the link in the verification mail, then check again.';
  MailCheck.Enabled := FCanSavePrefs and (EmailEdit.Text <> '');
  AwayBox.Enabled := FCanSavePrefs;
  if EmailEdit.Text <> '' then
    MailHint.Caption := 'To ' + EmailEdit.Text + ', at most one every ' + IntToStr(Me.Get('mail_hours', 6)) + ' hours, and only when something new waits for you.'
  else
    MailHint.Caption := 'Your account has no email address.';
  PasswordPanel.Visible := Me.Get('wrapped', '') = '';
  HasPassword := Me.Get('password', False);
  RepeatLabel.Visible := not HasPassword;
  RepeatEdit.Visible := not HasPassword;
  if HasPassword then
  begin
    PasswordLabel.Caption := 'Your current password';
    PasswordHint.Caption := 'Set up the key for locked conversations with your current password.';
    PasswordButton.Caption := 'Set up locked conversations';
  end
  else
  begin
    PasswordLabel.Caption := 'New password (8 characters or more)';
    PasswordHint.Caption := 'Set a password to sign in by name and use locked conversations.';
    PasswordButton.Caption := 'Set a password';
  end;
end;

procedure TSettingsForm.SetBusy(Value: boolean);
begin
  Busy := Value;
  Body.Enabled := not Value;
  ButtonPanel1.OKButton.Enabled := not Value;
end;

procedure TSettingsForm.RefreshAccount;
begin
  if not ApiTargetCurrent(Target) then Exit;
  SetBusy(True);
  ApiGetAsync('/api/me', @AccountDone);
end;

procedure TSettingsForm.AccountDone(Job: TApiJob);
var
  Me: TJSONObject;
  I: integer;
begin
  if not ApiTargetCurrent(Target) then Exit;
  SetBusy(False);
  try
    Me := Job.ObjectJSON;
    try
      if Me.Get('name', '') = '' then raise Exception.Create('Sign in first.');
      ShowAccount(Me);
      if InitialRead then
      begin
        MailCheck.Checked := Me.Get('mail_notes', True);
        // a time set elsewhere that is none of the choices here is kept
        // as it is: nothing is picked, and saving sends it back unchanged
        AwayKept := Me.Get('auto_away', 10);
        AwayBox.ItemIndex := -1;
        for I := 0 to High(AwayMinutes) do
          if AwayMinutes[I] = AwayKept then AwayBox.ItemIndex := I;
        InitialRead := False;
      end;
    finally
      Me.Free;
    end;
  except
    on E: Exception do
      if not ApiErrorHandled(E) then AccountStatus.Caption := E.Message;
  end;
end;

procedure TSettingsForm.VerifyButtonClick(Sender: TObject);
begin
  if Busy or not ApiTargetCurrent(Target) then Exit;
  SetBusy(True);
  ApiPostAsync('/api/verify', ['email', Trim(EmailEdit.Text)], @VerifyDone);
end;

procedure TSettingsForm.VerifyDone(Job: TApiJob);
begin
  if not ApiTargetCurrent(Target) then Exit;
  SetBusy(False);
  if Job.Error <> '' then
  begin
    if not Job.ErrorHandled then AccountStatus.Caption := Job.Error;
    Exit;
  end;
  AccountStatus.Caption := Job.Answer;
  RefreshAccount;
end;

procedure TSettingsForm.RefreshButtonClick(Sender: TObject);
begin
  if Busy then Exit;
  AccountStatus.Caption := 'Account state checked.';
  RefreshAccount;
end;

procedure TSettingsForm.PasswordButtonClick(Sender: TObject);
begin
  if Busy or not ApiTargetCurrent(Target) then Exit;
  SetBusy(True);
  ApiGetAsync('/api/me', @PasswordAccountDone);
end;

procedure TSettingsForm.PasswordAccountDone(Job: TApiJob);
var
  Me: TJSONObject;
begin
  if not ApiTargetCurrent(Target) then Exit;
  try
    Me := Job.ObjectJSON;
    try
      if Me.Get('name', '') = '' then raise Exception.Create('Sign in first.');
      if Me.Get('wrapped', '') <> '' then
      begin
        ShowAccount(Me);
        raise Exception.Create('This account has its keys already.');
      end;
      if Length(UTF8Decode(PasswordEdit.Text)) < 8 then
        raise Exception.Create('A password needs 8 characters or more.');
      if not Me.Get('password', False) and (PasswordEdit.Text <> RepeatEdit.Text) then
        raise Exception.Create('The passwords do not match.');
      AccountStatus.Caption := 'Setting up the key...';
      KeySetup.Free;
      KeySetup := TAccountKeySetup.Create(Self);
      KeySetup.Start(Target, Me.Get('name', ''), PasswordEdit.Text, @KeysDone);
      PasswordEdit.Clear;
      RepeatEdit.Clear;
    finally
      Me.Free;
    end;
  except
    on E: Exception do
    begin
      SetBusy(False);
      if not ApiErrorHandled(E) then AccountStatus.Caption := E.Message;
    end;
  end;
end;

procedure TSettingsForm.KeysDone(Setup: TAccountKeySetup);
begin
  if not ApiTargetCurrent(Target) then Exit;
  SetBusy(False);
  if Setup.Error <> '' then
  begin
    AccountStatus.Caption := Setup.Error;
    Exit;
  end;
  WipeBytes(MyKey);
  MyKey := Setup.TakeKey;
  PasswordPanel.Visible := False;
  AccountStatus.Caption := 'The key is ready for locked conversations. Account changes take effect immediately.';
end;

procedure TSettingsForm.SaveClick(Sender: TObject);
begin
  if Busy or not ApiTargetCurrent(Target) then Exit;
  if not FCanSavePrefs then
  begin
    ModalResult := mrOk;
    Exit;
  end;
  SetBusy(True);
  ApiPostAsync('/api/prefs', ['mail_notes', IntToStr(Ord(MailCheck.Checked)), 'auto_away', IntToStr(AwayToSave)], @SaveDone);
end;

{ The away time to save: the one picked, or the one the server had when
  none of the choices is it. }
function TSettingsForm.AwayToSave: integer;
begin
  if AwayBox.ItemIndex >= 0 then
    Result := AwayMinutes[AwayBox.ItemIndex]
  else
    Result := AwayKept;
end;

procedure TSettingsForm.SaveDone(Job: TApiJob);
begin
  if not ApiTargetCurrent(Target) then Exit;
  SetBusy(False);
  if Job.Error = '' then ModalResult := mrOk
  else if not Job.ErrorHandled then AccountStatus.Caption := Job.Error;
end;

procedure EditSettings(var AutoAway, Scale: integer);
var
  F: TSettingsForm;
  I: integer;
begin
  F := TSettingsForm.Create(Application);
  try
    F.Target := ApiTarget;
    F.InitialRead := True;
    F.AwayBox.ItemIndex := 2;
    F.SizeBox.ItemIndex := 1;
    for I := 0 to High(Scales) do
      if Scales[I] = Scale then F.SizeBox.ItemIndex := I;
    F.ButtonPanel1.OKButton.ModalResult := mrNone;
    F.ButtonPanel1.OKButton.OnClick := @F.SaveClick;
    F.RefreshAccount;
    if (F.ShowModal = mrOk) and ApiTargetCurrent(F.Target) then
    begin
      Scale := Scales[F.SizeBox.ItemIndex];
      if F.FCanSavePrefs then AutoAway := AwayMinutes[F.AwayBox.ItemIndex];
    end;
  finally
    F.Free;
  end;
end;

end.
