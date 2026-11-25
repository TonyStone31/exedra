unit DeskRoom;

{ Room > New room: a name, a topic and whether it is private. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ButtonPanel;

type
  TRoomForm = class(TForm)
    NameLabel: TLabel;
    NameEdit: TEdit;
    TopicLabel: TLabel;
    TopicEdit: TEdit;
    PrivateBox: TCheckBox;
    ButtonPanel1: TButtonPanel;
    procedure NameEditChange(Sender: TObject);
  end;

{ Asks for a room; True with the fields filled in when the member said
  Open it.  CanPublic and CanPrivate are what the server lets this member
  open; the private box starts ticked unless only public is allowed. }
function AskNewRoom(CanPublic, CanPrivate: boolean; out Slug, Topic: string; out Private: boolean): boolean;
function AskRoomTopic(const Title: string; var Topic: string): boolean;

implementation

uses Dialogs;

  {$R *.lfm}

function AskRoomTopic(const Title: string; var Topic: string): boolean;
begin
  Result := InputQuery('Topic for #' + Title, 'What the channel is for:', Topic);
end;

{ The server wants lowercase letters, digits and hyphens; the field keeps
  to that as the web page does. }
procedure TRoomForm.NameEditChange(Sender: TObject);
var
  S: string;
  C: char;
  At: integer;
begin
  S := '';
  for C in LowerCase(NameEdit.Text) do
    if C in ['a'..'z', '0'..'9'] then
      S := S + C
    else if (S <> '') and (S[Length(S)] <> '-') then
      S := S + '-';
  if S <> NameEdit.Text then
  begin
    At := NameEdit.SelStart;
    NameEdit.Text := S;
    NameEdit.SelStart := At;
  end;
end;

function AskNewRoom(CanPublic, CanPrivate: boolean; out Slug, Topic: string; out Private: boolean): boolean;
var
  F: TRoomForm;
begin
  Result := False;
  F := TRoomForm.Create(Application);
  try
    F.PrivateBox.Checked := not CanPublic;
    F.PrivateBox.Enabled := CanPublic and CanPrivate;
    if F.ShowModal <> mrOk then
      Exit;
    Slug := Trim(F.NameEdit.Text).Trim(['-']);
    Topic := Trim(F.TopicEdit.Text);
    Private := F.PrivateBox.Checked;
    Result := Slug <> '';
  finally
    F.Free;
  end;
end;

end.
