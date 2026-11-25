unit SiteReactions;

{ Shared reaction lists, stored as emoji so changing choices preserves
  existing reactions. /api/me exposes shown and more lists. Modules own
  their tables and permissions; ReactionTable, AttachReactions and
  WhoReacted share the storage and reading logic. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpjson;

const
  NoSuchReaction = 'This site does not offer that reaction.';
  { How many names WhoReacted gives; the rest are a number. }
  ReactedNames = 20;

{ The statement that makes a module's table of reactions: which member
  (user_id) put which emoji (reaction) on what (the column Thing). }
function ReactionTable(const Name, Thing: string): string;
{ For such a table from when a reaction was kept as a number, one of six:
  the upgrades that make it one of emoji, each number turned into its own. }
procedure UpgradeNumberedReactions(const Name, Thing: string);
{ The site's reactions now: the ones shown at once and the rest, none
  twice. }
procedure ReactionLists(out Shown, More: TStringArray);
{ True when Emoji is one of them. }
function IsReaction(const Emoji: string): boolean;
{ What is wrong with a line of emoji an admin wrote, '' when every word of
  it is one. }
function EmojiLineProblem(const Line: string): string;
{ The reactions in Table on the things Ids (numbers with commas between),
  put on each item of List, told by its "id", as "reactions": the emoji
  (r), how many gave it (n) and whether MeId did (mine). }
procedure AttachReactions(List: TJSONArray; const Table, Thing, Ids: string; MeId: integer);
{ Who put Emoji on a thing: the first ReactedNames names by the alphabet
  (names), and how many members beyond them (more). }
function WhoReacted(const Table, Thing: string; Id: integer; const Emoji: string): TJSONObject;

implementation

uses
  Classes, StrUtils, SiteDb, SiteUsers, SiteAdmin, SiteWords;

const
  DefaultShown = '👍 ❤️ 😂 🎉 🤔 👎';
  DefaultMore = '😠 😢 😮 🙏 👏 🔥 👀 ✅ ❌ 💯 🚀 😄 😉 😎 🙂 😐 😕 😬 ' +
    '🤯 😱 🥳 🤝 💪 👌 🤷 🙌 💡 ⭐ 😡 🥵 💩 😅 😵‍💫 🤢 🤮';
  MaxShown = 12;
  MaxAll = 120;
  // a setting's value is cut here when it is saved
  MaxLine = 2000;

{ The emoji is told apart by its bytes: the usual collations call
  different emoji equal. }
function ReactionTable(const Name, Thing: string): string;
begin
  Result := 'CREATE TABLE IF NOT EXISTS ' + Name + ' (' + Thing + ' INT NOT NULL, user_id INT NOT NULL,' +
    ' reaction VARCHAR(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL, PRIMARY KEY (' + Thing + ', user_id, reaction))';
end;

{ A new table takes the old one's place, since not every database server
  changes a column's type where it stands. }
procedure UpgradeNumberedReactions(const Name, Thing: string);
begin
  RegisterUpgrade(Name + '-emoji-1', ReactionTable(Name + '_emoji', Thing));
  RegisterUpgrade(Name + '-emoji-2', 'INSERT INTO ' + Name + '_emoji (' + Thing + ', user_id, reaction) SELECT ' + Thing + ', user_id,' +
    ' CASE reaction WHEN ''0'' THEN ''👍'' WHEN ''1'' THEN ''❤️'' WHEN ''2'' THEN ''😂'' WHEN ''3'' THEN ''🎉'' WHEN ''4'' THEN ''🤔'' ELSE ''👎'' END' +
    ' FROM ' + Name + ' WHERE reaction IN (''0'', ''1'', ''2'', ''3'', ''4'', ''5'')');
  RegisterUpgrade(Name + '-emoji-3', 'DROP TABLE ' + Name);
  RegisterUpgrade(Name + '-emoji-4', 'ALTER TABLE ' + Name + '_emoji RENAME TO ' + Name);
end;

{ Line's words in their order, without those in Skip and without repeats. }
function Words(const Line: string; const Skip: TStringArray): TStringArray;
var
  W: string;
begin
  Result := nil;
  for W in Line.Split([' ', #9, #10, #13], TStringSplitOptions.ExcludeEmpty) do
    if not MatchStr(W, Skip) and not MatchStr(W, Result) then
      Result := Concat(Result, [W]);
end;

procedure ReactionLists(out Shown, More: TStringArray);
begin
  Shown := Words(Setting('reactions_shown', DefaultShown), nil);
  More := Words(Setting('reactions_more', DefaultMore), Shown);
end;

function IsReaction(const Emoji: string): boolean;
var
  Shown, More: TStringArray;
begin
  ReactionLists(Shown, More);
  Result := MatchStr(Emoji, Shown) or MatchStr(Emoji, More);
end;

{ Told without tables: 1 to 32 bytes of whole UTF-8 with nothing below
  U+00A9 in it, so no English letters, digits, punctuation, markup or
  control characters.  Letters of other scripts pass. }
function LooksLikeEmoji(const S: string): boolean;
const
  Least: array[1..3] of integer = ($80, $800, $10000);
var
  P, N, I, Code: integer;
begin
  Result := (S <> '') and (Length(S) <= 32);
  P := 1;
  while Result and (P <= Length(S)) do
  begin
    case Ord(S[P]) of
      $C2..$DF: N := 1;
      $E0..$EF: N := 2;
      $F0..$F4: N := 3;
      else
        Exit(False);
    end;
    if P + N > Length(S) then
      Exit(False);
    Code := Ord(S[P]) and ($3F shr N);
    for I := 1 to N do
    begin
      Result := Result and (Ord(S[P + I]) and $C0 = $80);
      Code := (Code shl 6) or (Ord(S[P + I]) and $3F);
    end;
    // no longer form of a lower character, no half of a pair
    Result := Result and (Code >= Least[N]) and (Code >= $A9) and (Code <= $10FFFF) and ((Code < $D800) or (Code > $DFFF));
    Inc(P, N + 1);
  end;
end;

function EmojiLineProblem(const Line: string): string;
var
  W: string;
begin
  Result := '';
  for W in Words(Line, nil) do
    if not LooksLikeEmoji(W) then
      Exit(Format(Say('Reactions are emoji with spaces between them: "%s" is not one.'), [W]));
end;

{ The two lists as they are about to be saved: every word an emoji, not
  too many, and each kept without its repeats.  One sent alone is judged
  beside the other as it stands. }
function CheckLists(Sent: TStrings): string;
var
  AtShown, AtMore: integer;
  Shown, More: TStringArray;
begin
  Result := '';
  AtShown := Sent.IndexOfName('reactions_shown');
  AtMore := Sent.IndexOfName('reactions_more');
  if (AtShown < 0) and (AtMore < 0) then
    Exit;
  ReactionLists(Shown, More);
  if AtShown >= 0 then
    Shown := Words(Sent.ValueFromIndex[AtShown], nil);
  if AtMore >= 0 then
    More := Words(Sent.ValueFromIndex[AtMore], Shown)
  else
    More := Words(string.Join(' ', More), Shown);
  Result := EmojiLineProblem(string.Join(' ', Concat(Shown, More)));
  if Result <> '' then
    Exit;
  if Length(Shown) > MaxShown then
    Exit(Format(Say('At most %d reactions are shown at once.'), [MaxShown]));
  if (Length(Shown) + Length(More) > MaxAll) or (Length(string.Join(' ', Shown)) > MaxLine) or (Length(string.Join(' ', More)) > MaxLine) then
    Exit(Format(Say('At most %d reactions in all.'), [MaxAll]));
  if AtShown >= 0 then
    Sent[AtShown] := 'reactions_shown=' + string.Join(' ', Shown);
  if AtMore >= 0 then
    Sent[AtMore] := 'reactions_more=' + string.Join(' ', More);
end;

procedure AttachReactions(List: TJSONArray; const Table, Thing, Ids: string; MeId: integer);
var
  I: integer;
  Item: TJSONObject;
begin
  if Ids = '' then
    Exit;
  with Query('SELECT ' + Thing + ', reaction, COUNT(*), SUM(user_id = :u) FROM ' + Table + ' WHERE ' + Thing + ' IN (' + Ids + ') GROUP BY ' +
      Thing + ', reaction ORDER BY ' + Thing + ', reaction', [MeId]) do
  try
    while not EOF do
    begin
      for I := 0 to List.Count - 1 do
      begin
        Item := List.Objects[I];
        if Item.Integers['id'] = Fields[0].AsInteger then
          Item.Arrays['reactions'].Add(TJSONObject.Create(['r', Fields[1].AsString, 'n', Fields[2].AsInteger, 'mine', Fields[3].AsInteger > 0]));
      end;
      Next;
    end;
  finally
    Free;
  end;
end;

function WhoReacted(const Table, Thing: string; Id: integer; const Emoji: string): TJSONObject;
var
  Names: TJSONArray;
begin
  Names := TJSONArray.Create;
  Result := TJSONObject.Create(['names', Names]);
  with Query('SELECT u.name FROM ' + Table + ' x JOIN users u ON u.id = x.user_id WHERE x.' + Thing + ' = :i AND x.reaction = :r ORDER BY u.name LIMIT :n',
      [Id, Emoji, ReactedNames]) do
  try
    while not EOF do
    begin
      Names.Add(Fields[0].AsString);
      Next;
    end;
  finally
    Free;
  end;
  Result.Add('more', IntValue('SELECT COUNT(*) FROM ' + Table + ' WHERE ' + Thing + ' = :i AND reaction = :r', [Id, Emoji]) - Names.Count);
end;

function ListJSON(const List: TStringArray): TJSONArray;
var
  S: string;
begin
  Result := TJSONArray.Create;
  for S in List do
    Result.Add(S);
end;

{ On what /api/me answers: the lists a page offers. }
procedure AddToMe(const Me: TMember; Answer: TJSONObject);
var
  Shown, More: TStringArray;
begin
  ReactionLists(Shown, More);
  Answer.Add('reactions', TJSONObject.Create(['shown', ListJSON(Shown), 'more', ListJSON(More)]));
end;

initialization
  RegisterSetting('reactions_shown', 'Reactions shown at once: emoji with spaces between them, 12 at most', DefaultShown, 'longtext', 'Reactions');
  RegisterSetting('reactions_more', 'More reactions, behind a button: emoji with spaces between them, 120 in all at most (empty: no button)',
    DefaultMore, 'longtext', 'Reactions');
  RegisterSettingsCheck(@CheckLists);
  RegisterMeHook(@AddToMe);
end.
