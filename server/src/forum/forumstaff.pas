unit ForumStaff;

{ Forum moderation: post reports and stopping a member from posting in the
  forum while retaining reading access. Requests use Forum.Handle and its
  transaction; other modules are unaffected. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, httpdefs, SiteUsers;

{ Whether a moderator stopped this member posting in the forum.  Asked many
  times while one page is drawn, so the answer is kept for the request:
  ForumRequestStarts forgets it. }
function ForumStopped(UserId: integer): boolean;
procedure ForumRequestStarts;

{ POST /api/forum/member/stop  user_id, value (1 stops, 0 lets post again), reason }
function StopMember(R: TRequest; const Me: TMember): TJSONObject;
{ POST /api/forum/post/report  id, reason }
function ReportPost(R: TRequest; const Me: TMember): TJSONObject;
{ POST /api/forum/report/done  id }
function CloseReport(R: TRequest; const Me: TMember): TJSONObject;
{ The open reports a moderator may see, oldest first; and how many. }
function OpenReports(const Me: TMember): TJSONArray;
function OpenReportCount(const Me: TMember): integer;

implementation

uses
  Variants, sqldb, SiteDb, SiteRoles, SiteSql, ForumRequest, Forum;

threadvar
  StoppedKnown: integer;
  StoppedAnswer: boolean;

procedure ForumRequestStarts;
begin
  StoppedKnown := 0;
end;

function ForumStopped(UserId: integer): boolean;
begin
  if UserId <= 0 then
    Exit(False);
  if StoppedKnown <> UserId then
  begin
    StoppedAnswer := IntValue('SELECT COALESCE(MAX(stopped), 0) FROM forum_members WHERE user_id = :u', [UserId]) = 1;
    StoppedKnown := UserId;
  end;
  Result := StoppedAnswer;
end;

function StopMember(R: TRequest; const Me: TMember): TJSONObject;
var
  Id: integer;
  Roles, Reason: string;
  Stop: boolean;
begin
  if not Moderate(Me) then
    Refuse(403, 'You cannot moderate the forum.');
  Id := StrToIntDef(R.ContentFields.Values['user_id'], 0);
  if (Id <= 0) or (IntValue('SELECT COUNT(*) FROM users WHERE id = :u', [Id]) = 0) then
    Refuse(404, 'No member by that name.');
  Stop := R.ContentFields.Values['value'] = '1';
  Reason := Copy(Trim(R.ContentFields.Values['reason']), 1, 500);
  if Stop then
  begin
    if Id = Me.Id then
      Refuse(400, 'You cannot stop yourself posting.');
    // the forum's own staff and the site's are not stopped by a moderator
    Roles := VarToStr(Value('SELECT roles FROM users WHERE id = :u', [Id]));
    if Shielded(Roles) or HasRole(Roles, 'forum-moderator') or HasRole(Roles, 'forum-admin') then
      Refuse(403, 'A moderator''s posting is not stopped here.');
    if Reason = '' then
      Refuse(400, 'Say why, in a few words.');
  end;
  EnsureForumMember(Id);
  Exec('UPDATE forum_members SET stopped = :v, stopped_by = :b, stopped_reason = :r WHERE user_id = :u', [Ord(Stop), Me.Id, Reason, Id]);
  ForumRequestStarts;
  Result := TJSONObject.Create(['ok', True]);
end;

function ReportPost(R: TRequest; const Me: TMember): TJSONObject;
var
  Id: integer;
  Reason: string;
begin
  Id := StrToIntDef(R.ContentFields.Values['id'], 0);
  if not Me.Verified then
    Refuse(403, 'Confirm your email first.');
  // only a post this member can read is one they can report
  NeedReadablePost(Me, Id);
  Reason := Trim(R.ContentFields.Values['reason']);
  if Reason = '' then
    Refuse(400, 'Say what is wrong with the post, in a few words.');
  if Length(Reason) > 500 then
    Refuse(400, 'The text is too long.');
  // one open report of a post from a member is enough
  if IntValue('SELECT COUNT(*) FROM forum_reports WHERE post_id = :p AND reporter_id = :u AND done_at IS NULL', [Id, Me.Id]) = 0 then
    Exec('INSERT INTO forum_reports (post_id, reporter_id, reason, created) VALUES (:p, :u, :r, NOW(6))', [Id, Me.Id, Reason]);
  Result := TJSONObject.Create(['ok', True, 'reported', True]);
end;

function CloseReport(R: TRequest; const Me: TMember): TJSONObject;
var
  Id: integer;
begin
  if not Moderate(Me) then
    Refuse(403, 'You cannot moderate the forum.');
  Id := StrToIntDef(R.ContentFields.Values['id'], 0);
  // only a report this moderator is shown: of a post in a board they read
  NeedReadablePost(Me, IntValue('SELECT post_id FROM forum_reports WHERE id = :i', [Id]));
  Exec('UPDATE forum_reports SET done_by = :u, done_at = NOW(6) WHERE id = :i AND done_at IS NULL', [Me.Id, Id]);
  Result := TJSONObject.Create(['ok', True]);
end;

{ The open reports of posts in boards this moderator reads. }
function ReportsWhere(const Me: TMember): string;
var
  Ids: string;
begin
  Ids := ReadableBoards(Me);
  if Ids = '' then
    Ids := '0';
  Result := ' FROM forum_reports r JOIN forum_posts p ON p.id = r.post_id JOIN forum_topics t ON t.id = p.topic_id' +
    ' WHERE r.done_at IS NULL AND t.board_id IN (' + Ids + ')';
end;

function OpenReportCount(const Me: TMember): integer;
begin
  Result := 0;
  if Moderate(Me) then
    Result := IntValue('SELECT COUNT(*)' + ReportsWhere(Me), []);
end;

function OpenReports(const Me: TMember): TJSONArray;
var
  Q: TSQLQuery;
begin
  Result := TJSONArray.Create;
  if not Moderate(Me) then
    Exit;
  try
    Q := Query('SELECT r.id, r.post_id, r.reason, ' + SqlIsoTime('r.created') + ' AS reported, t.id AS topic_id, t.title,' +
      ' COALESCE(a.name, '''') AS author, COALESCE(w.name, '''') AS reporter, p.hidden' + ReportsWhere(Me).Replace(' WHERE ',
      ' LEFT JOIN users a ON a.id = p.author_id LEFT JOIN users w ON w.id = r.reporter_id WHERE ') + ' ORDER BY r.id LIMIT 200', []);
    try
      while not Q.EOF do
      begin
        Result.Add(TJSONObject.Create(['id', Q.FieldByName('id').AsInteger, 'post_id', Q.FieldByName('post_id').AsInteger, 'reason',
          Q.FieldByName('reason').AsString, 'created', Q.FieldByName('reported').AsString, 'topic_id', Q.FieldByName('topic_id').AsInteger,
          'title', Q.FieldByName('title').AsString, 'author', Q.FieldByName('author').AsString, 'reporter', Q.FieldByName('reporter').AsString,
          'hidden', Q.FieldByName('hidden').AsInteger <> 0]));
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

initialization
  RegisterTable('CREATE TABLE IF NOT EXISTS forum_reports (id INT AUTO_INCREMENT PRIMARY KEY, post_id INT NOT NULL, reporter_id INT NOT NULL,' +
    ' reason VARCHAR(500) NOT NULL, created DATETIME(6) NOT NULL, done_by INT NULL, done_at DATETIME(6) NULL,' +
    ' INDEX (done_at, id), INDEX (post_id)) ENGINE=InnoDB CHARACTER SET utf8mb4');
  RegisterUpgrade('forum-member-stopped', 'ALTER TABLE forum_members ADD COLUMN IF NOT EXISTS stopped TINYINT NOT NULL DEFAULT 0');
  RegisterUpgrade('forum-member-stopped-by', 'ALTER TABLE forum_members ADD COLUMN IF NOT EXISTS stopped_by INT NULL');
  RegisterUpgrade('forum-member-stopped-reason', 'ALTER TABLE forum_members ADD COLUMN IF NOT EXISTS stopped_reason VARCHAR(500) NOT NULL DEFAULT ''''');
end.
