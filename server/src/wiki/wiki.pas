unit Wiki;

{ Wiki pages, revisions, search and editing. Names keep their spelling with
  spaces as underscores and an initial capital; lookups ignore case. Page
  operations return problems as text. Writing needs wiki-edit; locked pages
  need wiki-lock. See docs/API.md for requests and docs/CODE-MAP.md for
  units. }

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, httpdefs, SiteMarkup, WikiFiles;

const
  MAIN_PAGE = 'Main_Page';

function SlugOf(const Name: string): string;
function PageExists(const Slug: string): boolean;
function PageUrl(const Slug: string): string;
{ The language a reader of the wiki chose, for words on its pages. }
function ReaderLanguage(ARequest: TRequest): string;

type
  { What follows a link prefix, as [[doc:Path]], made into an address. }
  TWikiPrefix = function(const Rest: string): string;

{ A link prefix of the site's own.  With Make nil the prefix names this
  wiki itself: [[fpc:Page]] is [[Page]]. }
procedure RegisterWikiPrefix(const Prefix: string; Make: TWikiPrefix);
{ [[Page]] and [[Page|words]] in a page's Markdown as links, code left alone. }
{ A page's text as readers see it, with the lookups given: pictures, which
  pages exist, members and rooms.  Targets, when given, receives the name
  of every page it links to, once each, as first written. }
function RenderPageWith(const Body: string; FileLookup: TWikiFileLookup; PageThere, MemberThere, RoomThere: TExistsFunc; Targets: TStrings = nil): string;
{ The id a heading gets in the browser (wiki.js), for [[Page#Section]]. }
function SectionId(const Words: string): string;
{ The text of section Number (its heading and all under it, 1 the first), and
  the page's text with that section replaced; False when there is none. }
function SectionText(const Body: string; Number: integer; out Text: string): boolean;
function ReplaceSection(const Body: string; Number: integer; const Text: string; out Whole: string): boolean;
{ Html with an edit link in each heading, when its headings are the text's own. }
function WithSectionLinks(const Html, Body, Slug, Words: string): string;
function CategoryText(const Body: string; Categories: TStrings): string;
function RedirectTarget(const Body: string): string;
{ Whether Body would send readers of Slug back to Slug: a page's text lost
  to its own redirect, which is how a name differing only in case did it. }
function SelfRedirect(const Slug, Body: string): boolean;
function BaseSlug(const Slug: string; out Language: integer): string;
function SlugLanguage(const Slug: string): string;
function PreferredLanguage(const CookieValue: string): string;
function WikiReturnUrl(const Url: string; const QueryString: string = ''): string;
function DiffLines(const BeforeText, AfterText: string; ARequest: TRequest = nil): string;
{ The longest page in bytes, as the admin set it (Settings, Wiki). }
function PageLimit: integer;
function WikiBodyProblem(const Body: string; ARequest: TRequest = nil): string;
{ A page in the wiki's frame, for another unit's own pages. }
procedure SendWikiPage(ARequest: TRequest; AResponse: TResponse; const Title, Content: string);

type
  { Something another unit adds under a page as it is read: Slug is the page
    shown, in its language. }
  TWikiPagePart = function(ARequest: TRequest; const Slug, Title: string): string;

var
  WikiPagePart: TWikiPagePart = nil;
  { Something another unit says above a page's text, after its languages:
    a line that it needs work, for instance; '' for nothing. }
  WikiPageNotice: TWikiPagePart = nil;

type
  TWikiPageMoved = procedure(const OldSlug, NewSlug: string);

  // The live talk's spot on a wiki page, for the template's {{live}}.
  TWikiLive = function(ARequest: TRequest; const Kind, Key: string): string;

var
  { Set by the unit that shows live talk beside pages; nil for none. }
  WikiLive: TWikiLive = nil;
  { Inside a move's own transaction, for records kept by a page's name
    that must go along or not at all. }
  WikiPageMoving: TWikiPageMoved = nil;
  { More values for the wiki's template, as name, value, name, value. }
  WikiPageValues: function(ARequest: TRequest; const PageSlug: string): TStringArray = nil;
  { A page's record from before this wiki, at its foot and, open, on its
    history; '' for none. }
  WikiEarlierEdits: function(ARequest: TRequest; const Slug: string; Open: boolean): string = nil;
  { Contributors from before this wiki: a SELECT of name, edits, pages,
    first and last (years), counted in with the wiki's own. }
  WikiEarlierContributors: string = '';
  { A condition on users u and wiki_revisions r that keeps only people's
    own edits among the contributors (an import's account is not one). }
  WikiOwnEdits: string = '';
  { The line under the Contributors heading, already escaped; nil for the
    wiki's own. }
  WikiContributorsIntro: function(ARequest: TRequest): string = nil;
  { Whether a chat channel has this name, so #name in a page links to it;
    set by the chat's side, nil when there is no chat. }
  WikiRoomThere: TExistsFunc = nil;
  { After a page has a new name, for the units that keep things by a
    page's name.  A unit keeps the one before
    and calls it too. }
  WikiPageMoved: TWikiPageMoved = nil;

implementation

uses
  StrUtils, Variants, fpjson, httproute, SiteStatic, SiteWords, SiteDb, SiteUsers, SiteRoles,
  SiteAdmin, SiteGuard, SiteGuardRules, SiteMail, SiteStats, SiteVisitors, WebPages, WikiRender, SiteSql, SiteParts, SiteNotices, SiteSearch, WikiEmoji, WikiEmojiSite;

const
  // the most an admin may allow a page (wiki_page_kb); the form that sends
  // it, its text encoded, is three times that at worst (the body limits below)
  MAX_PAGE_KB = 1024;
  PAGE_SIZE = 500;
  MAX_CATEGORIES = 50;
  HISTORY_SIZE = 200;
  // goes up when RenderPage renders differently; RenderOldPages catches up
  WikiRenderVersion = 8; // the wiki's own emoji pictures; 7: colored table cells (gone again); 6: wiki links parsed by fcl-md, the link index

type
  TPage = record
    Id: integer;
    Slug, Title, Body, Html: string;
    Rev: integer;
    Locked: boolean;
    UpdatedBy, Updated: string;
    // UpdatedBy is a member here, not only a name kept as text
    ByMember: boolean;
  end;

function W(ARequest: TRequest; const English: string): string; forward;

{ --------------------------------------------------------------- names }

{ A page name as kept: spaces to underscores, runs of them to one, the
  first letter capital, nothing a URL or a title cannot carry. }
function SlugOf(const Name: string): string;
var
  S: string;
  I: integer;
begin
  S := Trim(Name);
  S := StringReplace(S, ' ', '_', [rfReplaceAll]);
  Result := '';
  for I := 1 to Length(S) do
    // a page about a symbol may be named by it: ^, ;, &, *, =
    if (S[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '-', '.', '(', ')', ',', '!', '''', '+', '/', '$', '@', ':', '^', ';', '&', '*', '=']) or (Ord(S[I]) >= 128) then
      Result := Result + S[I];
  while Pos('__', Result) > 0 do
    Result := StringReplace(Result, '__', '_', [rfReplaceAll]);
  while (Result <> '') and (Result[1] in ['_', '.']) do
    Delete(Result, 1, 1);
  while (Result <> '') and (Result[Length(Result)] = '_') do
    SetLength(Result, Length(Result) - 1);
  if (Result <> '') and (Result[1] in ['a'..'z']) then
    Result[1] := UpCase(Result[1]);
  // cut on a whole character: half of one would not be saved
  Result := NoticeCut(Result, 180);
end;

function TitleOf(const Slug: string): string;
begin
  Result := StringReplace(Slug, '_', ' ', [rfReplaceAll]);
end;

function PageUrl(const Slug: string): string;
var
  I: integer;
begin
  // the characters a page name keeps are fine in a path but for a few
  Result := '';
  for I := 1 to Length(Slug) do
    if Slug[I] in ['''', '+', ',', '!', '(', ')', '^', ';', '&', '*', '='] then
      Result := Result + '%' + IntToHex(Ord(Slug[I]), 2)
    else if Ord(Slug[I]) >= 128 then
      Result := Result + '%' + IntToHex(Ord(Slug[I]), 2)
    else
      Result := Result + Slug[I];
  Result := '/wiki/' + Result;
end;

function LinksHereUrl(const Slug: string): string;
begin
  Result := '/wiki-links/' + Copy(PageUrl(Slug), Length('/wiki/') + 1, MaxInt);
end;

{ --------------------------------------------------------------- pages }

function LoadPage(const Slug: string; ForUpdate: boolean = False): TPage;
var
  Suffix: string;
begin
  Result := Default(TPage);
  Result.Slug := Slug;
  Result.Title := TitleOf(Slug);
  Suffix := '';
  if ForUpdate then
    Suffix := ' FOR UPDATE';
  with Query('SELECT p.id, p.slug, p.title, p.body, p.html, p.rev, p.locked, COALESCE(u.name, NULLIF(p.updated_by_name, ''''), ''''), ' +
      IsoTime('p.updated') + ', u.id IS NOT NULL FROM wiki_pages p LEFT JOIN users u ON u.id = p.updated_by WHERE p.name_key = :k' + Suffix, [LowerCase(Slug)]) do
  try
    if not EOF then
    begin
      Result.Id := Fields[0].AsInteger;
      Result.Slug := Fields[1].AsString;
      Result.Title := Fields[2].AsString;
      Result.Body := Fields[3].AsString;
      Result.Html := Fields[4].AsString;
      Result.Rev := Fields[5].AsInteger;
      Result.Locked := Fields[6].AsInteger = 1;
      Result.UpdatedBy := Fields[7].AsString;
      Result.Updated := Fields[8].AsString;
      Result.ByMember := Fields[9].AsInteger = 1;
    end;
  finally
    Free;
  end;
end;

var
  Prefixes: array of record
    Prefix: string;
    Make: TWikiPrefix;
    end;

procedure RegisterWikiPrefix(const Prefix: string; Make: TWikiPrefix);
begin
  SetLength(Prefixes, Length(Prefixes) + 1);
  Prefixes[High(Prefixes)].Prefix := Prefix;
  Prefixes[High(Prefixes)].Make := Make;
end;

function EarlierEdits(ARequest: TRequest; const Slug: string; Open: boolean): string;
begin
  Result := '';
  if Assigned(WikiEarlierEdits) then
    Result := WikiEarlierEdits(ARequest, Slug, Open);
end;

function RoomThere(const Name: string): boolean;
begin
  Result := Assigned(WikiRoomThere) and WikiRoomThere(Name);
end;

function PageExists(const Slug: string): boolean;
begin
  Result := IntValue('SELECT COUNT(*) FROM wiki_pages WHERE name_key = :k', [LowerCase(Slug)]) > 0;
end;

type
  { What a page's links point to while it is rendered, and the pages it
    names, for the link index. }
  TPageLinks = class(TWikiLinks)
  private
    FFileLookup: TWikiFileLookup;
    FPageThere: TExistsFunc;
    FKnown: TStringList;
    FTargets: TStrings;
  public
    constructor Create(FileLookup: TWikiFileLookup; PageThere: TExistsFunc; Targets: TStrings);
    destructor Destroy; override;
    procedure Resolve(const Target, Fragment: string; out Href: string; out Exists: boolean); override;
    function FileHtml(const Inner: string; out Html: string): boolean; override;
  end;

constructor TPageLinks.Create(FileLookup: TWikiFileLookup; PageThere: TExistsFunc; Targets: TStrings);
begin
  inherited Create;
  FFileLookup := FileLookup;
  FPageThere := PageThere;
  FTargets := Targets;
  // name keys as they are, with whether the page is there: a name may hold any sign
  FKnown := TStringList.Create;
  FKnown.CaseSensitive := True;
end;

destructor TPageLinks.Destroy;
begin
  FKnown.Free;
  inherited Destroy;
end;

function SectionId(const Words: string): string;
var
  C: char;
begin
  Result := '';
  for C in Trim(Words) do
    if C in [#9, #10, #13, ' '] then
    begin
      if (Result = '') or (Result[Length(Result)] <> '_') then
        Result := Result + '_';
    end
    else if not (C in ['[', ']', '{', '}', '|', '#', '<', '>', '"', '''']) then
      Result := Result + C;
end;

procedure TPageLinks.Resolve(const Target, Fragment: string; out Href: string; out Exists: boolean);
var
  Slug, Key: string;
  I: integer;
begin
  Exists := True;
  Href := '';
  // an address written as a page name
  if StartsText('https://', Target) or StartsText('http://', Target) then
  begin
    Href := Target;
    if Fragment <> '' then
      Href := Href + '#' + Fragment;
    Exit;
  end;
  if StartsText('wikipedia:', Target) then
  begin
    Href := 'https://en.wikipedia.org/wiki/' + StringReplace(Trim(Copy(Target, 11, MaxInt)), ' ', '_', [rfReplaceAll]);
    if Fragment <> '' then
      Href := Href + '#' + SectionId(Fragment);
    Exit;
  end;
  // a prefix the site registered: an address of its own, or this wiki by another name
  Slug := Target;
  for I := 0 to High(Prefixes) do
    if StartsText(Prefixes[I].Prefix + ':', Target) then
    begin
      if Prefixes[I].Make = nil then
        Slug := Copy(Target, Length(Prefixes[I].Prefix) + 2, MaxInt)
      else
      begin
        Href := Prefixes[I].Make(Trim(Copy(Target, Length(Prefixes[I].Prefix) + 2, MaxInt)));
        Exit;
      end;
      Break;
    end;
  Slug := SlugOf(Slug);
  if Slug = '' then
  begin
    // [[#Section]], a part of this same page
    if (Trim(Target) = '') and (SectionId(Fragment) <> '') then
      Href := '#' + SectionId(Fragment);
    Exit;
  end;
  Href := PageUrl(Slug);
  if SectionId(Fragment) <> '' then
    Href := Href + '#' + SectionId(Fragment);
  Key := LowerCase(Slug);
  I := FKnown.IndexOf(Key);
  if I < 0 then
  begin
    Exists := (FPageThere = nil) or FPageThere(Slug);
    FKnown.AddObject(Key, TObject(PtrUInt(Ord(Exists))));
    if FTargets <> nil then
      FTargets.Add(Slug);
  end
  else
    Exists := FKnown.Objects[I] <> nil;
end;

function TPageLinks.FileHtml(const Inner: string; out Html: string): boolean;
begin
  Result := FileLinkHtml(Inner, Html, FFileLookup);
end;

{ Only the trailing category block is metadata. Keep the rest byte for
  byte, including line breaks in Markdown code blocks. }
function CategoryText(const Body: string; Categories: TStrings): string;
var
  LineStart, LineEnd, BodyEnd: integer;
  Line, CategoryName: string;
begin
  Categories.Clear;
  BodyEnd := Length(Body);
  LineEnd := BodyEnd;
  while LineEnd > 0 do
  begin
    LineStart := LineEnd;
    while (LineStart > 0) and (Body[LineStart] <> #10) do
      Dec(LineStart);
    Line := Trim(Copy(Body, LineStart + 1, LineEnd - LineStart));
    if Line <> '' then
    begin
      // Category\: is the same line as a Markdown tool writes it, the colon escaped
      if StartsStr('Category\:', Line) then
        Delete(Line, Length('Category') + 1, 1);
      if not StartsStr('Category:', Line) then
        Break;
      CategoryName := Trim(Copy(Line, Length('Category:') + 1, MaxInt));
      if CategoryName = '' then
        Break;
      if Categories.IndexOf(CategoryName) < 0 then
        Categories.Insert(0, CategoryName);
      if Categories.Count > MAX_CATEGORIES then
        Break;
      BodyEnd := LineStart;
    end;
    LineEnd := LineStart - 1;
  end;
  Result := Copy(Body, 1, BodyEnd);
end;

function PageLimit: integer;
begin
  Result := SettingInt('wiki_page_kb', 500);
  if Result < 16 then
    Result := 16
  else if Result > MAX_PAGE_KB then
    Result := MAX_PAGE_KB;
  Result := Result * 1024;
end;

function WikiBodyProblem(const Body: string; ARequest: TRequest): string;
var
  Categories: TStringList;
  CategoryName: string;
begin
  Result := '';
  if Length(Body) > PageLimit then
    Exit(Format(SiteWord(ReaderLanguage(ARequest), 'The page is too long: %d KB at most.'), [PageLimit div 1024]));
  Categories := TStringList.Create;
  try
    CategoryText(Body, Categories);
    if Categories.Count > MAX_CATEGORIES then
      Exit(SiteWord(ReaderLanguage(ARequest), 'A page can have at most 50 categories.'));
    for CategoryName in Categories do
      if Length(CategoryName) > 200 then
        Exit(SiteWord(ReaderLanguage(ARequest), 'A category name is too long (200 bytes at most).'));
  finally
    Categories.Free;
  end;
end;

{ A page whose first line is #REDIRECT [[Other Page]] sends its readers
  there; the slug of that page, or '' when the page is an ordinary one. }
function RedirectTarget(const Body: string): string;
var
  Line: string;
  P: integer;
begin
  Result := '';
  Line := Trim(Copy(Body, 1, Pos(#10, Body + #10) - 1));
  if not StartsText('#REDIRECT', Line) then
    Exit;
  P := Pos('[[', Line);
  if P = 0 then
    Exit;
  Line := Copy(Line, P + 2, MaxInt);
  P := Pos(']]', Line);
  if P > 0 then
    SetLength(Line, P - 1);
  P := Pos('|', Line);
  if P > 0 then
    SetLength(Line, P - 1);
  P := Pos('#', Line);
  if P > 0 then
    SetLength(Line, P - 1);
  Result := SlugOf(Line);
end;

function SelfRedirect(const Slug, Body: string): boolean;
var
  Target: string;
begin
  Target := RedirectTarget(Body);
  Result := (Target <> '') and (LowerCase(Target) = LowerCase(Slug));
end;

function CategoryUrl(const CategoryName: string): string;
begin
  Result := '/wiki-category/' + StringReplace(HTTPEncode(CategoryName), '+', '%20', [rfReplaceAll]);
end;

function CategoryLinks(Categories: TStrings; ARequest: TRequest): string;
var
  I: integer;
begin
  Result := '';
  if Categories.Count = 0 then
    Exit;
  Result := '<nav class="categories" aria-label="' + W(ARequest, 'Categories') + '">' + W(ARequest, 'Categories:') + ' ';
  for I := 0 to Categories.Count - 1 do
    Result := Result + '<a href="' + E(CategoryUrl(Categories[I])) + '">' + E(Categories[I]) + '</a> ';
  Result := Result + '</nav>';
end;

function PageCategories(PageId: integer; ARequest: TRequest): string;
var
  Categories: TStringList;
begin
  Categories := TStringList.Create;
  try
    with Query('SELECT category FROM wiki_categories WHERE page_id = :p ORDER BY category', [PageId]) do
    try
      while not EOF do
      begin
        Categories.Add(Fields[0].AsString);
        Next;
      end;
    finally
      Free;
    end;
    Result := CategoryLinks(Categories, ARequest);
  finally
    Categories.Free;
  end;
end;

function RenderPageWith(const Body: string; FileLookup: TWikiFileLookup; PageThere, MemberThere, RoomThere: TExistsFunc; Targets: TStrings): string;
var
  Members, Rooms, Categories: TStringList;
  Links: TPageLinks;
begin
  Members := TStringList.Create;
  Rooms := TStringList.Create;
  Categories := TStringList.Create;
  Links := TPageLinks.Create(FileLookup, PageThere, Targets);
  try
    Result := RenderWikiText(CategoryText(Body, Categories), Links, MemberThere, RoomThere, Members, Rooms);
  finally
    Links.Free;
    Categories.Free;
    Rooms.Free;
    Members.Free;
  end;
end;

function RenderPage(const Body: string; Targets: TStrings = nil): string;
begin
  Result := RenderPageWith(Body, @LoadWikiFile, @PageExists, @MemberExists, @RoomThere, Targets);
end;

function BodyView(const Body: string; ARequest: TRequest): string;
var
  Categories: TStringList;
begin
  Categories := TStringList.Create;
  try
    CategoryText(Body, Categories);
    Result := '<div class="wikibody">' + RenderPage(Body) + '</div>' + CategoryLinks(Categories, ARequest);
  finally
    Categories.Free;
  end;
end;

function MayEdit(const Me: TMember; const Page: TPage): boolean;
begin
  Result := (Me.Id > 0) and Can(Me, 'wiki-edit') and (not Page.Locked or Can(Me, 'wiki-lock'));
end;

{ The pages a page names, for backlinks, wanted pages and red links: one
  row each, its redirect's target among them. }
type
  TSectionMark = record
    Start, Level: integer;
  end;
  TSectionMarks = array of TSectionMark;

{ The headings a reader sees as sections: lines of one to six # outside
  fenced code, as Markdown reads them. }
function FindSections(const Body: string): TSectionMarks;
var
  P, LineEnd, I, Run, Rest, Count, FenceLen: integer;
  Fence: char;
begin
  Result := nil;
  Count := 0;
  Fence := #0;
  FenceLen := 0;
  P := 1;
  while P <= Length(Body) do
  begin
    LineEnd := PosEx(#10, Body, P);
    if LineEnd = 0 then
      LineEnd := Length(Body) + 1;
    I := P;
    while (I < LineEnd) and (I - P < 3) and (Body[I] = ' ') do
      Inc(I);
    if (I < LineEnd) and (Body[I] in ['`', '~']) then
    begin
      Run := 0;
      while (I + Run < LineEnd) and (Body[I + Run] = Body[I]) do
        Inc(Run);
      if Run >= 3 then
        if Fence = #0 then
        begin
          Fence := Body[I];
          FenceLen := Run;
        end
        else if (Body[I] = Fence) and (Run >= FenceLen) then
        begin
          // a closing fence has nothing after it
          Rest := I + Run;
          while (Rest < LineEnd) and (Body[Rest] in [' ', #9, #13]) do
            Inc(Rest);
          if Rest >= LineEnd then
            Fence := #0;
        end;
    end
    else if (Fence = #0) and (I < LineEnd) and (Body[I] = '#') then
    begin
      Run := 0;
      while (I + Run < LineEnd) and (Body[I + Run] = '#') do
        Inc(Run);
      if (Run <= 6) and ((I + Run >= LineEnd) or (Body[I + Run] in [' ', #9, #13])) then
      begin
        SetLength(Result, Count + 1);
        Result[Count].Start := P;
        Result[Count].Level := Run;
        Inc(Count);
      end;
    end;
    P := LineEnd + 1;
  end;
end;

{ Where section Number starts and the first byte after it: up to the next
  heading of its own level or a higher one. }
function SectionSpan(const Body: string; Number: integer; out From, Stop: integer): boolean;
var
  Marks: TSectionMarks;
  I: integer;
begin
  From := 0;
  Stop := 0;
  Marks := FindSections(Body);
  Result := (Number >= 1) and (Number <= Length(Marks));
  if not Result then
    Exit;
  From := Marks[Number - 1].Start;
  Stop := Length(Body) + 1;
  for I := Number to High(Marks) do
    if Marks[I].Level <= Marks[Number - 1].Level then
    begin
      Stop := Marks[I].Start;
      Break;
    end;
end;

function SectionText(const Body: string; Number: integer; out Text: string): boolean;
var
  From, Stop: integer;
begin
  Text := '';
  Result := SectionSpan(Body, Number, From, Stop);
  if Result then
    Text := TrimRight(Copy(Body, From, Stop - From));
end;

function ReplaceSection(const Body: string; Number: integer; const Text: string; out Whole: string): boolean;
var
  From, Stop, Kept: integer;
begin
  Whole := '';
  Result := SectionSpan(Body, Number, From, Stop);
  if not Result then
    Exit;
  // the blank lines that stood between this section and the next stay
  Kept := Stop;
  while (Kept > From) and (Body[Kept - 1] in [#10, #13, ' ', #9]) do
    Dec(Kept);
  // a browser sends its lines with CR LF: the page keeps the endings it has
  if Pos(#13, Body) = 0 then
    Whole := Copy(Body, 1, From - 1) + TrimRight(StringReplace(Text, #13, '', [rfReplaceAll])) + Copy(Body, Kept, MaxInt)
  else
    Whole := Copy(Body, 1, From - 1) + TrimRight(Text) + Copy(Body, Kept, MaxInt);
end;

function WithSectionLinks(const Html, Body, Slug, Words: string): string;
var
  Marks: TSectionMarks;
  P, Stop, Done, Count: integer;
  Level: char;
begin
  Result := Html;
  Marks := FindSections(Body);
  if Length(Marks) = 0 then
    Exit;
  // the page's headings must be the text's, one for one, or a link would open another section
  Count := 0;
  P := PosEx('<h', Html, 1);
  while P > 0 do
  begin
    if (P + 3 <= Length(Html)) and (Html[P + 2] in ['1'..'6']) and (Html[P + 3] = '>') then
    begin
      if (Count >= Length(Marks)) or (Marks[Count].Level <> Ord(Html[P + 2]) - Ord('0')) then
        Exit;
      Inc(Count);
    end;
    P := PosEx('<h', Html, P + 2);
  end;
  if Count <> Length(Marks) then
    Exit;
  Result := '';
  Done := 1;
  Count := 0;
  P := PosEx('<h', Html, 1);
  while P > 0 do
  begin
    if (P + 3 <= Length(Html)) and (Html[P + 2] in ['1'..'6']) and (Html[P + 3] = '>') then
    begin
      Level := Html[P + 2];
      Stop := PosEx('</h' + Level + '>', Html, P);
      if Stop = 0 then
        Exit(Html);
      Inc(Count);
      Result := Result + Copy(Html, Done, Stop - Done) + ' <a class="sectionedit" href="' + PageUrl(Slug) + '?edit=1&amp;section=' +
        IntToStr(Count) + '">' + Words + '</a>';
      Done := Stop;
      P := PosEx('<h', Html, Stop);
    end
    else
      P := PosEx('<h', Html, P + 2);
  end;
  Result := Result + Copy(Html, Done, MaxInt);
end;

{ The link index of a page: the names RenderPage gathered in Targets, and
  where it redirects to.  A name twice, the same but for its case, is kept
  once (INSERT IGNORE). }
procedure StoreLinks(PageId: integer; Targets: TStrings; const Body: string);
var
  SQL, Redirect: string;
  Values: array of variant;
  I, N: integer;
begin
  Exec('DELETE FROM wiki_links WHERE page_id = :p', [PageId]);
  Redirect := RedirectTarget(Body);
  if Redirect <> '' then
    Targets.Add(Redirect);
  I := 0;
  while I < Targets.Count do
  begin
    // two hundred rows a statement
    SQL := '';
    Values := [];
    N := 0;
    while (I < Targets.Count) and (N < 200) do
    begin
      if SQL <> '' then
        SQL := SQL + ', ';
      SQL := SQL + Format('(:p%d, :k%d, :t%d)', [N, N, N]);
      SetLength(Values, Length(Values) + 3);
      Values[High(Values) - 2] := PageId;
      Values[High(Values) - 1] := LowerCase(Targets[I]);
      Values[High(Values)] := Targets[I];
      Inc(I);
      Inc(N);
    end;
    Exec('INSERT IGNORE INTO wiki_links (page_id, target_key, target) VALUES ' + SQL, Values);
  end;
end;

procedure StoreCategories(PageId: integer; const Body: string);
var
  Categories: TStringList;
  I: integer;
begin
  Categories := TStringList.Create;
  try
    CategoryText(Body, Categories);
    Exec('DELETE FROM wiki_categories WHERE page_id = :p', [PageId]);
    for I := 0 to Categories.Count - 1 do
      Exec(SqlInsertIgnore('wiki_categories', 'page_id, category', ':p, :c'), [PageId, Categories[I]]);
  finally
    Categories.Free;
  end;
end;

{ A page that came or went: the pages linking to it are rendered again by
  the chore, so their links to it turn blue or red. }
procedure MarkLinkersStale(const Slug: string);
begin
  Exec('UPDATE wiki_pages p JOIN wiki_links l ON l.page_id = p.id SET p.rendered = 0 WHERE l.target_key = :k', [LowerCase(Slug)]);
end;

{ Keeps a page and its revision; the first save makes the page.  Answers
  what went wrong, or ''.  A :keyword: of the emoji set is kept as its
  emoji (WikiEmoji), so the page's text is plain Markdown anywhere. }
{ A name in the files' own space: /wiki/File:x and /wiki/Image:x go to a
  file's page, so no wiki page may be called that. }
function FileName(const Slug: string): boolean;
begin
  Result := StartsText('File:', Slug) or StartsText('Image:', Slug);
end;

function SavePage(const Me: TMember; const Slug, Title, Typed, Summary: string; Base: integer; ARequest: TRequest): string;
var
  Page: TPage;
  Html, Heading, Body: string;
  Categories, Targets: TStringList;
  I: integer;
  TransactionOpen, Made: boolean;
begin
  // names that start File: or Image: are the files' own pages
  if FileName(Slug) then
    Exit(SiteWord(ReaderLanguage(ARequest), 'A page needs a name with letters or numbers in it.'));
  Body := ExpandEmojiKeywords(Typed);
  Result := WikiBodyProblem(Body, ARequest);
  if Result <> '' then
    Exit;
  Categories := TStringList.Create;
  Targets := TStringList.Create;
  TransactionOpen := False;
  Made := False;
  try
    Exec('START TRANSACTION', []);
    TransactionOpen := True;
    Page := LoadPage(Slug, True);
    if not MayEdit(Me, Page) then
      Exit(SiteWord(ReaderLanguage(ARequest), 'You may not change this page.'));
    if SelfRedirect(Slug, Body) or ((Page.Id > 0) and SelfRedirect(Page.Slug, Body)) then
      Exit(SiteWord(ReaderLanguage(ARequest), 'A page cannot send readers to itself.'));
    // an editor opened before the page existed sends 0: someone saving the
    // page first is a conflict too
    if (Page.Id > 0) and (Base <> Page.Rev) then
      Exit(SiteWord(ReaderLanguage(ARequest), 'Somebody saved this page while you were writing.') + ' ' + SiteWord(ReaderLanguage(ARequest),
        'Open it again and put your change into the new text.'));
    Heading := Trim(Title);
    if Heading = '' then
      Heading := Page.Title;
    Heading := NoticeCut(Heading, 200);
    CategoryText(Body, Categories);
    for I := 0 to Categories.Count - 1 do
      if Length(Categories[I]) > 200 then
        Exit(SiteWord(ReaderLanguage(ARequest), 'A category name is too long (200 bytes at most).'));
    Html := RenderPage(Body, Targets);
    if Page.Id = 0 then
    begin
      if Trim(Body) = '' then
        Exit(SiteWord(ReaderLanguage(ARequest), 'An empty page is not kept.'));
      Exec('INSERT INTO wiki_pages (name_key, slug, title, body, html, lang, rev, locked, updated, updated_by, rendered)' +
        ' VALUES (:k, :s, :t, :b, :h, :lang, 1, 0, NOW(), :u, :v)', [LowerCase(Slug), Slug, Heading, Body, Html, SlugLanguage(Slug), Me.Id, WikiRenderVersion]);
      Page.Id := LastId;
      Page.Rev := 1;
      Made := True;
    end
    else
    begin
      Page.Rev := Page.Rev + 1;
      Exec('UPDATE wiki_pages SET title = :t, body = :b, html = :h, lang = :lang, rev = :r, updated = NOW(), updated_by = :u, updated_by_name = '''', rendered = :v' +
        ' WHERE id = :i', [Heading, Body, Html, SlugLanguage(Slug), Page.Rev, Me.Id, WikiRenderVersion, Page.Id]);
    end;
    Exec('INSERT INTO wiki_revisions (page_id, rev, title, body, summary, user_id, at) VALUES (:p, :r, :t, :b, :s, :u, NOW())',
      [Page.Id, Page.Rev, Heading, Body, NoticeCut(Trim(Summary), 200), Me.Id]);
    StoreCategories(Page.Id, Body);
    StoreLinks(Page.Id, Targets, Body);
    if Made then
      MarkLinkersStale(Slug);
    Exec('COMMIT', []);
    TransactionOpen := False;
    Result := '';
  finally
    Targets.Free;
    Categories.Free;
    if TransactionOpen then
      Exec('ROLLBACK', []);
  end;
end;

{ Gives a page a new name and leaves a redirect at the old one, so links
  and bookmarks still land.  A change of capitals only renames it. }
function MovePage(const Me: TMember; const Slug, NewName, Reason: string; ARequest: TRequest): string;
var
  Page: TPage;
  OldSlug, NewSlug, Note, Body: string;
  Targets: TStringList;
  TransactionOpen, Renamed: boolean;
  RedirectId: integer;
begin
  NewSlug := SlugOf(NewName);
  if (NewSlug = '') or FileName(NewSlug) then
    Exit(SiteWord(ReaderLanguage(ARequest), 'A page needs a name with letters or numbers in it.'));
  Targets := TStringList.Create;
  TransactionOpen := False;
  try
    Exec('START TRANSACTION', []);
    TransactionOpen := True;
    Page := LoadPage(Slug, True);
    if Page.Id = 0 then
      Exit(SiteWord(ReaderLanguage(ARequest), 'There is no page by this name yet.'));
    if not MayEdit(Me, Page) or not Can(Me, 'wiki-move') then
      Exit(SiteWord(ReaderLanguage(ARequest), 'You may not move this page.'));
    OldSlug := Page.Slug;
    if NewSlug = OldSlug then
      Exit(SiteWord(ReaderLanguage(ARequest), 'The page has that name already.'));
    Renamed := LowerCase(NewSlug) <> LowerCase(OldSlug);
    if Renamed and (IntValue('SELECT COUNT(*) FROM wiki_pages WHERE name_key = :k', [LowerCase(NewSlug)]) > 0) then
      Exit(SiteWord(ReaderLanguage(ARequest), 'There is a page by that name already.'));
    Note := Format('Moved from %s to %s', [TitleOf(OldSlug), TitleOf(NewSlug)]);
    if Trim(Reason) <> '' then
      Note := Note + ': ' + Trim(Reason);
    // the heading follows the name, unless it was written apart from it
    if Page.Title = TitleOf(OldSlug) then
      Page.Title := TitleOf(NewSlug);
    Inc(Page.Rev);
    Exec('UPDATE wiki_pages SET name_key = :k, slug = :s, title = :t, lang = :lang, rev = :r, updated = NOW(), updated_by = :u, updated_by_name = '''' WHERE id = :i',
      [LowerCase(NewSlug), NewSlug, Page.Title, SlugLanguage(NewSlug), Page.Rev, Me.Id, Page.Id]);
    Exec('INSERT INTO wiki_revisions (page_id, rev, title, body, summary, user_id, at) VALUES (:p, :r, :t, :b, :s, :u, NOW())',
      [Page.Id, Page.Rev, Page.Title, Page.Body, NoticeCut(Note, 200), Me.Id]);
    if Renamed then
    begin
      Body := '#REDIRECT [[' + TitleOf(NewSlug) + ']]' + #10;
      Exec('INSERT INTO wiki_pages (name_key, slug, title, body, html, lang, rev, locked, updated, updated_by, rendered)' +
        ' VALUES (:k, :s, :t, :b, :h, :lang, 1, :locked, NOW(), :u, :v)', [LowerCase(OldSlug), OldSlug, TitleOf(OldSlug), Body,
        RenderPage(Body, Targets), SlugLanguage(OldSlug), Ord(Page.Locked), Me.Id, WikiRenderVersion]);
      RedirectId := LastId;
      Exec('INSERT INTO wiki_revisions (page_id, rev, title, body, summary, user_id, at) VALUES (:p, 1, :t, :b, :s, :u, NOW())',
        [RedirectId, TitleOf(OldSlug), Body, NoticeCut(Note, 200), Me.Id]);
      StoreLinks(RedirectId, Targets, Body);
      if Assigned(WikiPageMoving) then
        WikiPageMoving(OldSlug, NewSlug);
      MarkLinkersStale(NewSlug);
    end;
    Exec('COMMIT', []);
    TransactionOpen := False;
    if Renamed and Assigned(WikiPageMoved) then
      WikiPageMoved(OldSlug, NewSlug);
    Result := '';
  finally
    Targets.Free;
    if TransactionOpen then
      Exec('ROLLBACK', []);
  end;
end;

{ Takes a page off the wiki; its revisions stay, and a moderator can bring
  it back (RestorePage). }
function DeletePage(const Me: TMember; const Slug, Reason: string; ARequest: TRequest): string;
var
  Page: TPage;
  TransactionOpen: boolean;
begin
  if not Can(Me, 'wiki-delete') then
    Exit(SiteWord(ReaderLanguage(ARequest), 'Only a moderator deletes a page.'));
  TransactionOpen := False;
  try
    Exec('START TRANSACTION', []);
    TransactionOpen := True;
    Page := LoadPage(Slug, True);
    // a locked page is deleted by who may change it
    if not MayEdit(Me, Page) then
    begin
      Exec('ROLLBACK', []);
      TransactionOpen := False;
      Exit(SiteWord(ReaderLanguage(ARequest), 'This page is locked; only moderators change it.'));
    end;
    if Page.Id = 0 then
      Exit(SiteWord(ReaderLanguage(ARequest), 'There is no page by this name yet.'));
    if SameText(Page.Slug, MAIN_PAGE) then
      Exit(SiteWord(ReaderLanguage(ARequest), 'The main page cannot be deleted.'));
    Exec('INSERT INTO wiki_deleted (page_id, name_key, slug, title, rev, locked, reason, user_id, at) VALUES (:p, :k, :s, :t, :r, :l, :why, :u, NOW())',
      [Page.Id, LowerCase(Page.Slug), Page.Slug, Page.Title, Page.Rev, Ord(Page.Locked), NoticeCut(Trim(Reason), 200), Me.Id]);
    Exec('DELETE FROM wiki_categories WHERE page_id = :p', [Page.Id]);
    Exec('DELETE FROM wiki_links WHERE page_id = :p', [Page.Id]);
    Exec('DELETE FROM wiki_pages WHERE id = :p', [Page.Id]);
    MarkLinkersStale(Page.Slug);
    Exec('COMMIT', []);
    TransactionOpen := False;
    Result := '';
  finally
    if TransactionOpen then
      Exec('ROLLBACK', []);
  end;
end;

{ A deleted page back under its name, from its last revision, locked if it
  was. }
function RestorePage(const Me: TMember; const Slug: string; ARequest: TRequest): string;
var
  PageId, Rev, Locked: integer;
  Name, Title, Body: string;
  Targets: TStringList;
  TransactionOpen: boolean;
begin
  if not Can(Me, 'wiki-delete') then
    Exit(SiteWord(ReaderLanguage(ARequest), 'Only a moderator brings a page back.'));
  Targets := TStringList.Create;
  TransactionOpen := False;
  try
    Exec('START TRANSACTION', []);
    TransactionOpen := True;
    if PageExists(Slug) then
      Exit(SiteWord(ReaderLanguage(ARequest), 'A new page has this name now; move it away first.'));
    PageId := IntValue('SELECT COALESCE(MAX(page_id), 0) FROM wiki_deleted WHERE name_key = :k', [LowerCase(Slug)]);
    Name := VarToStr(Value('SELECT slug FROM wiki_deleted WHERE page_id = :p LIMIT 1', [PageId]));
    Locked := IntValue('SELECT locked FROM wiki_deleted WHERE page_id = :p', [PageId]);
    Rev := IntValue('SELECT COALESCE(MAX(rev), 0) FROM wiki_revisions WHERE page_id = :p', [PageId]);
    if (PageId = 0) or (Rev = 0) then
      Exit(SiteWord(ReaderLanguage(ARequest), 'Nothing to bring back.'));
    with Query('SELECT title, body FROM wiki_revisions WHERE page_id = :p AND rev = :r', [PageId, Rev]) do
    try
      Title := Fields[0].AsString;
      Body := Fields[1].AsString;
    finally
      Free;
    end;
    Inc(Rev);
    Exec('INSERT INTO wiki_pages (id, name_key, slug, title, body, html, lang, rev, locked, updated, updated_by, rendered)' +
      ' VALUES (:i, :k, :s, :t, :b, :h, :lang, :r, :l, NOW(), :u, :v)', [PageId, LowerCase(Name), Name, Title, Body, RenderPage(Body, Targets),
      SlugLanguage(Name), Rev, Locked, Me.Id, WikiRenderVersion]);
    Exec('INSERT INTO wiki_revisions (page_id, rev, title, body, summary, user_id, at) VALUES (:p, :r, :t, :b, :s, :u, NOW())',
      [PageId, Rev, Title, Body, 'Brought back after it was deleted', Me.Id]);
    StoreCategories(PageId, Body);
    StoreLinks(PageId, Targets, Body);
    Exec('DELETE FROM wiki_deleted WHERE page_id = :p', [PageId]);
    MarkLinkersStale(Name);
    Exec('COMMIT', []);
    TransactionOpen := False;
    Result := '';
  finally
    Targets.Free;
    if TransactionOpen then
      Exec('ROLLBACK', []);
  end;
end;

{ ---------------------------------------------------------------- html }

function ReaderLanguage(ARequest: TRequest): string;
begin
  if ARequest = nil then
    Exit(RequestLanguage);
  Result := LanguageOfRequest(ARequest);
end;

{ What the wiki's lists and search show: the reader's language, or all of
  them when the wiki's own cookie or the address says so. }
function FilterLanguage(ARequest: TRequest): string;
begin
  Result := ReaderLanguage(ARequest);
  if (ARequest.QueryFields.Values['all'] = '1') or (ARequest.CookieFields.Values['wiki_language'] = 'all') then
    Result := 'all';
end;

{ What the wiki's picker shows as chosen. }
function PickerLanguage(ARequest: TRequest): string;
begin
  Result := ReaderLanguage(ARequest);
  if ARequest.CookieFields.Values['wiki_language'] = 'all' then
    Result := 'all';
end;

function W(ARequest: TRequest; const English: string): string;
begin
  Result := E(SiteWord(ReaderLanguage(ARequest), English));
end;

function LanguageOptions(ARequest: TRequest): string; forward;

function PageHead(ARequest: TRequest; const Me: TMember): string;
begin
  Result := AccountBox(Me, ReaderLanguage(ARequest));
end;

procedure SendWiki(ARequest: TRequest; AResponse: TResponse; const Title, Content: string; const Kind: string = ''; const Description: string = ''; const PageSlug: string = '');
var
  Live: string;
  More: array of string;
begin
  // what another unit shows live on the page
  Live := '';
  if Assigned(WikiLive) then
    if PageSlug <> '' then
      Live := WikiLive(ARequest, 'wiki', PageSlug)
    else
      Live := WikiLive(ARequest, '', '');
  AResponse.SetCustomHeader('Cache-Control', 'private, no-store');
  AResponse.SetCustomHeader('Vary', 'Cookie');
  More := ['title', E(Title), 'content', Content, 'account', PageHead(ARequest, CurrentMember(ARequest)), 'kind', Kind, 'languages',
    LanguageOptions(ARequest), 'return', E(WikiReturnUrl(ARequest.URI, ARequest.QueryString)), 'description', E(Description), 'live', Live,
    'canonical', E(CanonicalUrl(ARequest))];
  if Assigned(WikiPageValues) then
    More := Concat(More, WikiPageValues(ARequest, PageSlug));
  SendPage(AResponse, FillTemplate('wiki', More, ReaderLanguage(ARequest)));
end;

procedure SendWikiPage(ARequest: TRequest; AResponse: TResponse; const Title, Content: string);
begin
  SendWiki(ARequest, AResponse, Title, Content, 'other');
end;

function Tools(ARequest: TRequest; const Page: TPage; const Me: TMember): string;
begin
  Result := '<nav class="pagetools">';
  if MayEdit(Me, Page) and (Page.Id = 0) then
    Result := Result + '<a class="button" href="' + PageUrl(Page.Slug) + '?edit=1">' + W(ARequest, 'Start this page') + '</a>'
  else if MayEdit(Me, Page) then
    Result := Result + '<a href="' + PageUrl(Page.Slug) + '?edit=1">' + W(ARequest, 'Edit') + '</a>'
  else if Me.Id = 0 then
    Result := Result + '<a href="/signin?return=' + HTTPEncode(PageUrl(Page.Slug)) + '">' + W(ARequest, 'Sign in to edit') + '</a>';
  if Page.Id > 0 then
    Result := Result + '<a href="' + PageUrl(Page.Slug) + '?history=1">' + W(ARequest, 'History') + '</a>';
  Result := Result + '<a href="' + LinksHereUrl(Page.Slug) + '">' + W(ARequest, 'What links here') + '</a>';
  if (Page.Id > 0) and MayEdit(Me, Page) and Can(Me, 'wiki-move') then
    Result := Result + '<a href="' + PageUrl(Page.Slug) + '?move=1">' + W(ARequest, 'Move') + '</a>';
  if (Page.Id > 0) and Can(Me, 'wiki-delete') and not SameText(Page.Slug, MAIN_PAGE) then
    Result := Result + '<a href="' + PageUrl(Page.Slug) + '?delete=1">' + W(ARequest, 'Delete') + '</a>';
  // a moderator locks a page so only moderators change it, and unlocks it again
  if (Page.Id > 0) and Can(Me, 'wiki-lock') then
    Result := Result + '<form method="post" action="' + PageUrl(Page.Slug) + '" class="pagetool-form"><input type="hidden" name="action" value="lock">' +
      '<input type="hidden" name="locked" value="' + IntToStr(Ord(not Page.Locked)) + '"><button type="submit">' + IfThen(Page.Locked,
      W(ARequest, 'Unlock'), W(ARequest, 'Lock')) + '</button></form>';
  // the browser's own print, which every browser can save as a PDF; shown by wiki.js
  if Page.Id > 0 then
    Result := Result + '<button type="button" class="pagetool-print" data-print hidden title="' + W(ARequest, 'Print this page, or save it as a PDF') +
      '">' + W(ARequest, 'Save as PDF') + '</button>';
  Result := Result + '</nav>';
end;

function MoveForm(ARequest: TRequest; const Page: TPage; const NewName, Reason, Problem: string): string;
begin
  Result := '<h1>' + E(Format(SiteWord(ReaderLanguage(ARequest), 'Move %s'), [Page.Title])) + '</h1>';
  if Problem <> '' then
    Result := Result + '<p class="problem">' + E(Problem) + '</p>';
  Result := Result + '<form method="post" action="' + PageUrl(Page.Slug) + '" class="wikiform"><input type="hidden" name="action" value="move">' +
    '<label>' + W(ARequest, 'New name') + ' <input name="to" maxlength="180" required value="' + E(NewName) + '"></label>' + '<label>' +
    W(ARequest, 'Why') + ' <input name="reason" maxlength="150" value="' + E(Reason) + '" placeholder="' + W(ARequest, 'a few words for the history') +
    '"></label>' + '<p class="fine">' + W(ARequest, 'The old name stays as a redirect, so links and bookmarks to it still land here.') +
    '</p>' + '<p><button type="submit">' + W(ARequest, 'Move') + '</button> <a href="' + PageUrl(Page.Slug) + '">' + W(ARequest, 'Cancel') + '</a></p></form>';
end;

function DeleteForm(ARequest: TRequest; const Page: TPage; const Reason, Problem: string): string;
begin
  Result := '<h1>' + E(Format(SiteWord(ReaderLanguage(ARequest), 'Delete %s'), [Page.Title])) + '</h1>';
  if Problem <> '' then
    Result := Result + '<p class="problem">' + E(Problem) + '</p>';
  Result := Result + '<form method="post" action="' + PageUrl(Page.Slug) + '" class="wikiform"><input type="hidden" name="action" value="delete">' +
    '<label>' + W(ARequest, 'Why') + ' <input name="reason" maxlength="150" required value="' + E(Reason) + '"></label>' + '<p class="fine">' +
    W(ARequest, 'The page leaves the wiki, its history stays, and a moderator can bring it back from its address.') + '</p>' +
    '<p><button type="submit">' + W(ARequest, 'Delete') + '</button> <a href="' + PageUrl(Page.Slug) + '">' + W(ARequest, 'Cancel') + '</a></p></form>';
end;

{ The pages that link to Slug, as a list; '' when none do. }
function LinksHereList(const Slug: string; Limit: integer): string;
begin
  Result := '';
  with Query('SELECT p.slug, p.title FROM wiki_links l JOIN wiki_pages p ON p.id = l.page_id WHERE l.target_key = :k' + ' ORDER BY p.name_key LIMIT ' +
      IntToStr(Limit), [LowerCase(Slug)]) do
  try
    while not EOF do
    begin
      Result := Result + '<li><a href="' + E(PageUrl(Fields[0].AsString)) + '">' + E(Fields[1].AsString) + '</a></li>';
      Next;
    end;
  finally
    Free;
  end;
  if Result <> '' then
    Result := '<ul class="wikipages">' + Result + '</ul>';
end;

{ What a reader finds at a name with no page: that it was deleted, if it
  was, a way to start it, and the pages waiting for it. }
function MissingPage(ARequest: TRequest; const Page: TPage; const Me: TMember): string;
var
  Linked: string;
begin
  Result := '<h1>' + E(Page.Title) + '</h1>';
  with Query('SELECT ' + IsoTime('d.at') + ', COALESCE(u.name, ''''), d.reason FROM wiki_deleted d LEFT JOIN users u ON u.id = d.user_id' +
      ' WHERE d.name_key = :k ORDER BY d.at DESC LIMIT 1', [LowerCase(Page.Slug)]) do
  try
    if not EOF then
    begin
      Result := Result + '<p class="notice">' + E(Format(SiteWord(ReaderLanguage(ARequest), 'This page was deleted on %s by %s.'),
        [Copy(Fields[0].AsString, 1, 10), Fields[1].AsString]));
      if Fields[2].AsString <> '' then
        Result := Result + ' ' + E(Format(SiteWord(ReaderLanguage(ARequest), 'Why: %s'), [Fields[2].AsString]));
      Result := Result + '</p>';
      if Can(Me, 'wiki-delete') then
        Result := Result + '<form method="post" action="' + PageUrl(Page.Slug) + '"><input type="hidden" name="action" value="undelete">' +
          '<button type="submit">' + W(ARequest, 'Bring it back') + '</button></form>';
    end
    else
      Result := Result + '<p class="notice">' + W(ARequest, 'There is no page by this name yet.') + '</p>';
  finally
    Free;
  end;
  Result := Result + Tools(ARequest, Page, Me);
  Linked := LinksHereList(Page.Slug, 50);
  if Linked <> '' then
    Result := Result + '<h2>' + W(ARequest, 'Pages that link here') + '</h2>' + Linked;
end;

{ --------------------------------------------------------- languages }

{ The slug without its language suffix, and which language it was in. }
function BaseSlug(const Slug: string; out Language: integer): string;
var
  P: integer;
begin
  Language := -1;
  Result := Slug;
  P := Length(Slug);
  while (P > 0) and (Slug[P] <> '/') do
    Dec(P);
  if P > 1 then
  begin
    Language := LanguageIndex(Copy(Slug, P + 1, MaxInt));
    if Language >= 0 then
      Result := Copy(Slug, 1, P - 1);
  end;
end;

function PreferredLanguage(const CookieValue: string): string;
var
  Language: integer;
begin
  if CookieValue = 'all' then
    Exit('all');
  Language := LanguageIndex(CookieValue);
  if Language >= 0 then
    Result := LANGUAGE_CODES[Language]
  else
    Result := 'en';
end;

function SlugLanguage(const Slug: string): string;
var
  Language: integer;
begin
  BaseSlug(Slug, Language);
  if Language >= 0 then
    Result := LANGUAGE_CODES[Language]
  else
    Result := 'en';
end;

{ Only wiki reading routes are valid return addresses. }
function WikiReturnUrl(const Url: string; const QueryString: string): string;
var
  Path: string;
begin
  Result := '/wiki';
  if (Pos(#13, Url + QueryString) > 0) or (Pos(#10, Url + QueryString) > 0) or (Pos('\', Url) > 0) then
    Exit;
  Path := Copy(Url, 1, Pos('?', Url + '?') - 1);
  if (Path = '/wiki') or StartsStr('/wiki/', Path) or (Path = '/wiki-search') or (Path = '/wiki-pages') or StartsStr('/wiki-category/', Path) or
    (Path = '/wiki-changes') or (Path = '/wiki-contact') then
  begin
    Result := Url;
    if (QueryString <> '') and (Pos('?', Url) = 0) then
      Result := Result + '?' + QueryString;
  end;
end;

function LanguageOptions(ARequest: TRequest): string;
var
  Used: TStringList;
  Language: integer;
  Code, Chosen: string;

  procedure AddOption(const OptionCode, Caption: string);
  begin
    Result := Result + '<option value="' + E(OptionCode) + '"';
    if OptionCode = Chosen then
      Result := Result + ' selected';
    Result := Result + '>' + E(Caption) + '</option>';
  end;

begin
  Result := '';
  Chosen := PickerLanguage(ARequest);
  AddOption('en', 'English');
  AddOption('all', SiteWord(ReaderLanguage(ARequest), 'All languages'));
  Used := TStringList.Create;
  try
    with Query('SELECT DISTINCT lang FROM wiki_pages ORDER BY lang', []) do
    try
      while not EOF do
      begin
        Code := Fields[0].AsString;
        Language := LanguageIndex(Code);
        if Language >= 0 then
          Used.AddObject(LANGUAGE_NAMES[Language], TObject(PtrInt(Language)));
        Next;
      end;
    finally
      Free;
    end;
    Used.Sort;
    for Language := 0 to Used.Count - 1 do
      AddOption(LANGUAGE_CODES[PtrInt(Used.Objects[Language])], Used[Language]);
  finally
    Used.Free;
  end;
end;

{ All languages is the wiki's own choice about what to list: it leaves the
  language the site speaks alone.  Any other choice is the site's language,
  and reading in it. }
procedure ChooseLanguage(ARequest: TRequest; AResponse: TResponse);
var
  Asked: string;
  Secured: boolean;

  procedure SetCookie(const CookieName, CookieValue: string; Days: integer);
  begin
    with AResponse.Cookies.Add do
    begin
      Name := CookieName;
      Value := CookieValue;
      Path := '/';
      Expires := NowUTC + Days;
      HttpOnly := True;
      SameSite := ssLax;
      Secure := Secured;
    end;
  end;

begin
  CheckConnection;
  Asked := PreferredLanguage(ARequest.QueryFields.Values['language']);
  Secured := Setting('https', '0') = '1';
  if Asked = 'all' then
  begin
    SetCookie('wiki_language', 'all', 365);
    SetCookie('site_language', ReaderLanguage(ARequest), 365);
  end
  else
  begin
    SetCookie('site_language', Asked, 365);
    SetCookie('wiki_language', '', -1);
  end;
  SeeOther(AResponse, WikiReturnUrl(ARequest.QueryFields.Values['return']));
end;

{ Empty markers also let an interrupted startup finish on its next run. }
procedure FillPageLanguages;
var
  Pending: TStringList;
  I: integer;
begin
  Pending := TStringList.Create;
  try
    with Query('SELECT id, slug FROM wiki_pages WHERE lang = :empty ORDER BY id', ['']) do
    try
      while not EOF do
      begin
        Pending.AddPair(Fields[0].AsString, Fields[1].AsString);
        Next;
      end;
    finally
      Free;
    end;
    for I := 0 to Pending.Count - 1 do
      Exec('UPDATE wiki_pages SET lang = :lang WHERE id = :id AND lang = :empty',
        [SlugLanguage(Pending.ValueFromIndex[I]), StrToInt(Pending.Names[I]), '']);
  finally
    Pending.Free;
  end;
end;

{ A line of links to the page's other languages, or '' when it stands alone. }
function LanguageBar(const Slug: string): string;
var
  Base, Other: string;
  Here, Language, Found: integer;
  Names: TStringList;
begin
  Result := '';
  Base := BaseSlug(Slug, Here);
  Names := TStringList.Create;
  try
    with Query('SELECT slug FROM wiki_pages WHERE name_key = :b OR name_key LIKE :p', [LowerCase(Base), LowerCase(Base) + '/%']) do
    try
      while not EOF do
      begin
        Other := Fields[0].AsString;
        if SameText(Other, Base) then
          Names.AddObject('English', TObject(PtrInt(-1)))
        else if BaseSlug(Other, Language) = Base then
          Names.AddObject(LANGUAGE_NAMES[Language], TObject(PtrInt(Language)));
        Next;
      end;
    finally
      Free;
    end;
    if Names.Count < 2 then
      Exit;
    Names.Sort;
    Result := '<p class="notice languages">';
    for Found := 0 to Names.Count - 1 do
    begin
      Language := PtrInt(Names.Objects[Found]);
      if Language < 0 then
        Other := Base
      else
        Other := Base + '/' + LANGUAGE_CODES[Language];
      if Found > 0 then
        Result := Result + ' · ';
      if Language = Here then
        Result := Result + '<b>' + E(Names[Found]) + '</b>'
      else
        Result := Result + '<a href="' + PageUrl(Other) + '">' + E(Names[Found]) + '</a>';
    end;
    Result := Result + '</p>';
  finally
    Names.Free;
  end;
end;

function ByLine(ARequest: TRequest; const Page: TPage): string;
var
  Who: string;
begin
  if Page.Id = 0 then
    Exit('');
  Result := '<p class="byline">';
  if Page.UpdatedBy <> '' then
  begin
    // a member's name links to them; a name kept as text is just the name
    if Page.ByMember then
      Who := '<a href="/u/' + E(Page.UpdatedBy) + '">' + E(Page.UpdatedBy) + '</a>'
    else
      Who := E(Page.UpdatedBy);
    if Page.Updated <> '' then
      Result := Result + Format(W(ARequest, 'Revision %d, last changed by %s %s.'), [Page.Rev, Who, DateTag(Page.Updated)])
    else
      Result := Result + Format(W(ARequest, 'Revision %d, last changed by %s.'), [Page.Rev, Who]);
  end
  else if Page.Updated <> '' then
    Result := Result + Format(W(ARequest, 'Revision %d %s.'), [Page.Rev, DateTag(Page.Updated)])
  else
    Result := Result + Format(W(ARequest, 'Revision %d.'), [Page.Rev]);
  if Page.Locked then
    Result := Result + ' ' + W(ARequest, 'Locked: only moderators change it.');
  Result := Result + '</p>';
end;

function Editor(ARequest: TRequest; const Page: TPage; const Body, Summary, Problem: string; Section: integer = 0): string;
var
  TitleField: string;
begin
  Result := '<h1>' + E(Page.Title) + '</h1>';
  if Problem <> '' then
    Result := Result + '<p class="problem">' + E(Problem) + '</p>';
  if Page.Id = 0 then
    Result := Result + '<p class="notice">' + W(ARequest, 'This page does not exist yet. What you write here starts it.') + '</p>';
  // one section: the page's name is not asked for, and the form says which part it holds
  if Section > 0 then
  begin
    Result := Result + '<p class="notice">' + W(ARequest, 'You are changing one section of this page.') + ' <a href="' + PageUrl(Page.Slug) +
      '?edit=1">' + W(ARequest, 'Edit the whole page') + '</a></p>';
    TitleField := '<input type="hidden" name="title" value="' + E(Page.Title) + '"><input type="hidden" name="section" value="' + IntToStr(Section) + '">';
  end
  else
    TitleField := '<label class="wikiedit-title">' + W(ARequest, 'Title') + ' ' + '<input name="title" maxlength="200" value="' + E(Page.Title) + '"></label>';
  Result := Result + '<form method="post" action="' + PageUrl(Page.Slug) + '" class="wikiedit">' + '<input type="hidden" name="base" value="' +
    IntToStr(Page.Rev) + '">' + TitleField + '<textarea name="body" rows="28" spellcheck="true">' + E(Body) + '</textarea>' + '<label>' +
    W(ARequest, 'What changed') + ' ' + '<input name="summary" maxlength="200" value="' + E(Summary) + '" placeholder="' +
    W(ARequest, 'a few words for the history') + '"></label>' + '<p class="fine">' +
    Format(W(ARequest, 'Markdown, as in the chat: %s, %s, %s for blocks, lists with %s and %s, links as %s, and %s for another page here.'),
    ['**bold**', '`code`', '```', '-', '1.', '[words](address)', '[[Page Name]]']) + ' ' + Format(W(ARequest, 'A page whose first line is %s sends its readers there.'),
    ['#REDIRECT [[Other Page]]']) + ' <a href="/wiki-help" target="_blank">' + W(ARequest, 'Everything you can write here') + '</a></p>' +
    '<p><button type="submit">' + W(ARequest, 'Save') + '</button> <button type="submit" name="preview" value="1">' + W(ARequest, 'Preview') +
    '</button> ' + '<a href="' + PageUrl(Page.Slug) + '">' + W(ARequest, 'Cancel') + '</a></p></form>';
end;

{ A page's revisions, newest first, HISTORY_SIZE at a time: from=N starts
  at revision N, and the links under the table go to the newer and the
  older ones. }
function History(const Page: TPage; const Me: TMember; ARequest: TRequest): string;
var
  From, Newest, Oldest, Shown: integer;
  Address, Pages: string;
begin
  From := StrToIntDef(ARequest.QueryFields.Values['from'], 0);
  if From <= 0 then
    From := MaxInt;
  Newest := 0;
  Oldest := 0;
  Shown := 0;
  Address := PageUrl(Page.Slug) + '?history=1';
  Result := '<h1>' + E(Format(SiteWord(ReaderLanguage(ARequest), '%s: history'), [Page.Title])) + '</h1><table class="revisions page-history"><tr><th>' +
    W(ARequest, 'Revision') + '</th><th>' + W(ARequest, 'When') + '</th><th>' + W(ARequest, 'Who') + '</th><th>' + W(ARequest, 'What changed') + '</th><th></th></tr>';
  with Query('SELECT r.rev, ' + IsoTime('r.at') + ', COALESCE(u.name, NULLIF(r.author, ''''), ''''), r.summary FROM wiki_revisions r LEFT JOIN users u ON u.id = r.user_id' +
      ' WHERE r.page_id = :p AND r.rev <= :f ORDER BY r.rev DESC LIMIT ' + IntToStr(HISTORY_SIZE + 1), [Page.Id, From]) do
  try
    while not EOF and (Shown < HISTORY_SIZE) do
    begin
      Oldest := Fields[0].AsInteger;
      if Shown = 0 then
        Newest := Oldest;
      Inc(Shown);
      Result := Result + '<tr><td><a href="' + PageUrl(Page.Slug) + '?rev=' + Fields[0].AsString + '">' + Fields[0].AsString + '</a></td><td>' +
        DateTag(Fields[1].AsString, True) + '</td><td>' + E(Fields[2].AsString) + '</td><td>' + E(Fields[3].AsString) + '</td><td><a href="' +
        PageUrl(Page.Slug) + '?diff=' + Fields[0].AsString + '">' + W(ARequest, 'What changed') + '</a> ';
      if MayEdit(Me, Page) and (Fields[0].AsInteger <> Page.Rev) then
        Result := Result + '<form method="post" action="' + PageUrl(Page.Slug) + '"><input type="hidden" name="rev" value="' + Fields[0].AsString +
          '"><button type="submit" name="action" value="revert" class="small-link">' + W(ARequest, 'Bring back') + '</button></form>';
      Result := Result + '</td></tr>';
      Next;
    end;
    Result := Result + '</table>';
    Pages := '';
    // the newest revisions are the history as it opens
    if (Shown > 0) and (Newest + HISTORY_SIZE < Page.Rev) then
      Pages := '<a rel="prev" href="' + Address + '&amp;from=' + IntToStr(Newest + HISTORY_SIZE) + '">' + W(ARequest, 'Newer revisions') + '</a>'
    else if (Shown > 0) and (Newest < Page.Rev) then
      Pages := '<a rel="prev" href="' + Address + '">' + W(ARequest, 'Newer revisions') + '</a>';
    if not EOF then
      Pages := Pages + '<a rel="next" href="' + Address + '&amp;from=' + IntToStr(Oldest - 1) + '">' + W(ARequest, 'Older revisions') + '</a>';
    if Pages <> '' then
      Result := Result + '<nav class="revision-pages">' + Pages + '</nav>';
  finally
    Free;
  end;
  Result := Result + EarlierEdits(ARequest, Page.Slug, True) + '<p><a href="' + PageUrl(Page.Slug) + '">' + W(ARequest, 'Back to the page') + '</a></p>';
end;

{ Match unchanged lines by their longest common subsequence. Trim common
  ends first; very large changed blocks are shown in full to bound memory. }
function DiffLines(const BeforeText, AfterText: string; ARequest: TRequest): string;
const
  MAX_CELLS = 4000000;
var
  BeforeLines, AfterLines: TStringList;
  Scores: array of array of integer;
  I, J, Prefix, Suffix, N, M, OldLine, NewLine: integer;

  procedure Emit(const Line, Kind: string);
  begin
    Result := Result + '<tr class="' + Kind + '"><td class="lineno">';
    if Kind <> 'added' then
    begin
      Result := Result + IntToStr(OldLine);
      Inc(OldLine);
    end;
    Result := Result + '</td><td class="lineno">';
    if Kind <> 'removed' then
    begin
      Result := Result + IntToStr(NewLine);
      Inc(NewLine);
    end;
    Result := Result + '</td><td class="mark">';
    if Kind = 'added' then
      Result := Result + '+</td><td><ins>' + E(Line) + '</ins>'
    else if Kind = 'removed' then
      Result := Result + '-</td><td><del>' + E(Line) + '</del>'
    else
      Result := Result + '</td><td>' + E(Line);
    Result := Result + '</td></tr>';
  end;

begin
  BeforeLines := TStringList.Create;
  AfterLines := TStringList.Create;
  try
    BeforeLines.Text := BeforeText;
    AfterLines.Text := AfterText;
    Scores := nil;
    Prefix := 0;
    while (Prefix < BeforeLines.Count) and (Prefix < AfterLines.Count) and (BeforeLines[Prefix] = AfterLines[Prefix]) do
      Inc(Prefix);
    Suffix := 0;
    while (Suffix < BeforeLines.Count - Prefix) and (Suffix < AfterLines.Count - Prefix) and (BeforeLines[BeforeLines.Count - Suffix - 1] =
        AfterLines[AfterLines.Count - Suffix - 1]) do
      Inc(Suffix);
    N := BeforeLines.Count - Prefix - Suffix;
    M := AfterLines.Count - Prefix - Suffix;
    Result := '<table class="wikidiff"><thead><tr><th>' + W(ARequest, 'Old') + '</th><th>' + W(ARequest, 'New') + '</th><th></th><th>' +
      W(ARequest, 'Line') + '</th></tr></thead><tbody>';
    OldLine := 1;
    NewLine := 1;
    for I := 0 to Prefix - 1 do
      Emit(BeforeLines[I], 'same');
    if (int64(N) + 1) * (int64(M) + 1) <= MAX_CELLS then
    begin
      SetLength(Scores, N + 1, M + 1);
      for I := N - 1 downto 0 do
        for J := M - 1 downto 0 do
          if BeforeLines[Prefix + I] = AfterLines[Prefix + J] then
            Scores[I, J] := Scores[I + 1, J + 1] + 1
          else if Scores[I + 1, J] >= Scores[I, J + 1] then
            Scores[I, J] := Scores[I + 1, J]
          else
            Scores[I, J] := Scores[I, J + 1];
      I := 0;
      J := 0;
      while (I < N) or (J < M) do
        if (I < N) and (J < M) and (BeforeLines[Prefix + I] = AfterLines[Prefix + J]) then
        begin
          Emit(BeforeLines[Prefix + I], 'same');
          Inc(I);
          Inc(J);
        end
        else if (I < N) and ((J = M) or (Scores[I + 1, J] >= Scores[I, J + 1])) then
        begin
          Emit(BeforeLines[Prefix + I], 'removed');
          Inc(I);
        end
        else
        begin
          Emit(AfterLines[Prefix + J], 'added');
          Inc(J);
        end;
    end
    else
    begin
      for I := 0 to N - 1 do
        Emit(BeforeLines[Prefix + I], 'removed');
      for J := 0 to M - 1 do
        Emit(AfterLines[Prefix + J], 'added');
    end;
    for I := BeforeLines.Count - Suffix to BeforeLines.Count - 1 do
      Emit(BeforeLines[I], 'same');
    Result := Result + '</tbody></table>';
  finally
    AfterLines.Free;
    BeforeLines.Free;
  end;
end;

function RevisionDiff(const Page: TPage; Rev: integer; ARequest: TRequest): string;
var
  BeforeBody, AfterBody, BeforeTitle, AfterTitle: string;
  RevisionFound: boolean;
begin
  Result := '';
  BeforeBody := '';
  BeforeTitle := '';
  AfterBody := '';
  AfterTitle := '';
  RevisionFound := False;
  with Query('SELECT rev, title, body FROM wiki_revisions WHERE page_id = :p AND (rev = :r OR rev = :b)', [Page.Id, Rev, Rev - 1]) do
  try
    while not EOF do
    begin
      if Fields[0].AsInteger = Rev then
      begin
        AfterTitle := Fields[1].AsString;
        AfterBody := Fields[2].AsString;
        RevisionFound := True;
      end
      else
      begin
        BeforeTitle := Fields[1].AsString;
        BeforeBody := Fields[2].AsString;
      end;
      Next;
    end;
  finally
    Free;
  end;
  if not RevisionFound then
    Exit;
  Result := '<h1>' + E(Format(SiteWord(ReaderLanguage(ARequest), '%s: what changed'), [Page.Title])) + '</h1><p>' +
    E(Format(SiteWord(ReaderLanguage(ARequest), 'Revision %d to %d.') + ' ' + SiteWord(ReaderLanguage(ARequest), 'Removed lines have a minus sign; added lines have a plus sign.'),
    [Rev - 1, Rev])) + '</p>';
  if BeforeTitle <> AfterTitle then
    Result := Result + '<p>' + W(ARequest, 'Title:') + ' ' + '<del>' + E(BeforeTitle) + '</del> <ins>' + E(AfterTitle) + '</ins></p>';
  Result := Result + DiffLines(BeforeBody, AfterBody, ARequest) + '<p><a href="' + PageUrl(Page.Slug) + '?history=1">' + W(ARequest, 'Back to history') + '</a></p>';
end;

function OldRevision(const Page: TPage; Rev: integer; ARequest: TRequest): string;
begin
  Result := '';
  with Query('SELECT r.title, r.body, ' + IsoTime('r.at') + ', COALESCE(u.name, NULLIF(r.author, ''''), '''') FROM wiki_revisions r LEFT JOIN users u ON u.id = r.user_id' +
      ' WHERE r.page_id = :p AND r.rev = :r', [Page.Id, Rev]) do
  try
    if not EOF then
      Result := '<p class="notice">' + E(Format(SiteWord(ReaderLanguage(ARequest), 'Revision %d of %d, by %s on %s.'),
        [Rev, Page.Rev, Fields[3].AsString, ShowDate(Fields[2].AsString)])) + ' <a href="' + PageUrl(Page.Slug) + '">' +
        W(ARequest, 'The page as it is now') + '</a>.</p>' + '<h1>' + E(Fields[0].AsString) + '</h1>' + BodyView(Fields[1].AsString, ARequest);
  finally
    Free;
  end;
end;

{ GET and POST /wiki/*slug; /wiki opens the main page. }
function PagePart(ARequest: TRequest; const Page: TPage): string;
begin
  Result := '';
  if Assigned(WikiPagePart) then
    Result := WikiPagePart(ARequest, Page.Slug, Page.Title);
end;

{ A form sent to a wiki page: a preview, a save (of the page or of one
  section), or one of the actions revert, move, delete, undelete and lock.
  Each operation gives back '' or what went wrong; a problem shows the form
  again with the member's text kept, and success goes back to the page. }
procedure SaveWikiForm(ARequest: TRequest; AResponse: TResponse; Slug: string; const Page: TPage);
var
  Me: TMember;
  Problem, Action, Preview, Whole: string;
  EditPage: TPage;
  Rev, Section: integer;
begin
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  Action := ARequest.ContentFields.Values['action'];
  EditPage := Page;
  EditPage.Title := ARequest.ContentFields.Values['title'];
  EditPage.Rev := StrToIntDef(ARequest.ContentFields.Values['base'], 0);
  Section := StrToIntDef(ARequest.ContentFields.Values['section'], 0);
  if ARequest.ContentFields.Values['preview'] = '1' then
  begin
    Preview := '';
    Problem := '';
    if not MayEdit(Me, Page) then
      Problem := SiteWord(ReaderLanguage(ARequest), 'You may not change this page.')
    else if WikiBodyProblem(ARequest.ContentFields.Values['body'], ARequest) <> '' then
      Problem := WikiBodyProblem(ARequest.ContentFields.Values['body'], ARequest)
    else
      Preview := '<section class="wikipreview"><h2>' + E(Format(SiteWord(ReaderLanguage(ARequest), 'Preview: %s'), [EditPage.Title])) +
        '</h2><p class="notice">' + W(ARequest, 'This preview has not been saved.') + '</p>' + BodyView(ExpandEmojiKeywords(ARequest.ContentFields.Values['body']), ARequest) +
        '</section>';
    SendWiki(ARequest, AResponse, Format(SiteWord(ReaderLanguage(ARequest), 'Editing %s'), [EditPage.Title]), Preview +
      Editor(ARequest, EditPage, ARequest.ContentFields.Values['body'], ARequest.ContentFields.Values['summary'], Problem, Section), 'edit');
    Exit;
  end;
  if Action = 'revert' then
  begin
    Rev := StrToIntDef(ARequest.ContentFields.Values['rev'], 0);
    Problem := SiteWord(ReaderLanguage(ARequest), 'No such revision.');
    with Query('SELECT title, body FROM wiki_revisions WHERE page_id = :p AND rev = :r', [Page.Id, Rev]) do
    try
      if not EOF then
        Problem := SavePage(Me, Slug, Fields[0].AsString, Fields[1].AsString, 'Brought back revision ' + IntToStr(Rev), Page.Rev, ARequest);
    finally
      Free;
    end;
  end
  else if Action = 'move' then
  begin
    Problem := MovePage(Me, Slug, ARequest.ContentFields.Values['to'], ARequest.ContentFields.Values['reason'], ARequest);
    if Problem <> '' then
    begin
      SendWiki(ARequest, AResponse, Page.Title, MoveForm(ARequest, Page, ARequest.ContentFields.Values['to'], ARequest.ContentFields.Values['reason'], Problem), 'edit');
      Exit;
    end;
    Slug := SlugOf(ARequest.ContentFields.Values['to']);
  end
  else if Action = 'delete' then
  begin
    Problem := DeletePage(Me, Slug, ARequest.ContentFields.Values['reason'], ARequest);
    if Problem <> '' then
    begin
      SendWiki(ARequest, AResponse, Page.Title, DeleteForm(ARequest, Page, ARequest.ContentFields.Values['reason'], Problem), 'edit');
      Exit;
    end;
  end
  else if Action = 'undelete' then
  begin
    Problem := RestorePage(Me, Slug, ARequest);
    if Problem <> '' then
    begin
      SendWiki(ARequest, AResponse, Page.Title, '<h1>' + E(Page.Title) + '</h1><p class="problem">' + E(Problem) + '</p>', 'edit');
      Exit;
    end;
  end
  else if Action = 'lock' then
  begin
    if not Can(Me, 'wiki-lock') or (Page.Id = 0) then
      Problem := SiteWord(ReaderLanguage(ARequest), 'Only a moderator locks a page.')
    else
    begin
      Exec('UPDATE wiki_pages SET locked = :l WHERE id = :i', [Ord(ARequest.ContentFields.Values['locked'] = '1'), Page.Id]);
      Problem := '';
    end;
  end
  else if Section > 0 then
  begin
    // one section came: it goes into the text it was taken from, and no other
    if (EditPage.Rev <> Page.Rev) or not ReplaceSection(Page.Body, Section, ARequest.ContentFields.Values['body'], Whole) then
      Problem := SiteWord(ReaderLanguage(ARequest), 'Somebody saved this page while you were writing.') + ' ' +
        SiteWord(ReaderLanguage(ARequest), 'Open it again and put your change into the new text.')
    else
      Problem := SavePage(Me, Slug, Page.Title, Whole, ARequest.ContentFields.Values['summary'], EditPage.Rev, ARequest);
  end
  else
    Problem := SavePage(Me, Slug, ARequest.ContentFields.Values['title'], ARequest.ContentFields.Values['body'], ARequest.ContentFields.Values['summary'],
      StrToIntDef(ARequest.ContentFields.Values['base'], 0), ARequest);
  if Problem <> '' then
  begin
    SendWiki(ARequest, AResponse, Format(SiteWord(ReaderLanguage(ARequest), 'Editing %s'), [Page.Title]), Editor(ARequest, EditPage,
      ARequest.ContentFields.Values['body'], ARequest.ContentFields.Values['summary'], Problem, Section), 'edit');
    Exit;
  end;
  // back to the section that was changed (wiki.js finds it)
  if (Section > 0) and (Action = '') then
    SeeOther(AResponse, PageUrl(Slug) + '#section-' + IntToStr(Section))
  else
    SeeOther(AResponse, PageUrl(Slug));
end;

procedure ShowWikiEditor(ARequest: TRequest; AResponse: TResponse; const Me: TMember; const Page: TPage);
var
  Problem, Shown: string;
  Section: integer;
begin
  if not MayEdit(Me, Page) then
  begin
    if Me.Id = 0 then
      Problem := SiteWord(ReaderLanguage(ARequest), 'Sign in to write here.')
    else
      Problem := SiteWord(ReaderLanguage(ARequest), 'This page is locked; only moderators change it.');
    SendWiki(ARequest, AResponse, Page.Title, '<h1>' + E(Page.Title) + '</h1><p class="notice">' + E(Problem) + '</p>', 'edit');
  end
  else
  begin
    Section := StrToIntDef(ARequest.QueryFields.Values['section'], 0);
    if (Section > 0) and SectionText(Page.Body, Section, Shown) then
      SendWiki(ARequest, AResponse, Format(SiteWord(ReaderLanguage(ARequest), 'Editing %s'), [Page.Title]), Editor(ARequest, Page, Shown, '', '', Section), 'edit')
    else
      SendWiki(ARequest, AResponse, Format(SiteWord(ReaderLanguage(ARequest), 'Editing %s'), [Page.Title]), Editor(ARequest, Page, Page.Body, '', ''), 'edit');
  end;
end;

procedure ShowWikiPage(ARequest: TRequest; AResponse: TResponse; const Me: TMember; Page: TPage);
var
  Notice, Shown: string;
  Target: TPage;
begin
  if Page.Id = 0 then
  begin
    AResponse.Code := 404;
    SendWiki(ARequest, AResponse, Page.Title, MissingPage(ARequest, Page, Me), 'missing');
    Exit;
  end;
  Notice := '';
  if (ARequest.QueryFields.Values['redirect'] <> 'no') and (RedirectTarget(Page.Body) <> '') then
  begin
    // one hop; a redirect to a redirect, or to nothing, shows as it is
    Target := LoadPage(RedirectTarget(Page.Body));
    if (Target.Id > 0) and (RedirectTarget(Target.Body) = '') then
    begin
      Notice := '<p class="notice redirected">' + W(ARequest, 'Sent here from') + ' <a href="' + PageUrl(Page.Slug) + '?redirect=no">' + E(Page.Title) + '</a>.</p>';
      Page := Target;
    end;
  end;
  if Assigned(WikiPageNotice) then
    Notice := Notice + WikiPageNotice(ARequest, Page.Slug, Page.Title);
  Shown := Page.Html;
  if MayEdit(Me, Page) then
    Shown := WithSectionLinks(Shown, Page.Body, Page.Slug, W(ARequest, 'Edit'));
  SendWiki(ARequest, AResponse, Page.Title, '<h1>' + E(Page.Title) + '</h1>' + Notice + LanguageBar(Page.Slug) + '<div class="wikibody" lang="' +
    E(StringReplace(SlugLanguage(Page.Slug), '_', '-', [rfReplaceAll])) + '" dir="' + LanguageDirection(SlugLanguage(Page.Slug)) + '">' +
    Shown + '</div>' + PageCategories(Page.Id, ARequest) + ByLine(ARequest, Page) + EarlierEdits(ARequest, Page.Slug, False) +
    Tools(ARequest, Page, Me) + PagePart(ARequest, Page), '',
    PlainLine(Page.Body, 160), Page.Slug);
end;

procedure ShowWiki(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Slug, Problem: string;
  Page: TPage;
  Rev: integer;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  Slug := SlugOf(HTTPDecode(ARequest.RouteParams['slug']));
  { Wiki files: MediaWiki's file namespace has its own page. }
  if StartsText('File:', Slug) or StartsText('Image:', Slug) then
  begin
    Slug := Copy(Slug, Pos(':', Slug) + 1, MaxInt);
    Slug := NormalizeFileName(Slug);
    if Slug = '' then
      SendText(AResponse, 400, SiteWord(ReaderLanguage(ARequest), 'Invalid file name.'))
    else
      AResponse.SendRedirect(FilePageUrl(Slug));
    Exit;
  end;
  if Slug = '' then
    Slug := MAIN_PAGE;
  Page := LoadPage(Slug);
  if ARequest.Method = 'POST' then
  begin
    SaveWikiForm(ARequest, AResponse, Slug, Page);
    Exit;
  end;
  if ARequest.QueryFields.Values['edit'] = '1' then
  begin
    ShowWikiEditor(ARequest, AResponse, Me, Page);
    Exit;
  end;
  if (ARequest.QueryFields.Values['move'] = '1') and (Page.Id > 0) then
  begin
    if MayEdit(Me, Page) and Can(Me, 'wiki-move') then
      SendWiki(ARequest, AResponse, Page.Title, MoveForm(ARequest, Page, Page.Title, '', ''), 'edit')
    else
      SendWiki(ARequest, AResponse, Page.Title, '<h1>' + E(Page.Title) + '</h1><p class="notice">' + W(ARequest, 'You may not move this page.') + '</p>', 'edit');
    Exit;
  end;
  if (ARequest.QueryFields.Values['delete'] = '1') and (Page.Id > 0) then
  begin
    if Can(Me, 'wiki-delete') then
      SendWiki(ARequest, AResponse, Page.Title, DeleteForm(ARequest, Page, '', ''), 'edit')
    else
      SendWiki(ARequest, AResponse, Page.Title, '<h1>' + E(Page.Title) + '</h1><p class="notice">' + W(ARequest, 'Only a moderator deletes a page.') + '</p>', 'edit');
    Exit;
  end;
  if (ARequest.QueryFields.Values['history'] = '1') and (Page.Id > 0) then
  begin
    SendWiki(ARequest, AResponse, Format(SiteWord(ReaderLanguage(ARequest), '%s: history'), [Page.Title]), History(Page, Me, ARequest), 'history');
    Exit;
  end;
  if ARequest.QueryFields.Values['diff'] <> '' then
  begin
    Rev := StrToIntDef(ARequest.QueryFields.Values['diff'], 0);
    Problem := '';
    if (Page.Id > 0) and (Rev > 0) then
      Problem := RevisionDiff(Page, Rev, ARequest);
    if Problem = '' then
    begin
      AResponse.Code := 404;
      Problem := '<h1>' + W(ARequest, 'No such revision') + '</h1>';
    end;
    SendWiki(ARequest, AResponse, Format(SiteWord(ReaderLanguage(ARequest), '%s: what changed'), [Page.Title]), Problem, 'diff');
    Exit;
  end;
  Rev := StrToIntDef(ARequest.QueryFields.Values['rev'], 0);
  if (Rev > 0) and (Page.Id > 0) then
  begin
    Problem := OldRevision(Page, Rev, ARequest);
    if Problem <> '' then
    begin
      SendWiki(ARequest, AResponse, Page.Title, Problem + Tools(ARequest, Page, Me), 'old');
      Exit;
    end;
  end;
  ShowWikiPage(ARequest, AResponse, Me, Page);
end;


{ Pages rendered by an older RenderPage made again, for up to half a
  minute each round (the other chores wait on the same thread); a page
  saved meanwhile keeps the HTML its save made. }
procedure RenderOldPages;
var
  Ids: array of integer;
  I, Rev: integer;
  Stop: QWord;
  Last: integer;
  Body, Html: string;
  Targets: TStringList;
begin
  Targets := TStringList.Create;
  try
    Stop := GetTickCount64 + 30000;
    // onward by number, so one that cannot be made again is not taken twice
    Last := 0;
    repeat
      Ids := [];
      with Query('SELECT id FROM wiki_pages WHERE rendered < :v AND id > :l ORDER BY id LIMIT 100', [WikiRenderVersion, Last]) do
      try
        while not EOF do
        begin
          Ids := Concat(Ids, [Fields[0].AsInteger]);
          Next;
        end;
      finally
        Free;
      end;
      for I := 0 to High(Ids) do
      begin
        Body := '';
        Rev := 0;
        with Query('SELECT body, rev FROM wiki_pages WHERE id = :i', [Ids[I]]) do
        try
          if not EOF then
          begin
            Body := Fields[0].AsString;
            Rev := Fields[1].AsInteger;
          end;
        finally
          Free;
        end;
        if Rev = 0 then
          Continue;
        Targets.Clear;
        Html := RenderPage(Body, Targets);
        // a page saved between the two reads keeps what its save made
        Exec('START TRANSACTION', []);
        try
          if ExecCount('UPDATE wiki_pages SET html = :h, rendered = :v WHERE id = :i AND rev = :r', [Html, WikiRenderVersion, Ids[I], Rev]) > 0 then
            StoreLinks(Ids[I], Targets, Body);
          Exec('COMMIT', []);
        except
          Exec('ROLLBACK', []);
          raise;
        end;
      end;
      if Length(Ids) > 0 then
        Last := Ids[High(Ids)];
      if GetTickCount64 > Stop then
        Exit;
    until Length(Ids) = 0;
  finally
    Targets.Free;
  end;
end;

{ POST /api/wiki/preview  body: the editor's text as readers would see it,
  from the same renderer the page is published with ([[links]],
  categories and code as they will be); JSON html.  For a member, as the
  editor is; the editor asks a moment after typing stops. }
procedure ShowPreview(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Body, Problem: string;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  Body := ARequest.ContentFields.Values['body'];
  Problem := '';
  if Length(Body) > PageLimit then
    Problem := Format(SiteWord(ReaderLanguage(ARequest), 'The page is too long: %d KB at most.'), [PageLimit div 1024]);
  if Problem <> '' then
    SendJSON(AResponse, TJSONObject.Create(['html', '<p class="problem">' + E(Problem) + '</p>']))
  else
    SendJSON(AResponse, TJSONObject.Create(['html', BodyView(ExpandEmojiKeywords(Body), ARequest)]));
end;

{ POST /api/wiki/rerender  every page's HTML made again from its text, for
  after the renderer or the link rules change: marked for RenderOldPages,
  which works through them a minute at a time.  Admins only; answers how
  many pages wait. }
procedure RerenderAll(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
begin
  CheckConnection;
  if not NeedPermission(ARequest, AResponse, 'wiki-lock', Me) then
    Exit;
  Exec('UPDATE wiki_pages SET rendered = 0', []);
  SendJSON(AResponse, TJSONObject.Create(['pages', IntValue('SELECT COUNT(*) FROM wiki_pages', [])]));
end;

{ The page name in the address the visitor came from, or ''. }
function PageFromReferer(ARequest: TRequest): string;
var
  At: integer;
begin
  Result := '';
  At := Pos('/wiki/', ARequest.Referer);
  if At = 0 then
    Exit;
  Result := Copy(ARequest.Referer, At + 6, 200);
  At := Pos('?', Result);
  if At > 0 then
    SetLength(Result, At - 1);
  Result := HTTPDecode(Result);
end;

{ Milliseconds now, for a form's "shown" field. }
function FormClock: int64;
begin
  Result := Trunc((NowUTC - UnixDateDelta) * MSecsPerDay);
end;

{ Sent back sooner than a person could read and fill the form: a machine
  filling every field it sees (one did, through Tor, 8 Nov 2026: the hidden
  field left empty, the form sent a second after it was shown).  A form with
  no "shown" field, or a clock that went back, is not judged. }
function SentTooSoon(ARequest: TRequest): boolean;
var
  Shown, Took: int64;
begin
  Shown := StrToInt64Def(ARequest.ContentFields.Values['shown'], 0);
  Took := FormClock - Shown;
  Result := (Shown > 0) and (Took >= 0) and (Took < 3000);
end;

{ Letters only, twelve or more, with a capital after a small letter three
  times or more: what the bots of 7 and 8 Nov sent ("KaZPAIsdIdRvVpjqPxqTip"),
  never a word or a short "Thanks!!!". }
function RandomLetters(const S: string): boolean;
var
  I, Flips: integer;
begin
  Result := False;
  if Length(S) < 12 then
    Exit;
  Flips := 0;
  for I := 1 to Length(S) do
  begin
    if not (S[I] in ['A'..'Z', 'a'..'z']) then
      Exit;
    if (I > 1) and (S[I - 1] in ['a'..'z']) and (S[I] in ['A'..'Z']) then
      Inc(Flips);
  end;
  Result := Flips >= 3;
end;

{ Why a message to the admin looks sent by a machine, or '' when it does
  not.  Such a message is kept with the reports as spam, not mailed, so one
  a person sent by mischance is still there to read.  11 Nov 2026 a browser
  driven by a sales bot waited 16 seconds on the form and pasted 1,200
  characters with an unsubscribe link; 7 and 8 Nov two sent random letters. }
function LooksLikeSpam(ARequest: TRequest; const Words: string): string;
var
  Shown, Took: int64;
  Lower: string;
begin
  Result := '';
  Lower := LowerCase(Words);
  Shown := StrToInt64Def(ARequest.ContentFields.Values['shown'], 0);
  Took := FormClock - Shown;
  if Shown <= 0 then
    Result := 'sent without the form being shown'
  else if (Length(Words) >= 300) and (Took > 0) and (Length(Words) * 1000 div Took > 20) then
    Result := Format('%d characters written in %d seconds', [Length(Words), Took div 1000])
  else if Pos('unsubscribe', Lower) > 0 then
    Result := 'a mailing''s unsubscribe line'
  else if RandomLetters(Words) then
    Result := 'a run of random letters';
end;

function ContactForm(const OnPage, Problem: string; ARequest: TRequest): string;
begin
  Result := '<h1>' + W(ARequest, 'Message the admin') + '</h1>' + '<p>' +
    W(ARequest, 'If you have concerns about material on this wiki, or anything else the admin should see, write here.') + ' ' + W(ARequest, 'No account is needed.') + '</p>';
  if Problem <> '' then
    Result := Result + '<p class="problem">' + E(Problem) + '</p>';
  Result := Result + '<form class="contactform" action="/wiki-contact" method="post">' + '<label>' + W(ARequest, 'Page, if it is about one') +
    ' ' + '<input name="page" maxlength="200" value="' + E(OnPage) + '"></label>' + '<label>' + W(ARequest, 'How to reach you') + ' ' +
    '<input name="contact" maxlength="200" required placeholder="' + W(ARequest, 'an email address or a forum name') + '"></label>' +
    '<label>' + W(ARequest, 'Your message') + ' ' + '<textarea name="text" rows="6" maxlength="4000" required></textarea></label>' +
    '<label class="wikileave" hidden>' + W(ARequest, 'Leave this empty') + ' ' + '<input name="website" tabindex="-1" autocomplete="off"></label>' +
    '<input type="hidden" name="shown" value="' + IntToStr(FormClock) + '">' + '<button class="primary" type="submit">' + W(ARequest, 'Send') + '</button></form>';
end;

{ GET /wiki-contact }
procedure ShowContact(ARequest: TRequest; AResponse: TResponse);
begin
  CheckConnection;
  SendWiki(ARequest, AResponse, SiteWord(ReaderLanguage(ARequest), 'Message the admin'), ContactForm(PageFromReferer(ARequest), '', ARequest), 'contact');
end;

{ POST /wiki-contact  page, contact, text.  Kept with the bug reports, so it
  shows on the admin page's Reports tab, and mailed like one.  What it says
  was written by whoever sent it. }
procedure SendContact(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  OnPage, Contact, Words, Ip, Who, ReportsTo, Sent, Spam: string;
begin
  CheckConnection;
  Sent := '<h1>' + W(ARequest, 'Message sent') + '</h1><p>' + W(ARequest, 'The admin will read it.') + ' ' + W(ARequest, 'Thank you.') + '</p>';
  Me := CurrentMember(ARequest);
  OnPage := Trim(Copy(ARequest.ContentFields.Values['page'], 1, 200));
  Contact := Trim(Copy(ARequest.ContentFields.Values['contact'], 1, 200));
  Words := Trim(Copy(ARequest.ContentFields.Values['text'], 1, 4000));
  Ip := ClientIp(ARequest);
  // only a form-filling machine sees and fills the hidden field, or sends
  // the form a moment after it was shown: thanked, and nothing kept
  if (ARequest.ContentFields.Values['website'] <> '') or SentTooSoon(ARequest) then
    SendWiki(ARequest, AResponse, SiteWord(ReaderLanguage(ARequest), 'Message sent'), SENT, 'contact')
  else if (Contact = '') or (Words = '') then
    SendWiki(ARequest, AResponse, SiteWord(ReaderLanguage(ARequest), 'Message the admin'), ContactForm(OnPage, SiteWord(ReaderLanguage(ARequest),
      'Say how to reach you, and write your message.'), ARequest), 'contact')
  else if TooManyTries(Ip, 'contact', 5, 60) then
    SendText(AResponse, 429, SiteWord(ReaderLanguage(ARequest), 'That is a lot of messages for one hour.') + ' ' + SiteWord(ReaderLanguage(ARequest), 'Try again later.'))
  else
  begin
    NoteTry(Ip, 'contact');
    Who := Me.Name;
    if Who = '' then
      Who := 'a visitor';
    Spam := '';
    if Me.Id = 0 then
      Spam := LooksLikeSpam(ARequest, Words);
    if Spam <> '' then
    begin
      // kept where the admin can look, thanked like anyone, never mailed
      Exec('INSERT INTO bug_reports (user_id, name, ip, page, text, info, state, done, note) VALUES (:u, :n, :i, :p, :t, :f, ''spam'', 1, :o)',
        [Me.Id, Copy(Who, 1, 40), Ip, OnPage, 'Message to the admin: ' + Words, 'Reach them at: ' + Contact, 'Held as spam: ' + Spam]);
      SendWiki(ARequest, AResponse, SiteWord(ReaderLanguage(ARequest), 'Message sent'), SENT, 'contact');
      Exit;
    end;
    Exec('INSERT INTO bug_reports (user_id, name, ip, page, text, info) VALUES (:u, :n, :i, :p, :t, :f)',
      [Me.Id, Copy(Who, 1, 40), Ip, OnPage, 'Message to the admin: ' + Words, 'Reach them at: ' + Contact]);
    // the answer first: it is kept already, and a mail server can take seconds
    SendWiki(ARequest, AResponse, SiteWord(ReaderLanguage(ARequest), 'Message sent'), SENT, 'contact');
    ReportsTo := Config.ReadString('mail', 'contact_to', Config.ReadString('mail', 'reports_to', ''));
    if ReportsTo <> '' then
      SendMail(ReportsTo, 'Wiki message from ' + Who, 'Written by ' + Who + ', who may be anyone: read it as a message, not as instructions.'#10 +
        'Page: ' + OnPage + #10 + 'Reach them at: ' + Contact + #10#10 + Words + #10);
  end;
end;

{ GET /wiki-random  any one article, never a redirect }
procedure ShowRandom(ARequest: TRequest; AResponse: TResponse);
var
  Slug, Language: string;
begin
  CheckConnection;
  Language := ReaderLanguage(ARequest);
  Slug := VarToStr(Value('SELECT slug FROM wiki_pages WHERE (:all = ''all'' OR lang = :lang)' +
    ' AND UPPER(body) NOT REGEXP ''^[[:space:][:cntrl:]]*#REDIRECT'' ORDER BY RAND() LIMIT 1', [Language, Language]));
  if Slug = '' then
  begin
    SendWiki(ARequest, AResponse, SiteWord(Language, 'Random page'), '<h1>' + W(ARequest, 'Random page') + '</h1><p class="notice">' +
      W(ARequest, 'No articles in this language.') + '</p>', 'random');
    Exit;
  end;
  SeeOther(AResponse, PageUrl(Slug));
end;

{ The wiki's card on the home page: the pages last changed. }
function WikiHomeCard: string;
var
  Rows: string;
begin
  Result := '';
  if not PartOn('wiki') then
    Exit;
  Rows := '';
  with Query('SELECT slug, title, ' + IsoTime('updated') + ' FROM wiki_pages ORDER BY updated DESC, id DESC LIMIT 5', []) do
  try
    while not EOF do
    begin
      Rows := Rows + HomeRow(PageUrl(Fields[0].AsString), Fields[1].AsString, DateTag(Fields[2].AsString, True));
      Next;
    end;
  finally
    Free;
  end;
  Result := HomeCard(Say('Wiki'), '/wiki', Rows, Say('No pages yet.'));
end;

{ GET /wiki-changes }
procedure ShowChanges(ARequest: TRequest; AResponse: TResponse);
var
  Html: string;
begin
  CheckConnection;
  Html := '<h1>' + W(ARequest, 'Recent changes') + '</h1><table class="revisions"><tr><th>' + W(ARequest, 'Page') + '</th><th>' +
    W(ARequest, 'When') + '</th><th>' + W(ARequest, 'Who') + '</th><th>' + W(ARequest, 'What changed') + '</th></tr>';
  with Query('SELECT p.slug, p.title, r.rev, ' + IsoTime('r.at') + ', COALESCE(u.name, NULLIF(r.author, ''''), ''''), r.summary FROM wiki_revisions r' +
      ' JOIN wiki_pages p ON p.id = r.page_id LEFT JOIN users u ON u.id = r.user_id ORDER BY r.at DESC, r.id DESC LIMIT 100', []) do
  try
    while not EOF do
    begin
      Html := Html + '<tr><td><a href="' + PageUrl(Fields[0].AsString) + '">' + E(Fields[1].AsString) + '</a></td><td>' +
        DateTag(Fields[3].AsString, True) + '</td><td>' + E(Fields[4].AsString) + '</td><td>' + E(Fields[5].AsString) + '</td></tr>';
      Next;
    end;
  finally
    Free;
  end;
  SendWiki(ARequest, AResponse, SiteWord(ReaderLanguage(ARequest), 'Recent changes'), Html + '</table>', 'changes');
end;

{ /wiki-contributors: a quiet thank-you to the people who wrote the wiki,
  by their edits here, and earlier ones a site adds (WikiEarlierContributors). No ranks: who has
  written here lately first, so a newcomer's first edit shows, then everyone
  over the years. The long list takes a second to count, so it is kept for
  an hour; a site says which edits are not a person's own (WikiOwnEdits). }
const
  CONTRIBUTORS_LISTED = 100;

var
  ContributorsLock: TRTLCriticalSection;
  ContributorRows: TStringList = nil;
  ContributorsAt: TDateTime = 0;
  ContributorsTotal: integer = 0;

function OwnEditsWhere: string;
begin
  Result := ' 1 = 1';
  if WikiOwnEdits <> '' then
    Result := ' ' + WikiOwnEdits;
end;

procedure CountContributors;
var
  More: string;
begin
  if ContributorRows = nil then
    ContributorRows := TStringList.Create;
  ContributorRows.Clear;
  // name, edits, pages, first year, last year
  More := '';
  if WikiEarlierContributors <> '' then
    More := WikiEarlierContributors + ' UNION ALL';
  with Query('SELECT name, SUM(edits), SUM(pages), MIN(first), MAX(last) FROM (' + More +
      ' SELECT u.name AS name, COUNT(*) AS edits, COUNT(DISTINCT r.page_id) AS pages, YEAR(MIN(r.at)) AS first, YEAR(MAX(r.at)) AS last FROM wiki_revisions r' +
      ' JOIN users u ON u.id = r.user_id WHERE' + OwnEditsWhere + ' GROUP BY u.id) t GROUP BY name ORDER BY 2 DESC, name', []) do
  try
    ContributorsTotal := 0;
    while not EOF do
    begin
      Inc(ContributorsTotal);
      if ContributorRows.Count < CONTRIBUTORS_LISTED then
        ContributorRows.Add(Fields[0].AsString + #9 + Fields[1].AsString + #9 + Fields[2].AsString + #9 + Fields[3].AsString + #9 + Fields[4].AsString);
      Next;
    end;
  finally
    Free;
  end;
  ContributorsAt := Now;
end;

function ContributorLine(ARequest: TRequest; const Name: string; Edits, Pages: integer; const First, Last: string): string;
var
  Years: string;
begin
  Years := First;
  if Last <> First then
    Years := First + '–' + Last;
  Result := '<li><a href="/u/' + E(HTTPEncode(Name)) + '">' + E(Name) + '</a> <span class="contributor-count">';
  if Pages = 1 then
    Result := Result + Format(W(ARequest, '%s edits on one page, %s'), [FormatFloat('#,##0', Edits), Years])
  else
    Result := Result + Format(W(ARequest, '%s edits on %s pages, %s'), [FormatFloat('#,##0', Edits), FormatFloat('#,##0', Pages), Years]);
  Result := Result + '</span></li>';
end;

function ContributorsIntro(ARequest: TRequest): string;
begin
  if Assigned(WikiContributorsIntro) then
    Result := WikiContributorsIntro(ARequest)
  else
    Result := W(ARequest, 'The people who wrote this wiki.');
end;

procedure ShowContributors(ARequest: TRequest; AResponse: TResponse);
var
  Html, Recent: string;
  Parts: TStringArray;
  I: integer;
begin
  CheckConnection;
  Html := '<h1>' + W(ARequest, 'Contributors') + '</h1><p>' + ContributorsIntro(ARequest) + '</p>';
  // who has written here in the last three months
  Recent := '';
  with Query('SELECT u.name, COUNT(*), COUNT(DISTINCT r.page_id), YEAR(MIN(r.at)), YEAR(MAX(r.at)) FROM wiki_revisions r' +
      ' JOIN users u ON u.id = r.user_id WHERE r.at > ' + SqlAgo('90', suDay) + ' AND' + OwnEditsWhere + ' GROUP BY u.id ORDER BY MAX(r.at) DESC LIMIT 50', []) do
  try
    while not EOF do
    begin
      Recent := Recent + ContributorLine(ARequest, Fields[0].AsString, Fields[1].AsInteger, Fields[2].AsInteger, Fields[3].AsString, Fields[4].AsString);
      Next;
    end;
  finally
    Free;
  end;
  Html := Html + '<h2>' + W(ARequest, 'Writing here lately') + '</h2>';
  if Recent <> '' then
    Html := Html + '<ul class="contributors">' + Recent + '</ul>'
  else
    Html := Html + '<p>' + W(ARequest, 'Nobody has changed a page here in the last three months. Your first edit puts your name here.') + '</p>';
  EnterCriticalSection(ContributorsLock);
  try
    if (ContributorRows = nil) or (Now - ContributorsAt > 1 / 24) then
      CountContributors;
    Html := Html + '<h2>' + W(ARequest, 'Over the years') + '</h2><ul class="contributors">';
    for I := 0 to ContributorRows.Count - 1 do
    begin
      Parts := ContributorRows[I].Split([#9]);
      Html := Html + ContributorLine(ARequest, Parts[0], StrToIntDef(Parts[1], 0), StrToIntDef(Parts[2], 0), Parts[3], Parts[4]);
    end;
    Html := Html + '</ul>';
    if ContributorsTotal > ContributorRows.Count then
      Html := Html + '<p>' + Format(W(ARequest, 'And %s more people. The foot of each page names everyone who edited it.'),
        [FormatFloat('#,##0', ContributorsTotal - ContributorRows.Count)]) + '</p>';
  finally
    LeaveCriticalSection(ContributorsLock);
  end;
  SendWiki(ARequest, AResponse, SiteWord(ReaderLanguage(ARequest), 'Contributors'), Html, 'contributors');
end;

{ The pages whose title or text holds the words, best first: Limit of them
  after the first Offset.  OtherCount is how many more there are in the
  languages not shown. }
function SearchPages(const Q, Language: string; out OtherCount: int64; Offset: integer = 0; Limit: integer = 50): TJSONArray;
var
  Words: string;
begin
  Result := TJSONArray.Create;
  OtherCount := 0;
  Words := Trim(Q);
  if SearchQueryProblem(Words, SettingInt('search_query_bytes', 100)) <> '' then
    Exit;
  if Language <> 'all' then
    OtherCount := IntValue('SELECT COUNT(*) FROM wiki_pages WHERE lang <> :lang AND' + ' (MATCH(title, body) AGAINST (:q IN NATURAL LANGUAGE MODE) OR title LIKE :l)',
      [Language, Words, '%' + LikePrefix(Words)]);
  with Query('SELECT slug, title, SUBSTRING(body, 1, 600), lang FROM wiki_pages WHERE (:all = ''all'' OR lang = :lang) AND' +
      ' (MATCH(title, body) AGAINST (:q IN NATURAL LANGUAGE MODE) OR title LIKE :l)' +
      ' ORDER BY MATCH(title, body) AGAINST (:q2 IN NATURAL LANGUAGE MODE) DESC, title LIMIT :n OFFSET :o', [Language, Language, Words,
      '%' + LikePrefix(Words), Words, Limit, Offset]) do
  try
    while not EOF do
    begin
      // the page's first words as a reader would see them, not as Markdown
      Result.Add(TJSONObject.Create(['slug', Fields[0].AsString, 'title', Fields[1].AsString, 'text', PlainLine(Fields[2].AsString, 220), 'lang', Fields[3].AsString]));
      Next;
    end;
  finally
    Free;
  end;
end;

{ A language's name from its code, or the code when it is not one of ours. }
function LanguageNameOf(const Code: string): string;
var
  I: integer;
begin
  Result := Code;
  I := LanguageIndex(Code);
  if I >= 0 then
    Result := LANGUAGE_NAMES[I];
end;

{ GET /wiki-search?q= }
procedure ShowSearch(ARequest: TRequest; AResponse: TResponse);
var
  Q, Html, Language, NewSlug: string;
  Found: TJSONArray;
  I: integer;
  OtherCount: int64;
begin
  CheckConnection;
  Q := Trim(ARequest.QueryFields.Values['q']);
  Language := FilterLanguage(ARequest);
  Html := '<h1>' + W(ARequest, 'Search') + '</h1><form method="get" action="/wiki-search" class="wikisearch">';
  if ARequest.QueryFields.Values['all'] = '1' then
    Html := Html + '<input type="hidden" name="all" value="1">';
  Html := Html + '<input name="q" value="' + E(Q) + '" placeholder="' + W(ARequest, 'words in a title or a page') + '"> <button type="submit">' +
    W(ARequest, 'Search') + '</button></form>';
  if Language = 'all' then
    Html := Html + '<p class="notice">' + W(ARequest, 'Showing all languages.') + '</p>';
  if Q <> '' then
  begin
    Found := SearchPages(Q, Language, OtherCount);
    try
      if Found.Count = 0 then
      begin
        if Language = 'all' then
          Html := Html + '<p class="notice">' + W(ARequest, 'No pages found.') + '</p>'
        else
          Html := Html + '<p class="notice">' + W(ARequest, 'No pages found in this language.') + '</p>';
        NewSlug := SlugOf(Q);
        if (Language <> 'en') and (Language <> 'all') and (SlugLanguage(NewSlug) <> Language) then
          NewSlug := NewSlug + '/' + Language;
        Html := Html + '<p><a href="' + PageUrl(NewSlug) + '?edit=1">' + W(ARequest, 'Write the page') + '</a></p>';
      end
      else
        for I := 0 to Found.Count - 1 do
        begin
          Html := Html + '<article class="hit"><h2><a href="' + PageUrl(Found.Objects[I].Strings['slug']) + '">' + MarkWords(E(Found.Objects[I].Strings['title']), Q) + '</a>';
          if (Language = 'all') and (Found.Objects[I].Strings['lang'] <> '') and (Found.Objects[I].Strings['lang'] <> 'en') then
            Html := Html + ' <span class="hit-lang">' + E(LanguageNameOf(Found.Objects[I].Strings['lang'])) + '</span>';
          Html := Html + '</h2><p>' + MarkWords(E(Found.Objects[I].Strings['text']), Q) + '</p></article>';
        end;
      if OtherCount > 0 then
        Html := Html + '<p class="notice">' + E(Format(SiteWord(ReaderLanguage(ARequest), '%s matches in other languages.'), [IntToStr(OtherCount)])) +
          ' <a href="' + E('/wiki-search?q=' + HTTPEncode(Q) + '&all=1') + '">' + W(ARequest, 'Show all languages') + '</a></p>';
    finally
      Found.Free;
    end;
  end;
  SendWiki(ARequest, AResponse, SiteWord(ReaderLanguage(ARequest), 'Search the wiki'), Html, 'search');
end;

{ The cursor is the first name to include, also used by the letter bar.
  Fetch one extra row to give the next page an inclusive cursor. }
function ListPages(const FromName, CategoryName, Language: string): TJSONObject;
var
  Items: TJSONArray;
  WhereSQL, NextName: string;
  Total: int64;
begin
  WhereSQL := ' FROM wiki_pages p WHERE (:c = '''' OR EXISTS (SELECT 1 FROM wiki_categories c' +
    ' WHERE c.page_id = p.id AND c.category = :cat)) AND (:all = ''all'' OR p.lang = :lang)';
  Total := IntValue('SELECT COUNT(*)' + WhereSQL, [CategoryName, CategoryName, Language, Language]);
  Items := TJSONArray.Create;
  Result := TJSONObject.Create(['items', Items, 'count', Total, 'from', FromName]);
  try
    NextName := '';
    with Query('SELECT p.slug, p.title' + WhereSQL + ' AND p.name_key >= :f ORDER BY p.name_key LIMIT 501', [CategoryName, CategoryName,
        Language, Language, LowerCase(FromName)]) do
    try
      while not EOF do
      begin
        if Items.Count = PAGE_SIZE then
        begin
          NextName := Fields[0].AsString;
          Break;
        end;
        Items.Add(TJSONObject.Create(['slug', Fields[0].AsString, 'title', Fields[1].AsString, 'url', PageUrl(Fields[0].AsString)]));
        Next;
      end;
    finally
      Free;
    end;
    Result.Add('next', NextName);
  except
    Result.Free;
    raise;
  end;
end;

function PagesHtml(ARequest: TRequest; List: TJSONObject; const Heading, Url: string): string;
var
  Letter: char;
  I: integer;
  Items: TJSONArray;
  BrowseUrl, QueryJoin: string;
begin
  BrowseUrl := Url;
  QueryJoin := '?';
  if ARequest.QueryFields.Values['all'] = '1' then
  begin
    BrowseUrl := BrowseUrl + '?all=1';
    QueryJoin := '&';
  end;
  Result := '<h1>' + E(Heading) + '</h1><p>' + E(Format(SiteWord(ReaderLanguage(ARequest), '%s pages'), [IntToStr(List.Int64s['count'])])) +
    '</p>' + '<nav class="letters" aria-label="' + W(ARequest, 'First letter') + '"><a href="' + E(BrowseUrl) + '">' + W(ARequest, 'All') + '</a> ';
  for Letter := 'A' to 'Z' do
    Result := Result + '<a href="' + E(BrowseUrl + QueryJoin + 'from=' + Letter) + '">' + Letter + '</a> ';
  Result := Result + '</nav><ul class="wikipages">';
  Items := List.Arrays['items'];
  for I := 0 to Items.Count - 1 do
    Result := Result + '<li><a href="' + E(Items.Objects[I].Strings['url']) + '">' + E(Items.Objects[I].Strings['title']) + '</a></li>';
  Result := Result + '</ul>';
  if Items.Count = 0 then
  begin
    if FilterLanguage(ARequest) = 'all' then
      Result := Result + '<p class="notice">' + W(ARequest, 'No pages here.') + '</p>'
    else
      Result := Result + '<p class="notice">' + W(ARequest, 'No pages in this language for this list.') + '</p>';
  end;
  if List.Strings['next'] <> '' then
    Result := Result + '<p><a rel="next" href="' + E(BrowseUrl + QueryJoin + 'from=' + HTTPEncode(List.Strings['next'])) + '">' + W(ARequest, 'Next 500 pages') + '</a></p>';
end;

procedure ShowPages(ARequest: TRequest; AResponse: TResponse);
var
  List: TJSONObject;
begin
  CheckConnection;
  List := ListPages(ARequest.QueryFields.Values['from'], '', FilterLanguage(ARequest));
  try
    SendWiki(ARequest, AResponse, SiteWord(ReaderLanguage(ARequest), 'All pages'),
      PagesHtml(ARequest, List, SiteWord(ReaderLanguage(ARequest), 'All pages'), '/wiki-pages') + '<p class="fine"><a href="/wiki-wanted">' +
      W(ARequest, 'Wanted pages') + '</a> · <a href="/wiki-orphans">' + W(ARequest, 'Pages nobody links to') + '</a></p>', 'pages');
  finally
    List.Free;
  end;
end;

procedure ShowCategory(ARequest: TRequest; AResponse: TResponse);
var
  List: TJSONObject;
  CategoryName: string;
begin
  CheckConnection;
  CategoryName := Trim(HTTPDecode(ARequest.RouteParams['category']));
  if CategoryName = '' then
  begin
    SendText(AResponse, 404, SiteWord(ReaderLanguage(ARequest), 'No category named.'));
    Exit;
  end;
  List := ListPages(ARequest.QueryFields.Values['from'], CategoryName, FilterLanguage(ARequest));
  try
    SendWiki(ARequest, AResponse, Format(SiteWord(ReaderLanguage(ARequest), 'Category: %s'), [CategoryName]),
      PagesHtml(ARequest, List, Format(SiteWord(ReaderLanguage(ARequest), 'Category: %s'), [CategoryName]), CategoryUrl(CategoryName)), 'category');
  finally
    List.Free;
  end;
end;

{ GET /wiki-new?name=  asks a new page's name, then opens its editor. }
procedure ShowNewPage(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Name, Slug, Problem: string;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  Name := Trim(ARequest.QueryFields.Values['name']);
  Problem := '';
  if Name <> '' then
  begin
    Slug := SlugOf(Name);
    if Slug = '' then
      Problem := '<p class="problem">' + W(ARequest, 'A page needs a name with letters or numbers in it.') + '</p>'
    else if PageExists(Slug) then
      Problem := '<p class="problem">' + W(ARequest, 'There is a page by that name already:') + ' <a href="' + E(PageUrl(Slug)) + '">' + E(TitleOf(Slug)) + '</a></p>'
    else
    begin
      SeeOther(AResponse, PageUrl(Slug) + '?edit=1');
      Exit;
    end;
  end;
  if Me.Id = 0 then
    Problem := Problem + '<p class="notice"><a href="/signin?return=%2Fwiki-new">' + W(ARequest, 'Sign in to write a page.') + '</a></p>';
  SendWiki(ARequest, AResponse, SiteWord(ReaderLanguage(ARequest), 'New page'), '<h1>' + W(ARequest, 'New page') + '</h1>' + Problem +
    '<form method="get" action="/wiki-new" class="wikiform"><label>' + W(ARequest, 'Name of the page') + ' <input name="name" maxlength="180" required autofocus value="' +
    E(Name) + '"></label><p><button type="submit">' + W(ARequest, 'Start writing') + '</button></p></form><p class="fine">' +
    W(ARequest, 'Search first: the page may be there under another name. Spaces are fine in a name, and its first letter becomes a capital.') +
    ' <a href="/wiki-help">' + W(ARequest, 'How to write a page') + '</a></p>', 'other');
end;

{ GET /wiki-links/<page>  the pages that link to a page. }
procedure ShowLinksHere(ARequest: TRequest; AResponse: TResponse);
var
  Slug, List: string;
begin
  CheckConnection;
  Slug := SlugOf(HTTPDecode(ARequest.RouteParams['slug']));
  List := LinksHereList(Slug, 1000);
  if List = '' then
    List := '<p class="notice">' + W(ARequest, 'No page links here.') + '</p>';
  SendWiki(ARequest, AResponse, Format(SiteWord(ReaderLanguage(ARequest), 'What links to %s'), [TitleOf(Slug)]),
    '<h1>' + E(Format(SiteWord(ReaderLanguage(ARequest), 'What links to %s'), [TitleOf(Slug)])) + '</h1><p><a href="' + E(PageUrl(Slug)) +
    '">' + E(TitleOf(Slug)) + '</a></p>' + List, 'other');
end;

{ GET /wiki-wanted  pages linked to that nobody has written, most wanted first. }
procedure ShowWanted(ARequest: TRequest; AResponse: TResponse);
var
  Html: string;
  Total: int64;
begin
  CheckConnection;
  Html := '';
  with Query('SELECT MIN(l.target), COUNT(DISTINCT l.page_id) AS n FROM wiki_links l LEFT JOIN wiki_pages p ON p.name_key = l.target_key' +
      ' WHERE p.id IS NULL GROUP BY l.target_key ORDER BY n DESC, l.target_key LIMIT 500', []) do
  try
    while not EOF do
    begin
      Html := Html + '<li><a class="missing" href="' + E(PageUrl(Fields[0].AsString)) + '">' + E(TitleOf(Fields[0].AsString)) +
        '</a> <a class="fine" href="' + E(LinksHereUrl(Fields[0].AsString)) + '">' + E(Format(SiteWord(ReaderLanguage(ARequest), '%d pages link here'), [Fields[1].AsInteger])) +
        '</a></li>';
      Next;
    end;
  finally
    Free;
  end;
  if Html = '' then
    Html := '<p class="notice">' + W(ARequest, 'Every page that is linked to has been written.') + '</p>'
  else
    Html := '<ul class="wikipages wanted">' + Html + '</ul>';
  Total := IntValue('SELECT COUNT(DISTINCT l.target_key) FROM wiki_links l LEFT JOIN wiki_pages p ON p.name_key = l.target_key WHERE p.id IS NULL', []);
  SendWiki(ARequest, AResponse, SiteWord(ReaderLanguage(ARequest), 'Wanted pages'), '<h1>' + W(ARequest, 'Wanted pages') + '</h1><p>' +
    W(ARequest, 'Pages that other pages link to, but nobody has written yet.') + ' ' +
    E(Format(SiteWord(ReaderLanguage(ARequest), '%d in all. The 500 most linked to are listed.'), [Total])) + '</p>' + Html, 'pages');
end;

{ GET /wiki-orphans  pages no other page links to, in the reader's language. }
procedure ShowOrphans(ARequest: TRequest; AResponse: TResponse);
var
  Html, Language: string;
begin
  CheckConnection;
  Html := '';
  Language := FilterLanguage(ARequest);
  with Query('SELECT p.slug, p.title FROM wiki_pages p WHERE (:all = ''all'' OR p.lang = :lang) AND p.name_key <> :main' + ' AND UPPER(' +
      SqlLeft('TRIM(p.body)', 9) + ') <> ''#REDIRECT''' + ' AND NOT EXISTS (SELECT 1 FROM wiki_links l WHERE l.target_key = p.name_key AND l.page_id <> p.id)' +
      ' ORDER BY p.name_key LIMIT 1000', [Language, Language, LowerCase(MAIN_PAGE)]) do
  try
    while not EOF do
    begin
      Html := Html + '<li><a href="' + E(PageUrl(Fields[0].AsString)) + '">' + E(Fields[1].AsString) + '</a></li>';
      Next;
    end;
  finally
    Free;
  end;
  if Html = '' then
    Html := '<p class="notice">' + W(ARequest, 'Every page has a page linking to it.') + '</p>'
  else
    Html := '<ul class="wikipages">' + Html + '</ul>';
  SendWiki(ARequest, AResponse, SiteWord(ReaderLanguage(ARequest), 'Pages nobody links to'), '<h1>' + W(ARequest, 'Pages nobody links to') +
    '</h1><p>' + W(ARequest, 'Readers find these only by searching. A link from a page on the same subject helps.') + '</p>' + Html, 'pages');
end;

(* The emoji set as a Markdown table, for the help's {{emoji-table}}:
  each emoji, its keywords and its name. *)
function EmojiTable: string;
var
  List: TEmojiList;
  I, K: integer;
  Keys: string;
begin
  List := EmojiSet;
  if Length(List) = 0 then
    Exit('');
  Result := '| | Keywords | Name |'#10'|---|---|---|'#10;
  for I := 0 to High(List) do
  begin
    Keys := '';
    for K := 0 to High(List[I].Keywords) do
    begin
      if Keys <> '' then
        Keys := Keys + ' ';
      Keys := Keys + '`:' + List[I].Keywords[K] + ':`';
    end;
    Result := Result + '| ' + List[I].Chars + ' | ' + Keys + ' | ' + List[I].Name + ' |'#10;
  end;
end;

{ GET /wiki-help  how to write here: templates/wiki-help.md, rendered as a page is. }
procedure ShowHelp(ARequest: TRequest; AResponse: TResponse);
var
  Text: TStringList;
  Title: string;
begin
  CheckConnection;
  Text := TStringList.Create;
  try
    if FileExists(FilesRoot + 'templates/wiki-help.md') then
      Text.LoadFromFile(FilesRoot + 'templates/wiki-help.md');
    // its first line, "# Title", is the page's own heading, as on any page
    Title := SiteWord(ReaderLanguage(ARequest), 'Writing on the wiki');
    if (Text.Count > 0) and StartsStr('# ', Text[0]) then
    begin
      Title := Trim(Copy(Text[0], 3, MaxInt));
      Text.Delete(0);
    end;
    SendWiki(ARequest, AResponse, Title, '<h1>' + E(Title) + '</h1><nav class="pagetools"><a href="/wiki-new">' + W(ARequest, 'New page') +
      '</a></nav><div class="wikibody">' + RenderPage(StringReplace(Text.Text, '{{emoji-table}}', EmojiTable, [])) + '</div>', 'other');
  finally
    Text.Free;
  end;
end;

{ ------------------------------------------------------------------ api }

procedure ApiPages(ARequest: TRequest; AResponse: TResponse);
begin
  CheckConnection;
  AResponse.SetCustomHeader('Cache-Control', 'private, no-store');
  AResponse.SetCustomHeader('Vary', 'Cookie');
  SendJSON(AResponse, ListPages(ARequest.QueryFields.Values['from'], '', FilterLanguage(ARequest)));
end;

procedure ApiCategories(ARequest: TRequest; AResponse: TResponse);
var
  List: TJSONArray;
begin
  CheckConnection;
  List := TJSONArray.Create;
  with Query('SELECT category, COUNT(*) FROM wiki_categories GROUP BY category ORDER BY category', []) do
  try
    while not EOF do
    begin
      List.Add(TJSONObject.Create(['category', Fields[0].AsString, 'count', Fields[1].AsInteger, 'url', CategoryUrl(Fields[0].AsString)]));
      Next;
    end;
  finally
    Free;
  end;
  SendJSON(AResponse, List);
end;

procedure ApiPage(ARequest: TRequest; AResponse: TResponse);
var
  Page: TPage;
begin
  CheckConnection;
  Page := LoadPage(SlugOf(ARequest.QueryFields.Values['slug']));
  if Page.Id = 0 then
    SendText(AResponse, 404, SiteWord(ReaderLanguage(ARequest), 'There is no page by that name.'))
  else
    SendJSON(AResponse, TJSONObject.Create(['slug', Page.Slug, 'title', Page.Title, 'body', Page.Body, 'html', Page.Html, 'rev', Page.Rev,
      'locked', Page.Locked, 'updated', Page.Updated, 'updated_by', Page.UpdatedBy, 'url', PageUrl(Page.Slug)]));
end;

procedure ApiSave(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Slug, Problem: string;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  Slug := SlugOf(ARequest.ContentFields.Values['slug']);
  if Slug = '' then
  begin
    SendText(AResponse, 400, SiteWord(ReaderLanguage(ARequest), 'The page needs a name.'));
    Exit;
  end;
  Problem := SavePage(Me, Slug, ARequest.ContentFields.Values['title'], ARequest.ContentFields.Values['body'], ARequest.ContentFields.Values['summary'],
    StrToIntDef(ARequest.ContentFields.Values['base'], 0), ARequest);
  if Problem <> '' then
    SendText(AResponse, 409, Problem)
  else
    SendJSON(AResponse, TJSONObject.Create(['slug', Slug, 'rev', LoadPage(Slug).Rev, 'url', PageUrl(Slug)]));
end;

procedure ApiSearch(ARequest: TRequest; AResponse: TResponse);
var
  Found: TJSONArray;
  OtherCount: int64;
begin
  CheckConnection;
  Found := SearchPages(ARequest.QueryFields.Values['q'], FilterLanguage(ARequest), OtherCount);
  AResponse.SetCustomHeader('Cache-Control', 'private, no-store');
  AResponse.SetCustomHeader('Vary', 'Cookie');
  AResponse.SetCustomHeader('X-Wiki-Other-Languages', IntToStr(OtherCount));
  if OtherCount > 0 then
    AResponse.SetCustomHeader('Link', '</api/wiki/search?q=' + HTTPEncode(Trim(ARequest.QueryFields.Values['q'])) + '&all=1>; rel="alternate"');
  SendJSON(AResponse, Found);
end;

{ The wiki in the site's search: pages in the reader's language, as its own
  search finds them.  Every page that is there may be read by anyone; a
  deleted one is not there. }
function FindInWiki(ARequest: TRequest; const Me: TMember; const Words: string; Offset, Limit: integer; out More: boolean): TSearchHits;
var
  Found: TJSONArray;
  OtherCount: int64;
  I: integer;
begin
  Result := nil;
  Found := SearchPages(Words, FilterLanguage(ARequest), OtherCount, Offset, Limit + 1);
  try
    More := Found.Count > Limit;
    for I := 0 to Found.Count - 1 do
      if I < Limit then
        AddSearchHit(Result, Found.Objects[I].Strings['title'], PageUrl(Found.Objects[I].Strings['slug']), Found.Objects[I].Strings['text'], '', '', 'page');
  finally
    Found.Free;
  end;
end;

procedure ApiChanges(ARequest: TRequest; AResponse: TResponse);
var
  List: TJSONArray;
begin
  CheckConnection;
  List := TJSONArray.Create;
  with Query('SELECT p.slug, p.title, r.rev, ' + IsoTime('r.at') + ', COALESCE(u.name, NULLIF(r.author, ''''), ''''), r.summary FROM wiki_revisions r' +
      ' JOIN wiki_pages p ON p.id = r.page_id LEFT JOIN users u ON u.id = r.user_id ORDER BY r.at DESC, r.id DESC LIMIT 100', []) do
  try
    while not EOF do
    begin
      List.Add(TJSONObject.Create(['slug', Fields[0].AsString, 'title', Fields[1].AsString, 'rev', Fields[2].AsInteger, 'at', Fields[3].AsString,
        'by', Fields[4].AsString, 'summary', Fields[5].AsString]));
      Next;
    end;
  finally
    Free;
  end;
  SendJSON(AResponse, List);
end;

{ The first page, so the wiki is never an empty door. }
const
  WELCOME = '# Welcome'#10#10 + 'This is the wiki: pages written and mended by the members here.'#10#10 +
    'Search above for a page by name or words, or open **All pages** to browse. Sign in and press **Edit** on any page to mend it, or write a ' +
    'new one by searching for its name. Link pages to each other with `[[Page Name]]`.'#10;

procedure SeedMainPage;
begin
  if PageExists(MAIN_PAGE) then
    Exit;
  Exec('INSERT INTO wiki_pages (name_key, slug, title, body, html, lang, rev, locked, updated, updated_by) VALUES (:k, :s, :t, :b, :h, ''en'', 1, 0, NOW(), NULL)',
    [LowerCase(MAIN_PAGE), MAIN_PAGE, 'Main Page', WELCOME, RenderPage(WELCOME)]);
  Exec('INSERT INTO wiki_revisions (page_id, rev, title, body, summary, user_id, at) SELECT id, 1, title, body, ''The first page'', NULL, NOW() FROM wiki_pages WHERE name_key = :k',
    [LowerCase(MAIN_PAGE)]);
end;

{ The wiki's pictures: files under <files>/wiki-images, served at
  /wiki-images/<path>. }
procedure ServeImages;
begin
  if DirectoryExists(FilesRoot + 'wiki-images') then
    ServeFolder('wiki-images', FilesRoot + 'wiki-images');
end;

function WikiLink: string;
begin
  Result := '<a href="/wiki">' + E(Say('Wiki')) + '</a>';
end;

initialization
  RegisterFileGuard('/wiki-images');
  RegisterOldLink('/wiki/');
  RegisterFilePath('/wiki-images/');
  RegisterSearchPlace('/wiki-search', 'wiki');
  RegisterSearchPlace('/api/wiki/search', 'wiki');
  RegisterVisitorPart('wiki', '/wiki');
  RegisterVisitorPart('wiki', '/wiki-');
  RegisterVisitorPart('static', '/wiki-images');
  RegisterStorageFolder('wiki-images', 'Wiki images', 'wiki-images');
  RegisterStorageTables('wiki', 'Wiki tables', 'wiki_pages,wiki_revisions,wiki_categories,wiki_links,wiki_deleted,wiki_files,wiki_file_versions');
  RegisterAdminRoute('/api/wiki/rerender', 'wiki-lock');
  RegisterSetting('wiki_page_kb', 'Wiki: longest page in KB (1024 at most)', '500', 'number', 'Wiki');
  RegisterBodyLimit('/wiki', 3 * MAX_PAGE_KB * 1024 + 65536);
  RegisterBodyLimit('/wiki/*', 3 * MAX_PAGE_KB * 1024 + 65536);
  RegisterBodyLimit('/api/wiki/save', 3 * MAX_PAGE_KB * 1024 + 65536);
  RegisterRequestLimit('wikisave', 'Wiki saves and previews', 600, 20, 60, 'wiki-lock', 240);
  LimitRoute('wikisave', '/wiki', 'POST');
  LimitRoute('wikisave', '/wiki/*', 'POST');
  LimitRoute('wikisave', '/api/wiki/save', 'POST');
  // the live preview asks as the member types, a moment after each pause
  RegisterRequestLimit('wikiprev', 'Wiki editor previews', 240, 120, 1);
  LimitRoute('wikiprev', '/api/wiki/preview', 'POST');
  RegisterBodyLimit('/api/wiki/preview', 3 * MAX_PAGE_KB * 1024 + 65536);
  HTTPRouter.RegisterRoute('/api/wiki/preview', rmPost, @ShowPreview);
  RegisterRequestLimit('wikiburst', 'Wiki saves and previews', 60, 10, 1, 'wiki-lock', 30);
  LimitRoute('wikiburst', '/wiki', 'POST');
  LimitRoute('wikiburst', '/wiki/*', 'POST');
  LimitRoute('wikiburst', '/api/wiki/save', 'POST');
  RegisterRequestLimit('wikisrch', 'Wiki searches', 30, 30, 1);
  RegisterSearch('wiki', 'Wiki', 20, @FindInWiki, '', '/wiki-search?q=');
  RegisterSearchRoute('/wiki-search');
  RegisterSearchRoute('/api/wiki/search');
  LimitRoute('wikisrch', '/wiki-search', 'GET');
  LimitRoute('wikisrch', '/api/wiki/search', 'GET');
  RegisterRequestLimit('wikilist', 'Wiki lists and random pages', 60, 60, 1);
  LimitRoute('wikilist', '/wiki-changes', 'GET');
  LimitRoute('wikilist', '/wiki-contributors', 'GET');
  InitCriticalSection(ContributorsLock);
  LimitRoute('wikilist', '/api/wiki/changes', 'GET');
  LimitRoute('wikilist', '/wiki-pages', 'GET');
  LimitRoute('wikilist', '/api/wiki/pages', 'GET');
  LimitRoute('wikilist', '/wiki-random', 'GET');
  LimitRoute('wikilist', '/wiki-category/*', 'GET');
  LimitRoute('wikilist', '/wiki-links/*', 'GET');
  LimitRoute('wikilist', '/wiki-wanted', 'GET');
  LimitRoute('wikilist', '/wiki-orphans', 'GET');
  LimitRoute('wikilist', '/api/wiki/categories', 'GET');
  RegisterStartup(@ServeImages);
  RegisterTable('CREATE TABLE IF NOT EXISTS wiki_pages (' + ' id INT AUTO_INCREMENT PRIMARY KEY, name_key VARCHAR(180) NOT NULL UNIQUE,' +
    ' slug VARCHAR(180) NOT NULL, title VARCHAR(200) NOT NULL, body MEDIUMTEXT NOT NULL, html MEDIUMTEXT NOT NULL,' +
    ' rev INT NOT NULL DEFAULT 1, locked TINYINT NOT NULL DEFAULT 0, updated DATETIME NOT NULL, updated_by INT NULL,' +
    ' updated_by_name VARCHAR(80) NOT NULL DEFAULT '''', FULLTEXT (title, body), INDEX (updated))');
  RegisterTable('CREATE TABLE IF NOT EXISTS wiki_revisions (' + ' id INT AUTO_INCREMENT PRIMARY KEY, page_id INT NOT NULL, rev INT NOT NULL,' +
    ' title VARCHAR(200) NOT NULL, body MEDIUMTEXT NOT NULL, summary VARCHAR(200) NOT NULL DEFAULT '''', user_id INT NULL,' +
    ' author VARCHAR(80) NOT NULL DEFAULT '''', at DATETIME NOT NULL, UNIQUE (page_id, rev))');
  RegisterTable('CREATE TABLE IF NOT EXISTS wiki_categories (page_id INT NOT NULL, category VARCHAR(200) NOT NULL,' + ' PRIMARY KEY (page_id, category), INDEX (category))');
  RegisterUpgrade('wiki-page-rendered', 'ALTER TABLE wiki_pages ADD COLUMN rendered INT NOT NULL DEFAULT 0');
  RegisterChore(@RenderOldPages, 1);
  RegisterUpgrade('wiki-page-language', 'ALTER TABLE wiki_pages ADD COLUMN lang VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT '''',' +
    ' ADD INDEX wiki_lang_name (lang, name_key)');
  // A revision or page credited to a name that is no member's: plain text.
  RegisterUpgrade('wiki-revisions-author', 'ALTER TABLE wiki_revisions ADD COLUMN IF NOT EXISTS author VARCHAR(80) NOT NULL DEFAULT ''''');
  RegisterUpgrade('wiki-pages-updated-by-name', 'ALTER TABLE wiki_pages ADD COLUMN IF NOT EXISTS updated_by_name VARCHAR(80) NOT NULL DEFAULT ''''');
  RegisterStartup(@FillPageLanguages);
  RegisterPermission('wiki-edit', 'Write and change wiki pages', 'member,moderator,admin');
  RegisterPermission('wiki-lock', 'Lock a wiki page, and change a locked one', 'moderator,admin');
  RegisterPermission('wiki-move', 'Give a wiki page a new name', 'member,moderator,admin');
  RegisterPermission('wiki-delete', 'Delete a wiki page, and bring one back', 'moderator,admin');
  RegisterPermission('wiki-settings', 'Change the wiki''s settings', 'admin');
  RegisterSettingsKeeper('Wiki', 'wiki-settings');
  RegisterRole('wiki-moderator', 'Keeps the peace in the wiki', 'wiki-lock,wiki-delete,wiki-files-moderate');
  RegisterRole('wiki-admin', 'Runs the wiki: its pages, pictures and emoji', 'wiki-lock,wiki-delete,wiki-files-moderate,wiki-emoji,wiki-settings,view-admin');
  // the pages each page links to: backlinks, wanted pages, red links
  RegisterTable('CREATE TABLE IF NOT EXISTS wiki_links (page_id INT NOT NULL, target_key VARCHAR(180) NOT NULL, target VARCHAR(180) NOT NULL,' +
    ' PRIMARY KEY (page_id, target_key), INDEX (target_key)) CHARACTER SET utf8mb4');
  // deleted pages; their revisions stay in wiki_revisions under page_id
  RegisterTable('CREATE TABLE IF NOT EXISTS wiki_deleted (page_id INT NOT NULL PRIMARY KEY, name_key VARCHAR(180) NOT NULL, slug VARCHAR(180) NOT NULL,' +
    ' title VARCHAR(200) NOT NULL, rev INT NOT NULL, reason VARCHAR(200) NOT NULL DEFAULT '''', user_id INT NULL, at DATETIME NOT NULL,' +
    ' INDEX (name_key)) CHARACTER SET utf8mb4');
  RegisterUpgrade('wiki-deleted-locked', 'ALTER TABLE wiki_deleted ADD COLUMN IF NOT EXISTS locked TINYINT NOT NULL DEFAULT 0');
  RegisterPart('wiki', 'The wiki: pages members write together', True);
  RegisterPartPaths('wiki', ['/wiki', '/wiki-pages', '/wiki-new', '/wiki-links', '/wiki-wanted', '/wiki-orphans', '/wiki-help', '/wiki-category',
    '/wiki-changes', '/wiki-contributors', '/wiki-random', '/wiki-language', '/wiki-contact', '/wiki-search', '/api/wiki']);
  RegisterPartLink('wiki', @WikiLink);
  RegisterPartHome('wiki', '/wiki');
  RegisterHomePart('wiki_home', @WikiHomeCard);
  RegisterStartup(@SeedMainPage);
  HTTPRouter.RegisterRoute('/wiki', rmAll, @ShowWiki);
  HTTPRouter.RegisterRoute('/wiki/*slug', rmAll, @ShowWiki);
  HTTPRouter.RegisterRoute('/wiki-pages', rmGet, @ShowPages);
  HTTPRouter.RegisterRoute('/wiki-new', rmGet, @ShowNewPage);
  HTTPRouter.RegisterRoute('/wiki-links/*slug', rmGet, @ShowLinksHere);
  HTTPRouter.RegisterRoute('/wiki-wanted', rmGet, @ShowWanted);
  HTTPRouter.RegisterRoute('/wiki-orphans', rmGet, @ShowOrphans);
  HTTPRouter.RegisterRoute('/wiki-help', rmGet, @ShowHelp);
  HTTPRouter.RegisterRoute('/wiki-category/*category', rmGet, @ShowCategory);
  HTTPRouter.RegisterRoute('/wiki-changes', rmGet, @ShowChanges);
  HTTPRouter.RegisterRoute('/wiki-contributors', rmGet, @ShowContributors);
  HTTPRouter.RegisterRoute('/wiki-random', rmGet, @ShowRandom);
  HTTPRouter.RegisterRoute('/wiki-language', rmGet, @ChooseLanguage);
  HTTPRouter.RegisterRoute('/wiki-contact', rmGet, @ShowContact);
  HTTPRouter.RegisterRoute('/wiki-contact', rmPost, @SendContact);
  HTTPRouter.RegisterRoute('/api/wiki/rerender', rmPost, @RerenderAll);
  HTTPRouter.RegisterRoute('/wiki-search', rmGet, @ShowSearch);
  HTTPRouter.RegisterRoute('/api/wiki', rmGet, @ApiPage);
  HTTPRouter.RegisterRoute('/api/wiki/pages', rmGet, @ApiPages);
  HTTPRouter.RegisterRoute('/api/wiki/categories', rmGet, @ApiCategories);
  HTTPRouter.RegisterRoute('/api/wiki/save', rmPost, @ApiSave);
  HTTPRouter.RegisterRoute('/api/wiki/search', rmGet, @ApiSearch);
  HTTPRouter.RegisterRoute('/api/wiki/changes', rmGet, @ApiChanges);
end.
