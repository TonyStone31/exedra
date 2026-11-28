unit Admin_Visitors;

{ The Visitors tab: the period's report in sub-tabs, one person's requests, the counts by
  part of the site, and the guard's list of blocked addresses. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, Admin_List;

procedure AdminVisitors(Box: TJSHTMLElement);
procedure DrawVisitReport(Subs: TSubTabs; R: TJSObject; Pick, HideMe, HiddenSet: JSValue);

implementation

uses Admin_Address;

type
  // Date calls the JS unit lacks: new Date(value), and setHours with every part.
  TMoment = class external name 'Date'(TJSDate)
    constructor new; overload;
    constructor new(Value: JSValue); overload;
    procedure setHours(Hours, Minutes, Seconds, Milliseconds: NativeInt); overload;
    function dayOfMonth: NativeInt; external name 'getDate';
    procedure setDayOfMonth(Day: NativeInt); external name 'setDate';
    function milliseconds: double; external name 'getTime';
    function zoneOffset: double; external name 'getTimezoneOffset';
  end;
  TPeriod = reference to function: TJSObject;
  TLookUp = reference to procedure(Ip: JSValue);

// ---- what the lists below are made of

// a column of a list; Flags: n a number, w wide, d downward first, s not sorted
function Column(const Key: string; Title: JSValue; const Flags: string = ''; Value: TRowValue = nil; Cell: TRowValue = nil;
  const Cls: string = ''): TJSObject;
begin
  Result := new(['key', Key, 'title', Title]);
  if Pos('n', Flags) > 0 then Result['num'] := True;
  if Pos('w', Flags) > 0 then Result['wide'] := True;
  if Pos('d', Flags) > 0 then Result['down'] := True;
  if Pos('s', Flags) > 0 then Result['nosort'] := True;
  if Cls <> '' then Result['cls'] := Cls;
  if Assigned(Value) then Result['value'] := Value;
  if Assigned(Cell) then Result['cell'] := Cell;
end;

function Filter(const Key: string; Title, All, Options: JSValue; Test: TRowTest): TJSObject;
begin
  Result := new(['key', Key, 'title', Title, 'all', All, 'options', Options, 'test', Test]);
end;

function Noun(const One, Many: string): TCountText;
begin
  Result := function(N: JSValue): JSValue begin Result := TN(N, One, Many); end;
end;

function FieldOf(const Key: string): TRowValue;
begin
  Result := function(R: TJSObject): JSValue begin Result := R[Key]; end;
end;

function StampOf(const Key: string): TRowValue;
begin
  Result := function(R: TJSObject): JSValue begin Result := Stamp(R[Key]); end;
end;

function PageOf(const Key: string): TRowValue;
begin
  Result := function(R: TJSObject): JSValue begin Result := PageLink(R[Key]); end;
end;

function MemberLink(Name: JSValue): TJSHTMLElement;
begin
  Result := C.link('/u/' + C.enc(Name), '', Name);
end;

// a link to the member when the row names one
function MemberOf(R: TJSObject): JSValue;
begin
  if Truthy(R['member']) then Result := MemberLink(R['member']) else Result := '';
end;

function BrowserOfRow(R: TJSObject): JSValue;
begin
  Result := BrowserOf(R['agent']);
end;

function Pair(A, B: JSValue): TJSArray;
begin
  Result := Items(A, B);
end;

// the values without their repeats, in the order first met
function Distinct(Values: TJSArray): TJSArray;
begin
  Result := TJSArray.from(TJSSet.new(Values));
end;

function Column2(Rows: TJSArray; const Key: string): TJSArray;
var
  I: NativeInt;
begin
  Result := TJSArray.new;
  for I := 0 to Rows.length - 1 do Result.push(TJSObject(Rows[I])[Key]);
end;

// each value as a choice named like itself
function AsChoices(Values: TJSArray): TJSArray;
var
  I: NativeInt;
begin
  Result := TJSArray.new;
  for I := 0 to Values.length - 1 do Result.push(Pair(Values[I], Values[I]));
end;

// what was counted, the most first, as choices with their counts; Kinds names them where it can
function Counted(Seen: TJSMap; Kinds: TJSObject): TJSArray;
var
  Pairs: TJSArray;
  Name: JSValue;
  I: NativeInt;
begin
  Pairs := SortBy(TJSArray.from(Seen), function(A, B: TJSArray): double begin Result := Num(B[1]) - Num(A[1]); end);
  Result := TJSArray.new;
  for I := 0 to Pairs.length - 1 do
  begin
    Name := TJSArray(Pairs[I])[0];
    if Kinds <> nil then Result.push(Pair(Name, string(Either(Kinds[string(Name)], Name)) + ' (' + string(TJSArray(Pairs[I])[1]) + ')'))
    else Result.push(Pair(Name, string(Name) + ' (' + string(TJSArray(Pairs[I])[1]) + ')'));
  end;
end;

procedure Count(Seen: TJSMap; Key: JSValue);
begin
  Seen.&set(Key, Num(Either(Seen.get(Key), 0)) + 1);
end;

function RequestWords(N: JSValue): JSValue;
begin
  Result := TN(N, '%d request', '%d requests');
end;

function Pixels(Share: double; Least: double): string;
begin
  Result := Str(MathMax(Least, MathRound(Share))) + 'px';
end;

// Addresses shut out for probing or wrong passwords (src/core/siteguard.pas), a
// sub-tab of Visitors: the list, a filter over it, and each row's whole
// story in the address panel.  period() is the window the Visitors tab shows.
procedure AdminBlocks(Box: TJSHTMLElement; Period: JSValue);
var
  Tiles: TJSHTMLElement;
  StateWords: TJSObject;
  List: TListView;

  function StateOf(B: TJSObject): string;
  begin
    if Truthy(B['for_good']) then Result := 'forgood' else if Truthy(B['active']) then Result := 'blocked' else Result := 'over';
  end;

  function Show: JSValue; async;
  var
    Rows: TJSArray;
    Active: NativeInt;
  begin
    Rows := await(TJSArray, C.get('/api/blocks'));
    Tiles.replaceChildren;
    Active := Rows.filter(function(B: JSValue; Index: NativeInt; All: TJSArray): boolean begin Result := Truthy(TJSObject(B)['active']); end).length;
    Stat(Tiles, Active, T('Blocked right now'), undefined, undefined);
    Stat(Tiles, Rows.filter(function(B: JSValue; Index: NativeInt; All: TJSArray): boolean begin Result := Truthy(TJSObject(B)['for_good']); end).length,
      T('For good'), undefined, undefined);
    Stat(Tiles, Rows.length - Active, T('Over, still listed'), undefined, undefined);
    List.set_(Rows);
  end;

  procedure BlocksChanged;
  begin
    TJSPromise(Show()).catch(function(Why: JSValue): JSValue begin end);
  end;

begin
  Tiles := C.el('div', 'tiles-admin');
  TKit(Box).fill(
    C.el('p', 'hint', T('An address that asks for six missing pages in a minute, or gets ten passwords wrong in a quarter hour, is shut out for an hour; after three times, for thirty days. Published crawlers, checked against the addresses their companies publish, are never limited or blocked; a browser string that claims to be one of them from another address is refused. This network and the addresses in Settings, allowed_ips, are never blocked either. Allow adds an address there. With an AbuseIPDB key in Settings, an address that probes or guesses passwords here is looked up on AbuseIPDB and reported back, and blocked for good when its confidence of abuse is at the set level or above. Type an address to see its story, or to block it by hand.')),
    Tiles);
  StateWords := new(['forgood', T('For good'), 'blocked', T('Blocked now'), 'over', T('Over')]);
  List := ListView(Box, TListOptions(new([
    'id', 'blocks', 'key', FieldOf('ip'), 'sort', '-when', 'csv', 'blocked',
    'search', T('Filter, or type an address and press Enter to look it up'),
    'enter', TLookUp(procedure(Ip: JSValue) begin if Truthy(Ip) then LookUpAddress(Ip); end),
    'columns', Items(
      Column('ip', T('Address'), '', nil, function(B: TJSObject): JSValue begin Result := C.el('b', 'lv-ip', B['ip']); end),
      Column('state', T('State'), '', function(B: TJSObject): JSValue begin Result := StateWords[StateOf(B)]; end,
        function(B: TJSObject): JSValue
        begin
          if StateOf(B) = 'over' then Result := C.chip(StateWords[StateOf(B)], '') else Result := C.chip(StateWords[StateOf(B)], 'bad');
        end),
      Column('reason', T('Why')),
      Column('times', T('Times'), 'n'),
      Column('when', T('Last change'), 'dw', nil, function(B: TJSObject): JSValue begin Result := DateTimeText(B['when']); end),
      Column('until', T('Until'), 'w', nil, function(B: TJSObject): JSValue
        begin
          if Truthy(B['for_good']) then Result := T('for good') else Result := DateTimeText(B['until']);
        end)),
    'filters', Items(
      Filter('state', T('State'), T('Every state'), Items(Pair('blocked', T('Blocked now')), Pair('forgood', T('For good')), Pair('over', T('Over'))),
        function(B: TJSObject; V: string): JSValue
        begin
          if V = 'forgood' then Result := B['for_good'] else if V = 'blocked' then Result := B['active'] else Result := not Truthy(B['active']);
        end),
      Filter('reason', T('Why'), T('Every reason'), TRowsValue(function(Rows: TJSArray): JSValue
        var
          Seen: TJSMap;
          I: NativeInt;
        begin
          Seen := TJSMap.new;
          for I := 0 to Rows.length - 1 do Count(Seen, TJSObject(Rows[I])['reason']);
          Result := Counted(Seen, nil);
        end),
        function(B: TJSObject; V: string): JSValue begin Result := Same(B['reason'], V); end)),
    'rowClass', TRowValue(function(B: TJSObject): JSValue begin if Truthy(B['active']) then Result := '' else Result := 'done'; end),
    'noun', Noun('%d address', '%d addresses'), 'empty', T('Nobody is blocked.'),
    'detail', TRowDetail(procedure(B: TJSObject; Holder: TJSHTMLElement; View: TListView) begin AddressPanel(B['ip'], Holder, Period); end)])));
  S['blocksChanged'] := @BlocksChanged;
  TJSPromise(Show()).catch(function(Why: JSValue): JSValue begin List.failed(TJSObject(Why)['message']); end);
end;

// one person's period: who, from where, and every request they made with that browser
procedure PersonDetail(V: TJSObject; Holder: TJSHTMLElement; Period: TJSObject);
var
  Head, Acts, Trail: TJSHTMLElement;
  From: JSValue;

  procedure Read; async;
  var
    A: TJSObject;
  begin
    try
      A := await(TJSObject, C.get('/api/admin/access?n=1000&ip=' + C.enc(V['ip']) + '&agent=' + C.enc(V['agent']) +
        '&from=' + C.enc(Period['from']) + '&to=' + C.enc(Period['to'])));
      Trail.replaceChildren;
      ListView(Trail, TListOptions(new([
        'id', 'v-trail', 'key', TRowValue(function(L: TJSObject): JSValue begin Result := string(L['at']) + string(L['path']); end),
        'sort', '-at', 'search', T('Filter their requests'), 'page', 200,
        'rows', A['lines'],
        'columns', Items(
          Column('at', T('When'), 'd', nil, StampOf('at')),
          Column('method', T('Method'), 'w'),
          Column('path', T('Page'), '', nil, PageOf('path')),
          Column('status', T('Status'), 'n', nil, function(L: TJSObject): JSValue begin Result := StatusCell(L['status']); end),
          Column('ms', T('Took'), 'nw', nil, function(L: TJSObject): JSValue begin Result := MsCell(L['ms']); end),
          Column('from', T('From'), 'w', function(L: TJSObject): JSValue begin Result := HostOf(L['referer']); end)),
        'filters', Items(new(['key', 'kind', 'title', T('Which'), 'all', T('Every request'), 'value', 'people',
          'options', Items(Pair('people', T('Pages they read')), Pair('other', T('Everything else'))),
          'test', TRowTest(function(L: TJSObject; K: string): JSValue
            begin
              if Same(L['method'], 'GET') and IsPagePath(L['path']) then Result := K = 'people' else Result := K = 'other';
            end)])),
        'noun', Noun('%d request', '%d requests')])));
    except
      TKit(Trail).fill(C.el('p', 'dim', T('The access log could not be read.')));
    end;
  end;

begin
  Head := C.el('div', 'lv-detail-head');
  Head.appendChild(C.el('b', '', V['ip']));
  if Truthy(V['member']) then Head.appendChild(MemberLink(V['member']));
  Head.appendChild(C.el('span', 'dim', BrowserOf(V['agent'])));
  if Truthy(V['flagged']) then Head.appendChild(C.chip(T('Of concern'), 'open'));
  Holder.appendChild(Head);
  if Truthy(V['referer']) then From := OutLink(V['referer']) else From := T('typed in, a bookmark, or not said');
  C.facts(Holder, Items(Pair(T('First seen'), Stamp(V['first'])), Pair(T('Last seen'), Stamp(V['last'])), Pair(T('Pages'), V['pages']),
    Pair(T('Requests'), V['requests']), Pair(T('Open tab checks'), Either(V['polls'], 0)),
    Pair(T('Came in on'), PageLink(V['entry'])), Pair(T('From'), From), Pair(T('Browser'), V['agent'])));
  Acts := C.el('div', 'lv-actions');
  Acts.appendChild(LookButton(V['ip']));
  Holder.appendChild(Acts);
  Holder.appendChild(C.el('h3', '', T('What they asked for in the period')));
  Trail := C.el('div');
  Holder.appendChild(Trail);
  C.waiting(Trail, T('Reading the log…'));
  Read;
end;

procedure DrawVisitOverview(Subs: TSubTabs; R: TJSObject; HideMe: JSValue);
var
  Box, Tiles, Worry, Days, Bar, Caption, Two, Left, Right: TJSHTMLElement;
  ByDay, Rows, Pages, Referers, Searches, Values: TJSArray;
  D, P: TJSObject;
  Top: double;
  Name: JSValue;
  I: NativeInt;
begin
  // the overview: the numbers, the hours, where people came from and what they read most
  Box := Subs.holder('overview');
  Tiles := C.el('div', 'tiles-admin');
  Stat(Tiles, R['people'], T('People'), T('a browser that took the page whole, not a bot'), undefined);
  Stat(Tiles, R['people_pages'], T('Pages they read'), undefined, undefined);
  Stat(Tiles, R['bot_requests'], T('Bot requests'), TN(TJSArray(R['bots']).length, '%d bot or crawler', '%d bots and crawlers'), undefined);
  Stat(Tiles, R['members_seen'], T('Members signed in'), undefined, undefined);
  if Truthy(R['concerns_count']) then
    Worry := Stat(Tiles, Either(R['concerns_count'], 0), T('Addresses of concern'), TN(Either(R['addresses'], 0), 'of %d address', 'of %d addresses'), 'warn')
  else
    Worry := Stat(Tiles, Either(R['concerns_count'], 0), T('Addresses of concern'), TN(Either(R['addresses'], 0), 'of %d address', 'of %d addresses'), '');
  TJSObject(Worry.style)['cursor'] := 'pointer';
  Worry.title := T('See the Of concern tab');
  Worry.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Subs.select('concerns'); end));
  if Truthy(HideMe) then
    Stat(Tiles, R['hidden_requests'], T('Your requests left out'), TN(R['hidden_addresses'], 'from %d address', 'from %d addresses'), undefined);
  Box.appendChild(Tiles);
  ByDay := TJSArray(Either(R['by_day'], TJSArray.new));
  if ByDay.length > 1 then
  begin
    Top := MostOf(Column2(ByDay, 'pages'));
    Days := C.el('div', 'days');
    for I := 0 to ByDay.length - 1 do
    begin
      D := TJSObject(ByDay[I]);
      Bar := C.el('i');
      TJSObject(Bar.style)['height'] := Pixels(66 * Num(D['pages']) / Top, 2);
      Bar.title := DateText(D['day']) + ': ' + TN(D['pages'], '%d page', '%d pages') + ', ' + TN(D['people'], '%d person', '%d people');
      Days.appendChild(Bar);
    end;
    Box.appendChild(Days);
    Caption := C.el('div', 'days-caption');
    TKit(Caption).add(C.el('span', '', DateText(TJSObject(ByDay[0])['day'])), C.el('span', '', T('pages people read, day by day')),
      C.el('span', '', DateText(TJSObject(ByDay[ByDay.length - 1])['day'])));
    Box.appendChild(Caption);
  end;
  TimelineChart(Box, TJSObject(R['timeline']));
  Two := C.el('div', 'visit-two');
  Left := C.el('div');
  Right := C.el('div');
  TKit(Two).add(Left, Right);
  Box.appendChild(Two);
  Left.appendChild(C.el('h3', '', T('What people read most')));
  Pages := TJSArray(R['pages']);
  if Pages.length > 0 then
  begin
    Rows := Pages.slice(0, 12);
    Values := TJSArray.new;
    for I := 0 to Rows.length - 1 do
    begin
      P := TJSObject(Rows[I]);
      Name := P['path'];
      try
        Name := decodeURIComponent(string(Name));
      except
      end;
      Values.push(new(['name', Name, 'value', P['views']]));
    end;
    Bars(Left, Values, function(N: JSValue): JSValue begin Result := TN(N, '%d view', '%d views'); end);
  end
  else Left.appendChild(C.el('p', 'dim', T('Nothing yet.')));
  Right.appendChild(C.el('h3', '', T('Where they came from')));
  Referers := TJSArray(R['referers']);
  if Referers.length > 0 then
  begin
    Rows := Referers.slice(0, 12);
    Values := TJSArray.new;
    for I := 0 to Rows.length - 1 do Values.push(new(['name', TJSObject(Rows[I])['host'], 'value', TJSObject(Rows[I])['views']]));
    Bars(Right, Values, function(N: JSValue): JSValue begin Result := TN(N, '%d page', '%d pages'); end);
  end
  else Right.appendChild(C.el('p', 'dim', T('Nobody came by a link in that period.')));
  Searches := TJSArray(R['searches']);
  if Searches.length > 0 then
  begin
    Box.appendChild(C.el('h3', '', T('What they searched for')));
    Rows := Searches.slice(0, 10);
    Values := TJSArray.new;
    for I := 0 to Rows.length - 1 do
      Values.push(new(['name', string(TJSObject(Rows[I])['words']) + '  ·  ' + string(PlaceName(TJSObject(Rows[I])['where'])), 'value', TJSObject(Rows[I])['count']]));
    Bars(Box, Values, function(N: JSValue): JSValue begin Result := TN(N, '%d time', '%d times'); end);
  end;
end;

procedure DrawPeople(Box: TJSHTMLElement; R: TJSObject);
var
  Visitors: TJSArray;
begin
  Box.appendChild(C.el('p', 'hint', T('Each address with one browser. Bots are counted apart, under Bots. Pick a row for everything they asked for.')));
  Visitors := TJSArray(R['visitors']);
  if Num(R['visitors_count']) > Visitors.length then
    Box.appendChild(C.el('p', 'hint', T('The %s who read the most are listed, of %s.', LocaleNumber(Visitors.length), LocaleNumber(R['visitors_count']))));
  ListView(Box, TListOptions(new([
    'id', 'v-people', 'key', TRowValue(function(V: TJSObject): JSValue begin Result := string(V['ip']) + ' ' + string(V['agent']); end),
    'sort', '-pages', 'csv', 'people-' + WindowName(R),
    'search', T('Filter by address, page, site or member'), 'rows', Visitors,
    'columns', Items(
      Column('last', T('Last seen'), 'd', nil, function(V: TJSObject): JSValue
        var
          Seen: TJSHTMLElement;
        begin
          Seen := C.el('span', '', Stamp(V['last']));
          Seen.title := T('First seen %s', Stamp(V['first']));
          Result := Seen;
        end),
      Column('ip', T('Address'), '', nil, function(V: TJSObject): JSValue begin Result := AddressCell(V['ip'], V['flagged']); end),
      Column('member', T('Member'), '', nil, @MemberOf),
      Column('pages', T('Pages'), 'n'),
      Column('requests', T('Requests'), 'nw'),
      Column('entry', T('Came in on'), '', nil, PageOf('entry')),
      Column('from', T('From'), 'w', function(V: TJSObject): JSValue begin Result := HostOf(V['referer']); end),
      Column('browser', T('Browser'), 'w', @BrowserOfRow)),
    'filters', Items(
      Filter('who', T('Who'), T('Everybody'), Items(Pair('members', T('Members signed in')), Pair('guests', T('Not signed in')), Pair('concern', T('Of concern'))),
        function(V: TJSObject; K: string): JSValue
        begin
          if K = 'members' then Result := Truthy(V['member']) else if K = 'guests' then Result := not Truthy(V['member']) else Result := Num(V['flagged']) > 0;
        end),
      Filter('browser', T('Browser'), T('Every browser'), TRowsValue(function(Rows: TJSArray): JSValue
        var
          Names: TJSArray;
          I: NativeInt;
        begin
          Names := TJSArray.new;
          for I := 0 to Rows.length - 1 do Names.push(BrowserOf(TJSObject(Rows[I])['agent']));
          Result := AsChoices(SortBy(Distinct(Names), undefined));
        end),
        function(V: TJSObject; K: string): JSValue begin Result := Same(BrowserOf(V['agent']), K); end),
      Filter('from', T('From'), T('From anywhere'), TRowsValue(function(Rows: TJSArray): JSValue
        var
          Hosts: TJSArray;
          Host: string;
          I: NativeInt;
        begin
          Hosts := TJSArray.new;
          for I := 0 to Rows.length - 1 do
          begin
            Host := HostOf(TJSObject(Rows[I])['referer']);
            if Host <> '' then Hosts.push(Host);
          end;
          Result := Items(Pair('-', T('No link (typed in or a bookmark)'))).concat(AsChoices(SortBy(Distinct(Hosts), undefined)));
        end),
        function(V: TJSObject; K: string): JSValue
        begin
          if K = '-' then Result := HostOf(V['referer']) = '' else Result := HostOf(V['referer']) = K;
        end)),
    'noun', Noun('%d person', '%d people'), 'empty', T('Nobody read a page in that period.'),
    'detail', TRowDetail(procedure(V: TJSObject; Holder: TJSHTMLElement; View: TListView)
      begin
        PersonDetail(V, Holder, new(['from', R['from'], 'to', R['to']]));
      end)])));
end;

procedure DrawCrawlers(Box: TJSHTMLElement; R: TJSObject);
var
  Crawlers, Sources, Pretenders, Named, Parts, Pairs, Keys, Columns, Shown, Order, DayList, Series, Counts: TJSArray;
  Totals: TJSMap;
  Crawler, Days, One: TJSObject;
  Legend, Chart, Wrap, Table, Head, Th, Row, Lists, Holder: TJSHTMLElement;
  Most, Peak: double;
  I, J: NativeInt;

  function PartsOf(Crawler: TJSObject): TJSObject;
  begin
    Result := TJSObject(Either(Crawler['parts'], TJSObject.new));
  end;

  function PartOf(Crawler: TJSObject; K: JSValue): JSValue;
  var
    Names: TJSStringDynArray;
    N: double;
    X: NativeInt;
  begin
    if not Same(K, 'other') then Exit(Either(PartsOf(Crawler)[string(K)], 0));
    N := 0;
    Names := TJSObject.keys(PartsOf(Crawler));
    for X := 0 to Length(Names) - 1 do
      if Named.indexOf(Names[X]) < 0 then N := N + Num(PartsOf(Crawler)[Names[X]]);
    Result := N;
  end;

  function PartColumn(P: TJSArray): TJSObject;
  begin
    Result := Column('part-' + string(P[0]), P[1], 'nw', function(Crawler: TJSObject): JSValue begin Result := PartOf(Crawler, P[0]); end);
  end;

  function Sum(Counts: TJSArray): double;
  var
    N: NativeInt;
  begin
    Result := 0;
    for N := 0 to Counts.length - 1 do Result := Result + Num(Counts[N]);
  end;

  // what each read, part by part: one bar a crawler, the parts side by side in it
  procedure ChartRow(Crawler: TJSObject);
  var
    Name, Bar, Seg, Track, Number: TJSHTMLElement;
    Words: TJSArray;
    P: TJSArray;
    N: NativeInt;
  begin
    Name := C.el('span', 'name', Crawler['name']);
    TJSObject(Name)['title'] := Crawler['company'];
    Bar := C.el('span', 'crawl-bar');
    TJSObject(Bar.style)['width'] := Str(MathMax(2, MathRound(100 * Num(Crawler['requests']) / Most))) + '%';
    Words := TJSArray.new;
    for N := 0 to Parts.length - 1 do
    begin
      P := TJSArray(Parts[N]);
      Words.push(string(P[1]) + ' ' + string(PartOf(Crawler, P[0])));
      if not Truthy(PartOf(Crawler, P[0])) then Continue;
      Seg := C.el('i', 'crawl-c' + Str(N + 1));
      TJSObject(Seg.style)['flexGrow'] := PartOf(Crawler, P[0]);
      Seg.title := string(P[1]) + ': ' + TN(PartOf(Crawler, P[0]), '%d request', '%d requests');
      Bar.appendChild(Seg);
    end;
    Track := C.el('span', 'crawl-track');
    Track.appendChild(Bar);
    Number := C.el('span', 'num', LocaleNumber(Crawler['requests']));
    Number.title := Words.join(' · ');
    TKit(Chart).add(Name, Track, Number);
  end;

  // two weeks of them, a row a crawler, a cell a day, darker for more
  procedure HeatRow(One: TJSObject);
  var
    Row, Cell: TJSHTMLElement;
    Counts: TJSArray;
    N: JSValue;
    Share: double;
    X: NativeInt;
  begin
    Row := C.el('tr');
    Row.appendChild(C.el('td', 'name', One['name']));
    Counts := TJSArray(One['counts']);
    for X := 0 to Counts.length - 1 do
    begin
      N := Counts[X];
      if Truthy(N) then Cell := C.el('td', 'heat', LocaleNumber(N)) else Cell := C.el('td', 'heat', '');
      // a log scale: a crawler that came ten times still shows
      if Truthy(N) then Share := MathRound(12 + 88 * MathLog(1 + Num(N)) / MathLog(1 + Peak)) else Share := 0;
      Cell.style.setProperty('--share', Str(Share) + '%');
      if Share > 55 then Cell.classList.add('deep');
      Cell.title := string(One['name']) + ', ' + DateText(DayList[X]) + ': ' + TN(N, '%d request', '%d requests');
      Row.appendChild(Cell);
    end;
    Table.appendChild(Row);
  end;

begin
  Sources := TJSArray(R['crawler_sources']);
  Box.appendChild(C.el('p', 'hint', TN(Sources.length,
    'Found by the address ranges their companies publish (%d list, read once a day): a request from those addresses is that company''s crawler, whatever its browser string says.',
    'Found by the address ranges their companies publish (%d lists, read once a day): a request from those addresses is that company''s crawler, whatever its browser string says.')));
  // the parts of the site the crawlers read, as the units register them: the three
  // they read most by name, the rest together, four colors in all
  Crawlers := TJSArray(R['crawlers']);
  Totals := TJSMap.new;
  for I := 0 to Crawlers.length - 1 do
  begin
    Crawler := TJSObject(Crawlers[I]);
    Keys := TJSArray(TJSObject.keys(PartsOf(Crawler)));
    for J := 0 to Keys.length - 1 do
      Totals.&set(Keys[J], Num(Either(Totals.get(Keys[J]), 0)) + Num(PartsOf(Crawler)[string(Keys[J])]));
  end;
  Pairs := SortBy(TJSArray.from(Totals).filter(function(X: JSValue; Index: NativeInt; All: TJSArray): boolean begin Result := not Same(TJSArray(X)[0], 'other'); end),
    function(A, B: TJSArray): double begin Result := Num(B[1]) - Num(A[1]); end).slice(0, 3);
  Named := TJSArray.new;
  Parts := TJSArray.new;
  for I := 0 to Pairs.length - 1 do
  begin
    Named.push(TJSArray(Pairs[I])[0]);
    Parts.push(Pair(TJSArray(Pairs[I])[0], PartLabel(TJSArray(Pairs[I])[0])));
  end;
  Parts.push(Pair('other', T('Other')));
  if Crawlers.length = 0 then Box.appendChild(C.el('p', 'dim', T('No known crawler came in that period.')))
  else
  begin
    Legend := C.el('div', 'crawl-legend');
    for I := 0 to Parts.length - 1 do
    begin
      Th := C.el('span');
      TKit(Th).add(C.el('i', 'crawl-c' + Str(I + 1)), ' ' + string(TJSArray(Parts[I])[1]));
      Legend.appendChild(Th);
    end;
    Box.appendChild(Legend);
    Most := MostOf(Column2(Crawlers, 'requests'));
    Chart := C.el('div', 'crawl-chart');
    Shown := Crawlers.slice(0, 20);
    for I := 0 to Shown.length - 1 do ChartRow(TJSObject(Shown[I]));
    Box.appendChild(Chart);
    Columns := Items(Column('name', T('Crawler')), Column('company', T('Company')), Column('requests', T('Requests'), 'n'));
    for I := 0 to Parts.length - 1 do Columns.push(PartColumn(TJSArray(Parts[I])));
    Columns.push(Column('addresses', T('Addresses'), 'n'), Column('last', T('Last seen'), 'd', nil, StampOf('last')));
    ListView(Box, TListOptions(new([
      'id', 'v-crawlers', 'key', FieldOf('name'), 'sort', '-requests', 'csv', 'crawlers-' + WindowName(R), 'search', T('Filter crawlers'), 'rows', Crawlers,
      'columns', Columns,
      'filters', Items(Filter('company', T('Company'), T('Every company'),
        TRowsValue(function(Rows: TJSArray): JSValue begin Result := AsChoices(SortBy(Distinct(Column2(Rows, 'company')), undefined)); end),
        function(Crawler: TJSObject; K: string): JSValue begin Result := Same(Crawler['company'], K); end)),
      'noun', Noun('%d crawler', '%d crawlers'),
      'detail', TRowDetail(procedure(Crawler: TJSObject; Holder: TJSHTMLElement; View: TListView)
        var
          Top: TJSHTMLElement;
          Names: TJSStringDynArray;
          ByPart, Paths, Read: TJSArray;
          N: NativeInt;
        begin
          Top := C.el('div', 'lv-detail-head');
          TKit(Top).add(C.el('b', '', Crawler['name']), C.el('span', 'dim', Crawler['company']));
          Holder.appendChild(Top);
          Names := TJSObject.keys(PartsOf(Crawler));
          ByPart := TJSArray.new;
          for N := 0 to Length(Names) - 1 do ByPart.push(string(PartLabel(Names[N])) + ' ' + string(PartsOf(Crawler)[Names[N]]));
          C.facts(Holder, Items(Pair(T('Requests'), LocaleNumber(Crawler['requests'])), Pair(T('Addresses'), Crawler['addresses']),
            Pair(T('Last seen'), Stamp(Crawler['last'])), Pair(T('By part'), ByPart.join(' · '))));
          Holder.appendChild(C.el('h3', '', T('What it read most')));
          Paths := TJSArray(Crawler['paths']);
          Read := TJSArray.new;
          for N := 0 to Paths.length - 1 do
            Read.push(new(['name', Either(TJSObject(Paths[N])['path'], '/'), 'value', TJSObject(Paths[N])['count']]));
          Bars(Holder, Read, @RequestWords);
        end)])));
  end;
  Days := TJSObject(R['crawler_days']);
  if Truthy(Days) and (TJSArray(Days['series']).length > 0) then
  begin
    Box.appendChild(C.el('h3', '', T('Day by day')));
    Series := TJSArray(Days['series']);
    Counts := TJSArray.new;
    for I := 0 to Series.length - 1 do Counts.push(MathMaxOf(nil, TJSArray(TJSObject(Series[I])['counts'])));
    Peak := MostOf(Counts);
    Wrap := C.el('div', 'gridwrap');
    Table := C.el('table', 'grid crawl-days');
    Head := C.el('tr');
    Head.appendChild(C.el('th', '', T('Crawler')));
    DayList := TJSArray(Days['days']);
    for I := 0 to DayList.length - 1 do
    begin
      Th := C.el('th', '', TJSString(DateText(DayList[I])).replace(TJSRegExp.new('[-/.]?\d{4}[-/.]?'), ''));
      Th.title := DateText(DayList[I]);
      Head.appendChild(Th);
    end;
    Table.appendChild(Head);
    Order := SortBy(Series.slice(0), function(A, B: TJSObject): double begin Result := Sum(TJSArray(B['counts'])) - Sum(TJSArray(A['counts'])); end);
    for I := 0 to Order.length - 1 do HeatRow(TJSObject(Order[I]));
    Wrap.appendChild(Table);
    Box.appendChild(Wrap);
  end;
  Pretenders := TJSArray(R['pretenders']);
  if Pretenders.length > 0 then
  begin
    Box.appendChild(C.el('h3', '', T('Pretending to be one of them')));
    Box.appendChild(C.el('p', 'hint', T('These name a known crawler in their browser string but come from outside its company''s published addresses.')));
    ListView(Box, TListOptions(new([
      'id', 'v-pretenders', 'key', FieldOf('name'), 'sort', '-requests', 'search', False, 'rows', Pretenders,
      'columns', Items(
        Column('name', T('Says it is')), Column('company', T('Company')), Column('requests', T('Requests'), 'n'),
        Column('addresses', T('Addresses'), 'n'), Column('last', T('Last seen'), 'd', nil, StampOf('last')),
        Column('sample', T('For example'), 'w', nil, function(P: TJSObject): JSValue begin Result := AddressCell(P['sample']); end)),
      'noun', Noun('%d pretender', '%d pretenders'),
      'detail', TRowDetail(procedure(P: TJSObject; Holder: TJSHTMLElement; View: TListView)
        begin
          C.facts(Holder, Items(Pair(T('Says it is'), string(P['name']) + ' (' + string(P['company']) + ')'), Pair(T('Requests'), P['requests']),
            Pair(T('For example'), AddressCell(P['sample']))));
        end)])));
  end;
  if Sources.length > 0 then
  begin
    Lists := C.el('details', 'crawl-sources');
    Lists.appendChild(C.el('summary', '', T('The published lists')));
    Holder := C.el('div');
    Lists.appendChild(Holder);
    Box.appendChild(Lists);
    ListView(Holder, TListOptions(new([
      'id', 'v-sources', 'key', FieldOf('url'), 'sort', 'company', 'search', False, 'rows', Sources,
      'columns', Items(
        Column('company', T('Company')),
        Column('name', T('Crawler'), '', nil, function(Source: TJSObject): JSValue
          var
            A: TJSHTMLElement;
          begin
            A := C.el('a', '', Source['name']);
            TJSObject(A)['href'] := Source['url'];
            TJSObject(A)['target'] := '_blank';
            TJSObject(A)['rel'] := 'noopener';
            Result := A;
          end),
        Column('ranges', T('Ranges'), 'n'),
        Column('created', T('List dated'), 'w', nil, function(Source: TJSObject): JSValue
          begin
            if Truthy(Source['created']) then Result := DateText(Source['created']) else Result := '';
          end),
        Column('fetched', T('Read'), 'w', nil, function(Source: TJSObject): JSValue
          begin
            if Truthy(Source['fetched']) then Result := DateTimeText(Source['fetched']) else Result := '';
          end),
        Column('error', T('Problem'))),
      'noun', Noun('%d list', '%d lists')])));
  end;
end;

procedure DrawBots(Box: TJSHTMLElement; R: TJSObject);
var
  Checks: TJSObject;

  function CheckSpan(B: TJSObject; Words: JSValue): TJSHTMLElement;
  begin
    if Same(B['check'], 'unverified') then Result := C.el('span', 'bot-bad', Words) else Result := C.el('span', 'bot-ok', Words);
  end;

begin
  Box.appendChild(C.el('p', 'hint', T('Known by the name in their browser string, or because they asked for robots.txt. The big search engines are checked against their DNS: one that only claims the name shows as not verified.')));
  Checks := new(['listed', '✓ ' + T('Published address'), 'verified', '✓ ' + T('Verified'), 'unverified', T('Not verified')]);
  ListView(Box, TListOptions(new([
    'id', 'v-bots', 'key', FieldOf('name'), 'sort', '-requests', 'csv', 'bots-' + WindowName(R), 'search', T('Filter bots'), 'rows', R['bots'],
    'columns', Items(
      Column('name', T('Bot')),
      Column('check', T('Checked'), '', function(B: TJSObject): JSValue begin Result := Either(Checks[string(B['check'])], ''); end,
        function(B: TJSObject): JSValue
        begin
          if Truthy(B['check']) then Result := CheckSpan(B, Either(Checks[string(B['check'])], B['check'])) else Result := '';
        end),
      Column('requests', T('Requests'), 'n'),
      Column('addresses', T('Addresses'), 'n'),
      Column('last', T('Last seen'), 'd', nil, StampOf('last')),
      Column('paths', T('Pages it asked for most'), 'ws', function(B: TJSObject): JSValue begin Result := TJSArray(B['paths']).join(' '); end,
        function(B: TJSObject): JSValue
        var
          Paths, Words: TJSArray;
          N: NativeInt;
        begin
          Paths := TJSArray(B['paths']).slice(0, 3);
          Words := TJSArray.new;
          for N := 0 to Paths.length - 1 do Words.push(Either(Paths[N], '/'));
          Result := C.el('span', 'dim', Words.join('  ·  '));
        end, 'lv-text')),
    'filters', Items(Filter('check', T('Checked'), T('Checked or not'),
      Items(Pair('listed', T('Published address')), Pair('verified', T('Verified')), Pair('unverified', T('Not verified')), Pair('-', T('Not checked'))),
      function(B: TJSObject; K: string): JSValue begin if K = '-' then Result := not Truthy(B['check']) else Result := Same(B['check'], K); end)),
    'noun', Noun('%d bot', '%d bots'), 'empty', T('No bot came in that period.'),
    'detail', TRowDetail(procedure(B: TJSObject; Holder: TJSHTMLElement; View: TListView)
      var
        Head, List, Line: TJSHTMLElement;
        Paths: TJSArray;
        Example: JSValue;
        N: NativeInt;
      begin
        Head := C.el('div', 'lv-detail-head');
        if Truthy(B['check']) then TKit(Head).add(C.el('b', '', B['name']), CheckSpan(B, Checks[string(B['check'])]))
        else TKit(Head).add(C.el('b', '', B['name']), '');
        Holder.appendChild(Head);
        if Truthy(B['sample']) then Example := AddressCell(B['sample']) else Example := '';
        C.facts(Holder, Items(Pair(T('Requests'), LocaleNumber(B['requests'])), Pair(T('Addresses'), B['addresses']), Pair(T('For example'), Example),
          Pair(T('Last seen'), Stamp(B['last']))));
        Holder.appendChild(C.el('h3', '', T('Pages it asked for most')));
        List := C.el('ul', 'lv-paths');
        Paths := TJSArray(B['paths']);
        for N := 0 to Paths.length - 1 do
        begin
          Line := C.el('li');
          Line.appendChild(PageLink(Either(Paths[N], '/')));
          List.appendChild(Line);
        end;
        Holder.appendChild(List);
      end)])));
end;

// the latest requests of the day, newest first: people's pages, the rest
// of what people asked for, and the bots', as the report told them apart
procedure DrawLatest(Box: TJSHTMLElement; R: TJSObject);
begin
  Box.appendChild(C.el('p', 'hint', T('The latest thousand requests from people and four hundred from bots in the period, newest first. Pick an address for its whole story.')));
  ListView(Box, TListOptions(new([
    'id', 'v-latest2', 'key', TRowValue(function(L: TJSObject): JSValue begin Result := string(L['at']) + string(L['ip']) + string(L['path']) + string(L['kind']); end),
    'sort', '-at', 'csv', 'latest-' + WindowName(R), 'page', 200,
    'search', T('Filter by address, page or member'), 'rows', Either(R['latest'], TJSArray.new),
    'columns', Items(
      Column('at', T('When'), 'd', nil, StampOf('at')),
      Column('ip', T('Address'), '', nil, function(L: TJSObject): JSValue begin Result := AddressCell(L['ip']); end),
      Column('member', T('Member'), '', nil, @MemberOf),
      Column('path', T('Page'), '', nil, PageOf('path')),
      Column('status', T('Status'), 'n', nil, function(L: TJSObject): JSValue begin Result := StatusCell(L['status']); end),
      Column('ms', T('Took'), 'nw', nil, function(L: TJSObject): JSValue begin Result := MsCell(L['ms']); end),
      Column('browser', T('Browser or bot'), 'w', function(L: TJSObject): JSValue begin Result := Either(L['bot'], BrowserOf(L['agent'])); end,
        function(L: TJSObject): JSValue
        var
          Seen: TJSHTMLElement;
        begin
          Seen := C.el('span', 'dim', Either(L['bot'], BrowserOf(L['agent'])));
          TJSObject(Seen)['title'] := L['agent'];
          Result := Seen;
        end)),
    'filters', Items(
      new(['key', 'kind', 'title', T('Which'), 'all', T('Every request'), 'value', 'page',
        'options', Items(Pair('page', T('Pages people read')), Pair('other', T('Everything else people asked for')), Pair('bot', T('Bots'))),
        'test', TRowTest(function(L: TJSObject; K: string): JSValue begin Result := Same(L['kind'], K); end)]),
      Filter('status', T('Status'), T('Any status'), Items(Pair('ok', T('Answered')), Pair('4xx', T('Refused or not here')), Pair('5xx', T('Failed'))),
        function(L: TJSObject; K: string): JSValue
        begin
          if K = 'ok' then Result := not (Num(L['status']) >= 400)
          else if K = '4xx' then Result := (Num(L['status']) >= 400) and (Num(L['status']) < 500)
          else Result := Num(L['status']) >= 500;
        end),
      Filter('section', T('Part of the site'), T('The whole site'),
        TRowsValue(function(Rows: TJSArray): JSValue begin Result := SectionOptions(Column2(Rows, 'path')); end),
        function(L: TJSObject; K: string): JSValue begin Result := SectionOf(L['path']) = K; end)),
    'noun', Noun('%d request', '%d requests'), 'empty', T('Nothing in that period''s logs yet.'),
    'detail', TRowDetail(procedure(L: TJSObject; Holder: TJSHTMLElement; View: TListView)
      var
        Head, Acts: TJSHTMLElement;
        Answered, From: JSValue;
      begin
        Head := C.el('div', 'lv-detail-head');
        TKit(Head).add(C.el('b', '', L['ip']), MemberOf(L), C.el('span', 'dim', DateTimeText(L['at'])));
        Holder.appendChild(Head);
        if Truthy(L['status']) then Answered := StatusCell(L['status']) else Answered := '';
        if Truthy(L['referer']) then From := OutLink(L['referer']) else From := '';
        C.facts(Holder, Items(Pair(T('Asked for'), string(L['method']) + ' ' + string(L['path'])), Pair(T('Page'), PageLink(L['path'])), Pair(T('Answered'), Answered),
          Pair(T('Took'), MsCell(L['ms'])), Pair(T('Bot'), L['bot']), Pair(T('From'), From), Pair(T('Browser'), L['agent'])));
        Acts := C.el('div', 'lv-actions');
        Acts.appendChild(LookButton(L['ip']));
        Holder.appendChild(Acts);
      end)])));
end;

procedure DrawVisitCounts(Box: TJSHTMLElement; Data: TJSObject);
var
  DayRows, Days, CountCols, Rows, Total: TJSArray;
  Today: JSValue;
  ByDay, Totals: TJSMap;
  Day: TJSObject;
  Row, Bar, Caption: TJSHTMLElement;
  Most: double;
  I: NativeInt;

  function PartName(X: TJSObject): JSValue;
  begin
    Result := PartLabel(X['part']);
  end;

begin
  if not Truthy(Data['server']) then Box.appendChild(C.el('p', 'notice', T('Visitor collection requires server mode.')));
  DayRows := TJSArray(Data['days']);
  if DayRows.length > 0 then Today := TJSObject(DayRows[0])['day'] else Today := '';
  ByDay := TJSMap.new;
  for I := 0 to DayRows.length - 1 do
  begin
    Day := TJSObject(DayRows[I]);
    ByDay.&set(Day['day'], Num(Either(ByDay.get(Day['day']), 0)) + Num(Day['requests']));
  end;
  Days := SortBy(TJSArray.from(ByDay), undefined).slice(-30);
  if Days.length > 1 then
  begin
    Rows := TJSArray.new;
    for I := 0 to Days.length - 1 do Rows.push(TJSArray(Days[I])[1]);
    Most := MostOf(Rows);
    Row := C.el('div', 'days');
    for I := 0 to Days.length - 1 do
    begin
      Bar := C.el('i');
      TJSObject(Bar.style)['height'] := Pixels(66 * Num(TJSArray(Days[I])[1]) / Most, 2);
      Bar.title := DateText(TJSArray(Days[I])[0]) + ': ' + TN(TJSArray(Days[I])[1], '%d request', '%d requests');
      if Same(TJSArray(Days[I])[0], Today) then Bar.classList.add('today');
      Row.appendChild(Bar);
    end;
    Box.appendChild(Row);
    Caption := C.el('div', 'days-caption');
    TKit(Caption).add(C.el('span', '', DateText(TJSArray(Days[0])[0])), C.el('span', '', T('requests a day, bots included')),
      C.el('span', '', DateText(TJSArray(Days[Days.length - 1])[0])));
    Box.appendChild(Caption);
  end;
  Box.appendChild(C.el('p', 'hint', T('UTC days. Counts are saved each minute. People are browsers that took the page whole, bots everything else that came; each address counts once in each part and day, and totals add those counts. People are counted from 6 Nov 2026.')));
  Totals := TJSMap.new;
  for I := 0 to DayRows.length - 1 do
  begin
    Day := TJSObject(DayRows[I]);
    Total := TJSArray(Either(Totals.get(Day['part']), Items(0, 0, 0, 0)));
    Day['people'] := MathMin(Num(Either(Day['people'], 0)), Num(Day['visitors']));
    Day['bots'] := Num(Day['visitors']) - Num(Day['people']);
    Total[0] := Num(Total[0]) + Num(Day['requests']);
    Total[1] := Num(Total[1]) + Num(Day['people']);
    Total[2] := Num(Total[2]) + Num(Day['refused']);
    Total[3] := Num(Total[3]) + Num(Day['bots']);
    Totals.&set(Day['part'], Total);
  end;
  CountCols := Items(Column('requests', T('Requests'), 'n'), Column('people', T('People'), 'n'), Column('bots', T('Bot addresses'), 'n'),
    Column('refused', T('Guard refusals'), 'n'));
  Box.appendChild(C.el('h3', '', T('All days kept')));
  Rows := TJSArray.new;
  Days := TJSArray.from(Totals);
  for I := 0 to Days.length - 1 do
  begin
    Total := TJSArray(TJSArray(Days[I])[1]);
    Rows.push(new(['part', TJSArray(Days[I])[0], 'requests', Total[0], 'people', Total[1], 'refused', Total[2], 'bots', Total[3]]));
  end;
  ListView(Box, TListOptions(new([
    'id', 'v-parts', 'key', FieldOf('part'), 'sort', '-requests', 'search', False,
    'rows', Rows,
    'columns', Items(Column('part', T('Part'), '', @PartName)).concat(CountCols), 'noun', Noun('%d part', '%d parts')])));
  Box.appendChild(C.el('h3', '', T('Day by day')));
  ListView(Box, TListOptions(new([
    'id', 'v-partdays', 'key', TRowValue(function(X: TJSObject): JSValue begin Result := string(X['day']) + string(X['part']); end),
    'sort', '-day', 'search', False, 'csv', 'requests-by-day',
    'rows', DayRows,
    'columns', Items(Column('day', T('Day'), 'd', nil, function(X: TJSObject): JSValue begin Result := DateText(X['day']); end),
      Column('part', T('Part'), '', @PartName)).concat(CountCols),
    'filters', Items(Filter('part', T('Part'), T('Every part'), TRowsValue(function(List: TJSArray): JSValue
      var
        Names, Choices: TJSArray;
        N: NativeInt;
      begin
        Names := Distinct(Column2(List, 'part'));
        Choices := TJSArray.new;
        for N := 0 to Names.length - 1 do Choices.push(Pair(Names[N], PartLabel(Names[N])));
        Result := Choices;
      end),
      function(X: TJSObject; K: string): JSValue begin Result := Same(X['part'], K); end)),
    'noun', Noun('%d row', '%d rows')])));
  Box.appendChild(C.el('h3', '', T('Busiest paths today')));
  ListView(Box, TListOptions(new([
    'id', 'v-paths', 'key', FieldOf('path'), 'sort', '-requests', 'search', T('Filter paths'), 'rows', Data['paths'],
    'columns', Items(Column('path', T('Path'), '', nil, PageOf('path')), Column('requests', T('Requests'), 'n')),
    'noun', Noun('%d path', '%d paths')])));
end;

// the addresses the report holds something against, the worst first
procedure DrawConcerns(Box: TJSHTMLElement; R: TJSObject; Period: JSValue);
var
  Concerns: TJSArray;
  Kinds, BlockWords: TJSObject;

  function Reasons(Concern: TJSObject): TJSArray;
  begin
    Result := TJSArray(Concern['reasons']);
  end;

begin
  Box.replaceChildren;
  Box.appendChild(C.el('p', 'hint', T('Every address is judged on its own, whatever it said it was: its busiest minute, how many browser strings and members it used, the pages it asked for that are not here, the scanner paths it probed, how often the guard turned it away, and whether it named a crawler it is not. A published crawler is welcome at any pace; an address on the allowed list (or this network) is not weighed. Pick a row for the whole story and the block buttons.')));
  Concerns := TJSArray(R['concerns']);
  if Num(R['concerns_count']) > Concerns.length then
    Box.appendChild(C.el('p', 'hint', T('The %s weighed heaviest are listed, of %s.', LocaleNumber(Concerns.length), LocaleNumber(R['concerns_count']))));
  Kinds := ReasonKinds;
  BlockWords := new(['forgood', T('For good'), 'blocked', T('Blocked now'), 'over', T('Block over')]);
  ListView(Box, TListOptions(new([
    'id', 'v-concerns', 'key', FieldOf('ip'), 'sort', '-score', 'csv', 'concerns-' + WindowName(R),
    'search', T('Filter by address, bot or reason'), 'rows', Concerns,
    'columns', Items(
      Column('score', T('Weight'), 'n'),
      Column('ip', T('Address'), '', nil, function(Concern: TJSObject): JSValue begin Result := C.el('b', 'lv-ip', Concern['ip']); end),
      // the guard's state, so a blocked address shows without opening it
      Column('block', T('Blocked'), '', function(Concern: TJSObject): JSValue begin Result := Either(BlockWords[string(Concern['block'])], ''); end,
        function(Concern: TJSObject): JSValue
        begin
          if not Truthy(Concern['block']) then Result := C.el('span', '', '')
          else if Same(Concern['block'], 'over') then Result := C.chip(BlockWords[string(Concern['block'])], '')
          else Result := C.chip(BlockWords[string(Concern['block'])], 'bad');
        end),
      Column('what', T('Says it is'), '', function(Concern: TJSObject): JSValue begin Result := Either(Either(Concern['crawler'], Concern['bot']), T('a browser')); end),
      // AbuseIPDB's confidence, once the site has looked the address up
      Column('abuse', T('AbuseIPDB'), 'n', function(Concern: TJSObject): JSValue
        begin
          if IsUndef(Concern['abuse']) or (Concern['abuse'] = nil) then Result := -1 else Result := Concern['abuse'];
        end,
        function(Concern: TJSObject): JSValue
        begin
          if IsUndef(Concern['abuse']) or (Concern['abuse'] = nil) then Result := C.el('span', 'dim', '')
          else if Num(Concern['abuse']) >= 75 then Result := C.chip(string(Concern['abuse']) + '%', 'bad')
          else Result := C.chip(string(Concern['abuse']) + '%', '');
        end),
      Column('reasons', T('Why'), 's', function(Concern: TJSObject): JSValue
        var
          Words: TJSArray;
          N: NativeInt;
        begin
          Words := TJSArray.new;
          for N := 0 to Reasons(Concern).length - 1 do Words.push(ReasonWords(TJSObject(Reasons(Concern)[N])));
          Result := Words.join('; ');
        end,
        function(Concern: TJSObject): JSValue
        var
          Chips: TJSHTMLElement;
          N: NativeInt;
        begin
          Chips := C.el('span', 'lv-reasons');
          for N := 0 to Reasons(Concern).length - 1 do Chips.appendChild(C.chip(ReasonWords(TJSObject(Reasons(Concern)[N])), 'open'));
          Result := Chips;
        end, 'lv-text'),
      Column('requests', T('Requests'), 'n'),
      Column('peak', T('Busiest minute'), 'nw'),
      Column('last', T('Last seen'), 'dw', nil, StampOf('last'))),
    'filters', Items(
      Filter('block', T('Blocked'), T('Blocked or not'),
        Items(Pair('forgood', T('For good')), Pair('blocked', T('Blocked now')), Pair('over', T('Block over')), Pair('none', T('Never blocked'))),
        function(Concern: TJSObject; V: string): JSValue
        begin
          if V = 'none' then Result := not Truthy(Concern['block']) else Result := Same(Concern['block'], V);
        end),
      Filter('kind', T('Reason'), T('Every reason'), TRowsValue(function(Rows: TJSArray): JSValue
        var
          Seen: TJSMap;
          N, M: NativeInt;
        begin
          Seen := TJSMap.new;
          for N := 0 to Rows.length - 1 do
            for M := 0 to Reasons(TJSObject(Rows[N])).length - 1 do Count(Seen, TJSObject(Reasons(TJSObject(Rows[N]))[M])['kind']);
          Result := Counted(Seen, Kinds);
        end),
        function(Concern: TJSObject; K: string): JSValue
        var
          N: NativeInt;
        begin
          Result := False;
          for N := 0 to Reasons(Concern).length - 1 do
            if Same(TJSObject(Reasons(Concern)[N])['kind'], K) then Exit(True);
        end)),
    'noun', Noun('%d address', '%d addresses'), 'empty', T('Nothing of concern in that period.'),
    'detail', TRowDetail(procedure(Concern: TJSObject; Holder: TJSHTMLElement; View: TListView) begin AddressPanel(Concern['ip'], Holder, Period); end)])));
end;

// the day's report in sub-tabs: people apart from bots, what they read,
// where from, the crawlers and bots, the latest requests
procedure DrawVisitReport(Subs: TSubTabs; R: TJSObject; Pick, HideMe, HiddenSet: JSValue);
const
  Keys: array[0..8] of string = ('overview', 'people', 'pages', 'searches', 'members', 'crawlers', 'bots', 'concerns', 'latest');
var
  Box: TJSHTMLElement;
  Pages: TJSArray;
  Hint: string;
  I: NativeInt;
begin
  for I := 0 to 8 do Subs.holder(Keys[I]).replaceChildren;
  if not Truthy(R['found']) then
  begin
    for I := 0 to 8 do Subs.holder(Keys[I]).appendChild(C.el('p', 'dim', T('There is no log for that period.')));
    Exit;
  end;
  // the lists stop at the thousand who read most; the badges count everyone
  if IsUndef(R['visitors_count']) or (R['visitors_count'] = nil) then Subs.count('people', TJSArray(R['visitors']).length)
  else Subs.count('people', R['visitors_count']);
  if IsUndef(R['pages_count']) or (R['pages_count'] = nil) then Subs.count('pages', TJSArray(R['pages']).length)
  else Subs.count('pages', R['pages_count']);
  Subs.count('searches', TJSArray(R['searches']).length);
  Subs.count('members', TJSArray(R['members']).length);
  Subs.count('crawlers', TJSArray(R['crawlers']).length);
  Subs.count('bots', TJSArray(R['bots']).length);
  Subs.count('concerns', Either(R['concerns_count'], 0));

  DrawVisitOverview(Subs, R, HideMe);

  DrawPeople(Subs.holder('people'), R);

  Box := Subs.holder('pages');
  Pages := TJSArray(R['pages']);
  if Num(R['pages_count']) > Pages.length then
    Box.appendChild(C.el('p', 'hint', T('The %s pages read most are listed, of %s.', LocaleNumber(Pages.length), LocaleNumber(R['pages_count']))));
  ListView(Box, TListOptions(new([
    'id', 'v-pages', 'key', FieldOf('path'), 'sort', '-views', 'csv', 'pages-' + WindowName(R), 'search', T('Filter pages'), 'rows', Pages,
    'columns', Items(
      Column('path', T('Page'), '', nil, PageOf('path')),
      Column('views', T('Views'), 'n'),
      Column('people', T('People'), 'n')),
    'filters', Items(Filter('section', T('Part of the site'), T('The whole site'),
      TRowsValue(function(Rows: TJSArray): JSValue begin Result := SectionOptions(Column2(Rows, 'path')); end),
      function(P: TJSObject; K: string): JSValue begin Result := SectionOf(P['path']) = K; end)),
    'noun', Noun('%d page', '%d pages'), 'empty', T('Nothing yet.')])));

  Box := Subs.holder('searches');
  Hint := T('What people typed in the search boxes and pages. A box that searches as one types counts once, with the words as they ended.');
  if Truthy(HideMe) then Hint := Hint + ' ' + T('Your own searches are left out while Hide my visits is ticked.');
  Box.appendChild(C.el('p', 'hint', Hint));
  ListView(Box, TListOptions(new([
    'id', 'v-searches', 'key', TRowValue(function(Search: TJSObject): JSValue begin Result := string(Search['where']) + string(Search['words']); end),
    'sort', '-count', 'search', T('Filter searches'), 'rows', R['searches'],
    'columns', Items(
      Column('where', T('Where'), '', function(Search: TJSObject): JSValue begin Result := PlaceName(Search['where']); end),
      Column('words', T('Words')),
      Column('count', T('Times'), 'n'),
      Column('last', T('Last searched'), 'd', nil, StampOf('last'))),
    'filters', Items(Filter('where', T('Where'), T('Everywhere'), TRowsValue(function(Rows: TJSArray): JSValue
      var
        Places, Choices: TJSArray;
        N: NativeInt;
      begin
        Places := Distinct(Column2(Rows, 'where'));
        Choices := TJSArray.new;
        for N := 0 to Places.length - 1 do Choices.push(Pair(Places[N], PlaceName(Places[N])));
        Result := Choices;
      end),
      function(Search: TJSObject; K: string): JSValue begin Result := Same(Search['where'], K); end)),
    'noun', Noun('%d search', '%d searches'), 'empty', T('Nobody searched in that period.')])));

  Box := Subs.holder('members');
  ListView(Box, TListOptions(new([
    'id', 'v-members', 'key', FieldOf('name'), 'sort', '-pages', 'search', False, 'rows', R['members'],
    'columns', Items(
      Column('name', T('Member'), '', nil, function(M: TJSObject): JSValue begin Result := MemberLink(M['name']); end),
      Column('pages', T('Pages'), 'n'),
      Column('last', T('Last seen'), 'd', nil, StampOf('last'))),
    'noun', Noun('%d member', '%d members'), 'empty', T('No member was signed in during that period.')])));

  DrawCrawlers(Subs.holder('crawlers'), R);
  DrawBots(Subs.holder('bots'), R);
end;

procedure AdminVisitors(Box: TJSHTMLElement);
const
  ReportParts: array[0..8] of string = ('overview', 'people', 'pages', 'searches', 'members', 'crawlers', 'bots', 'concerns', 'latest');
var
  HideMe, Blocks: boolean;
  Choice: string;
  Days: TJSArray;
  Controls, PickLabel, Custom, TickLabel, Again, AddrBox, AddrForm, AddrGo, AddrPanel: TJSHTMLElement;
  Pick: TJSHTMLSelectElement;
  FromBox, ToBox, Tick, AddrInput: TJSHTMLInputElement;
  Period: TJSObject;
  TabList: TJSArray;
  Subs: TSubTabs;
  ShownIp: string;
  Loads: NativeInt;

  function UtcDay(Back: double): string;
  begin
    Result := TJSString(TMoment.new(TJSDate.now - Back * 864e5).toISOString).slice(0, 10);
  end;

  function Iso(Ms: double): string;
  begin
    Result := TJSString(TMoment.new(Ms).toISOString).slice(0, 19) + 'Z';
  end;

  // midnight on this computer's clock, back days ago: today and yesterday
  // are the admin's own days, not UTC ones (those start at 7 PM in New York)
  function LocalMidnight(Back: NativeInt): double;
  var
    D: TMoment;
  begin
    D := TMoment.new;
    D.setHours(0, 0, 0, 0);
    D.setDayOfMonth(D.dayOfMonth - Back);
    Result := D.milliseconds;
  end;

  function Local(Ms: double): string;
  var
    D: TMoment;
  begin
    D := TMoment.new(Ms);
    Result := TJSString(TMoment.new(Ms - D.zoneOffset * 60000).toISOString).slice(0, 16);
  end;

  function Option(Value, Words: JSValue): TJSHTMLElement;
  begin
    Result := C.el('option', '', Words);
    TJSObject(Result)['value'] := Value;
  end;

  procedure FillPeriods;
  var
    Oldest: JSValue;
    One: TJSHTMLElement;
    I: NativeInt;
  begin
    if Days.length > 0 then Oldest := Days[Days.length - 1] else Oldest := UtcDay(0);
    TKit(JSValue(Pick)).fill(
      Option('1h', T('The last hour')), Option('8h', T('The last 8 hours')), Option('24h', T('The last 24 hours')),
      Option('48h', T('The last 2 days')), Option('168h', T('The last 7 days')),
      Option('today', T('Today')), Option('yesterday', T('Yesterday')),
      Option('all', TJSString(TN(Days.length, 'Every day kept (%d), from %s', 'Every day kept (%d), from %s')).replace('%s', DateText(Oldest))),
      Option('custom', T('Between two moments…')));
    One := C.el('optgroup');
    TJSObject(One)['label'] := T('One day');
    for I := 0 to Days.length - 1 do One.appendChild(Option(Days[I], DateText(Days[I])));
    Pick.appendChild(One);
    Pick.value := Choice;
    if Pick.value <> Choice then
    begin
      Choice := '24h';
      Pick.value := Choice;
    end;
  end;

  // the window as the server takes it: moments for the hours (the end rounded
  // to the minute, so a second look within it finds the report kept), days whole
  function WindowOf: TJSObject;
  var
    Minute, A, B: double;
    Oldest: JSValue;
  begin
    Minute := MathFloor(TJSDate.now / 60000) * 60000;
    if Regex('^\d+h$', Choice) then Exit(new(['from', Iso(Minute + 59000 - parseInt(Choice, 10) * 3600e3), 'to', Iso(Minute + 59000)]));
    if Choice = 'today' then Exit(new(['from', Iso(LocalMidnight(0)), 'to', Iso(Minute + 59000)]));
    if Choice = 'yesterday' then Exit(new(['from', Iso(LocalMidnight(1)), 'to', Iso(LocalMidnight(0) - 1000)]));
    if Choice = 'all' then
    begin
      if Days.length > 0 then Oldest := Days[Days.length - 1] else Oldest := UtcDay(0);
      Exit(new(['from', Oldest, 'to', UtcDay(0)]));
    end;
    if Choice = 'custom' then
    begin
      if FromBox.value <> '' then A := TMoment.new(FromBox.value).milliseconds else A := Minute - 864e5;
      if ToBox.value <> '' then B := TMoment.new(ToBox.value).milliseconds else B := Minute + 59000;
      if A <= B then Exit(new(['from', Iso(A), 'to', Iso(B)]));
      Exit(new(['from', Iso(B), 'to', Iso(A)]));
    end;
    Result := new(['from', Choice, 'to', Choice]);
  end;

  function PeriodNow: TJSObject;
  begin
    Result := Period;
  end;

  // the address panel: any address, typed or picked anywhere, in the window shown
  procedure ShowAddress(Ip: JSValue);
  begin
    ShownIp := TJSString(Either(Ip, '')).trim;
    AddrInput.value := ShownIp;
    AddrPanel.hidden := ShownIp = '';
    if ShownIp <> '' then AddressPanel(ShownIp, AddrPanel, @PeriodNow);
  end;

  procedure OpenAddress(Ip: JSValue);
  begin
    Subs.select('address');
    ShowAddress(Ip);
  end;

  procedure Hold(Held: boolean);
  begin
    Pick.disabled := Held;
    Tick.disabled := Held;
    TJSObject(Again)['disabled'] := Held;
  end;

  procedure Load; async;
  var
    Mine, I: NativeInt;
    R: TJSObject;
    Why: string;
    Problem: TJSObject;
  begin
    Inc(Loads);
    Mine := Loads;
    Period := WindowOf;
    for I := 0 to 8 do C.waiting(Subs.holder(ReportParts[I]), T('Reading the log…'));
    Hold(True);
    try
      try
        if HideMe then R := await(TJSObject, C.get('/api/admin/visitors/report?from=' + C.enc(Period['from']) + '&to=' + C.enc(Period['to']) + '&hide=me'))
        else R := await(TJSObject, C.get('/api/admin/visitors/report?from=' + C.enc(Period['from']) + '&to=' + C.enc(Period['to'])));
        if Mine <> Loads then Exit;
        if TJSJSON.stringify(Days) <> TJSJSON.stringify(R['days']) then
        begin
          Days := TJSArray(R['days']);
          FillPeriods;
          // "every day kept" asked before the days were known: asked again with them
          if not Same(WindowOf['from'], Period['from']) then
          begin
            Load;
            Exit;
          end;
        end;
        DrawVisitReport(Subs, R, Pick, HideMe, undefined);
        if Truthy(R['found']) then
        begin
          DrawLatest(Subs.holder('latest'), R);
          DrawConcerns(Subs.holder('concerns'), R, @PeriodNow);
        end;
        if ShownIp <> '' then ShowAddress(ShownIp);
        // a blocked row's open story, told again for this window
        if Truthy(S['blocksChanged']) then S.blocksChanged;
      except
        if Mine <> Loads then Exit;
        // the server's own short reason when it gave one (not a proxy's error page)
        Problem := TJSObject(JSExceptValue);
        if Truthy(Problem) and Truthy(Problem['message']) and (TJSString(Problem['message']).length < 300) and not Regex('[<>]', Problem['message']) then
          Why := ' ' + string(Problem['message'])
        else Why := '';
        for I := 0 to 8 do TKit(Subs.holder(ReportParts[I])).fill(C.el('p', 'notice', T('The access log could not be read.') + Why));
      end;
    finally
      if Mine = Loads then Hold(False);
    end;
  end;

  procedure ReadCounts; async;
  var
    Data: TJSObject;
  begin
    try
      Data := await(TJSObject, C.get('/api/admin/visitors'));
      Subs.holder('counts').replaceChildren;
      DrawVisitCounts(Subs.holder('counts'), Data);
    except
      TKit(Subs.holder('counts')).fill(C.el('p', 'notice', TJSObject(JSExceptValue)['message']));
    end;
  end;

begin
  // an admin who manages blocks without seeing visitors: the blocked list alone
  if Truthy(S['adminCan']) and not S.adminCan('view-visitors') then
  begin
    AdminBlocks(Box, TPeriod(function: TJSObject begin Result := new(['from', UtcDay(1), 'to', UtcDay(0)]); end));
    Exit;
  end;
  HideMe := True;
  try
    HideMe := window.localStorage.getItem('admin-hide-me') <> 'off';
  except
  end;
  // the window: the last hours back from now, today or yesterday on this
  // computer's clock, a UTC day (one log), every day kept, or any two
  // moments; the last 24 hours at first, the choice remembered
  Choice := '24h';
  try
    Choice := string(Either(window.localStorage.getItem('admin-visit-window'), '24h'));
  except
  end;
  Days := TJSArray.new;
  Controls := C.el('div', 'visit-controls');
  PickLabel := C.el('label', '', T('Period') + ' ');
  Pick := TJSHTMLSelectElement(C.el('select'));
  PickLabel.appendChild(Pick);
  Custom := C.el('span', 'visit-custom');
  FromBox := TJSHTMLInputElement(C.el('input'));
  ToBox := TJSHTMLInputElement(C.el('input'));
  ToBox._type := 'datetime-local';
  FromBox._type := 'datetime-local';
  FromBox.setAttribute('aria-label', T('From'));
  ToBox.setAttribute('aria-label', T('To'));
  FromBox.value := Local(TJSDate.now - 864e5);
  ToBox.value := Local(TJSDate.now);
  TKit(Custom).add(FromBox, ' – ', ToBox);
  Custom.hidden := Choice <> 'custom';
  FillPeriods;
  Period := WindowOf;
  TickLabel := C.el('label', 'visit-tick');
  Tick := TJSHTMLInputElement(C.el('input'));
  Tick._type := 'checkbox';
  Tick.checked := HideMe;
  TKit(TickLabel).add(Tick, ' ' + T('Hide my visits'));
  Tick.addEventListener('change', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      HideMe := Tick.checked;
      try
        if HideMe then window.localStorage.setItem('admin-hide-me', 'on') else window.localStorage.setItem('admin-hide-me', 'off');
      except
      end;
      Load;
    end));
  Again := C.el('button', 'small-link', T('Refresh'));
  TJSObject(Again)['type'] := 'button';
  Again.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Load; end));
  TKit(Controls).add(PickLabel, Custom, TickLabel, Again);
  Box.appendChild(Controls);
  TabList := Items(
    new(['key', 'overview', 'title', T('Overview')]), new(['key', 'people', 'title', T('People')]), new(['key', 'pages', 'title', T('Pages')]),
    new(['key', 'searches', 'title', T('Searches')]), new(['key', 'members', 'title', T('Members')]), new(['key', 'crawlers', 'title', T('Known crawlers')]),
    new(['key', 'bots', 'title', T('Bots')]), new(['key', 'concerns', 'title', T('Of concern')]), new(['key', 'latest', 'title', T('Latest requests')]),
    new(['key', 'address', 'title', T('Address')]));
  Blocks := Truthy(S['adminCan']) and S.adminCan('manage-blocks');
  if Blocks then TabList.push(new(['key', 'blocked', 'title', T('Blocked')]));
  TabList.push(new(['key', 'counts', 'title', T('By part of the site')]));
  Subs := C.subTabs(Box, 'visitors', TabList);

  AddrBox := Subs.holder('address');
  AddrForm := C.el('form', 'visit-lookup');
  AddrInput := TJSHTMLInputElement(C.el('input'));
  AddrInput._type := 'search';
  AddrInput.placeholder := T('An address, such as 203.0.113.9');
  AddrInput.setAttribute('aria-label', T('Address'));
  AddrGo := C.el('button', '', T('Look up'));
  TKit(AddrForm).add(AddrInput, AddrGo);
  AddrPanel := C.el('div', 'lv-detail visit-address');
  AddrPanel.hidden := True;
  TKit(AddrBox).add(C.el('p', 'hint', T('Everything one address did in the period, whatever it said it was, with the guard’s facts and the block buttons. Pick an address anywhere in these lists, or type one.')),
    AddrForm, AddrPanel);
  ShownIp := '';
  AddrForm.addEventListener('submit', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      E.preventDefault;
      ShowAddress(AddrInput.value);
    end));
  S['showAddress'] := @OpenAddress;
  S['blockLook'] := S['showAddress'];

  Loads := 0;
  Pick.addEventListener('change', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      Choice := Pick.value;
      try
        window.localStorage.setItem('admin-visit-window', Choice);
      except
      end;
      Custom.hidden := Choice <> 'custom';
      Load;
    end));
  FromBox.addEventListener('change', TJSRawEventHandler(procedure(E: TJSEvent) begin if Choice = 'custom' then Load; end));
  ToBox.addEventListener('change', TJSRawEventHandler(procedure(E: TJSEvent) begin if Choice = 'custom' then Load; end));
  Load;
  if Blocks then AdminBlocks(Subs.holder('blocked'), @PeriodNow);
  C.waiting(Subs.holder('counts'));
  ReadCounts;
end;

end.
