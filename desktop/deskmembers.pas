unit DeskMembers;

{$mode objfpc}{$H+}

interface

uses
  InfoBar, Toast, Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls,
  CheckLst, fpjson, DeskNet;

type
  TMembersForm = class(TForm)
    NoticeBar: TInfoBar;
    NoticeToast: TToast;
    FilterPanel, Buttons, RolePanel: TPanel;
    FilterLabel, RoleLabel: TLabel;
    FilterEdit: TEdit;
    SearchButton, PreviousButton, NextButton, CloseButton, SaveRolesButton, BanButton: TButton;
    Members: TListView;
    Details, Status: TMemo;
    Roles: TCheckListBox;
    procedure FormDestroy(Sender: TObject);
    procedure SearchClick(Sender: TObject);
    procedure PreviousClick(Sender: TObject);
    procedure NextClick(Sender: TObject);
    procedure SelectionChanged(Sender: TObject; Item: TListItem; Selected: boolean);
    procedure SaveRolesClick(Sender: TObject);
    procedure BanClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
  private
    Data: TJSONObject;
    Permissions: TStringList;
    MyName, SelectedName: string;
    Busy: boolean;
    Generation, Page: integer;
    Total: int64;
    function SelectedMember: TJSONObject;
    procedure UpdateControls;
    procedure UpdateSelection;
    procedure ReadList;
    procedure RolesDone(Job: TApiJob);
    procedure ListDone(Job: TApiJob);
    procedure SaveDone(Job: TApiJob);
  public
    procedure Open(const SignedInName: string; Can: TStrings);
    procedure Reset;
  end;

implementation

uses
  Dialogs, DeskStatus, DeskAdminLogic, DeskView;

  {$R *.lfm}

procedure TMembersForm.FormDestroy(Sender: TObject);
begin
  ApiForgetReceiver(Self);
  Members.OnSelectItem := nil;
  Data.Free;
  Permissions.Free;
end;

procedure TMembersForm.Reset;
begin
  Inc(Generation);
  ApiForgetReceiver(Self);
  Hide;
  NoticeBar.Hide;
  NoticeToast.Hide;
  Busy := False;
  MyName := '';
  SelectedName := '';
  Members.Clear;
  FreeAndNil(Data);
  FreeAndNil(Permissions);
  Roles.Clear;
  FilterEdit.Clear;
  Details.Clear;
  Status.Clear;
  Page := 0;
  Total := 0;
  UpdateControls;
end;

procedure TMembersForm.Open(const SignedInName: string; Can: TStrings);
begin
  if not AdminCan(Can, 'view-admin') then Exit;
  Show;
  BringToFront;
  if Busy then Exit;
  MyName := SignedInName;
  if Permissions = nil then Permissions := TStringList.Create;
  Permissions.Assign(Can);
  if AdminCan(Permissions, 'view-member-addresses') then
    FilterLabel.Caption := 'Filter by the start of a member name or address'
  else
    FilterLabel.Caption := 'Filter by the start of a member name';
  Inc(Generation);
  Busy := True;
  Roles.Clear;
  UpdateControls;
  Status.Text := 'Reading member roles...';
  // The admin response is the existing source of assignable site roles.
  ApiGetAsync('/api/admin', @RolesDone, Generation);
end;

procedure TMembersForm.RolesDone(Job: TApiJob);
var
  Answer: TJSONObject;
  Entry: TJSONEnum;
begin
  if Job.Tag <> Generation then Exit;
  Busy := False;
  try
    Answer := Job.ObjectJSON;
    try
      for Entry in ArrayOf(Answer, 'roles') do
        if (Entry.Value is TJSONObject) and GiveableRole(TJSONObject(Entry.Value)) then
          Roles.Items.Add(TJSONObject(Entry.Value).Get('name', ''));
    finally
      Answer.Free;
    end;
    ReadList;
  except
    on E: Exception do
      if not ApiErrorHandled(E) then Status.Text := E.Message;
  end;
  UpdateControls;
end;

procedure TMembersForm.SearchClick(Sender: TObject);
begin
  if Busy then Exit;
  Page := 0;
  SelectedName := '';
  ReadList;
end;

procedure TMembersForm.PreviousClick(Sender: TObject);
begin
  if Busy or (Page = 0) then Exit;
  Dec(Page);
  SelectedName := '';
  ReadList;
end;

procedure TMembersForm.NextClick(Sender: TObject);
begin
  if Busy or (int64(Page + 1) * 50 >= Total) then Exit;
  Inc(Page);
  SelectedName := '';
  ReadList;
end;

procedure TMembersForm.ReadList;
begin
  if Busy or not AdminCan(Permissions, 'view-admin') then Exit;
  Busy := True;
  UpdateControls;
  Status.Text := 'Reading members...';
  ApiGetAsync(AdminMembersPath(FilterEdit.Text, Page), @ListDone, Generation);
end;

procedure TMembersForm.ListDone(Job: TApiJob);
var
  Answer, Member: TJSONObject;
  Entry: TJSONEnum;
  Row: TListItem;
begin
  if Job.Tag <> Generation then Exit;
  Busy := False;
  Members.OnSelectItem := nil;
  Members.Items.BeginUpdate;
  try
    try
      Answer := Job.ObjectJSON;
      Members.Clear;
      Data.Free;
      Data := Answer;
      Total := Data.Get('total', int64(0));
      for Entry in ArrayOf(Data, 'members') do
      begin
        if not (Entry.Value is TJSONObject) then Continue;
        Member := TJSONObject(Entry.Value);
        Row := Members.Items.Add;
        Row.Data := Member;
        Row.Caption := Member.Get('name', '');
        Row.SubItems.Add(Member.Get('roles', ''));
        if Member.Get('banned', False) then Row.SubItems.Add('Banned')
        else
          Row.SubItems.Add('Not banned');
        Row.SubItems.Add(IntToStr(Member.Get('posts', int64(0))));
        if Row.Caption = SelectedName then Row.Selected := True;
      end;
      Status.Text := Format('%d members match. Page %d. Showing %d members.', [Total, Page + 1, Members.Items.Count]);
    except
      on E: Exception do
      begin
        Members.Clear;
        FreeAndNil(Data);
        Total := 0;
        if not ApiErrorHandled(E) then Status.Text := E.Message;
      end;
    end;
  finally
    Members.Items.EndUpdate;
    Members.OnSelectItem := @SelectionChanged;
  end;
  UpdateSelection;
end;

function TMembersForm.SelectedMember: TJSONObject;
begin
  Result := nil;
  if Members.Selected <> nil then Result := TJSONObject(Members.Selected.Data);
end;

procedure TMembersForm.UpdateControls;
var
  Actions: TMemberActions;
  Member: TJSONObject;
  Who: string;
begin
  Member := SelectedMember;
  Who := '';
  if Member <> nil then Who := Member.Get('name', '');
  Actions := MemberActions(Permissions, MyName, Who);
  RolePanel.Visible := AdminCan(Permissions, 'manage-members');
  Roles.Enabled := Actions.Roles and not Busy;
  SaveRolesButton.Enabled := Roles.Enabled and (Roles.Items.Count > 0);
  BanButton.Visible := AdminCan(Permissions, 'ban');
  BanButton.Enabled := Actions.Ban and not Busy;
  BanButton.Caption := 'Ban...';
  if (Member <> nil) and Member.Get('banned', False) then BanButton.Caption := 'Lift the ban';
  SearchButton.Enabled := not Busy;
  FilterEdit.Enabled := not Busy;
  PreviousButton.Enabled := not Busy and (Page > 0);
  NextButton.Enabled := not Busy and (int64(Page + 1) * 50 < Total);
  Members.Enabled := not Busy;
end;

procedure TMembersForm.UpdateSelection;
var
  Member, Address: TJSONObject;
  Entry: TJSONEnum;
  I: integer;
begin
  Member := SelectedMember;
  Details.Clear;
  for I := 0 to Roles.Items.Count - 1 do Roles.Checked[I] := False;
  if Member = nil then
    Details.Text := 'Select a member to see account details.'
  else
  begin
    SelectedName := Member.Get('name', '');
    // Native text controls display member text without interpreting markup.
    Details.Lines.Add(SelectedName);
    Details.Lines.Add('Roles: ' + Member.Get('roles', ''));
    if Member.Get('banned', False) then Details.Lines.Add('Banned');
    Details.Lines.Add('Joined: ' + MemberDate(Member.Get('joined', '')));
    Details.Lines.Add('Last here: ' + MemberDate(Member.Get('seen', '')));
    Details.Lines.Add('Messages: ' + IntToStr(Member.Get('posts', int64(0))));
    if AdminCan(Permissions, 'view-member-addresses') and (Member.Find('addresses') is TJSONArray) then
    begin
      Details.Lines.Add(Format('Addresses: %d newest of %d', [ArrayOf(Member, 'addresses').Count, Member.Get('address_count', 0)]));
      for Entry in ArrayOf(Member, 'addresses') do
        if Entry.Value is TJSONObject then
        begin
          Address := TJSONObject(Entry.Value);
          Details.Lines.Add(Address.Get('ip', '') + '  Last here: ' + MemberDate(Address.Get('seen', '')) + '  Times: ' + IntToStr(Address.Get('times', int64(0))));
        end;
    end;
    for I := 0 to Roles.Items.Count - 1 do
      Roles.Checked[I] := MemberHasRole(Member.Get('roles', ''), Roles.Items[I]);
    if SameText(MyName, SelectedName) then
      Details.Lines.Add('Ask another admin to change your own account.');
  end;
  UpdateControls;
end;

procedure TMembersForm.SelectionChanged(Sender: TObject; Item: TListItem; Selected: boolean);
begin
  UpdateSelection;
end;

procedure TMembersForm.SaveRolesClick(Sender: TObject);
var
  Member: TJSONObject;
  Actions: TMemberActions;
  NewRoles: string;
  I: integer;
begin
  Member := SelectedMember;
  if Busy or (Member = nil) then Exit;
  Actions := MemberActions(Permissions, MyName, Member.Get('name', ''));
  if not Actions.Roles then Exit;
  NewRoles := Member.Get('roles', '');
  for I := 0 to Roles.Items.Count - 1 do
    NewRoles := SetMemberRole(NewRoles, Roles.Items[I], Roles.Checked[I]);
  Busy := True;
  UpdateControls;
  Status.Text := 'Saving roles...';
  AdminMemberRoles(Member.Get('name', ''), NewRoles, @SaveDone, Generation);
end;

procedure TMembersForm.BanClick(Sender: TObject);
var
  Member: TJSONObject;
  Actions: TMemberActions;
  Who: string;
  Banned: boolean;
  AskedAt: integer;
begin
  Member := SelectedMember;
  if Busy or (Member = nil) then Exit;
  Who := Member.Get('name', '');
  Actions := MemberActions(Permissions, MyName, Who);
  if not Actions.Ban then Exit;
  Banned := not Member.Get('banned', False);
  AskedAt := Generation;
  Busy := True;
  UpdateControls;
  if Banned and (MessageDlg('Ban ' + Who + '? They will be signed out and can only read.', mtConfirmation, [mbYes, mbNo], 0, mbNo) <> mrYes) then
  begin
    if AskedAt <> Generation then Exit;
    Busy := False;
    UpdateControls;
    Exit;
  end;
  if AskedAt <> Generation then Exit;
  Status.Text := 'Saving ban status...';
  AdminMemberBan(Who, Banned, @SaveDone, Generation);
end;

procedure TMembersForm.SaveDone(Job: TApiJob);
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
  ReadList;
end;

procedure TMembersForm.CloseClick(Sender: TObject);
begin
  Close;
end;

end.
