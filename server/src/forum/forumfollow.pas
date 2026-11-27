unit ForumFollow;

{ Topic following with notices and mail for replies the follower may read.
  Stopping is remembered even after posting again; mail waits for a read
  mark before sending again. NoteReply queues delivery in the reply
  transaction; workers or CGI chores send after commit. See docs/CODE-MAP.md
  and docs/API.md. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson, httpdefs, SiteUsers;

const
  { The member's own preferences, on their profile. }
  ForumMailPref = 'forum_reply_mail';
  ForumFollowPref = 'forum_follow_posts';

type
  TFollowKey = record
    UserId, TopicId: integer;
    Member, Title: string;
  end;

function Follows(UserId, TopicId: integer): boolean;
{ Me wrote in the topic: they follow it from now on, unless they chose not
  to or stopped following this very topic. }
procedure FollowOnPost(const Me: TMember; TopicId: integer);
{ A reply went into the topic: its followers wait to be told.  Called
  inside the reply's transaction; nothing is sent here. }
procedure NoteReply(TopicId, PostId, AuthorId: integer);
{ Once that transaction is committed: tells them, off the request. }
procedure TellFollowersSoon;
{ The members a post names with @ get a notice that they were named, if
  they may read the post: noted while it is written (Before is the text it
  had, so a change tells only who it names anew), sent by TellMentioned
  once the request is committed, dropped by ForgetMentions when it is not. }
procedure NoteMentions(const Me: TMember; TopicId, PostId: integer; const Body: string; const Before: string = '');
procedure TellMentioned;
procedure ForgetMentions;
{ The member opened the topic: the notice about it has done its work. }
procedure FollowedTopicRead(UserId, TopicId: integer);
procedure StopFollow(UserId, TopicId: integer);
{ POST /api/forum/follow  topic_id and value (1 follows, 0 stops), or all=1:
  stops following every topic. }
function SetFollow(R: TRequest; const Me: TMember): TJSONObject;
{ Whose key this is, from a mail's link; False for one not known. }
function FindFollowKey(const Key: string; out Whose: TFollowKey): boolean;

implementation

uses
  Classes, Variants, SiteDb, SiteSql, SiteRoles, SiteMail, SiteMarkup, SiteNotices, ForumSwitch, ForumRules, ForumRequest, Forum;

const
  { One post tells this many members at most that it named them. }
  MentionsAPost = 10;

threadvar
  { This request's reply left followers waiting. }
  Waiting: boolean;
  { Whom this request's post named, until it is committed: member, topic, post and author, one group a line. }
  Mentioned: string;

function Follows(UserId, TopicId: integer): boolean;
begin
  Result := IntValue('SELECT state FROM forum_follows WHERE user_id = :u AND topic_id = :t', [UserId, TopicId]) = 1;
end;

function NoticeKey(TopicId: integer): string;
begin
  Result := 'forum-topic-' + IntToStr(TopicId);
end;

procedure FollowOnPost(const Me: TMember; TopicId: integer);
begin
  // a row that is there stays as it is: following, or stopped
  if MemberPref(Me.Id, ForumFollowPref) then
    Exec(SqlInsertIgnore('forum_follows', 'user_id, topic_id, stop_key', ':u, :t, :k'), [Me.Id, TopicId, RandomHex(16)]);
end;

procedure NoteReply(TopicId, PostId, AuthorId: integer);
begin
  // the first reply they have not been told of; later ones leave it be
  if ExecCount('UPDATE forum_follows SET due_post = :p WHERE topic_id = :t AND state = 1 AND due_post = 0 AND user_id <> :u', [PostId, TopicId, AuthorId]) > 0 then
    Waiting := True;
end;

function MentionKey(TopicId: integer): string;
begin
  Result := 'forum-mention-' + IntToStr(TopicId);
end;

procedure FollowedTopicRead(UserId, TopicId: integer);
begin
  MarkNoticeKeySeen(UserId, NoticeKey(TopicId));
  MarkNoticeKeySeen(UserId, MentionKey(TopicId));
end;

{$push}{$warn 5024 off}
function NoChannel(const Name: string): boolean;
begin
  Result := False;
end;
{$pop}

{ The members a text names with @, each once. }
function NamedIn(const Text: string): TStringList;
var
  Rooms: TStringList;
begin
  Result := TStringList.Create;
  if Text = '' then
    Exit;
  Rooms := TStringList.Create;
  try
    RenderText(Text, @MemberExists, @NoChannel, Result, Rooms);
  finally
    Rooms.Free;
  end;
end;

procedure NoteMentions(const Me: TMember; TopicId, PostId: integer; const Body: string; const Before: string);
var
  Names, Old: TStringList;
  Name: string;
  Who: TMember;
  Told: integer;
begin
  Names := NamedIn(Body);
  Old := NamedIn(Before);
  try
    Told := 0;
    for Name in Names do
    begin
      if Told >= MentionsAPost then
        Break;
      if Old.IndexOf(Name) >= 0 then
        Continue;
      Who := MemberById(MemberId(Name));
      if (Who.Id = 0) or (Who.Id = Me.Id) or Who.Banned or not Can(Who, 'forum-read') then
        Continue;
      // someone who ignores the writer hears nothing of them
      if Pos(',' + IntToStr(Me.Id) + ',', ',' + IgnoredIds(Who.Id) + ',') > 0 then
        Continue;
      // the board, as it stands for the member named
      try
        NeedReadablePost(Who, PostId);
      except
        on EForumRequest do
          Continue;
      end;
      Mentioned := Mentioned + Format('%d,%d,%d,%d', [Who.Id, TopicId, PostId, Me.Id]) + LineEnding;
      Inc(Told);
    end;
  finally
    Old.Free;
    Names.Free;
  end;
end;

procedure ForgetMentions;
begin
  Mentioned := '';
end;

procedure TellMentioned;
var
  Lines: TStringList;
  Line: string;
  Part: TStringArray;
begin
  if Mentioned = '' then
    Exit;
  Lines := TStringList.Create;
  try
    Lines.Text := Mentioned;
    Mentioned := '';
    for Line in Lines do
    begin
      Part := Line.Split([',']);
      if Length(Part) <> 4 then
        Continue;
      // the newest one of a topic stands for it, and reading the topic marks it seen
      ReplaceNotice(StrToInt(Part[0]), 'forum-mention', MentionKey(StrToInt(Part[1])),
        VarToStr(Value('SELECT name FROM users WHERE id = :u', [StrToInt(Part[3])])) + ' mentioned you in "' +
        VarToStr(Value('SELECT title FROM forum_topics WHERE id = :t', [StrToInt(Part[1])])) + '"', ForumPostUrl(StrToInt(Part[1]), StrToInt(Part[2])));
    end;
  finally
    Lines.Free;
  end;
end;

procedure StopFollow(UserId, TopicId: integer);
begin
  Exec('UPDATE forum_follows SET state = 0, due_post = 0 WHERE user_id = :u AND topic_id = :t', [UserId, TopicId]);
end;

function SetFollow(R: TRequest; const Me: TMember): TJSONObject;
var
  TopicId: integer;
begin
  if Field(R, 'all') = '1' then
  begin
    Exec('UPDATE forum_follows SET state = 0, due_post = 0 WHERE user_id = :u', [Me.Id]);
    Exit(TJSONObject.Create(['ok', True]));
  end;
  TopicId := Number(Field(R, 'topic_id'));
  NeedReadableTopic(Me, TopicId);
  if Flag(R, 'value') = 1 then
    Exec('INSERT INTO forum_follows (user_id, topic_id, stop_key) VALUES (:u, :t, :k)' + SqlOnConflict('user_id, topic_id', 'state = 1'), [Me.Id, TopicId, RandomHex(16)])
  else
    StopFollow(Me.Id, TopicId);
  Result := TJSONObject.Create(['ok', True, 'following', Follows(Me.Id, TopicId)]);
end;

function FindFollowKey(const Key: string; out Whose: TFollowKey): boolean;
begin
  Whose := Default(TFollowKey);
  if IsHex(Key, 32) then
    with Query('SELECT f.user_id, f.topic_id, u.name, t.title FROM forum_follows f JOIN users u ON u.id = f.user_id' +
        ' JOIN forum_topics t ON t.id = f.topic_id WHERE f.stop_key = :k', [Key]) do
    try
      if not EOF then
      begin
        Whose.UserId := Fields[0].AsInteger;
        Whose.TopicId := Fields[1].AsInteger;
        Whose.Member := Fields[2].AsString;
        Whose.Title := Fields[3].AsString;
      end;
    finally
      Free;
    end;
  Result := Whose.UserId > 0;
end;

{ Whether a mail about the topic may go to the member now: they want the
  forum's mail, have an address they confirmed, have read the reply the
  last mail was about, and the forum has not sent its hour's worth. }
function MailAddress(const Who: TMember; MailedPost: integer): string;
begin
  Result := '';
  if not Who.Verified or (Setting('forum_follow_mail', '1') <> '1') or not MailReady or not MemberPref(Who.Id, ForumMailPref) then
    Exit;
  // as the forum tells unread posts: by the topic's read mark and the board's
  if (MailedPost > 0) and (IntValue('SELECT COUNT(*) FROM forum_posts p JOIN forum_topics t ON t.id = p.topic_id WHERE p.id = :p' +
    ' AND p.id > COALESCE((SELECT r.post_id FROM forum_topic_reads r WHERE r.user_id = :u AND r.topic_id = t.id), 0)' +
    ' AND p.created > COALESCE((SELECT b.read_at FROM forum_board_reads b WHERE b.user_id = :u2 AND b.board_id = t.board_id), ''1000-01-01'')',
    [MailedPost, Who.Id, Who.Id]) > 0) then
    Exit;
  if IntValue('SELECT COUNT(*) FROM forum_follows WHERE mailed_at > ' + SqlAgo('1', suHour), []) >= SettingInt('forum_follow_mail_hour', 200) then
  begin
    Log('Forum: no mail about a reply to ' + Who.Name + ', the hour''s mails are sent (forum_follow_mail_hour)');
    Exit;
  end;
  Result := VarToStr(Value('SELECT email FROM users WHERE id = :u AND verified = 1', [Who.Id]));
end;

function MailReply(const Address, Member, Author, Title, Body, Link, Key: string): boolean;
var
  Url, Off: string;
begin
  Url := Setting('url', '');
  Off := Url + '/forum/mail-off/' + Key;
  Result := SendMail(Address, 'Reply in: ' + Title + ' (' + Setting('name', 'Exedra') + ')', 'Hello ' + Member + ','#10#10 + Author +
    ' replied in "' + Title + '":'#10#10 + '  ' + PlainLine(Body, 300) + #10#10 + 'Read it: ' + Url + Link + #10#10 + '--'#10 +
    'You follow this topic. This is the one mail about it until you have read it.'#10 + 'Stop mail about this topic (no need to sign in):'#10 +
    Off + #10 + 'Stop all forum mail:'#10 + Off + '/all'#10 + 'or change what you follow on the forum, and the mail on your profile page.'#10,
    'List-Unsubscribe: <' + Off + '>'#13#10 + 'List-Unsubscribe-Post: List-Unsubscribe=One-Click'#13#10);
end;

{ One follower who waits: the first reply since DuePost that they may read,
  as a notice and, when one is due, a mail. }
procedure TellOne(UserId, TopicId, DuePost, MailedPost: integer; const Key: string);
var
  Who: TMember;
  PostId: integer;
  Title, Author, Body, Ignored, Address, Link: string;
begin
  Who := MemberById(UserId);
  if (Who.Id = 0) or Who.Banned or not Can(Who, 'forum-read') then
    Exit;
  Ignored := IgnoredIds(UserId);
  if Ignored <> '' then
    Ignored := ' AND p.author_id NOT IN (' + Ignored + ')';
  with Query('SELECT p.id, t.title, COALESCE(a.name, ''''), p.body FROM forum_posts p JOIN forum_topics t ON t.id = p.topic_id' +
      ' LEFT JOIN users a ON a.id = p.author_id WHERE p.topic_id = :t AND p.id >= :p AND p.hidden = 0 AND t.hidden = 0 AND p.author_id <> :u' +
      Ignored + ' ORDER BY p.id LIMIT 1', [TopicId, DuePost, UserId]) do
  try
    if EOF then
      Exit;
    PostId := Fields[0].AsInteger;
    Title := Fields[1].AsString;
    Author := Fields[2].AsString;
    Body := Fields[3].AsString;
  finally
    Free;
  end;
  // the board, as it stands now for this member
  try
    NeedReadablePost(Who, PostId);
  except
    on EForumRequest do
      Exit;
  end;
  Link := ForumPostUrl(TopicId, PostId);
  if not ReplaceNotice(UserId, 'forum', NoticeKey(TopicId), Author + ' replied in "' + Title + '"', Link) then
    Exit;
  Address := MailAddress(Who, MailedPost);
  if (Address <> '') and MailReply(Address, Who.Name, Author, Title, Body, Link, Key) then
    Exec('UPDATE forum_follows SET mailed_post = :p, mailed_at = NOW() WHERE user_id = :u AND topic_id = :t', [PostId, UserId, TopicId]);
end;

{ A round: everyone who waits, a batch at a time.  Each is taken before
  they are told, so of two rounds at once only one tells them. }
procedure TellFollowers;
const
  BATCH = 200;
var
  Due: array of record
    UserId, TopicId, DuePost, MailedPost: integer;
    Key: string;
    end;
  I: integer;
begin
  if not ForumOn then
    Exit;
  repeat
    Due := nil;
    with Query('SELECT user_id, topic_id, due_post, mailed_post, stop_key FROM forum_follows WHERE due_post > 0 ORDER BY topic_id, user_id LIMIT ' + IntToStr(BATCH), []) do
    try
      while not EOF do
      begin
        SetLength(Due, Length(Due) + 1);
        Due[High(Due)].UserId := Fields[0].AsInteger;
        Due[High(Due)].TopicId := Fields[1].AsInteger;
        Due[High(Due)].DuePost := Fields[2].AsInteger;
        Due[High(Due)].MailedPost := Fields[3].AsInteger;
        Due[High(Due)].Key := Fields[4].AsString;
        Next;
      end;
    finally
      Free;
    end;
    for I := 0 to High(Due) do
      if ExecCount('UPDATE forum_follows SET due_post = 0 WHERE user_id = :u AND topic_id = :t AND due_post = :p', [Due[I].UserId, Due[I].TopicId, Due[I].DuePost]) > 0 then
      try
        TellOne(Due[I].UserId, Due[I].TopicId, Due[I].DuePost, Due[I].MailedPost, Due[I].Key);
      except
        on E: Exception do
          Log('Forum: a follower was not told of a reply: ' + E.Message);
      end;
  until Length(Due) < BATCH;
end;

{$ifndef CGI}
type
  { One round, off the request's thread. }
  TFollowRound = class(TThread)
  protected
    procedure Execute; override;
  end;

procedure TFollowRound.Execute;
begin
  try
    CheckConnection;
    try
      TellFollowers;
    finally
      DoneConnection;
    end;
  except
    on E: Exception do
      Log('Forum follows: ' + E.Message);
  end;
end;
{$endif}

procedure TellFollowersSoon;
begin
  if not Waiting then
    Exit;
  Waiting := False;
  // a CGI program has no threads: the chore tells them there
  {$ifndef CGI}
  with TFollowRound.Create(True) do
  begin
    FreeOnTerminate := True;
    Start;
  end;
  {$endif}
end;

initialization
  RegisterTable('CREATE TABLE IF NOT EXISTS forum_follows (user_id INT NOT NULL, topic_id INT NOT NULL, state TINYINT NOT NULL DEFAULT 1,' +
    ' due_post INT NOT NULL DEFAULT 0, mailed_post INT NOT NULL DEFAULT 0, mailed_at DATETIME NULL, stop_key CHAR(32) NOT NULL,' +
    ' PRIMARY KEY (user_id, topic_id), INDEX (topic_id, state), INDEX (due_post), INDEX (mailed_at), INDEX (stop_key)) ENGINE=InnoDB');
  // the forum mails about a reply itself, so the mail of what was missed leaves its notices out
  RegisterMailedNotices('forum');
  RegisterSetting('forum_follow_mail', 'Email members about replies in the topics they follow', '1', 'yesno', 'Forum');
  RegisterSetting('forum_follow_mail_hour', 'Mails about replies the forum sends in an hour, at most', '200', 'number', 'Forum');
  RegisterMemberPref(ForumMailPref, 'Email me about replies in forum topics I follow', True, @ForumOn);
  RegisterMemberPref(ForumFollowPref, 'Follow a topic when I post in it', True, @ForumOn);
  RegisterChore(@TellFollowers, 5);
end.
