unit SiteVisitors;

{ Visitor reports from access logs, with indexed seeking by time window.
  Separate people, crawlers and background polls; assess suspicious
  addresses without counting polls toward pace. Cache reports for a minute.
  See docs/CODE-MAP.md for classification and docs/API.md for requests. }

{$mode objfpc}{$H+}

interface

uses fpjson;

{ Where a search was made, by the start of its path: a page such as
  /wiki-search?q= or a box that asks as one types, such as /api/search?q=.
  The words are the q= of the request; a box's words as they grow,
  "tstr", "tstringl", "tstringlist", count once, as the last. }
procedure RegisterSearchPlace(const Prefix, Place: string);
{ A script of the site's own, told by Word in its browser string (lower
  case) and shown as Caption.  AnyPace: its pace is not held against it. }
procedure RegisterBot(const word, Caption: string; AnyPace: boolean = False);
{ Addresses that are files, not pages someone reads: Prefix starts the path. }
procedure RegisterFilePath(const Prefix: string);
{ The crawler or tool a browser string names, as the visitor report counts
  it; '' for what looks like a browser. }
function BotName(const Agent: string): string;
{ An address of the house or the machines behind it, not a visitor's. }
function PrivateAddress(const Ip: string): boolean;
{ The report over the window FromAt to ToAt (days or moments), as the
  admin's tab asks for it (Me and MyAddress: the admin, left out when Hide). }
function VisitorReport(const FromAt, ToAt, Me, MyAddress, OwnHost: string; Hide: boolean): TJSONObject;
{ One address's story in the window: its requests, browsers, members,
  pages, statuses, timeline, the last of its requests, and the guard's facts. }
function AddressReport(const Ip, FromAt, ToAt, OwnHost: string): TJSONObject;

implementation

uses
  SysUtils, Classes, StrUtils, Math, Generics.Collections, httpdefs, httproute,
  SiteDb, SiteUsers, SiteGuard, SiteGuardRules, SiteAdmin, SiteStats, SiteCrawlers;

const
  // the people and the pages a report lists at most; their counts are all of them
  VISITOR_ROWS = 1000;
  // what gives a browser's name and takes the bare page: no styles, no
  // scripts, nothing a browser showing the page would ask for
  UNNAMED_BOTS = 'Unnamed bots (browser name, bare pages only)';
  // the page's files a browser takes, at least, to be one
  BROWSER_FILES = 2;

type
  TPerson = class
    Address, Agent, Member, First, Last, Entry, Referer: string;
    Requests, Pages, Polls: integer;
    // the search before this one, place and words, and when: to tell a box's typing from a new search
    LastSearch, LastSearchAt: string;
    // whether it came from a box that asks as one types (a page's search is finished)
    LastTyped: boolean;
  end;

  TSearchPlace = record
    Prefix, Place: string;
  end;

var
  SearchPlaces: array of TSearchPlace;

procedure RegisterSearchPlace(const Prefix, Place: string);
begin
  SetLength(SearchPlaces, Length(SearchPlaces) + 1);
  SearchPlaces[High(SearchPlaces)].Prefix := Prefix;
  SearchPlaces[High(SearchPlaces)].Place := Place;
end;

type
  // counts and sets by key, hashed: a day of crawlers is a hundred thousand
  // lines and tens of thousands of different pages, too many for sorted lists
  TIntMap = specialize TDictionary<string, integer>;
  TKeySet = specialize THashSet<string>;
  TMemo = specialize TDictionary<string, string>;

  // one address, whatever browsers it used: what might make it a concern
  TAddress = class
    Ip, First, Last, Bot, Crawler, Claimed, PeakAt: string;
    Requests, Pages, Polls, Missing, Refused, Errors, Probes, PeakMinute, Score: integer;
    // the minute before the current one, for a line a second out of order
    PrevMinuteCount: integer;
    // claims a checked engine's name, and its DNS says no
    Fake: boolean;
    // runs a script the site registered as welcome at any pace
    Mirror: boolean;
    // the browser strings (the first sixty-four) and the members seen from it, made when needed
    Agents, Members: TKeySet;
    Reasons: TJSONArray;
    MinuteAt: int64;
    MinuteCount: integer;
    destructor Destroy; override;
    { One request of its: when (At in seconds), with what, as whom, answered how.
      Poll: an open tab asking what is new, counted apart and no part of its pace. }
    procedure Note(const Stamp: string; At: int64; const Agent, Member: string; Code: integer; const Path: string; Page, Poll: boolean);
    { Weighs what it did; Score above 0 makes it a concern, Reasons say why. }
    procedure Judge;
    function AgentCount: integer;
    function MemberCount: integer;
    function JSON: TJSONObject;
  end;

  TAddresses = specialize TObjectDictionary<string, TAddress>;

  // a day's start in seconds since 1970, kept between lines of the same day
  TDayMemo = record
    Day: string;
    Start: int64;
  end;

  // the window in bars: pages people read, the rest they asked for, bots, errors
  TTimeline = record
    Start: int64;
    Step, Count: integer;
    Counts: array[0..3] of array of integer;
  end;

  TBot = class
    Name: string;
    Requests: integer;
    Last: string;
    // every address, and the first few seen, which the DNS check asks about
    Addresses: TKeySet;
    Samples: TStringList;
    Paths: TIntMap;
    Verified, Unverified: boolean;
    constructor Create;
    destructor Destroy; override;
  end;

  TPage = class
    Views: integer;
    People: TKeySet;
    constructor Create;
    destructor Destroy; override;
  end;

  TCount = class
    N: integer;
    Last: string;
  end;

  // a crawler known by its company's published addresses
  TCrawler = class
    Name, Company, Last: string;
    Requests, Pages: integer;
    Addresses: TKeySet;
    Paths: TIntMap;
    // requests by part of the site, as the units register their parts
    Parts: TIntMap;
    constructor Create;
    destructor Destroy; override;
  end;

  // a browser string naming a listed crawler, from outside its company's addresses
  TPretender = class
    Name, Company, Last, Sample: string;
    Requests: integer;
    Addresses: TKeySet;
    constructor Create;
    destructor Destroy; override;
  end;

  TPeople = specialize TObjectDictionary<string, TPerson>;
  TBots = specialize TObjectDictionary<string, TBot>;
  TPages = specialize TObjectDictionary<string, TPage>;
  TCounts = specialize TObjectDictionary<string, TCount>;
  TCrawlers = specialize TObjectDictionary<string, TCrawler>;
  TPretenders = specialize TObjectDictionary<string, TPretender>;

  // the last requests of one kind, the oldest overwritten: the admin's list
  // of latest requests needs no more than these
  TLatest = record
    Lines, Marks: array of string;
    Next, Count: integer;
  end;

{ A list compared byte for byte: the report sorts addresses, paths and
  browser strings, and the RTL's default, comparing as the system's
  language would, made a busy day take seconds. }
function PlainList: TStringList;
begin
  Result := TStringList.Create;
  Result.CaseSensitive := True;
  Result.UseLocale := False;
end;

constructor TBot.Create;
begin
  Addresses := TKeySet.Create;
  Samples := PlainList;
  Paths := TIntMap.Create;
end;

destructor TBot.Destroy;
begin
  Addresses.Free;
  Samples.Free;
  Paths.Free;
  inherited;
end;

constructor TPage.Create;
begin
  People := TKeySet.Create;
end;

destructor TPage.Destroy;
begin
  People.Free;
  inherited;
end;

constructor TCrawler.Create;
begin
  Addresses := TKeySet.Create;
  Paths := TIntMap.Create;
  Parts := TIntMap.Create;
end;

destructor TCrawler.Destroy;
begin
  Addresses.Free;
  Paths.Free;
  Parts.Free;
  inherited;
end;

constructor TPretender.Create;
begin
  Addresses := TKeySet.Create;
end;

destructor TPretender.Destroy;
begin
  Addresses.Free;
  inherited;
end;

procedure KeepLatest(var Latest: TLatest; const Line, Mark: string);
begin
  Latest.Lines[Latest.Next] := Line;
  Latest.Marks[Latest.Next] := Mark;
  Latest.Next := (Latest.Next + 1) mod Length(Latest.Lines);
  if Latest.Count < Length(Latest.Lines) then
    Inc(Latest.Count);
end;

procedure StartLatest(var Latest: TLatest; Size: integer);
begin
  SetLength(Latest.Lines, Size);
  SetLength(Latest.Marks, Size);
  Latest.Next := 0;
  Latest.Count := 0;
end;

destructor TAddress.Destroy;
begin
  Agents.Free;
  Members.Free;
  Reasons.Free;
  inherited;
end;

procedure TAddress.Note(const Stamp: string; At: int64; const Agent, Member: string; Code: integer; const Path: string; Page, Poll: boolean);
begin
  if Poll then
    Inc(Polls)
  else
    Inc(Requests);
  if First = '' then
    First := Stamp;
  Last := Stamp;
  if Page then
    Inc(Pages);
  // its busiest minute: the lines come in time order, give or take a second
  if Poll then
  // a tab left open is no pace of its reader's
  else if At div 60 = MinuteAt - 1 then
  begin
    Inc(PrevMinuteCount);
    if PrevMinuteCount > PeakMinute then
    begin
      PeakMinute := PrevMinuteCount;
      PeakAt := Stamp;
    end;
  end
  else
  begin
    if At div 60 <> MinuteAt then
    begin
      if At div 60 = MinuteAt + 1 then
        PrevMinuteCount := MinuteCount
      else
        PrevMinuteCount := 0;
      MinuteAt := At div 60;
      MinuteCount := 0;
    end;
    Inc(MinuteCount);
    if MinuteCount > PeakMinute then
    begin
      PeakMinute := MinuteCount;
      PeakAt := Stamp;
    end;
  end;
  if Agents = nil then
    Agents := TKeySet.Create;
  if Agents.Count < 64 then
    Agents.Add(Agent);
  if Member <> '' then
  begin
    if Members = nil then
      Members := TKeySet.Create;
    Members.Add(Member);
  end;
  case Code of
    404:
    begin
      Inc(Missing);
      // an old link is not a probe, as the guard has it
      if Probing(Path) and not OldLink(Path) then
        Inc(Probes);
    end;
    403, 429:
      Inc(Refused);
    500..599:
      Inc(Errors);
  end;
end;

function TAddress.AgentCount: integer;
begin
  if Agents = nil then
    Result := 0
  else
    Result := Agents.Count;
end;

function TAddress.MemberCount: integer;
begin
  if Members = nil then
    Result := 0
  else
    Result := Members.Count;
end;

procedure TAddress.Judge;

  procedure Reason(const Kind: string; N, Weight: integer; const Text: string = '');
  begin
    Reasons.Add(TJSONObject.Create(['kind', Kind, 'n', N, 'text', Text]));
    Inc(Score, Weight);
  end;

begin
  Reasons.Free;
  Reasons := TJSONArray.Create;
  Score := 0;
  // a published crawler is welcome at any pace, and so is a script the
  // site registered as such; the rest are measured by theirs
  if (Crawler = '') and not Mirror then
  begin
    if PeakMinute >= 600 then
      Reason('rate', PeakMinute, 5, PeakAt)
    else if PeakMinute >= 120 then
      Reason('rate', PeakMinute, 3, PeakAt);
    if Requests >= 5000 then
      Reason('requests', Requests, 2);
    if ((Bot = '') or (Bot = UNNAMED_BOTS)) and (Pages >= 2000) then
      Reason('browser-crawl', Pages, 2);
    if AgentCount >= 10 then
      Reason('agents', AgentCount, 3)
    else if AgentCount >= 5 then
      Reason('agents', AgentCount, 2);
    if Claimed <> '' then
      Reason('pretender', 0, 3, Claimed)
    else if Fake then
      Reason('fake', 0, 3, Bot);
  end;
  // old links, our own limits and our own faults are no mark against a
  // published crawler; probing for secrets is, whoever does it
  if (Missing >= 30) and (Crawler = '') then
    Reason('missing', Missing, 2);
  if Probes > 0 then
    Reason('probes', Probes, 3);
  if (Refused >= 20) and (Crawler = '') then
    Reason('refused', Refused, 2);
  if (Errors >= 5) and (Crawler = '') then
    Reason('errors', Errors, 1);
  if MemberCount >= 3 then
    Reason('members', MemberCount, 1);
end;

function TAddress.JSON: TJSONObject;
begin
  if Reasons = nil then
    Judge;
  Result := TJSONObject.Create(['ip', Ip, 'requests', Requests, 'polls', Polls, 'pages', Pages, 'peak', PeakMinute, 'peak_at', PeakAt,
    'agents', AgentCount, 'members', MemberCount, 'missing', Missing, 'refused', Refused, 'errors', Errors, 'probes', Probes, 'bot', Bot,
    'crawler', Crawler, 'first', First, 'last', Last, 'score', Score, 'reasons', Reasons.Clone]);
end;

{ A log time (yyyy-mm-ddThh:nn:ssZ) in seconds since 1970; 0 when it is not one. }
function Moment(const Stamp: string; var Memo: TDayMemo): int64;
var
  Date: TDateTime;
begin
  if Length(Stamp) < 19 then
    Exit(0);
  if Copy(Stamp, 1, 10) <> Memo.Day then
  begin
    Memo.Day := Copy(Stamp, 1, 10);
    if TryEncodeDate(StrToIntDef(Copy(Stamp, 1, 4), 0), StrToIntDef(Copy(Stamp, 6, 2), 0), StrToIntDef(Copy(Stamp, 9, 2), 0), Date) then
      Memo.Start := (Trunc(Date) - UnixDateDelta) * int64(86400)
    else
      Memo.Start := 0;
  end;
  if Memo.Start = 0 then
    Exit(0);
  Result := Memo.Start + StrToIntDef(Copy(Stamp, 12, 2), 0) * 3600 + StrToIntDef(Copy(Stamp, 15, 2), 0) * 60 + StrToIntDef(Copy(Stamp, 18, 2), 0);
end;

function StampOf(At: int64): string;
begin
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', At / 86400 + UnixDateDelta);
end;

{ The moment Seconds before At (after it when negative): a seek enters the
  log a little early, and a reading leaves it a little late, since a line
  can sit a second or two out of order. }
function MomentBefore(const At: string; Seconds: integer): string;
var
  Memo: TDayMemo;
  M: int64;
begin
  Memo.Day := '';
  M := Moment(At, Memo);
  if M <= 0 then
    Exit(At);
  Result := StampOf(M - Seconds);
end;

{ Bars sized to the window: a minute for an hour or two, five for eight
  hours, a quarter for a day, half an hour for three, two hours for a
  week, then days; never more than four hundred. }
procedure StartTimeline(var T: TTimeline; const FromAt, ToAt: string);
var
  Memo: TDayMemo;
  Span: int64;
  K: integer;
begin
  Memo.Day := '';
  T.Start := Moment(FromAt, Memo);
  Span := Moment(ToAt, Memo) - T.Start + 1;
  if Span < 1 then
    Span := 1;
  if Span <= 2 * 3600 then
    T.Step := 60
  else if Span <= 8 * 3600 + 60 then
    T.Step := 300
  else if Span <= 26 * 3600 then
    T.Step := 900
  else if Span <= 3 * 86400 then
    T.Step := 1800
  else if Span <= 8 * 86400 then
    T.Step := 7200
  else
    T.Step := 86400;
  while (Span + T.Step - 1) div T.Step > 400 do
    T.Step := T.Step * 2;
  T.Count := (Span + T.Step - 1) div T.Step;
  for K := 0 to 3 do
    SetLength(T.Counts[K], T.Count);
end;

procedure Tick(var T: TTimeline; Kind: integer; At: int64);
var
  I: int64;
begin
  if At <= 0 then
    Exit;
  I := (At - T.Start) div T.Step;
  if (I >= 0) and (I < T.Count) then
    Inc(T.Counts[Kind][I]);
end;

function TimelineJSON(const T: TTimeline): TJSONObject;
const
  NAMES: array[0..3] of string = ('pages', 'other', 'bots', 'errors');
var
  K, I: integer;
  List: TJSONArray;
begin
  Result := TJSONObject.Create(['start', StampOf(T.Start), 'step', T.Step]);
  for K := 0 to 3 do
  begin
    List := TJSONArray.Create;
    for I := 0 to T.Count - 1 do
      List.Add(T.Counts[K][I]);
    Result.Add(NAMES[K], List);
  end;
end;

const
  // a word in the browser string, and the name the bot goes by; the first
  // that matches wins, so the particular come before the general
  BOT_NAMES: array[0..62] of array[0..1] of string = (
    ('googlebot', 'Googlebot'), ('google-inspectiontool', 'Google Inspection Tool'), ('googleother', 'GoogleOther'),
    ('storebot-google', 'Google Storebot'), ('adsbot-google', 'Google AdsBot'), ('mediapartners-google', 'Google AdSense'),
    ('google-extended', 'Google-Extended'), ('feedfetcher-google', 'Google Feedfetcher'), ('google-read-aloud', 'Google Read Aloud'),
    ('bingbot', 'Bingbot'), ('bingpreview', 'Bing Preview'), ('msnbot', 'MSNBot'), ('adidxbot', 'Bing AdIdxBot'),
    ('duckduckbot', 'DuckDuckBot'), ('duckassistbot', 'DuckAssistBot'), ('applebot', 'Applebot'), ('yandex', 'YandexBot'),
    ('baiduspider', 'Baiduspider'), ('petalbot', 'PetalBot'), ('seznambot', 'SeznamBot'), ('sogou', 'Sogou'),
    ('qwantbot', 'Qwantbot'), ('mojeekbot', 'MojeekBot'), ('yahoo! slurp', 'Yahoo Slurp'),
    ('gptbot', 'GPTBot (OpenAI)'), ('chatgpt-user', 'ChatGPT-User'), ('oai-searchbot', 'OAI-SearchBot'),
    ('claudebot', 'ClaudeBot (Anthropic)'), ('claude-user', 'Claude-User'), ('claude-searchbot', 'Claude-SearchBot'),
    ('anthropic-ai', 'anthropic-ai'), ('perplexity', 'PerplexityBot'), ('bytespider', 'Bytespider (ByteDance)'),
    ('amazonbot', 'Amazonbot'), ('ccbot', 'CCBot (Common Crawl)'), ('meta-externalagent', 'Meta external agent'),
    ('facebookexternalhit', 'Facebook link preview'), ('meta-externalfetcher', 'Meta fetcher'), ('twitterbot', 'Twitterbot'),
    ('linkedinbot', 'LinkedInBot'), ('slackbot', 'Slackbot'), ('discordbot', 'Discordbot'), ('telegrambot', 'TelegramBot'),
    ('whatsapp', 'WhatsApp link preview'), ('semrushbot', 'SemrushBot'), ('ahrefsbot', 'AhrefsBot'), ('mj12bot', 'MJ12bot (Majestic)'),
    ('dotbot', 'DotBot (Moz)'), ('dataforseobot', 'DataForSeoBot'), ('blexbot', 'BLEXBot'), ('serpstatbot', 'SerpstatBot'),
    ('archive.org_bot', 'Internet Archive'), ('ia_archiver', 'Internet Archive'), ('uptimerobot', 'UptimeRobot'),
    ('headlesschrome', 'Headless Chrome'), ('curl/', 'curl'), ('wget', 'Wget'),
    ('python', 'Python script'), ('go-http-client', 'Go program'), ('okhttp', 'OkHttp'), ('java/', 'Java program'),
    ('node-fetch', 'Node.js script'), ('axios', 'Node.js script'));
  // the rest that say what they are
  BOT_WORDS: array[0..9] of string = ('bot', 'crawl', 'spider', 'slurp', 'scrap', 'fetch', 'scan', 'monitor', 'preview', 'http');
  // the crawlers whose DNS says whether they are who they claim
  CHECKED_NAMES: array[0..5] of string = ('Googlebot', 'Bingbot', 'Applebot', 'YandexBot', 'DuckDuckBot', 'Yahoo Slurp');

var
  ReportLock: TRTLCriticalSection;
  // a finished day's crawler counts (day=name=count,...), kept: it does not
  // change; read from the logs folder's crawler-days.txt once (PastLoaded)
  PastDays: TStringList;
  PastLoaded: boolean;
  PastSignature: string;
  // one report built at a time: a second asking for the same waits for it
  BuildLock: TRTLCriticalSection;
  KeptKey: string;
  KeptAt: TDateTime;
  KeptReport: string;

var
  OwnBots: array of record
    word, Caption: string;
    AnyPace: boolean;
    end;
  FilePaths: array of string;

procedure RegisterBot(const word, Caption: string; AnyPace: boolean);
begin
  SetLength(OwnBots, Length(OwnBots) + 1);
  OwnBots[High(OwnBots)].word := LowerCase(word);
  OwnBots[High(OwnBots)].Caption := Caption;
  OwnBots[High(OwnBots)].AnyPace := AnyPace;
end;

procedure RegisterFilePath(const Prefix: string);
begin
  SetLength(FilePaths, Length(FilePaths) + 1);
  FilePaths[High(FilePaths)] := LowerCase(Prefix);
end;

{ The registered file addresses, for the admin page's own page test. }
procedure AdminFilePaths(const Me: TMember; Answer: TJSONObject);
var
  List: TJSONArray;
  Prefix: string;
begin
  List := TJSONArray.Create;
  for Prefix in FilePaths do
    List.Add(Prefix);
  Answer.Add('file_paths', List);
end;

{ True for the name of a registered script that may go at any pace. }
function AnyPaceBot(const Name: string): boolean;
var
  I: integer;
begin
  Result := False;
  for I := 0 to High(OwnBots) do
    if OwnBots[I].AnyPace and (OwnBots[I].Caption = Name) then
      Exit(True);
end;

function BotName(const Agent: string): string;
var
  Lower, word: string;
  I, P, Start, Stop: integer;
begin
  Lower := LowerCase(Agent);
  if Trim(Lower) = '' then
    Exit('No browser name');
  for I := 0 to High(OwnBots) do
    if Pos(OwnBots[I].word, Lower) > 0 then
      Exit(OwnBots[I].Caption);
  for I := Low(BOT_NAMES) to High(BOT_NAMES) do
    if Pos(BOT_NAMES[I][0], Lower) > 0 then
      Exit(BOT_NAMES[I][1]);
  // a browser says Mozilla and names its engine; a crawler built on one
  // still says what it is, so the words below are only for the rest
  for word in BOT_WORDS do
  begin
    P := Pos(word, Lower);
    if (P > 0) and ((word <> 'http') or (Pos('mozilla', Lower) = 0)) then
    begin
      // its own name: the word of the browser string the match sits in,
      // without its version ("ExampleBot/1.0" is ExampleBot)
      Start := P;
      while (Start > 1) and not (Agent[Start - 1] in [' ', ';', '(', ')', ',']) do
        Dec(Start);
      Stop := P;
      while (Stop < Length(Agent)) and not (Agent[Stop + 1] in [' ', ';', '(', ')', ',', '/']) do
        Inc(Stop);
      Result := Copy(Agent, Start, Stop - Start + 1);
      if StartsStr('+', Result) or (Pos('://', Result) > 0) or (Pos('@', Result) > 0) then
        Result := Trim(Copy(Agent, 1, 40));
      Exit(Copy(Result, 1, 40));
    end;
  end;
  if (Pos('mozilla', Lower) = 0) and (Pos('opera', Lower) = 0) then
    Exit('Other: ' + Trim(Copy(Agent, 1, 40)));
  Result := '';
end;

{ A page someone reads: not a picture, a script, a style, an API call or a feed. }
function IsPage(const Method, Path: string): boolean;
var
  P, Prefix: string;
begin
  Result := False;
  if Method <> 'GET' then
    Exit;
  P := LowerCase(Path);
  if Pos('?', P) > 0 then
    P := Copy(P, 1, Pos('?', P) - 1);
  if StartsStr('/static/', P) or StartsStr('/api/', P) or StartsStr('/images/', P) or StartsStr('/files/', P) or StartsStr('/f/', P) or
    StartsStr('/avatar', P) or StartsStr('/words.js', P) or StartsStr('/ws', P) or (P = '/robots.txt') or StartsStr('/sitemap', P) or
    StartsStr('/favicon', P) or StartsStr('/manifest', P) or StartsStr('/sw.js', P) then
    Exit;
  for Prefix in FilePaths do
    if StartsStr(Prefix, P) then
      Exit;
  Result := not (EndsStr('.css', P) or EndsStr('.js', P) or EndsStr('.png', P) or EndsStr('.jpg', P) or EndsStr('.jpeg', P) or EndsStr('.gif', P) or
    EndsStr('.svg', P) or EndsStr('.ico', P) or EndsStr('.webp', P) or EndsStr('.woff2', P) or EndsStr('.woff', P) or EndsStr('.xml', P) or
    EndsStr('.txt', P) or EndsStr('.json', P) or EndsStr('.map', P));
end;

{ An open tab asking what is new (the chat bubble, the chat itself): the
  page's script does it by itself, every half minute, for as long as the
  tab stays open. }
function IsPoll(const Path: string): boolean;
begin
  Result := BrowserProof(Path) = 2;
end;

{ The house and the machines behind it. }
function PrivateAddress(const Ip: string): boolean;
var
  Second: integer;
begin
  Result := StartsStr('127.', Ip) or StartsStr('10.', Ip) or StartsStr('192.168.', Ip) or (Ip = '::1') or StartsStr('fe80:', LowerCase(Ip)) or
    StartsStr('fc', LowerCase(Ip)) or StartsStr('fd', LowerCase(Ip));
  if not Result and StartsStr('172.', Ip) then
  begin
    Second := StrToIntDef(Copy(Ip, 5, Pos('.', Copy(Ip, 5, 4)) - 1), 0);
    Result := (Second >= 16) and (Second <= 31);
  end;
end;

function HostOf(const Url: string): string;
var
  P: integer;
begin
  Result := Url;
  P := Pos('://', Result);
  if P = 0 then
    Exit('');
  Delete(Result, 1, P + 2);
  P := Pos('/', Result);
  if P > 0 then
    Result := Copy(Result, 1, P - 1);
  P := Pos(':', Result);
  if P > 0 then
    Result := Copy(Result, 1, P - 1);
  Result := LowerCase(Result);
  if StartsStr('www.', Result) then
    Delete(Result, 1, 4);
end;

{ The words in ?q= on a search page. }
function SearchWords(const Path: string): string;
var
  Query, Pair: string;
begin
  Result := '';
  if Pos('?', Path) = 0 then
    Exit;
  Query := Copy(Path, Pos('?', Path) + 1, MaxInt);
  for Pair in Query.Split(['&']) do
    if StartsStr('q=', Pair) then
      Exit(Trim(Copy(HTTPDecode(StringReplace(Copy(Pair, 3, MaxInt), '+', ' ', [rfReplaceAll])), 1, 80)));
end;

function SearchPlace(const Path: string): string;
var
  Bare: string;
  I: integer;
begin
  Result := '';
  Bare := Path;
  if Pos('?', Bare) > 0 then
    Bare := Copy(Bare, 1, Pos('?', Bare) - 1);
  // a whole path, or one with the start of its query when that tells boxes apart
  for I := 0 to High(SearchPlaces) do
    if (Bare = SearchPlaces[I].Prefix) or ((Pos('?', SearchPlaces[I].Prefix) > 0) and StartsStr(SearchPlaces[I].Prefix, Path)) then
      Exit(SearchPlaces[I].Place);
end;

{ Seconds between two of the log's times (yyyy-mm-ddThh:nn:ssZ); a day
  apart or more is a day's worth. }
function SecondsApart(const A, B: string): integer;

  function Seconds(const T: string): integer;
  begin
    Result := StrToIntDef(Copy(T, 12, 2), 0) * 3600 + StrToIntDef(Copy(T, 15, 2), 0) * 60 + StrToIntDef(Copy(T, 18, 2), 0);
  end;

begin
  if Copy(A, 1, 10) <> Copy(B, 1, 10) then
    Exit(86400);
  Result := Abs(Seconds(B) - Seconds(A));
end;

{ The latest requests kept, newest first, as the admin's list of requests:
  a mark is a person's kind of request (page or other) or a bot's name. }
procedure AddLatest(List: TJSONArray; const Latest: TLatest; Bots: boolean);
var
  I, At, N: integer;
  F: TFields;
  Line: TJSONObject;
begin
  for I := 0 to Latest.Count - 1 do
  begin
    At := (Latest.Next - 1 - I + 2 * Length(Latest.Lines)) mod Length(Latest.Lines);
    N := SplitLine(Latest.Lines[At], F);
    Line := LineJSON(F, N);
    if Bots then
    begin
      Line.Add('kind', 'bot');
      Line.Add('bot', Latest.Marks[At]);
    end
    else
    begin
      Line.Add('kind', Latest.Marks[At]);
      Line.Add('bot', '');
    end;
    List.Add(Line);
  end;
end;

{ A database to ask: not in the report's own tests, which run without one. }
function DatabaseReady: boolean;
begin
  try
    CheckConnection;
    Result := True;
  except
    Result := False;
  end;
end;

{ The guard's word on each address it has blocked, as the Blocked list
  gives it: forgood, blocked (for now) or over. }
function BlockStates: TStringList;
begin
  Result := TStringList.Create;
  if not DatabaseReady then
    Exit;
  with Query('SELECT ip, CASE WHEN blocked_until IS NULL THEN ''forgood'' WHEN blocked_until > NOW() THEN ''blocked'' ELSE ''over'' END FROM blocks', []) do
  try
    while not EOF do
    begin
      Result.Values[Fields[0].AsString] := Fields[1].AsString;
      Next;
    end;
  finally
    Free;
  end;
end;

{ AbuseIPDB's confidence for the addresses unit SiteAbuse looked up. }
function AbuseScores: TStringList;
begin
  Result := TStringList.Create;
  if not DatabaseReady then
    Exit;
  with Query('SELECT ip, score FROM abuse_checks', []) do
  try
    while not EOF do
    begin
      Result.Values[Fields[0].AsString] := Fields[1].AsString;
      Next;
    end;
  finally
    Free;
  end;
end;

{ Concerns: the worst first, then the busiest, then by address. }
function ByScore(List: TStringList; A, B: integer): integer;
begin
  Result := TAddress(List.Objects[B]).Score - TAddress(List.Objects[A]).Score;
  if Result = 0 then
    Result := TAddress(List.Objects[B]).Requests - TAddress(List.Objects[A]).Requests;
  if Result = 0 then
    Result := CompareStr(List[A], List[B]);
end;

procedure Bump(Map: TIntMap; const Key: string);
var
  N: integer;
begin
  if Map.TryGetValue(Key, N) then
    Map[Key] := N + 1
  else
    Map.Add(Key, 1);
end;

function CountIn(Map: TCounts; const Key: string): TCount;
begin
  if not Map.TryGetValue(Key, Result) then
  begin
    Result := TCount.Create;
    Map.Add(Key, Result);
  end;
end;

{ Ranked lists: most first, and between equals by name, so the rows cut
  off at a list's end are always the same ones. }
function ByNumber(List: TStringList; A, B: integer): integer;
begin
  Result := PtrInt(List.Objects[B]) - PtrInt(List.Objects[A]);
  if Result = 0 then
    Result := CompareStr(List[A], List[B]);
end;

function ByPages(List: TStringList; A, B: integer): integer;
var
  X, Y: TPerson;
begin
  X := TPerson(List.Objects[A]);
  Y := TPerson(List.Objects[B]);
  Result := Y.Pages - X.Pages;
  if Result = 0 then
    Result := Y.Requests - X.Requests;
  if Result = 0 then
    Result := CompareStr(List[A], List[B]);
end;

function ByBotRequests(List: TStringList; A, B: integer): integer;
begin
  Result := TBot(List.Objects[B]).Requests - TBot(List.Objects[A]).Requests;
  if Result = 0 then
    Result := CompareStr(List[A], List[B]);
end;

function ByViews(List: TStringList; A, B: integer): integer;
begin
  Result := TPage(List.Objects[B]).Views - TPage(List.Objects[A]).Views;
  if Result = 0 then
    Result := CompareStr(List[A], List[B]);
end;

function ByCount(List: TStringList; A, B: integer): integer;
begin
  Result := TCount(List.Objects[B]).N - TCount(List.Objects[A]).N;
  if Result = 0 then
    Result := CompareStr(List[A], List[B]);
end;

function ByCrawlerRequests(List: TStringList; A, B: integer): integer;
begin
  Result := TCrawler(List.Objects[B]).Requests - TCrawler(List.Objects[A]).Requests;
  if Result = 0 then
    Result := CompareStr(List[A], List[B]);
end;

function ByPretenderRequests(List: TStringList; A, B: integer): integer;
begin
  Result := TPretender(List.Objects[B]).Requests - TPretender(List.Objects[A]).Requests;
  if Result = 0 then
    Result := CompareStr(List[A], List[B]);
end;

{ A map's keys, the count in each one's object, most first. }
function RankedNumbers(Map: TIntMap): TStringList;
var
  Key: string;
begin
  Result := PlainList;
  for Key in Map.Keys do
    Result.AddObject(Key, TObject(PtrInt(Map[Key])));
  Result.CustomSort(@ByNumber);
end;

{ The published crawler for an address, remembered in Memo as
  company#2crawler: a day of a hundred thousand lines asks for every line. }
function MemoCrawler(Memo: TMemo; const Ip: string; out Company: string): string;
var
  Seen: string;
begin
  if Memo.TryGetValue(Ip, Seen) then
  begin
    Company := Copy(Seen, 1, Pos(#2, Seen) - 1);
    Exit(Copy(Seen, Pos(#2, Seen) + 1, MaxInt));
  end;
  Result := PublishedCrawler(Ip, Company);
  Memo.Add(Ip, Company + #2 + Result);
end;

{ A browser string's bot name and the company it claims, remembered the
  same way (name#2company; a logged line has no control characters, so
  neither can be in a name): there are far fewer browser strings than lines. }
procedure MemoAgent(Agents: TMemo; const Agent: string; out Name, Claimed: string);
var
  Seen: string;
begin
  if Agents.TryGetValue(Agent, Seen) then
  begin
    Name := Copy(Seen, 1, Pos(#2, Seen) - 1);
    Claimed := Copy(Seen, Pos(#2, Seen) + 1, MaxInt);
    Exit;
  end;
  Name := BotName(Agent);
  Claimed := ClaimedCompany(Agent);
  Agents.Add(Agent, Name + #2 + Claimed);
end;

{ The published crawler lists the counts are made with: each list's name,
  its number of address ranges and its own date.  '' while any list has no
  ranges (not fetched yet, or its fetch failed): counts made then are not
  kept.  Kept counts made with other lists are dropped. }
function CrawlerListsSignature: string;
var
  Sources: TJSONArray;
  I: integer;
begin
  Result := '';
  Sources := CrawlerSourcesJSON;
  try
    for I := 0 to Sources.Count - 1 do
      with Sources.Objects[I] do
      begin
        if Get('ranges', 0) <= 0 then
          Exit('');
        Result := Result + Get('name', '') + ':' + IntToStr(Get('ranges', 0)) + ':' + Get('created', '') + ';';
      end;
  finally
    Sources.Free;
  end;
end;

const
  PAST_DAYS_HEADER = 'crawler counts by day, version 2';

function PastDaysFile: string;
begin
  Result := LogsFolder + 'crawler-days.txt';
end;

{ The finished days' crawler counts as made with the lists Signature: read
  once from the logs folder, where they outlast a restart (a day whose log
  has gone is dropped), and dropped when the lists change.  Under ReportLock. }
procedure UsePastDays(const Signature: string);
var
  Kept, Days: TStringList;
  I: integer;
begin
  if PastLoaded then
  begin
    if PastSignature <> Signature then
    begin
      PastDays.Clear;
      PastSignature := Signature;
    end;
    Exit;
  end;
  PastLoaded := True;
  PastSignature := Signature;
  if not FileExists(PastDaysFile) then
    Exit;
  Kept := TStringList.Create;
  Days := AccessLogDays;
  try
    try
      Kept.LoadFromFile(PastDaysFile);
    except
      on E: Exception do
      begin
        Log('Visitors: the crawler counts by day could not be read: ' + E.Message);
        Exit;
      end;
    end;
    if (Kept.Count = 0) or (Kept[0] <> PAST_DAYS_HEADER + #9 + Signature) then
      Exit;
    for I := 1 to Kept.Count - 1 do
      if (Days.IndexOf(Kept.Names[I]) >= 0) and (PastDays.IndexOfName(Kept.Names[I]) < 0) then
        PastDays.Add(Kept[I]);
  finally
    Kept.Free;
    Days.Free;
  end;
end;

{ Written whole beside itself, then put in its place.  Under ReportLock. }
procedure SavePastDays;
var
  Text, Days: TStringList;
  I: integer;
begin
  Text := TStringList.Create;
  Days := AccessLogDays;
  try
    // the days whose logs have gone go too
    for I := PastDays.Count - 1 downto 0 do
      if Days.IndexOf(PastDays.Names[I]) < 0 then
        PastDays.Delete(I);
    Text.Add(PAST_DAYS_HEADER + #9 + PastSignature);
    Text.AddStrings(PastDays);
    try
      Text.SaveToFile(PastDaysFile + '.part');
      if not RenameFile(PastDaysFile + '.part', PastDaysFile) then
        Log('Visitors: the crawler counts by day could not be put in place');
    except
      on E: Exception do
        Log('Visitors: the crawler counts by day could not be kept: ' + E.Message);
    end;
  finally
    Text.Free;
    Days.Free;
  end;
end;

{ Keeps a finished day's counts (name=count, comma separated), once.  The
  line is added whole, as an empty value given to Values would remove it. }
procedure KeepPastDay(const Day, Counts, Signature: string);
begin
  // counted while the lists were missing, or changed since the counting began
  if (Signature = '') or (CrawlerListsSignature <> Signature) then
    Exit;
  EnterCriticalSection(ReportLock);
  try
    UsePastDays(Signature);
    if PastDays.IndexOfName(Day) < 0 then
    begin
      PastDays.Add(Day + '=' + Counts);
      SavePastDays;
    end;
  finally
    LeaveCriticalSection(ReportLock);
  end;
end;

{ A day's requests by each published crawler, every request counted (the
  admin's too, so the counts do not depend on who asked), name=count lines;
  a finished day's are kept and not read again. }
function CrawlerCounts(const Day: string; Memo: TMemo; Finished: boolean; const Signature: string): TStringList;
var
  Reader: TLogReader;
  Counts: TIntMap;
  Line, Name, Company, Key: string;
  F: TFields;
  I: integer;
begin
  Result := PlainList;
  try
    if Finished and (Signature <> '') then
    begin
      EnterCriticalSection(ReportLock);
      try
        UsePastDays(Signature);
        I := PastDays.IndexOfName(Day);
        if I >= 0 then
        begin
          Result.CommaText := PastDays.ValueFromIndex[I];
          Exit;
        end;
      finally
        LeaveCriticalSection(ReportLock);
      end;
    end;
    Counts := TIntMap.Create;
    try
      Reader := OpenLog(Day, -1);
      if Reader <> nil then
      try
        while Reader.Next(Line) do
        begin
          if SplitLine(Line, F) < 6 then
            Continue;
          Name := MemoCrawler(Memo, F[1], Company);
          if Name <> '' then
            Bump(Counts, Name);
        end;
      finally
        Reader.Free;
      end;
      for Key in Counts.Keys do
        Result.Values[Key] := IntToStr(Counts[Key]);
      Result.Sort;
    finally
      Counts.Free;
    end;
    if Finished then
      KeepPastDay(Day, Result.CommaText, Signature);
  except
    Result.Free;
    raise;
  end;
end;

{ The days from FromDay to ToDay that have a log, oldest first. }
function DaysBetween(const FromDay, ToDay: string): TStringList;
var
  All: TStringList;
  I: integer;
begin
  Result := PlainList;
  All := AccessLogDays;
  try
    for I := All.Count - 1 downto 0 do
      if (All[I] >= FromDay) and (All[I] <= ToDay) then
        Result.Add(All[I]);
  finally
    All.Free;
  end;
end;

procedure ReportConcerns(Answer: TJSONObject; Addresses: TAddresses);
const
  CONCERN_ROWS = 200;
var
  Ranked, States, Scores: TStringList;
  Address: TAddress;
  Row: TJSONObject;
  List: TJSONArray;
  I: integer;
begin
  // the addresses of concern, worst first, before the people's rows are
  // marked; one the admin vouched for (allowed_ips) or the house's own is
  // not weighed, however it behaves
  Ranked := PlainList;
  try
    for Address in Addresses.Values do
    begin
      Address.Judge;
      if (Address.Score > 0) and NeverBlocked(Address.Ip) then
        Address.Score := 0;
      if Address.Score > 0 then
        Ranked.AddObject(Address.Ip, Address);
    end;
    Ranked.CustomSort(@ByScore);
    List := TJSONArray.Create;
    // each row says whether the address is blocked, so the list shows it unopened
    States := BlockStates;
    Scores := AbuseScores;
    try
      for I := 0 to Min(Ranked.Count, CONCERN_ROWS) - 1 do
      begin
        Row := TAddress(Ranked.Objects[I]).JSON;
        if States.Values[Ranked[I]] <> '' then
          Row.Add('block', States.Values[Ranked[I]]);
        if Scores.Values[Ranked[I]] <> '' then
          Row.Add('abuse', StrToIntDef(Scores.Values[Ranked[I]], 0));
        List.Add(Row);
      end;
    finally
      States.Free;
      Scores.Free;
    end;
    Answer.Add('concerns', List);
    Answer.Add('concerns_count', Ranked.Count);
  finally
    Ranked.Free;
  end;
end;

procedure ReportPeople(Answer: TJSONObject; People: TPeople; Addresses: TAddresses);
var
  Ranked: TStringList;
  Key: string;
  Person: TPerson;
  Address: TAddress;
  List: TJSONArray;
  I, K, Flag: integer;
begin
  // people: those who read most first; a passer-by with no page is left for the count
  Ranked := PlainList;
  try
    for Key in People.Keys do
      Ranked.AddObject(Key, People[Key]);
    Ranked.CustomSort(@ByPages);
    List := TJSONArray.Create;
    // the list stops at the VISITOR_ROWS who read most; the count is all of them
    K := 0;
    for I := 0 to Ranked.Count - 1 do
    begin
      Person := TPerson(Ranked.Objects[I]);
      if Person.Pages > 0 then
        Inc(K);
      if (Person.Pages = 0) or (List.Count >= VISITOR_ROWS) then
        Continue;
      Flag := 0;
      if Addresses.TryGetValue(Person.Address, Address) then
        Flag := Address.Score;
      List.Add(TJSONObject.Create(['ip', Person.Address, 'agent', Person.Agent, 'member', Person.Member, 'pages', Person.Pages, 'requests',
        Person.Requests, 'polls', Person.Polls, 'first', Person.First, 'last', Person.Last, 'entry', Person.Entry, 'referer', Person.Referer, 'flagged', Flag]));
    end;
    Answer.Add('visitors', List);
    Answer.Add('visitors_count', K);
  finally
    Ranked.Free;
  end;
end;

procedure ReportBots(Answer: TJSONObject; Bots: TBots; Crawlers: TCrawlers);
var
  Ranked, Top: TStringList;
  Key, Check: string;
  Bot: TBot;
  List, Paths: TJSONArray;
  I, J: integer;
begin
  Ranked := PlainList;
  try
    for Key in Bots.Keys do
      Ranked.AddObject(Key, Bots[Key]);
    Ranked.CustomSort(@ByBotRequests);
    List := TJSONArray.Create;
    for I := 0 to Ranked.Count - 1 do
    begin
      Bot := TBot(Ranked.Objects[I]);
      // its most asked-for pages
      Paths := TJSONArray.Create;
      Top := RankedNumbers(Bot.Paths);
      try
        for J := 0 to Min(Top.Count, 12) - 1 do
          Paths.Add(Top[J]);
      finally
        Top.Free;
      end;
      // an address that failed its check: not verified, even when others
      // were, or came from the company's published addresses
      if Bot.Unverified then
        Check := 'unverified'
      else if Crawlers.ContainsKey(Bot.Name) then
        Check := 'listed'
      else if Bot.Verified then
        Check := 'verified'
      else
        Check := '';
      List.Add(TJSONObject.Create(['name', Bot.Name, 'requests', Bot.Requests, 'addresses', Bot.Addresses.Count, 'last', Bot.Last,
        'check', Check, 'paths', Paths, 'sample', Bot.Samples[0]]));
    end;
    Answer.Add('bots', List);
  finally
    Ranked.Free;
  end;
end;

procedure ReportPages(Answer: TJSONObject; Pages: TPages);
var
  Ranked: TStringList;
  Key: string;
  APage: TPage;
  List: TJSONArray;
  I: integer;
begin
  Ranked := PlainList;
  try
    for Key in Pages.Keys do
      Ranked.AddObject(Key, Pages[Key]);
    Ranked.CustomSort(@ByViews);
    List := TJSONArray.Create;
    for I := 0 to Min(Ranked.Count, VISITOR_ROWS) - 1 do
    begin
      APage := TPage(Ranked.Objects[I]);
      List.Add(TJSONObject.Create(['path', Ranked[I], 'views', APage.Views, 'people', APage.People.Count]));
    end;
    Answer.Add('pages', List);
    Answer.Add('pages_count', Pages.Count);
  finally
    Ranked.Free;
  end;
end;

procedure ReportCrawlers(Answer: TJSONObject; Crawlers: TCrawlers);
var
  Ranked, Top: TStringList;
  Key: string;
  Crawler: TCrawler;
  List, Paths: TJSONArray;
  PartCounts: TJSONObject;
  I, J: integer;
begin
  Ranked := PlainList;
  try
    for Key in Crawlers.Keys do
      Ranked.AddObject(Key, Crawlers[Key]);
    Ranked.CustomSort(@ByCrawlerRequests);
    List := TJSONArray.Create;
    for I := 0 to Ranked.Count - 1 do
    begin
      Crawler := TCrawler(Ranked.Objects[I]);
      Paths := TJSONArray.Create;
      Top := RankedNumbers(Crawler.Paths);
      try
        for J := 0 to Min(Top.Count, 20) - 1 do
          Paths.Add(TJSONObject.Create(['path', Top[J], 'count', PtrInt(Top.Objects[J])]));
      finally
        Top.Free;
      end;
      // requests by part of the site, as part: count
      PartCounts := TJSONObject.Create;
      Top := RankedNumbers(Crawler.Parts);
      try
        Top.Sort;
        for J := 0 to Top.Count - 1 do
          PartCounts.Add(Top[J], PtrInt(Top.Objects[J]));
      finally
        Top.Free;
      end;
      List.Add(TJSONObject.Create(['name', Crawler.Name, 'company', Crawler.Company, 'requests', Crawler.Requests, 'pages', Crawler.Pages,
        'addresses', Crawler.Addresses.Count, 'last', Crawler.Last, 'parts', PartCounts, 'paths', Paths]));
    end;
    Answer.Add('crawlers', List);
  finally
    Ranked.Free;
  end;
end;

{ The report: each day of the period read twice, line by line and never
  whole (a day of crawlers is tens of megabytes): first for the admin's own
  addresses and who asked for robots.txt, then for everything else. }
function Report(const FromAt, ToAt, Me, MyAddress, OwnHost: string; Hide: boolean): TJSONObject;
const
  LATEST_PEOPLE = 1000;
  LATEST_BOTS = 400;
var
  Read, Sizes, Days, Ranked, Names, AllDays, Counts, Sorted: TStringList;
  Hidden, Robots, Browsers, DayPeople: TKeySet;
  People: TPeople;
  Bots: TBots;
  Pages: TPages;
  Referers, Searches, Members: TCounts;
  Crawlers: TCrawlers;
  Pretenders: TPretenders;
  Addresses: TAddresses;
  Memo, Agents: TMemo;
  DayCrawl, DayPages, DayPeopleCount, Files: TIntMap;
  PersonLatest, BotLatest: TLatest;
  Timeline: TTimeline;
  Clock: TDayMemo;
  Reader: TLogReader;
  Parts: TStringArray;
  F: TFields;
  Line, Day, LineDay, Ip, Agent, Path, PageKey, Member, Name, Key, Host, Words, Place, Before, Company, Claimed, AgentName, Part, ThisDay, FromDay, SeekAt, StopAt: string;
  Found, Checked, PageRead: boolean;
  Person: TPerson;
  Bot: TBot;
  APage: TPage;
  Count: TCount;
  Crawler: TCrawler;
  Pretender: TPretender;
  Address: TAddress;
  I, K, N, Lookups, Total, HiddenRequests, BotRequests, PersonPages, Code: integer;
  At: int64;
  List, DayList, CountList: TJSONArray;
  Series: TJSONObject;
  Signature: string;
begin
  // the crawler lists this report counts with, before it counts anything
  Signature := CrawlerListsSignature;
  FromDay := Copy(FromAt, 1, 10);
  Read := DaysBetween(FromDay, Copy(ToAt, 1, 10));
  // the first day's log is entered a little before the window and left a
  // little after it: a line can sit a second or two out of order, and each
  // line's time is checked anyway
  SeekAt := MomentBefore(FromAt, 120);
  StopAt := MomentBefore(ToAt, -120);
  Sizes := PlainList;
  Hidden := TKeySet.Create;
  Robots := TKeySet.Create;
  Browsers := TKeySet.Create;
  Files := TIntMap.Create;
  DayPeople := TKeySet.Create;
  People := TPeople.Create([doOwnsValues]);
  Bots := TBots.Create([doOwnsValues]);
  Pages := TPages.Create([doOwnsValues]);
  Referers := TCounts.Create([doOwnsValues]);
  Searches := TCounts.Create([doOwnsValues]);
  Members := TCounts.Create([doOwnsValues]);
  Crawlers := TCrawlers.Create([doOwnsValues]);
  Pretenders := TPretenders.Create([doOwnsValues]);
  Addresses := TAddresses.Create([doOwnsValues]);
  Memo := TMemo.Create;
  Agents := TMemo.Create;
  // each published crawler's requests by day (day#1name), for the day-by-day chart
  DayCrawl := TIntMap.Create;
  DayPages := TIntMap.Create;
  DayPeopleCount := TIntMap.Create;
  StartLatest(PersonLatest, LATEST_PEOPLE);
  StartLatest(BotLatest, LATEST_BOTS);
  StartTimeline(Timeline, FromAt, ToAt);
  Clock.Day := '';
  Result := TJSONObject.Create;
  try
    try
      Days := AccessLogDays;
      try
        List := TJSONArray.Create;
        for Line in Days do
          List.Add(Line);
        Result.Add('days', List);
      finally
        Days.Free;
      end;
      Result.Add('day', Copy(ToAt, 1, 10));
      Result.Add('from', FromAt);
      Result.Add('to', ToAt);
      Result.Add('hide', Hide);

      // first: who is the admin, who asked for robots.txt, and who is a browser
      // (its scripts called home, or it took the page's styles and scripts); each log's
      // size now, so the second reading of today's sees the same lines
      Found := False;
      if Hide then
        Hidden.Add(MyAddress);
      for Day in Read do
      begin
        Reader := OpenLog(Day, -1);
        if Reader = nil then
          Continue;
        try
          Found := True;
          Sizes.Values[Day] := IntToStr(Reader.Limit);
          if Day = FromDay then
            Reader.SeekTo(SeekAt);
          while Reader.Next(Line) do
          begin
            // before the window: on to the next; past it: done with the day
            if Copy(Line, 1, 20) < FromAt then
              Continue;
            if Copy(Line, 1, 20) > ToAt then
              if Copy(Line, 1, 20) > StopAt then
                Break
              else
                Continue;
            // most lines are neither: they are not taken apart
            // (the member is the last field of a line from before 9 Nov 2026)
            if not ((Pos(#9'/robots.txt'#9, Line) > 0) or (Pos(#9'/static/', Line) > 0) or (Pos(#9'/api/', Line) > 0) or (Pos(#9'/ws', Line) > 0) or
              (Hide and (Me <> '') and ((Pos(#9 + Me + #9, Line) > 0) or EndsStr(#9 + Me, Line)))) then
              Continue;
            N := SplitLine(Line, F);
            if N < 6 then
              Continue;
            if Hide and (N >= 7) and (Me <> '') and SameText(F[6], Me) then
              Hidden.Add(F[1]);
            // robots.txt marks that address with that browser, not the house behind it
            if F[3] = '/robots.txt' then
              Robots.Add(F[1] + #9 + F[5])
            else if IsPoll(F[3]) then
              Browsers.Add(F[1] + #9 + F[5])
            else if StartsStr('/static/', F[3]) then
            begin
              Bump(Files, F[1] + #9 + F[5]);
              if Files[F[1] + #9 + F[5]] >= BROWSER_FILES then
                Browsers.Add(F[1] + #9 + F[5]);
            end;
          end;
        finally
          Reader.Free;
        end;
      end;
      Result.Add('found', Found);

      Total := 0;
      HiddenRequests := 0;
      BotRequests := 0;
      PersonPages := 0;
      for Day in Read do
      begin
        I := Sizes.IndexOfName(Day);
        if I < 0 then
          Continue;
        Reader := OpenLog(Day, StrToInt64Def(Sizes.ValueFromIndex[I], 0));
        if Reader = nil then
          Continue;
        try
          if Day = FromDay then
            Reader.SeekTo(SeekAt);
          while Reader.Next(Line) do
          begin
            N := SplitLine(Line, F);
            if N < 6 then
              Continue;
            if F[0] < FromAt then
              Continue;
            if F[0] > ToAt then
              if F[0] > StopAt then
                Break
              else
                Continue;
            Inc(Total);
            Ip := F[1];
            Agent := F[5];
            Path := F[3];
            if (Path = '') or (Path[1] = '?') then
              Path := '/' + Path;
            Member := F[6];
            LineDay := Copy(F[0], 1, 10);
            // the answer's code, where the line has one (0 before 9 Nov 2026)
            Code := 0;
            if N >= 8 then
              Code := StrToIntDef(F[7], 0);
            At := Moment(F[0], Clock);
            Name := MemoCrawler(Memo, Ip, Company);
            // the chart counts every request, the admin's too: a finished
            // day's counts are kept, and must not depend on who asked
            if Name <> '' then
              Bump(DayCrawl, LineDay + #1 + Name);
            if Hide and (Hidden.Contains(Ip) or PrivateAddress(Ip)) then
            begin
              Inc(HiddenRequests);
              Continue;
            end;
            PageRead := IsPage(F[2], Path);
            // the address itself, whatever it says it is
            if not Addresses.TryGetValue(Ip, Address) then
            begin
              Address := TAddress.Create;
              Address.Ip := Ip;
              Address.Crawler := Name;
              Addresses.Add(Ip, Address);
            end;
            Address.Note(F[0], At, Agent, Member, Code, Path, PageRead, IsPoll(Path));
            if Code >= 400 then
              Tick(Timeline, 3, At);
            if Name <> '' then
            begin
              // from its company's own addresses: that crawler, whatever it says
              if not Crawlers.TryGetValue(Name, Crawler) then
              begin
                Crawler := TCrawler.Create;
                Crawler.Name := Name;
                Crawler.Company := Company;
                Crawlers.Add(Name, Crawler);
              end;
              Inc(Crawler.Requests);
              Crawler.Last := F[0];
              Crawler.Addresses.Add(Ip);
              Part := VisitorPart(Path);
              if Part = '' then
                Part := 'other';
              Bump(Crawler.Parts, Part);
              if PageRead then
              begin
                Inc(Crawler.Pages);
                Bump(Crawler.Paths, Path);
              end;
            end
            else
            begin
              MemoAgent(Agents, Agent, AgentName, Claimed);
              if Claimed <> '' then
              begin
                Key := AgentName;
                if Key = '' then
                  Key := Claimed;
                if not Pretenders.TryGetValue(Key, Pretender) then
                begin
                  Pretender := TPretender.Create;
                  Pretender.Name := Key;
                  Pretender.Company := Claimed;
                  Pretender.Sample := Ip;
                  Pretenders.Add(Key, Pretender);
                end;
                Inc(Pretender.Requests);
                Pretender.Last := F[0];
                Pretender.Addresses.Add(Ip);
                Address.Claimed := Claimed;
              end;
              Name := AgentName;
            end;
            if (Name = '') and (Member = '') and Robots.Contains(Ip + #9 + Agent) then
              Name := 'Asked for robots.txt';
            // a browser's name on something that took no styles and ran no
            // scripts: a fetcher (8 Nov 2026: 12,661 of them, a page each,
            // each from another address, counted as people)
            if (Name = '') and (Member = '') and not Browsers.Contains(Ip + #9 + Agent) then
              Name := UNNAMED_BOTS;
            if Name <> '' then
            begin
              Inc(BotRequests);
              Address.Bot := Name;
              if AnyPaceBot(Name) then
                Address.Mirror := True;
              if Code < 400 then
                Tick(Timeline, 2, At);
              if not Bots.TryGetValue(Name, Bot) then
              begin
                Bot := TBot.Create;
                Bot.Name := Name;
                Bots.Add(Name, Bot);
              end;
              KeepLatest(BotLatest, Line, Name);
              Inc(Bot.Requests);
              Bot.Last := F[0];
              if Bot.Addresses.Add(Ip) and (Bot.Samples.Count < 3) then
                Bot.Samples.Add(Ip);
              if PageRead then
                Bump(Bot.Paths, Path);
              Continue;
            end;
            Key := Ip + #9 + Agent;
            if not People.TryGetValue(Key, Person) then
            begin
              Person := TPerson.Create;
              Person.Address := Ip;
              Person.Agent := Agent;
              Person.First := F[0];
              People.Add(Key, Person);
            end;
            if IsPoll(Path) then
              Inc(Person.Polls)
            else
              Inc(Person.Requests);
            Person.Last := F[0];
            if Member <> '' then
              Person.Member := Member;
            if PageRead then
              KeepLatest(PersonLatest, Line, 'page')
            else if not IsPoll(Path) then
              KeepLatest(PersonLatest, Line, 'other');
            if Code < 400 then
              if PageRead then
                Tick(Timeline, 0, At)
              else if not IsPoll(Path) then
                Tick(Timeline, 1, At);
            // a search, from a page or a box that asks as one types; a box's words as
            // they grow are one search, the last: the shorter one before is taken back
            Place := SearchPlace(Path);
            Words := '';
            if Place <> '' then
              Words := LowerCase(SearchWords(Path));
            if Words <> '' then
            begin
              Before := Person.LastSearch;
              // typing is a couple of minutes at most: a search later on is a search of its own
              if (SecondsApart(Person.LastSearchAt, F[0]) > 120) or not Person.LastTyped then
                Before := '';
              Person.LastSearchAt := F[0];
              Person.LastTyped := StartsStr('/api/', Path);
              if Place + #9 + Words <> Before then
              begin
                if (Before <> '') and StartsStr(Place + #9, Before) and (StartsStr(Copy(Before, Length(Place) + 2, MaxInt), Words) or
                  StartsStr(Words, Copy(Before, Length(Place) + 2, MaxInt))) and Searches.TryGetValue(Before, Count) then
                begin
                  Dec(Count.N);
                  if Count.N <= 0 then
                    Searches.Remove(Before);
                end;
                Count := CountIn(Searches, Place + #9 + Words);
                Inc(Count.N);
                Count.Last := F[0];
                Person.LastSearch := Place + #9 + Words;
              end;
            end;
            if not PageRead then
              Continue;
            Inc(Person.Pages);
            Inc(PersonPages);
            if Person.Entry = '' then
              Person.Entry := Path;
            Host := HostOf(F[4]);
            if (Host <> '') and (Host <> OwnHost) then
            begin
              if Person.Referer = '' then
                Person.Referer := F[4];
              Count := CountIn(Referers, Host);
              Inc(Count.N);
              Count.Last := F[0];
            end;
            Bump(DayPages, LineDay);
            if DayPeople.Add(LineDay + #9 + Key) then
              Bump(DayPeopleCount, LineDay);
            PageKey := Path;
            if Pos('?', PageKey) > 0 then
              PageKey := Copy(PageKey, 1, Pos('?', PageKey) - 1);
            if not Pages.TryGetValue(PageKey, APage) then
            begin
              APage := TPage.Create;
              Pages.Add(PageKey, APage);
            end;
            Inc(APage.Views);
            APage.People.Add(Key);
            if Member <> '' then
            begin
              Count := CountIn(Members, Member);
              Inc(Count.N);
              Count.Last := F[0];
            end;
          end;
        finally
          Reader.Free;
        end;
      end;

      // the crawlers that can be checked: their first few addresses, at most
      // forty lookups in all (each is kept a day, so mostly no lookup at all)
      Lookups := 0;
      for Bot in Bots.Values do
      begin
        Checked := False;
        for Name in CHECKED_NAMES do
          if Bot.Name = Name then
            Checked := True;
        if not Checked then
          Continue;
        for Ip in Bot.Samples do
        begin
          if Lookups >= 40 then
            Break;
          Inc(Lookups);
          if KnownCrawler(Ip) then
            Bot.Verified := True
          else
          begin
            Bot.Unverified := True;
            if Addresses.TryGetValue(Ip, Address) then
              Address.Fake := True;
          end;
        end;
      end;

      Result.Add('requests', Total - HiddenRequests);
      Result.Add('hidden_requests', HiddenRequests);
      Sorted := PlainList;
      try
        for Line in Hidden do
          Sorted.Add(Line);
        Sorted.Sort;
        Result.Add('hidden_addresses', Sorted.Count);
        List := TJSONArray.Create;
        for Line in Sorted do
          List.Add(Line);
        Result.Add('hidden_list', List);
      finally
        Sorted.Free;
      end;
      Result.Add('people', People.Count);
      Result.Add('people_pages', PersonPages);
      Result.Add('bot_requests', BotRequests);
      Result.Add('members_seen', Members.Count);
      Result.Add('addresses', Addresses.Count);
      Result.Add('timeline', TimelineJSON(Timeline));
      // day by day: the pages people read and how many people read them
      List := TJSONArray.Create;
      for Day in Read do
      begin
        if not DayPages.TryGetValue(Day, N) then
          N := 0;
        if not DayPeopleCount.TryGetValue(Day, K) then
          K := 0;
        List.Add(TJSONObject.Create(['day', Day, 'pages', N, 'people', K]));
      end;
      Result.Add('by_day', List);

      ReportConcerns(Result, Addresses);

      ReportPeople(Result, People, Addresses);

      ReportBots(Result, Bots, Crawlers);

      ReportPages(Result, Pages);

      Ranked := PlainList;
      try
        for Key in Referers.Keys do
          Ranked.AddObject(Key, Referers[Key]);
        Ranked.CustomSort(@ByCount);
        List := TJSONArray.Create;
        for I := 0 to Min(Ranked.Count, 300) - 1 do
          List.Add(TJSONObject.Create(['host', Ranked[I], 'views', TCount(Ranked.Objects[I]).N, 'last', TCount(Ranked.Objects[I]).Last]));
        Result.Add('referers', List);
      finally
        Ranked.Free;
      end;

      Ranked := PlainList;
      try
        for Key in Searches.Keys do
          Ranked.AddObject(Key, Searches[Key]);
        Ranked.CustomSort(@ByCount);
        List := TJSONArray.Create;
        for I := 0 to Min(Ranked.Count, 500) - 1 do
        begin
          Parts := Ranked[I].Split([#9]);
          List.Add(TJSONObject.Create(['where', Parts[0], 'words', Parts[1], 'count', TCount(Ranked.Objects[I]).N, 'last', TCount(Ranked.Objects[I]).Last]));
        end;
        Result.Add('searches', List);
      finally
        Ranked.Free;
      end;

      ReportCrawlers(Result, Crawlers);

      Ranked := PlainList;
      try
        for Key in Pretenders.Keys do
          Ranked.AddObject(Key, Pretenders[Key]);
        Ranked.CustomSort(@ByPretenderRequests);
        List := TJSONArray.Create;
        for I := 0 to Ranked.Count - 1 do
        begin
          Pretender := TPretender(Ranked.Objects[I]);
          List.Add(TJSONObject.Create(['name', Pretender.Name, 'company', Pretender.Company, 'requests', Pretender.Requests, 'addresses',
            Pretender.Addresses.Count, 'last', Pretender.Last, 'sample', Pretender.Sample]));
        end;
        Result.Add('pretenders', List);
      finally
        Ranked.Free;
      end;

      // the crawlers day by day, as far back as the logs go (two weeks), oldest first
      AllDays := AccessLogDays;
      Names := PlainList;
      Names.Sorted := True;
      Names.Duplicates := dupIgnore;
      Series := TJSONObject.Create;
      DayList := TJSONArray.Create;
      ThisDay := FormatDateTime('yyyy-mm-dd', NowUTC);
      try
        for K := Min(AllDays.Count, 14) - 1 downto 0 do
        begin
          // the newest fourteen (AllDays is newest first), oldest of them first
          DayList.Add(AllDays[K]);
          // a whole day of the window was counted above, and a finished one is
          // kept; a day the window only enters is counted whole here
          if (Read.IndexOf(AllDays[K]) >= 0) and (AllDays[K] + 'T00:00:00Z' >= FromAt) and (AllDays[K] + 'T23:59:59Z' <= ToAt) then
          begin
            Counts := PlainList;
            for Key in DayCrawl.Keys do
              if StartsStr(AllDays[K] + #1, Key) then
                Counts.Values[Copy(Key, 12, MaxInt)] := IntToStr(DayCrawl[Key]);
            Counts.Sort;
            if AllDays[K] < ThisDay then
              KeepPastDay(AllDays[K], Counts.CommaText, Signature);
          end
          else
            Counts := CrawlerCounts(AllDays[K], Memo, AllDays[K] < ThisDay, Signature);
          try
            for I := 0 to Counts.Count - 1 do
            begin
              Names.Add(Counts.Names[I]);
              if Series.IndexOfName(Counts.Names[I]) < 0 then
                Series.Add(Counts.Names[I], TJSONObject.Create);
              Series.Objects[Counts.Names[I]].Add(AllDays[K], StrToIntDef(Counts.ValueFromIndex[I], 0));
            end;
          finally
            Counts.Free;
          end;
        end;
        List := TJSONArray.Create;
        for Name in Names do
        begin
          CountList := TJSONArray.Create;
          for K := 0 to DayList.Count - 1 do
            CountList.Add(Series.Objects[Name].Get(DayList.Strings[K], 0));
          List.Add(TJSONObject.Create(['name', Name, 'counts', CountList]));
        end;
        Result.Add('crawler_days', TJSONObject.Create(['days', DayList, 'series', List]));
        DayList := nil;
      finally
        DayList.Free;
        Series.Free;
        Names.Free;
        AllDays.Free;
      end;
      Result.Add('crawler_sources', CrawlerSourcesJSON);

      Ranked := PlainList;
      try
        for Key in Members.Keys do
          Ranked.AddObject(Key, Members[Key]);
        Ranked.CustomSort(@ByCount);
        List := TJSONArray.Create;
        for I := 0 to Ranked.Count - 1 do
          List.Add(TJSONObject.Create(['name', Ranked[I], 'pages', TCount(Ranked.Objects[I]).N, 'last', TCount(Ranked.Objects[I]).Last]));
        Result.Add('members', List);
      finally
        Ranked.Free;
      end;

      // the latest requests, people's and bots' apart, newest first
      List := TJSONArray.Create;
      AddLatest(List, PersonLatest, False);
      AddLatest(List, BotLatest, True);
      Result.Add('latest', List);
    except
      FreeAndNil(Result);
      raise;
    end;
  finally
    Read.Free;
    Sizes.Free;
    Hidden.Free;
    Robots.Free;
    Browsers.Free;
    Files.Free;
    DayPeople.Free;
    People.Free;
    Bots.Free;
    Pages.Free;
    Referers.Free;
    Searches.Free;
    Members.Free;
    Crawlers.Free;
    Pretenders.Free;
    Addresses.Free;
    Memo.Free;
    Agents.Free;
    DayCrawl.Free;
    DayPages.Free;
    DayPeopleCount.Free;
  end;
end;

function IsDay(const S: string): boolean;
var
  Day: TDateTime;
begin
  // a real day of the calendar: 2026-02-31 is not one
  Result := (Length(S) = 10) and (S[5] = '-') and (S[8] = '-') and TryEncodeDate(StrToIntDef(Copy(S, 1, 4), 0), StrToIntDef(Copy(S, 6, 2), 0),
    StrToIntDef(Copy(S, 9, 2), 0), Day);
end;

{ A moment as the log writes them, yyyy-mm-ddThh:nn:ssZ. }
function IsMoment(const S: string): boolean;
var
  I: integer;
begin
  Result := (Length(S) = 20) and IsDay(Copy(S, 1, 10)) and (S[11] = 'T') and (S[14] = ':') and (S[17] = ':') and (S[20] = 'Z');
  if not Result then
    Exit;
  for I in [12, 13, 15, 16, 18, 19] do
    if not (S[I] in ['0'..'9']) then
      Exit(False);
  Result := (StrToInt(Copy(S, 12, 2)) < 24) and (StrToInt(Copy(S, 15, 2)) < 60) and (StrToInt(Copy(S, 18, 2)) < 60);
end;

{ A window's ends as moments: a day given whole becomes its first or last second. }
procedure WindowEnds(var FromAt, ToAt: string);
begin
  if IsDay(FromAt) then
    FromAt := FromAt + 'T00:00:00Z';
  if IsDay(ToAt) then
    ToAt := ToAt + 'T23:59:59Z';
end;

function VisitorReport(const FromAt, ToAt, Me, MyAddress, OwnHost: string; Hide: boolean): TJSONObject;
var
  F, T: string;
begin
  F := FromAt;
  T := ToAt;
  WindowEnds(F, T);
  Result := Report(F, T, Me, MyAddress, OwnHost, Hide);
end;

function AddressReport(const Ip, FromAt, ToAt, OwnHost: string): TJSONObject;
const
  TRAIL_LINES = 500;
var
  Read, Ranked, Top: TStringList;
  Reader: TLogReader;
  Agents, Members, Referers: TCounts;
  Paths, Parts, Statuses: TIntMap;
  Timeline: TTimeline;
  Clock: TDayMemo;
  Address: TAddress;
  Trail: TLatest;
  F: TFields;
  Count: TCount;
  Day, Line, Mark, Path, PageKey, Host, Company, Key, FromDay, SeekAt, StopAt: string;
  N, Code, I: integer;
  At: int64;
  PageRead: boolean;
  List: TJSONArray;
  Obj: TJSONObject;
begin
  FromDay := Copy(FromAt, 1, 10);
  Read := DaysBetween(FromDay, Copy(ToAt, 1, 10));
  SeekAt := MomentBefore(FromAt, 120);
  StopAt := MomentBefore(ToAt, -120);
  Agents := TCounts.Create([doOwnsValues]);
  Members := TCounts.Create([doOwnsValues]);
  Referers := TCounts.Create([doOwnsValues]);
  Paths := TIntMap.Create;
  Parts := TIntMap.Create;
  Statuses := TIntMap.Create;
  Address := TAddress.Create;
  Address.Ip := Ip;
  Address.Crawler := PublishedCrawler(Ip, Company);
  StartTimeline(Timeline, FromAt, ToAt);
  StartLatest(Trail, TRAIL_LINES);
  Clock.Day := '';
  Mark := #9 + Ip + #9;
  Result := TJSONObject.Create(['ip', Ip, 'from', FromAt, 'to', ToAt]);
  try
    try
      for Day in Read do
      begin
        Reader := OpenLog(Day, -1);
        if Reader = nil then
          Continue;
        try
          if Day = FromDay then
            Reader.SeekTo(SeekAt);
          while Reader.Next(Line) do
          begin
            // the address somewhere in the line is cheap to ask; its own field is checked after
            if Pos(Mark, Line) = 0 then
              Continue;
            N := SplitLine(Line, F);
            if (N < 6) or (F[1] <> Ip) then
              Continue;
            if F[0] < FromAt then
              Continue;
            if F[0] > ToAt then
              if F[0] > StopAt then
                Break
              else
                Continue;
            Path := F[3];
            if (Path = '') or (Path[1] = '?') then
              Path := '/' + Path;
            Code := 0;
            if N >= 8 then
              Code := StrToIntDef(F[7], 0);
            At := Moment(F[0], Clock);
            PageRead := IsPage(F[2], Path);
            Address.Note(F[0], At, F[5], F[6], Code, Path, PageRead, IsPoll(Path));
            if Code >= 400 then
              Tick(Timeline, 3, At)
            else if PageRead then
              Tick(Timeline, 0, At)
            else
              Tick(Timeline, 1, At);
            Count := CountIn(Agents, F[5]);
            Inc(Count.N);
            Count.Last := F[0];
            if F[6] <> '' then
            begin
              Count := CountIn(Members, F[6]);
              Inc(Count.N);
              Count.Last := F[0];
            end;
            Bump(Statuses, IntToStr(Code));
            PageKey := Path;
            if Pos('?', PageKey) > 0 then
              PageKey := Copy(PageKey, 1, Pos('?', PageKey) - 1);
            Bump(Paths, PageKey);
            Bump(Parts, VisitorPart(Path));
            Host := HostOf(F[4]);
            if (Host <> '') and (Host <> OwnHost) then
            begin
              Count := CountIn(Referers, Host);
              Inc(Count.N);
              Count.Last := F[0];
            end;
            KeepLatest(Trail, Line, '');
          end;
        finally
          Reader.Free;
        end;
      end;
      // what it is, by the browser string it used most
      Ranked := PlainList;
      try
        for Key in Agents.Keys do
          Ranked.AddObject(Key, Agents[Key]);
        Ranked.CustomSort(@ByCount);
        if (Ranked.Count > 0) and (Address.Crawler = '') then
        begin
          Address.Bot := BotName(Ranked[0]);
          Address.Claimed := ClaimedCompany(Ranked[0]);
        end;
        for I := 0 to Ranked.Count - 1 do
          if AnyPaceBot(BotName(Ranked[I])) then
            Address.Mirror := True;
        List := TJSONArray.Create;
        for I := 0 to Min(Ranked.Count, 50) - 1 do
          List.Add(TJSONObject.Create(['agent', Ranked[I], 'requests', TCount(Ranked.Objects[I]).N, 'last', TCount(Ranked.Objects[I]).Last,
            'bot', BotName(Ranked[I]), 'claims', ClaimedCompany(Ranked[I])]));
        Result.Add('agents', List);
      finally
        Ranked.Free;
      end;
      Address.Judge;
      // one the admin vouched for is not a concern, whatever it did (its reasons still tell)
      if NeverBlocked(Ip) then
        Address.Score := 0;
      Obj := Address.JSON;
      Obj.Add('company', Company);
      Result.Add('address', Obj);
      Ranked := PlainList;
      try
        for Key in Members.Keys do
          Ranked.AddObject(Key, Members[Key]);
        Ranked.CustomSort(@ByCount);
        List := TJSONArray.Create;
        for I := 0 to Ranked.Count - 1 do
          List.Add(TJSONObject.Create(['name', Ranked[I], 'requests', TCount(Ranked.Objects[I]).N, 'last', TCount(Ranked.Objects[I]).Last]));
        Result.Add('members', List);
      finally
        Ranked.Free;
      end;
      Ranked := PlainList;
      try
        for Key in Referers.Keys do
          Ranked.AddObject(Key, Referers[Key]);
        Ranked.CustomSort(@ByCount);
        List := TJSONArray.Create;
        for I := 0 to Min(Ranked.Count, 20) - 1 do
          List.Add(TJSONObject.Create(['host', Ranked[I], 'requests', TCount(Ranked.Objects[I]).N]));
        Result.Add('referers', List);
      finally
        Ranked.Free;
      end;
      Top := RankedNumbers(Paths);
      try
        List := TJSONArray.Create;
        for I := 0 to Min(Top.Count, 40) - 1 do
          List.Add(TJSONObject.Create(['path', Top[I], 'count', PtrInt(Top.Objects[I])]));
        Result.Add('paths', List);
        Result.Add('paths_count', Top.Count);
      finally
        Top.Free;
      end;
      Top := RankedNumbers(Parts);
      try
        Obj := TJSONObject.Create;
        for I := 0 to Top.Count - 1 do
          Obj.Add(Top[I], PtrInt(Top.Objects[I]));
        Result.Add('parts', Obj);
      finally
        Top.Free;
      end;
      Top := RankedNumbers(Statuses);
      try
        Obj := TJSONObject.Create;
        for I := 0 to Top.Count - 1 do
          Obj.Add(Top[I], PtrInt(Top.Objects[I]));
        Result.Add('statuses', Obj);
      finally
        Top.Free;
      end;
      Result.Add('timeline', TimelineJSON(Timeline));
      List := TJSONArray.Create;
      AddLatest(List, Trail, False);
      Result.Add('trail', List);
      // the guard's facts need the database; without them the story still tells
      try
        Result.Add('guard', AddressFacts(Ip));
      except
        on E: Exception do
        begin
          Log('Address facts for ' + Ip + ': ' + E.Message);
          Result.Add('guard', TJSONNull.Create);
        end;
      end;
    except
      FreeAndNil(Result);
      raise;
    end;
  finally
    Read.Free;
    Agents.Free;
    Members.Free;
    Referers.Free;
    Paths.Free;
    Parts.Free;
    Statuses.Free;
    Address.Free;
  end;
end;

{ The window a request asks for: from= and to= as days (whole) or moments;
  day= for one day; today when none.  False, with the trouble sent, when
  they are not. }
function RequestWindow(ARequest: TRequest; AResponse: TResponse; out FromAt, ToAt: string): boolean;
begin
  FromAt := ARequest.QueryFields.Values['from'];
  ToAt := ARequest.QueryFields.Values['to'];
  if (FromAt = '') and (ToAt = '') then
  begin
    FromAt := ARequest.QueryFields.Values['day'];
    ToAt := FromAt;
  end;
  if ToAt = '' then
    ToAt := FormatDateTime('yyyy-mm-dd', NowUTC);
  if FromAt = '' then
    FromAt := Copy(ToAt, 1, 10);
  WindowEnds(FromAt, ToAt);
  Result := IsMoment(FromAt) and IsMoment(ToAt) and (FromAt <= ToAt);
  if not Result then
    SendText(AResponse, 400, 'from and to are days (yyyy-mm-dd) or moments (yyyy-mm-ddThh:nn:ssZ), from first.');
end;

{ GET /api/admin/visitors/report?from=&to=&hide=me  (or day=; today when neither) }
procedure ShowReport(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  FromAt, ToAt, Key, Body, OwnHost: string;
  Hide: boolean;
  Data: TJSONObject;
begin
  if not NeedPermission(ARequest, AResponse, 'view-visitors', Me) then
    Exit;
  if not RequestWindow(ARequest, AResponse, FromAt, ToAt) then
    Exit;
  Hide := ARequest.QueryFields.Values['hide'] = 'me';
  OwnHost := HostOf('https://' + ARequest.Host);
  Key := FromAt + #9 + ToAt + #9 + BoolToStr(Hide, True) + #9 + Me.Name + #9 + ClientIp(ARequest) + #9 + OwnHost;
  // one report built at a time: a second tab or a retry asking for the
  // same one waits for it and takes it, rather than reading the logs again
  EnterCriticalSection(BuildLock);
  try
    Body := '';
    EnterCriticalSection(ReportLock);
    try
      if (Key = KeptKey) and (Now - KeptAt < 1 / (24 * 60)) then
        Body := KeptReport;
    finally
      LeaveCriticalSection(ReportLock);
    end;
    if Body = '' then
    begin
      Data := Report(FromAt, ToAt, Me.Name, ClientIp(ARequest), OwnHost, Hide);
      try
        Body := Data.AsJSON;
      finally
        Data.Free;
      end;
      EnterCriticalSection(ReportLock);
      try
        KeptKey := Key;
        KeptAt := Now;
        KeptReport := Body;
      finally
        LeaveCriticalSection(ReportLock);
      end;
    end;
  finally
    LeaveCriticalSection(BuildLock);
  end;
  AResponse.ContentType := 'application/json; charset=utf-8';
  AResponse.SetCustomHeader('Cache-Control', 'no-store');
  AResponse.Content := Body;
  AResponse.SendContent;
end;

{ GET /api/admin/visitors/address?ip=&from=&to=  one address's story in the window }
procedure ShowAddress(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Ip, FromAt, ToAt: string;
  Data: TJSONObject;
begin
  if not NeedPermission(ARequest, AResponse, 'view-visitors', Me) then
    Exit;
  Ip := CanonicalIp(ARequest.QueryFields.Values['ip']);
  if Ip = '' then
  begin
    SendText(AResponse, 400, 'Enter an IP address.');
    Exit;
  end;
  if not RequestWindow(ARequest, AResponse, FromAt, ToAt) then
    Exit;
  // one pass over the logs at a time, as the report
  EnterCriticalSection(BuildLock);
  try
    Data := AddressReport(Ip, FromAt, ToAt, HostOf('https://' + ARequest.Host));
  finally
    LeaveCriticalSection(BuildLock);
  end;
  AResponse.SetCustomHeader('Cache-Control', 'no-store');
  SendJSON(AResponse, Data);
end;

initialization
  InitCriticalSection(ReportLock);
  InitCriticalSection(BuildLock);
  PastDays := PlainList;
  RegisterAdminRoute('/api/admin/visitors/report', 'view-visitors');
  RegisterAdminRoute('/api/admin/visitors/address', 'view-visitors');
  RegisterSearchPlace('/api/search', 'chat');
  RegisterAdminPart(@AdminFilePaths);
  HTTPRouter.RegisterRoute('/api/admin/visitors/report', rmGet, @ShowReport);
  HTTPRouter.RegisterRoute('/api/admin/visitors/address', rmGet, @ShowAddress);

finalization
  PastDays.Free;
  DoneCriticalSection(BuildLock);
  DoneCriticalSection(ReportLock);
end.
