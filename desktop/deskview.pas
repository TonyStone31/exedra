unit DeskView;

{ What the server sends, turned into the HTML LazInk shows: one block per
  message, one line per room.  Message bodies come from the server already
  made safe (html); everything else is escaped here. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, fpjson, jsonparser, Graphics, Controls, StdCtrls, Menus, InkMemo, InkMarkdown;

{ One message.  Follows says it continues the one before (same author, a
  few minutes later), so the name line is left out. }
function MessageHtml(Msg: TJSONObject; Follows: boolean; PreviewOpen: boolean = False; PreviewFocus: boolean = False): string;
{ True when Msg goes under Before without its own name line. }
function Continues(Before, Msg: TJSONObject): boolean;
{ True when Msg is the first of its day on show (Before nil or another day). }
function NewDay(Before, Msg: TJSONObject): boolean;
{ The day line over the first message of a day: Today, Yesterday, or the date. }
function DayHtml(Msg: TJSONObject): string;
{ The line over the first message not read before this visit. }
function NewMessagesHtml: string;
{ A room in the list: its name, bold when unread, the mention count. }
function RoomHtml(Room: TJSONObject; Paper: TColor = clWindow; Ink: TColor = clWindowText): string;
function Escape(const S: string): string;
{ The emoji a reaction pill's link stands for (react:id:place, the place
  among its message's reactions) and the message's Id, among the messages
  in Shown; '' when it is not there. }
function ReactionOfLink(Shown: TJSONArray; const LinkName: string; out Id: integer): string;
{ The entries under a React menu: the reactions the site offers (Lists,
  /api/me's reactions), the ones it shows at once and the rest under More,
  those Msg has from this member checked.  Each calls OnClick, its
  caption the emoji. }
procedure FillReactMenu(Menu: TMenuItem; Lists, Msg: TJSONObject; OnClick: TNotifyEvent);
{ Obj's array Name, or an empty one when it has none: a missing field
  is walked over without a check. }
function ArrayOf(Obj: TJSONObject; const Name: string): TJSONArray;
{ The server's UTC time (2026-10-28T14:05:00Z) as local time. }
function LocalTime(const Iso: string): TDateTime;
{ Stripes and a hover band for a memo of messages, mixed from its own
  background and ink so they follow the theme, light or dark; the colors
  of its stylesheet (times, day lines, reaction pills) are set the same
  way, after a marker line, so a theme change can write them again. }
procedure StripeMemo(M: TInkMemo);
procedure SizeExpiryBox(Box: TComboBox);
{ Base moved Share of the way (0..1) towards Ink; the colors here are mixed
  rather than fixed so they hold in a dark theme too. }
function Mix(Base, Ink: TColor; Share: double): TColor;
{ A control's ink: its font color, or the window text when it has none. }
function InkOf(FontColor: TColor): TColor;
{ The quiet ink for notes beside the text, half way from paper to ink. }
function Muted(Paper, Ink: TColor): TColor;
{ C as #rrggbb, for a style attribute or a stylesheet. }
function Hex(C: TColor): string;
{ A section heading in the room or people list, on a Paper background. }
function SectionHtml(const Text: string; Paper, Ink: TColor): string;
{ An unread or mention count: a small pill in the selection colors. }
function CountBadge(N: integer): string;
{ The line over a room: its icon (an index in the list's images, -1 for
  none), its title and a quiet note (the topic) beside it. }
function HeaderHtml(Pic: integer; const Title, Note: string; Paper, Ink: TColor; Menu: boolean = False): string;
{ What an empty room says, centered and quiet. }
function EmptyHtml(const Text: string): string;
{ A private message from /api/dm as a room message, so MessageHtml shows
  it: plain ones have their text and files, locked ones a note.  The
  caller frees it. }
function DmAsMessage(Item: TJSONObject; Locked: boolean = False): TJSONObject;

implementation

uses
  Math, DeskActions, DeskContent;

procedure SizeExpiryBox(Box: TComboBox);
var
  Bmp: TBitmap;
  Text: string;
  W: integer;
begin
  // A bitmap's canvas, not the box's: a frame is made before it has a
  // parent window, and the box's own canvas needs one.
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(1, 1);
    Bmp.Canvas.Font.Assign(Box.Font);
    W := 0;
    for Text in Box.Items do
      W := Max(W, Bmp.Canvas.TextWidth(Text));
    Box.Width := W + Box.Height + Box.Scale96ToFont(8);
  finally
    Bmp.Free;
  end;
end;

function Mix(Base, Ink: TColor; Share: double): TColor;
var
  B, K: longint;

  function Part(Shift: integer): byte;
  begin
    Result := Round(((B shr Shift) and $FF) + (((K shr Shift) and $FF) - ((B shr Shift) and $FF)) * Share);
  end;

begin
  B := ColorToRGB(Base);
  K := ColorToRGB(Ink);
  Result := RGBToColor(Part(0), Part(8), Part(16));
end;

function InkOf(FontColor: TColor): TColor;
begin
  if FontColor = clDefault then
    Result := clWindowText
  else
    Result := FontColor;
end;

function Muted(Paper, Ink: TColor): TColor;
begin
  Result := Mix(Paper, Ink, 0.55);
end;

function Hex(C: TColor): string;
begin
  C := ColorToRGB(C);
  Result := '#' + IntToHex(Red(C), 2) + IntToHex(Green(C), 2) + IntToHex(Blue(C), 2);
end;

procedure StripeMemo(M: TInkMemo);
const
  Marker = '/* theme */';
var
  Ink, Paper: TColor;
  I: integer;
begin
  Ink := InkOf(M.Font.Color);
  M.AlternateColor := Mix(M.Color, Ink, 0.05);
  M.HoverColor := Mix(M.Color, Ink, 0.11);
  M.StyleSheet.BeginUpdate;
  try
    I := M.StyleSheet.IndexOf(Marker);
    if I >= 0 then
      while M.StyleSheet.Count > I do
        M.StyleSheet.Delete(M.StyleSheet.Count - 1);
    M.StyleSheet.Add(Marker);
    Paper := ColorToRGB(M.Color);
    M.StyleSheet.Add(ServerCodeStyles(Red(Paper) + Green(Paper) + Blue(Paper) < 384));
    M.StyleSheet.Add('.at, .edited, .reactions, .replies, .badge, .day, .empty, .pill { color: ' + Hex(Muted(M.Color, Ink)) + ' }');
    M.StyleSheet.Add('.day::before, .day::after, .new::before, .new::after, .pill { border-color: ' + Hex(Mix(M.Color, Ink, 0.2)) + ' }');
    M.StyleSheet.Add('.pill { background-color: ' + Hex(Mix(M.Color, Ink, 0.06)) + ' }');
    M.StyleSheet.Add('.reactions a.pill { color: ' + Hex(Muted(M.Color, Ink)) + '; text-decoration: none }');
    M.StyleSheet.Add('.pill.mine { background-color: ' + Hex(Mix(M.Color, Ink, 0.16)) + '; border-color: ' + Hex(Mix(M.Color, Ink, 0.45)) + '; font-weight: bold }');
    M.StyleSheet.Add('blockquote.preview { margin: 4px 0; padding: 2px 10px; border-left: 3px solid ' + Hex(Mix(M.Color, Ink, 0.25)) + ' }');
    M.StyleSheet.Add('.preview-title { white-space: nowrap; overflow: hidden; text-overflow: ellipsis }');
    M.StyleSheet.Add('.preview a { color: ' + Hex(Muted(M.Color, Ink)) + ' }');
    M.StyleSheet.Add('blockquote.preview-focus { border-color: ' + Hex(Ink) + ' }');
  finally
    M.StyleSheet.EndUpdate;
  end;
end;

{ The label and the list box read the font tag's own attributes (color,
  size as the LCL spells it, bgcolor, pad and radius for a pill), not a
  style attribute, so the lines for them are written that way. }
function SectionHtml(const Text: string; Paper, Ink: TColor): string;
begin
  Result := '<font color="' + Hex(Muted(Paper, Ink)) + '"><small><b>' + Text + '</b></small></font>';
end;

function CountBadge(N: integer): string;
begin
  Result := '<font bgcolor="' + Hex(clHighlight) + '" color="' + Hex(clHighlightText) + '" pad="1 6" radius="9" minw="18"><small><b>' + IntToStr(N) + '</b></small></font>';
end;

function HeaderHtml(Pic: integer; const Title, Note: string; Paper, Ink: TColor; Menu: boolean): string;
begin
  Result := '';
  // In one column the list is not beside the room: a way back to it.
  if Menu then
    Result := '<a href="rooms:">Channels</a> <font color="' + Hex(Muted(Paper, Ink)) + '">&rsaquo;</font> ';
  if Pic >= 0 then
    Result := Result + '<img src="' + IntToStr(Pic) + '" style="vertical-align: middle">&nbsp; ';
  Result := Result + '<font size="-15"><b>' + Escape(Title) + '</b></font>';
  if Note <> '' then
    Result := Result + '<br><font color="' + Hex(Muted(Paper, Ink)) + '"><small>' + Escape(Note) + '</small></font>';
end;

function EmptyHtml(const Text: string): string;
begin
  Result := '<p class="empty">' + Text + '</p>';
end;

function Escape(const S: string): string;
begin
  Result := HtmlEscape(S);
end;

var
  NoItems: TJSONArray;

function ArrayOf(Obj: TJSONObject; const Name: string): TJSONArray;
begin
  if Obj.Find(Name) is TJSONArray then
    Result := Obj.Arrays[Name]
  else
    Result := NoItems;
end;

function LocalTime(const Iso: string): TDateTime;
begin
  Result := UniversalTimeToLocal(ISO8601ToDate(Iso, True));
end;

function NewDay(Before, Msg: TJSONObject): boolean;
begin
  Result := (Before = nil) or (Trunc(LocalTime(Before.Get('at', ''))) <> Trunc(LocalTime(Msg.Get('at', ''))));
end;

function DayHtml(Msg: TJSONObject): string;
var
  D: TDateTime;
begin
  D := Trunc(LocalTime(Msg.Get('at', '')));
  if D = Date then
    Result := 'Today'
  else if D = Date - 1 then
    Result := 'Yesterday'
  else if YearOf(D) = YearOf(Date) then
    Result := FormatDateTime('dddd d mmmm', D)
  else
    Result := FormatDateTime('dddd d mmmm yyyy', D);
  Result := '<p class="day">' + Result + '</p>';
end;

function NewMessagesHtml: string;
begin
  Result := '<p class="new">New messages</p>';
end;

{ The time of a message: the day too, and the year when it is another. }
function WhenText(Msg: TJSONObject): string;
var
  T: TDateTime;
begin
  T := LocalTime(Msg.Get('at', ''));
  if YearOf(T) = YearOf(Date) then
    Result := FormatDateTime('ddd d mmm, h:nn am/pm', T)
  else
    Result := FormatDateTime('ddd d mmm yyyy, h:nn am/pm', T);
end;

function Continues(Before, Msg: TJSONObject): boolean;
begin
  Result := (Before <> nil) and (Before.Get('name', '') = Msg.Get('name', '')) and not Before.Get('deleted', False) and
    (MinutesBetween(LocalTime(Before.Get('at', '')), LocalTime(Msg.Get('at', ''))) < 5);
end;

{ Each reaction is a pill and a link (react:id:place, its place among the
  message's) that adds one's own or takes it back; one's own are marked. }
function ReactionLine(Msg: TJSONObject): string;
var
  Item: TJSONEnum;
  R: TJSONObject;
  Cls: string;
begin
  Result := '';
  for Item in ArrayOf(Msg, 'reactions') do
  begin
    R := TJSONObject(Item.Value);
    Cls := 'pill';
    if R.Get('mine', False) then
      Cls := 'pill mine';
    Result := Result + '<a class="' + Cls + '" href="react:' + IntToStr(Msg.Get('id', 0)) + ':' + IntToStr(Item.KeyNum) + '">' +
      Escape(R.Get('r', '')) + ' ' + IntToStr(R.Get('n', 0)) + '</a> ';
  end;
  if Result <> '' then
    Result := '<p class="reactions">' + Result + '</p>';
end;

function ReactionOfLink(Shown: TJSONArray; const LinkName: string; out Id: integer): string;
var
  Parts: TStringArray;
  Reactions: TJSONArray;
  I, Place: integer;
begin
  Result := '';
  Id := 0;
  Parts := LinkName.Split([':']);
  if Length(Parts) <> 3 then
    Exit;
  Id := StrToIntDef(Parts[1], 0);
  Place := StrToIntDef(Parts[2], -1);
  for I := 0 to Shown.Count - 1 do
    if Shown.Objects[I].Get('id', 0) = Id then
    begin
      Reactions := ArrayOf(Shown.Objects[I], 'reactions');
      if (Place >= 0) and (Place < Reactions.Count) then
        Result := Reactions.Objects[Place].Get('r', '');
    end;
end;

procedure FillReactMenu(Menu: TMenuItem; Lists, Msg: TJSONObject; OnClick: TNotifyEvent);

  procedure Put(Under: TMenuItem; const List: string);
  var
    Emoji, Mine: TJSONEnum;
    Entry: TMenuItem;
  begin
    for Emoji in ArrayOf(Lists, List) do
    begin
      Entry := TMenuItem.Create(Menu);
      Entry.Caption := Emoji.Value.AsString;
      Entry.OnClick := OnClick;
      if Msg <> nil then
        for Mine in ArrayOf(Msg, 'reactions') do
          if TJSONObject(Mine.Value).Get('mine', False) and (TJSONObject(Mine.Value).Get('r', '') = Entry.Caption) then
            Entry.Checked := True;
      Under.Add(Entry);
    end;
  end;

var
  More: TMenuItem;
begin
  Menu.Clear;
  if Lists = nil then
    Exit;
  Put(Menu, 'shown');
  if ArrayOf(Lists, 'more').Count = 0 then
    Exit;
  More := TMenuItem.Create(Menu);
  More.Caption := 'More';
  Menu.Add(More);
  Put(More, 'more');
end;

function IsImageName(const Name: string): boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(Name));
  Result := (Ext = '.png') or (Ext = '.jpg') or (Ext = '.jpeg') or (Ext = '.gif') or (Ext = '.webp');
end;

{ Pictures shown, other files as links; the program fetches the pictures
  (TInkMemo.OnResource). }
function FileLines(Msg: TJSONObject): string;
var
  Item: TJSONEnum;
  F: TJSONObject;
  Url, Expiry: string;
  Files: TJSONArray;
begin
  Result := '';
  Files := CheckedFiles(Msg.Find('files'));
  try
    for Item in Files do
    begin
      F := TJSONObject(Item.Value);
      Url := Escape(F.Get('url', ''));
      if (F.Get('iv', '') <> '') and IsImageName(F.Get('name', '')) then
        // opened here with the conversation's key (the program's OnResource)
        Result := Result + '<p><a href="sealed:' + Escape(F.Get('token', '')) + '"><img class="shot" src="sealed:' + Escape(F.Get('token', '')) +
          '" alt="' + Escape(F.Get('name', '')) + '"></a></p>'
      else if F.Get('iv', '') <> '' then
        Result := Result + '<p><a href="sealed:' + Escape(F.Get('token', '')) + '">' + Escape(F.Get('name', '')) + '</a> <span class="at">locked file, ' +
          IntToStr(F.Get('size', int64(0)) div 1024 + 1) + ' KB</span></p>'
      else if F.Get('image', False) then
        Result := Result + '<p><a href="' + Url + '"><img class="shot" src="' + Url + '" alt="' + Escape(F.Get('name', '')) + '"></a></p>'
      else
        Result := Result + '<p><a href="' + Url + '">' + Escape(F.Get('name', '')) + '</a> <span class="at">' + IntToStr(F.Get('size', int64(0)) div 1024 + 1) + ' KB</span></p>';
      Expiry := FileExpiry(F);
      if Expiry <> '' then
        Result := Result + '<p class="at">' + Escape(Expiry) + '</p>';
    end;
  finally
    Files.Free;
  end;
end;

function MessageHtml(Msg: TJSONObject; Follows: boolean; PreviewOpen: boolean; PreviewFocus: boolean): string;
var
  Replies: integer;
begin
  Result := '';
  if not Follows then
  begin
    Result := '<p class="who">';
    if Msg.Get('avatar', '') <> '' then
      Result := Result + '<img class="face" alt="" src="' + Escape(Msg.Get('avatar', '')) + '"> ';
    Result := Result + '<b>' + Escape(Msg.Get('name', '')) + '</b>';
    if Msg.Get('badge', '') <> '' then
      Result := Result + ' <span class="badge">' + Escape(UpperCase(Msg.Get('badge', ''))) + '</span>';
    Result := Result + ' &nbsp;<span class="at">' + WhenText(Msg) + '</span></p>';
  end;
  if Msg.Get('deleted', False) then
    Result := Result + '<p><i>This message was deleted.</i></p>'
  else if Msg.Get('ignored', False) then
    Result := Result + '<p><i>A message from someone you ignore.</i></p>'
  else
  begin
    Result := Result + DmReplyHtml(Msg.Find('re')) + ServerBodyHtml(Msg.Get('html', ''));
    if Msg.Get('edited', False) then
      Result := Result + '<p class="edited">(edited)</p>';
    Result := Result + FileLines(Msg) + PreviewHtml(Msg, PreviewOpen, PreviewFocus) + ReactionLine(Msg);
  end;
  Replies := Msg.Get('replies', 0);
  if Replies = 1 then
    Result := Result + '<p class="replies"><a href="thread:' + IntToStr(Msg.Get('id', 0)) + '">1 reply</a></p>'
  else if Replies > 1 then
    Result := Result + '<p class="replies"><a href="thread:' + IntToStr(Msg.Get('id', 0)) + '">' + IntToStr(Replies) + ' replies</a></p>';
end;

function DmAsMessage(Item: TJSONObject; Locked: boolean): TJSONObject;
var
  Payload: TJSONObject;
  Reply: TJSONObject;
  Html: string;
begin
  Result := TJSONObject.Create(['id', Item.Get('id', 0), 'name', JsonText(Item, 'from', 60), 'at', JsonText(Item, 'at', 40)]);
  if Item.Find('edited') is TJSONBoolean then
    Result.Add('edited', Item.Get('edited', False));
  if Item.Find('reactions') is TJSONArray then
    Result.Add('reactions', Item.Arrays['reactions'].Clone);
  Payload := nil;
  if JsonText(Item, 'iv', 128) = '' then
    Payload := ReadDmPayload(JsonText(Item, 'data', 262144));
  try
    if not (Payload is TJSONObject) then
      Html := '<p><i>A locked message: open it on the website.</i></p>'
    else if TJSONObject(Payload).Get('t', '') = 'beam' then
      // the browser does the beaming; the link opens this conversation there
      Html := '<p><i>A file beamed browser to browser: <a href="beam:">open it on the website</a>.</i></p>'
    else
    begin
      if TJSONObject(Payload).Find('text') is TJSONString then
        Result.Add('body', TJSONObject(Payload).Get('text', ''));
      Reply := CheckedDmReply(TJSONObject(Payload).Find('re'));
      if Reply <> nil then
        Result.Add('re', Reply);
      Html := '';
      if Locked or not (Item.Find('html') is TJSONString) then
        Html := MarkdownToHTML(DmActionText(Result.Get('name', ''), Result.Get('body', '')));
      Html := DmBodyHtml(Item, Html, Locked);
      if not Locked and (Item.Find('preview') is TJSONObject) then
        Result.Add('preview', Item.Objects['preview'].Clone);
      if TJSONObject(Payload).Find('files') is TJSONArray then
      begin
        Result.Add('files', CheckedFiles(Payload.Find('files')));
        ApplyFileExpiry(Result.Arrays['files'], Item.Find('files'));
      end;
      if (Payload.Get('t', '') = 'text') or (Payload.Get('t', '') = 'file') then
        Result.Add('dm_payload', Payload.Clone);
      // it came locked: an edit must go back locked, or not at all
      if Locked then
        Result.Add('sealed', True);
    end;
    Result.Add('html', Html);
  finally
    Payload.Free;
  end;
end;

function RoomHtml(Room: TJSONObject; Paper: TColor; Ink: TColor): string;
var
  Name: string;
begin
  Name := Escape(Room.Get('title', Room.Get('slug', '')));
  if (NotifyMode(Room) = 'all') and (RoomUnread(Room) > 0) then
    Result := '<b>' + Name + '</b>'
  else
    Result := Name;
  if RoomMentions(Room) > 0 then
    Result := Result + ' ' + CountBadge(RoomMentions(Room));
  if NotifyMode(Room) = 'none' then
    Result := '<font color="' + Hex(Muted(Paper, Ink)) + '">' + Result + '</font>';
end;

initialization
  NoItems := TJSONArray.Create;

finalization
  NoItems.Free;
end.
