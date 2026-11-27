unit SiteSearch;

{ Shared search page and JSON endpoint, using module-registered callbacks.
  Each callback must return only hits the reader may open. This unit checks
  the module switch and search permission, never its tables. A module that
  joined the site's index (SiteIndex) is answered from there when the
  setting search_engine says so. See docs/MODULES.md for the callback
  contract and docs/API.md for requests. }

{$mode objfpc}{$H+}

interface

uses
  httpdefs, SiteUsers;

type
  { One thing found.  Everything is plain text: the page escapes it and
    marks the words searched for. }
  TSearchHit = record
    Title: string;    // what it is called: a page's title, a topic's, '#room' for a message
    Address: string;  // where it opens, a path on this site: /wiki/Main_Page
    Excerpt: string;  // a line or two of its text; '' when the module has none to give
    Time: string;     // when it was written or last changed, ISO and UTC; '' when not known
    Author: string;   // who wrote it, by name; '' when it has no one author
    Kind: string;     // what it is, in one lower-case word of the module's: page, topic, message
    Id: string;       // what the module knows it by, a row's number say; '' when it gives none
  end;
  TSearchHits = array of TSearchHit;

  { Return only hits Me may read, best first, at most Limit after Offset.
    More reports further hits. Words is trimmed and length-checked; the
    module defines matching. This callback must enforce access even when
    searching an index; see docs/MODULES.md. }
  TSearchFind = function(ARequest: TRequest; const Me: TMember; const Words: string; Offset, Limit: integer; out More: boolean): TSearchHits;

{ Register a search group, ordered lowest first. Part matches RegisterPart;
  unregistered names are always offered and selected by their path prefix.
  Caption is English; Permission limits access. OwnSearch names an optional
  search URL to append words to. See docs/MODULES.md. }
procedure RegisterSearch(const Part, Caption: string; Order: integer; Find: TSearchFind; const Permission: string = ''; const OwnSearch: string = '');
{ Adds a hit to the answer a module's function is making. }
procedure AddSearchHit(var Hits: TSearchHits; const Title, Address, Excerpt, Time, Author, Kind: string; const Id: string = '');
{ What is wrong with the words of a search, in the reader's language; ''
  for nothing. }
function SearchWordsProblem(const Words: string): string;
{ The words searched for, marked where they appear in text already escaped
  for HTML; case is kept as the text has it. }
function MarkWords(const Escaped, Words: string): string;
{ One hit as the results page shows it. TitleHtml and ExcerptHtml are HTML
  the program made itself and go in as given; where one is '' the hit's
  own text is escaped and the words marked. }
function HitHtml(const Hit: TSearchHit; const Words, TitleHtml, ExcerptHtml: string): string;
{ The line over a module's hits when the index corrected the words (Shown)
  or offers others (Meant), which link to a search of them in Scope; ''
  when neither is set. }
function HintHtml(const Shown, Meant, Scope: string): string;

implementation

uses
  SysUtils, StrUtils, fpjson, httproute, SiteDb, SiteRoles, SiteGuard, SiteGuardRules, SiteParts, SiteVisitors, SiteWords, WebPages, SiteIndex;

const
  { Hits shown for each module when all are searched, and on a page of one. }
  FewHits = 5;
  PageHits = 20;

type
  TSearcher = record
    Part, Caption, Permission, OwnSearch: string;
    Order: integer;
    Find: TSearchFind;
  end;

  { What one module found for a request. }
  TFound = record
    Searcher: TSearcher;
    Hits: TSearchHits;
    More: boolean;
    Engine: string;         // what answered: index or database
    Shown, Meant: string;   // the index's corrected words, and words it offers
    // beside Hits when the index answered: HTML it made, for HitHtml
    TitleHtml, ExcerptHtml: TStringArray;
  end;
  TFounds = array of TFound;

var
  Searchers: array of TSearcher;

procedure RegisterSearch(const Part, Caption: string; Order: integer; Find: TSearchFind; const Permission: string; const OwnSearch: string);
var
  I, At: integer;
begin
  At := Length(Searchers);
  while (At > 0) and (Searchers[At - 1].Order > Order) do
    Dec(At);
  SetLength(Searchers, Length(Searchers) + 1);
  for I := High(Searchers) downto At + 1 do
    Searchers[I] := Searchers[I - 1];
  Searchers[At].Part := Part;
  Searchers[At].Caption := Caption;
  Searchers[At].Order := Order;
  Searchers[At].Find := Find;
  Searchers[At].Permission := Permission;
  Searchers[At].OwnSearch := OwnSearch;
end;

procedure AddSearchHit(var Hits: TSearchHits; const Title, Address, Excerpt, Time, Author, Kind: string; const Id: string);
begin
  SetLength(Hits, Length(Hits) + 1);
  Hits[High(Hits)].Title := Title;
  Hits[High(Hits)].Address := Address;
  Hits[High(Hits)].Excerpt := Excerpt;
  Hits[High(Hits)].Time := Time;
  Hits[High(Hits)].Author := Author;
  Hits[High(Hits)].Kind := Kind;
  Hits[High(Hits)].Id := Id;
end;

function SearchWordsProblem(const Words: string): string;
begin
  Result := '';
  if SearchQueryProblem(Words, SettingInt('search_query_bytes', 100)) = '' then
    Exit;
  if Length(UTF8Decode(Trim(Words))) < 2 then
    Result := Say('Enter at least two characters to search.')
  else
    Result := Format(Say('Search text can be at most %d bytes.'), [SettingInt('search_query_bytes', 100)]);
end;

function MarkWords(const Escaped, Words: string): string;
var
  Term, Lower, LowerTerm: string;
  P, Start: integer;
begin
  Result := Escaped;
  for Term in Words.Split([' ', #9], TStringSplitOptions.ExcludeEmpty) do
  begin
    if (Length(Term) < 2) or (Pos('&', Term) > 0) or (Pos('<', Term) > 0) or (Pos('>', Term) > 0) then
      Continue;
    Lower := LowerCase(Result);
    LowerTerm := LowerCase(Term);
    Start := 1;
    while True do
    begin
      P := PosEx(LowerTerm, Lower, Start);
      if P = 0 then
        Break;
      // not inside a tag or an entity this function put there
      if (LastDelimiter('<', Copy(Lower, 1, P)) > LastDelimiter('>', Copy(Lower, 1, P))) or (LastDelimiter('&', Copy(Lower, 1, P)) >
        LastDelimiter(';', Copy(Lower, 1, P))) then
      begin
        Start := P + 1;
        Continue;
      end;
      Insert('</mark>', Result, P + Length(Term));
      Insert('<mark>', Result, P);
      Lower := LowerCase(Result);
      Start := P + Length(Term) + 13;
    end;
  end;
end;

{ Whether Me may search this module now. }
function Offered(const Searcher: TSearcher; const Me: TMember): boolean;
begin
  // a search of something that is no part of its own is there as long as the program has it
  Result := (PartOn(Searcher.Part) or not PartKnown(Searcher.Part)) and ((Searcher.Permission = '') or Can(Me, Searcher.Permission));
end;

{ The module a request asks to search, when Me may: '' for every module. }
function ScopeOf(const Asked: string; const Me: TMember): string;
var
  I: integer;
begin
  Result := '';
  for I := 0 to High(Searchers) do
    if (Searchers[I].Part = Asked) and Offered(Searchers[I], Me) then
      Result := Asked;
end;

function PageOf(ARequest: TRequest): integer;
begin
  Result := StrToIntDef(ARequest.QueryFields.Values['page'], 1);
  if (Result < 1) or (Result > 100000) then
    Result := 1;
end;

function SearchAddress(const Words, Scope: string; Page: integer; const Engine: string = ''): string;
begin
  Result := '/search?q=' + HTTPEncode(Words);
  if Scope <> '' then
    Result := Result + '&in=' + HTTPEncode(Scope);
  if Page > 1 then
    Result := Result + '&page=' + IntToStr(Page);
  if Engine <> '' then
    Result := Result + '&engine=' + Engine;
end;

function HintHtml(const Shown, Meant, Scope: string): string;
begin
  Result := '';
  if Shown <> '' then
    Result := '<p class="notice">' + Format(E(Say('Showing results for %s')), ['<b>' + E(Shown) + '</b>']) + '</p>'
  else if Meant <> '' then
    Result := '<p class="notice">' + Format(E(Say('Did you mean %s?')), ['<a href="' + E(SearchAddress(Meant, Scope, 1)) + '">' + E(Meant) + '</a>']) + '</p>';
end;

{ What answers Me's search, index or database, by the setting search_engine:
  the index for everyone, or under compare only for who may change the
  settings.  Such a reader picks either with engine= on the request. }
function EngineOf(ARequest: TRequest; const Me: TMember): string;
var
  Kept: string;
begin
  Result := 'database';
  Kept := Setting('search_engine', 'database');
  if Kept = 'database' then
    Exit;
  if Can(Me, 'manage-settings') then
  begin
    if ARequest.QueryFields.Values['engine'] <> 'database' then
      Result := 'index';
  end
  else if Kept = 'index' then
    Result := 'index';
end;

{ Asks the modules: the one in Scope for a page of its hits, or each that
  Me may search for its first few.  The index answers for a module when it
  can; the module's own function does otherwise. }
function Find(ARequest: TRequest; const Me: TMember; const Words, Scope: string; Page: integer): TFounds;
var
  I, Offset, Limit: integer;
  Wanted: string;
  Answer: TIndexAnswer;
begin
  Result := nil;
  Wanted := EngineOf(ARequest, Me);
  Offset := 0;
  Limit := FewHits;
  if Scope <> '' then
  begin
    Offset := (Page - 1) * PageHits;
    Limit := PageHits;
  end;
  for I := 0 to High(Searchers) do
    if Offered(Searchers[I], Me) and ((Scope = '') or (Scope = Searchers[I].Part)) then
    begin
      SetLength(Result, Length(Result) + 1);
      with Result[High(Result)] do
      begin
        Searcher := Searchers[I];
        if (Wanted = 'index') and IndexFind(ARequest, Me, Searcher.Part, Words, Offset, Limit, Answer) then
        begin
          Hits := Answer.Hits;
          TitleHtml := Answer.TitleHtml;
          ExcerptHtml := Answer.ExcerptHtml;
          More := Answer.More;
          Shown := Answer.Shown;
          Meant := Answer.Meant;
          Engine := 'index';
        end
        else
        begin
          Hits := Searcher.Find(ARequest, Me, Words, Offset, Limit, More);
          Engine := 'database';
        end;
      end;
    end;
end;

{ The first word of an address: docs of /docs/rtl/system. }
function FirstWord(const Path: string): string;
begin
  Result := Copy(Path, 2, MaxInt);
  if Pos('/', Result) > 0 then
    SetLength(Result, Pos('/', Result) - 1);
end;

{ The box on every page, for a template that has search_form in double
  braces: the words, and which module to look in when there are several.
  It starts on the module whose page the reader is on.  A plain form, so
  it works without scripts. }
function SearchForm: string;
var
  Me: TMember;
  Request: TRequest;
  Scope, Words, Choices: string;
  I, Count: integer;
begin
  Result := '';
  Request := PageRequest;
  if Request = nil then
    Exit;
  CheckConnection;
  Me := CurrentMember(Request);
  Words := '';
  if Request.PathInfo = '/search' then
  begin
    Scope := ScopeOf(Request.QueryFields.Values['in'], Me);
    Words := Trim(Request.QueryFields.Values['q']);
  end
  else
  begin
    Scope := ScopeOf(PartOfPath(Request.PathInfo), Me);
    if Scope = '' then
      Scope := ScopeOf(FirstWord(Request.PathInfo), Me);
  end;
  Choices := '';
  Count := 0;
  for I := 0 to High(Searchers) do
    if Offered(Searchers[I], Me) then
    begin
      Inc(Count);
      Choices := Choices + '<option value="' + E(Searchers[I].Part) + '"';
      if Searchers[I].Part = Scope then
        Choices := Choices + ' selected';
      Choices := Choices + '>' + E(Say(Searchers[I].Caption)) + '</option>';
    end;
  if Count = 0 then
    Exit;
  Result := '<form class="site-search" action="/search" method="get" role="search"><input type="search" name="q" value="' + E(Words) +
    '" maxlength="100" required placeholder="' + E(Say('Search')) + '" aria-label="' + E(Say('Search')) + '">';
  if Count > 1 then
  begin
    Result := Result + '<select name="in" aria-label="' + E(Say('Search in')) + '">' + Choices + '<option value=""';
    if Scope = '' then
      Result := Result + ' selected';
    Result := Result + '>' + E(Say('Everything')) + '</option></select>';
  end;
  Result := Result + '<button>' + E(Say('Search')) + '</button></form>';
  // suggestions while typing, where the index answers this reader
  if EngineOf(Request, Me) = 'index' then
    Result := Result + '<script src="/static/search.js?v=' + StaticVersion + '" defer></script>';
end;

function HitHtml(const Hit: TSearchHit; const Words, TitleHtml, ExcerptHtml: string): string;
var
  Title, Excerpt, Facts: string;
begin
  Title := TitleHtml;
  if Title = '' then
    Title := MarkWords(E(Hit.Title), Words);
  Excerpt := ExcerptHtml;
  if Excerpt = '' then
    Excerpt := MarkWords(E(Hit.Excerpt), Words);
  Result := '<article class="found-hit"><h3><a href="' + E(Hit.Address) + '">' + Title + '</a></h3>';
  if Excerpt <> '' then
    Result := Result + '<p>' + Excerpt + '</p>';
  Facts := E(Hit.Author);
  if Hit.Time <> '' then
  begin
    if Facts <> '' then
      Facts := Facts + ', ';
    // a day alone shows as a day
    Facts := Facts + DateTag(Hit.Time, Length(Hit.Time) > 10);
  end;
  if Facts <> '' then
    Result := Result + '<p class="found-facts">' + Facts + '</p>';
  Result := Result + '</article>';
end;

{ For who may change the settings, while an index is kept: what answered
  each module, how long the whole search took, and a link to the same
  search answered by the other engine. }
function EngineLine(const Founds: TFounds; const Words, Scope, Engine: string; Page: integer; Took: QWord): string;
var
  Found: TFound;
begin
  Result := '<p class="notice">';
  for Found in Founds do
    if Found.Engine = 'index' then
      Result := Result + E(Say(Found.Searcher.Caption) + ': ' + Say('Answered from the index')) + '. '
    else
      Result := Result + E(Say(Found.Searcher.Caption) + ': ' + Say('Answered from the database')) + '. ';
  Result := Result + IntToStr(Took) + ' ms. ';
  if Engine = '' then
    Result := Result + '<a href="' + E(SearchAddress(Words, Scope, Page, 'database')) + '">' + E(Say('Search the database instead')) + '</a></p>'
  else
    Result := Result + '<a href="' + E(SearchAddress(Words, Scope, Page)) + '">' + E(Say('Search the index instead')) + '</a></p>';
end;

{ GET /search?q=&in=&page=&engine= }
procedure ShowSearch(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Words, Scope, Html, Problem, Links, Engine, Meant, TitleHtml, ExcerptHtml: string;
  Page, I: integer;
  Founds: TFounds;
  Found: TFound;
  Any, Comparing: boolean;
  Started: QWord;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  Words := Trim(ARequest.QueryFields.Values['q']);
  Scope := ScopeOf(ARequest.QueryFields.Values['in'], Me);
  Page := PageOf(ARequest);
  Html := '<h1>' + E(Say('Search')) + '</h1>';
  Problem := SearchWordsProblem(Words);
  if Words = '' then
    Html := Html + '<p class="notice">' + E(Say('Type the words to look for in the search box.')) + '</p>'
  else if Problem <> '' then
    Html := Html + '<p class="notice">' + E(Problem) + '</p>'
  else
  begin
    Html := Html + '<p class="found-for">' + E(Format(Say('Results for %s'), [Words])) + '</p>';
    Comparing := Can(Me, 'manage-settings') and (Setting('search_engine', 'database') <> 'database');
    // the reader's own choice of engine, kept by the links to further hits
    Engine := '';
    if Comparing and (EngineOf(ARequest, Me) = 'database') then
      Engine := 'database';
    Started := GetTickCount64;
    Founds := Find(ARequest, Me, Words, Scope, Page);
    if Comparing then
      Html := Html + EngineLine(Founds, Words, Scope, Engine, Page, GetTickCount64 - Started);
    Any := False;
    Meant := '';
    for Found in Founds do
    begin
      if Meant = '' then
        Meant := Found.Meant;
      if (Length(Found.Hits) = 0) and (Page = 1) then
        Continue;
      Any := True;
      Html := Html + '<section class="found"><h2>' + E(Say(Found.Searcher.Caption)) + '</h2>' + HintHtml(Found.Shown, Found.Meant, Found.Searcher.Part);
      for I := 0 to High(Found.Hits) do
      begin
        TitleHtml := '';
        ExcerptHtml := '';
        // only the index gives ready HTML beside its hits
        if Found.Engine = 'index' then
        begin
          TitleHtml := Found.TitleHtml[I];
          ExcerptHtml := Found.ExcerptHtml[I];
        end;
        Html := Html + HitHtml(Found.Hits[I], Words, TitleHtml, ExcerptHtml);
      end;
      Links := '';
      if Scope = '' then
      begin
        if Found.More then
          Links := '<a href="' + E(SearchAddress(Words, Found.Searcher.Part, 1, Engine)) + '">' + E(Format(Say('More from %s'), [Say(Found.Searcher.Caption)])) + '</a>';
      end
      else
      begin
        if Page > 1 then
          Links := '<a href="' + E(SearchAddress(Words, Scope, Page - 1, Engine)) + '">' + E(Say('Previous')) + '</a> ';
        if Found.More then
          Links := Links + '<a href="' + E(SearchAddress(Words, Scope, Page + 1, Engine)) + '">' + E(Say('Next')) + '</a> ';
        if Found.Searcher.OwnSearch <> '' then
          Links := Links + '<a href="' + E(Found.Searcher.OwnSearch + HTTPEncode(Words)) + '">' +
            E(Format(Say('Open this search in %s'), [Say(Found.Searcher.Caption)])) + '</a>';
      end;
      if Links <> '' then
        Html := Html + '<p class="found-more">' + Links + '</p>';
      Html := Html + '</section>';
    end;
    if not Any then
      Html := Html + HintHtml('', Meant, Scope) + '<p class="notice">' + E(Say('Nothing found.')) + '</p>';
  end;
  SendPage(AResponse, PartPage(ARequest, Me, Say('Search'), Html, '', '', '', '', 'found-main'));
end;

{ GET /api/site-search?q=&in=&page=  what the page shows, for a program:
  groups, one for each module searched, each with its hits and whether it
  has more.  Who may change the settings is told what answered each. }
procedure ApiSearch(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Words, Scope: string;
  Found: TFound;
  Hit: TSearchHit;
  Groups, Hits: TJSONArray;
  Group: TJSONObject;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  Words := Trim(ARequest.QueryFields.Values['q']);
  Scope := ScopeOf(ARequest.QueryFields.Values['in'], Me);
  Groups := TJSONArray.Create;
  try
    for Found in Find(ARequest, Me, Words, Scope, PageOf(ARequest)) do
    begin
      Hits := TJSONArray.Create;
      Group := TJSONObject.Create(['module', Found.Searcher.Part, 'caption', Say(Found.Searcher.Caption), 'hits', Hits, 'more', Found.More]);
      Groups.Add(Group);
      if Found.Shown <> '' then
        Group.Add('showing_for', Found.Shown);
      if Found.Meant <> '' then
        Group.Add('did_you_mean', Found.Meant);
      if Can(Me, 'manage-settings') then
        Group.Add('engine', Found.Engine);
      for Hit in Found.Hits do
        Hits.Add(TJSONObject.Create(['title', Hit.Title, 'url', Hit.Address, 'excerpt', Hit.Excerpt, 'time', Hit.Time, 'author', Hit.Author, 'kind', Hit.Kind]));
    end;
  except
    Groups.Free;
    raise;
  end;
  AResponse.SetCustomHeader('Cache-Control', 'private, no-store');
  AResponse.SetCustomHeader('Vary', 'Cookie, Authorization');
  SendJSON(AResponse, TJSONObject.Create(['q', Words, 'in', Scope, 'page', PageOf(ARequest), 'groups', Groups]));
end;

{ GET /api/site-suggest?q=&in=  what to offer while the reader types: pages
  with their address and words to search for, eight at most. }
procedure ApiSuggest(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Words, Scope: string;
  Lists: array of TIndexOffers;
  Captions: TStringArray;
  List: TJSONArray;
  Item: TJSONObject;
  I, Row: integer;
  Any: boolean;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  Words := TrimLeft(ARequest.QueryFields.Values['q']);
  Scope := ScopeOf(ARequest.QueryFields.Values['in'], Me);
  Lists := nil;
  Captions := nil;
  if (Length(UTF8Decode(Trim(Words))) >= 2) and (Length(Words) <= SettingInt('search_query_bytes', 100)) and (EngineOf(ARequest, Me) = 'index') then
    for I := 0 to High(Searchers) do
      if Offered(Searchers[I], Me) and ((Scope = '') or (Scope = Searchers[I].Part)) then
      begin
        SetLength(Lists, Length(Lists) + 1);
        Lists[High(Lists)] := IndexOffers(ARequest, Me, Searchers[I].Part, Words, 8);
        SetLength(Captions, Length(Captions) + 1);
        Captions[High(Captions)] := Say(Searchers[I].Caption);
      end;
  // the first of each module, then the second: scores of separate indexes do not compare
  List := TJSONArray.Create;
  Row := 0;
  repeat
    Any := False;
    for I := 0 to High(Lists) do
      if (Row < Length(Lists[I])) and (List.Count < 8) then
      begin
        Any := True;
        Item := TJSONObject.Create(['text', Lists[I][Row].Text]);
        if Lists[I][Row].Address <> '' then
        begin
          Item.Add('url', Lists[I][Row].Address);
          Item.Add('caption', Captions[I]);
        end;
        List.Add(Item);
      end;
    Inc(Row);
  until not Any;
  AResponse.SetCustomHeader('Cache-Control', 'private, no-store');
  AResponse.SetCustomHeader('Vary', 'Cookie, Authorization');
  SendJSON(AResponse, TJSONObject.Create(['q', Words, 'offers', List]));
end;

initialization
  RegisterPageValue('search_form', @SearchForm);
  RegisterRequestLimit('suggest', 'Search suggestions while typing', 120, 240, 1);
  LimitRoute('suggest', '/api/site-suggest', 'GET');
  HTTPRouter.RegisterRoute('/api/site-suggest', rmGet, @ApiSuggest);
  RegisterRequestLimit('search', 'Site searches', 30, 30, 1);
  LimitRoute('search', '/search', 'GET');
  LimitRoute('search', '/api/site-search', 'GET');
  // the page answers words that are too short itself, in the reader's language
  RegisterSearchRoute('/api/site-search');
  RegisterSearchPlace('/search', 'site');
  RegisterSearchPlace('/api/site-search', 'site');
  HTTPRouter.RegisterRoute('/search', rmGet, @ShowSearch);
  HTTPRouter.RegisterRoute('/api/site-search', rmGet, @ApiSearch);
end.
