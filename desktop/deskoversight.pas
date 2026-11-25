unit DeskOversight;

{ Private channel and conversation metadata for members with manage-private. }

{$mode objfpc}{$H+}

interface

uses
  InfoBar, Toast, Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Menus,
  fpjson, DeskNet;

type
  TPrivateDeleted = procedure(const Kind, Slug, NameA, NameB: string) of object;

  TOversightForm = class(TForm)
    NoticeBar: TInfoBar;
    NoticeToast: TToast;
    FilterPanel: TPanel;
    FilterLabel: TLabel;
    FilterEdit: TEdit;
    Pages: TPageControl;
    ChannelsPage, ConversationsPage: TTabSheet;
    Channels, Conversations: TListView;
    Details, Status: TMemo;
    Buttons: TPanel;
    RefreshButton, DeleteButton, CloseButton: TButton;
    RowMenu: TPopupMenu;
    DeleteItem: TMenuItem;
    procedure FormDestroy(Sender: TObject);
    procedure FilterChange(Sender: TObject);
    procedure SelectionChanged(Sender: TObject; Item: TListItem; Selected: boolean);
    procedure PageChanged(Sender: TObject);
    procedure ListMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
    procedure RefreshClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
  private
    Data: TJSONObject;
    Busy: boolean;
    Generation: integer;
    DeleteKind, DeleteSlug, DeleteA, DeleteB: string;
    Said: string;            // the server's answer to a delete, kept above the counts
    function SelectedRow: TJSONObject;
    procedure UpdateSelection;
    procedure FillLists;
    procedure ReadList;
    procedure ListDone(Job: TApiJob);
    procedure DeleteDone(Job: TApiJob);
  public
    OnDeleted: TPrivateDeleted;
    procedure Open;
    procedure Reset;
  end;

implementation

uses
  Dialogs, LazUTF8, DeskView;

  {$R *.lfm}

function LastActivity(Obj: TJSONObject): string;
var
  Stamp: TJSONData;
begin
  Result := 'None';
  Stamp := Obj.Find('last');
  if (Stamp = nil) or (Stamp.JSONType = jtNull) or (Stamp.AsString = '') then
    Exit;
  Result := FormatDateTime('ddd d mmm yyyy, h:nn am/pm', LocalTime(Stamp.AsString));
end;

function MemberNames(Obj: TJSONObject): string;
var
  Member: TJSONEnum;
begin
  Result := '';
  for Member in ArrayOf(Obj, 'members') do
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + Member.Value.AsString;
  end;
end;

procedure TOversightForm.FormDestroy(Sender: TObject);
begin
  ApiForgetReceiver(Self);
  Channels.OnSelectItem := nil;
  Conversations.OnSelectItem := nil;
  Pages.OnChange := nil;
  FilterEdit.OnChange := nil;
  Data.Free;
end;

procedure TOversightForm.Reset;
begin
  Inc(Generation);
  Hide;
  NoticeBar.Hide;
  NoticeToast.Hide;
  Busy := False;
  Channels.Clear;
  Conversations.Clear;
  FreeAndNil(Data);
  Details.Clear;
  Status.Clear;
  FilterEdit.Clear;
  UpdateSelection;
end;

procedure TOversightForm.Open;
begin
  Show;
  BringToFront;
  ReadList;
end;

procedure TOversightForm.CloseClick(Sender: TObject);
begin
  Close;
end;

procedure TOversightForm.RefreshClick(Sender: TObject);
begin
  Status.Clear;
  ReadList;
end;

procedure TOversightForm.ReadList;
begin
  if Busy then
    Exit;
  Busy := True;
  RefreshButton.Enabled := False;
  UpdateSelection;
  if Status.Text = '' then
    Status.Text := 'Reading private channels and conversations...';
  ApiGetAsync('/api/admin/private', @ListDone, Generation);
end;

procedure TOversightForm.ListDone(Job: TApiJob);
var
  Answer: TJSONObject;
begin
  if Job.Tag <> Generation then
    Exit;
  Busy := False;
  RefreshButton.Enabled := True;
  try
    Answer := Job.ObjectJSON;
    Channels.Clear;
    Conversations.Clear;
    Data.Free;
    Data := Answer;
    FillLists;
    Status.Text := Trim(Said + ' ' + Format('%d private channels. %d conversations (newest 1,000 at most).', [ArrayOf(Data, 'channels').Count,
      ArrayOf(Data, 'conversations').Count]));
    Said := '';
  except
    on E: Exception do
    begin
      Channels.Clear;
      Conversations.Clear;
      FreeAndNil(Data);
      if not ApiErrorHandled(E) then Status.Text := E.Message;
    end;
  end;
  UpdateSelection;
end;

procedure TOversightForm.FilterChange(Sender: TObject);
begin
  FillLists;
end;

procedure TOversightForm.FillLists;
var
  Entry: TJSONEnum;
  Obj: TJSONObject;
  Row: TListItem;
  Needle, Names, SearchText: string;
begin
  Channels.Items.BeginUpdate;
  Conversations.Items.BeginUpdate;
  try
    Channels.Clear;
    Conversations.Clear;
    if Data <> nil then
    begin
      Needle := UTF8LowerCase(Trim(FilterEdit.Text));
      for Entry in ArrayOf(Data, 'channels') do
      begin
        Obj := TJSONObject(Entry.Value);
        Names := MemberNames(Obj);
        SearchText := Obj.Get('slug', '') + ' ' + Obj.Get('title', '') + ' ' + Obj.Get('owner', '') + ' ' + Names;
        if (Needle <> '') and (Pos(Needle, UTF8LowerCase(SearchText)) = 0) then
          Continue;
        Row := Channels.Items.Add;
        Row.Data := Obj;
        Row.Caption := '#' + Obj.Get('slug', '');
        Row.SubItems.Add(Obj.Get('owner', ''));
        if Names = '' then
          Row.SubItems.Add('Nobody')
        else
          Row.SubItems.Add(IntToStr(ArrayOf(Obj, 'members').Count) + ': ' + Names);
        Row.SubItems.Add(IntToStr(Obj.Get('messages', 0)));
        Row.SubItems.Add(LastActivity(Obj));
        if Obj.Get('archived', False) then
          Row.SubItems.Add('Yes')
        else
          Row.SubItems.Add('No');
      end;
      for Entry in ArrayOf(Data, 'conversations') do
      begin
        Obj := TJSONObject(Entry.Value);
        SearchText := Obj.Get('a', '') + ' ' + Obj.Get('b', '');
        if (Needle <> '') and (Pos(Needle, UTF8LowerCase(SearchText)) = 0) then
          Continue;
        Row := Conversations.Items.Add;
        Row.Data := Obj;
        Row.Caption := Obj.Get('a', '') + ' and ' + Obj.Get('b', '');
        Row.SubItems.Add(IntToStr(Obj.Get('messages', 0)));
        Row.SubItems.Add(LastActivity(Obj));
        if Obj.Get('locked', False) then
          Row.SubItems.Add('Locked')
        else
          Row.SubItems.Add('Plain');
      end;
    end;
  finally
    Conversations.Items.EndUpdate;
    Channels.Items.EndUpdate;
  end;
  UpdateSelection;
end;

function TOversightForm.SelectedRow: TJSONObject;
var
  Row: TListItem;
begin
  if Pages.ActivePage = ChannelsPage then
    Row := Channels.Selected
  else
    Row := Conversations.Selected;
  Result := nil;
  if Row <> nil then
    Result := TJSONObject(Row.Data);
end;

procedure TOversightForm.UpdateSelection;
var
  Obj: TJSONObject;
  Row: TListItem;
  I: integer;
begin
  Obj := SelectedRow;
  DeleteButton.Enabled := (Obj <> nil) and not Busy;
  DeleteItem.Enabled := DeleteButton.Enabled;
  Details.Clear;
  if Obj = nil then
    Details.Text := 'Select a row to see its details. Scroll across the list for more columns.'
  else
  begin
    if Pages.ActivePage = ChannelsPage then
      Row := Channels.Selected
    else
      Row := Conversations.Selected;
    Details.Lines.Add(Row.Caption);
    for I := 0 to Row.SubItems.Count - 1 do
      Details.Lines.Add(TListView(Row.ListView).Columns[I + 1].Caption + ': ' + Row.SubItems[I]);
  end;
end;

procedure TOversightForm.SelectionChanged(Sender: TObject; Item: TListItem; Selected: boolean);
begin
  UpdateSelection;
end;

procedure TOversightForm.PageChanged(Sender: TObject);
begin
  UpdateSelection;
end;

procedure TOversightForm.ListMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  if Button = mbRight then
  begin
    TListView(Sender).Selected := TListView(Sender).GetItemAt(X, Y);
    UpdateSelection;
  end;
end;

procedure TOversightForm.DeleteClick(Sender: TObject);
var
  Obj: TJSONObject;
  Words: string;
  AskedAt: integer;
begin
  if Busy then
    Exit;
  Obj := SelectedRow;
  if Obj = nil then
    Exit;
  DeleteSlug := '';
  DeleteA := '';
  DeleteB := '';
  if Pages.ActivePage = ChannelsPage then
  begin
    DeleteKind := 'channel';
    DeleteSlug := Obj.Get('slug', '');
    Words := 'Delete private channel #' + DeleteSlug + ' with all its messages, threads, files and memberships?';
  end
  else
  begin
    DeleteKind := 'conversation';
    DeleteA := Obj.Get('a', '');
    DeleteB := Obj.Get('b', '');
    Words := 'Delete every message and file in the conversation between ' + DeleteA + ' and ' + DeleteB + ', for both members?';
  end;
  AskedAt := Generation;
  Busy := True;
  RefreshButton.Enabled := False;
  UpdateSelection;
  if MessageDlg(Words + LineEnding + LineEnding + 'This cannot be undone.', mtConfirmation, [mbYes, mbNo], 0, mbNo) <> mrYes then
  begin
    Busy := False;
    RefreshButton.Enabled := True;
    UpdateSelection;
    Exit;
  end;
  if AskedAt <> Generation then
    Exit;
  Status.Text := 'Deleting...';
  ApiPostAsync('/api/admin/private/delete', ['kind', DeleteKind, 'slug', DeleteSlug, 'a', DeleteA, 'b', DeleteB], @DeleteDone, Generation);
end;

procedure TOversightForm.DeleteDone(Job: TApiJob);
begin
  if Job.Tag <> Generation then
    Exit;
  Busy := False;
  RefreshButton.Enabled := True;
  UpdateSelection;
  if Job.Error <> '' then
  begin
    if Job.ErrorHandled then Exit;
    Status.Text := Job.Error;
    NoticeBar.Show(Job.Error, mtError, [], 'deletedone');
    Exit;
  end;
  Said := Trim(Job.Answer);
  Status.Text := Said;
  if Assigned(OnDeleted) then
    OnDeleted(DeleteKind, DeleteSlug, DeleteA, DeleteB);
  ReadList;
end;

end.
