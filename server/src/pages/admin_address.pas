unit Admin_Address;

{ One address's whole story, the chart of a period in bars, and the buttons that
  block or allow an address. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, Admin_List;

procedure TimelineChart(Box: TJSHTMLElement; Tl: TJSObject; Compact: boolean = False);
procedure AddressPanel(Ip: JSValue; Holder: TJSHTMLElement; Period: JSValue);

implementation

type
  TAfter = reference to procedure;
  TPeriod = reference to function: TJSObject;

// Lift, Block now, Block for good, Allow: for an admin who manages blocks;
// after() runs once the server has it
// crawler: what a verified crawler at ip is ('GPTBot · OpenAI'), so a
// block of it is asked about first and sent with the server's say-so
procedure BlockButtons(Holder: TJSHTMLElement; Ip: JSValue; B: TJSObject; After: TAfter; Crawler: JSValue);
var
  Lift, ForGood, Block, Allow: TJSHTMLElement;

  // asked before anything else, so the warning comes ahead of the reason
  function CrawlerOk: boolean;
  begin
    Result := not Truthy(Crawler) or window.confirm(T('%s is %s, checked against the addresses its company publishes. Blocking it keeps the site out of that company’s search and answers. Block it anyway?', Ip, Crawler));
  end;

  procedure Act(const What: string; Reason: JSValue); async;
  var
    Blocking: boolean;
    Ok: string;
  begin
    Blocking := (What = 'block') or (What = 'forgood');
    if Blocking and Truthy(Crawler) then Ok := '1' else Ok := '';
    try
      await(JSValue, C.post('/api/blocks', new(['ip', Ip, 'do', What, 'reason', Either(Reason, ''), 'crawler_ok', Ok])));
    except
      C.failed(JSExceptValue);
      Exit;
    end;
    if Truthy(S['blocksChanged']) then S.blocksChanged;
    if Assigned(After) then After();
  end;

begin
  if not Truthy(S['adminCan']) or not S.adminCan('manage-blocks') then Exit;
  if Truthy(B) and Truthy(B['active']) then
  begin
    Lift := C.el('button', '', T('Lift'));
    TJSObject(Lift)['type'] := 'button';
    Lift.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Act('lift', undefined); end));
    Holder.appendChild(Lift);
  end;
  if not Truthy(B) or not Truthy(B['for_good']) then
  begin
    ForGood := C.el('button', 'bad', T('Block for good'));
    TJSObject(ForGood)['type'] := 'button';
    ForGood.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      var
        Go: boolean;
      begin
        if Truthy(Crawler) then Go := CrawlerOk else Go := window.confirm(T('Block %s for good?', Ip));
        if Go then Act('forgood', undefined);
      end));
    Holder.appendChild(ForGood);
  end;
  if not Truthy(B) or not Truthy(B['active']) then
  begin
    Block := C.el('button', '', T('Block now'));
    TJSObject(Block)['type'] := 'button';
    Block.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      var
        Reason: JSValue;
      begin
        if not CrawlerOk then Exit;
        Reason := window.prompt(T('Why? (kept with the block)'), '');
        if not (Reason = nil) then Act('block', Reason);
      end));
    Holder.appendChild(Block);
  end;
  Allow := C.el('button', '', T('Allow'));
  TJSObject(Allow)['type'] := 'button';
  Allow.title := T('Never block or limit this address again');
  Allow.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Act('allow', undefined); end));
  Holder.appendChild(Allow);
end;

// the window in bars, people apart from bots apart from errors, each row to
// its own scale: bots outnumber people a hundred to one here, and one scale
// would flatten the people to nothing
procedure TimelineChart(Box: TJSHTMLElement; Tl: TJSObject; Compact: boolean);
var
  Step, Start, Most, Total, Sum: double;
  N, I, J, K: NativeInt;
  StepWords: string;
  Rows, Series, Ser, Words: TJSArray;
  Row: TJSObject;
  Wrap, Head, Columns, Col, Seg, Cap: TJSHTMLElement;
  V: JSValue;
  Any: boolean;

  function Iso(Ms: double): string;
  begin
    Result := TDate.new(Ms).toISOString;
  end;

  function When(Bar: NativeInt): string;
  var
    A, B: double;
  begin
    A := Start + Bar * Step * 1000;
    B := A + Step * 1000 - 1000;
    if Step >= 86400 then Exit(DateText(TJSString(Iso(A)).slice(0, 10)));
    if Step >= 7200 then Result := DateTimeText(Iso(A)) else Result := string(Stamp(Iso(A)));
    Result := Result + ' – ' + string(C.clock(Iso(B)));
  end;

  // the count of one series in one bar, nothing where it has none
  function CountOf(One: TJSArray; Bar: NativeInt): JSValue;
  begin
    Result := Either(TJSArray(Either(One[0], TJSArray.new))[Bar], 0);
  end;

begin
  if not Truthy(Tl) or not Truthy(Tl['pages']) or not Truthy(TJSArray(Tl['pages']).length) then Exit;
  Step := Num(Tl['step']);
  Start := TDate.new(Tl['start']).time;
  N := TJSArray(Tl['pages']).length;
  if Step < 3600 then StepWords := TN(Step / 60, 'a bar a minute', 'a bar every %d minutes')
  else if Step < 86400 then StepWords := TN(Step / 3600, 'a bar an hour', 'a bar every %d hours')
  else StepWords := TN(Step / 86400, 'a bar a day', 'a bar every %d days');
  Rows := Items(
    new(['title', T('Pages people read, and the rest they asked for'),
      'series', Items(Items(Tl['pages'], 'tl-pages', T('pages')), Items(Tl['other'], 'tl-other', T('other requests')))]),
    new(['title', T('Bot requests'), 'series', Items(Items(Tl['bots'], 'tl-bots', T('bot requests')))]),
    new(['title', T('Refused, not here, or failed'), 'series', Items(Items(Tl['errors'], 'tl-errors', T('errors')))]));
  if Compact then Wrap := C.el('div', 'timeline compact') else Wrap := C.el('div', 'timeline');
  for I := 0 to Rows.length - 1 do
  begin
    Row := TJSObject(Rows[I]);
    Series := TJSArray(Row['series']);
    Any := False;
    for J := 0 to Series.length - 1 do
    begin
      Ser := TJSArray(Series[J]);
      if Truthy(Ser[0]) then
        for K := 0 to TJSArray(Ser[0]).length - 1 do
          if Truthy(TJSArray(Ser[0])[K]) then Any := True;
    end;
    if not Any then Continue;
    Most := 1;
    Total := 0;
    for K := 0 to N - 1 do
    begin
      Sum := 0;
      for J := 0 to Series.length - 1 do Sum := Sum + Num(CountOf(TJSArray(Series[J]), K));
      if Sum > Most then Most := Sum;
      Total := Total + Sum;
    end;
    Head := C.el('div', 'tl-head');
    TKit(Head).add(C.el('span', '', Row['title']), C.el('span', 'num', LocaleNumber(Total)));
    Wrap.appendChild(Head);
    Columns := C.el('div', 'days tl-row');
    for K := 0 to N - 1 do
    begin
      Col := C.el('b');
      Words := TJSArray.new;
      for J := 0 to Series.length - 1 do
      begin
        Ser := TJSArray(Series[J]);
        V := CountOf(Ser, K);
        Seg := C.el('i', Ser[1]);
        TJSObject(Seg.style)['height'] := Str(MathRound(60 * Num(V) / Most)) + 'px';
        Col.appendChild(Seg);
        Words.push(LocaleNumber(V) + ' ' + string(Ser[2]));
      end;
      Col.title := When(K) + ': ' + Words.join(', ');
      Columns.appendChild(Col);
    end;
    Wrap.appendChild(Columns);
  end;
  Cap := C.el('div', 'days-caption');
  TKit(Cap).add(C.el('span', '', DateTimeText(Tl['start'])), C.el('span', '', StepWords),
    C.el('span', '', DateTimeText(Iso(Start + N * Step * 1000 - 1000))));
  Wrap.appendChild(Cap);
  Box.appendChild(Wrap);
end;

function Requests(N: JSValue): JSValue;
begin
  Result := TN(N, '%d request', '%d requests');
end;

// the keys of counts, the largest count first
function KeysByCount(Counts: TJSObject): TJSArray;
begin
  Result := SortBy(TJSArray(JSValue(TJSObject.keys(Counts))),
    function(X, Y: string): double begin Result := Num(Counts[Y]) - Num(Counts[X]); end);
end;

// One address's whole story in the window (/api/admin/visitors/address):
// what it is, how it behaved, the guard's facts and buttons, its browsers,
// members, pages, statuses, timeline and the last of its requests.
procedure AddressPanel(Ip: JSValue; Holder: TJSHTMLElement; Period: JSValue);
var
  Win: TJSObject;

  procedure Again;
  begin
    AddressPanel(Ip, Holder, Period);
  end;

  procedure Draw(R: TJSObject);
  var
    A, G, Ab, X, M: TJSObject;
    Head, Look, Tiles, P, List, Li, Acts, Two, Left, Right, Ul: TJSHTMLElement;
    A2: TJSHTMLAnchorElement;
    Lookups, Kinds, Rows, Codes, Parts, Strikes, Shown, Names: TJSArray;
    Kinds2: TJSObject;
    CrawlerText, Words, Cls, Code: string;
    Note: JSValue;
    I: NativeInt;

    function Mark(Fits: boolean): string;
    begin
      if Fits then Result := 'warn' else Result := '';
    end;

    function AgentName(Row: TJSObject): JSValue;
    begin
      Result := Either(Row['bot'], BrowserOf(Row['agent']));
    end;

  begin
    Holder.replaceChildren;
    A := TJSObject(R['address']);
    G := TJSObject(R['guard']);
    Head := C.el('div', 'lv-detail-head');
    Head.appendChild(C.el('b', '', R['ip']));
    if Truthy(G) and Truthy(G['host']) then Head.appendChild(C.el('span', 'dim', G['host']));
    // what the rest of the internet knows about it, in a new tab; noreferrer
    // so those sites are not told about this admin page
    Look := C.el('span', 'ip-lookups');
    Lookups := Items(Items('AbuseIPDB', 'https://www.abuseipdb.com/check/', T('Abuse reports about this address')),
      Items('GreyNoise', 'https://viz.greynoise.io/ip/', T('Whether it scans the whole internet')),
      Items('ipinfo', 'https://ipinfo.io/', T('Who the address belongs to')));
    for I := 0 to Lookups.length - 1 do
    begin
      A2 := C.link(string(TJSArray(Lookups[I])[1]) + C.enc(R['ip']), '', TJSArray(Lookups[I])[0]);
      A2.target := '_blank';
      TJSObject(A2)['rel'] := 'noopener noreferrer';
      TJSObject(A2)['title'] := TJSArray(Lookups[I])[2];
      Look.appendChild(A2);
    end;
    Head.appendChild(Look);
    if Truthy(A['crawler']) then
    begin
      CrawlerText := string(A['crawler']);
      if Truthy(A['company']) then CrawlerText := CrawlerText + ' · ' + string(A['company']);
    end
    else if Truthy(G) and Truthy(G['crawler_name']) then
    begin
      CrawlerText := string(G['crawler_name']);
      if Truthy(G['company']) then CrawlerText := CrawlerText + ' · ' + string(G['company']);
    end
    else if Truthy(G) and Truthy(G['crawler']) then CrawlerText := T('a search engine’s crawler')
    else CrawlerText := '';
    if CrawlerText <> '' then Head.appendChild(C.chip(CrawlerText, 'admin'))
    else if Truthy(A['bot']) then Head.appendChild(C.chip(A['bot'], ''));
    if Truthy(G) and Truthy(G['local']) then Head.appendChild(C.chip(T('This network'), 'admin'))
    else if Truthy(G) and Truthy(G['allowed']) then Head.appendChild(C.chip(T('Allowed'), 'admin'));
    if Truthy(G) and Truthy(G['block']) and Truthy(TJSObject(G['block'])['active']) then
    begin
      if Truthy(TJSObject(G['block'])['for_good']) then Head.appendChild(C.chip(T('Blocked for good'), 'bad'))
      else Head.appendChild(C.chip(T('Blocked now'), 'bad'));
    end;
    if Num(A['score']) > 0 then Head.appendChild(C.chip(T('Of concern'), 'open'));
    Holder.appendChild(Head);
    if not Truthy(A['requests']) then
    begin
      if Truthy(S['adminCan']) and S.adminCan('view-visitors') then Holder.appendChild(C.el('p', 'dim', T('Nothing from this address in the period.')))
      else Holder.appendChild(C.el('p', 'dim', T('The log is for those who may view visitors.')));
    end
    else
    begin
      Tiles := C.el('div', 'tiles-admin');
      Stat(Tiles, A['requests'], T('Requests'), T('%s to %s', Stamp(A['first']), Stamp(A['last'])), undefined);
      Stat(Tiles, A['pages'], T('Pages'), undefined, undefined);
      if Truthy(A['polls']) then Stat(Tiles, A['polls'], T('Open tab checks'), T('a tab left open, asking what is new'), undefined);
      if Truthy(A['peak_at']) then Note := Stamp(A['peak_at']) else Note := '';
      Stat(Tiles, A['peak'], T('Busiest minute'), Note, Mark((Num(A['peak']) >= 120) and not Truthy(A['crawler'])));
      Stat(Tiles, A['agents'], T('Browser strings'), '', Mark((Num(A['agents']) >= 5) and not Truthy(A['crawler'])));
      if Truthy(A['probes']) then Note := TN(A['probes'], '%d scanner path', '%d scanner paths') else Note := '';
      Stat(Tiles, A['missing'], T('Not here (404)'), Note, Mark((Num(A['missing']) >= 30) or Truthy(A['probes'])));
      if Truthy(A['errors']) then Note := TN(A['errors'], '%d server error', '%d server errors') else Note := '';
      Stat(Tiles, A['refused'], T('Turned away'), Note, Mark(Num(A['refused']) >= 20));
      Holder.appendChild(Tiles);
    end;
    if Truthy(A['reasons']) and Truthy(TJSArray(A['reasons']).length) then
    begin
      P := C.el('p', 'lv-reasons');
      for I := 0 to TJSArray(A['reasons']).length - 1 do P.appendChild(C.chip(ReasonWords(TJSObject(TJSArray(A['reasons'])[I])), 'open'));
      Holder.appendChild(P);
    end;
    // the guard's facts, and what an admin may do about the address
    List := C.el('ul', 'block-facts');
    if not Truthy(G) then List.appendChild(C.el('li', 'dim', T('The guard’s facts could not be read.')))
    else
    begin
      Kinds2 := StrikeKinds;
      if Truthy(G['local']) then List.appendChild(C.el('li', 'good', T('This network: never blocked or limited.')))
      else if Truthy(G['allowed']) then List.appendChild(C.el('li', 'good', T('On the allowed list (Settings, allowed_ips): never blocked or limited.')));
      if Truthy(G['crawler']) then
        List.appendChild(C.el('li', 'good', T('A published crawler, by the addresses its company publishes or its name pointing back to the address: never limited or blocked by the guard.')));
      X := TJSObject(G['block']);
      if Truthy(X) and Truthy(X['active']) then
      begin
        if Truthy(X['for_good']) then List.appendChild(C.el('li', 'bad', T('Blocked for good: %s (%s).', X['reason'], DateTimeText(X['when']))))
        else List.appendChild(C.el('li', 'bad', T('Blocked until %s: %s. Blocked %d times so far.', DateTimeText(X['until']), X['reason'], X['times'])));
      end
      else if Truthy(X) then
        List.appendChild(C.el('li', '', T('Not blocked now. Last block: %s, over since %s; blocked %d times so far.', X['reason'], DateTimeText(X['until']), X['times'])))
      else
        List.appendChild(C.el('li', '', T('Not blocked, and never has been.')));
      // what AbuseIPDB said when the site looked it up (unit SiteAbuse)
      if Truthy(G['abuse']) then
      begin
        Ab := TJSObject(G['abuse']);
        Words := T('AbuseIPDB: %d%% confidence of abuse, %s from other sites (looked up %s).', Ab['score'],
          TN(Ab['reports'], '%d report', '%d reports'), DateTimeText(Ab['checked']));
        if Truthy(Ab['usage']) or Truthy(Ab['isp']) then
        begin
          Names := TJSArray.new;
          if Truthy(Ab['usage']) then Names.push(Ab['usage']);
          if Truthy(Ab['isp']) then Names.push(Ab['isp']);
          if Truthy(Ab['country']) then Names.push(Ab['country']);
          Words := Words + ' ' + Names.join(', ') + '.';
        end;
        if Truthy(Ab['reported']) then Words := Words + ' ' + T('We reported it %s.', DateTimeText(Ab['reported']));
        if Num(Ab['score']) >= 75 then Cls := 'bad' else Cls := '';
        List.appendChild(C.el('li', Cls, Words));
      end;
      if Truthy(G['strikes']) and Truthy(TJSArray(G['strikes']).length) then
      begin
        Li := C.el('li', '', T('In the last day:') + ' ');
        Strikes := TJSArray.new;
        for I := 0 to TJSArray(G['strikes']).length - 1 do
        begin
          X := TJSObject(TJSArray(G['strikes'])[I]);
          Strikes.push(string(Either(Kinds2[string(X['kind'])], X['kind'])) + ' × ' + string(X['count']));
        end;
        Li.appendChild(C.el('span', '', Strikes.join(', ')));
        List.appendChild(Li);
      end
      else
        List.appendChild(C.el('li', 'dim', T('Nothing counted against it in the last day.')));
    end;
    Holder.appendChild(List);
    Acts := C.el('div', 'lv-actions');
    if Truthy(G) then Note := G['block'] else Note := G;
    BlockButtons(Acts, R['ip'], TJSObject(Note), @Again, CrawlerText);
    if Acts.childNodes.length > 0 then Holder.appendChild(Acts);
    if not Truthy(A['requests']) then Exit;
    TimelineChart(Holder, TJSObject(R['timeline']), True);
    Two := C.el('div', 'visit-two');
    Left := C.el('div');
    Right := C.el('div');
    TKit(Two).add(Left, Right);
    Holder.appendChild(Two);
    if Num(R['paths_count']) > TJSArray(R['paths']).length then
      Left.appendChild(C.el('h3', '', T('What it asked for most (%s paths in all)', LocaleNumber(R['paths_count']))))
    else Left.appendChild(C.el('h3', '', T('What it asked for')));
    Shown := TJSArray(R['paths']).slice(0, 14);
    Rows := TJSArray.new;
    for I := 0 to Shown.length - 1 do
    begin
      X := TJSObject(Shown[I]);
      Note := X['path'];
      try
        Note := decodeURIComponent(string(Note));
      except
      end;
      Rows.push(new(['name', Either(Note, '/'), 'value', X['count']]));
    end;
    Bars(Left, Rows, @Requests);
    Right.appendChild(C.el('h3', '', T('How it was answered')));
    Codes := KeysByCount(TJSObject(Either(R['statuses'], TJSObject.new)));
    Rows := TJSArray.new;
    for I := 0 to Codes.length - 1 do
    begin
      Code := string(Codes[I]);
      if Code = '0' then Note := T('before the codes were logged') else Note := Code;
      Rows.push(new(['name', Note, 'value', TJSObject(R['statuses'])[Code], 'other', (Code = '0') or (Code < '400')]));
    end;
    Bars(Right, Rows, @Requests);
    Right.appendChild(C.el('h3', '', T('Parts of the site')));
    Parts := KeysByCount(TJSObject(Either(R['parts'], TJSObject.new)));
    Rows := TJSArray.new;
    for I := 0 to Parts.length - 1 do Rows.push(new(['name', PartLabel(Parts[I]), 'value', TJSObject(R['parts'])[string(Parts[I])]]));
    Bars(Right, Rows, @Requests);
    if Truthy(R['referers']) and Truthy(TJSArray(R['referers']).length) then
    begin
      Right.appendChild(C.el('h3', '', T('Came by links from')));
      Shown := TJSArray(R['referers']).slice(0, 8);
      Rows := TJSArray.new;
      for I := 0 to Shown.length - 1 do Rows.push(new(['name', TJSObject(Shown[I])['host'], 'value', TJSObject(Shown[I])['requests']]));
      Bars(Right, Rows, @Requests);
    end;
    Holder.appendChild(C.el('h3', '', T('Browser strings it used')));
    ListView(Holder, TListOptions(new([
      'id', 'v-addr-agents', 'key', TRowValue(function(Row: TJSObject): JSValue begin Result := Row['agent']; end),
      'sort', '-requests', 'search', False, 'rows', R['agents'],
      'columns', Items(
        new(['key', 'browser', 'title', T('Browser or bot'), 'value', TRowValue(@AgentName),
          'cell', TRowValue(function(Row: TJSObject): JSValue
            var
              Span: TJSHTMLElement;
            begin
              Span := C.el('span', '', AgentName(Row));
              if Truthy(Row['claims']) and not Truthy(A['crawler']) then TKit(Span).add(' ', C.chip(T('claims %s', Row['claims']), 'bad'));
              Result := Span;
            end)]),
        new(['key', 'requests', 'title', T('Requests'), 'num', True]),
        new(['key', 'last', 'title', T('Last seen'), 'down', True, 'cell', TRowValue(function(Row: TJSObject): JSValue begin Result := Stamp(Row['last']); end)]),
        new(['key', 'agent', 'title', T('The whole string'), 'wide', True, 'cls', 'lv-text'])),
      'noun', TCountText(function(N: JSValue): JSValue begin Result := TN(N, '%d browser string', '%d browser strings'); end)])));
    if Truthy(R['members']) and Truthy(TJSArray(R['members']).length) then
    begin
      Holder.appendChild(C.el('h3', '', T('Signed in from it as')));
      Ul := C.el('ul', 'lv-paths');
      for I := 0 to TJSArray(R['members']).length - 1 do
      begin
        M := TJSObject(TJSArray(R['members'])[I]);
        Li := C.el('li');
        TKit(Li).add(C.link('/u/' + C.enc(M['name']), '', M['name']), ' ',
          C.el('span', 'dim', TN(M['requests'], '%d request', '%d requests') + ', ' + string(Stamp(M['last']))));
        Ul.appendChild(Li);
      end;
      Holder.appendChild(Ul);
    end;
    Holder.appendChild(C.el('h3', '', T('Its last requests in the period')));
    ListView(Holder, TListOptions(new([
      'id', 'v-addr-trail', 'key', TRowValue(function(L: TJSObject): JSValue begin Result := string(L['at']) + string(L['path']); end),
      'sort', '-at', 'search', T('Filter its requests'), 'page', 100, 'rows', R['trail'],
      'csv', 'address-' + TJSString(R['ip']).replace(TJSRegExp.new('[^0-9a-z]', 'gi'), '_'),
      'columns', Items(
        new(['key', 'at', 'title', T('When'), 'down', True, 'cell', TRowValue(function(L: TJSObject): JSValue begin Result := Stamp(L['at']); end)]),
        new(['key', 'method', 'title', T('Method'), 'wide', True]),
        new(['key', 'path', 'title', T('Page'), 'cell', TRowValue(function(L: TJSObject): JSValue begin Result := PageLink(L['path']); end)]),
        new(['key', 'status', 'title', T('Status'), 'num', True, 'cell', TRowValue(function(L: TJSObject): JSValue begin Result := StatusCell(L['status']); end)]),
        new(['key', 'ms', 'title', T('Took'), 'num', True, 'wide', True, 'cell', TRowValue(function(L: TJSObject): JSValue begin Result := MsCell(L['ms']); end)]),
        new(['key', 'member', 'title', T('Member'), 'wide', True, 'cell', TRowValue(function(L: TJSObject): JSValue
          begin
            if Truthy(L['member']) then Result := C.link('/u/' + C.enc(L['member']), '', L['member']) else Result := '';
          end)]),
        new(['key', 'browser', 'title', T('Browser'), 'wide', True, 'value', TRowValue(function(L: TJSObject): JSValue begin Result := BrowserOf(L['agent']); end)])),
      'filters', Items(new(['key', 'kind', 'title', T('Which'), 'all', T('Every request'),
        'options', Items(Items('pages', T('Pages')), Items('other', T('Everything else')), Items('errors', T('Errors and refusals'))),
        'test', TRowTest(function(L: TJSObject; K: string): JSValue
          begin
            if K = 'errors' then Result := Num(L['status']) >= 400
            else if Same(L['method'], 'GET') and IsPagePath(L['path']) then Result := K = 'pages'
            else Result := K = 'other';
          end)])),
      'noun', TCountText(@Requests)])));
  end;

  procedure Read; async;
  var
    R, G: TJSObject;
    Why: string;
    Message: JSValue;
  begin
    try
      try
        R := await(TJSObject, C.get('/api/admin/visitors/address?ip=' + C.enc(Ip) + '&from=' + C.enc(Win['from']) + '&to=' + C.enc(Win['to'])));
      except
        // an admin who manages blocks but may not see visitors still gets the guard's facts
        if not Truthy(S['adminCan']) or S.adminCan('view-visitors') or not S.adminCan('manage-blocks') then raise;
        G := await(TJSObject, C.get('/api/blocks/why?ip=' + C.enc(Ip)));
        R := new(['ip', G['ip'], 'address', new(['requests', 0, 'reasons', TJSArray.new]), 'guard', G]);
      end;
      Draw(R);
    except
      Why := '';
      if Truthy(JSExceptValue) then
      begin
        Message := TJSObject(JSExceptValue)['message'];
        if Truthy(Message) and (TJSString(Message).length < 300) and not Regex('[<>]', Message) then Why := ' ' + string(Message);
      end;
      TKit(Holder).fill(C.el('p', 'notice', T('The address could not be looked up.') + Why));
    end;
  end;

begin
  // period: the window, or a function giving the window shown now (a
  // button pressed after the picker changed asks for the new one)
  if jsTypeOf(Period) = 'function' then Win := TPeriod(Period)() else Win := TJSObject(Period);
  C.waiting(Holder, T('Reading the log…'));
  Read;
end;

end.
