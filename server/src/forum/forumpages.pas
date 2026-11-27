unit ForumPages;

{ Forum HTML pages from Forum's reading functions and templates/forum.html.
  forum.js adds editing and API forms to plain pages. Escape all page text
  with E or use the shared Markdown renderer; W escapes translated words. }

{$mode objfpc}{$H+}

interface

uses fpjson, httpdefs, SiteUsers;

function ForumBoardTree(List: TJSONArray; ParentId: integer): string;
{ Followed: the topics a member follows, each with its button to stop. }
function ForumTopicsHtml(List: TJSONArray; Followed: boolean = False): string;
{ The button on a topic's page that follows it, or stops: a form of its
  own that needs no script. }
function ForumFollowControl(TopicId, Page: integer; Following: boolean): string;
{ Where that form's sender goes next. }
function FollowFormPage(R: TRequest): string;
function ForumRecentHtml(List: TJSONArray): string;
function ForumPostsHtml(Data: TJSONObject; const Me: TMember): string;
function ForumPager(const Path: string; Page: integer; More: boolean; const SearchText: string = ''; TotalPages: integer = 0): string;
procedure RegisterForumPages;

implementation

uses
  Classes, SysUtils, Variants, httproute, SiteDb,
  SiteRoles, SiteGuard, SiteStats, SiteVisitors, SiteWords, WebPages,
  Forum, ForumSwitch, ForumRules, ForumRequest, ForumStaff, ForumFiles, ForumReactions, ForumFollow;

function W(const Text: string): string;
begin
  Result := E(Say(Text));
end;

function Link(const Address, Caption: string): string;
begin
  Result := '<a href="' + E(Address) + '">' + E(Caption) + '</a>';
end;

function HiddenField(const Key, Text: string): string;
begin
  Result := '<input type="hidden" name="' + E(Key) + '" value="' + E(Text) + '">';
end;

function Input(const Key, Caption, Text: string; Limit: integer): string;
begin
  Result := '<label>' + E(Caption) + '<input name="' + E(Key) + '" value="' + E(Text) + '" maxlength="' + IntToStr(Limit) + '" required></label>';
end;

function Button(const Caption: string): string;
begin
  Result := '<button>' + E(Caption) + '</button>';
end;

{ A form forum.js sends; with Confirm, it asks that first. }
function Form(const Action, Fields, Caption: string; const Confirm: string = ''): string;
begin
  Result := '<form method="post" action="/api/forum/' + Action + '" data-forum-form';
  if Confirm <> '' then
    Result := Result + ' data-confirm="' + E(Confirm) + '"';
  Result := Result + '>' + Fields + Button(Caption) + '<p class="forum-error" role="alert"></p></form>';
end;

{ The post box; Upload is what ForumUploadAttributes gave for the member. }
function Editor(const Body, Upload: string): string;
begin
  Result := '<label>' + W('Post') + '<textarea class="forum-editor" name="body" rows="10" maxlength="' + IntToStr(ForumMaxBody) + '"' +
    Upload + ' required>' + E(Body) + '</textarea></label>';
end;

function ForumPager(const Path: string; Page: integer; More: boolean; const SearchText: string; TotalPages: integer): string;
var
  I, FirstPage, LastPage: integer;
begin
  Result := '<nav class="forum-pages" aria-label="' + W('Pages') + '"><span>' + W('Pages') + ':</span> ';
  if Page > 1 then
    Result := Result + Link(ForumPageUrl(Path, Page - 1, SearchText), Say('Previous')) + ' ';
  FirstPage := Page - 2;
  if FirstPage < 1 then FirstPage := 1;
  LastPage := Page + 2;
  if LastPage > TotalPages then LastPage := TotalPages;
  if (TotalPages > 1) and (FirstPage > 1) then Result := Result + Link(ForumPageUrl(Path, 1, SearchText), '1') + ' … ';
  if TotalPages > 1 then
    for I := FirstPage to LastPage do
      if I <> Page then Result := Result + Link(ForumPageUrl(Path, I, SearchText), IntToStr(I)) + ' '
      else
        Result := Result + '<strong aria-current="page">' + IntToStr(Page) + '</strong> ';
  if (TotalPages > 1) and (LastPage < TotalPages) then Result := Result + ' … ' + Link(ForumPageUrl(Path, TotalPages, SearchText), IntToStr(TotalPages));
  if TotalPages <= 1 then Result := Result + '<strong aria-current="page">' + IntToStr(Page) + '</strong>';
  if More then
    Result := Result + ' ' + Link(ForumPageUrl(Path, Page + 1, SearchText), Say('Next'));
  Result := Result + '</nav>';
end;

function PageJump(Down: boolean): string;
begin
  if Down then
    Result := '<a class="forum-jump" href="#forum-bottom">' + W('Go down') + '</a>'
  else
    Result := '<a class="forum-jump" href="#forum-top">' + W('Go up') + '</a>';
end;

function MemberLink(const Name: string): string;
begin
  Result := Link('/u/' + HTTPEncode(Name), Name);
end;

function StatusIcon(const Caption, Kind: string; Unread: boolean): string;
var
  Css, Shape: string;
begin
  Css := 'forum-status';
  if Unread then Css := Css + ' unread';
  Shape := 'M3 3h14v11H9l-5 3v-3H3z';
  if Kind <> 'posts' then Css := 'forum-symbol forum-' + Kind;
  case Kind of
    'locked': Shape := 'M5 9h10v8H5z M7 9V6a3 3 0 0 1 6 0v3 M10 12v2';
    'pinned': Shape := 'M6 3h8l-1 5 3 3H4l3-3z M10 11v7';
    'hot': Shape := 'M11 2c1 5 5 5 5 10a6 6 0 0 1-12 0c0-3 2-5 3-6 0 3 1 4 2 4 2-2 2-5 2-8z';
  end;
  Result := '<span class="' + Css + '" role="img" aria-label="' + E(Caption) + '" title="' + E(Caption) + '"><svg viewBox="0 0 20 20" aria-hidden="true"><path d="' +
    Shape + '"></path></svg></span>';
end;

function LastPost(Item: TJSONObject; BoardIndex: boolean): string;
var
  TopicId: integer;
  Address, Posted: string;
begin
  Result := '<span class="forum-last">' + W('No posts yet.') + '</span>';
  if (Item.Get('last_post_at', '') = '') or (Item.Get('last_post_id', 0) <= 0) then Exit;
  TopicId := Item.Get('last_topic_id', Item.Get('id', 0));
  Address := ForumPostUrl(TopicId, Item.Get('last_post_id', 0));
  Posted := DateTag(Item.Get('last_post_at', ''), True);
  if BoardIndex then
    // the topic on one line, who and when under it
    Result := '<span class="forum-last-topic">' + Link(Address, Item.Get('last_title', Say('Last post'))) + '</span>' +
      Format(W('%s by %s'), [Posted, MemberLink(Item.Get('last_post_name', ''))])
  else
    Result := Format(W('%s by %s'), ['<a href="' + E(Address) + '">' + Posted + '</a>', MemberLink(Item.Get('last_post_name', ''))]);
  Result := '<div class="forum-last">' + Result + '</div>';
end;

// The word beside the name of a board or topic with posts not read yet.
function NewMark(Item: TJSONObject): string;
begin
  Result := '';
  if Item.Get('unread', False) then Result := ' <span class="forum-new">' + W('New') + '</span>';
end;

// The class of a row in a list of boards or topics; one with unread posts
// says so.
function RowClass(const Css: string; Item: TJSONObject): string;
begin
  Result := Css;
  if Item.Get('unread', False) then Result := Trim(Result + ' forum-unread');
  if Result <> '' then Result := ' class="' + Result + '"';
end;

function BoardRow(Item: TJSONObject; List: TJSONArray): string;
var
  I: integer;
  Child: TJSONObject;
  Children, Caption: string;
begin
  Children := '';
  for I := 0 to List.Count - 1 do
  begin
    Child := TJSONObject(List[I]);
    if Child.Get('parent_id', 0) <> Item.Get('id', 0) then Continue;
    if Children <> '' then Children := Children + ', ';
    Children := Children + Link(ForumBoardUrl(Child.Get('slug', '')), Child.Get('name', ''));
    if Child.Get('unread', False) then Children := Children + ' ' + StatusIcon(Say('New posts'), 'posts', True);
  end;
  if Children <> '' then Children := '<p class="forum-children">' + W('Child boards') + ': ' + Children + '</p>';
  Caption := Say('No new posts');
  if Item.Get('unread', False) then Caption := Say('New posts');
  Result := '<li' + RowClass('forum-board-row', Item) + '>' + StatusIcon(Caption, 'posts', Item.Get('unread', False)) + '<div><h3>' +
    Link(ForumBoardUrl(Item.Get('slug', '')), Item.Get('name', '')) + NewMark(Item) + '</h3><p class="forum-description">' +
    E(Item.Get('description', '')) + '</p>' + Children + '</div><div class="forum-counts">' + E(SayCount(Item.Get('post_count', 0), '%d post', '%d posts')) +
    '<br>' + E(SayCount(Item.Get('topic_count', 0), '%d topic', '%d topics')) + '</div>' + LastPost(Item, True) + '</li>';
end;

function ForumBoardTree(List: TJSONArray; ParentId: integer): string;
var
  I, J, CategoryId: integer;
  Item: TJSONObject;
  Groups: TStringList;
  Rows, Caption: string;
begin
  Result := '';
  Groups := TStringList.Create;
  try
    for I := 0 to List.Count - 1 do
    begin
      Item := TJSONObject(List[I]);
      if Item.Get('parent_id', 0) <> ParentId then Continue;
      CategoryId := Item.Get('category_id', 0);
      if Groups.IndexOf(IntToStr(CategoryId)) < 0 then Groups.Add(IntToStr(CategoryId));
    end;
    for J := 0 to Groups.Count - 1 do
    begin
      CategoryId := StrToInt(Groups[J]);
      Rows := '';
      Caption := Say('General');
      for I := 0 to List.Count - 1 do
      begin
        Item := TJSONObject(List[I]);
        if (Item.Get('parent_id', 0) <> ParentId) or (Item.Get('category_id', 0) <> CategoryId) then Continue;
        if Item.Get('category', '') <> '' then Caption := Item.Get('category', '');
        Rows := Rows + BoardRow(Item, List);
      end;
      Result := Result + '<section class="forum-category" id="category-' + IntToStr(CategoryId) + '"><h2>' + E(Caption) + '</h2><ul class="forum-boards">' +
        Rows + '</ul></section>';
    end;
  finally
    Groups.Free;
  end;
end;

function Marks(Item: TJSONObject): string;
begin
  Result := '';
  if Item.Get('pinned', False) then
    Result := Result + ' ' + StatusIcon(Say('Pinned'), 'pinned', False);
  if Item.Get('locked', False) then
    Result := Result + ' ' + StatusIcon(Say('Locked'), 'locked', False);
  if Item.Get('reply_count', 0) >= 20 then
    Result := Result + ' ' + StatusIcon(Say('Hot topic'), 'hot', False);
  if Item.Get('hidden', False) then
    Result := Result + ' <span class="forum-mark">' + W('Hidden') + '</span>';
end;

function FollowForm(const Fields, Caption, Hint: string; Pressed: boolean): string;
begin
  Result := '<form class="forum-follow" method="post" action="/forum/follow">' + Fields + '<button title="' + E(Hint) + '" aria-pressed="' +
    LowerCase(BoolToStr(Pressed, True)) + '">' + E(Caption) + '</button></form>';
end;

function ForumFollowControl(TopicId, Page: integer; Following: boolean): string;
var
  Fields: string;
begin
  Fields := HiddenField('topic_id', IntToStr(TopicId)) + HiddenField('page', IntToStr(Page)) + HiddenField('value', IntToStr(Ord(not Following)));
  if Following then
    Result := FollowForm(Fields, Say('Following') + ' ✓', Say('You hear of replies to this topic. Press to stop following it.'), True)
  else
    Result := FollowForm(Fields, Say('Follow'), Say('Hear of replies to this topic: a notice here, and a mail.'), False);
end;

function FollowFormPage(R: TRequest): string;
begin
  if (Field(R, 'all') = '1') or (Field(R, 'list') = '1') then
    Result := '/forum/following'
  else
    Result := ForumPageUrl(ForumTopicUrl(StrToIntDef(Field(R, 'topic_id'), 0)), ForumPage(Field(R, 'page')));
end;

function ForumTopicsHtml(List: TJSONArray; Followed: boolean): string;
var
  I: integer;
  Item: TJSONObject;
  Caption, Stop, Column: string;
begin
  Result := '';
  for I := 0 to List.Count - 1 do
  begin
    Item := TJSONObject(List[I]);
    Caption := Say('No new posts');
    if Item.Get('unread', False) then Caption := Say('New posts');
    Result := Result + '<tr' + RowClass('', Item) + '><td>' + StatusIcon(Caption, 'posts', Item.Get('unread', False)) + '</td><td><h3>' +
      Link(ForumTopicUrl(Item.Get('id', 0)), Item.Get('title', '')) + NewMark(Item) + Marks(Item) + '</h3><p class="forum-started">' +
      W('Started by') + ' ' + MemberLink(Item.Get('author', '')) + ' · ' + DateTag(Item.Get('created', ''), True) + '</p>';
    Result := Result + '</td><td class="forum-counts">' + E(SayCount(Item.Get('reply_count', 0), '%d reply', '%d replies')) + '<br>' +
      E(SayCount(Item.Get('view_count', 0), '%d view', '%d views')) + '</td><td>' + LastPost(Item, False) + '</td>';
    if Followed then
      Result := Result + '<td>' + FollowForm(HiddenField('topic_id', IntToStr(Item.Get('id', 0))) + HiddenField('value', '0') +
        HiddenField('list', '1'), Say('Stop'), Say('Stop following this topic'), False) + '</td>';
    Result := Result + '</tr>';
  end;
  Stop := '';
  Column := '';
  if Followed then
  begin
    Stop := 'forum-followed';
    Column := '<th><span class="sr-only">' + W('Stop') + '</span></th>';
  end;
  if Result = '' then Result := '<p>' + W('No topics found.') + '</p>'
  else
    Result := '<table class="' + Trim('forum-topics ' + Stop) + '"><thead><tr><th><span class="sr-only">' + W('Status') + '</span></th><th>' +
      W('Subject') + '</th><th>' + W('Replies / Views') + '</th><th>' + W('Last post') + '</th>' + Column + '</tr></thead><tbody>' + Result + '</tbody></table>';
end;

function ForumRecentHtml(List: TJSONArray): string;
var
  I: integer;
  Item: TJSONObject;
begin
  Result := '';
  for I := 0 to List.Count - 1 do
  begin
    Item := TJSONObject(List[I]);
    Result := Result + '<article class="forum-recent"><header><h2>' + Link(ForumPostUrl(Item.Get('id', 0), Item.Get('last_post_id', 0)),
      Item.Get('title', '')) + '</h2>' + MemberLink(Item.Get('last_post_name', '')) + ' · ' + DateTag(Item.Get('last_post_at', ''), True) + '</header>';
    // Only the forum's server renderer supplies HTML in this stream.
    Result := Result + '<div class="forum-body body">' + Item.Get('html', '') + '</div></article>';
  end;
  if Result = '' then Result := '<p>' + W('No posts found.') + '</p>';
end;

function HideDetails(Item: TJSONObject): string;
begin
  Result := '';
  if Item.Get('hidden_at', '') <> '' then
    Result := '<p class="forum-hidden">' + W('Moderation') + ': ' + E(Item.Get('hidden_name', '')) + ' · ' + DateTag(Item.Get('hidden_at', ''), True) +
      ' · ' + E(Item.Get('hidden_reason', '')) + '</p>';
end;

function HideForm(const Kind, Key: string; Id: integer; IsHidden: boolean): string;
var
  Action, Caption, Fields: string;
begin
  Action := 'hide';
  Caption := Say('Hide');
  Fields := '';
  if IsHidden then
  begin
    Action := 'unhide';
    Caption := Say('Restore');
  end
  else
    Fields := Input('reason', Say('Reason'), '', 500);
  Result := Form(Kind + '/moderate', HiddenField(Key, IntToStr(Id)) + HiddenField('action', Action) + Fields, Caption);
end;

function TopicTools(Topic: TJSONObject; List: TJSONArray): string;
var
  Ids, Options, LockCaption, PinCaption: string;
  I: integer;
  Board: TJSONObject;
begin
  Ids := HiddenField('topic_id', IntToStr(Topic.Get('id', 0)));
  LockCaption := Say('Lock');
  PinCaption := Say('Pin');
  if Topic.Get('locked', False) then
    LockCaption := Say('Unlock');
  if Topic.Get('pinned', False) then
    PinCaption := Say('Unpin');
  Result := '<details data-forum-tools hidden><summary>' + W('Moderate topic') + '</summary>' + Form('topic/moderate', Ids +
    HiddenField('action', 'lock') + HiddenField('value', IntToStr(Ord(not Topic.Get('locked', False)))), LockCaption) +
    Form('topic/moderate', Ids + HiddenField('action', 'pin') + HiddenField('value', IntToStr(Ord(not Topic.Get('pinned', False)))), PinCaption) +
    HideForm('topic', 'topic_id', Topic.Get('id', 0), Topic.Get('hidden', False));
  Options := '';
  for I := 0 to List.Count - 1 do
  begin
    Board := TJSONObject(List[I]);
    if Board.Get('id', 0) = Topic.Get('board_id', 0) then
      Continue;
    Options := Options + '<option value="' + IntToStr(Board.Get('id', 0)) + '">' + E(Board.Get('name', '')) + '</option>';
  end;
  if Options <> '' then
    Result := Result + Form('topic/moderate', Ids + HiddenField('action', 'move') + '<label>' + W('Destination board') +
      '<select name="board_id" required>' + Options + '</select></label>', Say('Move'));
  Result := Result + '</details>';
end;

function PostAction(const PanelId, Caption: string): string;
begin
  Result := '<button type="button" data-forum-panel="' + PanelId + '" aria-controls="' + PanelId + '" aria-expanded="false">' + E(Caption) + '</button>';
end;

function ActionPanel(const PanelId, Content: string): string;
begin
  Result := '<div class="forum-action-panel" id="' + PanelId + '" hidden>' + Content + '</div>';
end;

function MemberAvatar(const MemberName, Address: string): string;
var
  Hue, InitialBytes: integer;
  C: char;
  Initial: string;
begin
  if Address <> '' then
    Exit('<img class="forum-avatar" src="' + E(Address) + '" alt="" loading="lazy">');
  Hue := 0;
  for C in LowerCase(MemberName) do Hue := (Hue * 31 + Ord(C)) mod 360;
  InitialBytes := 1;
  while (InitialBytes < Length(MemberName)) and ((Ord(MemberName[InitialBytes + 1]) and $C0) = $80) do Inc(InitialBytes);
  Initial := UpperCase(Copy(MemberName, 1, InitialBytes));
  if Initial = '' then Initial := '?';
  Result := '<span class="forum-avatar forum-avatar-placeholder" aria-hidden="true" style="--forum-hue:' + IntToStr(Hue) + '">' + E(Initial) + '</span>';
end;

// The side column's link to the member's signature, while signatures are on.
function SignatureLink: string;
begin
  Result := '';
  if SignaturesOn then Result := '<a class="room member-only" href="/forum/signature">' + W('Your signature') + '</a>';
end;

// What Remove does to a post, said before it is pressed: a topic's first
// post goes with the whole topic only while the topic holds no other post.
function RemoveWords(Action: TForumDelete): string;
begin
  case Action of
    fdHide: Result := Say('This hides the first post; the replies stay. To take the whole topic out of view, a moderator hides the topic.');
    fdTopic: Result := Say('This deletes the topic.');
    else
      Result := Say('Delete this post?');
  end;
end;

// A moderator's control over the member who wrote a post: stop them posting
// in the forum, or let them post again.
function StopForm(Item: TJSONObject): string;
var
  Fields: string;
begin
  Fields := HiddenField('user_id', IntToStr(Item.Get('author_id', 0)));
  if Item.Get('stopped', False) then
    Result := '<p>' + E(Format(Say('%s cannot post in the forum.'), [Item.Get('author', '')])) + '</p>' + Form('member/stop', Fields +
      HiddenField('value', '0'), Say('Let them post again'))
  else
    Result := '<p>' + E(Format(Say('Stop %s posting in the forum? They can still read it, and the rest of the site is not touched.'), [Item.Get('author', '')])) +
      '</p>' + Form('member/stop', Fields + HiddenField('value', '1') + Input('reason', Say('Reason'), '', 500), Say('Stop posting'));
end;

// The open reports, for the forum's moderators.
function ReportsHtml(List: TJSONArray): string;
var
  I: integer;
  Item: TJSONObject;
begin
  Result := '';
  for I := 0 to List.Count - 1 do
  begin
    Item := TJSONObject(List[I]);
    Result := Result + '<tr><td>' + Link(ForumPostUrl(Item.Get('topic_id', 0), Item.Get('post_id', 0)), Item.Get('title', '')) +
      '<p class="forum-started">' + W('Post by') + ' ' + MemberLink(Item.Get('author', '')) + '</p></td><td>' + E(Item.Get('reason', '')) +
      '<p class="forum-started">' + W('Reported by') + ' ' + MemberLink(Item.Get('reporter', '')) + ' · ' + DateTag(Item.Get('created', ''), True) +
      '</p></td><td>' + Form('report/done', HiddenField('id', IntToStr(Item.Get('id', 0))), Say('Done')) + '</td></tr>';
  end;
  if Result = '' then
    Result := '<p>' + W('No reports are waiting.') + '</p>'
  else
    Result := '<table class="forum-topics forum-reports"><thead><tr><th>' + W('Post') + '</th><th>' + W('Report') + '</th><th></th></tr></thead><tbody>' +
      Result + '</tbody></table>';
end;

// The side column's link to the reports, for a moderator, with how many wait.
function ReportsLink(const Me: TMember): string;
var
  Waiting: integer;
begin
  Result := '';
  if not Moderate(Me) then
    Exit;
  Waiting := OpenReportCount(Me);
  Result := '<a class="room" href="/forum/reports">' + W('Reports');
  if Waiting > 0 then
    Result := Result + ' <span class="forum-new">' + IntToStr(Waiting) + '</span>';
  Result := Result + '</a>';
end;

// The reactions under a post: a chip for each emoji with how many gave it,
// the reader's own marked.  The chips are read as they are; forum.js makes
// them live, and where MayAdd adds the button that offers more.
function ReactionsHtml(Item: TJSONObject; MayAdd: boolean): string;
var
  List: TJSONArray;
  Chip: TJSONObject;
  I: integer;
  Mine: string;
begin
  Result := '';
  List := Item.Get('reactions', TJSONArray(nil));
  if (List = nil) or ((List.Count = 0) and not MayAdd) then
    Exit;
  for I := 0 to List.Count - 1 do
  begin
    Chip := List.Objects[I];
    Mine := '';
    if Chip.Get('mine', False) then
      Mine := ' mine';
    Result := Result + '<button type="button" class="react' + Mine + '" data-r="' + E(Chip.Get('r', '')) + '" data-n="' + IntToStr(Chip.Get('n', 0)) +
      '"><span class="emoji">' + E(Chip.Get('r', '')) + '</span> ' + IntToStr(Chip.Get('n', 0)) + '</button>';
  end;
  Mine := '';
  if MayAdd then
    Mine := ' data-add';
  Result := '<div class="reacts" data-post="' + IntToStr(Item.Get('id', 0)) + '"' + Mine + '>' + Result + '</div>';
end;

// For forum.js, once on a page whose reader may react: the emoji the forum
// offers, those shown at once and the rest.
function ReactionChoices(const Me: TMember): string;
var
  Shown, More: TStringArray;
begin
  Result := '';
  if not Writable(Me) then
    Exit;
  ForumReactionLists(Shown, More);
  Result := '<div id="forum-reactions" data-shown="' + E(string.Join(' ', Shown)) + '" data-more="' + E(string.Join(' ', More)) + '" hidden></div>';
end;

function ForumPostsHtml(Data: TJSONObject; const Me: TMember): string;
var
  Topic, Item: TJSONObject;
  List: TJSONArray;
  I: integer;
  Fields, Subject, BadgeCaption, Actions, Panels, PanelId, Caption: string;
  MayChange, MayReply: boolean;
begin
  Topic := Data.Objects['topic'];
  List := Data.Arrays['posts'];
  Result := ReactionChoices(Me);
  // whoever may reply to the topic may quote its posts and react to them
  MayReply := Writable(Me) and not Topic.Get('hidden', False) and (not Topic.Get('locked', False) or Moderate(Me));
  for I := 0 to List.Count - 1 do
  begin
    Item := TJSONObject(List[I]);
    Subject := Topic.Get('title', '');
    if Item.Get('id', 0) <> Topic.Get('first_post_id', 0) then Subject := Say('Re:') + ' ' + Subject;
    Result := Result + '<article class="forum-post" id="post-' + IntToStr(Item.Get('id', 0)) + '"><aside class="forum-poster">';
    Result := Result + MemberAvatar(Item.Get('author', ''), Item.Get('avatar', ''));
    Result := Result + '<strong>' + MemberLink(Item.Get('author', '')) + '</strong>';
    BadgeCaption := '';
    case Item.Get('badge', '') of
      'admin': BadgeCaption := Say('Administrator');
      'moderator': BadgeCaption := Say('Moderator');
      'bot': BadgeCaption := Say('Bot');
    end;
    if BadgeCaption <> '' then Result := Result + '<span class="forum-mark">' + E(BadgeCaption) + '</span>';
    if Item.Get('stopped', False) then Result := Result + '<span class="forum-mark forum-stopped">' + W('Posting stopped') + '</span>';
    // a closed account: what it wrote stays under its name, with nothing of its standing
    if Item.Get('former', False) then
      Result := Result + '<span>' + W('Former member') + '</span>'
    else
      Result := Result + '<span>' + E(SayCount(Item.Get('post_count', 0), '%d post', '%d posts')) + '</span><span>' + W('Joined') + ' ' +
        DateTag(Item.Get('joined', ''), False) + '</span>';
    Result := Result + '</aside><div class="forum-post-content"><header><h3>' + E(Subject) + '</h3>' + DateTag(Item.Get('created', ''), True) +
      ' · ' + Link(ForumPostUrl(Topic.Get('id', 0), Item.Get('id', 0)), '#' + IntToStr(Item.Get('number', I + 1))) + '</header>';
    if Item.Get('hidden', False) then
      Result := Result + '<p class="forum-hidden">' + W('This post is hidden.') + '</p>';
    // Only the shared renderer supplies post HTML; all metadata is escaped.
    if Item.Find('html') <> nil then
      Result := Result + '<div class="forum-body body">' + Item.Get('html', '') + '</div>';
    Result := Result + ReactionsHtml(Item, MayReply and not Item.Get('hidden', False));
    // the signature too comes only from the shared renderer
    if Item.Find('signature') <> nil then
      Result := Result + '<div class="forum-signature body">' + Item.Get('signature', '') + '</div>';
    if Item.Get('edited', '') <> '' then
      Result := Result + '<p class="forum-edited">' + W('Edited by') + ' ' + E(Item.Get('editor', '')) + ' · ' + DateTag(Item.Get('edited', ''), True) + '</p>';
    if Moderate(Me) then
      Result := Result + HideDetails(Item);
    Actions := '';
    Panels := '';
    if MayReply and (Item.Find('body') <> nil) then
      Actions := Actions + '<button type="button" class="forum-quote" data-author="' + E(Item.Get('author', '')) + '" data-topic="' +
        IntToStr(Topic.Get('id', 0)) + '" data-post="' + IntToStr(Item.Get('id', 0)) + '" data-body="' + E(Item.Get('body', '')) + '">' + W('Quote') + '</button>';
    MayChange := ForumMayChange(Me.Id, Item.Get('author_id', 0), Writable(Me), Moderate(Me), Topic.Get('locked', False), Item.Get('hidden', False) or
      Topic.Get('hidden', False));
    if MayChange then
    begin
      Fields := HiddenField('id', IntToStr(Item.Get('id', 0))) + HiddenField('topic_id', IntToStr(Topic.Get('id', 0)));
      PanelId := 'edit-post-' + IntToStr(Item.Get('id', 0));
      Actions := Actions + PostAction(PanelId, Say('Modify'));
      // seen: the version this form was opened on, so a change made meanwhile is not written over
      Subject := Fields + HiddenField('seen', Item.Get('edited', ''));
      if Item.Get('id', 0) = Topic.Get('first_post_id', 0) then
        Panels := Panels + ActionPanel(PanelId, Form('post/edit', Subject + Input('title', Say('Title'), Topic.Get('title', ''), 200) +
          Editor(Item.Get('body', ''), ForumUploadAttributes(Me)), Say('Save')))
      else
        Panels := Panels + ActionPanel(PanelId, Form('post/edit', Subject + Editor(Item.Get('body', ''), ForumUploadAttributes(Me)), Say('Save')));
      PanelId := 'remove-post-' + IntToStr(Item.Get('id', 0));
      Actions := Actions + PostAction(PanelId, Say('Remove'));
      // the same rule the removal goes by (ForumDeleteAction), so the words are what happens
      Caption := RemoveWords(ForumDeleteAction(True, Item.Get('id', 0) = Topic.Get('first_post_id', 0), Topic.Get('other_posts', False)));
      Panels := Panels + ActionPanel(PanelId, '<p>' + E(Caption) + '</p>' + Form('post/delete', Fields, Say('Remove'), Caption));
    end;
    if Moderate(Me) then
    begin
      PanelId := 'moderate-post-' + IntToStr(Item.Get('id', 0));
      Caption := Say('Hide');
      if Item.Get('hidden', False) then Caption := Say('Restore');
      Actions := Actions + PostAction(PanelId, Caption);
      Panels := Panels + ActionPanel(PanelId, HideForm('post', 'id', Item.Get('id', 0), Item.Get('hidden', False)));
      if (Item.Get('author_id', 0) > 0) and (Item.Get('author_id', 0) <> Me.Id) then
      begin
        PanelId := 'stop-member-' + IntToStr(Item.Get('id', 0));
        Actions := Actions + PostAction(PanelId, Say('Member'));
        Panels := Panels + ActionPanel(PanelId, StopForm(Item));
      end;
    end
    else if (Me.Id > 0) and not Me.Banned and (Item.Get('author_id', 0) <> Me.Id) and not Item.Get('hidden', False) then
    begin
      PanelId := 'report-post-' + IntToStr(Item.Get('id', 0));
      Actions := Actions + PostAction(PanelId, Say('Report'));
      Panels := Panels + ActionPanel(PanelId, '<p>' + W('Tell the moderators what is wrong with this post.') + '</p>' +
        Form('post/report', HiddenField('id', IntToStr(Item.Get('id', 0))) + Input('reason', Say('Reason'), '', 500), Say('Report')));
    end;
    if Actions <> '' then Result := Result + '<div class="forum-actions" data-forum-tools hidden>' + Actions + '</div>';
    Result := Result + Panels + '</div></article>';
  end;
end;

function Breadcrumb(Board: TJSONObject; List: TJSONArray): string;
var
  I: integer;
  Parent: TJSONObject;
  CategoryName: string;
begin
  CategoryName := Board.Get('category', '');
  if CategoryName = '' then CategoryName := Say('General');
  Result := '<nav class="forum-crumbs" aria-label="' + W('Breadcrumb') + '">' + Link('/', Say('Home')) + ' › ' + Link('/forum', Say('Forum'));
  Parent := nil;
  for I := 0 to List.Count - 1 do
    if TJSONObject(List[I]).Get('id', 0) = Board.Get('parent_id', -1) then Parent := TJSONObject(List[I]);
  if Parent <> nil then
  begin
    CategoryName := Parent.Get('category', Say('General'));
    if CategoryName = '' then CategoryName := Say('General');
    Result := Result + ' › ' + Link('/forum#category-' + IntToStr(Parent.Get('category_id', 0)), CategoryName) + ' › ' +
      Link(ForumBoardUrl(Parent.Get('slug', '')), Parent.Get('name', ''));
  end
  else
    Result := Result + ' › ' + Link('/forum#category-' + IntToStr(Board.Get('category_id', 0)), CategoryName);
  Result := Result + ' › ' + Link(ForumBoardUrl(Board.Get('slug', '')), Board.Get('name', '')) + '</nav>';
end;

function InfoHtml(Data: TJSONObject; Boards: TJSONArray): string;
var
  I: integer;
  Posts, Topics: int64;
  Item: TJSONObject;
begin
  Posts := 0;
  Topics := 0;
  for I := 0 to Boards.Count - 1 do
  begin
    Item := TJSONObject(Boards[I]);
    Inc(Posts, Item.Get('post_count', int64(0)));
    Inc(Topics, Item.Get('topic_count', int64(0)));
  end;
  Result := '<section class="forum-info"><h2>' + W('Forum information') + '</h2><p>' + E(SayCount(Posts, '%d post', '%d posts')) + ' · ' +
    E(SayCount(Topics, '%d topic', '%d topics')) + ' · ' + E(SayCount(Data.Get('members', 0), '%d member', '%d members')) + '</p><p>' +
    W('Newest member') + ': ' + MemberLink(Data.Get('newest', '')) + '</p><h3>' + W('Latest posts') + '</h3><ul>';
  for I := 0 to Data.Arrays['posts'].Count - 1 do
  begin
    Item := TJSONObject(Data.Arrays['posts'][I]);
    Result := Result + '<li>' + Link(ForumPostUrl(Item.Get('topic_id', 0), Item.Get('id', 0)), Item.Get('title', '')) + ' · ' +
      MemberLink(Item.Get('author', '')) + ' · ' + DateTag(Item.Get('created', ''), True) + '</li>';
  end;
  Result := Result + '</ul></section>';
end;

{ A page of the forum in its frame; Address is the page's own, for its
  canonical link. }
function ForumPageHtml(R: TRequest; const Me: TMember; const Title, Address, Heading, Content: string): string;
var
  Who, Origin: string;
  Slash: integer;
begin
  Who := 'guest';
  if Me.Id > 0 then
    Who := 'member';
  // CanonicalUrl supplies the site's origin; normalized paths retain paging and search.
  Origin := CanonicalUrl(R);
  Slash := Pos('/', Origin, Pos('://', Origin) + 3);
  if Slash > 0 then
    Origin := Copy(Origin, 1, Slash - 1);
  Result := FillTemplate('forum', ['title', E(Title), 'account', AccountBox(Me), 'who', Who, 'canonical', E(Origin + Address), 'heading',
    Heading, 'content', Content, 'signature_link', SignatureLink, 'reports_link', ReportsLink(Me)]);
end;

{ GET /forum/mail-off/:key and /forum/mail-off/:key/all  the links in a
  mail about a reply, for a reader who is not signed in.  They ask first,
  as mail scanners open links; POST (the button, or a mail program's
  one-click unsubscribe) stops the member following the topic, or with
  /all turns the forum's mail off for them. }
procedure MailOff(R: TRequest; S: TResponse);
var
  Found: TFollowKey;
  All: boolean;
  Title, Text: string;
begin
  CheckConnection;
  if not ForumOn then
  begin
    SendText(S, 404, Say('Nothing here.'));
    Exit;
  end;
  if not TokenTry(R, S) then
    Exit;
  if not FindFollowKey(R.RouteParams['key'], Found) then
  begin
    SendText(S, 404, Say('That link is not known here.'));
    Exit;
  end;
  All := string(ExcludeTrailingPathDelimiter(R.PathInfo)).EndsWith('/all');
  Title := Say('Mail from the forum');
  if R.Method = 'POST' then
  begin
    if All then
    begin
      SaveMemberPref(Found.UserId, ForumMailPref, False);
      Text := Format(Say('Done. %s gets no more mail from the forum. The topics stay followed, with a notice on the site for each reply.'), [Found.Member]);
    end
    else
    begin
      StopFollow(Found.UserId, Found.TopicId);
      Text := Format(Say('Done. %s no longer follows "%s": no more mail or notices about it.'), [Found.Member, Found.Title]);
    end;
    Text := '<p>' + E(Text) + '</p><p>' + W('Sign in to change it back: Follow on the topic''s page, the mail on your profile page.') + '</p>';
  end
  else if All then
    Text := '<p>' + E(Format(Say('Stop all mail from the forum for %s? The topics stay followed.'), [Found.Member])) + '</p><form method="post">' +
      Button(Say('Stop all forum mail')) + '</form>'
  else
    Text := '<p>' + E(Format(Say('Stop following "%s" for %s? No more mail or notices about it.'), [Found.Title, Found.Member])) +
      '</p><form method="post">' + Button(Say('Stop following')) + '</form>';
  S.SetCustomHeader('Cache-Control', 'private, no-store');
  SendPage(S, ForumPageHtml(R, CurrentMember(R), Title, '/forum', '<h1>' + E(Title) + '</h1>', '<div class="forum-mail-off">' + Text + '</div>'));
end;

procedure ShowForum(R: TRequest; S: TResponse);
var
  Me: TMember;
  Data, Topic, Board: TJSONObject;
  List, Reports: TJSONArray;
  Path, Slug, Title, Heading, Content, Address, SearchText, Action: string;
  Id, Page, PageCount: integer;
begin
  Data := nil;
  List := nil;
  try
    try
      CheckConnection;
      if not ForumOn then
        Refuse(404, 'Nothing here.');
      Path := ExcludeTrailingPathDelimiter(HTTPDecode(R.PathInfo));
      // This file announces the lazy admin script only while the forum is on.
      if Path = '/forum/admin.js' then
      begin
        S.ContentType := 'application/javascript; charset=utf-8';
        S.SetCustomHeader('Cache-Control', 'private, no-store');
        S.Content := 'window.Chat.extras.adminScripts.push({src:"/static/forum-admin.js",permissions:["forum-boards"]});';
        // a member's own profile opens their forum signature
        if SignaturesOn then
          S.Content := S.Content + 'window.Chat.parts.push({profileTools:function(who,tools){if(who.name!==window.Chat.me.name)return;' +
            'var b=window.Chat.el("button","",window.t("Forum signature"));b.type="button";' +
            'b.addEventListener("click",function(){location.assign(window.SiteBase.url("/forum/signature"));});tools.appendChild(b);}});';
        S.SendContent;
        Exit;
      end;
      ForumRequestStarts;
      Me := CurrentMember(R);
      if not Can(Me, 'forum-read') then
        Refuse(404, 'Nothing here.');
      Page := ForumPage(R.QueryFields.Values['page']);
      Title := Say('Forum');
      Heading := '';
      Address := '/forum';
      SearchText := '';
      Content := '';
      if Path = '/forum' then
      begin
        Page := 1;
        FirstBoard;
        List := Boards(Me, False);
        Content := ForumBoardTree(List, 0);
        Data := ForumInfo(Me);
        Content := Content + InfoHtml(Data, List);
        if Me.Id > 0 then Content := Content + Form('read', '', Say('Mark all read'));
        if Content = '' then
          Content := '<p>' + W('No boards found.') + '</p>';
      end
      else if (Path = '/forum/recent') or (Path = '/forum/unread') then
      begin
        Title := Say('Recent posts');
        if Path = '/forum/unread' then Title := Say('Unread posts');
        Address := Path;
        Data := Recent(Page, Me, Path = '/forum/unread');
        if Path = '/forum/recent' then Content := ForumRecentHtml(Data.Arrays['topics'])
        else
          Content := ForumTopicsHtml(Data.Arrays['topics']);
        Content := ForumPager(Address, Page, Data.Get('has_more', False)) + Content + ForumPager(Address, Page, Data.Get('has_more', False));
        if Path = '/forum/unread' then Content := Content + Form('read', '', Say('Mark all read'));
      end
      else if Path = '/forum/following' then
      begin
        if Me.Id = 0 then
        begin
          SeeOther(S, '/signin?return=' + HTTPEncode(Path));
          Exit;
        end;
        Title := Say('Topics you follow');
        Address := Path;
        Data := Recent(Page, Me, False, True);
        Content := '<p class="forum-description">' + W('You hear of replies in these topics: a notice on the site, and a mail if you want one. Your profile page has the choices.')
          + '</p>' + ForumPager(Address, Page, Data.Get('has_more', False)) + ForumTopicsHtml(Data.Arrays['topics'], True);
        if Data.Arrays['topics'].Count > 0 then
          Content := Content + '<details class="forum-follow-all"><summary>' + W('Stop following all of them') + '</summary>' +
            FollowForm(HiddenField('all', '1'), Say('Stop following every topic'), Say('Each can be followed again on its page'), False) + '</details>';
      end
      else if Path = '/forum/reports' then
      begin
        if not Moderate(Me) then
          Refuse(404, 'Nothing here.');
        Title := Say('Reports');
        Address := Path;
        Page := 1;
        Reports := OpenReports(Me);
        try
          Content := '<p class="forum-description">' + W('Posts members reported. Open the post, deal with it, then press Done.') + '</p>' + ReportsHtml(Reports);
        finally
          Reports.Free;
        end;
      end
      else if Path = '/forum/signature' then
      begin
        // the member's own signature, in the editor the posts are written in
        if not SignaturesOn then
          Refuse(404, 'Nothing here.');
        if Me.Id = 0 then
        begin
          SeeOther(S, '/signin?return=' + HTTPEncode(Path));
          Exit;
        end;
        if not Writable(Me) then
          Refuse(403, 'You cannot post in the forum.');
        Title := Say('Your signature');
        Address := Path;
        Page := 1;
        Content := '<p class="forum-description">' + E(Format(
          Say('A few lines shown under each of your posts: %d characters and %d lines at most. Markdown works. Leave it empty for no signature.'),
          [ForumMaxSignature, ForumMaxSignatureLines])) + '</p><section data-forum-tools hidden>' + Form('signature', HiddenField('kind', 'signature') +
          '<label>' + W('Signature') + '<textarea class="forum-editor" name="body" rows="5" maxlength="' + IntToStr(ForumMaxSignature) +
          '">' + E(MemberSignature(Me)) + '</textarea></label>', Say('Save')) + '</section>';
      end
      else if Path = '/forum/search' then
      begin
        Title := Say('Search the forum');
        Address := Path;
        SearchText := Trim(R.QueryFields.Values['q']);
        if SearchText = '' then
          Page := 1;
        if SearchText <> '' then
        begin
          Data := Search(SearchText, Page, Me);
          Content := '<p>' + E(Format(Say('Results for %s'), [SearchText])) + '</p>' + ForumTopicsHtml(Data.Arrays['topics']) +
            ForumPager(Address, Page, Data.Get('has_more', False), SearchText);
        end;
      end
      else if Path.StartsWith('/forum/t/') then
      begin
        if not TryStrToInt(Copy(Path, 10, MaxInt), Id) or (Id <= 0) then
          Refuse(404, 'Nothing here.');
        if R.QueryFields.Values['post'] <> '' then
        begin
          Page := PostPage(Id, StrToIntDef(R.QueryFields.Values['post'], 0), Me);
          SeeOther(S, ForumPageUrl(ForumTopicUrl(Id), Page) + '#post-' + IntToStr(StrToIntDef(R.QueryFields.Values['post'], 0)));
          Exit;
        end;
        Data := TopicPage(Id, Page, Me, 0, ForumViewer(R, Me));
        Topic := Data.Objects['topic'];
        PageCount := ForumPageForPosition(Topic.Get('display_count', 0));
        if Moderate(Me) then PageCount := ForumPageForPosition(Topic.Get('post_count', 0));
        // a page past the last one, as after its only post was removed: the last page
        if (Page > PageCount) and (PageCount >= 1) then
        begin
          S.Code := 303;
          S.Location := ForumPageUrl(ForumTopicUrl(Id), PageCount);
          S.SendContent;
          Exit;
        end;
        Title := Topic.Get('title', '');
        Address := ForumTopicUrl(Id);
        List := Boards(Me, False);
        Board := nil;
        for Id := 0 to List.Count - 1 do
          if TJSONObject(List[Id]).Get('id', 0) = Topic.Get('board_id', 0) then
            Board := TJSONObject(List[Id]);
        if Board = nil then
          Refuse(404, 'Nothing here.');
        Content := Breadcrumb(Board, List) + '<div class="forum-titlebar"><h1>' + E(Title) + '</h1>' + Marks(Topic) + '</div>';
        if Moderate(Me) then
          Content := Content + HideDetails(Topic) + TopicTools(Topic, List);
        // the button that writes sits in the page bar, at its end
        Action := '';
        if (Me.Id > 0) and not Me.Banned then
          Action := ForumFollowControl(Topic.Get('id', 0), Page, Topic.Get('following', False));
        if Writable(Me) and not Topic.Get('hidden', False) and (not Topic.Get('locked', False) or Moderate(Me)) then
          Action := Action + '<a class="primary" href="#quick-reply">' + W('Reply') + '</a>';
        Content := Content + '<div class="forum-pagebar">' + ForumPager(Address, Page, Data.Get('has_more', False), '', PageCount) +
          PageJump(True) + Action + '</div>' + ForumPostsHtml(Data, Me) + '<div class="forum-pagebar">' + ForumPager(Address, Page,
          Data.Get('has_more', False), '', PageCount) + PageJump(False) + '</div>';
        if Me.Id = 0 then
          Content := Content + '<p class="forum-guest"><a class="primary" href="/signin?return=' + HTTPEncode(Address) + '">' + W('Sign in to reply') + '</a></p>'
        else if ForumStopped(Me.Id) then
          Content := Content + '<p class="forum-guest forum-hidden">' + W('A moderator has stopped you posting in the forum.') + '</p>';
        if Writable(Me) and not Topic.Get('hidden', False) and (not Topic.Get('locked', False) or Moderate(Me)) then
          Content := Content + '<section id="quick-reply" data-forum-tools hidden><h2>' + W('Quick reply') + '</h2><p class="forum-quote-hint">' +
            W('To quote part of a post, select the words in it and press Quote selection.') + '</p>' + Form('reply',
            HiddenField('topic_id', IntToStr(Topic.Get('id', 0))) + Editor('', ForumUploadAttributes(Me)), Say('Post reply')) + '</section>';
      end
      else if Path.StartsWith('/forum/') then
      begin
        Slug := Copy(Path, 8, MaxInt);
        if (Slug = '') or (ForumSlug(Slug) <> Slug) then
          Refuse(404, 'Nothing here.');
        Id := IntValue('SELECT id FROM forum_boards WHERE slug = :s', [Slug]);
        if Id = 0 then
          Refuse(404, 'Nothing here.');
        Data := BoardPage(Id, Page, Me);
        Board := Data.Objects['board'];
        PageCount := ForumPageForPosition(Board.Get('topic_count', 0));
        if Moderate(Me) then PageCount := ForumPageForPosition(Board.Get('total_topic_count', 0));
        Title := Board.Get('name', '');
        Address := ForumBoardUrl(Board.Get('slug', ''));
        List := Boards(Me, False);
        Content := Breadcrumb(Board, List) + '<div class="forum-titlebar"><div><h1>' + E(Title) + '</h1><p class="forum-description">' +
          E(Board.Get('description', '')) + '</p></div></div>';
        Action := '';
        if Writable(Me) then Action := '<a class="primary" href="#new-topic" data-forum-new>' + W('New topic') + '</a>';
        Content := Content + ForumBoardTree(List, Id) + '<div class="forum-pagebar">' + ForumPager(Address, Page, Data.Get('has_more', False), '', PageCount) +
          PageJump(True) + Action + '</div>' + ForumTopicsHtml(Data.Arrays['topics']) + '<div class="forum-pagebar">' +
          ForumPager(Address, Page, Data.Get('has_more', False), '', PageCount) + PageJump(False) + '</div>';
        if Writable(Me) then
        begin
          Content := Content + '<details id="new-topic" data-forum-tools hidden><summary>' + W('New topic') + '</summary>' +
            Form('topic/new', HiddenField('board_id', IntToStr(Id)) + Input('title', Say('Title'), '', 200) + Editor('', ForumUploadAttributes(Me)), Say('Create topic')) +
            '</details>';
        end;
      end
      else
        Refuse(404, 'Nothing here.');
      if (Path = '/forum') or (Path = '/forum/search') or (Path = '/forum/recent') or (Path = '/forum/unread') or (Path = '/forum/signature') or
        (Path = '/forum/reports') or (Path = '/forum/following') then
        Heading := '<h1>' + E(Title) + '</h1>';
      SendPage(S, ForumPageHtml(R, Me, Title, ForumPageUrl(Address, Page, SearchText), Heading, Content));
    except
      on Ex: EForumRequest do
        SendText(S, Ex.Code, Say(Ex.Message));
    end;
  finally
    List.Free;
    Data.Free;
  end;
end;

{ The forum's card on the home page: the topics last posted in, of the
  boards a visitor may read.  The card is the same for everyone, so it
  shows nothing a visitor could not open. }
function ForumHomeCard: string;
var
  Rows: string;
begin
  Result := '';
  if not ForumOn then
    Exit;
  Rows := '';
  with Query('SELECT t.id, t.title, ' + IsoTime('t.last_post_at') + ' FROM forum_topics t WHERE ' + ForumTopicWhere(ReadableBoards(Default(TMember)), False) +
      ' ORDER BY t.last_post_at DESC, t.id DESC LIMIT 5', []) do
  try
    while not EOF do
    begin
      Rows := Rows + HomeRow(ForumTopicUrl(Fields[0].AsInteger), Fields[1].AsString, DateTag(Fields[2].AsString, True));
      Next;
    end;
  finally
    Free;
  end;
  Result := HomeCard(Say('Forum'), '/forum', Rows, Say('No topics yet.'));
end;

procedure RegisterForumPages;
begin
  RegisterHomePart('forum_home', @ForumHomeCard);
  HTTPRouter.RegisterRoute('/forum', rmGet, @ShowForum);
  // before the pages below, which would take a GET of it for a board's name
  HTTPRouter.RegisterRoute('/forum/mail-off/:key', rmAll, @MailOff);
  HTTPRouter.RegisterRoute('/forum/mail-off/:key/all', rmAll, @MailOff);
  HTTPRouter.RegisterRoute('/forum/*path', rmGet, @ShowForum);
  RegisterVisitorPart('forum', '/forum');
  RegisterSearchPlace('/forum/search', 'forum');
  RegisterSearchPlace('/api/forum/search', 'forum');
  RegisterSearchRoute('/forum/search');
end;

end.
