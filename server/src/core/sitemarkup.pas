unit SiteMarkup;

{ Render Markdown with raw HTML escaped, or rebuild allowed HTML for
  READMEs. fcl-syntax colors code blocks. Caller-approved mentions and room
  names become links and are returned for notification and tagging. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Markdown.Parser;

type
  TExistsFunc = function(const Name: string): boolean;
  TMarkdownParserClass = class of TMarkdownParser;

{ Renders Text.  Members and Rooms receive the names that were linked. }
function RenderText(const Text: string; MemberExists, RoomExists: TExistsFunc; Members, Rooms: TStrings): string;
{ As RenderText, parsed by a parser of the caller's with its options added
  to GitHub's: a unit that knows more syntax than the chat (wiki links). }
function RenderTextWith(const Text: string; MemberExists, RoomExists: TExistsFunc; Members, Rooms: TStrings; ParserClass: TMarkdownParserClass;
  ExtraOptions: TMarkdownOptions): string;
{ Plain Markdown, for text with no mentions (a bio, a card). }
function RenderPlain(const Text: string): string;
{ Markdown written somewhere else, such as a project's README: as RenderPlain,
  and pictures may also come from these hosts, loaded without telling them from where.
  Its raw HTML is kept as GitHub keeps it: tables, quotes, details and the
  like, built again from a short list of tags and attributes. }
const
  // goes up when RenderReadme renders differently, so stored HTML is made again
  ReadmeRenderVersion = 4;

function RenderReadme(const Text: string; const ImageHosts: array of string): string;
{ A folder of the site's own pictures a message or page may show; Prefix
  starts the address. }
procedure RegisterPictureFolder(const Prefix: string);
{ HTML made elsewhere by a trusted tool, such as the reference's importer,
  made safe all the same: the README's tags and attributes, plus class names,
  data-lang and links within this site; every tag closed. }
function CleanDocHtml(const Html: string): string;
function HtmlText(const S: string): string;
{ Markdown as one short plain line: code as a sign in braces, pictures left
  out, links as their words and addresses as their site's name, at most
  Limit bytes and never part of a character. }
function PlainLine(const Body: string; Limit: integer = 160): string;

implementation

uses
  StrUtils, RegExpr, SiteDb, Markdown.Elements, Markdown.HtmlRender, Markdown.Processors,
  Markdown.Render, Markdown.Utils, syntax.highlighter, syntax.htmlrender, syntax.pascal,
  syntax.javascript, syntax.css, syntax.html, syntax.sql, syntax.json, syntax.bash,
  syntax.ini, syntax.go, SyntaxLfm, SyntaxLangs, SyntaxBarye, SyntaxMarkdown, SyntaxRst;

function HtmlText(const S: string): string;
begin
  Result := HtmlEscape(S);
end;

{ Code blocks }

function LanguageName(const Lang: string): string;
begin
  Result := LowerCase(Lang);
  if Result = '' then
    Result := Setting('code_language', 'pascal')
  else if AnsiMatchText(Result, ['pas', 'pp', 'lpr', 'dpr', 'fpc', 'lazarus', 'freepascal', 'delphi', 'objectpascal']) then
    Result := 'pascal'
  else if AnsiMatchText(Result, ['sh', 'shell', 'console', 'zsh']) then
    Result := 'bash'
  else if AnsiMatchText(Result, ['js', 'jsx', 'mjs']) then
    Result := 'javascript'
  else if AnsiMatchText(Result, ['golang']) then
    Result := 'go'
  else if AnsiMatchText(Result, ['md', 'mkd', 'mdown']) then
    Result := 'markdown'
  else if AnsiMatchText(Result, ['restructuredtext', 'rest']) then
    Result := 'rst';
end;

{ fcl-syntax's HTML highlighter (FPC trunk, November 2026) never moves past
  a character inside a tag that is not a name, =, /, a quote or a space:
  <?xml, xml:lang="en" or width=1.5 and it loops forever.  Such code is
  shown plain until that is fixed upstream. }
function HtmlHighlighterCopes(const Code: string): boolean;
var
  P: integer;
  InTag: boolean;
  Quote: char;
begin
  Result := True;
  InTag := False;
  Quote := #0;
  for P := 1 to Length(Code) do
    if Quote <> #0 then
    begin
      if Code[P] = Quote then
        Quote := #0;
    end
    else if not InTag then
      InTag := Code[P] = '<'
    else if Code[P] in ['"', ''''] then
      Quote := Code[P]
    else if Code[P] = '>' then
      InTag := False
    else if (Code[P] = '!') and (Code[P - 1] = '<') then
      // a comment or a doctype, which it reads on its own
      InTag := False
    else if not (Code[P] in ['a'..'z', 'A'..'Z', '0'..'9', '_', '-', '=', '/', ' ', #9, #10, #13]) then
      Exit(False);
end;

function Highlight(const Code, Lang: string): string;
var
  HighlighterClass: TSyntaxHighlighterClass;
  Highlighter: TSyntaxHighlighter;
  Renderer: THtmlSyntaxRenderer;
begin
  Result := HtmlEscape(Code);
  if ((Lang = 'html') or (Lang = 'htm')) and not HtmlHighlighterCopes(Code) then
    Exit;
  HighlighterClass := TSyntaxHighlighterRegistry.Instance.FindSyntaxHighlighterClass(Lang);
  if HighlighterClass = nil then
    Exit;
  Highlighter := HighlighterClass.Create;
  Renderer := THtmlSyntaxRenderer.Create;
  try
    try
      Renderer.Options := [hroNoDefaultSpan];
      Result := '';
      Renderer.RenderTokensToString(Highlighter.Execute(Code), Result);
    except
      on E: Exception do
        Result := HtmlEscape(Code);
    end;
  finally
    Renderer.Free;
    Highlighter.Free;
  end;
end;

{ A code block as the chat shows it: a bar with its language and a copy
  button over the colored code }
function CodeBox(const Code, Lang: string): string;
begin
  Result := '<div class="code"><div class="codebar"><span>' + HtmlEscape(Lang) + '</span><button type="button" class="copy">Copy</button></div><pre><code>' +
    Highlight(TrimRight(Code), Lang) + '</code></pre></div>';
end;

threadvar
  { set while a chat message renders: its markdown blocks show as
    documents.  The wiki, a README or a bio show them as source, as there
    they are nearly always examples of how to write it. }
  ShowDocs: boolean;

{ A markdown block shown as the document it describes, its source a click
  away.  Blocks inside it show as source. }
function DocBox(const Code, Lang: string): string;
var
  Doc: string;
begin
  ShowDocs := False;
  try
    Doc := RenderPlain(Code);
  finally
    ShowDocs := True;
  end;
  Result := '<div class="code doc"><div class="codebar"><span>' + HtmlEscape(Lang) +
    '</span><button type="button" class="flip">Source</button><button type="button" class="copy">Copy</button></div><div class="docview">' +
    Doc + '</div><pre><code>' + Highlight(TrimRight(Code), Lang) + '</code></pre></div>';
end;

type
  TCodeBlockRenderer = class(THTMLMarkdownCodeBlockRenderer)
  protected
    procedure DoRender(aElement: TMarkdownBlock); override;
  end;

procedure TCodeBlockRenderer.DoRender(aElement: TMarkdownBlock);
var
  Node: TMarkdownCodeBlock absolute aElement;
  Block: TMarkdownBlock;
  Code, Lang: string;
begin
  Code := '';
  for Block in Node.Blocks do
    if Block is TMarkdownTextBlock then
      Code := Code + TMarkdownTextBlock(Block).Text + #10;
  Lang := LanguageName(Node.Lang);
  if ShowDocs and (Lang = 'markdown') then
    Append(DocBox(Code, Lang))
  else
    Append(CodeBox(Code, Lang));
  AppendNl;
end;

{ Links }

type
  TLinkGuard = class
    procedure ResolveLink(aRenderer: TMarkdownRenderer; var aHref, aText: string; out aHandled: boolean);
  end;

procedure TLinkGuard.ResolveLink(aRenderer: TMarkdownRenderer; var aHref, aText: string; out aHandled: boolean);
begin
  aHandled := False;
  if not (StartsText('https://', aHref) or StartsText('http://', aHref) or StartsText('mailto:', aHref) or (aHref.StartsWith('/') and not aHref.StartsWith('//'))) then
    aHref := '#';
end;

var
  PictureFolders: array of string;

procedure RegisterPictureFolder(const Prefix: string);
begin
  SetLength(PictureFolders, Length(PictureFolders) + 1);
  PictureFolders[High(PictureFolders)] := Prefix;
end;

{ An address a browser would not rewrite into another path: no .. part,
  written out or encoded, and no backslash. }
function PlainPath(const Src: string): boolean;
begin
  Result := (Pos('/..', Src) = 0) and (Pos('\', Src) = 0) and (Pos('%2e', LowerCase(Src)) = 0) and (Pos('%2f', LowerCase(Src)) = 0) and (Pos('%5c', LowerCase(Src)) = 0);
end;

{ A file of the site as its address is made: /f/, 32 hex digits, one name. }
function OwnFile(const Src: string): boolean;
var
  I: integer;
begin
  Result := Src.StartsWith('/f/') and (Length(Src) > 36) and (Src[36] = '/') and (Pos('/', Src, 37) = 0) and PlainPath(Src);
  for I := 4 to 35 do
    Result := Result and (I <= Length(Src)) and (Src[I] in ['0'..'9', 'a'..'f']);
end;

function OwnPicture(const Src: string): boolean;
var
  Prefix: string;
begin
  Result := False;
  for Prefix in PictureFolders do
    if Src.StartsWith(Prefix) and PlainPath(Src) then
      Exit(True);
end;

{ Images from elsewhere would let any site watch who reads a message, so
  only the site's own files show; others become links. }
function GuardImages(const Html: string; const ImageHosts: array of string): string;
var
  P, Q, R, I: integer;
  Src: string;
  Outside: boolean;
begin
  Result := Html;
  P := Pos('<img src="', Result);
  while P > 0 do
  begin
    Q := PosEx('"', Result, P + 10);
    R := PosEx('>', Result, Q);
    if (Q = 0) or (R = 0) then
      Break;
    Src := Copy(Result, P + 10, Q - P - 10);
    // the site's own files, and the picture folders its units registered
    Outside := False;
    for I := 0 to High(ImageHosts) do
      if StartsText('https://' + ImageHosts[I] + '/', Src) then
        Outside := True;
    if Outside then
    begin
      Insert(' loading="lazy" referrerpolicy="no-referrer"', Result, P + 4);
      P := PosEx('<img src="', Result, R + 44);
    end
    else if OwnFile(Src) or OwnPicture(Src) then
      P := PosEx('<img src="', Result, R)
    else if StartsText('https://', Src) or StartsText('http://', Src) then
    begin
      Delete(Result, P, R - P + 1);
      Insert('<a rel="nofollow ugc" href="' + Src + '">' + Src + '</a>', Result, P);
      P := PosEx('<img src="', Result, P + 1);
    end
    else
    begin
      // any other kind of address (javascript:, data:) is only text, never a link:
      // fcl-md writes a picture without asking OnResolveLink
      Delete(Result, P, R - P + 1);
      Insert(Src, Result, P);
      P := PosEx('<img src="', Result, P + Length(Src));
    end;
  end;
end;

function IsNameChar(C: char): boolean;
begin
  Result := C in ['A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.'];
end;

{ Turns @name and #room into links where they exist and lists them.  Code
  spans and fenced code are left alone. }
function LinkNames(const Body: string; MemberExists, RoomExists: TExistsFunc; Members, Rooms: TStrings): string;
var
  Lines: TStringList;
  I, P, Q: integer;
  Line, Name, Output: string;
  InFence, InCode, Linked: boolean;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := Body;
    InFence := False;
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Lines[I];
      if TrimLeft(Line).StartsWith('```') then
        InFence := not InFence;
      if InFence then
        Continue;
      Output := '';
      InCode := False;
      P := 1;
      while P <= Length(Line) do
      begin
        if Line[P] = '`' then
          InCode := not InCode;
        Linked := False;
        if (Line[P] in ['@', '#']) and not InCode and ((P = 1) or not (IsNameChar(Line[P - 1]) or (Line[P - 1] in ['&', '/', '#', '@']))) then
        begin
          Q := P + 1;
          while (Q <= Length(Line)) and IsNameChar(Line[Q]) do
            Inc(Q);
          // A dot at the end is the sentence's, not the name's.
          while (Q > P + 1) and (Line[Q - 1] = '.') do
            Dec(Q);
          Name := Copy(Line, P + 1, Q - P - 1);
          if (Name <> '') and (Line[P] = '@') and MemberExists(Name) then
          begin
            Output := Output + '[@' + Name + '](/u/' + Name + ')';
            if Members.IndexOf(Name) < 0 then
              Members.Add(Name);
            Linked := True;
          end
          else if (Name <> '') and (Line[P] = '#') and RoomExists(LowerCase(Name)) then
          begin
            Output := Output + '[#' + LowerCase(Name) + '](/p/' + LowerCase(Name) + ')';
            if Rooms.IndexOf(LowerCase(Name)) < 0 then
              Rooms.Add(LowerCase(Name));
            Linked := True;
          end;
          if Linked then
            P := Q;
        end;
        if not Linked then
        begin
          Output := Output + Line[P];
          Inc(P);
        end;
      end;
      Lines[I] := Output;
    end;
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

{ fcl-md (FPC trunk, November 2026) takes "2011.06.28 Snapshots" at the
  start of a line or of a list item for a numbered list starting at 2011,
  though CommonMark wants a space after the 2011. and its bullets list
  check does want one.  Until that is fixed upstream, such a number's dot
  is escaped, which shows as the dot it is.  Code fences are left alone. }
procedure GuardNumberDots(Lines: TStrings);
var
  I, P, Q, Len: integer;
  S, Fence, Trimmed: string;
begin
  Fence := '';
  for I := 0 to Lines.Count - 1 do
  begin
    S := Lines[I];
    Trimmed := TrimLeft(S);
    if Fence <> '' then
    begin
      if Copy(Trimmed, 1, Length(Fence)) = Fence then
        Fence := '';
      Continue;
    end;
    if (Copy(Trimmed, 1, 3) = '```') or (Copy(Trimmed, 1, 3) = '~~~') then
    begin
      Fence := Copy(Trimmed, 1, 3);
      Continue;
    end;
    Len := Length(S);
    P := 1;
    // past the line's quote marks and list markers to where its text starts
    repeat
      while (P <= Len) and (S[P] in [' ', #9]) do
        Inc(P);
      if (P <= Len) and (S[P] = '>') then
      begin
        Inc(P);
        Continue;
      end;
      if (P < Len) and (S[P] in ['-', '*', '+']) and (S[P + 1] in [' ', #9]) then
      begin
        Inc(P, 2);
        Continue;
      end;
      Q := P;
      while (Q <= Len) and (S[Q] in ['0'..'9']) do
        Inc(Q);
      if (Q > P) and (Q - P <= 9) and (Q < Len) and (S[Q] in ['.', ')']) and (S[Q + 1] in [' ', #9]) then
      begin
        P := Q + 2;
        Continue;
      end;
      Break;
    until False;
    Q := P;
    while (Q <= Len) and (S[Q] in ['0'..'9']) do
      Inc(Q);
    if (Q > P) and (Q - P <= 9) and (Q < Len) and (S[Q] in ['.', ')']) and not (S[Q + 1] in [' ', #9]) then
      Lines[I] := Copy(S, 1, Q - 1) + '\' + Copy(S, Q, MaxInt);
  end;
end;

{ Raw HTML in a README }

const
  // what a README may keep, as GitHub does: built again from its name and
  // the attributes below, never copied
  KeptTags = ' a abbr b bdi bdo blockquote br caption center cite code dd del details dfn div dl dt em figcaption figure h1 h2 h3 h4 h5 h6' +
    ' hr i img ins kbd li mark ol p pre q rp rt ruby s samp small span strike strong sub summary sup table tbody td tfoot th thead' + ' time tr tt u ul var wbr ';
  // gone with all they hold
  DroppedWhole = ' script style iframe object embed noscript template textarea select svg math frameset frame applet head title noembed ';
  // a line opening one of these starts a block of HTML, to the next blank line (CommonMark)
  BlockTags = ' address article aside blockquote center details dialog dd div dl dt fieldset figcaption figure footer form h1 h2 h3 h4 h5 h6' +
    ' header hr li main nav ol p picture pre section summary table tbody td tfoot th thead tr ul ';
  EmptyTags = ' br hr img wbr area col embed input link meta source path rect ';
  // the reference's own drawings, its syntax diagrams: these shapes, and the
  // attributes DrawingAttribute allows, nothing more (no links, no styles)
  DrawingTags = ' svg g path rect text ';

function Listed(const List, Name: string): boolean;
begin
  Result := (Name <> '') and (Pos(' ' + Name + ' ', List) > 0);
end;

function IsTagStart(C: char): boolean;
begin
  Result := C in ['A'..'Z', 'a'..'z'];
end;

{ An attribute's value as written: entities read, so a check sees the real text. }
function ReadEntities(const S: string): string;
var
  P, Q, Code: integer;
  Name: string;
begin
  Result := '';
  P := 1;
  while P <= Length(S) do
  begin
    if S[P] = '&' then
    begin
      Q := PosEx(';', S, P);
      if (Q > P) and (Q - P <= 10) then
      begin
        Name := LowerCase(Copy(S, P + 1, Q - P - 1));
        Code := -1;
        if Name = 'amp' then
          Code := 38
        else if Name = 'quot' then
          Code := 34
        else if Name = 'lt' then
          Code := 60
        else if Name = 'gt' then
          Code := 62
        else if (Name = 'apos') or (Name = '#39') then
          Code := 39
        else if (Name <> '') and (Name[1] = '#') then
        begin
          if (Length(Name) > 1) and (Name[2] = 'x') then
            Code := StrToIntDef('$' + Copy(Name, 3, 8), -1)
          else
            Code := StrToIntDef(Copy(Name, 2, 8), -1);
        end;
        if (Code >= 0) and (Code < 128) then
        begin
          Result := Result + Chr(Code);
          P := Q + 1;
          Continue;
        end;
      end;
    end;
    Result := Result + S[P];
    Inc(P);
  end;
end;

{ An address a README's HTML may link or show: whole, on the web. }
function SafeAddress(const Url: string; Mail: boolean): boolean;
var
  C: char;
begin
  for C in Url do
    if C < ' ' then
      Exit(False);
  Result := StartsText('https://', Url) or StartsText('http://', Url) or (Mail and (StartsText('mailto:', Url) or Url.StartsWith('#')));
end;

function SmallNumber(const S: string; Percent: boolean): boolean;
var
  Digits: string;
begin
  Digits := S;
  if Percent and EndsStr('%', Digits) then
    SetLength(Digits, Length(Digits) - 1);
  if EndsText('px', Digits) then
    SetLength(Digits, Length(Digits) - 2);
  Result := (Digits <> '') and (Length(Digits) <= 5) and (StrToIntDef(Digits, -1) >= 0);
end;

{ One kept attribute, or '' }
function KeptAttribute(const Tag, Name, Raw: string; Doc: boolean = False): string;
var
  V: string;
  C: char;
  Plain: boolean;
begin
  V := Trim(ReadEntities(Raw));
  Result := '';
  // the reference's own HTML: its class names, a code block's language, and
  // links to this site's pages (one slash, never two)
  if Doc then
  begin
    // a drawing's geometry: numbers, path letters, spaces and signs only
    if Listed(DrawingTags, Tag) and AnsiMatchStr(Name, ['viewbox', 'width', 'height', 'x', 'y', 'rx', 'ry', 'd', 'text-anchor', 'role']) then
    begin
      for C in V do
        if not (C in ['0'..'9', 'a'..'z', 'A'..'Z', ' ', '.', ',', '-']) then
          Exit('');
      if Length(V) > 20000 then
        Exit('');
      if Name = 'viewbox' then
        Exit(V);
      Exit(V);
    end;
    if Listed(DrawingTags, Tag) and (Name = 'aria-label') and (Length(V) <= 200) then
      Exit(V);
    Plain := (V <> '') and (Length(V) <= 80);
    for C in V do
      if not (C in ['a'..'z', 'A'..'Z', '0'..'9', '-', '_', ' ']) then
        Plain := False;
    if ((Name = 'class') or (Name = 'data-lang')) and Plain then
      Exit(V);
    if (Name = 'href') and (Tag = 'a') and StartsStr('/', V) and not StartsStr('//', V) and (Pos('\', V) = 0) then
    begin
      for C in V do
        if C < ' ' then
          Exit('');
      Exit(V);
    end;
  end;
  if (Name = 'align') and AnsiMatchText(V, ['left', 'center', 'right', 'justify']) and Listed(' p div h1 h2 h3 h4 h5 h6 img td th table ', Tag) then
    Result := LowerCase(V)
  else if (Name = 'valign') and AnsiMatchText(V, ['top', 'middle', 'bottom']) and Listed(' td th tr ', Tag) then
    Result := LowerCase(V)
  else if (Name = 'title') and (Length(V) <= 300) then
    Result := V
  else if (Name = 'href') and (Tag = 'a') and SafeAddress(V, True) then
    Result := V
  else if (Name = 'src') and (Tag = 'img') and SafeAddress(V, False) then
    Result := V
  else if (Name = 'alt') and (Tag = 'img') and (Length(V) <= 300) then
    Result := V
  else if ((Name = 'width') or (Name = 'height')) and Listed(' img td th table ', Tag) and SmallNumber(V, True) then
    Result := V
  else if ((Name = 'colspan') or (Name = 'rowspan')) and Listed(' td th ', Tag) and SmallNumber(V, False) then
    Result := V
  else if (Name = 'start') and (Tag = 'ol') and SmallNumber(V, False) then
    Result := V
  else if (Name = 'type') and (Tag = 'ol') and AnsiMatchStr(V, ['1', 'a', 'A', 'i', 'I']) then
    Result := V
  else if (Name = 'open') and (Tag = 'details') then
    Result := 'open'
  else if (Name = 'datetime') and (Tag = 'time') and (Length(V) <= 40) then
    Result := V;
end;

{ A piece of a README's raw HTML made safe: the kept tags built again with
  their kept attributes, the rest of the tags left out, text escaped. }
function SafeHtml(const Raw: string; Doc: boolean = False): string;
var
  P, Q, Len, Stop: integer;
  Name, AttrName, AttrValue, Built, Src, Value: string;
  Closing: boolean;
  Quote: char;
begin
  Result := '';
  Len := Length(Raw);
  P := 1;
  while P <= Len do
  begin
    if Raw[P] = '<' then
    begin
      if Copy(Raw, P, 4) = '<!--' then
      begin
        Q := PosEx('-->', Raw, P + 4);
        if Q = 0 then
          Break;
        P := Q + 3;
        Continue;
      end;
      Q := P + 1;
      Closing := (Q <= Len) and (Raw[Q] = '/');
      if Closing then
        Inc(Q);
      if (Q <= Len) and IsTagStart(Raw[Q]) then
      begin
        Stop := Q;
        while (Stop <= Len) and (Raw[Stop] in ['A'..'Z', 'a'..'z', '0'..'9', '-']) do
          Inc(Stop);
        Name := LowerCase(Copy(Raw, Q, Stop - Q));
        // the attributes, to the tag's end; a > inside quotes is not its end
        Built := '';
        Src := '';
        Q := Stop;
        while (Q <= Len) and (Raw[Q] <> '>') do
        begin
          if Raw[Q] in [' ', #9, #10, #13, '/'] then
          begin
            Inc(Q);
            Continue;
          end;
          Stop := Q;
          while (Q <= Len) and not (Raw[Q] in [' ', #9, #10, #13, '/', '>', '=']) do
            Inc(Q);
          AttrName := LowerCase(Copy(Raw, Stop, Q - Stop));
          AttrValue := '';
          while (Q <= Len) and (Raw[Q] in [' ', #9, #10, #13]) do
            Inc(Q);
          if (Q <= Len) and (Raw[Q] = '=') then
          begin
            Inc(Q);
            while (Q <= Len) and (Raw[Q] in [' ', #9, #10, #13]) do
              Inc(Q);
            if (Q <= Len) and (Raw[Q] in ['"', '''']) then
            begin
              Quote := Raw[Q];
              Stop := PosEx(Quote, Raw, Q + 1);
              if Stop = 0 then
                Stop := Len + 1;
              AttrValue := Copy(Raw, Q + 1, Stop - Q - 1);
              Q := Stop + 1;
            end
            else
            begin
              Stop := Q;
              while (Q <= Len) and not (Raw[Q] in [' ', #9, #10, #13, '>']) do
                Inc(Q);
              AttrValue := Copy(Raw, Stop, Q - Stop);
            end;
          end;
          if Closing or not (Listed(KeptTags, Name) or Doc and Listed(DrawingTags, Name)) then
            Continue;
          Value := KeptAttribute(Name, AttrName, AttrValue, Doc);
          // the picture's address first, where the guard of pictures looks
          if Value = '' then
          else if AttrName = 'src' then
            Src := ' src="' + HtmlEscape(Value) + '"'
          else if Pos(' ' + AttrName + '=', Built) = 0 then
            Built := Built + ' ' + AttrName + '="' + HtmlEscape(Value) + '"';
        end;
        if Q > Len then
        begin
          // never closed: not a tag, only text
          Result := Result + '&lt;';
          Inc(P);
          Continue;
        end;
        P := Q + 1;
        if Listed(DroppedWhole, Name) and not (Doc and Listed(DrawingTags, Name)) then
        begin
          if not Closing then
          begin
            Q := Pos('</' + Name, LowerCase(Copy(Raw, P, MaxInt)));
            if Q = 0 then
              Break;
            Q := PosEx('>', Raw, P + Q - 1);
            if Q = 0 then
              Break;
            P := Q + 1;
          end;
          Continue;
        end;
        if not (Listed(KeptTags, Name) or Doc and Listed(DrawingTags, Name)) then
          Continue;
        if Name = 'center' then
        begin
          Name := 'div';
          if not Closing then
            Built := ' align="center"';
        end;
        if Closing then
        begin
          if not Listed(EmptyTags, Name) then
            Result := Result + '</' + Name + '>';
        end
        else if Name = 'img' then
        begin
          if Src <> '' then
            Result := Result + '<img' + Src + Built + '>';
        end
        else if (Name = 'a') and Doc and StartsStr(' href="/', Built) then
          // a page of this site, from the reference: followed as any other
          Result := Result + '<a' + Built + '>'
        else if Name = 'a' then
          Result := Result + '<a rel="nofollow ugc"' + Built + '>'
        else if Doc and Listed(' path rect ', Name) then
          // inside a drawing an empty shape closes itself, or the next one goes inside it
          Result := Result + '<' + Name + Built + '/>'
        else
          Result := Result + '<' + Name + Built + '>';
        Continue;
      end;
      Result := Result + '&lt;';
    end
    else if Raw[P] = '>' then
      Result := Result + '&gt;'
    else if Raw[P] = '&' then
    begin
      // an entity stays one; a lone & is written as one
      Q := P + 1;
      if (Q <= Len) and (Raw[Q] = '#') then
        Inc(Q);
      Stop := Q;
      while (Q <= Len) and (Q - Stop < 32) and (Raw[Q] in ['A'..'Z', 'a'..'z', '0'..'9']) do
        Inc(Q);
      if (Q > Stop) and (Q <= Len) and (Raw[Q] = ';') then
        Result := Result + '&'
      else
        Result := Result + '&amp;';
    end
    else
      Result := Result + Raw[P];
    Inc(P);
  end;
end;

{ Every tag closed, in order, and no closing one without its opening: a
  README's HTML must not reach into the page around it. }
function BalanceHtml(const Html: string): string;
var
  Open: TStringList;
  P, Q, Stop, I, Len: integer;
  Name: string;
  Closing: boolean;
  Quote: char;
begin
  Result := '';
  Open := TStringList.Create;
  try
    Len := Length(Html);
    P := 1;
    while P <= Len do
    begin
      Q := PosEx('<', Html, P);
      if Q = 0 then
      begin
        Result := Result + Copy(Html, P, MaxInt);
        Break;
      end;
      Result := Result + Copy(Html, P, Q - P);
      // the tag's end, quotes minded
      Stop := Q + 1;
      Quote := #0;
      while Stop <= Len do
      begin
        if Quote <> #0 then
        begin
          if Html[Stop] = Quote then
            Quote := #0;
        end
        else if Html[Stop] in ['"', ''''] then
          Quote := Html[Stop]
        else if Html[Stop] = '>' then
          Break;
        Inc(Stop);
      end;
      Closing := (Q < Len) and (Html[Q + 1] = '/');
      I := Q + 1 + Ord(Closing);
      Name := '';
      while (I <= Len) and (Html[I] in ['A'..'Z', 'a'..'z', '0'..'9']) do
      begin
        Name := Name + LowerCase(Html[I]);
        Inc(I);
      end;
      if (Name = '') or Listed(EmptyTags, Name) or ((Stop <= Len) and (Html[Stop - 1] = '/')) then
        Result := Result + Copy(Html, Q, Stop - Q + 1)
      else if not Closing then
      begin
        // a heading or paragraph left open ends where a block begins, as
        // a reader would take it (a README's <h2> without its </h2>)
        if Listed(BlockTags, Name) then
          while (Open.Count > 0) and Listed(' p h1 h2 h3 h4 h5 h6 ', Open[Open.Count - 1]) do
          begin
            Result := Result + '</' + Open[Open.Count - 1] + '>';
            Open.Delete(Open.Count - 1);
          end;
        Open.Add(Name);
        Result := Result + Copy(Html, Q, Stop - Q + 1);
      end
      else
      begin
        I := Open.Count - 1;
        while (I >= 0) and (Open[I] <> Name) do
          Dec(I);
        if I >= 0 then
        begin
          while Open.Count - 1 > I do
          begin
            Result := Result + '</' + Open[Open.Count - 1] + '>';
            Open.Delete(Open.Count - 1);
          end;
          Open.Delete(I);
          Result := Result + Copy(Html, Q, Stop - Q + 1);
        end;
      end;
      P := Stop + 1;
    end;
    for I := Open.Count - 1 downto 0 do
      Result := Result + '</' + Open[I] + '>';
  finally
    Open.Free;
  end;
end;

{ The name of the tag a line or text opens at P ('' when it is none), and
  whether it closes one. }
function TagAt(const S: string; P: integer; out Closing: boolean): string;
var
  Q: integer;
begin
  Result := '';
  Closing := False;
  if (P > Length(S)) or (S[P] <> '<') then
    Exit;
  Q := P + 1;
  if (Q <= Length(S)) and (S[Q] = '/') then
  begin
    Closing := True;
    Inc(Q);
  end;
  if (Q > Length(S)) or not IsTagStart(S[Q]) then
    Exit;
  P := Q;
  while (Q <= Length(S)) and (S[Q] in ['A'..'Z', 'a'..'z', '0'..'9', '-']) do
    Inc(Q);
  // <name> <name ...> <name/> or the line's end; <https://...> is a link
  if (Q <= Length(S)) and not (S[Q] in [' ', #9, '>', '/']) then
    Exit;
  Result := LowerCase(Copy(S, P, Q - P));
end;

{ Takes a README's raw HTML out of the Markdown before fcl-md sees it,
  leaving a mark for each piece, and keeps the piece made safe in Pieces.
  A line that opens a block tag starts a block of HTML that runs to the
  next blank line, as CommonMark has it; elsewhere each known tag is one
  piece.  Code, fenced, indented or in backticks, is left as it is. }
procedure LiftHtml(Lines: TStringList; Pieces: TStrings; const RawMark: string);
var
  I, J, P, Q, Ticks, Run: integer;
  S, Trimmed, Fence, Name, Output, Block: string;
  Closing, Blank, InCode: boolean;

  function Mark(const Html: string): string;
  begin
    Pieces.Add(Html);
    Result := RawMark + IntToStr(Pieces.Count - 1) + 'Q';
  end;

begin
  Fence := '';
  Blank := True;
  InCode := False;
  I := 0;
  while I < Lines.Count do
  begin
    S := Lines[I];
    Trimmed := TrimLeft(S);
    if Fence <> '' then
    begin
      if Copy(Trimmed, 1, Length(Fence)) = Fence then
        Fence := '';
      Inc(I);
      Continue;
    end;
    if (Copy(Trimmed, 1, 3) = '```') or (Copy(Trimmed, 1, 3) = '~~~') then
    begin
      Fence := Copy(Trimmed, 1, 3);
      Inc(I);
      Continue;
    end;
    // indented code: four spaces or a tab after a blank line, and on
    InCode := (Trimmed <> '') and (StartsStr('    ', S) or StartsStr(#9, S)) and (Blank or InCode);
    Blank := Trimmed = '';
    if InCode or Blank then
    begin
      Inc(I);
      Continue;
    end;
    Name := TagAt(Trimmed, 1, Closing);
    if (Length(S) - Length(Trimmed) <= 3) and (Listed(BlockTags, Name) or Listed(DroppedWhole, Name) or StartsStr('<!--', Trimmed)) then
    begin
      // the block: to a blank line, or for a comment, <pre> or <script> to its end
      J := I;
      Block := '';
      repeat
        Block := Block + Lines[J] + #10;
        Inc(J);
        if StartsStr('<!--', Trimmed) then
        begin
          if Pos('-->', Block) > 0 then
            Break;
        end
        else if (Name = 'pre') or Listed(DroppedWhole, Name) then
        begin
          if Pos('</' + Name, LowerCase(Block)) > 0 then
            Break;
        end
        else if (J < Lines.Count) and (Trim(Lines[J]) = '') then
          Break;
      until J >= Lines.Count;
      for P := J - 1 downto I do
        Lines.Delete(P);
      Lines.Insert(I, '');
      Lines.Insert(I + 1, Mark(SafeHtml(Block)));
      Lines.Insert(I + 2, '');
      Inc(I, 3);
      Blank := True;
      Continue;
    end;
    // tags inside a line, outside code spans
    Output := '';
    P := 1;
    while P <= Length(S) do
    begin
      if S[P] = '`' then
      begin
        Ticks := P;
        while (P <= Length(S)) and (S[P] = '`') do
          Inc(P);
        Run := P - Ticks;
        Q := PosEx(StringOfChar('`', Run), S, P);
        if Q = 0 then
        begin
          Output := Output + Copy(S, Ticks, Run);
          Continue;
        end;
        Output := Output + Copy(S, Ticks, Q + Run - Ticks);
        P := Q + Run;
        Continue;
      end;
      Name := TagAt(S, P, Closing);
      if StartsStr('<!--', Copy(S, P, 4)) and (PosEx('-->', S, P) > 0) then
      begin
        P := PosEx('-->', S, P) + 3;
        Continue;
      end;
      if Listed(DroppedWhole, Name) and not Closing then
      begin
        // a script and all it holds, to its end on this line (or the line's end)
        Q := Pos('</' + Name, LowerCase(Copy(S, P, MaxInt)));
        if Q > 0 then
          Q := PosEx('>', S, P + Q - 1);
        if Q = 0 then
          Q := Length(S);
        Output := Output + Mark('');
        P := Q + 1;
        Continue;
      end;
      if Listed(KeptTags, Name) or Listed(DroppedWhole, Name) or Listed(BlockTags, Name) or (Name = 'font') or (Name = 'picture') or (Name = 'source') then
      begin
        Q := PosEx('>', S, P);
        if Q > 0 then
        begin
          Output := Output + Mark(SafeHtml(Copy(S, P, Q - P + 1)));
          P := Q + 1;
          Continue;
        end;
      end;
      Output := Output + S[P];
      Inc(P);
    end;
    Lines[I] := Output;
    Inc(I);
  end;
end;

{ The pieces back where their marks are, in one pass over fcl-md's HTML: a
  block's alone in a paragraph, without the paragraph.  A mark inside a tag
  (a link's address or title, a picture's alt) is where text was, so it
  goes, never a piece: a piece there would end the attribute.  Pieces are
  not looked at again for marks. }
function PutBackHtml(const Html, Mark: string; Pieces: TStrings): string;
var
  P, Q, N, Len: integer;
  InTag: boolean;
  Piece: string;
begin
  Result := '';
  Len := Length(Html);
  InTag := False;
  P := 1;
  while P <= Len do
  begin
    if InTag then
    begin
      if Html[P] = '>' then
        InTag := False;
    end
    else if Html[P] = '<' then
    begin
      // <p> and a mark alone in it: the block, without the paragraph
      if Copy(Html, P, 3 + Length(Mark)) = '<p>' + Mark then
      begin
        Q := P + 3 + Length(Mark);
        N := 0;
        while (Q <= Len) and (Html[Q] in ['0'..'9']) and (N < 100000) do
        begin
          N := N * 10 + Ord(Html[Q]) - Ord('0');
          Inc(Q);
        end;
        if (Copy(Html, Q, 5) = 'Q</p>') and (N < Pieces.Count) then
        begin
          Result := Result + Pieces[N];
          P := Q + 5;
          Continue;
        end;
      end;
      InTag := True;
    end
    else if (Html[P] = Mark[1]) and (Copy(Html, P, Length(Mark)) = Mark) then
    begin
      Q := P + Length(Mark);
      N := 0;
      while (Q <= Len) and (Html[Q] in ['0'..'9']) and (N < 100000) do
      begin
        N := N * 10 + Ord(Html[Q]) - Ord('0');
        Inc(Q);
      end;
      if (Q <= Len) and (Html[Q] = 'Q') and (Q > P + Length(Mark)) then
      begin
        Piece := '';
        if N < Pieces.Count then
          Piece := Pieces[N];
        Result := Result + Piece;
        P := Q + 1;
        Continue;
      end;
    end;
    if InTag and (Copy(Html, P, Length(Mark)) = Mark) then
    begin
      // in a tag: the mark and its number go
      Q := P + Length(Mark);
      while (Q <= Len) and (Html[Q] in ['0'..'9']) do
        Inc(Q);
      if (Q <= Len) and (Html[Q] = 'Q') then
      begin
        P := Q + 1;
        Continue;
      end;
    end;
    Result := Result + Html[P];
    Inc(P);
  end;
end;

function CleanDocHtml(const Html: string): string;
begin
  Result := BalanceHtml(SafeHtml(Html, True));
end;

function RenderMarkdown(const Text: string; const ImageHosts: array of string; KeepHtml: boolean; ParserClass: TMarkdownParserClass = nil;
  ExtraOptions: TMarkdownOptions = []): string;
var
  Lines: TStringList;
  Pieces: TStringList;
  RawMark: string;
  Tick: integer;
  Parser: TMarkdownParser;
  Doc: TMarkdownDocument;
  Renderer: TMarkdownHTMLRenderer;
  Guard: TLinkGuard;
begin
  Lines := TStringList.Create;
  if ParserClass = nil then
    ParserClass := TMarkdownParser;
  Parser := ParserClass.Create(nil);
  Renderer := TMarkdownHTMLRenderer.Create(nil);
  Guard := TLinkGuard.Create;
  Pieces := TStringList.Create;
  Doc := nil;
  try
    Lines.Text := Text;
    // letters only, so Markdown leaves it as it is; new for each README
    RawMark := 'Qx';
    for Tick := 1 to 8 do
      RawMark := RawMark + Chr(Ord('a') + Random(26));
    RawMark := RawMark + 'Raw';
    if KeepHtml then
      LiftHtml(Lines, Pieces, RawMark);
    GuardNumberDots(Lines);
    Parser.Options := [mdoGithubFlavoured] + ExtraOptions;
    Doc := Parser.Parse(Lines);
    Renderer.OnResolveLink := @Guard.ResolveLink;
    Result := Renderer.RenderHTML(Doc);
    // Members' raw HTML is escaped, so every link here is one fcl-md wrote;
    // a README's own come back built again, with rel already.
    Result := StringReplace(Result, '<a href="', '<a rel="nofollow ugc" href="', [rfReplaceAll]);
    if KeepHtml then
      Result := BalanceHtml(PutBackHtml(Result, RawMark, Pieces));
    Result := GuardImages(Result, ImageHosts);
  finally
    Pieces.Free;
    Doc.Free;
    Guard.Free;
    Renderer.Free;
    Parser.Free;
    Lines.Free;
  end;
end;

function RenderPlain(const Text: string): string;
begin
  Result := RenderMarkdown(Text, [], False);
end;

function RenderReadme(const Text: string; const ImageHosts: array of string): string;
begin
  Result := RenderMarkdown(Text, ImageHosts, True);
end;

function RenderText(const Text: string; MemberExists, RoomExists: TExistsFunc; Members, Rooms: TStrings): string;
begin
  ShowDocs := True;
  try
    Result := RenderPlain(LinkNames(Text, MemberExists, RoomExists, Members, Rooms));
  finally
    ShowDocs := False;
  end;
end;

function RenderTextWith(const Text: string; MemberExists, RoomExists: TExistsFunc; Members, Rooms: TStrings; ParserClass: TMarkdownParserClass;
  ExtraOptions: TMarkdownOptions): string;
begin
  Result := RenderMarkdown(LinkNames(Text, MemberExists, RoomExists, Members, Rooms), [], False, ParserClass, ExtraOptions);
end;

function PlainLine(const Body: string; Limit: integer): string;
var
  S: string;
  I, Fence: integer;
begin
  S := Body;
  // fenced code becomes a word, so a paste of source does not fill the line
  repeat
    I := Pos('```', S);
    if I = 0 then
      Break;
    Fence := PosEx('```', S, I + 3);
    if Fence = 0 then
      S := Copy(S, 1, I - 1) + ' { … } '
    else
      S := Copy(S, 1, I - 1) + ' { … } ' + Copy(S, Fence + 3, MaxInt);
  until False;
  // pictures out, links as their words, addresses and markup signs out
  S := ReplaceRegExpr('!\[[^\]]*\]\([^)]*\)', S, ' ', False);
  S := ReplaceRegExpr('\[([^\]]*)\]\([^)]*\)', S, '$1', True);
  // the wiki's [[Page Name|words]] and [[Page Name]]
  S := ReplaceRegExpr('\[\[([^\]|]*)\|([^\]]*)\]\]', S, '$2', True);
  S := ReplaceRegExpr('\[\[([^\]]*)\]\]', S, '$1', True);
  // an address as the name of its site
  S := ReplaceRegExpr('https?://(www\.)?([^/\s]+)\S*', S, '$2', True);
  S := ReplaceRegExpr('(^|\s)[#>*_~`]+', S, '$1', True);
  S := ReplaceRegExpr('[*_~`]+(\s|$)', S, '$1', True);
  for I := 1 to Length(S) do
    if S[I] in [#9, #10, #13] then
      S[I] := ' ';
  while Pos('  ', S) > 0 do
    S := StringReplace(S, '  ', ' ', [rfReplaceAll]);
  S := Trim(S);
  if Length(S) > Limit then
  begin
    I := Limit;
    // not in the middle of a character of several bytes
    while (I > 1) and (Ord(S[I + 1]) and $C0 = $80) do
      Dec(I);
    S := TrimRight(Copy(S, 1, I)) + '…';
  end;
  Result := S;
end;

initialization
  TCodeBlockRenderer.RegisterRenderer(TMarkdownHTMLRenderer);
end.
