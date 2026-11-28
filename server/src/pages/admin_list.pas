unit Admin_List;

{ What the admin page's tabs share: the shell's names, tables, tiles, bars, the list view
  and the small pieces the visitors' lists are drawn with. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web;

type
  // Tabs inside a tab, as the shell's subTabs gives them.
  TSubTabs = class external name 'Object'(TJSObject)
    function holder(const Key: string): TJSHTMLElement;
    procedure select(const Key: string);
    procedure count(const Key: string; N: JSValue);
  end;

  // What a list view gives back.
  TListView = class external name 'Object'(TJSObject)
    element: TJSHTMLElement;
    procedure set_(Rows: JSValue); external name 'set';
    function reload: TJSPromise;
    procedure loading;
    procedure failed(Words: JSValue);
    procedure changed(R: JSValue);
    function pick(Match: JSValue): boolean;
    procedure show(R: JSValue);
    procedure unpick;
    procedure search(const Words: string);
    function rows: TJSArray;
  end;

  // The functions among a list view's options, called as its maker wrote them.
  TListColumn = class external name 'Object'(TJSObject)
    function value(R: JSValue): JSValue;
    function cell(R: JSValue): JSValue;
  end;
  TListFilter = class external name 'Object'(TJSObject)
    function test(R, V: JSValue): JSValue;
    function options(Rows: TJSArray): TJSArray;
  end;
  TListOptions = class external name 'Object'(TJSObject)
    function remote(State: TJSObject): TJSPromise;
    procedure enter(const Words: string);
    function rowClass(R: JSValue): JSValue;
    function noun(N: JSValue): JSValue;
    procedure detail(R: JSValue; Holder: TJSHTMLElement; View: TListView);
  end;

  // The site's shell (window.Chat, also window.Site), as far as the admin page uses it.
  TShell = class external name 'Object'(TJSObject)
    function find(const Selector: string): TJSHTMLElement; overload; external name '$';
    function find(const Selector: string; Root: JSValue): TJSHTMLElement; overload; external name '$';
    function el(const Tag: string): TJSHTMLElement; overload;
    function el(const Tag: string; Cls: JSValue): TJSHTMLElement; overload;
    function el(const Tag: string; Cls, Text: JSValue): TJSHTMLElement; overload;
    function link(Href, Cls, Text: JSValue): TJSHTMLAnchorElement;
    function get(const Url: string): TJSPromise;
    function post(const Url: string; Data: JSValue): TJSPromise;
    function enc(V: JSValue): string;
    procedure toast(Text: JSValue); overload;
    procedure toast(Text, Kind: JSValue); overload;
    procedure failed(Err: JSValue);
    function route(const Path: string; Push: JSValue): TJSPromise;
    function ago(Iso: JSValue): string;
    function subTabs(Box: TJSHTMLElement; const Id: string; List: TJSArray): TSubTabs;
    function facts(Holder: TJSHTMLElement; Pairs: TJSArray): TJSHTMLElement;
    function chip(Text: JSValue): TJSHTMLElement; overload;
    function chip(Text, Cls: JSValue): TJSHTMLElement; overload;
    function waiting(Holder: TJSHTMLElement): TJSHTMLElement; overload;
    function waiting(Holder: TJSHTMLElement; Words: JSValue): TJSHTMLElement; overload;
    function iconButton(Name, Title, Cls: JSValue): TJSHTMLElement;
    function sizeText(N: JSValue): string;
    procedure syncNow(WithRooms: JSValue);
    procedure toggleMenu;
    function clock(At: JSValue): JSValue;
    function shared(const Key: string): string; overload;
    function shared(const Key: string; Value: JSValue): string; overload;
    function loadScript(Src: JSValue): TJSPromise;
  end;

  // What the admin page leaves in the shell's state for its tabs.
  TAdminState = class external name 'Object'(TJSObject)
    function adminCan(const P: string): boolean;
    function adminTab(const Title: string): boolean;
    procedure adminCount(const Title: string; N: JSValue);
    procedure showAddress(Ip: JSValue);
    procedure blocksChanged;
  end;

  // Browser calls the Web unit lacks or types too narrowly, each the browser's own.
  TKit = class external name 'HTMLElement'(TJSHTMLElement)
    procedure add; varargs; external name 'append';
    procedure fill; varargs; external name 'replaceChildren';
    procedure putAfter; varargs; external name 'after';
    procedure swapFor; varargs; external name 'replaceWith';
    procedure scrollTo(Options: TJSObject); external name 'scrollIntoView';
  end;
  TAny = class external name 'Object'(TJSObject)
    function toLocaleString(Locales: JSValue): string;
    function localeCompare(const Other: string; Locales: JSValue; Options: TJSObject): double;
    function toggle(const Name: string; Force: boolean): boolean;
    function toFixed(Digits: NativeInt): string;
    function find(Test: JSValue): JSValue;
    function sort(Compare: JSValue): TJSArray;
  end;
  // new Blob(parts, options) with the options as an object.
  TBlob = class external name 'Blob'(TJSBlob)
    constructor new(Parts: TJSArray; Options: TJSObject); overload;
  end;
  // new Date(value) for a value of any kind.
  TDate = class external name 'Date'(TJSDate)
    constructor new(Value: JSValue); overload;
  end;

  TFormat = reference to function(N: JSValue): JSValue;
  TCan = reference to function(const P: string): boolean;
  TOnly = reference to function(Group: JSValue): boolean;
  TRowValue = reference to function(R: TJSObject): JSValue;
  TRowTest = reference to function(R: TJSObject; V: string): JSValue;
  TRowsValue = reference to function(Rows: TJSArray): JSValue;
  TCountText = reference to function(N: JSValue): JSValue;
  TRowDetail = reference to procedure(R: TJSObject; Holder: TJSHTMLElement; View: TListView);

var
  // The shell and what the script takes from it when it is loaded.
  C: TShell;
  Me, Extras: TJSObject;
  S: TAdminState;
  Stream: TJSHTMLElement;
  Locale, SiteName: JSValue;
  // addresses the server's units named as files, from /api/admin
  FilePaths: TJSArray;

function T(English: JSValue): string; varargs; external name 'window.t';
function TN(N: JSValue; const One, Many: string): string; varargs; external name 'window.tn';
function DateText(Value: JSValue): string; external name 'window.dateText';
function DateTimeText(Value: JSValue): string; external name 'window.dateTimeText';
function Truthy(Value: JSValue): boolean; external name 'Boolean';
function Str(Value: JSValue): string; external name 'String';
function Num(Value: JSValue): double; external name 'Number';
function Items: TJSArray; varargs; external name 'Array.of';
function NotANumber(Value: JSValue): boolean; external name 'isNaN';
function MathMax(A: double): double; varargs; external name 'Math.max';
function MathMaxOf(This: JSValue; Values: TJSArray): double; external name 'Math.max.apply';
function MathMin(A: double): double; varargs; external name 'Math.min';
function MathRound(A: double): double; external name 'Math.round';
function MathFloor(A: double): double; external name 'Math.floor';
function MathLog(A: double): double; external name 'Math.log';

function Same(A, B: JSValue): boolean;
function IsUndef(V: JSValue): boolean;
function Either(A, B: JSValue): JSValue;
function LocaleNumber(V: JSValue): string;
function Fixed(V: JSValue; Digits: NativeInt): string;
function Toggle(Node: TJSElement; const Name: string; Force: boolean): boolean;
function FindIn(List: TJSArray; Test: JSValue): JSValue;
function SortBy(List: TJSArray; Compare: JSValue): TJSArray;
function Regex(const Pattern: string; Value: JSValue): boolean;
function MostOf(Values: TJSArray): double;

procedure AdminTable(Box: TJSHTMLElement; Headings, Rows: TJSArray);
function Stat(Holder: TJSHTMLElement; Value, Caption, Note, Cls: JSValue): TJSHTMLElement;
procedure Bars(Holder: TJSHTMLElement; Rows: TJSArray; Format: TFormat);
function BrowserOf(Agent: JSValue): JSValue;
function HostOf(Url: JSValue): string;
function IsPagePath(Path: JSValue): boolean;
function PageLink(Path: JSValue): TJSHTMLElement;
function ListView(Box: TJSHTMLElement; O: TListOptions): TListView;
function StrikeKinds: TJSObject;
function SectionOf(Path: JSValue): string;
function SectionOptions(Paths: TJSArray): TJSArray;
procedure LookUpAddress(Ip: JSValue);
function AddressCell(Ip: JSValue): TJSHTMLElement; overload;
function AddressCell(Ip, Flagged: JSValue): TJSHTMLElement; overload;
function Stamp(At: JSValue): JSValue;
function OutLink(Url: JSValue): TJSHTMLElement;
function LookButton(Ip: JSValue): TJSHTMLElement;
function ReasonWords(X: TJSObject): JSValue;
function ReasonKinds: TJSObject;
function StatusCell(Code: JSValue): TJSHTMLElement;
function MsCell(Ms: JSValue): JSValue;
function PartLabel(Part: JSValue): JSValue;
function PlaceName(Where: JSValue): JSValue;
function WindowName(R: TJSObject): string;

implementation

// a === b
function Same(A, B: JSValue): boolean;
begin
  Result := (jsTypeOf(A) = jsTypeOf(B)) and (A = B);
end;

function IsUndef(V: JSValue): boolean;
begin
  Result := jsTypeOf(V) = 'undefined';
end;

// a || b
function Either(A, B: JSValue): JSValue;
begin
  if Truthy(A) then Result := A else Result := B;
end;

function LocaleNumber(V: JSValue): string;
begin
  Result := TAny(V).toLocaleString(Locale);
end;

function Fixed(V: JSValue; Digits: NativeInt): string;
begin
  Result := TAny(V).toFixed(Digits);
end;

// classList.toggle(name, force)
function Toggle(Node: TJSElement; const Name: string; Force: boolean): boolean;
begin
  Result := TAny(JSValue(Node.classList)).toggle(Name, Force);
end;

function FindIn(List: TJSArray; Test: JSValue): JSValue;
begin
  Result := TAny(JSValue(List)).find(Test);
end;

function SortBy(List: TJSArray; Compare: JSValue): TJSArray;
begin
  Result := TAny(JSValue(List)).sort(Compare);
end;

function Regex(const Pattern: string; Value: JSValue): boolean;
begin
  Result := TJSRegExp.new(Pattern).test(Str(Value));
end;

// the largest of the values, and at least one
function MostOf(Values: TJSArray): double;
begin
  Result := MathMaxOf(nil, Values.concat(Items(1)));
end;

// ------------------------------------------------------------------ admin

procedure AdminTable(Box: TJSHTMLElement; Headings, Rows: TJSArray);
var
  Wrap, Table, Head, Row, Cell: TJSHTMLElement;
  Values: TJSArray;
  Value: JSValue;
  I, J: NativeInt;
begin
  Wrap := C.el('div', 'gridwrap');
  Table := C.el('table', 'grid');
  Head := C.el('tr');
  for I := 0 to Headings.length - 1 do Head.appendChild(C.el('th', '', Headings[I]));
  Table.appendChild(Head);
  for I := 0 to Rows.length - 1 do
  begin
    Row := C.el('tr');
    Values := TJSArray(Rows[I]);
    for J := 0 to Values.length - 1 do
    begin
      // a cell is words, or something already built (a link, a chip)
      Value := Values[J];
      Cell := C.el('td');
      if jsTypeOf(Value) = 'object' then Cell.appendChild(TJSNode(Value))
      else Cell.textContent := Str(Value);
      Row.appendChild(Cell);
    end;
    Table.appendChild(Row);
  end;
  Wrap.appendChild(Table);
  Box.appendChild(Wrap);
end;

// a number as a tile: the figure, its caption, a small note under it
function Stat(Holder: TJSHTMLElement; Value, Caption, Note, Cls: JSValue): TJSHTMLElement;
var
  Box: TJSHTMLElement;
begin
  if Truthy(Cls) then Box := C.el('div', 'stat ' + string(Cls)) else Box := C.el('div', 'stat');
  if jsTypeOf(Value) = 'number' then Box.appendChild(C.el('b', '', LocaleNumber(Value)))
  else Box.appendChild(C.el('b', '', Value));
  Box.appendChild(C.el('span', '', Caption));
  if Truthy(Note) then Box.appendChild(C.el('small', '', Note));
  Holder.appendChild(Box);
  Result := Box;
end;

// sizes or counts as plain bars, the longest filling the row
procedure Bars(Holder: TJSHTMLElement; Rows: TJSArray; Format: TFormat);
var
  Most: double;
  Grid, Bar, Fill: TJSHTMLElement;
  Values: TJSArray;
  R: TJSObject;
  I: NativeInt;
begin
  Values := TJSArray.new;
  for I := 0 to Rows.length - 1 do Values.push(TJSObject(Rows[I])['value']);
  Most := MostOf(Values);
  Grid := C.el('div', 'bars');
  for I := 0 to Rows.length - 1 do
  begin
    R := TJSObject(Rows[I]);
    Grid.appendChild(C.el('span', 'name', R['name']));
    if Truthy(R['other']) then Bar := C.el('span', 'bar other') else Bar := C.el('span', 'bar');
    Fill := C.el('i');
    TJSObject(Fill.style)['width'] := Str(MathMax(1, MathRound(100 * Num(R['value']) / Most))) + '%';
    Bar.appendChild(Fill);
    Bar.title := string(R['name']) + ': ' + string(Format(R['value']));
    Grid.appendChild(Bar);
    Grid.appendChild(C.el('span', 'num', Format(R['value'])));
  end;
  Holder.appendChild(Grid);
end;

// a browser string in a few words: "Firefox on Linux"
function BrowserOf(Agent: JSValue): JSValue;
var
  A, Name, System: string;
begin
  A := string(Either(Agent, ''));
  if Regex('Edg\/', A) then Name := 'Edge' else if Regex('OPR\/|Opera', A) then Name := 'Opera'
  else if Regex('SamsungBrowser', A) then Name := 'Samsung Internet' else if Regex('Firefox\/', A) then Name := 'Firefox'
  else if Regex('Chrome\/', A) then Name := 'Chrome' else if Regex('Version\/[\d.]+.*Safari', A) then Name := 'Safari' else Name := '';
  if Regex('Android', A) then System := 'Android' else if Regex('iPhone|iPad|iPod', A) then System := 'iOS'
  else if Regex('Windows', A) then System := 'Windows' else if Regex('Mac OS X|Macintosh', A) then System := 'macOS'
  else if Regex('CrOS', A) then System := 'ChromeOS' else if Regex('Linux|X11', A) then System := 'Linux' else System := '';
  if (Name <> '') and (System <> '') then Exit(T('%s on %s', Name, System));
  if Name <> '' then Result := Name else if System <> '' then Result := System else Result := TJSString(A).slice(0, 32);
end;

function HostOf(Url: JSValue): string;
begin
  try
    Result := TJSString(TJSURL.new(Str(Url)).hostname).replace(TJSRegExp.new('^www\.'), '');
  except
    Result := '';
  end;
end;

// a page someone reads: not a picture, script, style, API call or feed (as the report has it)
function IsPagePath(Path: JSValue): boolean;
var
  P: string;
  I: NativeInt;
begin
  P := TJSString(TJSString(string(Either(Path, '/'))).toLowerCase).split('?')[0];
  if Regex('^\/(static|api|images|files|f\/|avatar|ws|sitemap|favicon|manifest)', P) or
    (P = '/robots.txt') or (P = '/words.js') or (P = '/sw.js') then Exit(False);
  for I := 0 to FilePaths.length - 1 do
    if TJSString(P).startsWith(string(FilePaths[I])) then Exit(False);
  Result := not Regex('\.(css|js|png|jpe?g|gif|svg|ico|webp|woff2?|xml|txt|json|map)$', P);
end;

function PageLink(Path: JSValue): TJSHTMLElement;
var
  Shown: JSValue;
begin
  Path := Either(Path, '/');
  Shown := Path;
  try
    Shown := decodeURIComponent(string(Path));
  except
  end;
  // a link only for a path of this site: one slash, not two (which would name another host)
  if not Regex('^\/(?!\/)', Path) then Exit(C.el('span', 'visit-path', Shown));
  Result := C.el('a', 'visit-path', Shown);
  TJSObject(Result)['href'] := Path;
  TJSObject(Result)['target'] := '_blank';
  TJSObject(Result)['rel'] := 'noopener';
  TJSObject(Result)['title'] := Path;
end;

// ------------------------------------------------------------ list views

// Searchable, sortable lists with keyboard selection and a detail panel.
// Rows may be local or fetched a page at a time; set() replaces them and
// failed(words) reports a load failure. The listView options are in
// docs/CODE-MAP.md.
function ListView(Box: TJSHTMLElement; O: TListOptions): TListView;
type
  TRowText = reference to function(R: JSValue): JSValue;
var
  View, Bar, Scroller, Table, Thead, Tbody, Foot, Count, More, Detail, Head: TJSHTMLElement;
  Find: TJSHTMLInputElement;
  KeyOf, TextOf: TRowText;
  Step, Limit, Page, Asked: double;
  Total, Picked, Trouble: JSValue;
  Rows, Shown, Selects, Ths, Columns, Given: TJSArray;
  Q, Sort: string;
  Loading: boolean;
  Filters, Saved: TJSObject;
  Timer: NativeInt;
  Api: TListView;
  I: NativeInt;

  function Refresh: JSValue; async; forward;
  procedure Unpick; forward;
  procedure Pick(R: JSValue; Tr: TJSHTMLElement; KeepFocus: boolean = False); forward;
  procedure ShowDetail; forward;

  function ValueOf(Col: TListColumn; R: JSValue): JSValue;
  begin
    if Truthy(Col['value']) then Result := Col.value(R) else Result := TJSObject(R)[string(Col['key'])];
    if IsUndef(Result) or (Result = nil) then Result := '';
  end;

  function PlainSort: string;
  begin
    Result := TJSString(Sort).replace(TJSRegExp.new('^-'), '');
  end;

  procedure Save;
  begin
    // the sort is kept; a filter is not, so a list never opens narrowed by an old choice
    if Truthy(O['id']) then
      try
        window.localStorage.setItem('lv-' + string(O['id']), TJSJSON.stringify(new(['sort', Sort])));
      except
      end;
  end;

  procedure AddFind;
  begin
    Find := TJSHTMLInputElement(C.el('input', 'lv-find'));
    Find._type := 'search';
    Find.placeholder := string(Either(O['search'], T('Search')));
    Find.setAttribute('aria-label', Find.placeholder);
    Find.addEventListener('input', TJSRawEventHandler(procedure(E: TJSEvent)
      var
        Wait: NativeInt;
      begin
        window.clearTimeout(Timer);
        if Truthy(O['remote']) then Wait := 250 else Wait := 60;
        Timer := window.setTimeout(procedure begin Q := TJSString(Find.value).trim; Refresh; end, Wait);
      end));
    Find.addEventListener('keydown', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        if TJSKeyboardEvent(E).key = 'Enter' then
        begin
          E.preventDefault;
          if Truthy(O['enter']) then O.enter(TJSString(Find.value).trim);
        end
        else if (TJSKeyboardEvent(E).key = 'ArrowDown') and Truthy(Tbody.firstChild) and Same(TJSObject(Tbody.firstChild)['tabIndex'], 0) then
        begin
          E.preventDefault;
          TJSHTMLElement(Tbody.firstChild).focus;
        end;
      end));
    Bar.appendChild(Find);
  end;

  procedure AddFilter(F: TListFilter);
  var
    Choice: TJSHTMLSelectElement;
  begin
    Choice := TJSHTMLSelectElement(C.el('select', 'lv-filter'));
    Choice.setAttribute('aria-label', string(F['title']));
    Choice.title := string(F['title']);
    Filters[string(F['key'])] := Either(F['value'], '');
    Choice.addEventListener('change', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        Filters[string(F['key'])] := Choice.value;
        Toggle(Choice, 'on', Choice.value <> '');
        Save;
        Refresh;
      end));
    Bar.appendChild(Choice);
    Selects.push(new(['f', F, 's', Choice]));
  end;

  procedure FillSelects;
  var
    N, M: NativeInt;
    F: TListFilter;
    Choice: TJSHTMLSelectElement;
    Options: TJSArray;
    Want: JSValue;

    function Option(Value, Words: JSValue): TJSHTMLElement;
    begin
      Result := C.el('option', '', Words);
      TJSObject(Result)['value'] := Value;
    end;

  begin
    for N := 0 to Selects.length - 1 do
    begin
      F := TListFilter(TJSObject(Selects[N])['f']);
      Choice := TJSHTMLSelectElement(TJSObject(Selects[N])['s']);
      if jsTypeOf(F['options']) = 'function' then Options := F.options(Rows) else Options := TJSArray(F['options']);
      TKit(JSValue(Choice)).fill(Option('', Either(F['all'], T('All'))));
      for M := 0 to Options.length - 1 do Choice.appendChild(Option(TJSArray(Options[M])[0], TJSArray(Options[M])[1]));
      Want := Either(Filters[string(F['key'])], '');
      TJSObject(Choice)['value'] := Want;
      // a choice these rows do not have shows everything
      if not Same(Choice.value, Want) then Choice.value := '';
      // a filter that narrows the list stands out
      Toggle(Choice, 'on', Choice.value <> '');
    end;
  end;

  procedure AddCsv;
  var
    Csv: TJSHTMLElement;

    function Cell(V: JSValue): string;
    begin
      Result := Str(V);
      // text from visitors that a spreadsheet would run as a formula stays text
      if Regex('^[=+\-@\t\r]', Result) and not Regex('^-?\d+(\.\d+)?$', Result) then Result := '''' + Result;
      if Regex('[",\n]', Result) then Result := '"' + TJSString(Result).replace(TJSRegExp.new('"', 'g'), '""') + '"';
    end;

    function Line(R: JSValue; Titles: boolean): string;
    var
      Cells: TJSArray;
      N: NativeInt;
    begin
      Cells := TJSArray.new;
      Columns := TJSArray(O['columns']);
      for N := 0 to Columns.length - 1 do
        if Titles then Cells.push(Cell(TJSObject(Columns[N])['title'])) else Cells.push(Cell(ValueOf(TListColumn(Columns[N]), R)));
      Result := Cells.join(',');
    end;

  begin
    Csv := C.el('button', 'small-link lv-csv', T('Download CSV'));
    TJSObject(Csv)['type'] := 'button';
    Csv.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      var
        Lines: TJSArray;
        A: TJSHTMLAnchorElement;
        N: NativeInt;
      begin
        Lines := Items(Line(nil, True));
        for N := 0 to Shown.length - 1 do Lines.push(Line(Shown[N], False));
        A := TJSHTMLAnchorElement(C.el('a'));
        A.href := TJSURL.createObjectURL(TBlob.new(Items(Lines.join(#10) + #10), new(['type', 'text/csv'])));
        A.download := string(O['csv']) + '.csv';
        document.body.appendChild(A);
        A.click;
        A.remove;
        window.setTimeout(procedure begin TJSURL.revokeObjectURL(A.href); end, 5000);
      end));
    Bar.appendChild(Csv);
  end;

  // the headings: a click sorts by it, a second click the other way
  procedure AddHeading(Col: TJSObject);
  var
    Th, B: TJSHTMLElement;
    Cls: string;
  begin
    Cls := '';
    if Truthy(Col['num']) then Cls := 'num';
    if Truthy(Col['wide']) then Cls := Cls + ' wide';
    Th := C.el('th', Cls);
    if Truthy(Col['nosort']) then TJSObject(Th)['textContent'] := Col['title']
    else
    begin
      B := C.el('button', 'lv-sort', Col['title']);
      TJSObject(B)['type'] := 'button';
      B.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
        var
          Key: string;
        begin
          Key := string(Col['key']);
          if Same(Sort, Col['key']) then Sort := '-' + Key
          else if Sort = '-' + Key then Sort := Key
          else if Truthy(Col['num']) or Truthy(Col['down']) then Sort := '-' + Key
          else Sort := Key;
          Save;
          Refresh;
        end));
      Th.appendChild(B);
    end;
    Ths.push(Th);
    Head.appendChild(Th);
  end;

  procedure MarkSort;
  var
    N: NativeInt;
    Here, Down: boolean;
    Th: TJSHTMLElement;
  begin
    Columns := TJSArray(O['columns']);
    for N := 0 to Columns.length - 1 do
    begin
      Here := Same(PlainSort, TJSObject(Columns[N])['key']);
      Down := TJSString(Sort).charAt(0) = '-';
      Th := TJSHTMLElement(Ths[N]);
      Toggle(Th, 'sorted', Here);
      Toggle(Th, 'down', Here and Down);
      if Here then
      begin
        if Down then Th.setAttribute('aria-sort', 'descending') else Th.setAttribute('aria-sort', 'ascending');
      end
      else Th.removeAttribute('aria-sort');
    end;
  end;

  function Blank(V: JSValue): boolean;
  begin
    Result := Same(V, '') or (V = nil) or IsUndef(V);
  end;

  function Compare(A, B: JSValue): double;
  begin
    if (jsTypeOf(A) = 'number') and (jsTypeOf(B) = 'number') then Exit(double(A) - double(B));
    if (jsTypeOf(A) = 'boolean') or (jsTypeOf(B) = 'boolean') then Exit(Num(A) - Num(B));
    Result := TAny(JSValue(Str(A))).localeCompare(Str(B), Locale, new(['numeric', True, 'sensitivity', 'base']));
  end;

  procedure Local;
  var
    Words: string;
    List: TJSArray;
    N, M: NativeInt;
    R, V: JSValue;
    Keep: boolean;
    Col: TListColumn;
    Dir: double;
  begin
    Words := TJSString(Q).toLowerCase;
    List := TJSArray.new;
    for N := 0 to Rows.length - 1 do
    begin
      R := Rows[N];
      Keep := True;
      for M := 0 to Selects.length - 1 do
      begin
        V := TJSObject(TJSObject(Selects[M])['s'])['value'];
        if Truthy(V) and not Truthy(TListFilter(TJSObject(Selects[M])['f']).test(R, V)) then
        begin
          Keep := False;
          Break;
        end;
      end;
      if Keep and ((Words = '') or (TJSString(TJSString(TextOf(R)).toLowerCase).indexOf(Words) >= 0)) then List.push(R);
    end;
    Col := nil;
    Columns := TJSArray(O['columns']);
    for N := 0 to Columns.length - 1 do
      if not Truthy(TJSObject(Columns[N])['nosort']) and Same(TJSObject(Columns[N])['key'], PlainSort) then
      begin
        Col := TListColumn(Columns[N]);
        Break;
      end;
    if Col <> nil then
    begin
      if TJSString(Sort).charAt(0) = '-' then Dir := -1 else Dir := 1;
      SortBy(List, function(X, Y: JSValue): double
        var
          A, B: JSValue;
        begin
          A := ValueOf(Col, X);
          B := ValueOf(Col, Y);
          // the empty ones last, whichever way
          if Blank(A) or Blank(B) then Exit(Num(Blank(A)) - Num(Blank(B)));
          Result := Dir * Compare(A, B);
        end);
    end;
    Shown := List;
    Total := Rows.length;
  end;

  function RowOf(R: JSValue): TJSHTMLElement;
  var
    Tr, Td: TJSHTMLElement;
    Col: TListColumn;
    Cls: string;
    V: JSValue;
    N: NativeInt;
  begin
    Tr := C.el('tr');
    TJSObject(Tr)['row'] := R;
    if Truthy(O['rowClass']) then
    begin
      V := O.rowClass(R);
      if Truthy(V) then TJSObject(Tr)['className'] := V;
    end;
    Columns := TJSArray(O['columns']);
    for N := 0 to Columns.length - 1 do
    begin
      Col := TListColumn(Columns[N]);
      Cls := '';
      if Truthy(Col['num']) then Cls := 'num';
      if Truthy(Col['wide']) then Cls := Cls + ' wide';
      if Truthy(Col['cls']) then Cls := Cls + ' ' + string(Col['cls']);
      Td := C.el('td', Cls);
      if Truthy(Col['cell']) then V := Col.cell(R) else V := ValueOf(Col, R);
      if Truthy(V) and (jsTypeOf(V) = 'object') then Td.appendChild(TJSNode(V))
      else if jsTypeOf(V) = 'number' then Td.textContent := LocaleNumber(V)
      else if IsUndef(V) or (V = nil) then Td.textContent := Str('')
      else Td.textContent := Str(V);
      Tr.appendChild(Td);
    end;
    if Truthy(O['detail']) then
    begin
      Tr.tabIndex := 0;
      if Truthy(Picked) and Same(KeyOf(Picked), KeyOf(R)) then Tr.classList.add('on');
      Tr.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
        begin
          if Truthy(TJSElement(E.target).closest('a, button, input, select, label, textarea')) then Exit;
          Pick(R, Tr);
        end));
      Tr.addEventListener('keydown', TJSRawEventHandler(procedure(E: TJSEvent)
        var
          Key: string;
          Goal: TJSElement;
        begin
          Key := TJSKeyboardEvent(E).key;
          if Key = 'ArrowDown' then Goal := Tr.nextElementSibling
          else if Key = 'ArrowUp' then Goal := Tr.previousElementSibling
          else Goal := nil;
          if Truthy(Goal) and Truthy(TJSObject(Goal)['row']) then
          begin
            E.preventDefault;
            TJSHTMLElement(Goal).focus;
            Pick(TJSObject(Goal)['row'], TJSHTMLElement(Goal), True);
          end
          else if (Key = 'ArrowUp') and Truthy(Find) then
          begin
            E.preventDefault;
            Find.focus;
          end
          else if (Key = 'Enter') or (Key = ' ') then
          begin
            E.preventDefault;
            Pick(R, Tr);
          end
          else if Key = 'Escape' then Unpick;
        end));
    end;
    Result := Tr;
  end;

  procedure Draw;
  var
    List: TJSArray;
    Tr, Td: TJSHTMLElement;
    All: JSValue;
    N: NativeInt;
  begin
    Tbody.replaceChildren;
    if Truthy(O['remote']) then List := Shown else List := Shown.slice(0, Trunc(Limit));
    for N := 0 to List.length - 1 do Tbody.appendChild(RowOf(List[N]));
    Toggle(View, 'lv-busy', Loading and (List.length > 0));
    Columns := TJSArray(O['columns']);
    if (List.length = 0) and (Loading or Truthy(Trouble)) then
    begin
      if Truthy(Trouble) then Tr := C.el('tr', 'lv-none lv-trouble') else Tr := C.el('tr', 'lv-none lv-loading');
      Td := C.el('td');
      if Truthy(Trouble) then TJSObject(Td)['textContent'] := Trouble
      else TKit(Td).add(C.el('span', 'lv-spinner'), ' ' + T('Loading…'));
      TJSObject(Td)['colSpan'] := Columns.length;
      Tr.appendChild(Td);
      Tbody.appendChild(Tr);
      Count.textContent := '';
      More.hidden := True;
      Exit;
    end;
    if List.length = 0 then
    begin
      Tr := C.el('tr', 'lv-none');
      if (Rows.length = 0) and not Truthy(O['remote']) then Td := C.el('td', '', Either(O['empty'], T('Nothing here yet.')))
      else Td := C.el('td', '', T('Nothing matches.'));
      TJSObject(Td)['colSpan'] := Columns.length;
      Tr.appendChild(Td);
      Tbody.appendChild(Tr);
    end;
    if Truthy(O['remote']) then All := Total else All := Rows.length;
    if List.length < Num(All) then TJSObject(Count)['textContent'] := T('%d of %d shown', List.length, All)
    else if Truthy(O['noun']) then TJSObject(Count)['textContent'] := O.noun(All)
    else TJSObject(Count)['textContent'] := TN(All, '%d row', '%d rows');
    if Loading then Count.textContent := Count.textContent + ' · ' + T('Loading…');
    if Truthy(O['remote']) then More.hidden := Shown.length >= Num(Total) else More.hidden := Shown.length <= Limit;
  end;

  procedure MoreClick(E: TJSEvent); async;
  var
    Mine, Next: double;
    A: TJSObject;
  begin
    if not Truthy(O['remote']) then
    begin
      Limit := Limit + Step;
      Draw;
      Exit;
    end;
    Mine := Asked;
    Next := Page + 1;
    TJSObject(More)['disabled'] := True;
    More.textContent := T('Loading…');
    try
      try
        A := await(TJSObject, O.remote(new(['q', Q, 'filters', Filters, 'sort', Sort, 'page', Next])));
      except
        C.failed(JSExceptValue);
        Exit;
      end;
    finally
      TJSObject(More)['disabled'] := False;
      More.textContent := T('Show more');
    end;
    // a newer search or filter since: this page is not part of its list
    if Mine <> Asked then Exit;
    Page := Next;
    Shown := Shown.concat(A['rows']);
    Total := A['total'];
    Draw;
  end;

  function FreshOf(K: JSValue): JSValue;
  var
    N: NativeInt;
  begin
    for N := 0 to Rows.length - 1 do
      if Same(KeyOf(Rows[N]), K) then Exit(Rows[N]);
    Result := undefined;
  end;

  function Refresh: JSValue; async;
  var
    Mine: double;
    A: TJSObject;
  begin
    if Truthy(O['remote']) then
    begin
      Page := 0;
      Asked := Asked + 1;
      Mine := Asked;
      // the rows there stay, dimmed, until the new ones come
      Loading := True;
      Trouble := '';
      MarkSort;
      Draw;
      try
        A := await(TJSObject, O.remote(new(['q', Q, 'filters', Filters, 'sort', Sort, 'page', 0])));
      except
        if Mine <> Asked then Exit;
        Loading := False;
        Trouble := Either(TJSObject(JSExceptValue)['message'], T('The list could not be read.'));
        Shown := TJSArray.new;
        Draw;
        Exit;
      end;
      if Mine <> Asked then Exit;
      Loading := False;
      Rows := TJSArray(A['rows']);
      Shown := Rows;
      Total := A['total'];
      // the picked row as the server has it now, its box drawn again
      if Truthy(Picked) then
      begin
        // gone from the list (unhidden while hidden ones show): its box goes too
        Picked := Either(FreshOf(KeyOf(Picked)), nil);
        MarkSort;
        Draw;
        ShowDetail;
        Exit;
      end;
    end
    else
    begin
      Limit := Step;
      Local;
    end;
    MarkSort;
    Draw;
  end;

  procedure ShowDetail;
  var
    Close, Inner: TJSHTMLElement;
  begin
    Detail.replaceChildren;
    if not Truthy(Picked) then
    begin
      Detail.hidden := True;
      Exit;
    end;
    Detail.hidden := False;
    Close := C.el('button', 'lv-close', '×');
    TJSObject(Close)['type'] := 'button';
    Close.title := T('Close');
    Close.setAttribute('aria-label', T('Close'));
    Close.addEventListener('click', TJSRawEventHandler(@Unpick));
    Inner := C.el('div', 'lv-detail-body');
    TKit(Detail).add(Close, Inner);
    O.detail(Picked, Inner, Api);
  end;

  procedure MarkRows(Tr: JSValue; ByKey: boolean; R: JSValue);
  var
    Lines: TJSArray;
    N: NativeInt;
    X: TJSHTMLElement;
  begin
    Lines := TJSArray.from(Tbody.children);
    for N := 0 to Lines.length - 1 do
    begin
      X := TJSHTMLElement(Lines[N]);
      if ByKey then Toggle(X, 'on', Truthy(TJSObject(X)['row']) and Same(KeyOf(TJSObject(X)['row']), KeyOf(R)))
      else Toggle(X, 'on', X = Tr);
    end;
  end;

  procedure Pick(R: JSValue; Tr: TJSHTMLElement; KeepFocus: boolean);
  var
    Top, High: double;
  begin
    Picked := R;
    MarkRows(Tr, False, nil);
    ShowDetail;
    // the box in sight, the list where it was
    if not KeepFocus and Truthy(TJSObject(Detail)['getBoundingClientRect']) then
    begin
      Top := Detail.getBoundingClientRect.top;
      High := double(Either(window.innerHeight, 800));
      if Top > High - 120 then TKit(Detail).scrollTo(new(['block', 'nearest', 'behavior', 'smooth']));
    end;
  end;

  procedure Unpick;
  var
    Lines: TJSArray;
    N: NativeInt;
  begin
    Picked := nil;
    Lines := TJSArray.from(Tbody.children);
    for N := 0 to Lines.length - 1 do TJSHTMLElement(Lines[N]).classList.remove('on');
    ShowDetail;
  end;

  // new rows, the picked one kept when it is still there
  procedure SetRows(List: TJSArray);
  begin
    Rows := List;
    Loading := False;
    Trouble := '';
    if Truthy(Picked) then Picked := Either(FreshOf(KeyOf(Picked)), nil);
    FillSelects;
    Refresh;
    ShowDetail;
  end;

  function Reload: JSValue;
  begin
    Result := Refresh;
  end;

  // the rows are coming again (a list someone else fills), or could not be had
  procedure SetLoading;
  begin
    Loading := True;
    Trouble := '';
    Draw;
  end;

  procedure SetFailed(Words: JSValue);
  begin
    Loading := False;
    Trouble := Either(Words, T('The list could not be read.'));
    Rows := TJSArray.new;
    Shown := Rows;
    Draw;
  end;

  // a row changed in place: its line and its box drawn again
  procedure Changed(R: JSValue);
  var
    Lines: TJSArray;
    N: NativeInt;
    Tr, Fresh: TJSHTMLElement;
  begin
    Lines := TJSArray.from(Tbody.children);
    for N := 0 to Lines.length - 1 do
    begin
      Tr := TJSHTMLElement(Lines[N]);
      if Truthy(TJSObject(Tr)['row']) and Same(KeyOf(TJSObject(Tr)['row']), KeyOf(R)) then
      begin
        Fresh := RowOf(R);
        if Tr.classList.contains('on') then Fresh.classList.add('on');
        TKit(Tr).swapFor(Fresh);
      end;
    end;
    if Truthy(Picked) and Same(KeyOf(Picked), KeyOf(R)) then
    begin
      Picked := R;
      ShowDetail;
    end;
  end;

  function PickBy(Match: JSValue): boolean;
  var
    R: JSValue;
  begin
    if Truthy(O['remote']) then R := FindIn(Shown, Match) else R := FindIn(Rows, Match);
    if not Truthy(R) then Exit(False);
    Picked := R;
    Draw;
    ShowDetail;
    Result := True;
  end;

  // a thing that need not be a row, an address looked up, in the box
  procedure Show(R: JSValue);
  begin
    Picked := R;
    MarkRows(nil, True, R);
    ShowDetail;
  end;

  procedure Search(Words: string);
  begin
    if Truthy(Find) then
    begin
      Find.value := Words;
      Q := Words;
      Refresh;
    end;
  end;

  function GiveRows: TJSArray;
  begin
    Result := Rows;
  end;

begin
  if Truthy(O['cls']) then View := C.el('div', 'listview ' + string(O['cls'])) else View := C.el('div', 'listview');
  Bar := C.el('div', 'lv-bar');
  Scroller := C.el('div', 'lv-scroll');
  Table := C.el('table', 'lv-table');
  Thead := C.el('thead');
  Tbody := C.el('tbody');
  TKit(Table).add(Thead, Tbody);
  Scroller.appendChild(Table);
  Foot := C.el('div', 'lv-foot');
  Count := C.el('span', 'lv-count');
  More := C.el('button', 'small-link', T('Show more'));
  TJSObject(More)['type'] := 'button';
  More.hidden := True;
  TKit(Foot).add(Count, More);
  Detail := C.el('div', 'lv-detail');
  Detail.hidden := True;
  TKit(View).add(Bar, Scroller, Foot, Detail);
  Box.appendChild(View);

  if Truthy(O['key']) then KeyOf := TRowText(O['key'])
  else KeyOf := function(R: JSValue): JSValue begin Result := TJSJSON.stringify(R); end;
  if Truthy(O['text']) then TextOf := TRowText(O['text'])
  else TextOf := function(R: JSValue): JSValue
    var
      Words: TJSArray;
      N: NativeInt;
    begin
      Words := TJSArray.new;
      Columns := TJSArray(O['columns']);
      for N := 0 to Columns.length - 1 do Words.push(Str(ValueOf(TListColumn(Columns[N]), R)));
      Result := Words.join(' ');
    end;
  Step := double(Either(O['page'], 100));
  Rows := TJSArray(Either(O['rows'], TJSArray.new));
  Shown := TJSArray.new;
  Total := 0;
  Limit := Step;
  Page := 0;
  Picked := nil;
  Q := '';
  Asked := 0;
  // waiting for the rows: from the server, or from whoever made the list
  Loading := Truthy(O['remote']) or IsUndef(O['rows']);
  Trouble := '';
  Sort := string(Either(O['sort'], ''));
  Filters := TJSObject.new;
  Saved := TJSObject.new;
  try
    if Truthy(O['id']) then Saved := TJSObject(TJSJSON.parse(string(Either(window.localStorage.getItem('lv-' + string(O['id'])), '{}'))));
  except
  end;
  Columns := TJSArray(O['columns']);
  if Truthy(Saved['sort']) then
    for I := 0 to Columns.length - 1 do
      if not Truthy(TJSObject(Columns[I])['nosort']) and
        Same(TJSObject(Columns[I])['key'], TJSString(Saved['sort']).replace(TJSRegExp.new('^-'), '')) then
      begin
        Sort := string(Saved['sort']);
        Break;
      end;

  Find := nil;
  Timer := 0;
  if not Same(O['search'], False) then AddFind;
  Selects := TJSArray.new;
  Given := TJSArray(Either(O['filters'], TJSArray.new));
  for I := 0 to Given.length - 1 do AddFilter(TListFilter(Given[I]));
  if Truthy(O['csv']) then AddCsv;
  if Bar.children.length = 0 then Bar.hidden := True;

  Head := C.el('tr');
  Ths := TJSArray.new;
  for I := 0 to Columns.length - 1 do AddHeading(TJSObject(Columns[I]));
  Thead.appendChild(Head);

  More.addEventListener('click', TJSRawEventHandler(@MoreClick));
  Api := TListView(new([
    'set', @SetRows,
    'reload', @Reload,
    'loading', @SetLoading,
    'failed', @SetFailed,
    'changed', @Changed,
    'pick', @PickBy,
    'show', @Show,
    'unpick', @Unpick,
    'search', @Search,
    'rows', @GiveRows,
    'element', View]));
  FillSelects;
  Refresh;
  Result := Api;
end;

// the guard's names for what it counts against an address
function StrikeKinds: TJSObject;
begin
  Result := TJSObject.assign(new(['g-miss', T('missing pages'), 'g-password', T('wrong passwords or tokens'), 'g-admin', T('admin pages probed'),
    'signin', T('sign-in tries'), 'signup', T('sign-up tries'), 'token', T('token tries'), 'authtry', T('sign-in requests'),
    'wikilist', T('wiki lists'), 'search', T('searches')]), TJSObject(Either(Extras['strikeKinds'], TJSObject.new)));
end;

// the part of the site a path is in, by its first word: /wiki, /forum, /p
function SectionOf(Path: JSValue): string;
var
  First: string;
begin
  First := TJSString(string(Either(TJSString(TJSString(string(Either(Path, '/'))).split('?')[0]).split('/')[1], ''))).split('-')[0];
  if First <> '' then Result := '/' + First else Result := '/';
end;

function ByCount(Seen: TJSMap): TJSArray;
var
  Pairs: TJSArray;
  I: NativeInt;
begin
  Pairs := SortBy(TJSArray.from(Seen), function(A, B: TJSArray): double begin Result := double(B[1]) - double(A[1]); end);
  Result := TJSArray.new;
  for I := 0 to Pairs.length - 1 do
    Result.push(Items(TJSArray(Pairs[I])[0], string(TJSArray(Pairs[I])[0]) + ' (' + string(TJSArray(Pairs[I])[1]) + ')'));
end;

function SectionOptions(Paths: TJSArray): TJSArray;
var
  Seen: TJSMap;
  Section: string;
  I: NativeInt;
begin
  Seen := TJSMap.new;
  for I := 0 to Paths.length - 1 do
  begin
    Section := SectionOf(Paths[I]);
    Seen.&set(Section, double(Either(Seen.get(Section), 0)) + 1);
  end;
  Result := ByCount(Seen);
end;

// the address panel, from anywhere an address shows: under Visitors, Address
procedure LookUpAddress(Ip: JSValue);
begin
  // the Visitors tab in front (built now if it never was), then its panel
  if Truthy(S['adminTab']) then S.adminTab('Visitors');
  if Truthy(S['showAddress']) then S.showAddress(Ip);
end;

function AddressCell(Ip: JSValue): TJSHTMLElement;
begin
  Result := AddressCell(Ip, undefined);
end;

// an address as a button that opens its panel; marked when it is of concern
function AddressCell(Ip, Flagged: JSValue): TJSHTMLElement;
var
  B, Mark: TJSHTMLElement;
begin
  B := C.el('button', 'lv-ip lv-link', Ip);
  TJSObject(B)['type'] := 'button';
  B.title := T('Everything about this address');
  B.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin LookUpAddress(Ip); end));
  if not Truthy(Flagged) then Exit(B);
  Result := C.el('span', 'lv-flag');
  Mark := C.chip('!', 'bad');
  Mark.title := T('Of concern: see the Of concern tab');
  TKit(Result).add(B, ' ', Mark);
end;

// when, for the visitors' lists: the time for today, the date and time before
function Stamp(At: JSValue): JSValue;
var
  D: TJSDate;
begin
  D := TDate.new(At);
  if NotANumber(D) then Exit(Either(At, ''));
  if D.toDateString = TJSDate.new.toDateString then Result := C.clock(At) else Result := DateTimeText(At);
end;

// a link out of the site, for a referer
function OutLink(Url: JSValue): TJSHTMLElement;
begin
  // what a visitor's browser said it came from: a link only when it is a web address
  if not TJSRegExp.new('^https?:\/\/', 'i').test(Str(Url)) then Exit(C.el('span', 'visit-path', Url));
  Result := C.el('a', 'visit-path', Url);
  TJSObject(Result)['href'] := Url;
  TJSObject(Result)['target'] := '_blank';
  TJSObject(Result)['rel'] := 'noopener noreferrer';
end;

function LookButton(Ip: JSValue): TJSHTMLElement;
begin
  Result := C.el('button', '', T('Everything about this address'));
  TJSObject(Result)['type'] := 'button';
  Result.title := T('Its whole story in the period, the guard''s facts included, under Address');
  Result.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin LookUpAddress(Ip); end));
end;

// a reason the report gives against an address, in words
function ReasonWords(X: TJSObject): JSValue;
var
  N: JSValue;
  Kind: string;
begin
  N := Either(X['n'], 0);
  Kind := Str(X['kind']);
  if not Same(Kind, X['kind']) then Exit(X['kind']);
  if Kind = 'rate' then
  begin
    Result := TN(N, '%d request in one minute', '%d requests in one minute');
    if Truthy(X['text']) then Result := string(Result) + ' (' + string(Stamp(X['text'])) + ')';
  end
  else if Kind = 'requests' then Result := TN(N, '%d request', '%d requests')
  else if Kind = 'browser-crawl' then Result := T('a browser that read %s pages', LocaleNumber(N))
  else if Kind = 'agents' then Result := TN(N, '%d browser string', '%d browser strings')
  else if Kind = 'pretender' then Result := T('names %s’s crawler from outside its addresses', X['text'])
  else if Kind = 'fake' then Result := T('claims to be %s; its DNS says no', X['text'])
  else if Kind = 'missing' then Result := TN(N, '%d page that is not here', '%d pages that are not here')
  else if Kind = 'probes' then Result := TN(N, '%d scanner path probed', '%d scanner paths probed')
  else if Kind = 'refused' then Result := TN(N, 'turned away %d time', 'turned away %d times')
  else if Kind = 'errors' then Result := TN(N, '%d server error', '%d server errors')
  else if Kind = 'members' then Result := TN(N, 'signed in as %d member', 'signed in as %d members')
  else Result := X['kind'];
end;

function ReasonKinds: TJSObject;
begin
  Result := new(['rate', T('Pace'), 'requests', T('Many requests'), 'browser-crawl', T('A browser crawling'), 'agents', T('Browser strings'),
    'pretender', T('Pretending to be a crawler'), 'fake', T('Failed its DNS check'), 'missing', T('Missing pages'), 'probes', T('Probing'),
    'refused', T('Turned away'), 'errors', T('Server errors'), 'members', T('Many members')]);
end;

// a status code as a small mark: errors stand out, a line from before the codes shows none
function StatusCell(Code: JSValue): TJSHTMLElement;
begin
  if not Truthy(Code) then Exit(C.el('span', 'dim', '–'));
  if Num(Code) >= 500 then Result := C.chip(Str(Code), 'bad')
  else if Num(Code) >= 400 then Result := C.chip(Str(Code), 'open')
  else Result := C.chip(Str(Code), '');
end;

function MsCell(Ms: JSValue): JSValue;
var
  Cls, Words: string;
begin
  if IsUndef(Ms) or (Ms = nil) then Exit('');
  if Num(Ms) >= 2000 then Cls := 'bot-bad' else Cls := 'dim';
  if Num(Ms) >= 1000 then Words := Fixed(Num(Ms) / 1000, 1) + ' s' else Words := string(Ms) + ' ms';
  Result := C.el('span', Cls, Words);
end;

// a part of the site by its registered name, in words where they are known
// (a site on top names its own parts and search places in Extras.places)
function PartLabel(Part: JSValue): JSValue;
var
  Name: string;
begin
  Name := string(Part);
  Result := Either(TJSObject(Extras['places'])[Name],
    new(['chat', T('Chat'), 'api', T('API'), 'static', T('Static'), 'other', T('Other')])[Name]);
  if not Truthy(Result) then Result := TJSString(TJSString(Part).charAt(0)).toUpperCase + TJSString(Part).slice(1);
end;

function PlaceName(Where: JSValue): JSValue;
begin
  if Same(Where, 'chat') then Result := T('Chat') else Result := Either(TJSObject(Extras['places'])[string(Where)], Where);
end;

// a window's name for a file: its days
function WindowName(R: TJSObject): string;
begin
  Result := TJSString(Str(Either(R['from'], ''))).slice(0, 10) + '-' + TJSString(Str(Either(R['to'], ''))).slice(0, 10);
end;

initialization
  C := TShell(window['Chat']);
  SiteName := C['Site'];
  Me := TJSObject(C['me']);
  S := TAdminState(C['state']);
  Extras := TJSObject(C['extras']);
  Locale := C['locale'];
  Stream := TJSHTMLElement(C['stream']);
  FilePaths := TJSArray.new;
end.
