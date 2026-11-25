unit DeskReport;

{ Report a problem, as the web page's bug button does: what the member
  writes and what the program knows go to the server (POST /api/bug), which
  keeps them for the admin page and mails whoever runs the site. }

{$mode objfpc}{$H+}

interface

uses
  InfoBar, Classes, SysUtils, Forms, Controls, StdCtrls, ButtonPanel, DeskNet;

type
  TReportForm = class(TForm)
    NoticeBar: TInfoBar;
    PromptLabel: TLabel;
    Words: TMemo;
    HintLabel: TLabel;
    ButtonPanel1: TButtonPanel;
    procedure FormCreate(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
  private
    FPage, FInfo: string;
    Target: TApiTarget;
    procedure Sent(Job: TApiJob);
  public
    destructor Destroy; override;
  end;

{ Shows the dialog and sends what was written.  Page says where the member
  was, Info what the program knows about itself. }
function ReportProblem(const Page, Info: string): boolean;

implementation

uses
  Dialogs;

  {$R *.lfm}

procedure TReportForm.FormCreate(Sender: TObject);
begin
  ButtonPanel1.OKButton.Caption := 'Send the report';
  // The dialog closes after the server accepts the report.
  ButtonPanel1.OKButton.ModalResult := mrNone;
end;

procedure TReportForm.OKButtonClick(Sender: TObject);
begin
  if not ApiTargetCurrent(Target) then Exit;
  if Trim(Words.Text) = '' then
  begin
    HintLabel.Caption := 'Say what went wrong, even in a few words.';
    Exit;
  end;
  if not ButtonPanel1.OKButton.Enabled then Exit;
  ButtonPanel1.OKButton.Enabled := False;
  Words.ReadOnly := True;
  ApiPostAsync('/api/bug', ['text', Words.Text, 'page', FPage, 'info', FInfo], @Sent);
end;

procedure TReportForm.Sent(Job: TApiJob);
begin
  if not ApiTargetCurrent(Target) then Exit;
  ButtonPanel1.OKButton.Enabled := True;
  Words.ReadOnly := False;
  if Job.Error = '' then ModalResult := mrOk
  else if not Job.ErrorHandled then NoticeBar.Show(Job.Error, mtError, [], 'report');
end;

destructor TReportForm.Destroy;
begin
  ApiForgetReceiver(Self);
  inherited Destroy;
end;

function ReportProblem(const Page, Info: string): boolean;
var
  F: TReportForm;
begin
  F := TReportForm.Create(Application);
  try
    F.FPage := Page;
    F.FInfo := Info;
    F.Target := ApiTarget;
    Result := F.ShowModal = mrOk;
  finally
    F.Free;
  end;
end;

end.
