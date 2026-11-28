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
  Classes, SysUtils, SyncObjs, httpdefs, httpprotocol, httproute, fpmimetypes, zstream, crc;

type
  { A file kept compressed, and the file's time and size it was made from. }
  TZipped = class
    Age: longint;
    Size: int64;
    Bytes: TBytes;
  end;

var
  Folders: TStringList;
  Zips: TStringList;
  ZipLock: TCriticalSection;

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

{ Text files are sent gzipped to a browser that takes it. }
function Compressible(const Name: string): boolean;
begin
  Result := Pos(' ' + LowerCase(ExtractFileExt(Name)) + ' ', ' .js .css .svg .txt .json .html .xml .md ') > 0;
end;

{ The gzip form of a file, made once and kept until the file changes. }
function GzipOf(const Name: string): TBytes;
var
  Age: longint;
  Size: int64;
  Index: integer;
  Entry: TZipped;
  Raw: TBytesStream;
  Deflated: TMemoryStream;
  Z: TCompressionStream;
  Sum: cardinal;
  Tail: array[0..7] of byte;
const
  Head: array[0..9] of byte = ($1F, $8B, 8, 0, 0, 0, 0, 0, 0, 255);
begin
  Age := FileAge(Name);
  Raw := TBytesStream.Create;
  try
    Raw.LoadFromFile(Name);
    Size := Raw.Size;
    ZipLock.Enter;
    try
      Index := Zips.IndexOf(Name);
      if Index >= 0 then
      begin
        Entry := TZipped(Zips.Objects[Index]);
        if (Entry.Age = Age) and (Entry.Size = Size) then
          Exit(Entry.Bytes);
      end;
    finally
      ZipLock.Leave;
    end;
    Deflated := TMemoryStream.Create;
    try
      Deflated.WriteBuffer(Head, SizeOf(Head));
      Z := TCompressionStream.Create(clMax, Deflated, True);
      try
        Z.WriteBuffer(Raw.Bytes[0], Size);
      finally
        Z.Free;
      end;
      Sum := crc32(0, nil, 0);
      if Size > 0 then
        Sum := crc32(Sum, @Raw.Bytes[0], Size);
      Tail[0] := Sum and $FF;
      Tail[1] := (Sum shr 8) and $FF;
      Tail[2] := (Sum shr 16) and $FF;
      Tail[3] := Sum shr 24;
      Tail[4] := Size and $FF;
      Tail[5] := (Size shr 8) and $FF;
      Tail[6] := (Size shr 16) and $FF;
      Tail[7] := (Size shr 24) and $FF;
      Deflated.WriteBuffer(Tail, SizeOf(Tail));
      SetLength(Result, Deflated.Size);
      if Deflated.Size > 0 then
        Move(Deflated.Memory^, Result[0], Deflated.Size);
    finally
      Deflated.Free;
    end;
  finally
    Raw.Free;
  end;
  ZipLock.Enter;
  try
    Index := Zips.IndexOf(Name);
    if Index < 0 then
      Index := Zips.AddObject(Name, TZipped.Create);
    Entry := TZipped(Zips.Objects[Index]);
    Entry.Age := Age;
    Entry.Size := Size;
    Entry.Bytes := Result;
  finally
    ZipLock.Leave;
  end;
end;

procedure SendFile(ARequest: TRequest; AResponse: TResponse);
var
  Name: string;
  F: TFileStream;
  Zipped: TBytes;
  Body: TBytesStream;
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
  // a page asks for its scripts and styles with ?v=<version>: that address never changes its content
  if ARequest.QueryFields.Values['v'] <> '' then
    AResponse.SetCustomHeader('Cache-Control', 'public, max-age=31536000, immutable')
  else
    AResponse.SetCustomHeader('Cache-Control', 'no-cache');
  if Compressible(Name) then
  begin
    AResponse.SetCustomHeader('Vary', 'Accept-Encoding');
    if Pos('gzip', LowerCase(ARequest.GetHeader(hhAcceptEncoding))) > 0 then
    begin
      Zipped := GzipOf(Name);
      AResponse.SetCustomHeader('Content-Encoding', 'gzip');
      Body := TBytesStream.Create(Zipped);
      try
        AResponse.ContentStream := Body;
        AResponse.SendContent;
        AResponse.ContentStream := nil;
        AResponse.ContentLength := Length(Zipped);
      finally
        Body.Free;
      end;
      Exit;
    end;
  end;
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
  Zips := TStringList.Create;
  Zips.CaseSensitive := True;
  Zips.OwnsObjects := True;
  ZipLock := TCriticalSection.Create;

finalization
  Folders.Free;
  Zips.Free;
  ZipLock.Free;
end.
