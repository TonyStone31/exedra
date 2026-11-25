unit WikiFiles;

{ Versioned wiki files, their pages and [[File:name]] rendering. Validate
  image types, strip camera metadata, track uses and provide upload,
  browsing and deletion pages. }

{$mode objfpc}{$H+}

interface

uses Classes;

type
  TWikiFile = record
    Name, Path, Sha1, Mime, Uploaded, Uploader, Description: string;
    Size: int64;
    Width, Height, UploadedBy, Version: integer;
  end;
  TWikiFileLookup = function(const FileName: string; out Info: TWikiFile): boolean;

function NormalizeFileName(const Proposed: string): string;
function WikiFilePath(const FileName: string): string;
function WikiFileUrl(const RelativePath: string): string;
function FilePageUrl(const FileName: string): string;
function ImageHeader(const Bytes: rawbytestring; out Mime: string; out Width, Height: integer): boolean;
function StripImageMetadata(const Bytes: rawbytestring; out Cleaned: rawbytestring): boolean;
function ImageExtensionMatches(const FileName, Mime: string): boolean;
{ Inner is the text between [[ and ]]. False means an ordinary page link. }
function FileLinkHtml(const Inner: string; out Html: string; Lookup: TWikiFileLookup = nil): boolean;
function LoadWikiFile(const FileName: string; out Info: TWikiFile): boolean;
{ One process at a time changes the files and their index. }
procedure LockFiles;
procedure UnlockFiles;

const
  MB = 1024 * 1024;
  MAX_UPLOAD_MB = 31;

var
  { The name shown for a file nobody here uploaded. }
  WikiNoUploader: string = '';

implementation

uses
  SysUtils, StrUtils, Math, md5, sha1, DateUtils, Variants, sqldb, fpjson, httpdefs, httproute,
  SiteDb, SiteUsers, SiteRoles, SiteFiles, SiteGuard, SiteMarkup, SiteScan, WebPages, SiteWords, Wiki, SiteSql, SiteParts;

{ The columns every reader of a file row asks for, in TWikiFile's order. }
function FileColumns: string;
begin
  Result := 'f.name, f.path, f.sha1, f.size, f.mime, f.width, f.height, f.uploaded_by, ' + SqlIsoTime('f.uploaded') +
    ', f.description, f.version, COALESCE(u.name, ' + QuotedStr(WikiNoUploader) + ')';
end;

function NormalizeFileName(const Proposed: string): string;
var
  C: char;
  U: unicodestring;
  I: integer;
begin
  Result := '';
  for C in Proposed do
    if (C in ['/', '\', ':', '|', '#', '<', '>', '[', ']', '%']) or (Ord(C) < 32) or (Ord(C) = 127) then
      Exit;
  U := UTF8Decode(Proposed);
  if UTF8Encode(U) <> Proposed then
    Exit;
  for I := 1 to Length(U) do
    if (Ord(U[I]) >= $80) and (Ord(U[I]) <= $9F) then
      Exit;
  Result := Trim(Proposed);
  Result := StringReplace(Result, ' ', '_', [rfReplaceAll]);
  while Pos('__', Result) > 0 do
    Result := StringReplace(Result, '__', '_', [rfReplaceAll]);
  while (Result <> '') and (Result[1] = '_') do
    Delete(Result, 1, 1);
  while (Result <> '') and (Result[Length(Result)] = '_') do
    SetLength(Result, Length(Result) - 1);
  if (Result = '') or (Result[1] = '.') or (Length(Result) > 240) or (Pos(#$E2#$80#$8E, Result) > 0) or (Pos(#$E2#$80#$8F, Result) > 0) then
    Exit('');
  U := UTF8Decode(Result);
  U[1] := UnicodeUpperCase(Copy(U, 1, 1))[1];
  Result := UTF8Encode(U);
end;

function WikiFilePath(const FileName: string): string;
var
  Digest: string;
begin
  Digest := MD5Print(MD5String(FileName));
  Result := Copy(Digest, 1, 1) + '/' + Copy(Digest, 1, 2) + '/' + FileName;
end;

function PathEncode(const S: string): string;
var
  C: char;
begin
  Result := '';
  for C in S do
    if C in ['a'..'z', 'A'..'Z', '0'..'9', '_', '-', '.', '/'] then
      Result := Result + C
    else
      Result := Result + '%' + IntToHex(Ord(C), 2);
end;

function WikiFileUrl(const RelativePath: string): string;
begin
  Result := '/wiki-images/' + PathEncode(RelativePath);
end;

function FilePageUrl(const FileName: string): string;
begin
  Result := '/wiki-file/' + PathEncode(FileName);
end;

function NumberAt(const S: rawbytestring; P, Count: integer; BigEndian: boolean): cardinal;
var
  I: integer;
begin
  Result := 0;
  if (P < 1) or (P + Count - 1 > Length(S)) then
    Exit;
  for I := 0 to Count - 1 do
    if BigEndian then
      Result := (Result shl 8) or Ord(S[P + I])
    else
      Result := Result or (cardinal(Ord(S[P + I])) shl (I * 8));
end;

function ImageHeader(const Bytes: rawbytestring; out Mime: string; out Width, Height: integer): boolean;
var
  P, N, Marker: integer;
  Bits: cardinal;
begin
  Mime := '';
  Width := 0;
  Height := 0;
  if (Length(Bytes) >= 33) and (Copy(Bytes, 1, 8) = #$89'PNG'#13#10#$1A#10) and (NumberAt(Bytes, 9, 4, True) = 13) and (Copy(Bytes, 13, 4) = 'IHDR') then
  begin
    Mime := 'image/png';
    if (NumberAt(Bytes, 17, 4, True) > High(integer)) or (NumberAt(Bytes, 21, 4, True) > High(integer)) then
      Exit(False);
    Width := NumberAt(Bytes, 17, 4, True);
    Height := NumberAt(Bytes, 21, 4, True);
  end
  else if (Length(Bytes) >= 13) and ((Copy(Bytes, 1, 6) = 'GIF87a') or (Copy(Bytes, 1, 6) = 'GIF89a')) then
  begin
    Mime := 'image/gif';
    Width := NumberAt(Bytes, 7, 2, False);
    Height := NumberAt(Bytes, 9, 2, False);
  end
  else if (Length(Bytes) >= 12) and (Copy(Bytes, 1, 3) = #$FF#$D8#$FF) then
  begin
    P := 3;
    while P + 3 <= Length(Bytes) do
    begin
      if Bytes[P] <> #$FF then
        Break;
      while (P <= Length(Bytes)) and (Bytes[P] = #$FF) do
        Inc(P);
      if P > Length(Bytes) then
        Break;
      Marker := Ord(Bytes[P]);
      Inc(P);
      if (Marker = $DA) or (Marker = $D9) then
        Break;
      if (Marker = $01) or ((Marker >= $D0) and (Marker <= $D7)) then
        Continue;
      N := NumberAt(Bytes, P, 2, True);
      if (N < 2) or (N > Length(Bytes) - P + 1) then
        Break;
      if (Marker >= $C0) and (Marker <= $CF) and not (Marker in [$C4, $C8, $CC]) and (N >= 8) then
      begin
        Mime := 'image/jpeg';
        Height := NumberAt(Bytes, P + 3, 2, True);
        Width := NumberAt(Bytes, P + 5, 2, True);
        Break;
      end;
      Inc(P, N);
    end;
  end
  else if (Length(Bytes) >= 20) and (Copy(Bytes, 1, 4) = 'RIFF') and (Copy(Bytes, 9, 4) = 'WEBP') and (int64(NumberAt(Bytes, 5, 4, False)) + 8 = Length(Bytes)) then
  begin
    P := 13;
    while P + 7 <= Length(Bytes) do
    begin
      Bits := NumberAt(Bytes, P + 4, 4, False);
      if Bits > cardinal(Length(Bytes) - P - 7) then
        Break;
      N := Bits;
      if (Copy(Bytes, P, 4) = 'VP8X') and (N >= 10) then
      begin
        Width := 1 + NumberAt(Bytes, P + 12, 3, False);
        Height := 1 + NumberAt(Bytes, P + 15, 3, False);
      end
      else if (Copy(Bytes, P, 4) = 'VP8L') and (N >= 5) and (Bytes[P + 8] = #$2F) then
      begin
        Bits := NumberAt(Bytes, P + 9, 4, False);
        Width := 1 + (Bits and $3FFF);
        Height := 1 + ((Bits shr 14) and $3FFF);
      end
      else if (Copy(Bytes, P, 4) = 'VP8 ') and (N >= 10) and (Copy(Bytes, P + 11, 3) = #$9D#$01#$2A) then
      begin
        Width := NumberAt(Bytes, P + 14, 2, False) and $3FFF;
        Height := NumberAt(Bytes, P + 16, 2, False) and $3FFF;
      end;
      if (Width > 0) and (Height > 0) then
      begin
        Mime := 'image/webp';
        Break;
      end;
      Inc(P, 8 + N + (N mod 2));
    end;
  end;
  Result := (Mime <> '') and (Width > 0) and (Height > 0);
end;

function StripImageMetadata(const Bytes: rawbytestring; out Cleaned: rawbytestring): boolean;
var
  Mime, Kind: string;
  W, H, P, N, Start, Marker: integer;
  ChunkSize: cardinal;
  OutStream: TMemoryStream;

  procedure Keep(AStart, Count: integer);
  begin
    if Count > 0 then
      OutStream.WriteBuffer(Bytes[AStart], Count);
  end;

begin
  Cleaned := '';
  Result := False;
  if not ImageHeader(Bytes, Mime, W, H) then
    Exit;
  OutStream := TMemoryStream.Create;
  try
    if Mime = 'image/png' then
    begin
      Keep(1, 8);
      P := 9;
      while P + 11 <= Length(Bytes) do
      begin
        ChunkSize := NumberAt(Bytes, P, 4, True);
        if ChunkSize > cardinal(Length(Bytes) - P - 11) then
          Exit;
        N := integer(ChunkSize) + 12;
        Kind := Copy(Bytes, P + 4, 4);
        if not AnsiMatchStr(Kind, ['eXIf', 'tEXt', 'iTXt', 'zTXt']) then
          Keep(P, N);
        Inc(P, N);
        if Kind = 'IEND' then
        begin
          if ChunkSize <> 0 then
            Exit;
          Result := True;
          Break;
        end;
      end;
    end
    else if Mime = 'image/jpeg' then
    begin
      Keep(1, 2);
      P := 3;
      while P <= Length(Bytes) do
      begin
        Start := P;
        if Bytes[P] <> #$FF then
          Exit;
        while (P <= Length(Bytes)) and (Bytes[P] = #$FF) do
          Inc(P);
        if P > Length(Bytes) then
          Exit;
        Marker := Ord(Bytes[P]);
        Inc(P);
        if (Marker = $DA) or (Marker = $D9) then
        begin
          Keep(Start, Length(Bytes) - Start + 1);
          Result := True;
          Break;
        end;
        if (Marker = $01) or ((Marker >= $D0) and (Marker <= $D7)) then
        begin
          Keep(Start, P - Start);
          Continue;
        end;
        N := NumberAt(Bytes, P, 2, True);
        if (N < 2) or (N > Length(Bytes) - P + 1) then
          Exit;
        if Marker <> $E1 then
          Keep(Start, P + N - Start);
        Inc(P, N);
      end;
    end
    else
    begin
      Keep(1, Length(Bytes));
      Result := True;
    end;
    if Result then
    begin
      SetLength(Cleaned, OutStream.Size);
      if Cleaned <> '' then
        Move(OutStream.Memory^, Cleaned[1], Length(Cleaned));
    end;
  finally
    OutStream.Free;
  end;
end;

function ImageExtensionMatches(const FileName, Mime: string): boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(FileName));
  Result := ((Mime = 'image/png') and (Ext = '.png')) or ((Mime = 'image/jpeg') and ((Ext = '.jpg') or (Ext = '.jpeg'))) or
    ((Mime = 'image/gif') and (Ext = '.gif')) or ((Mime = 'image/webp') and (Ext = '.webp'));
end;

function ImageSizeOption(const Option: string; out W, H: integer): boolean;
var
  S: string;
  C: char;
  X: integer;
begin
  Result := False;
  W := 0;
  H := 0;
  if not EndsStr('px', Option) then
    Exit;
  S := Copy(Option, 1, Length(Option) - 2);
  for C in S do
    if not (C in ['0'..'9', 'x']) then
      Exit;
  X := Pos('x', S);
  if X = 0 then
    W := StrToIntDef(S, 0)
  else
  begin
    W := StrToIntDef(Copy(S, 1, X - 1), 0);
    H := StrToIntDef(Copy(S, X + 1, MaxInt), 0);
    if (H <= 0) or ((X > 1) and (W <= 0)) then
      Exit;
  end;
  Result := (W > 0) or (H > 0);
end;

function FileLinkHtml(const Inner: string; out Html: string; Lookup: TWikiFileLookup): boolean;
var
  Parts: TStringArray;
  Target, FileName, Opt, Low, Caption, AltText, Link, Alignment, Img, Style: string;
  Info: TWikiFile;
  Plain, Thumb, Framed, HasAlt, HasLink, Found: boolean;
  I, OptionW, OptionH, RequestedW, RequestedH, W, H: integer;
begin
  Result := False;
  Html := '';
  Parts := Inner.Split(['|']);
  Target := Trim(Parts[0]);
  Plain := StartsStr(':', Target);
  if Plain then
    Delete(Target, 1, 1);
  if StartsText('File:', Target) then
    Delete(Target, 1, 5)
  else if StartsText('Image:', Target) then
    Delete(Target, 1, 6)
  else
    Exit;
  Result := True;
  FileName := NormalizeFileName(Target);
  if FileName = '' then
  begin
    Html := E('[[' + Inner + ']]');
    Exit;
  end;
  Info := Default(TWikiFile);
  Found := False;
  if Assigned(Lookup) then
    Found := Lookup(FileName, Info);
  Caption := '';
  AltText := '';
  HasAlt := False;
  HasLink := False;
  Link := FilePageUrl(FileName);
  Alignment := '';
  Thumb := False;
  Framed := False;
  RequestedW := 0;
  RequestedH := 0;
  for I := 1 to High(Parts) do
  begin
    Opt := Trim(Parts[I]);
    Low := LowerCase(Opt);
    if Plain then
      Caption := Parts[I]
    else if (Low = 'thumb') or (Low = 'thumbnail') then
      Thumb := True
    else if Low = 'frame' then
      Framed := True
    else if Low = 'frameless' then
    begin
      Thumb := False;
      Framed := False;
    end
    else if AnsiMatchStr(Low, ['left', 'right', 'center', 'none']) then
      Alignment := Low
    else if StartsStr('alt=', Low) then
    begin
      HasAlt := True;
      AltText := Copy(Opt, 5, MaxInt);
    end
    else if StartsStr('link=', Low) then
    begin
      HasLink := True;
      Link := Trim(Copy(Opt, 6, MaxInt));
      if Link <> '' then
        if StartsText('https://', Link) or StartsText('http://', Link) then
        // Quotes and other HTML characters are escaped below.
        else
          Link := PageUrl(SlugOf(Link));
    end
    else if ImageSizeOption(Low, OptionW, OptionH) then
    begin
      RequestedW := OptionW;
      RequestedH := OptionH;
    end
    else
      Caption := Parts[I];
  end;
  if Plain or not Found then
  begin
    if Caption = '' then
      Caption := 'File:' + FileName;
    Style := '';
    if not Found then
      Style := ' class="missing" style="color:#b32424"';
    Html := '<a' + Style + ' href="' + E(FilePageUrl(FileName)) + '">' + E(Caption) + '</a>';
    Exit;
  end;
  if not HasAlt then
  begin
    AltText := Caption;
    if AltText = '' then
      AltText := StringReplace(FileName, '_', ' ', [rfReplaceAll]);
  end;
  W := Info.Width;
  H := Info.Height;
  RequestedW := EnsureRange(RequestedW, 0, 10000);
  RequestedH := EnsureRange(RequestedH, 0, 10000);
  if Thumb and (RequestedW = 0) and (RequestedH = 0) then
    RequestedW := 220;
  if (W > 0) and (H > 0) then
  begin
    if (RequestedW > 0) and ((RequestedH = 0) or (int64(RequestedW) * H <= int64(RequestedH) * W)) then
    begin
      H := Max(1, Round(int64(H) * RequestedW / W));
      W := RequestedW;
    end
    else if RequestedH > 0 then
    begin
      W := Max(1, Round(int64(W) * RequestedH / H));
      H := RequestedH;
    end;
  end
  else
  begin
    W := RequestedW;
    H := RequestedH;
  end;
  Style := 'max-width:100%;height:auto';
  if Alignment = 'left' then
    Style := Style + ';float:left;margin:0 1em 1em 0'
  else if Alignment = 'right' then
    Style := Style + ';float:right;margin:0 0 1em 1em'
  else if Alignment = 'center' then
    Style := Style + ';display:block;margin-left:auto;margin-right:auto'
  else if Alignment = 'none' then
    Style := Style + ';display:block';
  Img := '<img src="' + E(WikiFileUrl(Info.Path)) + '" alt="' + E(AltText) + '" loading="lazy" style="max-width:100%;height:auto"';
  if W > 0 then
    Img := Img + ' width="' + IntToStr(W) + '"';
  if H > 0 then
    Img := Img + ' height="' + IntToStr(H) + '"';
  Img := Img + '>';
  if (not HasLink) or (Link <> '') then
    Img := '<a href="' + E(Link) + '">' + Img + '</a>';
  if Thumb or Framed then
  begin
    if Alignment = '' then
      Style := Style + ';float:right;margin:0 0 1em 1em';
    Html := '<figure class="wiki-file" style="' + Style + '">' + Img + '<figcaption>' + E(Caption) + '</figcaption></figure>';
  end
  else
    Html := '<span class="wiki-file" style="' + Style + '">' + Img + '</span>';
end;

function ReadFileRow(Row: TSQLQuery): TWikiFile;
begin
  Result := Default(TWikiFile);
  Result.Name := Row.Fields[0].AsString;
  Result.Path := Row.Fields[1].AsString;
  Result.Sha1 := Row.Fields[2].AsString;
  Result.Size := Row.Fields[3].AsLargeInt;
  Result.Mime := Row.Fields[4].AsString;
  Result.Width := Row.Fields[5].AsInteger;
  Result.Height := Row.Fields[6].AsInteger;
  Result.UploadedBy := Row.Fields[7].AsInteger;
  Result.Uploaded := Row.Fields[8].AsString;
  Result.Description := Row.Fields[9].AsString;
  Result.Version := Row.Fields[10].AsInteger;
  Result.Uploader := Row.Fields[11].AsString;
end;

function LoadWikiFile(const FileName: string; out Info: TWikiFile): boolean;
var
  Row: TSQLQuery;
begin
  Info := Default(TWikiFile);
  Result := False;
  Row := Query('SELECT ' + FileColumns + ' FROM wiki_files f LEFT JOIN users u ON u.id = f.uploaded_by WHERE f.name = :n', [FileName]);
  try
    if Row.EOF then
      Exit;
    Info := ReadFileRow(Row);
    Result := FileExists(FilesRoot + 'wiki-images/' + Info.Path);
  finally
    Row.Free;
  end;
end;

function W(ARequest: TRequest; const English: string): string;
begin
  Result := E(SiteWord(LanguageOfRequest(ARequest), English));
end;

function MayUpload(const Me: TMember): boolean;
begin
  Result := (Me.Id > 0) and not Me.Banned and Me.Verified and Can(Me, 'wiki-edit');
end;

function MayReplace(const Me: TMember; const Info: TWikiFile): boolean;
begin
  Result := MayUpload(Me) and ((Me.Id = Info.UploadedBy) or Can(Me, 'wiki-files-moderate'));
end;

function FileJson(const Info: TWikiFile): TJSONObject;
begin
  Result := TJSONObject.Create(['name', Info.Name, 'url', WikiFileUrl(Info.Path), 'width', Info.Width, 'height', Info.Height, 'size',
    Info.Size, 'mime', Info.Mime, 'uploaded_by', Info.Uploader, 'uploaded_by_id', Info.UploadedBy, 'uploaded', Info.Uploaded, 'page', FilePageUrl(Info.Name)]);
end;

procedure LockFiles;
begin
  if IntValue('SELECT ' + SqlLock('''wiki-files''', 10), []) <> 1 then
    raise Exception.Create('Wiki files are busy. Try again.');
end;

procedure UnlockFiles;
begin
  IntValue('SELECT ' + SqlUnlock('''wiki-files'''), []);
end;

function ReadBytes(const LocalPath: string): rawbytestring;
var
  F: TFileStream;
begin
  Result := '';
  F := TFileStream.Create(LocalPath, fmOpenRead or fmShareDenyWrite);
  try
    if F.Size > MAX_UPLOAD_MB * MB then
      raise Exception.Create('The image is too large.');
    SetLength(Result, F.Size);
    if Result <> '' then
      F.ReadBuffer(Result[1], Length(Result));
  finally
    F.Free;
  end;
end;

{ Find pages mentioning a file with five SQL parameters. Byte search avoids
  expensive per-body collation and replacement. Include bare,
  space/underscore, initial-case and percent-encoded names for links and
  paths; harmless prose mentions also count. }
type
  TVariantArray = array of variant;

const
  MENTIONS_FILE = '(LOCATE(BINARY :m1, body) > 0 OR LOCATE(BINARY :m2, body) > 0 OR LOCATE(BINARY :m3, body) > 0 OR LOCATE(BINARY :m4, body) > 0 OR LOCATE(BINARY :m5, body) > 0)';

function MentionTerms(const FileName: string): TVariantArray;
var
  Spaced, Lower: string;
  U: unicodestring;
begin
  Spaced := StringReplace(FileName, '_', ' ', [rfReplaceAll]);
  U := UTF8Decode(FileName);
  if U <> '' then
    U[1] := UnicodeLowerCase(Copy(U, 1, 1))[1];
  Lower := UTF8Encode(U);
  // the last: a stored path, its brackets and the like percent-encoded
  Result := [FileName, Spaced, Lower, StringReplace(Lower, '_', ' ', [rfReplaceAll]), PathEncode(FileName)];
end;

{ Pages that show the file are made again by the rerender chore, so a
  missing-picture link turns into the picture.  Run after the upload's
  transaction, so it never holds rows other saves wait for. }
procedure InvalidateFilePages(const Info: TWikiFile);
var
  Ids: string;
begin
  try
    // found by a plain read first: an UPDATE over every page locks and
    // reads each one, two seconds, where the SELECT takes a quarter of one
    Ids := '';
    with Query('SELECT id FROM wiki_pages WHERE ' + MENTIONS_FILE, MentionTerms(Info.Name)) do
    try
      while not EOF do
      begin
        Ids := Ids + IfThen(Ids <> '', ',', '') + IntToStr(Fields[0].AsInteger);
        Next;
      end;
    finally
      Free;
    end;
    if Ids <> '' then
      Exec('UPDATE wiki_pages SET rendered = 0 WHERE id IN (' + Ids + ')', []);
  except
    on E: Exception do
      Log('wiki files: pages using ' + Info.Name + ' not marked: ' + E.Message);
  end;
end;

function AvailableName(const FileName: string): string;
var
  Stem, Ext, Suffix: string;
  U: unicodestring;
  I: integer;
begin
  Ext := ExtractFileExt(FileName);
  Stem := Copy(FileName, 1, Length(FileName) - Length(Ext));
  I := 2;
  repeat
    Suffix := '_' + IntToStr(I);
    U := UTF8Decode(Stem);
    while Length(Stem) + Length(Suffix) + Length(Ext) > 240 do
    begin
      SetLength(U, Length(U) - 1);
      Stem := UTF8Encode(U);
    end;
    Result := Stem + Suffix + Ext;
    Inc(I);
  until (IntValue('SELECT COUNT(*) FROM wiki_files WHERE name = :n', [Result]) = 0) and not FileExists(FilesRoot + 'wiki-images/' + WikiFilePath(Result));
end;

function ArchivePath(const FileName: string): string;
var
  Stamp: TDateTime;
  Hashed: string;
begin
  Hashed := WikiFilePath(FileName);
  Hashed := ExtractFilePath(Hashed);
  Stamp := LocalTimeToUniversal(Now);
  repeat
    Result := 'archive/' + Hashed + FormatDateTime('yyyymmddhhnnss', Stamp) + '!' + FileName;
    Stamp := IncSecond(Stamp);
  until not FileExists(FilesRoot + 'wiki-images/' + Result);
end;

procedure StoreUpload(const Me: TMember; var Info: TWikiFile; const Previous: TWikiFile; const Bytes: rawbytestring);
var
  TempPath, TargetPath, OldPath, ArchiveRelative, ArchivedPath: string;
  F, Source: TFileStream;
  Archived, Installed, InTransaction: boolean;
begin
  TargetPath := FilesRoot + 'wiki-images/' + Info.Path;
  ForceDirectories(ExtractFilePath(TargetPath));
  TempPath := ExtractFilePath(TargetPath) + '.wiki-' + RandomHex(12) + '.tmp';
  Archived := False;
  Installed := False;
  InTransaction := False;
  OldPath := '';
  ArchivedPath := '';
  try
    try
      F := TFileStream.Create(TempPath, fmCreate);
      try
        F.WriteBuffer(Bytes[1], Length(Bytes));
      finally
        F.Free;
      end;
      Exec('START TRANSACTION', []);
      InTransaction := True;
      if Previous.Version > 0 then
      begin
        ArchiveRelative := ArchivePath(Info.Name);
        ArchivedPath := FilesRoot + 'wiki-images/' + ArchiveRelative;
        ForceDirectories(ExtractFilePath(ArchivedPath));
        OldPath := FilesRoot + 'wiki-images/' + Previous.Path;
        Exec('INSERT INTO wiki_file_versions (name, path, sha1, size, mime, width, height, uploaded_by, uploaded, description, version)' +
          ' SELECT name, :p, sha1, size, mime, width, height, uploaded_by, uploaded, description, version FROM wiki_files WHERE name = :n',
          [ArchiveRelative, Info.Name]);
        // Keep the public path present while the new version is installed by rename.
        Archived := True;
        Source := TFileStream.Create(OldPath, fmOpenRead or fmShareDenyWrite);
        try
          F := TFileStream.Create(ArchivedPath, fmCreate);
          try
            F.CopyFrom(Source, 0);
          finally
            F.Free;
          end;
        finally
          Source.Free;
        end;
      end;
      if not RenameFile(TempPath, TargetPath) then
        raise Exception.Create('Cannot install the wiki image.');
      Installed := True;
      Exec('INSERT INTO wiki_files (name, path, sha1, size, mime, width, height, uploaded_by, uploaded, description, version)' +
        ' VALUES (:n, :p, :s, :z, :m, :w, :h, :u, ' + SqlUtcNow + ', :d, :v)' + SqlOnConflict('name', 'path=' + SqlNew('path') +
        ', sha1=' + SqlNew('sha1') + ', size=' + SqlNew('size') + ', mime=' + SqlNew('mime') + ',' + ' width=' + SqlNew('width') +
        ', height=' + SqlNew('height') + ', uploaded_by=' + SqlNew('uploaded_by') + ', uploaded=' + SqlNew('uploaded') + ',' + ' description=' +
        SqlNew('description') + ', version=' + SqlNew('version')),
        [Info.Name, Info.Path, Info.Sha1, Info.Size, Info.Mime, Info.Width, Info.Height, Me.Id, Info.Description, Info.Version]);
      Exec('COMMIT', []);
      InTransaction := False;
    except
      if InTransaction then
        Exec('ROLLBACK', []);
      if Installed then
      begin
        if Archived then
          RenameFile(ArchivedPath, OldPath)
        else
          DeleteFile(TargetPath);
      end
      else if Archived then
        DeleteFile(ArchivedPath);
      raise;
    end;
  finally
    DeleteFile(TempPath);
  end;
  InvalidateFilePages(Info);
end;

procedure UploadImage(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Upload: TUploadedFile;
  Proposed, Mime, Subject, SavedName, Refusal: string;
  Raw, Cleaned: rawbytestring;
  Info, Previous: TWikiFile;
  ExistsAlready: boolean;
  Code: integer;
begin
  CheckConnection;
  if FromAnotherSite(ARequest) then
  begin
    SendText(AResponse, 403, W(ARequest, 'Send this form from this site.'));
    Exit;
  end;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  if not MayUpload(Me) then
  begin
    SendText(AResponse, 403, W(ARequest, 'You may not upload wiki images.'));
    Exit;
  end;
  Subject := 'member ' + IntToStr(Me.Id);
  LockFiles;
  try
    if TooManyTries(Subject, 'wikiup', 30, 60) then
    begin
      SendText(AResponse, 429, W(ARequest, 'You may upload 30 images per hour.'));
      Exit;
    end;
    NoteTry(Subject, 'wikiup');
    Upload := ARequest.Files.FindFile('file');
    if (Upload = nil) or (ARequest.Files.Count <> 1) then
    begin
      SendText(AResponse, 400, W(ARequest, 'Send one image in the file field.'));
      Exit;
    end;
    if (Upload.Size <= 0) or (Upload.Size > EnsureRange(SettingInt('wiki_upload_max_mb', 5), 1, MAX_UPLOAD_MB) * MB) then
    begin
      SendText(AResponse, 413, W(ARequest, 'The image exceeds the wiki upload size limit.'));
      Exit;
    end;
    Info := Default(TWikiFile);
    Proposed := ARequest.ContentFields.Values['name'];
    if Proposed = '' then
      Proposed := Upload.FileName;
    Info.Name := NormalizeFileName(Proposed);
    Mime := ImageType(Upload.LocalFileName);
    Raw := ReadBytes(Upload.LocalFileName);
    if (Mime = '') or not ImageHeader(Raw, Info.Mime, Info.Width, Info.Height) or (Mime <> Info.Mime) or not StripImageMetadata(Raw, Cleaned) then
    begin
      SendText(AResponse, 415, W(ARequest, 'Only PNG, JPEG, GIF and WebP images are allowed.'));
      Exit;
    end;
    if (Info.Name = '') or not ImageExtensionMatches(Info.Name, Info.Mime) then
    begin
      SendText(AResponse, 400, W(ARequest, 'Use a valid file name with an extension matching the image type.'));
      Exit;
    end;
    if not UploadScanPasses(Me.Id, 'wiki', Info.Name, Upload.LocalFileName, Refusal, Code) then
    begin
      SendText(AResponse, Code, Refusal);
      Exit;
    end;
    Info.Sha1 := SHA1Print(SHA1String(Cleaned));
    Info.Size := Length(Cleaned);
    Info.Path := WikiFilePath(Info.Name);
    Info.UploadedBy := Me.Id;
    Info.Description := Copy(ARequest.ContentFields.Values['description'], 1, 10000);
    ExistsAlready := LoadWikiFile(Info.Name, Previous);
    if ExistsAlready and ((Previous.Sha1 = Info.Sha1) or (Previous.Sha1 = SHA1Print(SHA1String(Raw)))) then
    begin
      SendJSON(AResponse, FileJson(Previous));
      Exit;
    end;
    if ExistsAlready and ((ARequest.ContentFields.Values['replace'] <> '1') or not MayReplace(Me, Previous)) then
    begin
      AResponse.Code := 409;
      SendJSON(AResponse, TJSONObject.Create(['conflict', True, 'name', Info.Name, 'url', WikiFileUrl(Previous.Path), 'suggested', AvailableName(Info.Name)]));
      Exit;
    end;
    if Previous.Version > 0 then
      Info.Path := Previous.Path;
    // A file the index does not know must never be silently overwritten.
    if not ExistsAlready and FileExists(FilesRoot + 'wiki-images/' + Info.Path) then
    begin
      AResponse.Code := 409;
      SendJSON(AResponse, TJSONObject.Create(['conflict', True, 'name', Info.Name, 'url', WikiFileUrl(Info.Path), 'suggested', AvailableName(Info.Name)]));
      Exit;
    end;
    Info.Version := Previous.Version + 1;
    StoreUpload(Me, Info, Previous, Cleaned);
    SavedName := Info.Name;
    LoadWikiFile(SavedName, Info);
    AResponse.SetCustomHeader('Cache-Control', 'no-store');
    SendJSON(AResponse, FileJson(Info));
  finally
    UnlockFiles;
  end;
end;

function UsageText(const Text: string): string;
begin
  Result := StringReplace(UTF8Encode(UnicodeLowerCase(UTF8Decode(Text))), ' ', '_', [rfReplaceAll]);
end;

type
  TWikiFileArray = array of TWikiFile;

{ Find used pictures in one pass through pages, including File/Image links,
  stored paths and raw HTML. Compare bare names after decoding percent
  escapes and removing direction marks; ignore case and treat spaces as
  underscores. }
function UsedFileNames(const Items: TWikiFileArray): TStringList;
const
  Stops = [#0..#31, '/', ':', '[', ']', '(', ')', '"', '''', '|', '=', '<', '>', '{', '}'];
var
  Keys: TStringList;
  Found: TStringList;
  Body, Token: string;
  I, P, Q, Len: integer;

  procedure Look(const Candidate: string);
  var
    Index: integer;
  begin
    if (Candidate <> '') and Keys.Find(Candidate, Index) then
      Found.Add(Items[PtrInt(Keys.Objects[Index])].Name);
  end;

begin
  Found := TStringList.Create;
  Found.Sorted := True;
  Found.Duplicates := dupIgnore;
  Keys := TStringList.Create;
  try
    try
      Keys.Sorted := True;
      Keys.Duplicates := dupIgnore;
      for I := 0 to High(Items) do
        Keys.AddObject(UsageText(Items[I].Name), TObject(PtrInt(I)));
      with Query('SELECT body FROM wiki_pages', []) do
      try
        while not EOF do
        begin
          // HTTPDecode treats a plus as a form space; a path's literal plus stays.
          Body := UsageText(HTTPDecode(StringReplace(Fields[0].AsString, '+', '%2B', [rfReplaceAll])));
          Body := StringReplace(StringReplace(Body, #$E2#$80#$8E, '', [rfReplaceAll]), #$E2#$80#$8F, '', [rfReplaceAll]);
          Q := Pos('.', Body);
          while Q > 0 do
          begin
            Len := 0;
            if AnsiMatchStr(Copy(Body, Q, 4), ['.png', '.jpg', '.gif']) then
              Len := 4
            else if AnsiMatchStr(Copy(Body, Q, 5), ['.jpeg', '.webp']) then
              Len := 5;
            if (Len > 0) and ((Q + Len > Length(Body)) or (Body[Q + Len] in Stops + ['_', ' ', '.', ','])) then
            begin
              P := Q - 1;
              while (P > 0) and (Q - P < 240) and not (Body[P] in Stops) do
                Dec(P);
              Token := Copy(Body, P + 1, Q + Len - P - 1);
              while (Token <> '') and (Token[1] = '_') do
                System.Delete(Token, 1, 1);
              Look(Token);
              // in prose the name may follow other words: its last word too
              if LastDelimiter('_', Token) > 0 then
                Look(Copy(Token, LastDelimiter('_', Token) + 1, MaxInt));
            end;
            Q := PosEx('.', Body, Q + 1);
          end;
          Next;
        end;
      finally
        Free;
      end;
    except
      Found.Free;
      raise;
    end;
  finally
    Keys.Free;
  end;
  Result := Found;
end;

{ The library's order: newest (the default), by name, or largest first. }
function FileOrder(const Sort: string): string;
begin
  if Sort = 'name' then
    Result := ' ORDER BY f.name'
  else if Sort = 'big' then
    Result := ' ORDER BY f.width * f.height DESC, f.name'
  else
    Result := ' ORDER BY f.uploaded DESC, f.name';
end;

{ A page of pictures whose name holds Search, and in Total how many there
  are in all; with Unused, only those no page uses. }
function ListFiles(const Search, Sort: string; Limit, Offset: integer; Unused: boolean; out Total: integer): TJSONArray;
var
  SQL, Term: string;
  Info: TWikiFile;
  Rows: TSQLQuery;
  Candidates: TWikiFileArray;
  UsedNames: TStringList;
  I: integer;
begin
  Result := TJSONArray.Create;
  Total := 0;
  Term := StringReplace(Search, ' ', '_', [rfReplaceAll]);
  SQL := 'SELECT ' + FileColumns + ' FROM wiki_files f LEFT JOIN users u ON u.id=f.uploaded_by WHERE INSTR(LOWER(f.name), LOWER(:q)) > 0' + FileOrder(Sort);
  if not Unused then
  begin
    Total := IntValue('SELECT COUNT(*) FROM wiki_files f WHERE INSTR(LOWER(f.name), LOWER(:q)) > 0', [Term]);
    SQL := SQL + ' LIMIT ' + IntToStr(Limit) + ' OFFSET ' + IntToStr(Offset);
  end;
  Candidates := [];
  try
    Rows := Query(SQL, [Term]);
    try
      while not Rows.EOF do
      begin
        Info := ReadFileRow(Rows);
        if Unused then
          Candidates := Concat(Candidates, [Info])
        else
          Result.Add(FileJson(Info));
        Rows.Next;
      end;
    finally
      Rows.Free;
    end;
    if Unused then
    begin
      UsedNames := UsedFileNames(Candidates);
      try
        for I := 0 to High(Candidates) do
          if UsedNames.IndexOf(Candidates[I].Name) < 0 then
          begin
            if (Total >= Offset) and (Result.Count < Limit) then
              Result.Add(FileJson(Candidates[I]));
            Inc(Total);
          end;
      finally
        UsedNames.Free;
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure ApiFiles(ARequest: TRequest; AResponse: TResponse);
var
  Items: TJSONArray;
  ExactNames: TStringArray;
  FileName, Normal: string;
  Info: TWikiFile;
  Total: integer;
begin
  CheckConnection;
  if ARequest.QueryFields.IndexOfName('names') >= 0 then
  begin
    Items := TJSONArray.Create;
    try
      ExactNames := ARequest.QueryFields.Values['names'].Split(['|']);
      for FileName in ExactNames do
      begin
        if Items.Count >= 100 then
          Break;
        Normal := NormalizeFileName(FileName);
        if (Normal <> '') and LoadWikiFile(Normal, Info) then
          Items.Add(FileJson(Info));
      end;
    except
      Items.Free;
      raise;
    end;
  end
  else
    Items := ListFiles(ARequest.QueryFields.Values['q'], ARequest.QueryFields.Values['sort'], EnsureRange(StrToIntDef(ARequest.QueryFields.Values['limit'], 50), 1, 100),
      Max(0, StrToIntDef(ARequest.QueryFields.Values['offset'], 0)), False, Total);
  SendJSON(AResponse, Items);
end;

procedure SendFilesPage(ARequest: TRequest; AResponse: TResponse; const Title, Content: string);
begin
  SendWikiPage(ARequest, AResponse, Title, FillTemplate('wiki-files-style', []) + Content);
end;

function UploadForm(ARequest: TRequest; const FileName: string; ReplaceExisting: boolean): string;
begin
  Result := '<form method="post" action="/api/wiki/upload" enctype="multipart/form-data" class="wiki-file-upload">' + '<label>' +
    W(ARequest, 'Image') + ' <input type="file" name="file" accept="image/png,image/jpeg,image/gif,image/webp" required></label>' + '<label>' +
    W(ARequest, 'File name') + ' <input name="name" value="' + E(FileName) + '" maxlength="240"></label>' + '<label>' + W(ARequest, 'Description') +
    ' <textarea name="description" maxlength="10000"></textarea></label>';
  if ReplaceExisting then
    Result := Result + '<input type="hidden" name="replace" value="1">';
  Result := Result + '<button type="submit">' + W(ARequest, 'Upload image') + '</button></form>';
end;

const
  LIBRARY_PAGE = 100;

{ /wiki-files with its search, order, list and page. }
function LibraryUrl(const Q, Sort: string; Unused: boolean; Page: integer): string;
begin
  Result := '/wiki-files?';
  if Q <> '' then
    Result := Result + 'q=' + HTTPEncode(Q) + '&';
  if (Sort <> '') and (Sort <> 'new') then
    Result := Result + 'sort=' + HTTPEncode(Sort) + '&';
  if Unused then
    Result := Result + 'unused=1&';
  if Page > 1 then
    Result := Result + 'page=' + IntToStr(Page) + '&';
  SetLength(Result, Length(Result) - 1);
end;

{ The library's page numbers: the first, the last, and two on each side of
  this one, with a gap where numbers are left out. }
function LibraryPager(ARequest: TRequest; const Q, Sort: string; Unused: boolean; Page, Pages: integer): string;
var
  N: integer;
  Gap: boolean;
begin
  Result := '';
  if Pages <= 1 then
    Exit;
  Result := '<nav class="wiki-file-pager" aria-label="' + W(ARequest, 'Pages') + '">';
  if Page > 1 then
    Result := Result + '<a rel="prev" href="' + E(LibraryUrl(Q, Sort, Unused, Page - 1)) + '">‹ ' + W(ARequest, 'Previous') + '</a>';
  Gap := False;
  for N := 1 to Pages do
    if (N = 1) or (N = Pages) or (Abs(N - Page) <= 2) then
    begin
      if N = Page then
        Result := Result + '<span aria-current="page">' + IntToStr(N) + '</span>'
      else
        Result := Result + '<a href="' + E(LibraryUrl(Q, Sort, Unused, N)) + '">' + IntToStr(N) + '</a>';
      Gap := False;
    end
    else if not Gap then
    begin
      Result := Result + '<span class="gap">…</span>';
      Gap := True;
    end;
  if Page < Pages then
    Result := Result + '<a rel="next" href="' + E(LibraryUrl(Q, Sort, Unused, Page + 1)) + '">' + W(ARequest, 'Next') + ' ›</a>';
  Result := Result + '</nav>';
end;

procedure ShowLibrary(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Items: TJSONArray;
  I, Page, Pages, Total: integer;
  Html, Q, Sort, Name, Size: string;
  Unused: boolean;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  Unused := ARequest.QueryFields.Values['unused'] = '1';
  if Unused and not Can(Me, 'wiki-files-moderate') then
  begin
    SendText(AResponse, 403, W(ARequest, 'Only moderators may list unused files.'));
    Exit;
  end;
  Q := ARequest.QueryFields.Values['q'];
  Sort := ARequest.QueryFields.Values['sort'];
  if (Sort <> 'name') and (Sort <> 'big') then
    Sort := 'new';
  Page := Max(1, StrToIntDef(ARequest.QueryFields.Values['page'], 1));
  Items := ListFiles(Q, Sort, LIBRARY_PAGE, (Page - 1) * LIBRARY_PAGE, Unused, Total);
  try
    Pages := Max(1, (Total + LIBRARY_PAGE - 1) div LIBRARY_PAGE);
    // the heading with the upload button beside it, then the search, as
    // the other wiki lists have it
    Html := '<div class="wiki-file-head"><h1>' + W(ARequest, 'Wiki images') + '</h1>';
    if MayUpload(Me) then
      Html := Html + '<a class="wiki-file-button" href="#upload">' + W(ARequest, 'Upload an image') + '</a>';
    Html := Html + '</div>';
    if ARequest.QueryFields.Values['deleted'] <> '' then
      Html := Html + '<p class="notice">' + E(Format(Say('%s was deleted.'), [StringReplace(ARequest.QueryFields.Values['deleted'], '_', ' ', [rfReplaceAll])])) + '</p>';
    Html := Html + '<form method="get" class="wikisearch wiki-file-search" role="search"><input type="search" name="q" value="' + E(Q) +
      '" placeholder="' + W(ARequest, 'Search images') + '" aria-label="' + W(ARequest, 'Search images') + '">';
    if Sort <> 'new' then
      Html := Html + '<input type="hidden" name="sort" value="' + E(Sort) + '">';
    if Unused then
      Html := Html + '<input type="hidden" name="unused" value="1">';
    Html := Html + '<button>' + W(ARequest, 'Search') + '</button></form>';
    // how many, in what order, and the moderators' list of unused ones
    Html := Html + '<div class="wiki-file-bar"><p class="wiki-file-count">';
    if Unused then
      Html := Html + E(SayCount(Total, '%d image no page shows', '%d images no page shows'))
    else if Q <> '' then
      Html := Html + E(SayCount(Total, '%d image matches', '%d images match'))
    else
      Html := Html + E(SayCount(Total, '%d image', '%d images'));
    if Pages > 1 then
      Html := Html + ' · ' + E(Format(Say('page %d of %d'), [Page, Pages]));
    Html := Html + '</p><p class="wiki-file-sort">' + W(ARequest, 'Order:');
    for Name in ['new', 'name', 'big'] do
    begin
      if Name = Sort then
        Html := Html + ' <b>'
      else
        Html := Html + ' <a href="' + E(LibraryUrl(Q, Name, Unused, 1)) + '">';
      if Name = 'new' then
        Html := Html + W(ARequest, 'Newest')
      else if Name = 'name' then
        Html := Html + W(ARequest, 'Name')
      else
        Html := Html + W(ARequest, 'Largest');
      if Name = Sort then
        Html := Html + '</b>'
      else
        Html := Html + '</a>';
    end;
    Html := Html + '</p>';
    if Unused then
      Html := Html + '<p class="wiki-file-sort"><a href="' + E(LibraryUrl(Q, Sort, False, 1)) + '">' + W(ARequest, 'All images') + '</a></p>'
    else if Can(Me, 'wiki-files-moderate') then
      Html := Html + '<p class="wiki-file-sort"><a href="' + E(LibraryUrl(Q, Sort, True, 1)) + '">' + W(ARequest, 'Unused images') + '</a></p>';
    Html := Html + '</div>' + LibraryPager(ARequest, Q, Sort, Unused, Page, Pages) + '<div class="wiki-file-grid">';
    // a picture opens in the viewer (wiki-files.js); without scripts, on its page
    for I := 0 to Items.Count - 1 do
      with Items.Objects[I] do
      begin
        Size := IntToStr(Integers['width']) + ' × ' + IntToStr(Integers['height']);
        Html := Html + '<a href="' + E(Strings['page']) + '" data-view="' + E(Strings['url']) + '" data-size="' + Size +
          '"><span class="wiki-file-thumb"><img loading="lazy" src="' + E(Strings['url']) + '" alt=""></span><span class="wiki-file-name">' +
          E(StringReplace(Strings['name'], '_', ' ', [rfReplaceAll])) + '</span><span class="wiki-file-size">' + Size + '</span></a>';
      end;
    if Items.Count = 0 then
      Html := Html + '<p class="fine">' + W(ARequest, 'No image has that name.') + '</p>';
    Html := Html + '</div>' + LibraryPager(ARequest, Q, Sort, Unused, Page, Pages);
    if MayUpload(Me) then
      Html := Html + '<section id="upload"><h2>' + W(ARequest, 'Upload an image') + '</h2>' + UploadForm(ARequest, '', False) + '</section>';
    SendFilesPage(ARequest, AResponse, Say('Wiki images'), Html);
  finally
    Items.Free;
  end;
end;

{ The short addresses for a file, /File:Name, /Image:Name and
  /Media:Name, as MediaWiki has them: on to the file page.
  Anything else goes on to the guard's "Nothing here". }
function OldFileAddress(ARequest: TRequest; AResponse: TResponse): boolean;
var
  Path, FileName: string;
  Colon: integer;
begin
  Result := False;
  Path := HTTPDecode(ARequest.PathInfo);
  if not (StartsText('/File:', Path) or StartsText('/Image:', Path) or StartsText('/Media:', Path)) then
    Exit;
  Colon := Pos(':', Path);
  FileName := NormalizeFileName(Copy(Path, Colon + 1, MaxInt));
  if FileName = '' then
    Exit;
  AResponse.Location := FilePageUrl(FileName);
  AResponse.Code := 301;
  AResponse.CodeText := 'Moved Permanently';
  Result := True;
end;

procedure ShowFile(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Info: TWikiFile;
  FileName, Html: string;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  FileName := NormalizeFileName(HTTPDecode(ARequest.RouteParams['name']));
  if FileName = '' then
  begin
    SendText(AResponse, 400, W(ARequest, 'Invalid file name.'));
    Exit;
  end;
  Html := '<p><a href="/wiki-files">' + W(ARequest, 'Wiki images') + '</a></p><h1>' + E('File:' + FileName) + '</h1>';
  if not LoadWikiFile(FileName, Info) then
  begin
    AResponse.Code := 404;
    Html := Html + '<p class="notice">' + W(ARequest, 'This image has not been uploaded yet.') + '</p>';
    if MayUpload(Me) then
      Html := Html + UploadForm(ARequest, FileName, False);
    SendFilesPage(ARequest, AResponse, FileName, Html);
    Exit;
  end;
  Html := Html + '<a href="' + E(WikiFileUrl(Info.Path)) + '"><img class="wiki-file-preview" src="' + E(WikiFileUrl(Info.Path)) +
    '" alt="' + E(FileName) + '" width="' + IntToStr(Info.Width) + '" height="' + IntToStr(Info.Height) + '"></a>' + '<p>' +
    E(IntToStr(Info.Size)) + ' ' + W(ARequest, 'bytes') + ', ' + E(IntToStr(Info.Width) + ' × ' + IntToStr(Info.Height)) + ' px · ' +
    E(Info.Uploader) + ' · ' + DateTag(Info.Uploaded, True) + '</p><p class="wiki-file-description">' + E(Info.Description) + '</p>' +
    '<h2>' + W(ARequest, 'Version history') + '</h2><table class="history"><thead><tr><th>' + W(ARequest, 'Version') + '</th><th>' +
    W(ARequest, 'Uploaded') + '</th><th>' + W(ARequest, 'Member') + '</th><th>' + W(ARequest, 'Size') + '</th></tr></thead><tbody>' +
    '<tr><td><a href="' + E(WikiFileUrl(Info.Path)) + '">' + IntToStr(Info.Version) + '</a></td><td>' + DateTag(Info.Uploaded, True) +
    '</td><td>' + E(Info.Uploader) + '</td><td>' + IntToStr(Info.Size) + '</td></tr>';
  with Query('SELECT v.version, v.path, ' + IsoTime('v.uploaded') + ', COALESCE(u.name, ' + QuotedStr(WikiNoUploader) +
      '), v.size FROM wiki_file_versions v' + ' LEFT JOIN users u ON u.id=v.uploaded_by WHERE v.name=:n ORDER BY v.version DESC', [FileName]) do
  try
    while not EOF do
    begin
      Html := Html + '<tr><td><a href="' + E(WikiFileUrl(Fields[1].AsString)) + '">' + E(Fields[0].AsString) + '</a></td><td>' +
        DateTag(Fields[2].AsString, True) + '</td><td>' + E(Fields[3].AsString) + '</td><td>' + E(Fields[4].AsString) + '</td></tr>';
      Next;
    end;
  finally
    Free;
  end;
  Html := Html + '</tbody></table><h2>' + W(ARequest, 'Used on these pages') + '</h2><ul>';
  with Query('SELECT slug, title FROM wiki_pages WHERE ' + MENTIONS_FILE + ' ORDER BY name_key', MentionTerms(FileName)) do
  try
    while not EOF do
    begin
      Html := Html + '<li><a href="' + E(PageUrl(Fields[0].AsString)) + '">' + E(Fields[1].AsString) + '</a></li>';
      Next;
    end;
  finally
    Free;
  end;
  Html := Html + '</ul>';
  if MayReplace(Me, Info) then
    Html := Html + '<h2>' + W(ARequest, 'Upload a new version') + '</h2>' + UploadForm(ARequest, FileName, True);
  if (Me.Id > 0) and Can(Me, 'wiki-files-moderate') then
    Html := Html + '<form method="post" action="/api/wiki/files/delete" class="wiki-file-delete" data-confirm="' +
      W(ARequest, 'Delete this image and all its versions? Pages that show it will show a missing image.') + '"><input type="hidden" name="name" value="' +
      E(FileName) + '"><button type="submit">' + W(ARequest, 'Delete image and all versions') + '</button></form>';
  SendFilesPage(ARequest, AResponse, FileName, Html);
end;

procedure DeleteImage(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  FileName, Trash: string;
  Info: TWikiFile;
  Paths: TStringList;
  I, Moved: integer;
begin
  CheckConnection;
  if FromAnotherSite(ARequest) then
  begin
    SendText(AResponse, 403, W(ARequest, 'Send this form from this site.'));
    Exit;
  end;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  if not Can(Me, 'wiki-files-moderate') then
  begin
    SendText(AResponse, 403, W(ARequest, 'Only moderators may delete wiki images.'));
    Exit;
  end;
  FileName := NormalizeFileName(ARequest.ContentFields.Values['name']);
  Paths := TStringList.Create;
  try
    LockFiles;
    try
      if not LoadWikiFile(FileName, Info) then
      begin
        SendText(AResponse, 404, W(ARequest, 'Image not found.'));
        Exit;
      end;
      Paths.Add(Info.Path);
      with Query('SELECT path FROM wiki_file_versions WHERE name=:n', [FileName]) do
      try
        while not EOF do
        begin
          Paths.Add(Fields[0].AsString);
          Next;
        end;
      finally
        Free;
      end;
      // inside wiki-images: the service's sandbox mounts each writable
      // folder apart, and a rename from one mount to another is refused
      Trash := FilesRoot + 'wiki-images/.trash/' + RandomHex(12) + '/';
      if not ForceDirectories(Trash) then
        raise Exception.Create('Cannot prepare image deletion.');
      Moved := 0;
      Exec('START TRANSACTION', []);
      try
        for I := 0 to Paths.Count - 1 do
        begin
          if not RenameFile(FilesRoot + 'wiki-images/' + Paths[I], Trash + IntToStr(I)) then
            raise Exception.Create('Cannot remove a wiki image.');
          Inc(Moved);
        end;
        Exec('DELETE FROM wiki_file_versions WHERE name=:n', [FileName]);
        Exec('DELETE FROM wiki_files WHERE name=:n', [FileName]);
        InvalidateFilePages(Info);
        Exec('COMMIT', []);
      except
        Exec('ROLLBACK', []);
        for I := Moved - 1 downto 0 do
          if not RenameFile(Trash + IntToStr(I), FilesRoot + 'wiki-images/' + Paths[I]) then
            Log('Could not restore a wiki image after a failed deletion: ' + Paths[I]);
        RemoveDir(Trash);
        raise;
      end;
      for I := 0 to Paths.Count - 1 do
        if not DeleteFile(Trash + IntToStr(I)) then
          Log('Could not remove a deleted wiki image from trash: ' + Paths[I]);
      RemoveDir(Trash);
      // the file page's own form goes back to the library; a script gets JSON
      if Pos('text/html', ARequest.Accept) > 0 then
        SeeOther(AResponse, '/wiki-files?deleted=' + HTTPEncode(FileName))
      else
        SendJSON(AResponse, TJSONObject.Create(['deleted', True, 'name', FileName]));
    finally
      UnlockFiles;
    end;
  finally
    Paths.Free;
  end;
end;

procedure PrepareFiles;
begin
  ForceDirectories(FilesRoot + 'wiki-images');
  // Each upload handler still enforces its own configured limit.
  TUploadedFiles.MaxUploadFileSize := Max(TUploadedFiles.MaxUploadFileSize, MAX_UPLOAD_MB * MB);
end;

initialization
  RegisterPictureFolder('/wiki-images/');
  RegisterPartPaths('wiki', ['/wiki-file', '/wiki-files']);
  RegisterUpgrade('wiki-files-v1', 'CREATE TABLE IF NOT EXISTS wiki_files (' +
    'name VARCHAR(240) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin PRIMARY KEY, path VARCHAR(512) NOT NULL,' +
    'sha1 CHAR(40) CHARACTER SET ascii NOT NULL, size BIGINT NOT NULL, mime VARCHAR(32) NOT NULL,' +
    'width INT NOT NULL, height INT NOT NULL, uploaded_by INT NOT NULL DEFAULT 0, uploaded DATETIME NOT NULL,' +
    'description TEXT NOT NULL, version INT NOT NULL DEFAULT 1, INDEX (uploaded)) CHARACTER SET utf8mb4');
  RegisterUpgrade('wiki-file-versions-v1', 'CREATE TABLE IF NOT EXISTS wiki_file_versions (' +
    'name VARCHAR(240) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL, path VARCHAR(512) NOT NULL,' +
    'sha1 CHAR(40) CHARACTER SET ascii NOT NULL, size BIGINT NOT NULL, mime VARCHAR(32) NOT NULL,' +
    'width INT NOT NULL, height INT NOT NULL, uploaded_by INT NOT NULL, uploaded DATETIME NOT NULL,' +
    'description TEXT NOT NULL, version INT NOT NULL, PRIMARY KEY (name, version)) CHARACTER SET utf8mb4');
  RegisterPermission('wiki-files-moderate', 'Replace and delete wiki images; list unused images', 'moderator,admin');
  RegisterSetting('wiki_upload_max_mb', 'Wiki: image upload limit in MB (31 at most)', '5', 'number', 'Wiki');
  // The handler applies the current setting; the transport bounds multipart parsing.
  RegisterBodyLimit('/api/wiki/upload', MAX_UPLOAD_MB * MB + 65536);
  RegisterStartup(@PrepareFiles);
  HTTPRouter.RegisterRoute('/api/wiki/upload', rmPost, @UploadImage);
  HTTPRouter.RegisterRoute('/api/wiki/files', rmGet, @ApiFiles);
  HTTPRouter.RegisterRoute('/api/wiki/files/delete', rmPost, @DeleteImage);
  HTTPRouter.RegisterRoute('/wiki-file/*name', rmGet, @ShowFile);
  HTTPRouter.RegisterRoute('/wiki-files', rmGet, @ShowLibrary);
  UnroutedPath := @OldFileAddress;
end.
