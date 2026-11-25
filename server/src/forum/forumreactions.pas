unit ForumReactions;

{ Post reactions from SiteReactions choices, less the forum's excluded
  emoji. Anyone allowed to post may react to a readable post, including
  their own. Only forum_reactions changes: post order, counts and unread
  marks are unaffected. Requests use Forum.Handle. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson, httpdefs, SiteUsers;

{ The reactions the forum offers now: the ones shown at once, and the rest. }
procedure ForumReactionLists(out Shown, More: TStringArray);
{ POST /api/forum/react  post, r (an emoji): puts the member's reaction on
  the post or takes it back.  Answers the post's reactions as they are then. }
function React(R: TRequest; const Me: TMember): TJSONObject;
{ GET /api/forum/reacted?post=&r=  who put the emoji r on the post. }
function Reacted(R: TRequest; const Me: TMember): TJSONObject;

implementation

uses
  Classes, StrUtils, SiteDb, SiteAdmin, SiteReactions, ForumRequest, Forum;

function LeftOut: TStringArray;
begin
  Result := Setting('forum_reactions_out', '').Split([' '], TStringSplitOptions.ExcludeEmpty);
end;

function Offered(const List, Without: TStringArray): TStringArray;
var
  Emoji: string;
begin
  Result := nil;
  for Emoji in List do
    if not MatchStr(Emoji, Without) then
      Result := Concat(Result, [Emoji]);
end;

procedure ForumReactionLists(out Shown, More: TStringArray);
begin
  ReactionLists(Shown, More);
  Shown := Offered(Shown, LeftOut);
  More := Offered(More, LeftOut);
end;

function React(R: TRequest; const Me: TMember): TJSONObject;
var
  PostId: integer;
  Emoji: string;
  List: TJSONArray;
begin
  NeedWrite(Me);
  PostId := Number(Field(R, 'post'));
  Emoji := Trim(Field(R, 'r'));
  // the post's row is held, so it is not deleted while a reaction is put on it
  with Query('SELECT id FROM forum_posts WHERE id = :p FOR UPDATE', [PostId]) do
    Free;
  NeedReadablePost(Me, PostId);
  // one's own comes off whatever it is and wherever the topic stands
  if ExecCount('DELETE FROM forum_reactions WHERE post_id = :p AND user_id = :u AND reaction = :r', [PostId, Me.Id, Emoji]) = 0 then
  begin
    if not IsReaction(Emoji) or MatchStr(Emoji, LeftOut) then
      Refuse(400, NoSuchReaction);
    // as with a reply: nothing new on what is hidden, and on a locked topic only from a moderator
    if IntValue('SELECT COUNT(*) FROM forum_posts p JOIN forum_topics t ON t.id = p.topic_id WHERE p.id = :p' +
      ' AND (p.hidden = 1 OR t.hidden = 1 OR (t.locked = 1 AND :moderator = 0))', [PostId, Ord(Moderate(Me))]) > 0 then
      Refuse(403, 'This topic is closed to reactions.');
    Exec('INSERT INTO forum_reactions (post_id, user_id, reaction) VALUES (:p, :u, :r)', [PostId, Me.Id, Emoji]);
  end;
  List := TJSONArray.Create([TJSONObject.Create(['id', PostId, 'reactions', TJSONArray.Create])]);
  try
    AttachReactions(List, 'forum_reactions', 'post_id', IntToStr(PostId), Me.Id);
    Result := TJSONObject(List.Extract(0));
  finally
    List.Free;
  end;
end;

function Reacted(R: TRequest; const Me: TMember): TJSONObject;
var
  PostId: integer;
begin
  PostId := Number(R.QueryFields.Values['post']);
  NeedReadablePost(Me, PostId);
  Result := WhoReacted('forum_reactions', 'post_id', PostId, R.QueryFields.Values['r']);
end;

function CheckLeftOut(Sent: TStrings): string;
begin
  Result := EmojiLineProblem(Sent.Values['forum_reactions_out']);
end;

initialization
  RegisterTable(ReactionTable('forum_reactions', 'post_id'));
  RegisterSetting('forum_reactions_out', 'Reactions the forum leaves out: emoji with spaces between them', '', 'longtext', 'Forum');
  RegisterSettingsCheck(@CheckLeftOut);
end.
