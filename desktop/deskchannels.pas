unit DeskChannels;

{$mode objfpc}{$H+}

interface

uses
  InfoBar, Toast, Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls,
  Dialogs, fpjson, DeskNet;

type
  TChannelsForm = class(TForm)
    NoticeBar: TInfoBar;
    NoticeToast: TToast;
    Channels: TListView;
    Editor, Buttons: TPanel;
    PolicyLabel: TLabel;
    PolicyBox: TComboBox;
    ArchivedBox: TCheckBox;
    Topic: TMemo;
    Status: TMemo;
    TopicButton, IconButton, SaveButton, NewButton, RefreshButton, CloseButton: TButton;
    IconDialog: TOpenDialog;
    procedure FormDestroy(Sender: TObject);
    procedure SelectionChanged(Sender: TObject; Item: TListItem; Selected: boolean);
    procedure TopicClick(Sender: TObject);
    procedure IconClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure NewClick(Sender: TObject);
    procedure RefreshClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
  private
    Data: TJSONObject;
    Permissions: TStringList;
    Busy: boolean;
    Generation: integer;
    SelectedSlug, DraftTopic: string;
    function SelectedChannel: TJSONObject;
    procedure UpdateControls;
    procedure UpdateSelection;
    procedure ReadList;
    procedure ListDone(Job: TApiJob);
    procedure SaveDone(Job: TApiJob);
    procedure IconDone(Job: TApiJob);
  public
    OnNewChannel, OnChanged: TNotifyEvent;
    procedure Open(Can: TStrings);
    procedure Reset;
  end;

implementation

uses DeskStatus, DeskAdminLogic, DeskRoom, DeskView;

  {$R *.lfm}

procedure TChannelsForm.FormDestroy(Sender: TObject);
begin
  ApiForgetReceiver(Self);
  Channels.OnSelectItem := nil;
  Data.Free;
  Permissions.Free;
end;

procedure TChannelsForm.Reset;
begin
  Inc(Generation);
  ApiForgetReceiver(Self);
  Hide;
  NoticeBar.Hide;
  NoticeToast.Hide;
  Busy := False;
  Channels.Clear;
  FreeAndNil(Data);
  FreeAndNil(Permissions);
  SelectedSlug := '';
  DraftTopic := '';
  Topic.Clear;
  Status.Clear;
  UpdateControls;
end;

procedure TChannelsForm.Open(Can: TStrings);
begin
  if not AdminCan(Can, 'manage-channels') then Exit;
  Show;
  BringToFront;
  if Busy then Exit;
  if Permissions = nil then Permissions := TStringList.Create;
  Permissions.Assign(Can);
  ReadList;
end;

procedure TChannelsForm.ReadList;
begin
  if Busy or not AdminCan(Permissions, 'manage-channels') then Exit;
  Busy := True;
  UpdateControls;
  Status.Text := 'Reading public channels...';
  ApiGetAsync('/api/admin', @ListDone, Generation);
end;

procedure TChannelsForm.ListDone(Job: TApiJob);
var
  Answer, Channel: TJSONObject;
  Entry: TJSONEnum;
  Row: TListItem;
begin
  if Job.Tag <> Generation then Exit;
  Busy := False;
  Channels.OnSelectItem := nil;
  Channels.Items.BeginUpdate;
  try
    try
      Answer := Job.ObjectJSON;
      try
        Channels.Clear;
        FreeAndNil(Data);
        Data := TJSONObject.Create;
        Data.Add('channels', ArrayOf(Answer, 'channels').Clone);
      finally
        Answer.Free;
      end;
      for Entry in ArrayOf(Data, 'channels') do
      begin
        if not (Entry.Value is TJSONObject) then Continue;
        Channel := TJSONObject(Entry.Value);
        Row := Channels.Items.Add;
        Row.Data := Channel;
        Row.Caption := '#' + Channel.Get('slug', '');
        Row.SubItems.Add(Channel.Get('topic', ''));
        Row.SubItems.Add(ChannelPolicy(Channel.Get('policy', 'all')));
        if Channel.Get('archived', False) then Row.SubItems.Add('Yes')
        else
          Row.SubItems.Add('No');
        if Channel.Get('slug', '') = SelectedSlug then Row.Selected := True;
      end;
      Status.Text := Format('%d public channels.', [Channels.Items.Count]);
    except
      on E: Exception do
      begin
        Channels.Clear;
        FreeAndNil(Data);
        if not ApiErrorHandled(E) then Status.Text := E.Message;
      end;
    end;
  finally
    Channels.Items.EndUpdate;
    Channels.OnSelectItem := @SelectionChanged;
  end;
  UpdateSelection;
end;

function TChannelsForm.SelectedChannel: TJSONObject;
begin
  Result := nil;
  if Channels.Selected <> nil then Result := TJSONObject(Channels.Selected.Data);
end;

procedure TChannelsForm.UpdateControls;
var
  Allowed, Ready: boolean;
begin
  Allowed := AdminCan(Permissions, 'manage-channels');
  Ready := Allowed and (SelectedChannel <> nil) and not Busy;
  Editor.Visible := Allowed;
  Editor.Enabled := Ready;
  SaveButton.Visible := Allowed;
  SaveButton.Enabled := Ready;
  NewButton.Visible := AdminCan(Permissions, 'create-channel');
  NewButton.Enabled := not Busy;
  Channels.Enabled := not Busy;
  RefreshButton.Enabled := not Busy;
end;

procedure TChannelsForm.UpdateSelection;
var
  Channel: TJSONObject;
begin
  Channel := SelectedChannel;
  DraftTopic := '';
  PolicyBox.ItemIndex := 0;
  ArchivedBox.Checked := False;
  if Channel <> nil then
  begin
    SelectedSlug := Channel.Get('slug', '');
    DraftTopic := Channel.Get('topic', '');
    if Channel.Get('policy', 'all') = 'readonly' then PolicyBox.ItemIndex := 1;
    ArchivedBox.Checked := Channel.Get('archived', False);
  end;
  Topic.Text := DraftTopic;
  UpdateControls;
end;

procedure TChannelsForm.SelectionChanged(Sender: TObject; Item: TListItem; Selected: boolean);
begin
  UpdateSelection;
end;

procedure TChannelsForm.TopicClick(Sender: TObject);
var
  Value: string;
  AskedAt: integer;
begin
  if not SaveButton.Enabled then Exit;
  AskedAt := Generation;
  Value := DraftTopic;
  Busy := True;
  UpdateControls;
  if AskRoomTopic(SelectedSlug, Value) and (AskedAt = Generation) then
  begin
    DraftTopic := Value;
    Topic.Text := DraftTopic;
  end;
  if AskedAt <> Generation then Exit;
  Busy := False;
  UpdateControls;
end;

procedure TChannelsForm.IconClick(Sender: TObject);
var
  Stream: TFileStream;
  AskedAt: integer;
  Slug: string;
begin
  if not SaveButton.Enabled then Exit;
  AskedAt := Generation;
  Slug := SelectedSlug;
  if not IconDialog.Execute or (AskedAt <> Generation) then Exit;
  try
    Stream := TFileStream.Create(IconDialog.FileName, fmOpenRead or fmShareDenyWrite);
    try
      ApiUploadAsync(ExtractFileName(IconDialog.FileName), Stream, False, False, '', Slug, @IconDone, Generation);
    finally
      Stream.Free;
    end;
    Busy := True;
    UpdateControls;
  except
    on E: Exception do NoticeBar.Show(E.Message, mtError, [], 'iconclick');
  end;
end;

procedure TChannelsForm.IconDone(Job: TApiJob);
begin
  if Job.Tag <> Generation then Exit;
  Busy := False;
  UpdateControls;
  if Job.Error <> '' then
  begin
    if not Job.ErrorHandled then NoticeBar.Show(Job.Error, mtError, [], 'iconclick');
    Exit;
  end;
  Status.Text := 'Icon saved.';
  NoticeToast.Show('Saved.');
  if Assigned(OnChanged) then OnChanged(Self);
end;

procedure TChannelsForm.SaveClick(Sender: TObject);
var
  Policy: string;
begin
  if not SaveButton.Enabled then Exit;
  Policy := 'all';
  if PolicyBox.ItemIndex = 1 then Policy := 'readonly';
  Busy := True;
  UpdateControls;
  Status.Text := 'Saving channel...';
  AdminChannelSave(SelectedSlug, DraftTopic, Policy, ArchivedBox.Checked, @SaveDone, Generation);
end;

procedure TChannelsForm.SaveDone(Job: TApiJob);
begin
  if Job.Tag <> Generation then Exit;
  Busy := False;
  UpdateControls;
  if Job.Error <> '' then
  begin
    if Job.ErrorHandled then Exit;
    Status.Text := Job.Error;
    NoticeBar.Show(Job.Error, mtError, [], 'savedone');
    Exit;
  end;
  NoticeToast.Show('Saved.');
  if Job.Tag <> Generation then Exit;
  if Assigned(OnChanged) then OnChanged(Self);
  ReadList;
end;

procedure TChannelsForm.NewClick(Sender: TObject);
var
  AskedAt: integer;
begin
  if Busy or not AdminCan(Permissions, 'create-channel') then Exit;
  AskedAt := Generation;
  Busy := True;
  UpdateControls;
  if Assigned(OnNewChannel) then OnNewChannel(Self);
  if AskedAt <> Generation then Exit;
  Busy := False;
  ReadList;
end;

procedure TChannelsForm.RefreshClick(Sender: TObject);
begin
  ReadList;
end;

procedure TChannelsForm.CloseClick(Sender: TObject);
begin
  Close;
end;

end.
