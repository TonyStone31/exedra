unit DeskAbout;

{ Help > About: the logo, what the program is, and the server it talks to. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ButtonPanel;

type
  TAboutForm = class(TForm)
    Logo: TImage;
    NameLabel: TLabel;
    WhatLabel: TLabel;
    ServerLabel: TLabel;
    ButtonPanel1: TButtonPanel;
    procedure FormCreate(Sender: TObject);
  end;

procedure ShowAbout(const Server: string);

implementation

{$R *.lfm}

procedure TAboutForm.FormCreate(Sender: TObject);
begin
  Logo.Picture.LoadFromResourceName(HInstance, 'LOGO');
  // Esc closes it too.
  ButtonPanel1.CloseButton.Cancel := True;
end;

procedure ShowAbout(const Server: string);
var
  F: TAboutForm;
begin
  F := TAboutForm.Create(Application);
  try
    if Server <> '' then
      F.ServerLabel.Caption := 'Signed in at ' + Server
    else
      F.ServerLabel.Caption := '';
    F.ShowModal;
  finally
    F.Free;
  end;
end;

end.
