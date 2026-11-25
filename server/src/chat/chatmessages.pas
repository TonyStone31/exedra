unit ChatMessages;

{ Messages, threads, reactions, pins, search and /api/sync. Revisions let
  clients fetch changes through message_rooms indexes; posts do not write
  per follower. Replies and answers notify their authors as mentions.
  RegisterCommand and RegisterSyncHook extend commands and sync answers. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, httpdefs, SiteUsers, ChatRooms;

type
  TCommandResult = record
    Post: string;   // posted as the member's message when not empty
    Info: string;   // shown to the member only
    Go: string;     // a page to open, such as /p/lobby
  end;
  TCommandFunc = function(const Me: TMember; const Room: TRoom; Parent: integer; const Args: string): TCommandResult;
  TSyncHook = procedure(ARequest: TRequest; const Me: TMember; Answer: TJSONObject);

  { after a message is posted or edited, with what it says; and after a
    page of messages is loaded, with the list and its ids as a list of
    numbers for an IN - what units on top add to messages (link previews) }
  TMessageHook = procedure(MessageId: integer; const Body: string);
  TLoadHook = procedure(List: TJSONArray; const Ids: string);

{ Usage is the command's line in /help: how it is typed, ' - ', and a
  sentence.  Anywhere marks one that needs no channel, so it also works in
  a private conversation; its function is then given an empty Room. }
procedure RegisterCommand(const Name, Usage: string; Func: TCommandFunc; Anywhere: boolean = False);
procedure RegisterSyncHook(Hook: TSyncHook);
procedure RegisterMessageHook(Hook: TMessageHook);
procedure RegisterLoadHook(Hook: TLoadHook);
{ A message changed: a new revision, and the pages showing it rung. }
procedure Touch(MessageId: integer; Fresh: boolean = False);
{ Re is the message this one answers, 0 for none. }
function AddMessage(const Room: TRoom; Parent, UserId: integer; const Author, Body, Files: string; Re: integer = 0): integer;
{ Messages as JSON.  Where follows the joins and the WHERE of the query. }
function LoadMessages(const Where: string; const Values: array of variant; const Me: TMember): TJSONArray;
{ The week's messages with the most reactions. }
function BestOfWeek(const Me: TMember): TJSONArray;
function CommandResult(const Post, Info: string; const Go: string = ''): TCommandResult;
function Say(const Me: TMember; Room: TRoom; Parent: integer; Body: string; const Files: string; out Info, Go: string; out Status: integer; Re: integer = 0): integer;

implementation

uses
  StrUtils, Variants, httproute, SiteDb, SiteSql, SiteMarkup, SiteFiles, SiteRoles, SiteBell, SiteSearch, SiteReactions, SiteWords, ChatPush;

const
  MaxBody = 8000;
  // the page does this one itself: a private message is encrypted there
  MsgUsage = '/msg name text - sends someone a private message';

type
  TCommand = record
    Name, Usage: string;
    Func: TCommandFunc;
    Anywhere: boolean;
  end;

var
  Commands: array of TCommand;
  SyncHooks: array of TSyncHook;

procedure RegisterCommand(const Name, Usage: string; Func: TCommandFunc; Anywhere: boolean);
begin
  SetLength(Commands, Length(Commands) + 1);
  Commands[High(Commands)].Name := Name;
  Commands[High(Commands)].Usage := Usage;
  Commands[High(Commands)].Func := Func;
  Commands[High(Commands)].Anywhere := Anywhere;
end;

procedure RegisterSyncHook(Hook: TSyncHook);
begin
  SetLength(SyncHooks, Length(SyncHooks) + 1);
  SyncHooks[High(SyncHooks)] := Hook;
end;

var
  MessageHooks: array of TMessageHook;
  LoadHooks: array of TLoadHook;

procedure RegisterMessageHook(Hook: TMessageHook);
begin
  SetLength(MessageHooks, Length(MessageHooks) + 1);
  MessageHooks[High(MessageHooks)] := Hook;
end;

procedure RegisterLoadHook(Hook: TLoadHook);
begin
  SetLength(LoadHooks, Length(LoadHooks) + 1);
  LoadHooks[High(LoadHooks)] := Hook;
end;

procedure RunMessageHooks(MessageId: integer; const Body: string);
var
  H: TMessageHook;
begin
  for H in MessageHooks do
    H(MessageId, Body);
end;

function CommandResult(const Post, Info: string; const Go: string): TCommandResult;
begin
  Result.Post := Post;
  Result.Info := Info;
  Result.Go := Go;
end;

{ Reading }

function MessageColumns: string;
begin
  Result := 'SELECT m.id, r.slug, m.parent_id, m.user_id, COALESCE(u.name, m.author), u.avatar, u.roles,' + ' m.body, m.html, ' +
    IsoTime('m.created') + ', m.edited, m.deleted, m.pinned, m.reply_count, ' + IsoTime('m.last_reply') + ', m.rev, m.re_id' +
    ' FROM messages m JOIN rooms r ON r.id = m.room_id LEFT JOIN users u ON u.id = m.user_id ';
end;

function FindById(List: TJSONArray; Id: integer): TJSONObject;
var
  I: integer;
begin
  Result := nil;
  for I := 0 to List.Count - 1 do
    if List.Objects[I].Integers['id'] = Id then
      Exit(List.Objects[I]);
end;

{ The message each of these answers, as re: its id, who wrote it (from) and
  its first words as they are now (text; a file's name when it has no
  words), or gone when it was deleted since. }
procedure AttachAnswered(List: TJSONArray; const Ids: string);
var
  Re: TJSONObject;
  Words: string;
begin
  // Ids is a list of numbers read from the database.
  with Query('SELECT m.id, a.id, COALESCE(u.name, a.author), a.body, a.deleted,' + ' (SELECT MIN(f.name) FROM files f WHERE f.purpose = ''message'' AND f.message_id = a.id)'
      + ' FROM messages m JOIN messages a ON a.id = m.re_id LEFT JOIN users u ON u.id = a.user_id' + ' WHERE m.deleted = 0 AND m.id IN (' + Ids + ')', []) do
  try
    while not EOF do
    begin
      Re := TJSONObject.Create(['id', Fields[1].AsInteger, 'gone', Fields[4].AsInteger = 1]);
      if Fields[4].AsInteger = 0 then
      begin
        Words := PlainLine(Fields[3].AsString, 140);
        if Words = '' then
          Words := Fields[5].AsString;
        Re.Add('from', Fields[2].AsString);
        Re.Add('text', Words);
      end;
      FindById(List, Fields[0].AsInteger).Add('re', Re);
      Next;
    end;
  finally
    Free;
  end;
end;

function LoadMessages(const Where: string; const Values: array of variant; const Me: TMember): TJSONArray;
var
  Item: TJSONObject;
  Ids, Ignored: string;
  Deleted, Answers: boolean;
  Files: TJSONObject;
  I: integer;
begin
  Result := TJSONArray.Create;
  Ids := '';
  Answers := False;
  Ignored := ',' + IgnoredIds(Me.Id) + ',';
  with Query(MessageColumns + Where, Values) do
  try
    while not EOF do
    begin
      Deleted := Fields[11].AsInteger = 1;
      Item := TJSONObject.Create(['id', Fields[0].AsInteger, 'room', Fields[1].AsString, 'parent', Fields[2].AsInteger, 'uid',
        Fields[3].AsInteger, 'name', Fields[4].AsString, 'avatar', AvatarUrl(Fields[5].AsString), 'badge', BadgeIn(Fields[6].AsString, 'chat'),
        'at', Fields[9].AsString, 'edited', Fields[10].AsInteger = 1, 'deleted', Deleted, 'pinned', Fields[12].AsInteger = 1, 'replies',
        Fields[13].AsInteger, 'last_reply', Fields[14].AsString, 'rev', Fields[15].AsLargeInt, 'mentions_me', False, 'ignored', Pos(',' + Fields[3].AsString + ',', Ignored) > 0]);
      if Deleted then
      begin
        Item.Add('body', '');
        Item.Add('html', '');
      end
      else
      begin
        Item.Add('body', Fields[7].AsString);
        Item.Add('html', Fields[8].AsString);
      end;
      Item.Add('reactions', TJSONArray.Create);
      Item.Add('files', TJSONArray.Create);
      Result.Add(Item);
      if Ids <> '' then
        Ids := Ids + ',';
      Ids := Ids + Fields[0].AsString;
      Answers := Answers or not Fields[16].IsNull;
      Next;
    end;
  finally
    Free;
  end;
  if Ids = '' then
    Exit;
  if Answers then
    AttachAnswered(Result, Ids);

  // Ids is a list of numbers read from the database above.
  AttachReactions(Result, 'reactions', 'message_id', Ids, Me.Id);

  if Me.Id > 0 then
    with Query('SELECT message_id FROM mentions WHERE user_id = :u AND message_id IN (' + Ids + ')', [Me.Id]) do
    try
      while not EOF do
      begin
        FindById(Result, Fields[0].AsInteger).Booleans['mentions_me'] := True;
        Next;
      end;
    finally
      Free;
    end;

  Files := FilesFor(Ids, 'message');
  try
    for I := 0 to Files.Count - 1 do
    begin
      Item := FindById(Result, StrToInt(Files.Names[I]));
      Item.Delete('files');
      Item.Add('files', Files.Items[I].Clone);
    end;
  finally
    Files.Free;
  end;
  for I := 0 to High(LoadHooks) do
    LoadHooks[I](Result, Ids);
end;

{ Unread messages in one room, counted to 100 at most: the sidebar shows
  99+ beyond that, and counting further would read the whole backlog. }
function UnreadIn(RoomId, LastRead, UserId: integer): integer;
begin
  Result := IntValue('SELECT COUNT(*) FROM (SELECT 1 FROM message_rooms mr' + ' JOIN messages m ON m.id = mr.message_id WHERE mr.room_id = :r AND mr.message_id > :l' +
    ' AND m.deleted = 0 AND (m.user_id IS NULL OR m.user_id <> :u) LIMIT 100) x', [RoomId, LastRead, UserId]);
end;

{ The rooms a member follows, with what is unread in each. }
function BestOfWeek(const Me: TMember): TJSONArray;
begin
  // Starts from the week's messages (index on created), not every reaction.
  Result := LoadMessages('JOIN (SELECT w.id, (SELECT COUNT(*) FROM reactions x WHERE x.message_id = w.id) AS n' +
    ' FROM messages w JOIN rooms wr ON wr.id = w.room_id WHERE w.created > ' + SqlAgo('7', suDay) +
    ' AND w.deleted = 0 AND wr.private = 0 AND wr.kind <> ''shelf'' ORDER BY n DESC, w.id DESC LIMIT 3) top' +
    ' ON top.id = m.id WHERE top.n > 0 ORDER BY top.n DESC, m.id DESC', [], Me);
end;

function RoomsList(const Me: TMember): TJSONArray;
var
  BannedSees: string;
  Item: TJSONObject;
  Mentions: TStringList;
  I: integer;
begin
  Result := TJSONArray.Create;
  if Me.Id = 0 then
  begin
    with Query('SELECT slug, kind, title, topic, avatar FROM rooms WHERE kind = ''channel''' + ' AND archived = 0 AND private = 0 ORDER BY id', []) do
    try
      while not EOF do
      begin
        Result.Add(TJSONObject.Create(['slug', Fields[0].AsString, 'kind', Fields[1].AsString, 'title', Fields[2].AsString, 'topic',
          Fields[3].AsString, 'private', False, 'unread', 0, 'mentions', 0, 'avatar', AvatarUrl(Fields[4].AsString)]));
        Next;
      end;
    finally
      Free;
    end;
    Exit;
  end;

  // a banned member keeps the public channels in their list, not the private ones
  BannedSees := '';
  if Me.Banned then
    BannedSees := ' AND r.private = 0';
  // Mentions not yet read, by room.  Only mentions newer than the oldest
  // place the member has read to are looked at.
  Mentions := TStringList.Create;
  try
    with Query('SELECT m.room_id, COUNT(*) FROM mentions n JOIN messages m ON m.id = n.message_id' + ' JOIN follows f ON f.room_id = m.room_id AND f.user_id = n.user_id' +
        ' WHERE n.user_id = :u AND n.message_id > (SELECT COALESCE(MIN(last_read_id), 0) FROM follows' +
        ' WHERE user_id = :u2) AND n.message_id > f.last_read_id AND m.deleted = 0 GROUP BY m.room_id', [Me.Id, Me.Id]) do
    try
      while not EOF do
      begin
        Mentions.Values[Fields[0].AsString] := Fields[1].AsString;
        Next;
      end;
    finally
      Free;
    end;

    with Query('SELECT r.id, r.slug, r.kind, r.title, r.topic, r.private, f.last_read_id, r.last_message_id, r.avatar, r.owner_id, f.notify' +
        ' FROM follows f JOIN rooms r ON r.id = f.room_id WHERE f.user_id = :u AND r.archived = 0' + BannedSees +
        ' ORDER BY r.kind <> ''channel'', r.kind = ''shelf'', ' + SqlIf('r.kind = ''channel''', 'r.id', '0') + ',' + ' r.last_talk DESC LIMIT 300', [Me.Id]) do
    try
      while not EOF do
      begin
        // owner: this member opened it, so the sidebar can offer to delete a private one
        Item := TJSONObject.Create(['slug', Fields[1].AsString, 'kind', Fields[2].AsString, 'title', Fields[3].AsString, 'topic',
          Fields[4].AsString, 'private', Fields[5].AsInteger = 1, 'mentions', StrToIntDef(Mentions.Values[Fields[0].AsString], 0), 'avatar',
          AvatarUrl(Fields[8].AsString), 'owner', Fields[9].AsInteger = Me.Id, 'notify', NotifyWord(Fields[10].AsInteger)]);
        // Rooms nothing new was said in cost nothing more.
        if Fields[7].AsInteger > Fields[6].AsInteger then
          Item.Add('unread', -Fields[0].AsInteger)   // counted below
        else
          Item.Add('unread', 0);
        Result.Add(Item);
        Next;
      end;
    finally
      Free;
    end;
  finally
    Mentions.Free;
  end;
  for I := 0 to Result.Count - 1 do
  begin
    Item := Result.Objects[I];
    if Item.Integers['unread'] < 0 then
      Item.Integers['unread'] := UnreadIn(-Item.Integers['unread'], IntValue('SELECT last_read_id FROM follows WHERE user_id = :u AND room_id = :r',
        [Me.Id, -Item.Integers['unread']]), Me.Id);
  end;
end;

{ GET /api/rooms }
procedure ShowRooms(ARequest: TRequest; AResponse: TResponse);
begin
  CheckConnection;
  SendJSON(AResponse, RoomsList(CurrentMember(ARequest)));
end;

function ReadableRoom(ARequest: TRequest; AResponse: TResponse; const Slug: string; out Me: TMember; out Room: TRoom): boolean;
begin
  Me := CurrentMember(ARequest);
  Room := FindRoom(Slug);
  Result := CanRead(Me, Room);
  if not Result then
    SendText(AResponse, 404, 'No channel by that name.');
end;

{ GET /api/messages?room=x&before=id  the 50 messages before id }
procedure ShowMessages(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Room: TRoom;
  Before: integer;
begin
  CheckConnection;
  if not ReadableRoom(ARequest, AResponse, ARequest.QueryFields.Values['room'], Me, Room) then
    Exit;
  Before := StrToIntDef(ARequest.QueryFields.Values['before'], MaxInt);
  SendJSON(AResponse, TJSONObject.Create(['messages', LoadMessages('JOIN message_rooms mr ON mr.message_id = m.id WHERE mr.room_id = :r' +
    ' AND mr.message_id < :b ORDER BY mr.message_id DESC LIMIT 50', [Room.Id, Before], Me), 'last_read',
    IntValue('SELECT last_read_id FROM follows WHERE user_id = :u AND room_id = :r', [Me.Id, Room.Id]), 'rev', IntValue('SELECT ' + RevNow, [])]));
end;

{ The room a thread (or any message) was said in. }
function RoomOfMessage(Id: integer): TRoom;
begin
  Result := RoomById(IntValue('SELECT room_id FROM messages WHERE id = :m', [Id]));
end;

{ Who may fetch a file of a message: whoever may read the channel it was
  said in.  One not yet in a message is its sender's. }
function MayFetchFile(ARequest: TRequest; MessageId, OwnerId: integer): boolean;
var
  Me: TMember;
begin
  Me := CurrentMember(ARequest);
  if MessageId = 0 then
    Result := (Me.Id > 0) and (Me.Id = OwnerId)
  else
    Result := CanRead(Me, RoomOfMessage(MessageId));
end;

{ GET /api/thread?id=  a message and its replies }
procedure ShowThread(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Id: integer;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  Id := StrToIntDef(ARequest.QueryFields.Values['id'], 0);
  if not CanRead(Me, RoomOfMessage(Id)) then
    SendText(AResponse, 404, 'That message is gone.')
  else
    SendJSON(AResponse, LoadMessages('WHERE m.id = :a OR m.parent_id = :b ORDER BY m.id LIMIT 1000', [Id, Id], Me));
end;

{ GET /api/pins?room=  }
procedure ShowPins(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Room: TRoom;
begin
  CheckConnection;
  if ReadableRoom(ARequest, AResponse, ARequest.QueryFields.Values['room'], Me, Room) then
    SendJSON(AResponse, LoadMessages('WHERE m.room_id = :r AND m.pinned = 1 AND m.deleted = 0' + ' ORDER BY m.id LIMIT 100', [Room.Id], Me));
end;

{ The words of a search in the full-text index's boolean form: each word
  must be there, and may be the start of a longer one.  Characters the
  index gives a meaning to are left out. }
function SearchWords(const Words: string): string;
var
  W, Clean: string;
  C: char;
begin
  Result := '';
  for W in Words.Split([' ', #9, #10, #13], TStringSplitOptions.ExcludeEmpty) do
  begin
    Clean := '';
    for C in W do
      if (C in ['A'..'Z', 'a'..'z', '0'..'9', '_']) or (Ord(C) >= 128) then
        Clean := Clean + C;
    if Length(Clean) >= 3 then
      Result := Result + ' +' + Clean + '*';
  end;
  Result := Trim(Result);
end;

{ The messages that hold the words, newest first, among those Me may read:
  everywhere, or in one room when Slug names it.  Words of three letters or
  more use the full-text index; shorter ones are only looked for inside
  one room. }
function FoundMessages(const Me: TMember; const Text, Slug: string; Offset, Limit: integer): TJSONArray;
var
  Room: TRoom;
  Words, Indexed, Where, Paging: string;
begin
  Words := Trim(Text);
  Indexed := SearchWords(Words);
  Room := FindRoom(Slug);
  Paging := ' ORDER BY m.id DESC LIMIT ' + IntToStr(Limit) + ' OFFSET ' + IntToStr(Offset);
  if (Length(Words) < 2) or ((Slug <> '') and not CanRead(Me, Room)) then
    Result := TJSONArray.Create
  else if Slug <> '' then
  begin
    if Indexed <> '' then
      Where := 'WHERE m.room_id = :r AND m.deleted = 0 AND ' + SqlMatch('m.body', ':q', True)
    else
    begin
      Where := 'WHERE m.room_id = :r AND m.deleted = 0 AND m.body LIKE :q';
      Indexed := '%' + Words + '%';
    end;
    Result := LoadMessages(Where + Paging, [Room.Id, Indexed], Me);
  end
  // everywhere: only for who may read channels at all, and a banned member
  // finds nothing in the private ones they were in
  else if (Indexed = '') or not Can(Me, 'view-room') then
    Result := TJSONArray.Create
  else if Me.Banned then
    Result := LoadMessages('WHERE ' + SqlMatch('m.body', ':q', True) + ' AND m.deleted = 0 AND r.private = 0' + Paging, [Indexed], Me)
  else
    Result := LoadMessages('WHERE ' + SqlMatch('m.body', ':q', True) + ' AND m.deleted = 0' +
      ' AND (r.private = 0 OR r.id IN (SELECT room_id FROM follows WHERE user_id = :u))' + Paging, [Indexed, Me.Id], Me);
end;

{ GET /api/search?q=&room=  words anywhere the member may read, or in one room. }
procedure Search(ARequest: TRequest; AResponse: TResponse);
begin
  CheckConnection;
  SendJSON(AResponse, FoundMessages(CurrentMember(ARequest), ARequest.QueryFields.Values['q'], ARequest.QueryFields.Values['room'], 0, 50));
end;

{ The chat in the site's search: messages in the channels Me may read, each
  under its channel's name.  Private conversations are not searched here.
  A message of someone Me ignores is left out. }
function FindInChat(ARequest: TRequest; const Me: TMember; const Words: string; Offset, Limit: integer; out More: boolean): TSearchHits;
var
  Found: TJSONArray;
  Item: TJSONObject;
  I: integer;
begin
  Result := nil;
  Found := FoundMessages(Me, Words, '', Offset, Limit + 1);
  try
    More := Found.Count > Limit;
    for I := 0 to Found.Count - 1 do
    begin
      Item := Found.Objects[I];
      if (I < Limit) and not Item.Booleans['ignored'] then
        AddSearchHit(Result, '#' + Item.Strings['room'], '/m/' + IntToStr(Item.Integers['id']), PlainLine(Item.Strings['body'], 220),
          Item.Strings['at'], Item.Strings['name'], 'message');
    end;
  finally
    Found.Free;
  end;
end;

{ Room and thread changes since rev, in revision order; more continues from
  the last rev. read marks a message read, here=1 adds presence and typing,
  rooms=1 adds unread counts, and live subscribes that connection to the
  room. See docs/API.md. }
procedure Sync(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Room: TRoom;
  Since: int64;
  Thread, ReadUpTo: integer;
  Answer: TJSONObject;
  Changed: TJSONArray;
  Hook: TSyncHook;
  Here: boolean;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  with ARequest.QueryFields do
  begin
    Room := FindRoom(Values['room']);
    Since := StrToInt64Def(Values['since'], 0);
    Thread := StrToIntDef(Values['thread'], 0);
    ReadUpTo := StrToIntDef(Values['read'], 0);
  end;
  if not CanRead(Me, Room) then
    Room := FindRoom('');
  if (Thread > 0) and not CanRead(Me, RoomOfMessage(Thread)) then
    Thread := 0;
  Watch(ARequest.QueryFields.Values['live'], Me.Id, Room.Id, Thread);
  Here := ARequest.QueryFields.Values['here'] = '1';
  Answer := TJSONObject.Create(['rev', IntValue('SELECT ' + RevNow, [])]);
  if Room.Id > 0 then
  begin
    if Me.Id > 0 then
    begin
      if Here then
        TouchPresence(Me.Id, Room.Id);
      if ReadUpTo > 0 then
        Exec('UPDATE follows SET last_read_id = :m WHERE user_id = :u AND room_id = :r AND last_read_id < :m2',
          [ReadUpTo, Me.Id, Room.Id, ReadUpTo]);
    end;
    Changed := LoadMessages('JOIN message_rooms mr ON mr.message_id = m.id' + ' WHERE mr.room_id = :r AND mr.rev > :s ORDER BY mr.rev LIMIT 200', [Room.Id, Since], Me);
    Answer.Add('messages', Changed);
    Answer.Add('more', Changed.Count = 200);
    if Here then
    begin
      Answer.Add('typing', TypingNames(Room.Id, Me.Id));
      Answer.Add('here', HereNow(Room.Id));
    end;
  end;
  if Thread > 0 then
    Answer.Add('thread', LoadMessages('WHERE (m.id = :a OR m.parent_id = :b) AND m.rev > :s' + ' ORDER BY m.id LIMIT 1000', [Thread, Thread, Since], Me));
  if (Me.Id > 0) and (ARequest.QueryFields.Values['rooms'] = '1') then
    Answer.Add('rooms', RoomsList(Me));
  for Hook in SyncHooks do
    Hook(ARequest, Me, Answer);
  SendJSON(AResponse, Answer);
end;

{ Writing }

{ A message as anyone may see it, with the names it mentions, to ride
  along with a ring; each page works out mentions_me and ignored itself. }
function RingCopy(MessageId: integer): TJSONObject;
var
  Nobody: TMember;
  List: TJSONArray;
  Names: TJSONArray;
begin
  Nobody.Id := 0;
  Nobody.Name := '';
  Nobody.Roles := '';
  Nobody.Banned := False;
  Nobody.Verified := False;
  List := LoadMessages('WHERE m.id = :m', [MessageId], Nobody);
  try
    Result := TJSONObject(List.Extract(0));
  finally
    List.Free;
  end;
  Names := TJSONArray.Create;
  with Query('SELECT u.name FROM mentions n JOIN users u ON u.id = n.user_id WHERE n.message_id = :m', [MessageId]) do
  try
    while not EOF do
    begin
      Names.Add(Fields[0].AsString);
      Next;
    end;
  finally
    Free;
  end;
  Result.Add('names', Names);
end;

{ A message changed: give it a new revision, in its rooms too, and ring
  the pages showing them.  Fresh says it is new, so it rides along. }
procedure Touch(MessageId: integer; Fresh: boolean = False);
var
  Root: integer;
  Shown: TJSONObject;
begin
  Exec('UPDATE messages SET rev = ' + RevNow + ' WHERE id = :m', [MessageId]);
  Exec('UPDATE message_rooms mr JOIN messages m ON m.id = mr.message_id SET mr.rev = m.rev' + ' WHERE mr.message_id = :m', [MessageId]);
  Root := IntValue('SELECT COALESCE(parent_id, id) FROM messages WHERE id = :m', [MessageId]);
  Shown := nil;
  if Fresh then
    Shown := RingCopy(MessageId);
  try
    with Query('SELECT room_id FROM message_rooms WHERE message_id = :m', [Root]) do
    try
      while not EOF do
      begin
        RingRoom(RoomById(Fields[0].AsInteger), Shown);
        Next;
      end;
    finally
      Free;
    end;
  finally
    Shown.Free;
  end;
end;

procedure NoteNames(MessageId, AuthorId: integer; Members, Rooms: TStrings; TagRooms: boolean);
// TagRooms is false for replies and for anything said in a private room,
// which must never show up in a public one.
var
  S: string;
  Target: TRoom;
  Id: integer;
begin
  for S in Members do
  begin
    Id := MemberId(S);
    if (Id > 0) and (Id <> AuthorId) and not Ignores(Id, AuthorId) and not MemberClosed(Id) then
    begin
      Exec(SqlInsertIgnore('mentions', 'message_id, user_id', ':m, :u'), [MessageId, Id]);
      RingUser(Id, BellNote(['t', 'me']));
      // a channel the member silenced still counts the mention; it does not
      // push or mail about it
      if not Silenced(Id, RoomOfMessage(MessageId).Id) then
        NotifyMember(Id);
    end;
  end;
  // Naming a public room shows the message there too, while that is on
  // (off since 31 Oct 2026: a message listing the channels went to all of
  // them, and how to cross post on purpose is still to be decided).
  if TagRooms and CrossPosting then
    for S in Rooms do
    begin
      Target := FindRoom(S);
      if (Target.Id > 0) and not Target.Private and (CanStart(MemberById(AuthorId), Target) = '') then
        Exec(SqlInsertIgnoreSelect('message_rooms', 'room_id, message_id, rev', 'SELECT :r, id, rev FROM messages WHERE id = :m'), [Target.Id, MessageId]);
    end;
end;

{ A row's number for a column that is NULL when there is none. }
function IdOrNull(Id: integer): variant;
begin
  if Id > 0 then
    Result := Id
  else
    Result := Null;
end;

{ Adds to Members, the names a message mentions, whoever it tells without
  naming them: the author of the message it answers (Re) and, for a reply,
  the member who started its thread (Parent).  Only a member who may still
  read the room, and never a bot. }
procedure AddAnswered(Members: TStrings; const Room: TRoom; Parent, Re: integer);
var
  Told: TMember;
begin
  with Query('SELECT DISTINCT user_id FROM messages WHERE id IN (:e, :p) AND user_id IS NOT NULL', [Re, Parent]) do
  try
    while not EOF do
    begin
      Told := MemberById(Fields[0].AsInteger);
      if not Told.Banned and not HasRole(Told.Roles, 'bot') and CanRead(Told, Room) and (Members.IndexOf(Told.Name) < 0) then
        Members.Add(Told.Name);
      Next;
    end;
  finally
    Free;
  end;
end;

function AddMessage(const Room: TRoom; Parent, UserId: integer; const Author, Body, Files: string; Re: integer): integer;
var
  Members, Rooms: TStringList;
  Html: string;
begin
  Members := TStringList.Create;
  Rooms := TStringList.Create;
  try
    Html := RenderText(Body, @MemberExists, @RoomExists, Members, Rooms);
    Exec('INSERT INTO messages (room_id, parent_id, user_id, author, body, html, re_id, rev) VALUES' + ' (:r, :p, :u, :a, :b, :h, :e, ' +
      RevNow + ')', [Room.Id, IdOrNull(Parent), IdOrNull(UserId), Author, Body, Html, IdOrNull(Re)]);
    Result := LastId;
    if Parent = 0 then
      Exec('INSERT INTO message_rooms (room_id, message_id, rev) SELECT :r, id, rev FROM messages' + ' WHERE id = :m', [Room.Id, Result]);
    AddAnswered(Members, Room, Parent, Re);
    // Naming a room in a reply does not pull the reply out of its thread.
    NoteNames(Result, UserId, Members, Rooms, (Parent = 0) and not Room.Private);
  finally
    Rooms.Free;
    Members.Free;
  end;
  if Files <> '' then
    AttachFiles(Result, Room.Id, UserId, Files, 'message');
  RunMessageHooks(Result, Body);
  if UserId > 0 then
    Exec('UPDATE users SET posts = posts + 1 WHERE id = :u', [UserId]);
  Exec('UPDATE rooms SET message_count = message_count + 1 WHERE id = :r', [Room.Id]);
  if Parent > 0 then
  begin
    // The parent changes (its count), so its revision moves; the reply
    // itself rides along with the ring.
    Exec('UPDATE messages SET reply_count = reply_count + 1, last_reply = NOW(), rev = ' + RevNow + ' WHERE id = :p', [Parent]);
    Exec('UPDATE message_rooms mr JOIN messages m ON m.id = mr.message_id SET mr.rev = m.rev' + ' WHERE mr.message_id = :p', [Parent]);
    Touch(Result, True);
  end
  else
  begin
    Exec('UPDATE rooms r JOIN message_rooms mr ON mr.room_id = r.id SET r.last_talk = NOW(),' + ' r.last_message_id = :m WHERE mr.message_id = :m2', [Result, Result]);
    if UserId > 0 then
      Exec('UPDATE follows SET last_read_id = :m WHERE user_id = :u AND room_id = :r', [Result, UserId, Room.Id]);
    Touch(Result, True);
  end;
end;

function FindCommand(const Name: string): integer;
var
  I: integer;
begin
  Result := -1;
  for I := 0 to High(Commands) do
    if SameText(Commands[I].Name, Name) then
      Exit(I);
end;

{ Tells the poster, the way IRC does, that someone they named is away. }
function AwayNotes(MessageId: integer): string;
begin
  Result := '';
  with Query('SELECT u.name, u.away FROM mentions n JOIN users u ON u.id = n.user_id' + ' WHERE n.message_id = :m AND u.away <> ''''', [MessageId]) do
  try
    while not EOF do
    begin
      Result := Result + Format(SiteWords.Say('%s is away: %s'), [Fields[0].AsString, Fields[1].AsString]) + #10;
      Next;
    end;
  finally
    Free;
  end;
  Result := Trim(Result);
end;

{ Whether a message said in Room, or in the thread Parent, may answer the
  message Re: one still there, of that channel's own or of that thread. }
function Answerable(Re: integer; const Room: TRoom; Parent: integer): boolean;
begin
  if Parent > 0 then
    Result := IntValue('SELECT COUNT(*) FROM messages WHERE id = :m AND deleted = 0 AND (id = :p OR parent_id = :q)', [Re, Parent, Parent]) > 0
  else
    Result := IntValue('SELECT COUNT(*) FROM messages WHERE id = :m AND deleted = 0 AND room_id = :r AND parent_id IS NULL', [Re, Room.Id]) > 0;
end;

{ Says Body as Me in Room, or in the thread Parent, the way the page posts:
  the rate limit, the room's rules and /commands.  The new message's id, or
  0 with Status the HTTP code and Info why.  Info also carries what to tell
  Me after a post (a command's answer, who is away), Go a page to open.
  Re is the message it answers, 0 for none. }
function Say(const Me: TMember; Room: TRoom; Parent: integer; Body: string; const Files: string; out Info, Go: string; out Status: integer; Re: integer): integer;
var
  Command: integer;
  Why, Name: string;
  Said: TCommandResult;
begin
  Result := 0;
  Info := '';
  Go := '';
  Status := 200;
  Body := Trim(Body);
  if not Me.Verified then
  begin
    Status := 403;
    Info := SiteWords.Say('Confirm your email first: the link is in the mail we sent you.');
    Exit;
  end;
  if IntValue('SELECT COUNT(*) FROM messages WHERE user_id = :u AND created > ' + SqlAgo('10', suSecond), [Me.Id]) >= 10 then
  begin
    Status := 429;
    Info := SiteWords.Say('Slow down a little.');
    Exit;
  end;
  // A reply goes where its thread started, and anyone who may talk there
  // may reply, even in a read-only room.
  if Parent > 0 then
  begin
    Room := RoomById(IntValue('SELECT room_id FROM messages WHERE id = :p AND parent_id IS NULL', [Parent]));
    Why := '';
    if not CanRead(Me, Room) then
      Why := SiteWords.Say('That thread is gone.')
    else if Room.Archived then
      Why := SiteWords.Say('This channel is archived.')
    else if not RoomCan(Me, 'post', Room) then
      Why := SiteWords.Say('Posting is not open to you here.');
  end
  else
    Why := CanStart(Me, Room);
  // Commands work anywhere the member can read, even where they cannot post,
  // and with no room at all: a private conversation's page sends them so.
  // A first word that is no command (/usr/local/bin, /shrug) is the start
  // of an ordinary message.
  Command := -1;
  Name := Copy(Body, 2, Pos(' ', Body + ' ') - 2);
  if Body.StartsWith('/') and ((Room.Id = 0) or CanRead(Me, Room)) then
    Command := FindCommand(Name);
  if Command >= 0 then
  begin
    if (Room.Id = 0) and not Commands[Command].Anywhere then
    begin
      Info := Format(SiteWords.Say('/%s is for channels. It does nothing in a private conversation.'), [Commands[Command].Name]);
      Exit;
    end;
    Said := Commands[Command].Func(Me, Room, Parent, Trim(Copy(Body, Length(Name) + 2, MaxInt)));
    Body := Said.Post;
    Info := Said.Info;
    Go := Said.Go;
    if Body = '' then
      Exit;
  end;
  if Why <> '' then
    Status := 403
  else if (Body = '') and (Files = '') then
  begin
    Status := 400;
    Why := SiteWords.Say('Nothing to send.');
  end
  else if Length(Body) > MaxBody then
  begin
    Status := 400;
    Why := Format(SiteWords.Say('A message is %d characters at most. Long code fits better in a file.'), [MaxBody]);
  end
  else if (Re > 0) and not Answerable(Re, Room, Parent) then
  begin
    Status := 404;
    Why := SiteWords.Say('That message is gone.');
  end;
  if Status <> 200 then
  begin
    Info := Why;
    Exit;
  end;
  Result := AddMessage(Room, Parent, Me.Id, Me.Name, Body, Files, Re);
  Info := Trim(Info + #10 + AwayNotes(Result));
end;

{ POST /api/post  room, parent, body, files (tokens from /api/upload), re
  (the message it answers) }
procedure Post(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Id, Status: integer;
  Info, Go: string;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  with ARequest.ContentFields do
    Id := Say(Me, FindRoom(Values['room']), StrToIntDef(Values['parent'], 0), Values['body'], Values['files'], Info, Go, Status, StrToIntDef(Values['re'], 0));
  if Status <> 200 then
    SendText(AResponse, Status, Info)
  else
    SendJSON(AResponse, TJSONObject.Create(['id', Id, 'info', Info, 'go', Go]));
end;

{ POST /api/edit  id, body: the author's own message }
procedure Edit(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Id: integer;
  Body, Html: string;
  Members, Rooms: TStringList;
  Room: TRoom;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  Id := StrToIntDef(ARequest.ContentFields.Values['id'], 0);
  Body := Trim(ARequest.ContentFields.Values['body']);
  if (IntValue('SELECT COUNT(*) FROM messages WHERE id = :m AND user_id = :u AND deleted = 0', [Id, Me.Id]) = 0) or not Can(Me, 'edit-own') then
  begin
    SendText(AResponse, 403, 'Only your own messages can be edited.');
    Exit;
  end;
  // only where the member could still write: not after being put out of the
  // channel, muted in it, or once it is archived
  Room := RoomOfMessage(Id);
  if not CanRead(Me, Room) or Room.Archived or IsMuted(Me.Id, Room.Id) then
  begin
    SendText(AResponse, 403, 'This message cannot be changed now.');
    Exit;
  end;
  if (Body = '') or (Length(Body) > MaxBody) then
  begin
    SendText(AResponse, 400, 'An edited message cannot be empty or too long. Delete it instead.');
    Exit;
  end;
  Members := TStringList.Create;
  Rooms := TStringList.Create;
  try
    Html := RenderText(Body, @MemberExists, @RoomExists, Members, Rooms);
    Exec('UPDATE messages SET body = :b, html = :h, edited = 1 WHERE id = :m', [Body, Html, Id]);
    NoteNames(Id, Me.Id, Members, Rooms, (IntValue('SELECT COUNT(*) FROM messages WHERE id = :m' + ' AND parent_id IS NULL', [Id]) > 0) and not RoomOfMessage(Id).Private);
  finally
    Rooms.Free;
    Members.Free;
  end;
  RunMessageHooks(Id, Body);
  Touch(Id);
  SendText(AResponse, 200, 'ok');
end;

{ POST /api/delete  id: the author, or whoever may delete any message there }
procedure Remove(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Id, Author, Parent: integer;
  Room: TRoom;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  Id := StrToIntDef(ARequest.ContentFields.Values['id'], 0);
  Author := IntValue('SELECT user_id FROM messages WHERE id = :m', [Id]);
  Room := RoomOfMessage(Id);
  // one's own, or anyone's in a channel the member can read and moderates
  if not ((Author = Me.Id) and Can(Me, 'delete-own')) and not (CanRead(Me, Room) and RoomCan(Me, 'delete-any', Room)) then
  begin
    SendText(AResponse, 403, 'That is not yours to delete.');
    Exit;
  end;
  Exec('UPDATE messages SET body = '''', html = '''', deleted = 1, pinned = 0 WHERE id = :m', [Id]);
  DeleteFilesOf(Id, 'message');
  Parent := IntValue('SELECT parent_id FROM messages WHERE id = :m', [Id]);
  if Parent > 0 then
    Exec('UPDATE messages SET reply_count = ' + SqlGreatest('reply_count - 1', '0') + ' WHERE id = :p', [Parent]);
  Touch(Id);
  if Parent > 0 then
    Touch(Parent);
  SendText(AResponse, 200, 'ok');
end;

{ POST /api/react  id, r (an emoji): adds the member's reaction or takes it
  back.  Added, it has to be one the site offers now; one's own comes off
  whatever it is. }
procedure React(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Id: integer;
  R: string;
  Room: TRoom;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  Id := StrToIntDef(ARequest.ContentFields.Values['id'], 0);
  R := Trim(ARequest.ContentFields.Values['r']);
  Room := RoomOfMessage(Id);
  if not CanRead(Me, Room) or not RoomCan(Me, 'react', Room) then
    SendText(AResponse, 403, 'Reactions are not open to you here.')
  else if ExecCount('DELETE FROM reactions WHERE message_id = :m AND user_id = :u AND reaction = :r', [Id, Me.Id, R]) > 0 then
  begin
    Touch(Id);
    SendText(AResponse, 200, 'ok');
  end
  else if not IsReaction(R) then
    SendText(AResponse, 400, NoSuchReaction)
  else
  begin
    Exec('INSERT INTO reactions (message_id, user_id, reaction) SELECT id, :u, :r FROM messages' + ' WHERE id = :m AND deleted = 0', [Me.Id, R, Id]);
    Touch(Id);
    SendText(AResponse, 200, 'ok');
  end;
end;

{ GET /api/reacted?id=&r=  who put the emoji r on the message: names (the
  first 20 by the alphabet) and more (how many beyond them).  For whoever
  may read the message's channel. }
procedure Reacted(ARequest: TRequest; AResponse: TResponse);
var
  Id: integer;
begin
  CheckConnection;
  Id := StrToIntDef(ARequest.QueryFields.Values['id'], 0);
  if not CanRead(CurrentMember(ARequest), RoomOfMessage(Id)) then
    SendText(AResponse, 404, 'That message is gone.')
  else
    SendJSON(AResponse, WhoReacted('reactions', 'message_id', Id, ARequest.QueryFields.Values['r']));
end;

{ POST /api/pin  id }
procedure Pin(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Id: integer;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  Id := StrToIntDef(ARequest.ContentFields.Values['id'], 0);
  // in a channel the member can read, and only a message still there
  if not CanRead(Me, RoomOfMessage(Id)) or not RoomCan(Me, 'pin', RoomOfMessage(Id)) then
  begin
    SendText(AResponse, 403, 'Only the channel''s owner or a moderator pins messages.');
    Exit;
  end;
  Exec('UPDATE messages SET pinned = 1 - pinned WHERE id = :m AND deleted = 0', [Id]);
  Touch(Id);
  SendText(AResponse, 200, 'ok');
end;

{ GET /api/commands  for the message box's suggestions; anywhere marks the
  ones that also work in a private conversation }
procedure ShowCommands(ARequest: TRequest; AResponse: TResponse);
var
  List: TJSONArray;
  C: TCommand;
begin
  List := TJSONArray.Create;
  for C in Commands do
    List.Add(TJSONObject.Create(['name', C.Name, 'usage', SiteWords.Say(C.Usage), 'anywhere', C.Anywhere]));
  SendJSON(AResponse, List);
end;

{ Commands every site has; ChatCommands adds the IRC ones. }

{ /help lists the commands that work where it was typed; /help name (or
  /help /name) gives that one's line, wherever it works. }
function HelpCommand(const Me: TMember; const Room: TRoom; Parent: integer; const Args: string): TCommandResult;
var
  Lines, Wanted: string;
  C: TCommand;
begin
  Wanted := Copy(Args, 1, Pos(' ', Args + ' ') - 1).TrimLeft(['/']);
  Lines := '';
  for C in Commands do
    if SameText(C.Name, Wanted) then
      Exit(CommandResult('', SiteWords.Say(C.Usage)))
    else if (Room.Id > 0) or C.Anywhere then
      Lines := Lines + SiteWords.Say(C.Usage) + #10;
  Lines := Lines + SiteWords.Say(MsgUsage);
  if SameText(Wanted, 'msg') then
    Lines := SiteWords.Say(MsgUsage)
  else if Wanted <> '' then
    Lines := Format(SiteWords.Say('There is no /%s. The commands:'), [Wanted]) + #10 + Lines;
  Result := CommandResult('', Lines);
end;

function MeCommand(const Me: TMember; const Room: TRoom; Parent: integer; const Args: string): TCommandResult;
begin
  if Args = '' then
    Result := CommandResult('', SiteWords.Say('Use: /me does something'))
  else
    Result := CommandResult('*' + Me.Name + ' ' + Args + '*', '');
end;

function TopicCommand(const Me: TMember; const Room: TRoom; Parent: integer; const Args: string): TCommandResult;
begin
  if not RoomCan(Me, 'set-topic', Room) then
    Exit(CommandResult('', SiteWords.Say('Only the channel''s owner or a moderator changes its topic.')));
  Exec('UPDATE rooms SET topic = :t WHERE id = :r', [Copy(Args, 1, 500), Room.Id]);
  Result := CommandResult('changed the topic: ' + Args, '');
end;

{ Messages keep the HTML made when they were sent, so code written before
  a language was colored stays plain.  Once for each CODE_COLORS, at
  startup: every message with a code block is shaped again from its own
  words. }
procedure ColorOldCode;
const
  CODE_COLORS = '4';
var
  Members, Rooms, Ids, Bodies: TStringList;
  I: integer;
begin
  if Setting('code_colors', '') = CODE_COLORS then
    Exit;
  Members := TStringList.Create;
  Rooms := TStringList.Create;
  Ids := TStringList.Create;
  Bodies := TStringList.Create;
  try
    with Query('SELECT id, body FROM messages WHERE deleted = 0 AND body LIKE ''%```%''', []) do
    try
      while not EOF do
      begin
        Ids.Add(Fields[0].AsString);
        Bodies.Add(Fields[1].AsString);
        Next;
      end;
    finally
      Free;
    end;
    for I := 0 to Ids.Count - 1 do
    begin
      Members.Clear;
      Rooms.Clear;
      Exec('UPDATE messages SET html = :h WHERE id = :m', [RenderText(Bodies[I], @MemberExists, @RoomExists, Members, Rooms), StrToInt(Ids[I])]);
    end;
    SaveSetting('code_colors', CODE_COLORS);
    Log('Code blocks colored again in ' + IntToStr(Ids.Count) + ' messages');
  finally
    Bodies.Free;
    Ids.Free;
    Rooms.Free;
    Members.Free;
  end;
end;

initialization
  RegisterTable('CREATE TABLE IF NOT EXISTS messages (' + ' id INT AUTO_INCREMENT PRIMARY KEY,' + ' room_id INT NOT NULL,' +
    ' parent_id INT NULL,' + ' user_id INT NULL,' + ' author VARCHAR(40) NOT NULL,' + ' body TEXT NOT NULL,' + ' html MEDIUMTEXT NOT NULL,' +
    ' pinned TINYINT NOT NULL DEFAULT 0,' + ' edited TINYINT NOT NULL DEFAULT 0,' + ' deleted TINYINT NOT NULL DEFAULT 0,' +
    ' reply_count INT NOT NULL DEFAULT 0,' + ' last_reply DATETIME NULL,' + ' created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,' +
    ' rev BIGINT UNSIGNED NOT NULL,' + ' INDEX (parent_id), INDEX (user_id, created), INDEX (room_id, pinned), INDEX (room_id, created),' +
    ' INDEX (room_id, user_id), INDEX (created),' + ' FULLTEXT (body)' + ') CHARACTER SET utf8mb4');
  // The rooms a message that starts a thread shows in: where it was said,
  // and each public #room it names.  rev copies the message's, so a room's
  // changes are one index range.
  RegisterTable('CREATE TABLE IF NOT EXISTS message_rooms (' + ' room_id INT NOT NULL, message_id INT NOT NULL, rev BIGINT UNSIGNED NOT NULL,' +
    ' PRIMARY KEY (room_id, message_id), INDEX (message_id), INDEX (room_id, rev))');
  // the message this one answers, of the same channel or thread
  RegisterUpgrade('messages-re', 'ALTER TABLE messages ADD COLUMN re_id INT NULL');
  RegisterTable(ReactionTable('reactions', 'message_id'));
  UpgradeNumberedReactions('reactions', 'message_id');
  RegisterTable('CREATE TABLE IF NOT EXISTS mentions (' + ' message_id INT NOT NULL, user_id INT NOT NULL,' + ' PRIMARY KEY (user_id, message_id))');
  RegisterStartup(@ColorOldCode);
  RegisterFileGuard('message', @MayFetchFile);
  RegisterPermission('react', 'React to messages', 'member');
  RegisterPermission('edit-own', 'Edit their own messages', 'member');
  RegisterPermission('delete-own', 'Delete their own messages', 'member');
  RegisterPermission('delete-any', 'Delete anyone''s messages', 'owner,room-moderator,moderator,admin');
  RegisterPermission('pin', 'Pin messages', 'owner,room-moderator,moderator,admin');
  RegisterCommand('help', '/help [command] - lists the commands, or explains one', @HelpCommand, True);
  RegisterCommand('me', '/me does something - says it as an action: your name, then what you typed', @MeCommand, True);
  RegisterCommand('topic', '/topic text - sets the channel''s topic', @TopicCommand);
  HTTPRouter.RegisterRoute('/api/rooms', rmGet, @ShowRooms);
  HTTPRouter.RegisterRoute('/api/commands', rmGet, @ShowCommands);
  HTTPRouter.RegisterRoute('/api/messages', rmGet, @ShowMessages);
  HTTPRouter.RegisterRoute('/api/thread', rmGet, @ShowThread);
  HTTPRouter.RegisterRoute('/api/pins', rmGet, @ShowPins);
  RegisterSearch('chat', 'Chat', 10, @FindInChat, 'view-room');
  HTTPRouter.RegisterRoute('/api/search', rmGet, @Search);
  HTTPRouter.RegisterRoute('/api/sync', rmGet, @Sync);
  HTTPRouter.RegisterRoute('/api/post', rmPost, @Post);
  HTTPRouter.RegisterRoute('/api/edit', rmPost, @Edit);
  HTTPRouter.RegisterRoute('/api/delete', rmPost, @Remove);
  HTTPRouter.RegisterRoute('/api/react', rmPost, @React);
  HTTPRouter.RegisterRoute('/api/reacted', rmGet, @Reacted);
  HTTPRouter.RegisterRoute('/api/pin', rmPost, @Pin);
end.
