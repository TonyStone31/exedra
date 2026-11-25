unit SiteStatic;

{ Serve static folders without per-request shared state. FPC's file module
  keeps request helpers in an unlocked list; this unit shares only folders
  registered before the server starts. }

{$mode objfpc}{$H+}

interface

{ Serves the files under Directory at /Location/<path>.  Call before the
  server starts taking requests. }
procedure ServeFolder(const Location, Directory: string);

implementation

uses
  Classes, SysUtils, httpdefs, httproute, fpmimetypes;

var
  Folders: TStringList;

{ A path with its %XX turned back into bytes, or '' when one is not two
  hex digits.  A plus sign stays a plus sign, as it is in a path. }
function Unescaped(const Path: string): string;
var
  I, B: integer;
begin
  Result := '';
  I := 1;
  while I <= Length(Path) do
  begin
    if Path[I] <> '%' then
      Result := Result + Path[I]
    else
    begin
      if not TryStrToInt('$' + Copy(Path, I + 1, 2), B) or (I + 2 > Length(Path)) then
        Exit('');
      Result := Result + Chr(B);
      Inc(I, 2);
    end;
    Inc(I);
  end;
end;

{ The file a request path names, or '' when it names none we serve. }
function FileFor(const RequestPath: string): string;
var
  P: integer;
  Path, Dir, Name, Part: string;
begin
  Result := '';
  Path := Unescaped(RequestPath);
  if Path = '' then
    Exit;
  P := Pos('/', Path, 2);
  if (P = 0) or (Path[1] <> '/') then
    Exit;
  Dir := Folders.Values[Copy(Path, 2, P - 2)];
  Name := Copy(Path, P + 1, MaxInt);
  if (Dir = '') or (Name = '') or (Pos('\', Name) > 0) or (Pos(#0, Name) > 0) then
    Exit;
  for Part in Name.Split(['/']) do
    if (Part = '') or (Part = '.') or (Part = '..') then
      Exit;
  if FileExists(Dir + Name) then
    Result := Dir + Name;
end;

procedure SendFile(ARequest: TRequest; AResponse: TResponse);
var
  Name: string;
  F: TFileStream;
begin
  if ARequest.Method <> 'GET' then
  begin
    AResponse.Code := 405;
    AResponse.SendContent;
    Exit;
  end;
  Name := FileFor(ARequest.PathInfo);
  if Name = '' then
  begin
    AResponse.Code := 404;
    AResponse.ContentType := 'text/plain; charset=utf-8';
    AResponse.Content := 'Not found';
    AResponse.SendContent;
    Exit;
  end;
  AResponse.ContentType := MimeTypes.GetMimeType(ExtractFileExt(Name));
  if AResponse.ContentType = '' then
    AResponse.ContentType := 'application/octet-stream';
  F := TFileStream.Create(Name, fmOpenRead or fmShareDenyWrite);
  try
    AResponse.ContentStream := F;
    AResponse.SendContent;
    AResponse.ContentStream := nil;
    // for the steps after the request, which log the size
    AResponse.ContentLength := F.Size;
  finally
    F.Free;
  end;
end;

procedure ServeFolder(const Location, Directory: string);
begin
  Folders.Values[Location] := IncludeTrailingPathDelimiter(Directory);
  HTTPRouter.RegisterRoute('/' + Location + '/*', rmAll, @SendFile);
end;

initialization
  Folders := TStringList.Create;
  Folders.CaseSensitive := True;

finalization
  Folders.Free;
end.
