unit DeskThread;

{$mode objfpc}{$H+}

interface

uses
  InfoBar, Toast, Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Menus, Dialogs,
  fpjson, InkMemo, InkLabel, CrossDragDropData, CrossDragDropHelpers, DeskContent, DeskNet;

type
  TLinkEvent = procedure(const Link: string) of object;
  TPictureEvent = procedure(const URL: string; Destination: TStream; var Handled: boolean) of object;

  TThreadFrame = class(TFrame)
    NoticeBar: TInfoBar;
    NoticeToast: TToast;
    HeadPanel: TPanel;
    TitleLabel: TLabel;
    CloseButton: TButton;
    HeadRule: TShape;
    Replies: TInkMemo;
    ReplyPanel: TPanel;
    ReplyBox: TMemo;
    ButtonBox: TPanel;
    ReplyButton: TButton;
    AttachButton: TButton;
    CodeButton: TButton;
    FileExpiryBox: TComboBox;
    AttachRow: TInkLabel;
    EditLabel: TLabel;
    OpenDialog1: TOpenDialog;
    MessageMenu: TPopupMenu;
    ReactItem: TMenuItem;
    PinItem, CopyItem, CopyLinkItem, MenuSeparator, EditItem, DeleteItem: TMenuItem;
    procedure NoticeAnswer(Sender: TObject; const Key: string; Answer: TModalResult);
    procedure CloseButtonClick(Sender: TObject);
    procedure RepliesLinkClick(Sender: TObject; LineIndex: integer; const LinkName: string);
    procedure RepliesKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure RepliesResource(Sender: TObject; const URL: string; Destination: TStream; var Handled: boolean);
    procedure ReplyBoxKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure ReplyButtonClick(Sender: TObject);
    procedure AttachButtonClick(Sender: TObject);
    procedure CodeButtonClick(Sender: TObject);
    procedure AttachRowLink(Sender: TObject; const LinkName: string);
    procedure MessageMenuPopup(Sender: TObject);
    procedure ReactClick(Sender: TObject);
    procedure PinItemClick(Sender: TObject);
    procedure CopyItemClick(Sender: TObject);
    procedure CopyLinkItemClick(Sender: TObject);
    procedure EditItemClick(Sender: TObject);
    procedure DeleteItemClick(Sender: TObject);
  private
    Generation, Uploading: integer;
    Sending: boolean;
    SentEdit: integer;
    procedure ThreadDone(Job: TApiJob);
    procedure ActionDone(Job: TApiJob);
    procedure SendDone(Job: TApiJob);
    procedure UploadDone(Job: TApiJob);
    procedure UpdateBusy;
  private
    FRootId: integer;
    FRoom, FMyName: string;
    FAccountReady: boolean;
    FCanReact, FCanPin, FCanDeleteAny, FCanEditOwn, FCanDeleteOwn: boolean;
    Shown, Attached: TJSONArray;
    FReactions: TJSONObject;
    Previews: TPreviewState;
    MenuId, EditingId, ReplyBase: integer;
    RetryRoot, RetryEpoch: integer;
    DraftBeforeEdit: string;
    DropTarget: TCrossDragDropTarget;
    FOnClose: TNotifyEvent;
    FOnConnectionAnswer: TInfoBarAnswerEvent;
    FOnLink: TLinkEvent;
    FOnPicture: TPictureEvent;
    function GetSyncId: integer;
    function FindMessage(Id: integer): TJSONObject;
    function MenuMessage: TJSONObject;
    function OwnMessage(Msg: TJSONObject): boolean;
    procedure LoadThread(AId: integer);
    procedure Render(Follow: boolean; OldY: integer);
    procedure AppendMessage(Msg: TJSONObject; Follows: boolean);
    procedure StopEdit;
    procedure ShowAttached;
    procedure AttachFile(const FileName: string);
    procedure ReplyDropFiles(Sender: TObject; Files: TStrings; X, Y: integer);
    procedure DropError(Sender: TObject; const Message: string);
    procedure ReactTo(Id: integer; const Reaction: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { Reactions: the site's, as /api/me gave them; a copy is kept. }
    procedure SetMember(const AName: string; CanReact, CanPin, CanDeleteAny, CanEditOwn, CanDeleteOwn: boolean; Reactions: TJSONObject);
    procedure OpenThread(ARootId: integer);
    procedure ClearThread;
    procedure ResetRequests;
    procedure Refresh; reintroduce;
    procedure MergeSync(Answer: TJSONObject);
    { The colors again, after the system's theme changed. }
    procedure Retheme;
    procedure PictureArrived(const URL: string);
    property AccountReady: boolean read FAccountReady write FAccountReady;
    property RootId: integer read FRootId;
    property SyncId: integer read GetSyncId;
    property OnConnectionAnswer: TInfoBarAnswerEvent read FOnConnectionAnswer write FOnConnectionAnswer;
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
    property OnLink: TLinkEvent read FOnLink write FOnLink;
    property OnPicture: TPictureEvent read FOnPicture write FOnPicture;
  end;

implementation

uses
  Graphics, Clipbrd, LazUTF8, LCLType, LCLIntf, InkMarkdown, DeskView, DeskKeys;

  {$R *.lfm}

constructor TThreadFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAccountReady := True;
  Shown := TJSONArray.Create;
  Previews := TPreviewState.Create;
  Attached := TJSONArray.Create;
  ReplyBase := ReplyPanel.Height;
  DropTarget := TCrossDragDropTarget.Create(Self);
  DropTarget.AcceptedFormats := [cdfFiles];
  DropTarget.OnDropFiles := @ReplyDropFiles;
  DropTarget.OnError := @DropError;
end;

procedure TThreadFrame.CodeButtonClick(Sender: TObject);
var
  At: integer;
  Sel: string;
begin
  At := ReplyBox.SelStart;
  Sel := ReplyBox.SelText;
  ReplyBox.SelText := '```' + LineEnding + Sel + LineEnding + '```';
  ReplyBox.SelStart := At + 3 + Length(LineEnding) + UTF8Length(Sel);
  ReplyBox.SetFocus;
end;

destructor TThreadFrame.Destroy;
begin
  ApiForgetReceiver(Self);
  DropTarget.Free;
  Shown.Free;
  FReactions.Free;
  Previews.Free;
  Attached.Free;
  inherited Destroy;
end;

procedure TThreadFrame.SetMember(const AName: string; CanReact, CanPin, CanDeleteAny, CanEditOwn, CanDeleteOwn: boolean; Reactions: TJSONObject);
begin
  FreeAndNil(FReactions);
  if Reactions <> nil then
    FReactions := TJSONObject(Reactions.Clone);
  FMyName := AName;
  FCanReact := CanReact;
  FCanPin := CanPin;
  FCanDeleteAny := CanDeleteAny;
  FCanEditOwn := CanEditOwn;
  FCanDeleteOwn := CanDeleteOwn;
end;

function TThreadFrame.GetSyncId: integer;
begin
  Result := 0;
  if Visible then
    Result := FRootId;
end;

procedure TThreadFrame.OpenThread(ARootId: integer);
begin
  if ARootId <= 0 then
    Exit;
  LoadThread(ARootId);
  Visible := True;
  // The frame has its parent window now; attaching creates a native handle.
  DropTarget.Control := ReplyBox;
  if ReplyBox.CanFocus then
    ReplyBox.SetFocus;
end;

procedure TThreadFrame.ClearThread;
begin
  ResetRequests;
  NoticeBar.Hide;
  NoticeToast.Hide;
  FRootId := 0;
  FRoom := '';
  MenuId := 0;
  StopEdit;
  WipeText(DraftBeforeEdit);
  ReplyBox.Clear;
  Attached.Clear;
  ShowAttached;
  Shown.Clear;
  Previews.Clear;
  Replies.Clear;
end;

procedure TThreadFrame.ResetRequests;
begin
  Inc(Generation);
  ApiForgetReceiver(Self);
  Sending := False;
  Uploading := 0;
  UpdateBusy;
end;

procedure TThreadFrame.Refresh;
begin
  if FRootId <> 0 then
    LoadThread(FRootId);
end;

procedure TThreadFrame.LoadThread(AId: integer);
begin
  if FRootId <> AId then
  begin
    ClearThread;
    FRootId := AId;
  end;
  ApiGetAsync('/api/thread?' + Query(['id', IntToStr(AId)]), @ThreadDone, Generation, 'thread');
end;

procedure TThreadFrame.ThreadDone(Job: TApiJob);
var
  List: TJSONArray;
  OldY: integer;
  Follow: boolean;
begin
  if Job.Tag <> Generation then Exit;
  try
    List := Job.ArrayJSON;
    try
      if List.Count = 0 then raise Exception.Create('That thread is gone.');
      OldY := Replies.ScrollY;
      Follow := (Shown.Count = 0) or (OldY >= Replies.ContentHeight - Replies.ClientHeight - 2);
      FRoom := TJSONObject(List[0]).Get('room', '');
      Shown.Free;
      Shown := List;
      List := nil;
      Render(Follow, OldY);
    finally
      List.Free;
    end;
  except
    on E: Exception do
      if not ApiErrorHandled(E) then NoticeBar.Show(E.Message, mtError, [], 'refresh');
  end;
end;

procedure TThreadFrame.ActionDone(Job: TApiJob);
begin
  if Job.Tag <> Generation then Exit;
  if Job.Error = '' then Refresh
  else if not Job.ErrorHandled then NoticeBar.Show(Job.Error, mtError, [], 'action');
end;

{ Replies are absent from the room's messages array. The thread array
  carries their edits, deletions and reactions as well as new replies. }
procedure TThreadFrame.MergeSync(Answer: TJSONObject);
var
  Item: TJSONEnum;
  Msg: TJSONObject;
  I, Id, OldY: integer;
  HasChanges, Follow: boolean;

  procedure Merge(List: TJSONArray);
  begin
    for Item in List do
    begin
      Msg := TJSONObject(Item.Value);
      Id := Msg.Get('id', 0);
      if (Id <> FRootId) and (Msg.Get('parent', 0) <> FRootId) then
        Continue;
      I := 0;
      while (I < Shown.Count) and (TJSONObject(Shown[I]).Get('id', 0) < Id) do
        Inc(I);
      if (I < Shown.Count) and (TJSONObject(Shown[I]).Get('id', 0) = Id) then
      begin
        if Msg.Get('rev', int64(0)) <= TJSONObject(Shown[I]).Get('rev', int64(0)) then
          Continue;
        Shown[I] := Msg.Clone;
      end
      else
        Shown.Insert(I, Msg.Clone);
      HasChanges := True;
    end;
  end;

begin
  if (SyncId = 0) or (Shown.Count = 0) then
    Exit;
  OldY := Replies.ScrollY;
  Follow := OldY >= Replies.ContentHeight - Replies.ClientHeight - 2;
  HasChanges := False;
  Merge(ArrayOf(Answer, 'messages'));
  Merge(ArrayOf(Answer, 'thread'));
  if HasChanges then
    Render(Follow, OldY);
end;

procedure TThreadFrame.AppendMessage(Msg: TJSONObject; Follows: boolean);
var
  Back: TColor;
  CopyMsg: TJSONObject;
begin
  Back := clNone;
  if Msg.Get('mentions_me', False) then
    Back := Mix(Replies.Color, clHighlight, 0.18);
  // The count below replaces the root's link to this same thread.
  CopyMsg := Msg.Clone as TJSONObject;
  try
    CopyMsg.Integers['replies'] := 0;
    Replies.AppendBlock(MessageHtml(CopyMsg, Follows, Previews.IsOpen(Msg), Previews.FocusId = Msg.Get('id', 0)), itfHTML, Back);
  finally
    CopyMsg.Free;
  end;
end;

procedure TThreadFrame.Retheme;
begin
  StripeMemo(Replies);
  SizeExpiryBox(FileExpiryBox);
  HeadRule.Pen.Color := Mix(Color, InkOf(TitleLabel.Font.Color), 0.2);
  HeadRule.Brush.Color := HeadRule.Pen.Color;
end;

procedure TThreadFrame.Render(Follow: boolean; OldY: integer);
var
  I, Count: integer;
  Before, Msg: TJSONObject;
begin
  Retheme;
  Replies.BeginUpdate;
  try
    Replies.Clear;
    TitleLabel.Caption := 'Thread by ' + TJSONObject(Shown[0]).Get('name', '') + ' in #' + FRoom;
    AppendMessage(TJSONObject(Shown[0]), False);
    Count := 0;
    for I := 1 to Shown.Count - 1 do
      if not TJSONObject(Shown[I]).Get('deleted', False) then
        Inc(Count);
    if Count = 1 then
      Replies.AppendBlock('<p class="replies">1 reply</p>', itfHTML)
    else
      Replies.AppendBlock('<p class="replies">' + IntToStr(Count) + ' replies</p>', itfHTML);
    Before := nil;
    for I := 1 to Shown.Count - 1 do
    begin
      Msg := TJSONObject(Shown[I]);
      AppendMessage(Msg, Continues(Before, Msg));
      Before := Msg;
    end;
  finally
    Replies.EndUpdate;
  end;
  if Follow then
    Replies.ScrollTo(MaxInt)
  else
    Replies.ScrollTo(OldY);
  Msg := FindMessage(EditingId);
  if (EditingId > 0) and ((Msg = nil) or Msg.Get('deleted', False)) then
    StopEdit;
end;

function TThreadFrame.FindMessage(Id: integer): TJSONObject;
var
  I: integer;
begin
  Result := nil;
  if Id = 0 then
    Exit;
  for I := 0 to Shown.Count - 1 do
    if TJSONObject(Shown[I]).Get('id', 0) = Id then
      Exit(TJSONObject(Shown[I]));
end;

function TThreadFrame.MenuMessage: TJSONObject;
begin
  Result := FindMessage(MenuId);
end;

function TThreadFrame.OwnMessage(Msg: TJSONObject): boolean;
begin
  Result := (Msg <> nil) and (FMyName <> '') and (Msg.Get('name', '') = FMyName) and not Msg.Get('deleted', False);
end;

procedure TThreadFrame.MessageMenuPopup(Sender: TObject);
var
  P: TPoint;
  Entry: integer;
  Msg: TJSONObject;
begin
  P := Replies.ScreenToClient(MessageMenu.PopupPoint);
  Entry := Replies.EntryAt(P.X, P.Y);
  MenuId := 0;
  // Entry 1 is the reply count, not a message.
  if Entry > 1 then
    Dec(Entry)
  else if Entry = 1 then
    Entry := -1;
  if (Entry >= 0) and (Entry < Shown.Count) then
    MenuId := TJSONObject(Shown[Entry]).Get('id', 0);
  Msg := MenuMessage;
  ReactItem.Enabled := (Msg <> nil) and not Msg.Get('deleted', False) and FCanReact;
  PinItem.Enabled := (Msg <> nil) and not Msg.Get('deleted', False) and FCanPin;
  PinItem.Caption := 'Pin';
  if (Msg <> nil) and Msg.Get('pinned', False) then
    PinItem.Caption := 'Unpin';
  CopyItem.Enabled := Msg <> nil;
  CopyLinkItem.Enabled := Msg <> nil;
  EditItem.Enabled := OwnMessage(Msg) and FCanEditOwn;
  DeleteItem.Enabled := (OwnMessage(Msg) and FCanDeleteOwn) or ((Msg <> nil) and not Msg.Get('deleted', False) and FCanDeleteAny);
  FillReactMenu(ReactItem, FReactions, Msg, @ReactClick);
end;

procedure TThreadFrame.ReactTo(Id: integer; const Reaction: string);
var
  Msg: TJSONObject;
begin
  if not FAccountReady then Exit;
  Msg := FindMessage(Id);
  if not FCanReact or (Msg = nil) or Msg.Get('deleted', False) or (Reaction = '') then
    Exit;
  ApiPostAsync('/api/react', ['id', IntToStr(Id), 'r', Reaction], @ActionDone, Generation);
end;

procedure TThreadFrame.ReactClick(Sender: TObject);
begin
  ReactTo(MenuId, TMenuItem(Sender).Caption);
end;

procedure TThreadFrame.PinItemClick(Sender: TObject);
var
  Msg: TJSONObject;
begin
  if not FAccountReady then Exit;
  Msg := MenuMessage;
  if not FCanPin or (Msg = nil) or Msg.Get('deleted', False) then
    Exit;
  ApiPostAsync('/api/pin', ['id', IntToStr(MenuId)], @ActionDone, Generation);
end;

procedure TThreadFrame.CopyItemClick(Sender: TObject);
begin
  if MenuMessage <> nil then
  begin
    Clipboard.AsText := MenuMessage.Get('body', '');
    NoticeToast.Show('Copied.');
  end;
end;

procedure TThreadFrame.EditItemClick(Sender: TObject);
begin
  if Sending then Exit;
  if not FCanEditOwn or not OwnMessage(MenuMessage) then
    Exit;
  if EditingId = 0 then
    DraftBeforeEdit := ReplyBox.Text;
  EditingId := MenuId;
  ReplyBox.Text := MenuMessage.Get('body', '');
  ReplyBox.SelStart := UTF8Length(ReplyBox.Text);
  EditLabel.Caption := 'Editing your message. Esc stops.';
  EditLabel.Visible := True;
  ReplyPanel.Height := ReplyBase + AttachRow.Height + EditLabel.Height;
  ReplyButton.Caption := 'Save';
  AttachButton.Enabled := False;
  ReplyBox.SetFocus;
end;

procedure TThreadFrame.CopyLinkItemClick(Sender: TObject);
begin
  if MenuMessage <> nil then
  begin
    Clipboard.AsText := MessageLink(Server, MenuMessage.Get('id', 0));
    NoticeToast.Show('Link copied.');
  end;
end;

procedure TThreadFrame.StopEdit;
begin
  if EditingId > 0 then
  begin
    ReplyBox.Text := DraftBeforeEdit;
    ReplyBox.SelStart := UTF8Length(ReplyBox.Text);
  end;
  EditingId := 0;
  DraftBeforeEdit := '';
  EditLabel.Visible := False;
  ReplyPanel.Height := ReplyBase + AttachRow.Height;
  ReplyButton.Caption := 'Reply';
  AttachButton.Enabled := True;
end;

procedure TThreadFrame.DeleteItemClick(Sender: TObject);
var
  Msg: TJSONObject;
  Id, Epoch: integer;
begin
  if not FAccountReady then Exit;
  Msg := MenuMessage;
  if (Msg = nil) or Msg.Get('deleted', False) or not ((OwnMessage(Msg) and FCanDeleteOwn) or FCanDeleteAny) then
    Exit;
  Id := MenuId;
  Epoch := ApiEpoch;
  if MessageDlg('Delete this message?', mtConfirmation, [mbYes, mbNo], 0, mbNo) <> mrYes then
    Exit;
  if Epoch <> ApiEpoch then
    Exit;
  ApiPostAsync('/api/delete', ['id', IntToStr(Id)], @ActionDone, Generation);
end;

procedure TThreadFrame.CloseButtonClick(Sender: TObject);
begin
  ClearThread;
  if Assigned(FOnClose) then
    FOnClose(Self);
end;

procedure TThreadFrame.RepliesLinkClick(Sender: TObject; LineIndex: integer; const LinkName: string);
var
  Emoji: string;
  Msg: TJSONObject;
  OldY, Id: integer;
begin
  // an address from the server's HTML carries the path the site sits under: handled without it
  if SiteLocal(LinkName) <> LinkName then
  begin
    RepliesLinkClick(Sender, LineIndex, SiteLocal(LinkName));
    Exit;
  end;
  if LinkName.StartsWith('preview:') then
  begin
    Msg := FindMessage(StrToIntDef(Copy(LinkName, 9, MaxInt), 0));
    if Msg <> nil then
    begin
      OldY := Replies.ScrollY;
      Previews.Toggle(Msg);
      Render(False, OldY);
    end;
  end
  else if LinkName.StartsWith('react:') then
  begin
    Emoji := ReactionOfLink(Shown, LinkName, Id);
    ReactTo(Id, Emoji);
  end
  else if Assigned(FOnLink) then
    FOnLink(LinkName);
end;

procedure TThreadFrame.RepliesKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
var
  I, B, Entry: integer;
  Preview: TJSONObject;
begin
  if (Shift = [ssAlt]) and ((Key = VK_DOWN) or (Key = VK_UP)) then
  begin
    I := Previews.Step(Shown, Key = VK_UP);
    if I >= 0 then
    begin
      Render(False, Replies.ScrollY);
      Entry := I;
      if I > 0 then
        Inc(Entry);
      for B := 0 to Replies.BlockCount - 1 do
        if Replies.Block(B).Entry = Entry then
        begin
          Replies.ScrollTo(Replies.Block(B).Bounds.Top);
          Break;
        end;
    end;
    Key := 0;
  end
  else if (Shift = []) and ((Key = VK_RETURN) or (Key = VK_SPACE)) and (Previews.FocusId > 0) then
  begin
    RepliesLinkClick(Sender, -1, 'preview:' + IntToStr(Previews.FocusId));
    Key := 0;
  end
  else if (Shift = [ssCtrl]) and (Key = VK_RETURN) then
  begin
    Preview := PreviewOf(FindMessage(Previews.FocusId));
    if Preview <> nil then
      OpenURL(Preview.Get('url', ''));
    Key := 0;
  end;
end;

procedure TThreadFrame.RepliesResource(Sender: TObject; const URL: string; Destination: TStream; var Handled: boolean);
begin
  // an address from the server's HTML carries the path the site sits under: handled without it
  if SiteLocal(URL) <> URL then
  begin
    RepliesResource(Sender, SiteLocal(URL), Destination, Handled);
    Exit;
  end;
  if Assigned(FOnPicture) then
    FOnPicture(URL, Destination, Handled);
end;

procedure TThreadFrame.PictureArrived(const URL: string);
begin
  Replies.ResourceChanged(URL);
end;

procedure TThreadFrame.ReplyBoxKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
begin
  if Key = 27 then
  begin
    Key := 0;
    if EditingId > 0 then
      StopEdit
    else
      CloseButtonClick(Sender);
    Exit;
  end;
  if Key <> 13 then
    Exit;
  Key := 0;
  if (ssShift in Shift) or InCodeFence(ReplyBox.Text, ReplyBox.SelStart) then
    ReplyBox.SelText := LineEnding
  else
    ReplyButtonClick(Sender);
end;

procedure TThreadFrame.NoticeAnswer(Sender: TObject; const Key: string; Answer: TModalResult);
begin
  if (Key = 'connection') and Assigned(FOnConnectionAnswer) then
    FOnConnectionAnswer(Sender, Key, Answer)
  else if (Key = 'send') and (Answer = mrRetry) and (RetryRoot = FRootId) and (RetryEpoch = ApiEpoch) then ReplyButtonClick(nil);
end;

procedure TThreadFrame.UpdateBusy;
begin
  ReplyButton.Enabled := not Sending and (Uploading = 0);
  ReplyBox.ReadOnly := Sending;
  CodeButton.Enabled := not Sending;
  AttachRow.Enabled := not Sending;
  AttachButton.Enabled := not Sending and (EditingId = 0);
end;

procedure TThreadFrame.ReplyButtonClick(Sender: TObject);
begin
  if not FAccountReady or Sending or (Uploading > 0) or (FRoom = '') then Exit;
  if (FRootId = 0) or ((Trim(ReplyBox.Text) = '') and ((Attached.Count = 0) or (EditingId > 0))) then Exit;
  Sending := True;
  SentEdit := EditingId;
  UpdateBusy;
  if EditingId > 0 then
    ApiPostAsync('/api/edit', ['id', IntToStr(EditingId), 'body', ReplyBox.Text], @SendDone, Generation)
  else
    ApiPostAsync('/api/post', ['room', FRoom, 'parent', IntToStr(FRootId), 'body', ReplyBox.Text, 'files', AttachedTokens(Attached)], @SendDone, Generation);
end;

procedure TThreadFrame.SendDone(Job: TApiJob);
begin
  if Job.Tag <> Generation then Exit;
  Sending := False;
  UpdateBusy;
  if Job.Error <> '' then
  begin
    RetryRoot := FRootId;
    RetryEpoch := ApiEpoch;
    if not Job.ErrorHandled then
      NoticeBar.ShowQuestion('The message was not sent. Your text and files are still in the box. ' + Job.Error,
        mtError, [mrRetry, 'Send again'], 'send');
    Exit;
  end;
  if SentEdit > 0 then
  begin
    if EditingId = SentEdit then StopEdit;
  end
  else
  begin
    ReplyBox.Clear;
    Attached.Clear;
    ShowAttached;
  end;
  NoticeBar.Hide('send');
  Refresh;
end;

procedure TThreadFrame.ShowAttached;
begin
  AttachRow.Caption := AttachedHtml(Attached);
  if Attached.Count = 0 then
    AttachRow.Height := 0
  else
    AttachRow.Height := 24;
  AttachButton.Caption := AttachCaption(Attached);
  ReplyPanel.Height := ReplyBase + AttachRow.Height;
  if EditingId > 0 then
    ReplyPanel.Height := ReplyPanel.Height + EditLabel.Height;
end;

procedure TThreadFrame.AttachRowLink(Sender: TObject; const LinkName: string);
var
  I: integer;
begin
  if Sending then Exit;
  if not LinkName.StartsWith('drop:') then
    Exit;
  I := StrToIntDef(Copy(LinkName, 6, MaxInt), -1);
  if (I >= 0) and (I < Attached.Count) then
    Attached.Delete(I);
  ShowAttached;
  if ReplyBox.CanFocus then
    ReplyBox.SetFocus;
end;

procedure TThreadFrame.AttachFile(const FileName: string);
var
  Data: TBytesStream;
begin
  if not FAccountReady or Sending then Exit;
  if (FRootId = 0) or (EditingId > 0) then
    Exit;
  Data := TBytesStream.Create;
  try
    try
      Data.LoadFromFile(FileName);
      ApiUploadAsync(ExtractFileName(FileName), Data, False, False, ExpiryValue(FileExpiryBox.ItemIndex), '', @UploadDone, Generation);
      Inc(Uploading);
      UpdateBusy;
    except
      on E: Exception do
        if not ApiErrorHandled(E) then NoticeBar.Show(E.Message, mtError, [], 'attachfile');
    end;
  finally
    Data.Free;
  end;
end;

procedure TThreadFrame.UploadDone(Job: TApiJob);
begin
  if Job.Tag <> Generation then Exit;
  Dec(Uploading);
  UpdateBusy;
  try
    Attached.Add(Job.ObjectJSON);
    ShowAttached;
  except
    on E: Exception do
      if not ApiErrorHandled(E) then NoticeBar.Show(E.Message, mtError, [], 'attachfile');
  end;
end;

procedure TThreadFrame.AttachButtonClick(Sender: TObject);
var
  Path: string;
  Target: TApiTarget;
  Root: integer;
begin
  Target := ApiTarget;
  Root := FRootId;
  if OpenDialog1.Execute and ApiTargetCurrent(Target) and (Root = FRootId) then
    for Path in OpenDialog1.Files do
      AttachFile(Path);
  if ReplyBox.CanFocus then
    ReplyBox.SetFocus;
end;

procedure TThreadFrame.ReplyDropFiles(Sender: TObject; Files: TStrings; X, Y: integer);
var
  Path: string;
begin
  for Path in Files do
    AttachFile(Path);
  if ReplyBox.CanFocus then
    ReplyBox.SetFocus;
end;

procedure TThreadFrame.DropError(Sender: TObject; const Message: string);
begin
  ReplyBox.Hint := 'Dropping files: ' + Message;
  ReplyBox.ShowHint := True;
end;

end.
