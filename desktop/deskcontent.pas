unit DeskContent;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson;

type
  TMemberStatus = (msUnknown, msOffline, msOnline, msAway);

  TPreviewState = class
  private
    Opened: TStringList;
  public
    FocusId: integer;
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function IsOpen(Msg: TJSONObject): boolean;
    function Toggle(Msg: TJSONObject): boolean;
    function Step(List: TJSONArray; Backward: boolean): integer;
  end;

function HtmlEscape(const S: string): string;
function ServerBodyHtml(const Html: string): string;
function ServerCodeStyles(Dark: boolean): string;
function WebAddress(const S: string): boolean;
{ A server's address as typed, made whole: https:// before a bare name.
  False, with the reason in Why, for one this program does not sign in
  to: plain http is only for a server on this computer or this network,
  since the sign-in would cross the internet unprotected. }
function ServerAddress(const Typed: string; out Url, Why: string): boolean;
function PreviewOf(Msg: TJSONObject): TJSONObject;
function PreviewHtml(Msg: TJSONObject; Expanded, Focused: boolean): string;
function MemberStatus(Member: TJSONObject; Here: boolean = False): TMemberStatus;
function StatusDot(Status: TMemberStatus; Dark: boolean): string;
{ The message another one answers (re), in a private conversation and in
  a channel alike: its first words for the line over the box, a checked
  copy of what came (nil when it is not the expected shape; the caller
  frees the copy), and the line shown above the answer. }
function DmReplyText(const Text: string): string;
function CheckedDmReply(Data: TJSONData): TJSONObject;
function DmReplyHtml(Data: TJSONData): string;
{ The answered message's words beside its author's name.  An action's own
  words begin with that name (Ann waves), which is not said twice. }
function ReplyWords(Reply: TJSONObject): string;
{ A private message's words as they are shown: /me waves from Ann is
  *Ann waves*, an action as in a channel; anything else is as it was. }
function DmActionText(const From, Text: string): string;
function JsonText(Obj: TJSONObject; const Name: string; Limit: integer): string;
function CheckedFiles(Data: TJSONData): TJSONArray;
function ReadDmPayload(const Data: string): TJSONObject;
function DmEditPayload(Payload: TJSONObject; const Text: string): TJSONObject;
function InCodeFence(const Text: string; Caret: integer): boolean;
function MessageLink(const Server: string; Id: integer): string;
{ The files waiting to go with the next message: their tokens, comma
  separated, as a post names them. }
function AttachedTokens(Files: TJSONArray): string;
{ Those files as the line over the composer: each with its name, its size
  and a link "drop:" and its place in the list, which takes it out. }
function AttachedHtml(Files: TJSONArray): string;
{ The Attach button's words, with how many files wait. }
function AttachCaption(Files: TJSONArray): string;
function FileExpiry(FileInfo: TJSONObject): string;
function ExpiryValue(Index: integer): string;
function DmBodyHtml(Item: TJSONObject; const LocalHtml: string; Locked: boolean): string;
procedure ApplyFileExpiry(Files: TJSONArray; Metadata: TJSONData);

implementation

uses
  StrUtils, LazUTF8, jsonparser, DateUtils;

function ServerBodyHtml(const Html: string): string;
const
  Header = '<div class="codebar"><span>';
  AfterLanguage = '</span><button type="button" class="copy">Copy</button></div><pre><code>';
var
  Start, Stop, Next, I: SizeInt;
  Lang: string;
begin
  Result := '';
  Next := 1;
  Start := Pos(Header, Html);
  while Start > 0 do
  begin
    Result := Result + Copy(Html, Next, Start - Next);
    Stop := PosEx('</span>', Html, Start + Length(Header));
    if (Stop > 0) and (Copy(Html, Stop, Length(AfterLanguage)) = AfterLanguage) then
    begin
      Lang := Copy(Html, Start + Length(Header), Stop - Start - Length(Header));
      // Only a language name belongs in the class, never header markup.
      for I := 1 to Length(Lang) do
        if not (Lang[I] in ['a'..'z', 'A'..'Z', '0'..'9', '-', '_', '+', '#']) then
        begin
          Lang := '';
          Break;
        end;
      Result := Result + '<pre><code';
      if Lang <> '' then
        Result := Result + ' class="language-' + Lang + '"';
      Result := Result + '>';
      Next := Stop + Length(AfterLanguage);
    end
    else
    begin
      Result := Result + Header;
      Next := Start + Length(Header);
    end;
    Start := PosEx(Header, Html, Next);
  end;
  Result := Result + Copy(Html, Next, Length(Html));
end;

function ServerCodeStyles(Dark: boolean): string;
const
  Colors: array[boolean, 0..8] of string = (
    ('#8f3fb6', '#6b7686', '#1d7d4f', '#b65a00', '#2c63d6', '#3c4656', '#0f9d8f', '#d64545', '#c27a06'),
    ('#c792ea', '#6f7d93', '#9ccc65', '#f7a35c', '#82aaff', '#a9b4c6', '#3fd1c0', '#ff6b6b', '#f2b042'));
begin
  Result := 'pre code .keyword, pre code .section { color: ' + Colors[Dark, 0] + '; font-weight: bold }' + 'pre code .comment { color: ' +
    Colors[Dark, 1] + '; font-style: italic }' + 'pre code .strings, pre code .characters, pre code .rawstring, pre code .template { color: ' +
    Colors[Dark, 2] + ' }' + 'pre code .numbers, pre code .escape { color: ' + Colors[Dark, 3] + ' }' + 'pre code .directive, pre code .attribute, pre code .key { color: ' +
    Colors[Dark, 4] + ' }' + 'pre code .symbol, pre code .operator { color: ' + Colors[Dark, 5] + ' }' + 'pre code .attribute-lfm { color: ' +
    Colors[Dark, 6] + '; font-weight: bold }' + 'pre code .assembler { color: ' + Colors[Dark, 0] + ' }' + 'pre code .error { color: ' +
    Colors[Dark, 7] + ' }' + 'pre code .warning { color: ' + Colors[Dark, 8] + ' }';
end;

function JsonText(Obj: TJSONObject; const Name: string; Limit: integer): string;
begin
  Result := '';
  if (Obj <> nil) and (Obj.Find(Name) is TJSONString) then
    Result := UTF8Copy(Obj.Get(Name, ''), 1, Limit);
end;

function CheckedFiles(Data: TJSONData): TJSONArray;
const
  Names: array[0..6] of string = ('name', 'url', 'token', 'iv', 'expires', 'type', 'mime');
  Limits: array[0..6] of integer = (255, 4096, 128, 128, 40, 128, 128);
var
  I, J: integer;
  Source, Dest: TJSONObject;
  Size: int64;
  S: string;
  C: char;
begin
  Result := TJSONArray.Create;
  if not (Data is TJSONArray) then
    Exit;
  for I := 0 to TJSONArray(Data).Count - 1 do
  begin
    if I >= 100 then
      Break;
    if not (TJSONArray(Data)[I] is TJSONObject) then
      Continue;
    Source := TJSONObject(TJSONArray(Data)[I]);
    Dest := TJSONObject.Create;
    for J := 0 to High(Names) do
      if Source.Find(Names[J]) is TJSONString then
      begin
        S := JsonText(Source, Names[J], Limits[J]);
        if Names[J] = 'token' then
          for C in S do
            if not (C in ['a'..'z', 'A'..'Z', '0'..'9', '-', '_']) then
            begin
              S := '';
              Break;
            end;
        if (Names[J] = 'url') and not S.StartsWith('/f/') then
          S := '';
        Dest.Add(Names[J], S);
      end;
    if (Source.Find('size') is TJSONNumber) and TryStrToInt64(Source.Find('size').AsJSON, Size) and (Size >= 0) then
      Dest.Add('size', Size);
    if Source.Find('image') is TJSONBoolean then
      Dest.Add('image', Source.Get('image', False));
    if Source.Find('once') is TJSONBoolean then
      Dest.Add('once', Source.Get('once', False));
    Result.Add(Dest);
  end;
end;

procedure ApplyFileExpiry(Files: TJSONArray; Metadata: TJSONData);
var
  Checked: TJSONArray;
  I, J: integer;
  Dest, Source: TJSONObject;
begin
  Checked := CheckedFiles(Metadata);
  try
    for I := 0 to Files.Count - 1 do
    begin
      Dest := Files.Objects[I];
      if Dest.Get('token', '') = '' then
        Continue;
      for J := 0 to Checked.Count - 1 do
      begin
        Source := Checked.Objects[J];
        if Source.Get('token', '') <> Dest.Get('token', '') then
          Continue;
        if Source.Find('expires') is TJSONString then
          Dest.Strings['expires'] := Source.Get('expires', '');
        if Source.Find('once') is TJSONBoolean then
          Dest.Booleans['once'] := Source.Get('once', False);
        Break;
      end;
    end;
  finally
    Checked.Free;
  end;
end;

function DmBodyHtml(Item: TJSONObject; const LocalHtml: string; Locked: boolean): string;
begin
  if not Locked and (Item.Find('html') is TJSONString) then
    Exit(JsonText(Item, 'html', 1048576));
  Result := LocalHtml;
  if Locked then
    Result := StringReplace(Result, '<pre>', '<p class="at">Not colored: the server cannot read a locked conversation.</p><pre>', [rfReplaceAll]);
end;

function ReadDmPayload(const Data: string): TJSONObject;
var
  Parsed: TJSONData;
  Source: TJSONObject;
begin
  Result := nil;
  if Length(Data) > 262144 then
    Exit;
  try
    Parsed := GetJSON(Data);
  except
    Exit;
  end;
  try
    if not (Parsed is TJSONObject) then
      Exit;
    Source := TJSONObject(Parsed);
    // Keep the original metadata for edits. Drawing uses checked copies.
    Result := Source.Clone as TJSONObject;
    Result.Delete('t');
    Result.Add('t', JsonText(Source, 't', 20));
    Result.Delete('text');
    Result.Add('text', JsonText(Source, 'text', 65536));
    if not (Source.Find('files') is TJSONArray) then
      Result.Delete('files');
  finally
    Parsed.Free;
  end;
end;

function DmEditPayload(Payload: TJSONObject; const Text: string): TJSONObject;
begin
  Result := nil;
  if (Payload = nil) or not ((Payload.Get('t', '') = 'text') or (Payload.Get('t', '') = 'file')) then
    raise Exception.Create('This message cannot be edited.');
  if (Trim(Text) = '') and (not (Payload.Find('files') is TJSONArray) or (Payload.Arrays['files'].Count = 0)) then
    raise Exception.Create('An edited message cannot be empty. Delete it instead.');
  Result := Payload.Clone as TJSONObject;
  Result.Strings['text'] := Trim(Text);
end;

function InCodeFence(const Text: string; Caret: integer): boolean;
var
  S: string;
  I: integer;
begin
  S := UTF8Copy(Text, 1, Caret);
  Result := False;
  I := Pos('```', S);
  while I > 0 do
  begin
    Result := not Result;
    I := PosEx('```', S, I + 3);
  end;
end;

function MessageLink(const Server: string; Id: integer): string;
begin
  Result := '';
  if WebAddress(Server) and (Id > 0) then
    Result := ExcludeTrailingPathDelimiter(Server) + '/m/' + IntToStr(Id);
end;

function AttachedTokens(Files: TJSONArray): string;
var
  Item: TJSONEnum;
begin
  Result := '';
  for Item in Files do
  begin
    if Result <> '' then
      Result := Result + ',';
    Result := Result + TJSONObject(Item.Value).Get('token', '');
  end;
end;

function AttachedHtml(Files: TJSONArray): string;
var
  I: integer;
  F: TJSONObject;
begin
  Result := '';
  for I := 0 to Files.Count - 1 do
  begin
    F := TJSONObject(Files[I]);
    if Result <> '' then
      Result := Result + ' &nbsp;&middot;&nbsp; ';
    Result := Result + '<b>' + HtmlEscape(F.Get('name', 'file')) + '</b> <font color="gray">' + IntToStr(F.Get('size', 0) div 1024 + 1) +
      ' KB</font> <a href="drop:' + IntToStr(I) + '">remove</a>';
  end;
end;

function AttachCaption(Files: TJSONArray): string;
begin
  Result := 'Attach';
  if Files.Count > 0 then
    Result := Result + ' (' + IntToStr(Files.Count) + ')';
end;

function FileExpiry(FileInfo: TJSONObject): string;
var
  D: TDateTime;
begin
  Result := '';
  if FileInfo.Find('once') is TJSONBoolean then
    if FileInfo.Get('once', False) then
      Exit('deletes after one download');
  if TryISO8601ToDate(JsonText(FileInfo, 'expires', 40), D, True) then
    Result := 'until ' + FormatDateTime('mmm d, yyyy h:nn AM/PM', UniversalTimeToLocal(D));
end;

function ExpiryValue(Index: integer): string;
const
  Values: array[0..4] of string = ('', 'hour', 'day', 'week', 'once');
begin
  Result := '';
  if Index in [0..4] then
    Result := Values[Index];
end;

function DmReplyText(const Text: string): string;
var
  S: string;
  I, Last, Start, Stop: integer;
begin
  S := Text;
  Start := Pos('```', S);
  while Start > 0 do
  begin
    Stop := PosEx('```', S, Start + 3);
    if Stop = 0 then
      Stop := Length(S) + 1
    else
      Inc(Stop, 3);
    Delete(S, Start, Stop - Start);
    Insert(' ', S, Start);
    Start := Pos('```', S);
  end;
  Result := '';
  SetLength(Result, Length(S));
  Last := 0;
  for I := 1 to Length(S) do
    if not (S[I] in ['*', '_', '~', '`']) then
    begin
      if S[I] <= ' ' then
      begin
        if (Last = 0) or (Result[Last] = ' ') then
          Continue;
        Inc(Last);
        Result[Last] := ' ';
      end
      else
      begin
        Inc(Last);
        Result[Last] := S[I];
      end;
    end;
  SetLength(Result, Last);
  Result := UTF8Copy(Trim(Result), 1, 140);
  if Result = '' then
    Result := 'code';
end;

function CheckedDmReply(Data: TJSONData): TJSONObject;
var
  Obj: TJSONObject;
  Id: integer;
begin
  Result := nil;
  if not (Data is TJSONObject) then
    Exit;
  Obj := TJSONObject(Data);
  if not (Obj.Find('id') is TJSONNumber) or not TryStrToInt(Obj.Find('id').AsJSON, Id) or (Id <= 0) then
    Exit;
  // a channel's answered message deleted since: nothing of it is left to show
  if (Obj.Find('gone') is TJSONBoolean) and Obj.Booleans['gone'] then
    Exit(TJSONObject.Create(['id', Id, 'gone', True]));
  if not (Obj.Find('from') is TJSONString) or not (Obj.Find('text') is TJSONString) then
    Exit;
  Result := TJSONObject.Create(['id', Id, 'from', UTF8Copy(Obj.Get('from', ''), 1, 60), 'text', UTF8Copy(Obj.Get('text', ''), 1, 140)]);
end;

function ReplyWords(Reply: TJSONObject): string;
var
  From: string;
begin
  From := Reply.Get('from', '') + ' ';
  Result := Reply.Get('text', '');
  if Result.StartsWith(From) then
    Delete(Result, 1, Length(From));
end;

function DmActionText(const From, Text: string): string;
begin
  if Text.StartsWith('/me ', True) and (Trim(Copy(Text, 5, MaxInt)) <> '') and (Pos(#10, Text) = 0) then
    Result := '*' + From + ' ' + Trim(Copy(Text, 5, MaxInt)) + '*'
  else
    Result := Text;
end;

function DmReplyHtml(Data: TJSONData): string;
var
  Reply: TJSONObject;
begin
  Result := '';
  Reply := CheckedDmReply(Data);
  if Reply = nil then
    Exit;
  try
    if Reply.Get('gone', False) then
      Result := '<blockquote class="preview"><i>a deleted message</i></blockquote>'
    else
      Result := '<blockquote class="preview"><a href="dmquote:' + IntToStr(Reply.Get('id', 0)) + '"><b>' + HtmlEscape(Reply.Get('from', '')) +
        '</b> ' + HtmlEscape(ReplyWords(Reply)) + '</a></blockquote>';
  finally
    Reply.Free;
  end;
end;

function HtmlEscape(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

function WebAddress(const S: string): boolean;
var
  Lower: string;
  C: char;
begin
  Result := False;
  if Length(S) > 4096 then
    Exit;
  for C in S do
    if C <= ' ' then
      Exit;
  Lower := LowerCase(S);
  Result := (Lower.StartsWith('http://') and (Length(S) > 7)) or (Lower.StartsWith('https://') and (Length(S) > 8));
end;

function ServerAddress(const Typed: string; out Url, Why: string): boolean;
var
  Host: string;
  P, Second: integer;
  Numbers: boolean;
  C: char;
begin
  Result := False;
  Why := '';
  Url := Trim(Typed);
  while (Url <> '') and (Url[Length(Url)] = '/') do
    SetLength(Url, Length(Url) - 1);
  if Url = '' then
  begin
    Why := 'Enter the server''s address.';
    Exit;
  end;
  if Pos('://', Url) = 0 then
    Url := 'https://' + Url;
  if not WebAddress(Url) then
  begin
    Why := 'That is not a server''s address.';
    Exit;
  end;
  if LowerCase(Copy(Url, 1, 8)) = 'https://' then
    Exit(True);
  // http: the host, without a port
  Host := LowerCase(Copy(Url, 8, MaxInt));
  P := Pos('/', Host);
  if P > 0 then
    SetLength(Host, P - 1);
  if (Host <> '') and (Host[1] = '[') then
    Host := Copy(Host, 2, Pos(']', Host) - 2)
  else
  begin
    P := Pos(':', Host);
    if P > 0 then
      SetLength(Host, P - 1);
  end;
  // a number address is judged by its numbers, a name by its ending
  Numbers := Host <> '';
  for C in Host do
    if not (C in ['0'..'9', '.']) then
      Numbers := False;
  Second := 0;
  if Numbers and Host.StartsWith('172.') then
    Second := StrToIntDef(Copy(Host, 5, Pos('.', Copy(Host, 5, MaxInt)) - 1), 0);
  if Numbers then
    Result := Host.StartsWith('127.') or Host.StartsWith('10.') or Host.StartsWith('192.168.') or ((Second >= 16) and (Second <= 31))
  else
    Result := (Host = 'localhost') or (Host = '::1') or Host.EndsWith('.local') or Host.EndsWith('.lan') or ((Host <> '') and (Pos('.', Host) = 0) and (Pos(':', Host) = 0));
  if not Result then
    Why := 'That address starts with http://, which would send your sign-in unprotected. Use https://.';
end;

function PreviewOf(Msg: TJSONObject): TJSONObject;
begin
  Result := nil;
  if (Msg = nil) or Msg.Get('deleted', False) or Msg.Get('ignored', False) then
    Exit;
  if Msg.Find('preview') is TJSONObject then
  begin
    Result := Msg.Objects['preview'];
    if not (Result.Find('url') is TJSONString) or not WebAddress(Result.Get('url', '')) then
      Result := nil;
  end;
end;

function PreviewHtml(Msg: TJSONObject; Expanded, Focused: boolean): string;
var
  Preview: TJSONObject;
  Title, Site, Image, Cls, Mark: string;
begin
  Result := '';
  Preview := PreviewOf(Msg);
  if Preview = nil then
    Exit;
  Title := JsonText(Preview, 'title', 512);
  if Title = '' then
    Title := JsonText(Preview, 'url', 4096);
  Site := JsonText(Preview, 'site', 255);
  if Site <> '' then
    Title := Title + ' · ' + Site;
  Cls := 'preview';
  if Focused then
    Cls := Cls + ' preview-focus';
  Mark := '&#9656; ';
  if Expanded then
    Mark := '&#9662; ';
  Result := '<blockquote class="' + Cls + '"><p class="preview-title"><a href="preview:' + IntToStr(Msg.Get('id', 0)) + '">' + Mark + HtmlEscape(Title) + '</a></p>';
  if Expanded then
  begin
    if JsonText(Preview, 'description', 4096) <> '' then
      Result := Result + '<p>' + HtmlEscape(JsonText(Preview, 'description', 4096)) + '</p>';
    Image := JsonText(Preview, 'image', 4096);
    if WebAddress(Image) or Image.StartsWith('/f/') then
      Result := Result + '<p><img class="shot" src="preview-image:' + HtmlEscape(Image) + '" alt="Preview image"></p>';
    Result := Result + '<p><a href="' + HtmlEscape(JsonText(Preview, 'url', 4096)) + '">Open link</a></p>';
  end;
  Result := Result + '</blockquote>';
end;

constructor TPreviewState.Create;
begin
  inherited Create;
  Opened := TStringList.Create;
end;

destructor TPreviewState.Destroy;
begin
  Opened.Free;
  inherited Destroy;
end;

procedure TPreviewState.Clear;
begin
  Opened.Clear;
  FocusId := 0;
end;

function TPreviewState.IsOpen(Msg: TJSONObject): boolean;
var
  Preview: TJSONObject;
begin
  Preview := PreviewOf(Msg);
  Result := (Preview <> nil) and (Opened.Values[IntToStr(Msg.Get('id', 0))] = JsonText(Preview, 'url', 4096));
end;

function TPreviewState.Toggle(Msg: TJSONObject): boolean;
var
  Preview: TJSONObject;
  Key: string;
  Index: integer;
begin
  Result := False;
  Preview := PreviewOf(Msg);
  if Preview = nil then
    Exit;
  Key := IntToStr(Msg.Get('id', 0));
  Index := Opened.IndexOfName(Key);
  if IsOpen(Msg) then
    Opened.Delete(Index)
  else
  begin
    Opened.Values[Key] := JsonText(Preview, 'url', 4096);
    Result := True;
  end;
end;

function TPreviewState.Step(List: TJSONArray; Backward: boolean): integer;
var
  I, Start, Direction, N: integer;
  Msg: TJSONObject;
begin
  Result := -1;
  Start := -1;
  Direction := 1;
  if Backward then
  begin
    Start := List.Count;
    Direction := -1;
  end;
  for I := 0 to List.Count - 1 do
    if TJSONObject(List[I]).Get('id', 0) = FocusId then
      Start := I;
  for N := 1 to List.Count do
  begin
    I := (Start + N * Direction + List.Count) mod List.Count;
    Msg := TJSONObject(List[I]);
    if PreviewOf(Msg) <> nil then
    begin
      FocusId := Msg.Get('id', 0);
      Exit(I);
    end;
  end;
  FocusId := 0;
end;

function MemberStatus(Member: TJSONObject; Here: boolean): TMemberStatus;
begin
  Result := msUnknown;
  if Member = nil then
    Exit;
  if not Here and not (Member.Find('online') is TJSONBoolean) then
    Exit;
  Result := msOffline;
  if Here or Member.Get('online', False) then
  begin
    Result := msOnline;
    if Member.Get('away', '') <> '' then
      Result := msAway;
  end;
end;

function StatusDot(Status: TMemberStatus; Dark: boolean): string;
const
  Colors: array[boolean, msOffline..msAway] of string =
    (('#707070', '#187a35', '#9b7100'), ('#aaaaaa', '#63d787', '#f2cf59'));
begin
  Result := '';
  if Status <> msUnknown then
    Result := '<font color="' + Colors[Dark, Status] + '">&#9679;</font>&nbsp;';
end;

end.
