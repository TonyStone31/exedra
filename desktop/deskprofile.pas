unit DeskProfile;

{ Member profiles and the People panel's Profile and Message menu. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ButtonPanel,
  Dialogs, Menus, InkMemo, InkListBox, DeskNet, DeskPictures;

type
  TProfileForm = class(TForm)
    Body: TScrollBox;
    Content: TPanel;
    Avatar: TImage;
    NameLabel: TLabel;
    BadgeLabel: TLabel;
    SeenLabel: TLabel;
    AwayLabel: TLabel;
    Details: TInkMemo;
    Editor: TPanel;
    BioLabel: TLabel;
    BioEdit: TMemo;
    LinksLabel: TLabel;
    LinksEdit: TMemo;
    EditButton: TButton;
    AvatarButton: TButton;
    SaveButton: TButton;
    CancelEditButton: TButton;
    Actions: TPanel;
    StatusLabel: TLabel;
    ButtonPanel1: TButtonPanel;
    AvatarDialog: TOpenDialog;
    procedure FormShow(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure EditButtonClick(Sender: TObject);
    procedure CancelEditButtonClick(Sender: TObject);
    procedure SaveButtonClick(Sender: TObject);
    procedure AvatarButtonClick(Sender: TObject);
    procedure DetailsLinkClick(Sender: TObject; LineIndex: integer; const LinkName: string);
    procedure DetailsResource(Sender: TObject; const URL: string; Destination: TStream; var Handled: boolean);
  private
    MemberName, SignedInName, OriginalBio, OriginalLinks: string;
    Target: TApiTarget;
    Pictures: TPictureCache;
    Busy: boolean;
    AvatarGeneration: integer;
    procedure ProfileDone(Job: TApiJob);
    procedure Saved(Job: TApiJob);
    procedure AvatarSaved(Job: TApiJob);
    procedure AvatarFetched(const Path: string; Bytes: TBytes; FetchTag: integer);
    procedure PictureFetched(const Path: string; Bytes: TBytes; FetchTag: integer);
    procedure PictureDropped(const Path: string);
    procedure SetBusy(Value: boolean);
    procedure LoadProfile;
    procedure LoadAvatar(const URL: string);
    procedure ResetEditor;
    procedure SetEditing(Editing: boolean);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

  TProfileMessage = procedure(const Wanted: string) of object;

procedure ShowProfile(const Name, MyName: string);
{ Names parallels the list, with empty entries for headings. MyName is
  the form's current signed-in name; all three outlive the menu. }
procedure AttachProfileMenu(List: TInkListBox; Names: TStrings; MyName: PString; MessageTo: TProfileMessage);

implementation

uses
  Graphics, LCLIntf, LCLType, fpjson, InkWebP, DeskView, DeskIcons;

  {$R *.lfm}

type
  TProfileMenu = class(TPopupMenu)
  private
    People: TInkListBox;
    Names: TStrings;
    MyName: PString;
    Picked: string;
    Target: TApiTarget;
    MessageItem: TMenuItem;
    MessageTo: TProfileMessage;
    procedure ContextPopup(Sender: TObject; MousePos: TPoint; var Handled: boolean);
    procedure ProfileClick(Sender: TObject);
    procedure MessageClick(Sender: TObject);
  end;

procedure TProfileMenu.ContextPopup(Sender: TObject; MousePos: TPoint; var Handled: boolean);
var
  I: integer;
begin
  Picked := '';
  Target := ApiTarget;
  if MousePos.X < 0 then
    I := People.ItemIndex
  else
    I := People.ItemAtPos(MousePos, True);
  if (I >= 0) and (I < Names.Count) then
    Picked := Names[I];
  Handled := Picked = '';
  MessageItem.Enabled := (MyName^ <> '') and not SameText(Picked, MyName^);
end;

procedure TProfileMenu.ProfileClick(Sender: TObject);
begin
  if not ApiTargetCurrent(Target) then Exit;
  if Picked <> '' then
    ShowProfile(Picked, MyName^);
end;

procedure TProfileMenu.MessageClick(Sender: TObject);
begin
  if not ApiTargetCurrent(Target) then Exit;
  if (Picked <> '') and MessageItem.Enabled then
    MessageTo('@' + Picked);
end;

procedure AttachProfileMenu(List: TInkListBox; Names: TStrings; MyName: PString; MessageTo: TProfileMessage);
var
  Menu: TProfileMenu;
  Item: TMenuItem;
begin
  Menu := TProfileMenu.Create(List);
  Menu.People := List;
  Menu.Names := Names;
  Menu.MyName := MyName;
  Menu.MessageTo := MessageTo;
  Item := TMenuItem.Create(Menu);
  Item.Caption := 'Profile';
  Item.OnClick := @Menu.ProfileClick;
  Menu.Items.Add(Item);
  Item := TMenuItem.Create(Menu);
  Item.Caption := 'Message';
  Item.OnClick := @Menu.MessageClick;
  Menu.Items.Add(Item);
  Menu.MessageItem := Item;
  List.PopupMenu := Menu;
  List.OnContextPopup := @Menu.ContextPopup;
end;

procedure ShowProfile(const Name, MyName: string);
var
  F: TProfileForm;
begin
  F := TProfileForm.Create(Application);
  try
    F.MemberName := Name;
    F.SignedInName := MyName;
    F.Target := ApiTarget;
    F.ShowModal;
  finally
    F.Free;
  end;
end;

procedure TProfileForm.FormShow(Sender: TObject);
begin
  if Width > Monitor.WorkareaRect.Right - Monitor.WorkareaRect.Left then
    Width := Monitor.WorkareaRect.Right - Monitor.WorkareaRect.Left;
  if Height > Monitor.WorkareaRect.Bottom - Monitor.WorkareaRect.Top then
    Height := Monitor.WorkareaRect.Bottom - Monitor.WorkareaRect.Top;
  if Left < Monitor.WorkareaRect.Left then Left := Monitor.WorkareaRect.Left;
  if Top < Monitor.WorkareaRect.Top then Top := Monitor.WorkareaRect.Top;
  if Left + Width > Monitor.WorkareaRect.Right then Left := Monitor.WorkareaRect.Right - Width;
  if Top + Height > Monitor.WorkareaRect.Bottom then Top := Monitor.WorkareaRect.Bottom - Height;
  ButtonPanel1.CloseButton.Cancel := True;
  try
    LoadProfile;
  except
    on E: Exception do
      if not ApiErrorHandled(E) then StatusLabel.Caption := E.Message;
  end;
end;

procedure TProfileForm.FormKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    ModalResult := mrClose;
    Key := 0;
  end;
end;

constructor TProfileForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Pictures := TPictureCache.Create;
  Pictures.OnDrop := @PictureDropped;
end;

destructor TProfileForm.Destroy;
begin
  ApiForgetReceiver(Self);
  Pictures.Free;
  inherited Destroy;
end;

procedure TProfileForm.SetBusy(Value: boolean);
begin
  Busy := Value;
  Actions.Enabled := not Value;
  Editor.Enabled := not Value;
end;

procedure TProfileForm.LoadAvatar(const URL: string);
begin
  Inc(AvatarGeneration);
  AvatarFetched('', nil, AvatarGeneration);
  if URL.StartsWith('/f/') then Fetch(URL, @AvatarFetched, False, AvatarGeneration);
end;

procedure TProfileForm.AvatarFetched(const Path: string; Bytes: TBytes; FetchTag: integer);
var
  Pic: TBitmap;
  Data: TBytesStream;
  WebP: TInkWebP;
begin
  if (FetchTag <> AvatarGeneration) or not ApiTargetCurrent(Target) then Exit;
  Pic := IconFromBytes(Bytes, Avatar.Width);
  if (Pic = nil) and (PictureCost(Bytes) > 0) then
  begin
    Data := TBytesStream.Create(Bytes);
    try
      WebP := TInkWebP.Create(Data);
      try
        if WebP.Decoded then
        begin
          Pic := TBitmap.Create;
          Pic.Assign(WebP.Bitmap);
        end;
      finally
        WebP.Free;
      end;
    finally
      Data.Free;
    end;
  end;
  if Pic = nil then Pic := LetterIcon(MemberName, Avatar.Width);
  try
    Avatar.Picture.Assign(Pic);
  finally
    Pic.Free;
  end;
end;

procedure TProfileForm.LoadProfile;
begin
  if not ApiTargetCurrent(Target) then Exit;
  SetBusy(True);
  ApiGetAsync('/api/user?' + Query(['name', MemberName]), @ProfileDone);
end;

procedure TProfileForm.ProfileDone(Job: TApiJob);
var
  Who: TJSONObject;
  Link, Html, Stamp: string;
  Links: TStringArray;
begin
  if not ApiTargetCurrent(Target) then Exit;
  SetBusy(False);
  try
    Who := Job.ObjectJSON;
    try
      MemberName := Who.Get('name', MemberName);
      Caption := MemberName + ' - Profile';
      NameLabel.Caption := MemberName;
      BadgeLabel.Caption := Who.Get('badge', '');
      if Who.Get('banned', False) then
        BadgeLabel.Caption := Trim(BadgeLabel.Caption + ' banned');
      AwayLabel.Caption := '';
      if Who.Get('away', '') <> '' then
        AwayLabel.Caption := 'Away: ' + Who.Get('away', '');
      SeenLabel.Caption := '';
      // a closed account: the name, and that its member left
      if Who.Get('closed', False) then
        SeenLabel.Caption := 'Former member';
      Stamp := Who.Get('joined', '');
      if Stamp <> '' then
        SeenLabel.Caption := 'Joined ' + DateToStr(LocalTime(Stamp));
      Stamp := Who.Get('seen', '');
      if Stamp <> '' then
        SeenLabel.Caption := SeenLabel.Caption + LineEnding + 'Last seen ' + DateTimeToStr(LocalTime(Stamp));
      OriginalBio := Who.Get('bio', '');
      OriginalLinks := Who.Get('links', '');
      Html := Who.Get('bio_html', '');
      Links := OriginalLinks.Split([' ', #9, #10, #13], TStringSplitOptions.ExcludeEmpty);
      for Link in Links do
        if Link.StartsWith('https://') or Link.StartsWith('http://') then
          Html := Html + '<p><a href="' + Escape(Link) + '">' + Escape(Link) + '</a></p>';
      Details.LoadDocument(Html);
      ResetEditor;
      EditButton.Visible := (SignedInName <> '') and SameText(MemberName, SignedInName);
      AvatarButton.Visible := EditButton.Visible;
      LoadAvatar(Who.Get('avatar', ''));
    finally
      Who.Free;
    end;
  except
    on E: Exception do
      if not ApiErrorHandled(E) then StatusLabel.Caption := E.Message;
  end;
end;

procedure TProfileForm.ResetEditor;
var
  Link: string;
begin
  BioEdit.Text := OriginalBio;
  LinksEdit.Lines.Clear;
  for Link in OriginalLinks.Split([' ', #9, #10, #13], TStringSplitOptions.ExcludeEmpty) do
    LinksEdit.Lines.Add(Link);
  BioEdit.Modified := False;
  LinksEdit.Modified := False;
end;

procedure TProfileForm.SetEditing(Editing: boolean);
begin
  Editor.Visible := Editing;
  Details.Visible := not Editing;
  SaveButton.Visible := Editing;
  CancelEditButton.Visible := Editing;
  EditButton.Visible := not Editing;
  AvatarButton.Enabled := not Editing;
  if Editing then
    BioEdit.SetFocus;
end;

procedure TProfileForm.EditButtonClick(Sender: TObject);
begin
  StatusLabel.Caption := '';
  SetEditing(True);
end;

procedure TProfileForm.CancelEditButtonClick(Sender: TObject);
begin
  ResetEditor;
  StatusLabel.Caption := '';
  SetEditing(False);
end;

procedure TProfileForm.SaveButtonClick(Sender: TObject);
var
  Bio, Links: string;
begin
  if not ApiTargetCurrent(Target) then Exit;
  Bio := OriginalBio;
  Links := OriginalLinks;
  if BioEdit.Modified then
    Bio := BioEdit.Text;
  if LinksEdit.Modified then
    Links := Trim(LinksEdit.Text);
  if Busy then Exit;
  SetBusy(True);
  ApiPostAsync('/api/profile', ['bio', Bio, 'links', Links], @Saved);
end;

procedure TProfileForm.Saved(Job: TApiJob);
begin
  if not ApiTargetCurrent(Target) then Exit;
  SetBusy(False);
  if Job.Error <> '' then
  begin
    if not Job.ErrorHandled then StatusLabel.Caption := Job.Error;
    Exit;
  end;
  StatusLabel.Caption := 'Profile saved.';
  SetEditing(False);
  LoadProfile;
end;

{ A picture from disk becomes the member's avatar (the upload says so). }
procedure TProfileForm.AvatarButtonClick(Sender: TObject);
var
  Data: TBytesStream;
begin
  if Busy then Exit;
  if not AvatarDialog.Execute then
    Exit;
  if not ApiTargetCurrent(Target) then Exit;
  Data := TBytesStream.Create;
  try
    try
      Data.LoadFromFile(AvatarDialog.FileName);
      SetBusy(True);
      ApiUploadAsync(ExtractFileName(AvatarDialog.FileName), Data, False, True, '', '', @AvatarSaved);
    except
      on E: Exception do
      begin
        SetBusy(False);
        if not ApiErrorHandled(E) then StatusLabel.Caption := E.Message;
      end;
    end;
  finally
    Data.Free;
  end;
end;

procedure TProfileForm.AvatarSaved(Job: TApiJob);
begin
  if not ApiTargetCurrent(Target) then Exit;
  SetBusy(False);
  if Job.Error <> '' then
  begin
    if not Job.ErrorHandled then StatusLabel.Caption := Job.Error;
    Exit;
  end;
  StatusLabel.Caption := 'Picture changed.';
  LoadProfile;
end;

procedure TProfileForm.DetailsLinkClick(Sender: TObject; LineIndex: integer; const LinkName: string);
begin
  // an address from the server's HTML carries the path the site sits under: handled without it
  if SiteLocal(LinkName) <> LinkName then
  begin
    DetailsLinkClick(Sender, LineIndex, SiteLocal(LinkName));
    Exit;
  end;
  if not ApiTargetCurrent(Target) then Exit;
  if LinkName.StartsWith('https://') or LinkName.StartsWith('http://') or LinkName.StartsWith('mailto:') then
    OpenURL(LinkName)
  else if LinkName.StartsWith('/') and not LinkName.StartsWith('//') then
    OpenURL(Server + LinkName);
end;

procedure TProfileForm.DetailsResource(Sender: TObject; const URL: string; Destination: TStream; var Handled: boolean);
var
  Entry: TPictureEntry;
begin
  // an address from the server's HTML carries the path the site sits under: handled without it
  if SiteLocal(URL) <> URL then
  begin
    DetailsResource(Sender, SiteLocal(URL), Destination, Handled);
    Exit;
  end;
  Handled := True;
  if not ApiTargetCurrent(Target) or not URL.StartsWith('/f/') then Exit;
  Entry := Pictures.Read(URL);
  if Entry <> nil then
  begin
    Entry.Position := 0;
    Destination.CopyFrom(Entry, Entry.Size);
  end
  else if Pictures.BeginFetch(URL) then
    if not Fetch(URL, @PictureFetched) then Pictures.Failed(URL);
end;

procedure TProfileForm.PictureFetched(const Path: string; Bytes: TBytes; FetchTag: integer);
begin
  if not ApiTargetCurrent(Target) then Exit;
  if Pictures.Complete(Path, Bytes) then Details.ResourceChanged(Path);
end;

procedure TProfileForm.PictureDropped(const Path: string);
begin
  Details.ResourceChanged(Path);
end;

end.
