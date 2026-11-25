unit WikiEmojiSite;

{ Wiki emoji storage, SVG pictures and administration. Missing defaults from
  static/emoji/manifest.json are added at start; admin edits stay. Check SVG
  for scripts, events and external references. Picture changes mark affected
  pages for rendering; versioned URLs refresh caches. See docs/API.md. }

{$mode objfpc}{$H+}

interface

{ The set from the table, into WikiEmoji: at start and after a change. }
procedure LoadEmojiSet;
{ Why an SVG may not be an emoji's picture, or ''. }
function EmojiSvgProblem(const Svg: string): string;

implementation

uses
  Classes, SysUtils, StrUtils, fpjson, jsonparser, sqldb, httpdefs, httproute,
  SiteDb, SiteUsers, SiteRoles, SiteGuard, WebPages, SiteParts, WikiEmoji;

const
  MAX_SVG = 64 * 1024;

function Words(const S: string): TStringArray;
var
  Parts: TStringArray;
  W: string;
begin
  Result := nil;
  Parts := SplitString(LowerCase(StringReplace(StringReplace(S, ',', ' ', [rfReplaceAll]), ':', ' ', [rfReplaceAll])), ' ');
  for W in Parts do
    if W <> '' then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := W;
    end;
end;

function DefaultFolder: string;
begin
  Result := FilesRoot + 'static' + DirectorySeparator + 'emoji' + DirectorySeparator;
end;

{ manifest.json's emoji that the table does not have yet, added at the end. }
procedure SeedFromManifest;
var
  Data: TJSONData;
  Item: TJSONObject;
  F: TStringList;
  I, Sort: integer;
  Chars: string;
begin
  if not FileExists(DefaultFolder + 'manifest.json') then
    Exit;
  F := TStringList.Create;
  try
    F.LoadFromFile(DefaultFolder + 'manifest.json');
    Data := GetJSON(F.Text);
  finally
    F.Free;
  end;
  try
    if not (Data is TJSONArray) then
      Exit;
    Sort := IntValue('SELECT COALESCE(MAX(sort), 0) FROM wiki_emoji', []);
    for I := 0 to TJSONArray(Data).Count - 1 do
    begin
      if not (TJSONArray(Data).Items[I] is TJSONObject) then
        Continue;
      Item := TJSONObject(TJSONArray(Data).Items[I]);
      Chars := Item.Get('emoji', '');
      if (Chars = '') or (IntValue('SELECT COUNT(*) FROM wiki_emoji WHERE chars = :c', [Chars]) > 0) then
        Continue;
      Inc(Sort);
      Exec('INSERT INTO wiki_emoji (chars, name, grp, keywords, file, drawn, version, sort) VALUES (:c, :n, :g, :k, :f, 1, 1, :s)',
        [Chars, Item.Get('name', ''), Item.Get('group', ''), Item.Arrays['keywords'].AsJSON, Item.Get('file', ''), Sort]);
    end;
  finally
    Data.Free;
  end;
end;

procedure LoadEmojiSet;
var
  List: TEmojiList;
  Keys: TJSONData;
  K: integer;
  N: integer;
begin
  List := nil;
  with Query('SELECT chars, name, grp, keywords, file, drawn, version, CASE WHEN svg IS NULL THEN 0 ELSE 1 END FROM wiki_emoji ORDER BY sort, id', []) do
  try
    while not EOF do
    begin
      N := Length(List);
      SetLength(List, N + 1);
      List[N].Chars := Fields[0].AsString;
      List[N].Name := Fields[1].AsString;
      List[N].Group := Fields[2].AsString;
      List[N].Keywords := nil;
      Keys := nil;
      try
        Keys := GetJSON(Fields[3].AsString);
      except
        Keys := nil;
      end;
      if Keys is TJSONArray then
        for K := 0 to TJSONArray(Keys).Count - 1 do
          if ValidEmojiKeyword(TJSONArray(Keys).Strings[K]) then
          begin
            SetLength(List[N].Keywords, Length(List[N].Keywords) + 1);
            List[N].Keywords[High(List[N].Keywords)] := TJSONArray(Keys).Strings[K];
          end;
      Keys.Free;
      // drawn, and there is a picture: the admin's own or the default file
      if (Fields[5].AsInteger <> 0) and ((Fields[7].AsInteger <> 0) or ((Fields[4].AsString <> '') and FileExists(DefaultFolder + Fields[4].AsString))) then
        List[N].Src := '/wiki-emoji/' + EmojiCodeName(List[N].Chars) + '.svg?v=' + Fields[6].AsString
      else
        List[N].Src := '';
      Next;
    end;
  finally
    Free;
  end;
  SetEmojiSet(List);
end;

procedure StartEmoji;
begin
  SeedFromManifest;
  LoadEmojiSet;
end;

function EmojiSvgProblem(const Svg: string): string;
var
  L, Head: string;
  P: integer;
begin
  Result := '';
  if Length(Svg) > MAX_SVG then
    Exit('The picture is too big: 64 KB at most.');
  L := LowerCase(Svg);
  Head := TrimLeft(L);
  if StartsStr('<?xml', Head) then
  begin
    P := Pos('?>', Head);
    Head := TrimLeft(Copy(Head, P + 2, MaxInt));
  end;
  if not StartsStr('<svg', Head) or (Pos('</svg>', L) = 0) then
    Exit('The picture must be an SVG file.');
  if (Pos('<script', L) > 0) or (Pos('<foreignobject', L) > 0) or (Pos('<!entity', L) > 0) or (Pos('<!doctype', L) > 0) or
    (Pos('javascript:', L) > 0) or (Pos('<iframe', L) > 0) or (Pos('<image', L) > 0) or (Pos('@import', L) > 0) or (Pos('url(http', L) > 0) or
    (Pos('url(//', L) > 0) or (Pos('data:', L) > 0) then
    Exit('The picture may not have scripts, embedded files or outside references.');
  // event attributes: on...= anywhere in a tag
  P := 1;
  repeat
    P := PosEx(' on', L, P);
    if P = 0 then
      Break;
    Inc(P, 3);
    while (P <= Length(L)) and (L[P] in ['a'..'z']) do
      Inc(P);
    while (P <= Length(L)) and (L[P] in [' ', #9, #10, #13]) do
      Inc(P);
    if (P <= Length(L)) and (L[P] = '=') then
      Exit('The picture may not have scripts, embedded files or outside references.');
  until False;
  // links: only to a part of the same picture
  P := 1;
  repeat
    P := PosEx('href', L, P);
    if P = 0 then
      Break;
    Inc(P, 4);
    while (P <= Length(L)) and (L[P] in [' ', #9, #10, #13, '=']) do
      Inc(P);
    if (P <= Length(L)) and (L[P] in ['"', '''']) then
      Inc(P);
    if (P <= Length(L)) and (L[P] <> '#') then
      Exit('The picture may not have scripts, embedded files or outside references.');
  until False;
end;

{ GET /api/wiki/emoji }
procedure ApiEmoji(ARequest: TRequest; AResponse: TResponse);
var
  List: TEmojiList;
  Answer: TJSONArray;
  Item: TJSONObject;
  Keys: TJSONArray;
  I, K: integer;
begin
  List := EmojiSet;
  Answer := TJSONArray.Create;
  for I := 0 to High(List) do
  begin
    Keys := TJSONArray.Create;
    for K := 0 to High(List[I].Keywords) do
      Keys.Add(List[I].Keywords[K]);
    Item := TJSONObject.Create(['emoji', List[I].Chars, 'name', List[I].Name, 'group', List[I].Group, 'src', List[I].Src]);
    Item.Add('keywords', Keys);
    Answer.Add(Item);
  end;
  AResponse.SetCustomHeader('Cache-Control', 'public, max-age=300');
  SendJSON(AResponse, Answer);
end;

{ GET /wiki-emoji/<code points>.svg }
procedure ShowEmojiPicture(ARequest: TRequest; AResponse: TResponse);
var
  Wanted, Svg, PictureFile: string;
  Hit: boolean;
  F: TStringList;
begin
  CheckConnection;
  Wanted := ARequest.RouteParams['file'];
  if not EndsStr('.svg', Wanted) then
  begin
    SendText(AResponse, 404, 'Not found');
    Exit;
  end;
  Wanted := Copy(Wanted, 1, Length(Wanted) - 4);
  Svg := '';
  PictureFile := '';
  Hit := False;
  with Query('SELECT chars, svg, file FROM wiki_emoji', []) do
  try
    while not EOF do
    begin
      if EmojiCodeName(Fields[0].AsString) = Wanted then
      begin
        Hit := True;
        if not Fields[1].IsNull then
          Svg := Fields[1].AsString;
        PictureFile := Fields[2].AsString;
        Break;
      end;
      Next;
    end;
  finally
    Free;
  end;
  if Hit and (Svg = '') and (PictureFile <> '') and (Pos('/', PictureFile) = 0) and (Pos('\', PictureFile) = 0) and (Pos('..', PictureFile) = 0) and
    FileExists(DefaultFolder + PictureFile) then
  begin
    F := TStringList.Create;
    try
      F.LoadFromFile(DefaultFolder + PictureFile);
      Svg := F.Text;
    finally
      F.Free;
    end;
  end;
  if Svg = '' then
  begin
    SendText(AResponse, 404, 'Not found');
    Exit;
  end;
  AResponse.Code := 200;
  AResponse.ContentType := 'image/svg+xml';
  // opened on its own, a picture still runs nothing
  AResponse.SetCustomHeader('Content-Security-Policy', 'default-src ''none''; style-src ''unsafe-inline''; sandbox');
  AResponse.SetCustomHeader('X-Content-Type-Options', 'nosniff');
  // the address changes with the picture
  AResponse.SetCustomHeader('Cache-Control', 'public, max-age=2592000, immutable');
  AResponse.Content := Svg;
  AResponse.SendContent;
end;

function KeywordsTaken(const Keys: TStringArray; const Chars: string): string;
var
  List: TEmojiList;
  I, K, J: integer;
begin
  Result := '';
  List := EmojiSet;
  for I := 0 to High(List) do
    if List[I].Chars <> Chars then
      for K := 0 to High(List[I].Keywords) do
        for J := 0 to High(Keys) do
          if List[I].Keywords[K] = Keys[J] then
            Exit(Keys[J] + ' (' + List[I].Name + ')');
end;

{ POST /api/wiki/emoji/save }
procedure SaveEmoji(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Chars, Name, Svg, Problem, Taken, Pattern: string;
  Keys: TStringArray;
  KeyJSON: TJSONArray;
  K, Drawn: integer;
  Adding, Exists: boolean;
begin
  CheckConnection;
  if FromAnotherSite(ARequest) then
  begin
    SendText(AResponse, 403, 'Send this form from this site.');
    Exit;
  end;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  if not Can(Me, 'wiki-emoji') then
  begin
    SendText(AResponse, 403, 'Only admins may change the emoji.');
    Exit;
  end;
  Chars := Trim(ARequest.ContentFields.Values['chars']);
  Adding := ARequest.ContentFields.Values['add'] = '1';
  if (Chars = '') or (Length(Chars) > 32) or (EmojiCodeName(Chars) = '') or (Chars[1] < #$80) then
  begin
    SendText(AResponse, 400, 'Give one emoji.');
    Exit;
  end;
  Exists := IntValue('SELECT COUNT(*) FROM wiki_emoji WHERE chars = :c', [Chars]) > 0;
  if Adding = Exists then
  begin
    if Exists then
      SendText(AResponse, 409, 'That emoji is in the set already.')
    else
      SendText(AResponse, 404, 'That emoji is not in the set.');
    Exit;
  end;
  Keys := Words(ARequest.ContentFields.Values['keywords']);
  for K := 0 to High(Keys) do
    if not ValidEmojiKeyword(Keys[K]) then
    begin
      SendText(AResponse, 400, 'A keyword is a to z, 0 to 9, + - and _, 30 at most: ' + Keys[K]);
      Exit;
    end;
  Taken := KeywordsTaken(Keys, Chars);
  if Taken <> '' then
  begin
    SendText(AResponse, 409, 'Another emoji has that keyword: ' + Taken);
    Exit;
  end;
  Svg := ARequest.ContentFields.Values['svg'];
  if Svg <> '' then
  begin
    Problem := EmojiSvgProblem(Svg);
    if Problem <> '' then
    begin
      SendText(AResponse, 400, Problem);
      Exit;
    end;
  end;
  Name := Copy(Trim(ARequest.ContentFields.Values['name']), 1, 60);
  Drawn := Ord(ARequest.ContentFields.Values['drawn'] <> '0');
  KeyJSON := TJSONArray.Create;
  try
    for K := 0 to High(Keys) do
      KeyJSON.Add(Keys[K]);
    if Adding then
      Exec('INSERT INTO wiki_emoji (chars, name, grp, keywords, file, svg, drawn, version, sort) VALUES (:c, :n, ''own'', :k, '''', :s, :d, 1, :o)',
        [Chars, Name, KeyJSON.AsJSON, Svg, Drawn, IntValue('SELECT COALESCE(MAX(sort), 0) + 1 FROM wiki_emoji', [])])
    else
    begin
      Exec('UPDATE wiki_emoji SET name = :n, keywords = :k, drawn = :d WHERE chars = :c', [Name, KeyJSON.AsJSON, Drawn, Chars]);
      if Svg <> '' then
        Exec('UPDATE wiki_emoji SET svg = :s, version = version + 1 WHERE chars = :c', [Svg, Chars])
      else if ARequest.ContentFields.Values['plain'] = '1' then
        Exec('UPDATE wiki_emoji SET svg = NULL, version = version + 1 WHERE chars = :c', [Chars]);
    end;
  finally
    KeyJSON.Free;
  end;
  LoadEmojiSet;
  // the pages that show it are drawn again, with its new address or none
  Pattern := '%' + StringReplace(Chars, #$EF#$B8#$8F, '', [rfReplaceAll]) + '%';
  Exec('UPDATE wiki_pages SET rendered = 0 WHERE body LIKE :p', [Pattern]);
  Log(Me.Name + ' changed the wiki emoji ' + EmojiCodeName(Chars));
  SendJSON(AResponse, TJSONObject.Create(['saved', True]));
end;

initialization
  RegisterTable('CREATE TABLE IF NOT EXISTS wiki_emoji (id INT AUTO_INCREMENT PRIMARY KEY,' +
    ' chars VARCHAR(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL UNIQUE, name VARCHAR(60) NOT NULL DEFAULT '''',' +
    ' grp VARCHAR(20) NOT NULL DEFAULT '''', keywords VARCHAR(500) NOT NULL DEFAULT ''[]'', file VARCHAR(80) NOT NULL DEFAULT '''',' +
    ' svg MEDIUMTEXT NULL, drawn TINYINT NOT NULL DEFAULT 1, version INT NOT NULL DEFAULT 1, sort INT NOT NULL DEFAULT 0)' + ' CHARACTER SET utf8mb4');
  RegisterPermission('wiki-emoji', 'Change the wiki''s emoji: their pictures and keywords', 'admin');
  RegisterStartup(@StartEmoji);
  RegisterPartPaths('wiki', ['/wiki-emoji', '/api/wiki/emoji']);
  RegisterPartScript('wiki', '/static/wiki-admin.js');
  RegisterBodyLimit('/api/wiki/emoji/save', MAX_SVG * 3 + 8192);
  LimitRoute('wikisave', '/api/wiki/emoji/save', 'POST');
  HTTPRouter.RegisterRoute('/api/wiki/emoji', rmGet, @ApiEmoji);
  HTTPRouter.RegisterRoute('/api/wiki/emoji/save', rmPost, @SaveEmoji);
  HTTPRouter.RegisterRoute('/wiki-emoji/:file', rmGet, @ShowEmojiPicture);
end.
