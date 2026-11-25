unit SiteFiles;

{ Uploaded files, sealed files and avatars, stored outside the web root
  under random names. Admin limits cover size, quota, types and retention;
  members can request expiry or deletion after a download. Image detection
  checks file contents. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, httpdefs;

{ Gives a member's unattached uploads to a message. }
{ Uploaded: the purpose the files were sent with, when a module keeps its
  own uploads apart from the chat's ('' for the chat's own). }
procedure AttachFiles(MessageId, RoomId, UserId: integer; const Tokens: string; const Purpose: string; const Uploaded: string = '');
{ The files of the given messages, by message id. }
function FilesFor(const Ids: string; const Purpose: string): TJSONObject;
procedure DeleteFilesOf(MessageId: integer; const Purpose: string);
procedure DeleteFileByToken(const Token: string);
procedure ApplyUploadLimit;

type
  { Whether whoever sent ARequest may fetch a file: MessageId is what the
    file is attached to (0 while it is attached to nothing), OwnerId the
    member who sent it. }
  TFileGuard = function(ARequest: TRequest; MessageId, OwnerId: integer): boolean;

{ A file's address alone opens it, unless the module that keeps files of
  this purpose registers a guard: then each download asks the guard. }
procedure RegisterFileGuard(const Purpose: string; Guard: TFileGuard);

{ Between the two, files deleted are only noted, and leave the disk when
  the work is done (Done) or stay when it failed: a transaction that is
  rolled back gets its rows back, and so must find its files. }
procedure HoldFileDeletes;
procedure EndFileDeletes(Done: boolean);

var
  { Keeps an uploaded picture as a channel's own; set by the chat. }
  RoomIconSaved: procedure(const Slug, Token: string) = nil;
{ The picture type from the file's first bytes, or '' when it is not one. }
function ImageType(const FileName: string): string;
{ Keeps a copy of the file at LocalPath for a member and returns its token.
  Seconds and MaxDownloads 0 keep it for good. }
function StoreFile(UserId: integer; const Purpose, FileName, LocalPath: string; Seconds, MaxDownloads: integer): string;

implementation

uses
  StrUtils, Variants, httproute, SiteDb, SiteSql, SiteUsers, SiteRoles, SiteScan;

const
  MB = 1024 * 1024;
  UploadCeilingMB = 32;

function FilesDir: string;
begin
  Result := IncludeTrailingPathDelimiter(Setting('files_dir', ExtractFilePath(ParamStr(0)) + 'data' + PathDelim + 'files'));
end;

procedure ApplyUploadLimit;
begin
  // the most any upload may be on its way in; what takes the file (the chat,
  // the wiki, the forum) checks it against its own setting after
  TUploadedFiles.MaxUploadFileSize := UploadCeilingMB * MB;
end;

function ImageType(const FileName: string): string;
var
  F: TFileStream;
  B: array[0..23] of byte;
  Got: integer;
begin
  Result := '';
  FillChar(B, SizeOf(B), 0);
  F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    Got := F.Read(B, SizeOf(B));
  finally
    F.Free;
  end;
  // the whole signature and the start of what must follow it, not only
  // the first letters: a file cut off after them is no picture
  if (Got >= 24) and (B[0] = $89) and (B[1] = $50) and (B[2] = $4E) and (B[3] = $47) and (B[4] = $0D) and (B[5] = $0A) and (B[6] = $1A) and
    (B[7] = $0A) and (B[12] = $49) and (B[13] = $48) and (B[14] = $44) and (B[15] = $52) then
    Result := 'image/png'
  else if (Got >= 4) and (B[0] = $FF) and (B[1] = $D8) and (B[2] = $FF) and (B[3] >= $C0) then
    Result := 'image/jpeg'
  else if (Got >= 10) and (B[0] = $47) and (B[1] = $49) and (B[2] = $46) and (B[3] = $38) and (B[4] in [$37, $39]) and (B[5] = $61) then
    Result := 'image/gif'
  else if (Got >= 16) and (B[0] = $52) and (B[1] = $49) and (B[2] = $46) and (B[3] = $46) and (B[8] = $57) and (B[9] = $45) and (B[10] = $42) and (B[11] = $50) then
    Result := 'image/webp';
end;

function SafeFileName(const Name: string): string;
var
  C: char;
begin
  Result := '';
  for C in ExtractFileName(Name) do
    if C in ['A'..'Z', 'a'..'z', '0'..'9', '.', '-', '_', ' ', '(', ')'] then
      Result := Result + C
    else
      Result := Result + '_';
  Result := Copy(Trim(Result), 1, 150);
  if Result = '' then
    Result := 'file';
end;

{ A closed account's picture goes; the files in what the member wrote stay. }
procedure RemoveAvatar(UserId: integer);
var
  Token: string;
begin
  Token := VarToStr(Value('SELECT avatar FROM users WHERE id = :u', [UserId]));
  if Token <> '' then
    DeleteFileByToken(Token);
end;

{ A chore: files past their time, or never attached to anything. }
procedure CleanUpFiles;
var
  Token: string;
begin
  with Query('SELECT token FROM files WHERE expires < NOW()' + ' OR (message_id IS NULL AND purpose <> ''avatar'' AND created < ' +
      SqlAgo('1', suDay) + ')' + ' OR (max_downloads > 0 AND downloads >= max_downloads)', []) do
  try
    while not EOF do
    begin
      Token := Fields[0].AsString;
      DeleteFile(FilesDir + Token);
      Exec('DELETE FROM files WHERE token = :t', [Token]);
      Next;
    end;
  finally
    Free;
  end;
end;

{ POST /api/upload  file, expire (hour, day, week, once or empty), sealed (1
  when encrypted in the browser), avatar (1 to make it the member's avatar) }
function StoreFile(UserId: integer; const Purpose, FileName, LocalPath: string; Seconds, MaxDownloads: integer): string;
var
  Mime: string;
  Size: int64;
  Source, Target: TFileStream;
begin
  Mime := '';
  if Purpose <> 'sealed' then
    Mime := ImageType(LocalPath);
  if Mime = '' then
    Mime := 'application/octet-stream';
  Result := RandomHex(16);
  ForceDirectories(FilesDir);
  Source := TFileStream.Create(LocalPath, fmOpenRead or fmShareDenyWrite);
  Target := TFileStream.Create(FilesDir + Result, fmCreate);
  try
    Size := Target.CopyFrom(Source, 0);
  finally
    Target.Free;
    Source.Free;
  end;
  // Times are the database's clock, so the expiry is added there.
  Exec('INSERT INTO files (token, user_id, purpose, name, mime, size, expires, max_downloads) VALUES' + ' (:t, :u, :p, :n, :m, :s, ' +
    SqlIf(':e > 0', SqlAhead(':e2', suSecond), 'NULL') + ', :d)',
    [Result, UserId, Purpose, SafeFileName(FileName), Mime, Size, Seconds, Seconds, MaxDownloads]);
end;

procedure TakeUpload(ARequest: TRequest; AResponse: TResponse; const Me: TMember; Upload: TUploadedFile); forward;

procedure Upload(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Upload: TUploadedFile;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  if not Can(Me, 'upload') then
  begin
    SendText(AResponse, 403, 'Sending files is not open to you here.');
    Exit;
  end;
  if ARequest.Files.Count <> 1 then
  begin
    SendText(AResponse, 400, 'Send one file at a time.');
    Exit;
  end;
  Upload := ARequest.Files[0];
  if Upload.Size > SettingInt('upload_max_mb', 5) * MB then
  begin
    SendText(AResponse, 413, Format('Files can be %d MB at most here.', [SettingInt('upload_max_mb', 5)]));
    Exit;
  end;
  // a member's uploads one after another: two at once would each find room
  // for itself in the same space
  if IntValue('SELECT ' + SqlLock(':n', 10), ['files-' + IntToStr(Me.Id)]) <> 1 then
  begin
    SendText(AResponse, 409, 'Another of your files is still being taken in. Try again.');
    Exit;
  end;
  try
    TakeUpload(ARequest, AResponse, Me, Upload);
  finally
    IntValue('SELECT ' + SqlUnlock(':n'), ['files-' + IntToStr(Me.Id)]);
  end;
end;

{ The file checked and kept; Upload holds the member's lock around it. }
procedure TakeUpload(ARequest: TRequest; AResponse: TResponse; const Me: TMember; Upload: TUploadedFile);
var
  Token, Mime, Expire, Purpose, Name, RoomIcon, Route, Refusal, OldAvatar: string;
  Seconds, MaxDownloads, Code: integer;
begin
  if IntValue('SELECT COALESCE(SUM(size), 0) FROM files WHERE user_id = :u', [Me.Id]) + Upload.Size > SettingInt('user_quota_mb', 500) * MB then
  begin
    SendText(AResponse, 413, 'Your files are at their limit. Delete some messages with files first.');
    Exit;
  end;
  // room_icon names a channel whose icon this is (the admin page's Channels).
  RoomIcon := ARequest.ContentFields.Values['room_icon'];
  if (RoomIcon <> '') and not (Assigned(RoomIconSaved) and Can(Me, 'manage-channels')) then
  begin
    SendText(AResponse, 403, 'Channel icons are for those who run the channels.');
    Exit;
  end;
  // a channel's icon is an admin change: not from another site's page
  if (RoomIcon <> '') and FromAnotherSite(ARequest) then
  begin
    SendText(AResponse, 403, 'Press it on this site.');
    Exit;
  end;
  Purpose := 'message';
  if ARequest.ContentFields.Values['sealed'] = '1' then
    Purpose := 'sealed'
  else if (ARequest.ContentFields.Values['avatar'] = '1') or (RoomIcon <> '') then
    Purpose := 'avatar';
  Mime := '';
  if Purpose <> 'sealed' then
    Mime := ImageType(Upload.LocalFileName);
  if (Mime = '') and ((Purpose = 'avatar') or ((SettingInt('images_only', 0) = 1) and (Purpose = 'message'))) then
  begin
    SendText(AResponse, 415, 'Only pictures (PNG, JPEG, GIF, WebP) can be sent here.');
    Exit;
  end;
  if Mime = '' then
    Mime := 'application/octet-stream';
  if Purpose = 'avatar' then
    Route := 'avatar'
  else
    Route := 'chat';
  // a sealed file is scanned too: the server cannot tell a file encrypted in
  // the browser, where the scanner sees only noise, from a plain one called sealed
  if not UploadScanPasses(Me.Id, Route, Upload.FileName, Upload.LocalFileName, Refusal, Code) then
  begin
    SendText(AResponse, Code, Refusal);
    Exit;
  end;

  Seconds := 0;
  MaxDownloads := 0;
  Expire := ARequest.ContentFields.Values['expire'];
  if Expire = 'hour' then
    Seconds := SecsPerHour
  else if Expire = 'day' then
    Seconds := SecsPerDay
  else if Expire = 'week' then
    Seconds := 7 * SecsPerDay
  else if Expire = 'once' then
    MaxDownloads := 1;
  if (Seconds = 0) and (SettingInt('keep_days', 0) > 0) and (Purpose <> 'avatar') then
    Seconds := SettingInt('keep_days', 0) * SecsPerDay;

  Token := StoreFile(Me.Id, Purpose, Upload.FileName, Upload.LocalFileName, Seconds, MaxDownloads);
  Name := SafeFileName(Upload.FileName);
  if RoomIcon <> '' then
    RoomIconSaved(RoomIcon, Token)
  else if Purpose = 'avatar' then
  begin
    // the picture before goes: it would only count against the member's space
    OldAvatar := VarToStr(Value('SELECT avatar FROM users WHERE id = :u', [Me.Id]));
    Exec('UPDATE users SET avatar = :t WHERE id = :u', [Token, Me.Id]);
    if (OldAvatar <> '') and (OldAvatar <> Token) then
      DeleteFileByToken(OldAvatar);
  end;
  SendJSON(AResponse, TJSONObject.Create(['token', Token, 'name', Name, 'size', Upload.Size, 'mime', Mime, 'image', Mime.StartsWith('image/'),
    'url', '/f/' + Token + '/' + Name]));
end;

var
  FileGuards: array of record
    Purpose: string;
    Guard: TFileGuard;
    end;

threadvar
  HeldDeletes: TStringList;

procedure RegisterFileGuard(const Purpose: string; Guard: TFileGuard);
begin
  SetLength(FileGuards, Length(FileGuards) + 1);
  FileGuards[High(FileGuards)].Purpose := Purpose;
  FileGuards[High(FileGuards)].Guard := Guard;
end;

{ The guard for files of this purpose, nil for none. }
function GuardOf(const Purpose: string): TFileGuard;
var
  I: integer;
begin
  Result := nil;
  for I := 0 to High(FileGuards) do
    if FileGuards[I].Purpose = Purpose then
      Exit(FileGuards[I].Guard);
end;

procedure HoldFileDeletes;
begin
  FreeAndNil(HeldDeletes);
  HeldDeletes := TStringList.Create;
end;

procedure EndFileDeletes(Done: boolean);
var
  Token: string;
begin
  if HeldDeletes = nil then
    Exit;
  if Done then
    for Token in HeldDeletes do
      DeleteFile(FilesDir + Token);
  FreeAndNil(HeldDeletes);
end;

{ Takes a stored file off the disk, now or when the held work is done. }
procedure RemoveStored(const Token: string);
begin
  if HeldDeletes <> nil then
    HeldDeletes.Add(ExtractFileName(Token))
  else
    DeleteFile(FilesDir + ExtractFileName(Token));
end;

{ GET /f/token/name }
procedure Download(ARequest: TRequest; AResponse: TResponse);
var
  Token, SavedName, FileMime, Purpose: string;
  Content: TFileStream;
  FinalDownload: boolean;
  MessageId, OwnerId: integer;
  Guard: TFileGuard;
begin
  CheckConnection;
  Token := ARequest.RouteParams['token'];
  // the row locked while it is counted: two downloads of a file that may
  // be downloaded once cannot both get it
  Exec('START TRANSACTION', []);
  try
    Content := nil;
    with Query('SELECT name, mime, max_downloads, downloads, CASE WHEN expires < NOW() THEN 1 ELSE 0 END, purpose, COALESCE(message_id, 0), user_id' +
        ' FROM files WHERE token = :t FOR UPDATE', [Token]) do
    try
      if EOF or (Fields[4].AsInteger = 1) or ((Fields[2].AsInteger > 0) and (Fields[3].AsInteger >= Fields[2].AsInteger)) or not FileExists(FilesDir + Token) then
      begin
        Exec('ROLLBACK', []);
        SendText(AResponse, 410, 'This file is gone. It may have been set to delete itself.');
        Exit;
      end;
      SavedName := Fields[0].AsString;
      FileMime := Fields[1].AsString;
      // a sealed file goes out only as the bytes a private conversation opens
      if Fields[5].AsString = 'sealed' then
      begin
        SavedName := 'sealed';
        FileMime := 'application/octet-stream';
      end;
      FinalDownload := (Fields[2].AsInteger > 0) and (Fields[3].AsInteger + 1 >= Fields[2].AsInteger);
      Purpose := Fields[5].AsString;
      MessageId := Fields[6].AsInteger;
      OwnerId := Fields[7].AsInteger;
    finally
      Free;
    end;
    // a module that guards its files says whether this reader may have it
    Guard := GuardOf(Purpose);
    if (Guard <> nil) and not Guard(ARequest, MessageId, OwnerId) then
    begin
      Exec('ROLLBACK', []);
      SendText(AResponse, 404, 'Nothing here.');
      Exit;
    end;
    // Read straight from the disk, never whole into memory.  A file deleted
    // on its last download is still read to the end from the open stream.
    try
      Content := TFileStream.Create(FilesDir + Token, fmOpenRead or fmShareDenyNone);
    except
      on EFOpenError do
      begin
        Exec('ROLLBACK', []);
        SendText(AResponse, 410, 'This file is gone. It may have been set to delete itself.');
        Exit;
      end;
    end;
    Exec('UPDATE files SET downloads = downloads + 1 WHERE token = :t', [Token]);
    if FinalDownload then
      Exec('DELETE FROM files WHERE token = :t', [Token]);
    Exec('COMMIT', []);
  except
    Content.Free;
    Exec('ROLLBACK', []);
    raise;
  end;
  if FinalDownload then
    DeleteFile(FilesDir + Token);
  AResponse.ContentType := FileMime;
  AResponse.SetCustomHeader('X-Content-Type-Options', 'nosniff');
  AResponse.SetCustomHeader('Content-Security-Policy', 'default-src ''none''; sandbox');
  if FileMime.StartsWith('image/') then
    AResponse.SetCustomHeader('Content-Disposition', 'inline')
  else
    AResponse.SetCustomHeader('Content-Disposition', 'attachment; filename="' + SavedName + '"');
  if FinalDownload then
    AResponse.SetCustomHeader('Cache-Control', 'no-store')
  // a guarded file is asked for again soon, so a reader who lost it loses it
  else if Guard <> nil then
    AResponse.SetCustomHeader('Cache-Control', 'private, max-age=300')
  else
    AResponse.SetCustomHeader('Cache-Control', 'private, max-age=86400');
  AResponse.ContentStream := Content;
  AResponse.FreeContentStream := True;
  AResponse.SendContent;
end;

procedure AttachFiles(MessageId, RoomId, UserId: integer; const Tokens: string; const Purpose: string; const Uploaded: string);
var
  Token, Sent: string;
begin
  // a sealed upload goes with a locked private message only, and a plain one never does
  Sent := 'message';
  if Purpose = 'sealed' then
    Sent := 'sealed';
  if Uploaded <> '' then
    Sent := Uploaded;
  for Token in Tokens.Split([','], TStringSplitOptions.ExcludeEmpty) do
    Exec('UPDATE files SET message_id = :m, room_id = :r, purpose = :p WHERE token = :t' + ' AND user_id = :u AND message_id IS NULL AND purpose = :s',
      [MessageId, RoomId, Purpose, Trim(Token), UserId, Sent]);
end;

function FilesFor(const Ids: string; const Purpose: string): TJSONObject;
var
  Key: string;
  List: TJSONArray;
begin
  Result := TJSONObject.Create;
  if Ids = '' then
    Exit;
  // Ids is a list of numbers this program built, never text from a request.
  with Query('SELECT message_id, token, name, size, mime, ' + IsoTime('expires') + ', max_downloads' + ' FROM files WHERE purpose = :p AND message_id IN (' +
      Ids + ') ORDER BY id', [Purpose]) do
  try
    while not EOF do
    begin
      Key := Fields[0].AsString;
      List := TJSONArray(Result.Find(Key));
      if List = nil then
      begin
        List := TJSONArray.Create;
        Result.Add(Key, List);
      end;
      List.Add(TJSONObject.Create(['token', Fields[1].AsString, 'name', Fields[2].AsString, 'size', Fields[3].AsLargeInt, 'mime',
        Fields[4].AsString, 'image', Fields[4].AsString.StartsWith('image/'), 'url', '/f/' + Fields[1].AsString + '/' + Fields[2].AsString,
        'expires', Fields[5].AsString, 'once', Fields[6].AsInteger = 1]));
      Next;
    end;
  finally
    Free;
  end;
end;

procedure DeleteFileByToken(const Token: string);
begin
  if Token = '' then
    Exit;
  RemoveStored(Token);
  Exec('DELETE FROM files WHERE token = :t', [Token]);
end;

procedure DeleteFilesOf(MessageId: integer; const Purpose: string);
begin
  with Query('SELECT token FROM files WHERE message_id = :m AND purpose = :p', [MessageId, Purpose]) do
  try
    while not EOF do
    begin
      RemoveStored(Fields[0].AsString);
      Next;
    end;
  finally
    Free;
  end;
  Exec('DELETE FROM files WHERE message_id = :m AND purpose = :p', [MessageId, Purpose]);
end;

initialization
  RegisterTable('CREATE TABLE IF NOT EXISTS files (' + ' id INT AUTO_INCREMENT PRIMARY KEY,' + ' token CHAR(32) NOT NULL UNIQUE,' +
    ' user_id INT NOT NULL,' + ' purpose VARCHAR(8) NOT NULL,' + ' room_id INT NULL,' + ' message_id INT NULL,' + ' name VARCHAR(200) NOT NULL,' +
    ' mime VARCHAR(100) NOT NULL,' + ' size BIGINT NOT NULL,' + ' created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,' + ' expires DATETIME NULL,' +
    ' max_downloads INT NOT NULL DEFAULT 0,' + ' downloads INT NOT NULL DEFAULT 0,' + ' INDEX (message_id), INDEX (user_id), INDEX (expires)' + ') CHARACTER SET utf8mb4');
  RegisterChore(@CleanUpFiles, 10);
  RegisterCloseMemberHook(@RemoveAvatar);
  RegisterPermission('upload', 'Send files', 'member');
  HTTPRouter.RegisterRoute('/api/upload', rmPost, @Upload);
  HTTPRouter.RegisterRoute('/f/:token/:name', rmGet, @Download);
end.
