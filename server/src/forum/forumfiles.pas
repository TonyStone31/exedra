unit ForumFiles;

{ Post files use SiteFiles storage and /f/token/name addresses with forum-
  specific size and type limits. Files belong to the post that names them
  and are removed with it; unattached uploads expire after a day. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, httpdefs, SiteUsers;

const
  { the purpose the forum's files carry in the files table }
  FORUM_FILE = 'forum';

{ What the post box needs to know about files, as attributes of the
  textarea: the largest size and the kinds accepted; '' when this member
  may add none. }
function ForumUploadAttributes(const Me: TMember): string;
{ Before the request's transaction: the file sent is checked and scanned,
  and the member's uploads are locked until FreeFileLock. }
function CheckUpload(R: TRequest; const Me: TMember): TUploadedFile;
procedure FreeFileLock;
{ POST /api/forum/upload  file }
function UploadFile(Sent: TUploadedFile; const Me: TMember): TJSONObject;
{ Gives a post the files its text names.  With DropOthers, a file the post
  had and its text no longer names is deleted. }
procedure KeepPostFiles(PostId, UserId: integer; const Body: string; DropOthers: boolean = False);

implementation

uses
  Variants, SiteDb, SiteRoles, SiteFiles, SiteScan, SiteSql, ForumSwitch, ForumRequest, Forum;

const
  PICTURE_TYPES = ' png jpg jpeg gif webp ';
  DEFAULT_TYPES = 'png jpg jpeg gif webp zip txt log pas pp inc lpr lfm lpi lpk patch diff pdf';

{ Who may fetch a file of a forum post: whoever may read the post.  One not
  yet in a post is its sender's, to see in the preview. }
function MayFetchFile(ARequest: TRequest; MessageId, OwnerId: integer): boolean;
var
  Me: TMember;
begin
  Result := False;
  if not ForumOn then
    Exit;
  Me := CurrentMember(ARequest);
  if not Can(Me, 'forum-read') then
    Exit;
  if MessageId = 0 then
    Exit((Me.Id > 0) and ((Me.Id = OwnerId) or Moderate(Me)));
  try
    NeedReadablePost(Me, MessageId);
    Result := True;
  except
    on EForumRequest do
      Result := False;
  end;
end;

function UploadMb: integer;
begin
  Result := SettingInt('forum_upload_mb', 5);
end;

{ The accepted kinds between blanks: " png jpg zip ". }
function UploadTypes: string;
var
  C: char;
begin
  Result := ' ';
  for C in LowerCase(Setting('forum_upload_types', DEFAULT_TYPES)) do
    if C in ['a'..'z', '0'..'9'] then
      Result := Result + C
    else if Result[Length(Result)] <> ' ' then
      Result := Result + ' ';
  if Result[Length(Result)] <> ' ' then
    Result := Result + ' ';
end;

function MayUpload(const Me: TMember): boolean;
begin
  Result := Writable(Me) and Can(Me, 'forum-upload') and (UploadMb > 0) and (Trim(UploadTypes) <> '');
end;

function ForumUploadAttributes(const Me: TMember): string;
begin
  if MayUpload(Me) then
    Result := ' data-upload-mb="' + IntToStr(UploadMb) + '" data-upload-types="' + Trim(UploadTypes) + '"'
  else
    Result := '';
end;

threadvar
  { the named lock an upload holds until its request is done }
  FileLock: string;

procedure FreeFileLock;
begin
  if FileLock <> '' then
  begin
    IntValue('SELECT ' + SqlUnlock(':n'), [FileLock]);
    FileLock := '';
  end;
end;

{ The file checked and scanned, before the request's transaction: a scan
  may take minutes, and SQLite's write lock would be held all along.  The
  member's lock is held from here until the request is done. }
function CheckUpload(R: TRequest; const Me: TMember): TUploadedFile;
var
  Kind, Refusal: string;
  Code: integer;
begin
  NeedWrite(Me);
  if not MayUpload(Me) then
    Refuse(403, 'Adding files to posts is not open to you here.');
  if R.Files.Count <> 1 then
    Refuse(400, 'Send one file at a time.');
  Result := R.Files[0];
  if Result.Size > int64(UploadMb) * 1024 * 1024 then
    Refuse(413, 'That file is too big for the forum.');
  // a member's uploads one after another: two at once would each find room
  // for itself in the same space
  if IntValue('SELECT ' + SqlLock(':n', 10), ['files-' + IntToStr(Me.Id)]) <> 1 then
    Refuse(409, 'Another of your files is still being taken in. Try again.');
  // let go by the request's handler once the file's row is saved for good
  FileLock := 'files-' + IntToStr(Me.Id);
  if IntValue('SELECT COALESCE(SUM(size), 0) FROM files WHERE user_id = :u', [Me.Id]) + Result.Size > SettingInt('user_quota_mb', 500) * int64(1024 * 1024) then
    Refuse(413, 'Your files are at their limit. Delete some messages with files first.');
  Kind := LowerCase(ExtractFileExt(Result.FileName));
  Delete(Kind, 1, 1);
  if (Kind = '') or (Pos(' ' + Kind + ' ', UploadTypes) = 0) then
    Refuse(415, 'That kind of file is not accepted here.');
  // a picture is one by its first bytes, whatever its name says
  if (Pos(' ' + Kind + ' ', PICTURE_TYPES) > 0) and (ImageType(Result.LocalFileName) = '') then
    Refuse(415, 'That file is not the picture its name says it is.');
  // outside a transaction, the scan's row of a refusal stays
  if not UploadScanPasses(Me.Id, 'forum', Result.FileName, Result.LocalFileName, Refusal, Code) then
    Refuse(Code, Refusal);
end;

{ POST /api/forum/upload  file: kept, inside the transaction, once CheckUpload passed it. }
function UploadFile(Sent: TUploadedFile; const Me: TMember): TJSONObject;
var
  Mime, Token, Name: string;
begin
  Mime := ImageType(Sent.LocalFileName);
  Token := StoreFile(Me.Id, FORUM_FILE, Sent.FileName, Sent.LocalFileName, 0, 0);
  Name := VarToStr(Value('SELECT name FROM files WHERE token = :t', [Token]));
  Result := TJSONObject.Create(['token', Token, 'name', Name, 'size', Sent.Size, 'image', Mime <> '', 'url', '/f/' + Token + '/' + Name]);
end;

{ The files a post's text names become the post's: /f/ and the 32 letters
  of a token.  Only the member's own, not yet in another post.  With
  DropOthers, a file the post had and its text no longer names is deleted:
  the post was changed and the file taken out. }
procedure KeepPostFiles(PostId, UserId: integer; const Body: string; DropOthers: boolean = False);
var
  P, I: integer;
  Token, Tokens: string;
  Good: boolean;
  Gone: TStringList;
begin
  Tokens := '';
  P := Pos('/f/', Body);
  while P > 0 do
  begin
    Token := Copy(Body, P + 3, 32);
    Good := (Length(Token) = 32) and (Copy(Body, P + 35, 1) = '/');
    for I := 1 to Length(Token) do
      if not (Token[I] in ['0'..'9', 'a'..'f']) then
        Good := False;
    if Good and (Pos(Token, Tokens) = 0) then
      Tokens := Tokens + Token + ',';
    P := Pos('/f/', Body, P + 3);
  end;
  if Tokens <> '' then
    AttachFiles(PostId, 0, UserId, Tokens, FORUM_FILE, FORUM_FILE);
  if not DropOthers then
    Exit;
  Gone := TStringList.Create;
  try
    with Query('SELECT token FROM files WHERE message_id = :m AND purpose = :p', [PostId, FORUM_FILE]) do
    try
      while not EOF do
      begin
        if Pos(Fields[0].AsString, Tokens) = 0 then
          Gone.Add(Fields[0].AsString);
        Next;
      end;
    finally
      Free;
    end;
    for Token in Gone do
      DeleteFileByToken(Token);
  finally
    Gone.Free;
  end;
end;

initialization
  RegisterFileGuard(FORUM_FILE, @MayFetchFile);
  RegisterPermission('forum-upload', 'Add files to forum posts', 'member');
  RegisterSetting('forum_upload_mb', 'Largest file in a forum post, in MB (0: no files; 32 MB at most)', '5', 'number', 'Forum');
  RegisterSetting('forum_upload_types', 'Kinds of file accepted in forum posts (endings, between blanks)', DEFAULT_TYPES, 'longtext', 'Forum');
end.
