unit SiteSearch;

{ Shared search page and JSON endpoint, using module-registered callbacks.
  Each callback must return only hits the reader may open. This unit checks
  the module switch and search permission, never its tables. See
  docs/MODULES.md for the callback contract and docs/API.md for requests. }

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
procedure AddSearchHit(var Hits: TSearchHits; const Title, Address, Excerpt, Time, Author, Kind: string);
{ What is wrong with the words of a search, in the reader's language; ''
  for nothing. }
function SearchWordsProblem(const Words: string): string;
{ The words searched for, marked where they appear in text already escaped
  for HTML; case is kept as the text has it. }
function MarkWords(const Escaped, Words: string): string;

implementation

uses
  SysUtils, StrUtils, fpjson, httproute, SiteDb, SiteRoles, SiteGuard, SiteGuardRules, SiteParts, SiteVisitors, SiteWords, WebPages;

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

procedure AddSearchHit(var Hits: TSearchHits; const Title, Address, Excerpt, Time, Author, Kind: string);
begin
  SetLength(Hits, Length(Hits) + 1);
  Hits[High(Hits)].Title := Title;
  Hits[High(Hits)].Address := Address;
  Hits[High(Hits)].Excerpt := Excerpt;
  Hits[High(Hits)].Time := Time;
  Hits[High(Hits)].Author := Author;
  Hits[High(Hits)].Kind := Kind;
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

function SearchAddress(const Words, Scope: string; Page: integer): string;
begin
  Result := '/search?q=' + HTTPEncode(Words);
  if Scope <> '' then
    Result := Result + '&in=' + HTTPEncode(Scope);
  if Page > 1 then
    Result := Result + '&page=' + IntToStr(Page);
end;

{ Asks the modules: the one in Scope for a page of its hits, or each that
  Me may search for its first few. }
function Find(ARequest: TRequest; const Me: TMember; const Words, Scope: string; Page: integer): TFounds;
var
  I: integer;
begin
  Result := nil;
  for I := 0 to High(Searchers) do
    if Offered(Searchers[I], Me) and ((Scope = '') or (Scope = Searchers[I].Part)) then
    begin
      SetLength(Result, Length(Result) + 1);
      with Result[High(Result)] do
      begin
        Searcher := Searchers[I];
        if Scope = '' then
          Hits := Searcher.Find(ARequest, Me, Words, 0, FewHits, More)
        else
          Hits := Searcher.Find(ARequest, Me, Words, (Page - 1) * PageHits, PageHits, More);
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
end;

function HitHtml(const Hit: TSearchHit; const Words: string): string;
var
  Facts: string;
begin
  Result := '<article class="found-hit"><h3><a href="' + E(Hit.Address) + '">' + MarkWords(E(Hit.Title), Words) + '</a></h3>';
  if Hit.Excerpt <> '' then
    Result := Result + '<p>' + MarkWords(E(Hit.Excerpt), Words) + '</p>';
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

{ GET /search?q=&in=&page= }
procedure ShowSearch(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Words, Scope, Html, Problem, Links: string;
  Page: integer;
  Found: TFound;
  Hit: TSearchHit;
  Any: boolean;
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
    Any := False;
    for Found in Find(ARequest, Me, Words, Scope, Page) do
    begin
      if (Length(Found.Hits) = 0) and (Page = 1) then
        Continue;
      Any := True;
      Html := Html + '<section class="found"><h2>' + E(Say(Found.Searcher.Caption)) + '</h2>';
      for Hit in Found.Hits do
        Html := Html + HitHtml(Hit, Words);
      Links := '';
      if Scope = '' then
      begin
        if Found.More then
          Links := '<a href="' + E(SearchAddress(Words, Found.Searcher.Part, 1)) + '">' + E(Format(Say('More from %s'), [Say(Found.Searcher.Caption)])) + '</a>';
      end
      else
      begin
        if Page > 1 then
          Links := '<a href="' + E(SearchAddress(Words, Scope, Page - 1)) + '">' + E(Say('Previous')) + '</a> ';
        if Found.More then
          Links := Links + '<a href="' + E(SearchAddress(Words, Scope, Page + 1)) + '">' + E(Say('Next')) + '</a> ';
        if Found.Searcher.OwnSearch <> '' then
          Links := Links + '<a href="' + E(Found.Searcher.OwnSearch + HTTPEncode(Words)) + '">' +
            E(Format(Say('Open this search in %s'), [Say(Found.Searcher.Caption)])) + '</a>';
      end;
      if Links <> '' then
        Html := Html + '<p class="found-more">' + Links + '</p>';
      Html := Html + '</section>';
    end;
    if not Any then
      Html := Html + '<p class="notice">' + E(Say('Nothing found.')) + '</p>';
  end;
  SendPage(AResponse, PartPage(ARequest, Me, Say('Search'), Html, '', '', '', '', 'found-main'));
end;

{ GET /api/site-search?q=&in=&page=  what the page shows, for a program:
  groups, one for each module searched, each with its hits and whether it
  has more. }
procedure ApiSearch(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Words, Scope: string;
  Found: TFound;
  Hit: TSearchHit;
  Groups, Hits: TJSONArray;
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
      Groups.Add(TJSONObject.Create(['module', Found.Searcher.Part, 'caption', Say(Found.Searcher.Caption), 'hits', Hits, 'more', Found.More]));
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

initialization
  RegisterPageValue('search_form', @SearchForm);
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
