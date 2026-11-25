unit DeskConfig;

{$mode objfpc}{$H+}

interface

function ConfigFile: string;
procedure OwnerOnly;
procedure PrepareConfig;
procedure ReadConnectionFile(const Path: string; out Server, Channel: string);
procedure SaveConnectionFile(const Path, Server, Channel: string);

implementation

uses
  Classes, SysUtils, IniFiles{$ifdef unix}, BaseUnix{$endif};

function ConfigFile: string;
begin
  Result := GetAppConfigDir(False) + 'exedra.ini';
end;

{ Sign-ins and their folder belong to the owner alone.
  Windows keeps the user's settings folder private. }
procedure OwnerOnly;
begin
  {$ifdef unix}
  FpChmod(ExcludeTrailingPathDelimiter(GetAppConfigDir(False)), &700);
  if FileExists(ConfigFile) then
    FpChmod(ConfigFile, &600);
  {$endif}
end;

procedure PrepareConfig;
begin
  if not ForceDirectories(GetAppConfigDir(False)) then
    raise Exception.Create('The settings folder could not be created.');
  OwnerOnly;
end;

procedure ReadConnectionFile(const Path: string; out Server, Channel: string);
begin
  with TIniFile.Create(Path) do
  try
    Server := ReadString('exedra', 'server', '');
    Channel := ReadString('exedra', 'channel', '');
  finally
    Free;
  end;
end;

procedure SaveConnectionFile(const Path, Server, Channel: string);
begin
  with TMemIniFile.Create(Path) do
  try
    Clear;
    WriteString('exedra', 'server', Server);
    if Channel <> '' then
      WriteString('exedra', 'channel', Channel);
    UpdateFile;
  finally
    Free;
  end;
end;

end.
