program exedradesktop;

{ An Exedra chat client: the same conversations as the web page, as a
  native program. }

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces,
  SysUtils,
  Forms,
  DeskMain;

  {$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Title := 'Exedra';
  Application.Initialize;
  // Keep the settings folder tied to the executable name.
  OnGetApplicationName := nil;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
