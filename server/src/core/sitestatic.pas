unit SiteStatic;

{ Serve static folders without per-request shared state. FPC's file module
  keeps request helpers in an unlocked list; this unit shares only folders
  registered before the server starts. }

{$mode objfpc}{$H+}

interface

{ Serves the files under Directory at /Location/<path>.  Call before the
  server starts taking requests. }
procedure ServeFolder(const Location, Directory: string);

var
  { The ?v= the server's pages put on /static addresses now; files no
    newer than the server's start are the same bytes at that address. }
  CurrentVersion: function: string = nil;

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
  ZipBytes: int64 = 0;
  StartedAge: longint;

const
  { Larger files go out as they are; the kept gzip forms stay under a budget. }
  ZipLimit = 2 * 1024 * 1024;
  ZipBudget = 32 * 1024 * 1024;

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

{ The gzip form of a file, made once and kept until the file changes. One
  request compresses it while the others wait for that one. }
function GzipOf(const Name: string; Age: longint; Size: int64): TBytes;
var
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
  ZipLock.Enter;
  try
    Index := Zips.IndexOf(Name);
    if Index >= 0 then
    begin
      Entry := TZipped(Zips.Objects[Index]);
      if (Entry.Age = Age) and (Entry.Size = Size) then
        Exit(Entry.Bytes);
    end;
    Raw := TBytesStream.Create;
    Deflated := TMemoryStream.Create;
    try
      Raw.LoadFromFile(Name);
      Size := Raw.Size;
      Deflated.WriteBuffer(Head, SizeOf(Head));
      Z := TCompressionStream.Create(clMax, Deflated, True);
      try
        if Size > 0 then
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
      Raw.Free;
    end;
    // over the budget, the kept forms are dropped and made again as asked for
    if ZipBytes + Length(Result) > ZipBudget then
    begin
      Zips.Clear;
      ZipBytes := 0;
    end;
    Index := Zips.IndexOf(Name);
    if Index < 0 then
      Index := Zips.AddObject(Name, TZipped.Create)
    else
      Dec(ZipBytes, Length(TZipped(Zips.Objects[Index]).Bytes));
    Entry := TZipped(Zips.Objects[Index]);
    Entry.Age := Age;
    Entry.Size := Size;
    Entry.Bytes := Result;
    Inc(ZipBytes, Length(Result));
  finally
    ZipLock.Leave;
  end;
end;

{ A file's time for Last-Modified. }
function HttpTime(Age: longint): string;
begin
  Result := FormatDateTime('ddd, dd mmm yyyy hh:nn:ss', LocalTimeToUniversal(FileDateToDateTime(Age)), DefaultFormatSettings) + ' GMT';
end;

procedure SendFile(ARequest: TRequest; AResponse: TResponse);
var
  Name: string;
  F: TFileStream;
  Zipped: TBytes;
  Body: TBytesStream;
  Found: TSearchRec;
  Age: longint;
  Size: int64;
  Version, Stamp: string;
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
  if FindFirst(Name, faAnyFile, Found) <> 0 then
  begin
    AResponse.Code := 404;
    AResponse.SendContent;
    Exit;
  end;
  Age := FileAge(Name);
  Size := Found.Size;
  FindClose(Found);
  // Kept for a year only at an address that names these very bytes: the file's own
  // age, or this start's version for a file no newer than the start. Else asked again.
  Version := ARequest.QueryFields.Values['v'];
  if (Version <> '') and ((Version = IntToStr(Age)) or (Assigned(CurrentVersion) and (Version = CurrentVersion()) and (Age <= StartedAge))) then
    AResponse.SetCustomHeader('Cache-Control', 'public, max-age=31536000, immutable')
  else
    AResponse.SetCustomHeader('Cache-Control', 'no-cache');
  Stamp := HttpTime(Age);
  AResponse.SetCustomHeader('Last-Modified', Stamp);
  if Trim(ARequest.GetFieldByName(HeaderIfModifiedSince)) = Stamp then
  begin
    AResponse.Code := 304;
    AResponse.SendContent;
    Exit;
  end;
  if Compressible(Name) and (Size <= ZipLimit) then
  begin
    AResponse.SetCustomHeader('Vary', 'Accept-Encoding');
    if Pos('gzip', LowerCase(ARequest.GetHeader(hhAcceptEncoding))) > 0 then
    begin
      Zipped := GzipOf(Name, Age, Size);
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
  StartedAge := DateTimeToFileDate(Now);

finalization
  Folders.Free;
  Zips.Free;
  ZipLock.Free;
end.
