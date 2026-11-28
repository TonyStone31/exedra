unit LivePage;

{ Corner chat: the page's bench, last-used room or site's open channel, with a
  teaser once a visit and a bench's latest messages.  All member text is built as text nodes. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

implementation

uses JS, Web;

type
  TSay = reference to function(const English: string): string;
  TSayCount = reference to function(N: JSValue; const One, Many: string): string;
  // pas2js Web declares only the string URLSearchParams constructor.
  TParams = class external name 'URLSearchParams'(TJSURLSearchParams)
    constructor new(Data: TJSObject);
  end;
  // js.pas types the sort callback's answer as an integer; it may be NaN here.
  TOrder = reference to function(A, B: TJSObject): double;
  TSorted = class external name 'Array'(TJSArray)
    procedure sort(Order: TOrder);
  end;

const
  SVG = 'http://www.w3.org/2000/svg';
  // how long ago, in the largest unit that fits
  Limits: array[0..5] of double = (60, 3600, 86400, 604800, 2629800, 31557600);
  Parts: array[0..6] of string = ('second', 'minute', 'hour', 'day', 'week', 'month', 'year');
  Sizes: array[0..6] of double = (1, 60, 3600, 86400, 604800, 2629800, 31557600);

function Truthy(Value: JSValue): boolean; external name 'Boolean';
// Two JSValues compare loosely in pas2js; this keeps the strict test for text.
function Same(A, B: JSValue): boolean; external name 'Object.is';
function Number(Value: JSValue): double; external name 'Number';
function NotNumber(Value: JSValue): boolean; external name 'isNaN';
function Largest(This: JSValue; Values: TJSArray): double; external name 'Math.max.apply';

function Messages(Data: TJSObject): TJSArray;
begin
  if Truthy(Data['messages']) then Result := TJSArray(Data['messages']) else Result := TJSArray.new;
end;

procedure Start;
var
  Spot, Bubble, Badge, Teaser, TeaserWho, TeaserText, TeaserWhen, TeaserOff, TeaserRow, Panel, Head, Title, TitleText, TitleName, Here, Fold,
    News, List, Foot, Offer, SayNote, SentLine, Invite: TJSHTMLElement;
  Open, GoOn, Join: TJSHTMLAnchorElement;
  SayForm: TJSHTMLFormElement;
  SayBox: TJSHTMLTextAreaElement;
  Send: TJSHTMLButtonElement;
  Glimpses: TJSArray;
  Styles: TJSHTMLLinkElement;
  Base, Lang, Own, Room, PageKey, PageTitle, CanBench, PageHeading, LastSeen: string;
  T: TSay;
  TN: TSayCount;
  Relative: TJSIntlRelativeTimeFormat;
  Member, Shown, OpenAtStart: boolean;
  Timer, TeaserTimer, Generation, I: NativeInt;
  NewsAsked: double;
  Current, Found: TJSObject;
  Ways: TJSNodeList;

  // on another site (embed.js): every request and link goes to the chat's
  // own address, with no cookies, and links open there in a new tab
  function U(const Path: string): string;
  begin
    Result := Base + Path;
  end;

  function Away(A: TJSHTMLAnchorElement): TJSHTMLAnchorElement;
  begin
    if Base <> '' then
    begin
      A.target := '_blank';
      A.rel := 'noopener';
    end;
    Result := A;
  end;

  function Ago(Iso: JSValue): string;
  var
    Seconds: double;
    N: integer;
  begin
    Seconds := (TJSDate.parse(string(Iso)) - TJSDate.now) / 1000;
    if (Relative = nil) or NotNumber(Seconds) then Exit('');
    for N := 0 to 6 do
      if (N = 6) or (Abs(Seconds) < Limits[N]) then
      begin
        if N = 0 then Exit(Relative.format(0, 'second'));
        Exit(Relative.format(Round(Seconds / Sizes[N]), Parts[N]));
      end;
    Result := '';
  end;

  function El(const Tag: string; Cls: JSValue = undefined; Text: JSValue = undefined): TJSHTMLElement;
  begin
    Result := TJSHTMLElement(document.createElement(Tag));
    if Truthy(Cls) then Result.className := string(Cls);
    if jsTypeOf(Text) <> 'undefined' then TJSObject(Result)['textContent'] := Text;
  end;

  function BenchIcon: TJSElement;
  var
    Path: TJSElement;
  begin
    Result := document.createElementNS(SVG, 'svg');
    Result.setAttribute('viewBox', '0 0 24 24');
    Result.setAttribute('aria-hidden', 'true');
    Path := document.createElementNS(SVG, 'path');
    Path.setAttribute('d', 'M3 10h18M5 10v8M19 10v8M3 14h18M6 6h12');
    Path.setAttribute('fill', 'none');
    Path.setAttribute('stroke', 'currentColor');
    Path.setAttribute('stroke-width', '2');
    Path.setAttribute('stroke-linecap', 'round');
    Result.appendChild(Path);
  end;

  function GetJson(const Url: string): JSValue; async;
  var
    R: TJSResponse;
    Cookies: string;
    Failure: TJSError;
  begin
    if Base <> '' then Cookies := 'omit' else Cookies := 'same-origin';
    R := await(TJSResponse, window.fetch(U(Url), new(['credentials', Cookies, 'cache', 'no-store'])));
    if not R.ok then
    begin
      Failure := TJSError.new(await(string, R.text));
      TJSObject(Failure)['status'] := R.status;
      raise Failure;
    end;
    Result := await(JSValue, R.json);
  end;

  procedure Remember(const Key: string; Value: JSValue);
  begin
    try
      window.localStorage.setItem(Key, string(Value));
    except
    end;
  end;

  function Recall(const Key: string): string;
  var
    Kept: JSValue;
  begin
    try
      Kept := window.localStorage.getItem(Key);
      if Truthy(Kept) then Result := string(Kept) else Result := '';
    except
      Result := '';
    end;
  end;

  function Session(const Key: string; Value: JSValue = undefined): string;
  var
    Kept: JSValue;
  begin
    Result := '';
    try
      if jsTypeOf(Value) = 'undefined' then
      begin
        Kept := window.sessionStorage.getItem(Key);
        if Truthy(Kept) then Result := string(Kept);
        Exit;
      end;
      window.sessionStorage.setItem(Key, string(Value));
    except
    end;
  end;

  // ---- a bench's glimpse on its page
  procedure RefreshGlimpse(Box: TJSElement); async;
  var
    Data, M: TJSObject;
    Said: TJSArray;
    Lead, Ol, Li: TJSHTMLElement;
    N: NativeInt;
  begin
    try
      Data := TJSObject(await(GetJson('/api/live?room=' + encodeURIComponent(Box.getAttribute('data-live-room')))));
    except
      Exit;
    end;
    Said := Messages(Data).slice().reverse();
    Box.replaceChildren;
    if Said.length = 0 then
    begin
      Box.appendChild(El('p', 'glimpse-empty', T('Nothing said here yet. Be the first.')));
      Exit;
    end;
    Lead := El('p', 'glimpse-head', T('Latest at its bench'));
    if Number(Data['here']) > 0 then Lead.appendChild(El('span', 'live-here', ' · ' + TN(Data['here'], '%d here now', '%d here now')));
    Box.appendChild(Lead);
    Ol := El('ol', 'glimpse-list');
    for N := 0 to Said.length - 1 do
    begin
      M := TJSObject(Said[N]);
      Li := El('li');
      Li.appendChild(El('b', 'live-who', M['name']));
      Li.appendChild(El('time', 'live-when', Ago(M['at'])));
      Li.appendChild(El('span', 'live-text', M['text']));
      Ol.appendChild(Li);
    end;
    Box.appendChild(Ol);
  end;

  procedure AllGlimpses;
  var
    N: NativeInt;
  begin
    for N := 0 to Glimpses.length - 1 do RefreshGlimpse(TJSElement(Glimpses[N]));
  end;

  procedure SwitchRoom(Slug: JSValue);
  begin
    Room := string(Slug);
    Inc(Generation);
    LastSeen := '';
    Open.href := U('/p/' + encodeURIComponent(Room));
  end;

  // the room's own name, kind and whether it is readable at all: a room
  // remembered from the chat may have gone, in which case the site's channel
  procedure DescribeRoom; async;
  var
    Mine: NativeInt;
    Info: TJSObject;
    Channel: string;
  begin
    Mine := Generation;
    Info := nil;
    try
      Info := TJSObject(await(GetJson('/api/room?slug=' + encodeURIComponent(Room))));
    except
      if Mine <> Generation then Exit;
      Channel := Spot.getAttribute('data-live-default');
      if (Own = '') and (Room <> Channel) and Truthy(Channel) then
      begin
        SwitchRoom(Channel);
        TitleName.textContent := '#' + Room;
        await(DescribeRoom);
      end;
      Exit;
    end;
    if Mine <> Generation then Exit;
    if (Info <> nil) and Truthy(Info['title']) then
      if Own <> '' then TJSObject(TitleName)['textContent'] := Info['title']
      else if Same(Info['kind'], 'channel') then TitleName.textContent := '#' + string(Info['slug'])
      else TJSObject(TitleName)['textContent'] := Info['title'];
    if Own <> '' then Here.textContent := T('Live bench')
    else if (Info <> nil) and Same(Info['kind'], 'channel') then Here.textContent := T('Live chat')
    else Here.textContent := T('Live bench');
  end;

  procedure HideTeaser;
  begin
    TeaserRow.hidden := True;
    if TeaserTimer <> 0 then
    begin
      window.clearTimeout(TeaserTimer);
      TeaserTimer := 0;
    end;
  end;

  procedure RefreshNews; async; forward;

  // ---- read here is read: the mark the chat's own page leaves as it syncs,
  // so the badge and the chat's sidebar stop counting what was seen here
  procedure MarkRead(Data: TJSObject); async;
  var
    Newest: double;
  begin
    Newest := Largest(nil, Messages(Data).map(function(M: JSValue; N: NativeInt; A: TJSArray): JSValue
      begin Result := TJSObject(M)['id']; end));
    if not (Newest > Number(Data['last_read'])) then Exit;
    try
      await(GetJson('/api/sync?' + TParams.new(new(['room', Room, 'since', Data['rev'], 'read', Newest])).toString));
    except
      Exit;
    end;
    NewsAsked := 0;
    RefreshNews;
  end;

  procedure RefreshList(First: boolean); async;
  var
    Mine, N: NativeInt;
    Data, M: TJSObject;
    Said: TJSArray;
    Seen: string;
    AtBottom, Action: boolean;
    LastName: JSValue;
    Row: TJSHTMLAnchorElement;
    Who: TJSHTMLElement;
  begin
    if document.visibilityState = 'hidden' then Exit;
    Mine := Generation;
    try
      Data := TJSObject(await(GetJson('/api/messages?room=' + encodeURIComponent(Room))));
    except
      if First and (Mine = Generation) then List.replaceChildren(El('p', 'live-sheet-empty', T('The chat could not be reached.')));
      Exit;
    end;
    if Mine <> Generation then Exit;
    // not what was deleted, and not the members this reader ignores
    Said := Messages(Data).filter(function(Each: JSValue; N: NativeInt; A: TJSArray): boolean
      begin
        Result := not Truthy(TJSObject(Each)['deleted']) and not Truthy(TJSObject(Each)['ignored']) and Truthy(TJSObject(Each)['body']);
      end).reverse().slice(-40);
    Seen := TJSJSON.stringify(Said.map(function(Each: JSValue; N: NativeInt; A: TJSArray): JSValue
      begin
        if Truthy(TJSObject(Each)['edited']) then Result := TJSArray._of(TJSObject(Each)['id'], TJSObject(Each)['body'], TJSObject(Each)['edited'])
        else Result := TJSArray._of(TJSObject(Each)['id'], TJSObject(Each)['body'], '');
      end));
    if not First and (Seen = LastSeen) then Exit;
    AtBottom := First or (List.scrollHeight - List.scrollTop - List.clientHeight < 80);
    List.replaceChildren;
    if Said.length = 0 then List.appendChild(El('p', 'live-sheet-empty', T('Nothing said here yet. Be the first.')));
    LastName := '';
    for N := 0 to Said.length - 1 do
    begin
      M := TJSObject(Said[N]);
      // a message is a way into the chat, at that very message
      if Same(M['name'], LastName) then Row := TJSHTMLAnchorElement(El('a', 'live-msg same')) else Row := TJSHTMLAnchorElement(El('a', 'live-msg'));
      Row.href := U('/m/' + encodeURIComponent(string(M['id'])));
      Away(Row);
      Row.title := T('Open in the chat');
      if not Same(M['name'], LastName) then
      begin
        Who := El('div', 'live-msg-who');
        Who.appendChild(El('b', '', M['name']));
        Who.appendChild(El('time', '', Ago(M['at'])));
        Row.appendChild(Who);
      end;
      // an action (/me waves) is stored as *Ann waves*: shown as the chat shows it
      Action := TJSString(M['body']).startsWith('*' + string(M['name']) + ' ') and TJSString(M['body']).endsWith('*');
      if Action then Row.appendChild(El('div', 'live-msg-text action', TJSString(M['body']).slice(1, -1)))
      else Row.appendChild(El('div', 'live-msg-text', M['body']));
      List.appendChild(Row);
      LastName := M['name'];
    end;
    LastSeen := Seen;
    if AtBottom then List.scrollTop := List.scrollHeight;
    if Member and AtBottom then MarkRead(Data);
  end;

  procedure Show(Open_: boolean);
  begin
    Shown := Open_;
    Panel.hidden := not Open_;
    // Web declares classList.toggle without its second argument.
    if Open_ then Bubble.classList.add('open') else Bubble.classList.remove('open');
    if Open_ then Session('live-open', '1') else Session('live-open', '0');
    if Open_ then HideTeaser;
    // one timer at most, however often it is opened
    if Timer <> 0 then
    begin
      window.clearInterval(Timer);
      Timer := 0;
    end;
    if Open_ then
    begin
      RefreshList(True);
      RefreshNews;
      Timer := window.setInterval(TJSTimerCallBack(@RefreshList), 6000);
    end;
  end;

  // ---- a member's news, counted as the chat's sidebar counts it: a silenced room
  // counts nothing, a mentions-only room its mentions.  Asked for once in twenty seconds at most.
  function CountOf(R: TJSObject): double;
  begin
    if Same(R['notify'], 'none') then Result := 0
    else if Same(R['notify'], 'mentions') then
    begin
      if Truthy(R['mentions']) then Result := Number(R['mentions']) else Result := 0;
    end
    else if Truthy(R['unread']) then Result := Number(R['unread'])
    else Result := 0;
  end;

  function Count99(N: double): string;
  begin
    if N > 99 then Result := '99+' else Result := String(JSValue(N));
  end;

  procedure RefreshNews; async;
  var
    Rooms: JSValue;
    Fresh: TJSArray;
    R: TJSObject;
    Total, Mentions: double;
    N: NativeInt;
    A: TJSHTMLAnchorElement;
  begin
    if not Member or (document.visibilityState = 'hidden') or (TJSDate.now - NewsAsked < 20000) then Exit;
    NewsAsked := TJSDate.now;
    try
      Rooms := await(GetJson('/api/rooms'));
    except
      Exit;
    end;
    if not Truthy(Rooms) then Rooms := TJSArray.new;
    Fresh := TJSArray(Rooms).filter(function(Each: JSValue; K: NativeInt; All: TJSArray): boolean
      begin Result := CountOf(TJSObject(Each)) > 0; end);
    Total := 0;
    Mentions := 0;
    for N := 0 to Fresh.length - 1 do
    begin
      R := TJSObject(Fresh[N]);
      Total := Total + CountOf(R);
      if not Same(R['notify'], 'none') and Truthy(R['mentions']) then Mentions := Mentions + Number(R['mentions']);
    end;
    Badge.hidden := Total = 0;
    Badge.textContent := Count99(Total);
    if Mentions > 0 then Badge.classList.add('mention') else Badge.classList.remove('mention');
    if Truthy(Total) then Bubble.title := TN(Total, '%d unread message in the chat', '%d unread messages in the chat')
    else Bubble.title := T('Live chat');
    News.replaceChildren;
    News.hidden := Fresh.length = 0;
    if Fresh.length = 0 then Exit;
    News.appendChild(El('span', 'live-news-lead', T('New for you:')));
    TSorted(Fresh).sort(function(A, B: TJSObject): double
      begin
        Result := Number(B['mentions']) - Number(A['mentions']);
        if not Truthy(Result) then Result := Number(B['unread']) - Number(A['unread']);
      end);
    for N := 0 to TJSArray(Fresh.slice(0, 6)).length - 1 do
    begin
      R := TJSObject(Fresh[N]);
      if Truthy(R['mentions']) then A := TJSHTMLAnchorElement(El('a', 'live-news-room mention')) else A := TJSHTMLAnchorElement(El('a', 'live-news-room'));
      if Same(R['kind'], 'shelf') then A.href := U('/u/' + encodeURIComponent(string(R['title'])))
      else A.href := U('/p/' + encodeURIComponent(string(R['slug'])));
      if Same(R['kind'], 'channel') then A.append(El('span', '', '#' + string(R['slug'])), El('b', '', Count99(CountOf(R))))
      else A.append(El('span', '', R['title']), El('b', '', Count99(CountOf(R))));
      if Truthy(R['mentions']) then A.title := TN(R['mentions'], '%d mention of you', '%d mentions of you')
      else A.title := TN(CountOf(R), '%d unread', '%d unread');
      News.appendChild(A);
    end;
    if Fresh.length > 6 then
      TJSHTMLAnchorElement(News.appendChild(El('a', 'live-news-more', TN(Fresh.length - 6, 'and %d more', 'and %d more')))).href := '/';
  end;

  // ---- the way to speak: a box for a member, an invitation for a visitor;
  // and a bench for the page, when it has none and this reader may open one
  function BenchOffer: TJSHTMLElement;
  var
    Box, Note: TJSHTMLElement;
    B: TJSHTMLButtonElement;
    A: TJSHTMLAnchorElement;

    procedure Make(E: TJSEvent); async;
    var
      Names: TJSArray;
      R: TJSResponse;
      Made: TJSObject;
    begin
      B.disabled := True;
      Note.textContent := '';
      Names := TJSArray(TJSString(PageKey).split(':'));
      try
        R := await(TJSResponse, window.fetch('/page-bench', new(['method', 'POST', 'credentials', 'same-origin',
          'body', TParams.new(new(['kind', Names[0], 'key', Names.slice(1).join(':')]))])));
        if not R.ok then
        begin
          Note.textContent := TJSString(await(string, R.text)).slice(0, 200);
          B.disabled := False;
          Exit;
        end;
        Made := await(TJSObject, R.json);
        Remember('last-room', Made['room']);
        TJSObject(window.location)['href'] := Made['url'];
      except
        Note.textContent := T('The chat could not be reached.');
        B.disabled := False;
      end;
    end;

  begin
    if (PageKey = '') or (Own <> '') then Exit(nil);
    Box := El('div', 'live-make');
    if CanBench = 'yes' then
    begin
      B := TJSHTMLButtonElement(El('button', 'live-make-bench', T('Open a bench for this page')));
      B._type := 'button';
      B.title := PageTitle;
      Note := El('span', 'live-make-note');
      B.addEventListener('click', TJSRawEventHandler(@Make));
      Box.append(B, Note);
    end
    else if CanBench = 'embed' then
    begin
      // a page on another site: the chat's own site opens the bench, signed in there
      A := Away(TJSHTMLAnchorElement(El('a', 'live-make-bench', T('Open a bench for this page'))));
      A.href := U('/embed/bench?url=' + encodeURIComponent(TJSString(PageKey).slice(TJSString(PageKey).indexOf(':') + 1)));
      A.title := PageTitle;
      Box.appendChild(A);
    end
    else if CanBench = 'signin' then
    begin
      A := TJSHTMLAnchorElement(El('a', 'live-make-signin', T('Sign in to open a bench for this page')));
      A.href := '/signin?return=' + encodeURIComponent(window.location.pathname + window.location.search);
      Box.appendChild(A);
    end
    else Exit(nil);
    Result := Box;
  end;

  procedure Speak(Event: TJSEvent); async;
  var
    Words: string;
    R: TJSResponse;
  begin
    Event.preventDefault;
    Words := TJSString(SayBox.value).trim;
    if Words = '' then Exit;
    Send.disabled := True;
    SayNote.textContent := '';
    SentLine.hidden := True;
    try
      try
        R := await(TJSResponse, window.fetch('/api/post', new(['method', 'POST', 'credentials', 'same-origin',
          'body', TParams.new(new(['room', Room, 'body', Words]))])));
        if not R.ok then
        begin
          SayNote.textContent := TJSString(await(string, R.text)).slice(0, 200);
          Exit;
        end;
        SayBox.value := '';
        Remember('last-room', Room);
        GoOn.href := '/p/' + encodeURIComponent(Room);
        SentLine.hidden := False;
        await(RefreshList(True));
      except
        SayNote.textContent := T('The chat could not be reached.');
      end;
    finally
      Send.disabled := False;
      SayBox.focus;
    end;
  end;

  // ---- who is there: the pulse on the bubble, the line under the title,
  // and for a visitor the badge
  procedure RefreshHere; async;
  var
    Data: TJSObject;
    N: double;
  begin
    if document.visibilityState = 'hidden' then Exit;
    try
      Data := TJSObject(await(GetJson('/api/live?room=' + encodeURIComponent(Room))));
    except
      Exit;
    end;
    if Truthy(Data['here']) then N := Number(Data['here']) else N := 0;
    if not Member then
    begin
      Badge.hidden := N = 0;
      Badge.textContent := String(JSValue(N));
      if N > 0 then Bubble.title := TN(N, '%d here now', '%d here now') else Bubble.title := T('Live chat');
    end;
    if N > 0 then Bubble.classList.add('busy') else Bubble.classList.remove('busy');
    if N > 0 then Here.textContent := TN(N, '%d here now', '%d here now')
    else if Own <> '' then Here.textContent := T('Live bench')
    else Here.textContent := T('Live chat');
  end;

  // ---- the teaser: the latest line said at the page's bench, or anywhere
  // on the site, once a visit, while it is less than a day old
  procedure Tease; async;
  var
    Data, M: TJSObject;
    Where: string;
  begin
    if (Session('live-teased') <> '') or (Session('live-open') = '1') then Exit;
    try
      if Own <> '' then Data := TJSObject(await(GetJson('/api/live?room=' + encodeURIComponent(Room))))
      else Data := TJSObject(await(GetJson('/api/live')));
    except
      Exit;
    end;
    M := TJSObject(Messages(Data)[0]);
    if not Truthy(M) or (TJSDate.now - TJSDate.parse(string(M['at'])) > 86400000) then Exit;
    Session('live-teased', '1');
    Where := '';
    if (Own = '') and Truthy(M['room']) then
      if Same(M['kind'], 'channel') then Where := ' ' + T('in') + ' #' + string(M['room']) else Where := ' ' + T('in') + ' ' + string(M['title']);
    TeaserWho.textContent := string(M['name']) + Where + ':';
    // an action's words begin with the name, which is not said twice
    if TJSString(M['text']).startsWith(string(M['name']) + ' ') then
      TeaserText.textContent := ' ' + TJSString(M['text']).slice(TJSString(M['name']).length + 1) + ' '
    else
      TeaserText.textContent := ' ' + string(M['text']) + ' ';
    TeaserWhen.textContent := Ago(M['at']);
    Teaser.title := T('Open the chat');
    Teaser.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        // a line from another room opens that room
        if (Own = '') and Truthy(M['room']) and not Same(M['room'], Room) then
        begin
          SwitchRoom(M['room']);
          if Same(M['kind'], 'channel') then TitleName.textContent := '#' + string(M['room']) else TJSObject(TitleName)['textContent'] := M['title'];
          DescribeRoom;
        end;
        Show(True);
      end));
    TeaserOff.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin HideTeaser; end));
    TeaserRow.hidden := False;
    TeaserTimer := window.setTimeout(@HideTeaser, 20000);
  end;

begin
  Spot := TJSHTMLElement(document.querySelector('[data-live-strip]'));
  // the glimpse boxes on the page: not the bubble's spot, which names a room too
  Glimpses := TJSArray.from(document.querySelectorAll('[data-live-room]:not([data-live-strip])'));
  if (Spot = nil) and (Glimpses.length = 0) then Exit;
  if Spot <> nil then Base := Spot.getAttribute('data-live-base') else Base := '';
  if not Truthy(Base) then Base := '';
  // the corner chat's stylesheet comes from where this script came from; it is shown once that is in
  Styles := TJSHTMLLinkElement(document.createElement('link'));
  Styles.rel := 'stylesheet';
  Current := TJSObject(TJSObject(document)['currentScript']);
  Found := nil;
  if Truthy(Current) then Found := TJSRegexp.new('\?v=[^&]*').execFull(string(Current['src']));
  if Found <> nil then Styles.href := U('/static/live.css') + string(Found['0']) else Styles.href := U('/static/live.css');
  if Spot <> nil then document.head.appendChild(Styles);
  if Truthy(TJSObject(window)['t']) then T := TSay(TJSObject(window)['t'])
  else T := function(const English: string): string begin Result := English; end;
  if Truthy(TJSObject(window)['tn']) then TN := TSayCount(TJSObject(window)['tn'])
  else TN := function(N: JSValue; const One, Many: string): string
    begin
      if Same(N, 1) then Result := One else Result := Many;
      Result := TJSString(Result).replace('%d', string(N));
    end;
  Lang := string(TJSObject(document.documentElement)['lang']);
  if not Truthy(Lang) then Lang := 'en';
  Relative := nil;
  try
    Relative := TJSIntlRelativeTimeFormat.new(Lang, TJSIntlRelativeTimeFormatOptions(new(['numeric', 'auto'])));
  except
  end;

  // ---- the bubble and its sheet
  if Spot = nil then
  begin
    AllGlimpses;
    Exit;
  end;
  // a reader on another site counts as a visitor: no cookies go there
  Member := (Base = '') and (document.querySelector('.account .me') <> nil);
  // the page's own bench when it has one; else the room last used in the
  // chat; else the site's open channel (asked for when the page named none)
  Own := Spot.getAttribute('data-live-room');
  if not Truthy(Own) then
    if Glimpses.length > 0 then Own := TJSElement(Glimpses[0]).getAttribute('data-live-room') else Own := '';
  Room := Own;
  if not Truthy(Room) then Room := Recall('last-room');
  if not Truthy(Room) then Room := Spot.getAttribute('data-live-default');
  if not Truthy(Room) then Room := '';
  // the page a bench can be opened for, and whether this reader may
  PageKey := Spot.getAttribute('data-live-page');
  if not Truthy(PageKey) then PageKey := '';
  PageTitle := Spot.getAttribute('data-live-title');
  if not Truthy(PageTitle) then PageTitle := '';
  CanBench := Spot.getAttribute('data-live-can-bench');
  if not Truthy(CanBench) then CanBench := '';
  if document.querySelector('h1') <> nil then PageHeading := TJSString(document.querySelector('h1').textContent).trim else PageHeading := '';

  if Truthy(TJSObject(Styles)['sheet']) then Spot.hidden := False
  else
  begin
    TJSObject(Styles)['onerror'] := procedure begin Spot.hidden := False; end;
    TJSObject(Styles)['onload'] := TJSObject(Styles)['onerror'];
  end;
  Spot.className := 'live-bench';
  Spot.replaceChildren;
  Bubble := El('button', 'live-bubble');
  TJSHTMLButtonElement(Bubble)._type := 'button';
  Bubble.setAttribute('aria-label', T('Live chat'));
  Bubble.title := T('Live chat');
  Bubble.appendChild(BenchIcon);
  Badge := El('span', 'live-badge', '');
  Badge.hidden := True;
  Bubble.appendChild(Badge);
  // a line of the latest talk beside the button, once a visit
  Teaser := El('button', 'live-teaser');
  TJSHTMLButtonElement(Teaser)._type := 'button';
  TeaserWho := El('b');
  TeaserText := El('span', 'live-teaser-text');
  TeaserWhen := El('time');
  Teaser.append(TeaserWho, TeaserText, TeaserWhen);
  TeaserOff := El('button', 'live-teaser-off', '×');
  TJSHTMLButtonElement(TeaserOff)._type := 'button';
  TeaserOff.title := T('Not now');
  TeaserOff.setAttribute('aria-label', T('Not now'));
  TeaserRow := El('div', 'live-teaser-row');
  TeaserRow.hidden := True;
  TeaserRow.append(Teaser, TeaserOff);
  Spot.appendChild(TeaserRow);
  Spot.appendChild(Bubble);

  Panel := El('section', 'live-sheet');
  Panel.hidden := True;
  Panel.setAttribute('aria-label', T('Live chat'));
  Head := El('header', 'live-sheet-head');
  Title := El('div', 'live-sheet-title');
  Title.appendChild(BenchIcon);
  TitleText := El('div');
  if Own = '' then TitleName := El('b', '', '#' + Room)
  else if PageHeading <> '' then TitleName := El('b', '', PageHeading)
  else TitleName := El('b', '', Room);
  TitleText.appendChild(TitleName);
  if Own <> '' then Here := El('span', 'live-sheet-here', T('Live bench')) else Here := El('span', 'live-sheet-here', T('Live chat'));
  TitleText.appendChild(Here);
  Title.appendChild(TitleText);
  Head.appendChild(Title);
  Open := TJSHTMLAnchorElement(El('a', 'live-sheet-open', T('Open the chat')));
  Open.href := U('/p/' + encodeURIComponent(Room));
  Away(Open);
  Head.appendChild(Open);
  Fold := El('button', 'live-sheet-fold', '–');
  TJSHTMLButtonElement(Fold)._type := 'button';
  Fold.title := T('Minimize');
  Fold.setAttribute('aria-label', T('Minimize'));
  Head.appendChild(Fold);
  Panel.appendChild(Head);
  // for a member: where there is something new for them
  News := El('nav', 'live-news');
  News.hidden := True;
  News.setAttribute('aria-label', T('New for you'));
  Panel.appendChild(News);
  List := El('div', 'live-sheet-list');
  List.setAttribute('role', 'log');
  List.setAttribute('aria-live', 'polite');
  Panel.appendChild(List);
  Foot := El('div', 'live-sheet-foot');
  Panel.appendChild(Foot);
  Spot.insertBefore(Panel, TeaserRow);

  Shown := False;
  Timer := 0;
  // what was drawn last: an edit or a deletion changes it, not only a new message
  LastSeen := '';
  // which room the sheet is on: an answer that comes back for an earlier one is dropped
  Generation := 0;
  Bubble.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Show(not Shown); end));
  Fold.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Show(False); end));
  NewsAsked := 0;

  Offer := BenchOffer;
  if Offer <> nil then Foot.appendChild(Offer);
  if Member then
  begin
    SayForm := TJSHTMLFormElement(El('form', 'live-say'));
    SayBox := TJSHTMLTextAreaElement(El('textarea'));
    SayBox.rows := 1;
    SayBox.maxLength := 8000;
    SayBox.placeholder := T('Say something…');
    SayBox.setAttribute('aria-label', T('Say something…'));
    Send := TJSHTMLButtonElement(El('button', 'live-send', T('Send')));
    Send._type := 'submit';
    SayForm.append(SayBox, Send);
    SayNote := El('p', 'live-say-note');
    SentLine := El('p', 'live-sent');
    SentLine.hidden := True;
    GoOn := TJSHTMLAnchorElement(El('a', '', T('Continue in the chat')));
    // Web.append omits text before a node; the erased cast preserves the call.
    SentLine.append(TJSElement(JSValue(T('Sent.') + ' ')), GoOn);
    Foot.append(SayForm, SayNote, SentLine);
    SayBox.addEventListener('keydown', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        if (TJSKeyboardEvent(E).key = 'Enter') and not TJSKeyboardEvent(E).shiftKey then
        begin
          E.preventDefault;
          if Truthy(TJSObject(SayForm)['requestSubmit']) then SayForm.requestSubmit else Send.click;
        end;
      end));
    SayForm.addEventListener('submit', TJSRawEventHandler(@Speak));
  end
  else
  begin
    Invite := El('p', 'live-invite', T('Read along, or join to say something here.') + ' ');
    Join := TJSHTMLAnchorElement(El('a', 'button', T('Join')));
    if Base <> '' then Join.href := U('/p/' + encodeURIComponent(Room))
    else Join.href := '/signin?return=' + encodeURIComponent(window.location.pathname + window.location.search);
    Away(Join);
    Invite.appendChild(Join);
    Foot.appendChild(Invite);
  end;

  TeaserTimer := 0;
  OpenAtStart := Session('live-open') = '1';
  // a bench just opened for this page, or the page asking for it: the sheet opens
  if Same(TJSURLSearchParams.new(window.location.search).get('bench'), 'open') then OpenAtStart := True;
  DescribeRoom;
  if OpenAtStart then Show(True);
  // the page's bench card: its way in opens the live bench here rather than leaving
  Ways := document.querySelectorAll('.page-bench a[href="/p/' + Room + '"], .catalog-room a[href="/p/' + Room + '"]');
  for I := 0 to Ways.length - 1 do
    Ways[I].addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        if TJSMouseEvent(E).metaKey or TJSMouseEvent(E).ctrlKey then Exit;
        E.preventDefault;
        Show(True);
        Panel.scrollIntoView(new(['block', 'nearest']));
      end));
  RefreshHere;
  window.setInterval(@RefreshHere, 30000);
  if Member then
  begin
    RefreshNews;
    window.setInterval(@RefreshNews, 180000);
  end;
  window.setTimeout(@Tease, 2500);
  document.addEventListener('visibilitychange', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      if document.visibilityState = 'visible' then
      begin
        RefreshHere;
        if Shown then RefreshList(False);
        if Member then RefreshNews;
      end;
    end));
  AllGlimpses;
  window.setInterval(@AllGlimpses, 30000);
end;

initialization
  Start;
end.
