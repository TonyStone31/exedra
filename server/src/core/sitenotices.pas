unit SiteNotices;

{ Member notices: text and a link, retained until read. Registered hooks can
  deliver push and mail notifications. GET /api/notices lists notices; POST
  marks them seen. See docs/API.md for fields. }

{$mode objfpc}{$H+}

interface

uses
  fpjson;

type
  TNoticeSent = procedure(UserId: integer);

var
  { Set by the chat (ChatPush): the push, and the mail that may follow. }
  OnNoticeSent: TNoticeSent = nil;

{ Sends Text with Link (a path on this site) to the member.  Key makes it
  once only: a notice with the same Key the member had before is not sent
  again ('' sends every time).  Kind groups notices for the page that
  lists them: letters, digits and minus.  False when it was not sent. }
function SendNotice(UserId: integer; const Kind, Key, Text, Link: string): boolean;
{ A module that mails its members about its own notices says so with the
  kind it sends them under, so a mail that gathers what a member missed
  leaves those out and nobody is told twice. }
procedure RegisterMailedNotices(const Kind: string);
{ ' AND kind NOT IN (...)' for those kinds, or '' when there are none. }
function NotMailedElsewhere: string;
{ The same for something that goes on changing (a topic with a new reply):
  the notice the member had under Key gives way to this one, so there is
  one for it, the newest. }
function ReplaceNotice(UserId: integer; const Kind, Key, Text, Link: string): boolean;
{ The member's notices of Kind ('' for every kind), newest first, older
  than the notice Before when it is not 0: objects with id, kind, text,
  link, created and seen. }
function MemberNotices(UserId: integer; const Kind: string; Limit: integer; Before: integer = 0; UnseenOnly: boolean = False): TJSONArray;
function UnseenNotices(UserId: integer; const Kind: string = ''): integer;
procedure MarkNoticesSeen(UserId: integer; const Kind: string = '');
{ Only these of the member's notices, the ones a page showed. }
procedure MarkNoticeIdsSeen(UserId: integer; const Ids: array of integer);
{ The notice sent with Key: the member is looking at what it points to. }
procedure MarkNoticeKeySeen(UserId: integer; const Key: string);
{ Text cut to MaxBytes at most, never inside a character of several bytes. }
function NoticeCut(const Text: string; MaxBytes: integer): string;

implementation

uses
  SysUtils, httpdefs, httproute, SiteDb, SiteSql, SiteUsers, SiteBell;

const
  { Seen notices are kept this long. }
  KeptDays = 180;

{ A kind as it is kept: letters, digits and minus, 40 at most. }
function KindText(const Kind: string): string;
var
  C: char;
begin
  Result := '';
  for C in Kind do
    if C in ['a'..'z', 'A'..'Z', '0'..'9', '-'] then
      Result := Result + C;
  Result := Copy(Result, 1, 40);
end;

function NoticeCut(const Text: string; MaxBytes: integer): string;
var
  N: integer;
begin
  if Length(Text) <= MaxBytes then
    Exit(Text);
  N := MaxBytes;
  // back to where the character that does not fit starts
  while (N > 0) and ((Ord(Text[N + 1]) and $C0) = $80) do
    Dec(N);
  Result := Copy(Text, 1, N);
end;

var
  MailedKinds: string = '';

procedure RegisterMailedNotices(const Kind: string);
var
  C: char;
begin
  // a kind is letters, digits and minus, so it can stand in a statement as it is
  for C in Kind do
    if not (C in ['a'..'z', 'A'..'Z', '0'..'9', '-']) then
      Exit;
  if MailedKinds <> '' then
    MailedKinds := MailedKinds + ', ';
  MailedKinds := MailedKinds + '''' + Kind + '''';
end;

function NotMailedElsewhere: string;
begin
  Result := '';
  if MailedKinds <> '' then
    Result := ' AND kind NOT IN (' + MailedKinds + ')';
end;

function SendNotice(UserId: integer; const Kind, Key, Text, Link: string): boolean;
begin
  Result := False;
  if UserId <= 0 then
    Exit;
  CheckConnection;
  // nobody is there to read it
  if MemberClosed(UserId) then
    Exit;
  // the key taken in one statement: of two senders at once, one sends
  if (Key <> '') and (ExecCount(SqlInsertIgnore('notice_keys', 'user_id, note_key', ':u, :k'), [UserId, NoticeCut(Key, 190)]) = 0) then
    Exit;
  Exec('INSERT INTO notices (user_id, kind, note_key, body, link) VALUES (:u, :k, :n, :b, :l)',
    [UserId, KindText(Kind), NoticeCut(Key, 190), NoticeCut(Text, 1000), NoticeCut(Link, 300)]);
  Result := True;
  RingUser(UserId, BellNote(['t', 'notice']));
  if Assigned(OnNoticeSent) then
    OnNoticeSent(UserId);
end;

function ReplaceNotice(UserId: integer; const Kind, Key, Text, Link: string): boolean;
begin
  CheckConnection;
  Exec('DELETE FROM notices WHERE user_id = :u AND note_key = :k', [UserId, NoticeCut(Key, 190)]);
  Exec('DELETE FROM notice_keys WHERE user_id = :u AND note_key = :k', [UserId, NoticeCut(Key, 190)]);
  Result := SendNotice(UserId, Kind, Key, Text, Link);
end;

function KindWhere(const Kind: string): string;
begin
  Result := '';
  if Kind <> '' then
    Result := ' AND kind = ''' + KindText(Kind) + '''';
end;

function MemberNotices(UserId: integer; const Kind: string; Limit: integer; Before: integer; UnseenOnly: boolean): TJSONArray;
var
  Older: string;
begin
  Result := TJSONArray.Create;
  Older := '';
  if Before > 0 then
    Older := ' AND id < ' + IntToStr(Before);
  if UnseenOnly then
    Older := Older + ' AND seen = 0';
  with Query('SELECT id, kind, body, link, ' + IsoTime('created') + ', seen FROM notices WHERE user_id = :u' + KindWhere(Kind) + Older +
      ' ORDER BY id DESC LIMIT ' + IntToStr(Limit), [UserId]) do
  try
    while not EOF do
    begin
      Result.Add(TJSONObject.Create(['id', Fields[0].AsInteger, 'kind', Fields[1].AsString, 'text', Fields[2].AsString, 'link',
        Fields[3].AsString, 'created', Fields[4].AsString, 'seen', Fields[5].AsInteger = 1]));
      Next;
    end;
  finally
    Free;
  end;
end;

function UnseenNotices(UserId: integer; const Kind: string): integer;
begin
  Result := IntValue('SELECT COUNT(*) FROM notices WHERE user_id = :u AND seen = 0' + KindWhere(Kind), [UserId]);
end;

procedure MarkNoticesSeen(UserId: integer; const Kind: string);
begin
  Exec('UPDATE notices SET seen = 1 WHERE user_id = :u AND seen = 0' + KindWhere(Kind), [UserId]);
end;

procedure MarkNoticeIdsSeen(UserId: integer; const Ids: array of integer);
var
  List: string;
  Id: integer;
begin
  List := '';
  for Id in Ids do
  begin
    if List <> '' then
      List := List + ', ';
    List := List + IntToStr(Id);
  end;
  if List <> '' then
    Exec('UPDATE notices SET seen = 1 WHERE user_id = :u AND seen = 0 AND id IN (' + List + ')', [UserId]);
end;

procedure MarkNoticeKeySeen(UserId: integer; const Key: string);
begin
  Exec('UPDATE notices SET seen = 1 WHERE user_id = :u AND note_key = :k AND seen = 0', [UserId, NoticeCut(Key, 190)]);
end;

procedure ShowNotices(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  AResponse.SetCustomHeader('Cache-Control', 'private, no-store');
  SendJSON(AResponse, TJSONObject.Create(['items', MemberNotices(Me.Id, ARequest.QueryFields.Values['kind'], 50, 0, ARequest.QueryFields.Values['unseen'] = '1'),
    'unseen', UnseenNotices(Me.Id)]));
end;

procedure SeeNotices(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Kind: string;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  if FromAnotherSite(ARequest) then
  begin
    SendText(AResponse, 403, 'Press it on this site.');
    Exit;
  end;
  Kind := ARequest.ContentFields.Values['seen'];
  if Kind = 'all' then
    Kind := '';
  if ARequest.ContentFields.Values['id'] <> '' then
    MarkNoticeIdsSeen(Me.Id, [StrToIntDef(ARequest.ContentFields.Values['id'], 0)])
  else
    MarkNoticesSeen(Me.Id, Kind);
  SendJSON(AResponse, TJSONObject.Create(['unseen', UnseenNotices(Me.Id)]));
end;

procedure ForgetOldNotices;
begin
  Exec('DELETE FROM notices WHERE seen = 1 AND created < ' + SqlAgo(IntToStr(KeptDays), suDay), []);
end;

{ A closed account's notices were for its member alone. }
procedure ForgetMemberNotices(UserId: integer);
begin
  Exec('DELETE FROM notices WHERE user_id = :u', [UserId]);
  Exec('DELETE FROM notice_keys WHERE user_id = :u', [UserId]);
end;

initialization
  RegisterCloseMemberHook(@ForgetMemberNotices);
  RegisterTable('CREATE TABLE IF NOT EXISTS notices (id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, kind VARCHAR(40) NOT NULL DEFAULT '''',' +
    ' note_key VARCHAR(190) NOT NULL DEFAULT '''', body VARCHAR(1000) NOT NULL DEFAULT '''', link VARCHAR(300) NOT NULL DEFAULT '''',' +
    ' created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, seen TINYINT NOT NULL DEFAULT 0, INDEX (user_id, seen), INDEX (user_id, note_key))' + ' CHARACTER SET utf8mb4');
  // the keys a member's notices were sent with: each one once
  RegisterTable('CREATE TABLE IF NOT EXISTS notice_keys (user_id INT NOT NULL, note_key VARCHAR(190) NOT NULL, PRIMARY KEY (user_id, note_key))' + ' CHARACTER SET utf8mb4');
  // the keys of notices sent before the table above
  RegisterUpgrade('notice-keys', 'INSERT IGNORE INTO notice_keys (user_id, note_key) SELECT DISTINCT user_id, note_key FROM notices WHERE note_key <> ''''');
  HTTPRouter.RegisterRoute('/api/notices', rmGet, @ShowNotices);
  HTTPRouter.RegisterRoute('/api/notices', rmPost, @SeeNotices);
  RegisterChore(@ForgetOldNotices, 24 * 60);
end.
