unit WikiRender;

{ Wiki text to HTML: the chat's Markdown with fcl-md's own [[wiki links]],
  so what is code and what is a link is decided once, by the parser.
  Where a link goes, whether its page exists and a picture's HTML come
  from the caller's TWikiLinks. }

{$mode objfpc}{$H+}

interface

uses Classes, SiteMarkup;

type
  TWikiLinks = class
  public
    { Where [[Target#Fragment]] goes ('' leaves it as text), and whether its page exists. }
    procedure Resolve(const Target, Fragment: string; out Href: string; out Exists: boolean); virtual; abstract;
    { [[File:...]] and [[Image:...]]: Inner is all between the brackets; False leaves it as text. }
    function FileHtml(const Inner: string; out Html: string): boolean; virtual; abstract;
  end;

{ The chat renderer's output with wiki links; Links answers for them. }
function RenderWikiText(const Text: string; Links: TWikiLinks; MemberExists, RoomExists: TExistsFunc; Members, Rooms: TStrings): string;

implementation

uses SysUtils, StrUtils, Markdown.Elements, Markdown.Parser, Markdown.InlineText, Markdown.HtmlRender, Markdown.Utils, WikiEmoji;

threadvar
  CurrentLinks: TWikiLinks;

type
  TWikiInlineProcessor = class(TInlineTextProcessor)
  protected
    function HandleWikiLink: boolean; override;
  end;

  TWikiParser = class(TMarkdownParser)
  protected
    function GetInlineTextProcessorClass: TInlineTextProcessorClass; override;
  end;

  TWikiTextRenderer = class(THTMLMarkdownTextRenderer)
  private
    FInLink: boolean;
  protected
    procedure DoRender(Node: TMarkdownTextNode); override;
    procedure RenderWikiLink(aElement: TMarkdownTextNode); override;
  end;

const
  // stands in for | inside [[...]] while the text is parsed, so a link's
  // bar never splits a table cell; one byte, so code coloring keeps it whole
  LINK_BAR = #1;

{ Each [[...]] closed on its own line gets LINK_BAR for its bars. }
function GuardLinkBars(const Text: string): string;
var
  P, Q, Depth, Done: integer;
begin
  Result := Text;
  if Pos('[[', Text) = 0 then
    Exit;
  Result := '';
  Done := 1;
  P := PosEx('[[', Text, 1);
  while P > 0 do
  begin
    // the ]] that closes it, before the line ends
    Depth := 0;
    Q := P;
    while (Q < Length(Text)) and (Text[Q] <> #10) do
    begin
      if (Text[Q] = '[') and (Text[Q + 1] = '[') then
      begin
        Inc(Depth);
        Inc(Q, 2);
      end
      else if (Text[Q] = ']') and (Text[Q + 1] = ']') then
      begin
        Dec(Depth);
        Inc(Q, 2);
        if Depth = 0 then
          Break;
      end
      else
        Inc(Q);
    end;
    if Depth = 0 then
    begin
      Result := Result + Copy(Text, Done, P - Done) + StringReplace(Copy(Text, P, Q - P), '|', LINK_BAR, [rfReplaceAll]);
      Done := Q;
      P := PosEx('[[', Text, Q);
    end
    else
      P := PosEx('[[', Text, P + 2);
  end;
  Result := Result + Copy(Text, Done, MaxInt);
end;

function IsFileLink(const Text: string; At: integer): boolean;
var
  Name: string;
begin
  Name := Copy(Text, At + 2, 7);
  // [[:File:Name]] links to the picture's own page, as in MediaWiki
  if StartsStr(':', Name) then
    Delete(Name, 1, 1);
  Result := StartsText('File:', Name) or StartsText('Image:', Name);
end;

{ [[Target#Fragment|label]] on one line, no [ or ] in its target; a picture's
  options and caption stay raw, and the caption may hold links of its own,
  so it ends at the ]] that closes its [[. }
function TWikiInlineProcessor.HandleWikiLink: boolean;
var
  Text, Inner, Target, Fragment, Words: string;
  Start, P, Stop, Depth: integer;
  Node: TMarkdownTextNode;
  Location: TPosition;
begin
  Result := False;
  Text := Scanner.Text;
  Start := Scanner.CursorPos;
  if IsFileLink(Text, Start) then
  begin
    Depth := 0;
    P := Start;
    while P < Length(Text) do
    begin
      if Text[P] = #10 then
        Exit;
      if (Text[P] = '[') and (Text[P + 1] = '[') then
      begin
        Inc(Depth);
        Inc(P, 2);
      end
      else if (Text[P] = ']') and (Text[P + 1] = ']') then
      begin
        Dec(Depth);
        Inc(P, 2);
        if Depth = 0 then
          Break;
      end
      else
        Inc(P);
    end;
    if Depth <> 0 then
      Exit;
    Node := Nodes.AddTextNode(Scanner.Location, nkWikiLink, '');
    Node.Attrs['file'] := StringReplace(Copy(Text, Start + 2, P - Start - 4), LINK_BAR, '|', [rfReplaceAll]);
    Scanner.NextChars(P - Start);
    Exit(True);
  end;
  Stop := PosEx(']]', Text, Start + 2);
  if Stop = 0 then
    Exit;
  Inner := StringReplace(Copy(Text, Start + 2, Stop - Start - 2), LINK_BAR, '|', [rfReplaceAll]);
  if Pos(#10, Inner) > 0 then
    Exit;
  Words := '';
  P := Pos('|', Inner);
  if P > 0 then
  begin
    Words := Trim(Copy(Inner, P + 1, MaxInt));
    Inner := Copy(Inner, 1, P - 1);
  end;
  if (Pos('[', Inner) > 0) or (Pos(']', Inner) > 0) then
    Exit;
  Target := Trim(Inner);
  // [[http://address words]], an outside link as MediaWiki writes one
  P := Pos(' ', Target);
  if (Words = '') and (P > 0) and (StartsText('http://', Target) or StartsText('https://', Target)) then
  begin
    Words := Trim(Copy(Target, P + 1, MaxInt));
    Target := Copy(Target, 1, P - 1);
    Inner := Target;
  end;
  Fragment := '';
  P := Pos('#', Target);
  if P > 0 then
  begin
    Fragment := Trim(Copy(Target, P + 1, MaxInt));
    Target := TrimRight(Copy(Target, 1, P - 1));
  end;
  if (Target = '') and (Fragment = '') then
    Exit;
  Location := Scanner.Location;
  Node := Nodes.AddTextNode(Location, nkWikiLink, '');
  Node.Attrs['target'] := Target;
  if Fragment <> '' then
    Node.Attrs['fragment'] := Fragment;
  if Words = '' then
    Words := Trim(Inner);
  ProcessNested(Node, Words, Location);
  Scanner.NextChars(Stop + 2 - Start);
  Result := True;
end;

function TWikiParser.GetInlineTextProcessorClass: TInlineTextProcessorClass;
begin
  Result := TWikiInlineProcessor;
end;

procedure TWikiTextRenderer.DoRender(Node: TMarkdownTextNode);
var
  StyleNode: TMarkdownTextNode;
  I: integer;
begin
  { fcl-md's renderAttrs creates and scans a 196613-slot hash for bare code. }
  // a link's words are never a link of their own
  if FInLink and (Node.Kind in [nkURI, nkEmail]) then
  begin
    Append(HtmlEscape(Node.NodeText));
    Node.Active := False;
  end
  else if (CurrentLinks <> nil) and (Node.Kind = nkCode) and not Node.HasAttrs and not Node.HasChildren then
  begin
    // Let the original renderer open and close styles in exactly its own order.
    StyleNode := TMarkdownTextNode.Create(Default(TPosition), nkText);
    try
      for I := High(Node.StyleList) downto 0 do
        StyleNode.AddStyle(Node.StyleList[I]);
      inherited DoRender(StyleNode);
    finally
      StyleNode.Free;
    end;
    Append('<code>' + HtmlEscape(Node.NodeText) + '</code>');
    Node.Active := False;
  end
  else
    inherited DoRender(Node);
end;

procedure TWikiTextRenderer.RenderWikiLink(aElement: TMarkdownTextNode);
var
  Href, Html, Inner: string;
  Exists: boolean;
begin
  if CurrentLinks = nil then
  begin
    inherited RenderWikiLink(aElement);
    Exit;
  end;
  aElement.Active := False;
  Inner := aElement.Attrs['file'];
  if Inner <> '' then
  begin
    if CurrentLinks.FileHtml(Inner, Html) then
      Append(Html)
    else
      Append(HtmlEscape('[[' + Inner + ']]'));
    Exit;
  end;
  CurrentLinks.Resolve(aElement.Attrs['target'], aElement.Attrs['fragment'], Href, Exists);
  if Href = '' then
    Append('<span>')
  else if Exists then
    Append('<a href="' + HtmlEscape(Href) + '">')
  else
    Append('<a href="' + HtmlEscape(Href) + '" class="missing">');
  if aElement.NodeText <> '' then
    Append(HtmlEscape(aElement.NodeText));
  FInLink := True;
  try
    RenderChildren(aElement);
  finally
    FInLink := False;
  end;
  if Href = '' then
    Append('</span>')
  else
    Append('</a>');
end;

function RenderWikiText(const Text: string; Links: TWikiLinks; MemberExists, RoomExists: TExistsFunc; Members, Rooms: TStrings): string;
var
  Previous: TWikiLinks;
begin
  Previous := CurrentLinks;
  CurrentLinks := Links;
  try
    Result := RenderTextWith(GuardLinkBars(Text), MemberExists, RoomExists, Members, Rooms, TWikiParser, [mdoWikiLinks]);
    Result := StringReplace(Result, LINK_BAR, '|', [rfReplaceAll]);
    // the set's emoji with the site's own pictures
    Result := DrawEmoji(Result);
  finally
    CurrentLinks := Previous;
  end;
end;

initialization
  TWikiTextRenderer.RegisterRenderer(TMarkdownHTMLRenderer);
end.
