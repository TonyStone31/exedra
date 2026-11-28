unit ReactionsPage;

{ Shared reaction chips, names and emoji picker. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web;

type
  TReactionPick = reference to procedure(Emoji: JSValue);
  TReactionResize = reference to procedure;

function Chips(List: TJSArray; Opts: TJSObject): TJSHTMLElement;
procedure Offer(Box: TJSHTMLElement; Lists: TJSObject; Pick: TReactionPick; Resized: TReactionResize);
procedure Choose(Anchor: TJSHTMLElement; Lists: TJSObject; Pick: TReactionPick);
procedure Under(Box: TJSHTMLElement; R: TJSDOMRect);

implementation

uses PageKit, PageGlobals;

const
  REST = 350;
  HOLD = 500;

type
  // Web omits focus(options); this overload calls the browser method unchanged.
  TFocusElement = class external name 'HTMLElement'(TJSHTMLElement)
    procedure focus(Options: TJSObject);
  end;

var
  Opened: TJSObject;

function El(const Tag: string; Cls: JSValue = undefined; Text: JSValue = undefined): TJSHTMLElement;
begin
  Result := Side.el(Tag, Cls, Text);
end;

function Max(A, B: double): double; external name 'Math.max';
function Min(A, B: double): double; external name 'Math.min';
function Number(Value: JSValue): double; external name 'Number';
// The count goes to the site's words as the answer gave it.
function Count(N: JSValue; const One, Many: string): string; varargs; external name 'window.tn';

procedure Close(Refocus: boolean = False);
begin
  if Opened = nil then Exit;
  TJSHTMLElement(Opened['box']).remove;
  if Refocus and Truthy(Opened['refocus']) then
    TFocusElement(Opened['anchor']).focus(new(['preventScroll', True]));
  Opened := nil;
end;

procedure Under(Box: TJSHTMLElement; R: TJSDOMRect);
var
  High, Top: double;
begin
  High := Box.offsetHeight;
  Top := R.bottom + 4;
  if Top + High > window.innerHeight - 8 then Top := R.top - 4 - High;
  Box.style.setProperty('top', String(JSValue(Max(8, Min(Top, window.innerHeight - High - 8)))) + 'px');
  Box.style.setProperty('left', String(JSValue(Max(8, Min(R.left, window.innerWidth - Box.offsetWidth - 8)))) + 'px');
end;

procedure Open(Box, Anchor: TJSHTMLElement; Refocus: boolean);
begin
  Close;
  document.body.appendChild(Box);
  Opened := new(['box', Box, 'anchor', Anchor, 'refocus', Refocus]);
  Under(Box, Anchor.getBoundingClientRect);
end;

type
  THeld = reference to function: boolean;
  TAsk = reference to function: TJSPromise;

function WhoGave(B: TJSHTMLElement; Ask: TAsk): THeld;
var
  Timer: NativeInt;
  Wanted, Held: boolean;

  procedure Show; async;
  var
    Answer: TJSObject;
    Box: TJSHTMLElement;
    Names: TJSArray;
    I: NativeInt;
  begin
    Wanted := True;
    try
      Answer := await(TJSObject, Ask());
    except
      Exit;
    end;
    if not Wanted or not Truthy(TJSObject(B)['isConnected']) or not Truthy(TJSObject(Answer['names'])['length']) then Exit;
    Names := TJSArray(Answer['names']);
    Box := El('div', 'reactwho');
    Box.setAttribute('role', 'tooltip');
    for I := 0 to Names.length - 1 do Box.appendChild(El('div', '', Names[I]));
    if Number(Answer['more']) > 0 then
      Box.appendChild(El('div', 'more', Count(Answer['more'], 'and %d more', 'and %d more')));
    Open(Box, B, False);
  end;

  procedure Soon(Ms: NativeInt; Hold: boolean);
  begin
    window.clearTimeout(Timer);
    Timer := window.setTimeout(procedure begin Held := Hold; Show; end, Ms);
  end;

  procedure Drop;
  begin
    window.clearTimeout(Timer);
    Wanted := False;
    if (Opened <> nil) and (Opened['anchor'] = B) then Close;
  end;

  procedure EndPointer(E: TJSEvent);
  begin
    if TJSPointerEvent(E).pointerType <> 'mouse' then window.clearTimeout(Timer);
  end;

begin
  Timer := 0; Wanted := False; Held := False;
  B.addEventListener('pointerenter', TJSRawEventHandler(procedure(E: TJSEvent)
    begin if TJSPointerEvent(E).pointerType = 'mouse' then Soon(REST, False); end));
  B.addEventListener('pointerleave', TJSRawEventHandler(procedure(E: TJSEvent)
    begin if TJSPointerEvent(E).pointerType = 'mouse' then Drop; end));
  B.addEventListener('focus', TJSRawEventHandler(procedure(E: TJSEvent)
    begin if B.matches(':focus-visible') then Soon(0, False); end));
  B.addEventListener('blur', TJSRawEventHandler(procedure(E: TJSEvent) begin Drop; end));
  B.addEventListener('pointerdown', TJSRawEventHandler(procedure(E: TJSEvent)
    begin Held := False; if TJSPointerEvent(E).pointerType <> 'mouse' then Soon(HOLD, True); end));
  B.addEventListener('pointerup', TJSRawEventHandler(@EndPointer));
  B.addEventListener('pointercancel', TJSRawEventHandler(@EndPointer));
  B.addEventListener('contextmenu', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      E.preventDefault;
      window.clearTimeout(Timer);
      Held := TJSPointerEvent(E).pointerType = 'touch';
      if (Opened = nil) or (Opened['anchor'] <> B) then Show;
    end));
  Result := function: boolean
    begin
      Result := Held;
      Held := False;
      if not Result then Drop;
    end;
end;

function Chip(R, Opts: TJSObject): TJSHTMLElement;
var
  B: TJSHTMLButtonElement;
  Held: THeld;
  Cls: string;
begin
  Cls := 'react';
  if Truthy(R['mine']) then Cls := Cls + ' mine';
  B := TJSHTMLButtonElement(El('button', Cls));
  B._type := 'button';
  B.setAttribute('aria-pressed', String(JSValue(Truthy(R['mine']))));
  // Web.append omits a node followed by text; the erased cast preserves the call.
  B.append(El('span', 'emoji', R['r']), TJSElement(JSValue(' ' + String(R['n']))));
  Held := WhoGave(B, function: TJSPromise
    begin Result := TJSPromise(TJSFunction(Opts['who']).call(Opts, R)); end);
  B.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    begin if not Held() then TJSFunction(Opts['toggle']).call(Opts, R); end));
  Result := B;
end;

function Chips(List: TJSArray; Opts: TJSObject): TJSHTMLElement;
var
  I: NativeInt;
begin
  Result := El('div', 'reacts');
  for I := 0 to List.length - 1 do Result.appendChild(Chip(TJSObject(List[I]), Opts));
end;

procedure Offer(Box: TJSHTMLElement; Lists: TJSObject; Pick: TReactionPick; Resized: TReactionResize);
var
  Shown: TJSHTMLElement;
  More: TJSHTMLButtonElement;

  function Button(Emoji: JSValue): TJSHTMLElement;
  begin
    Result := El('button', '', Emoji);
    TJSHTMLButtonElement(Result)._type := 'button';
    Result.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Pick(Emoji); end));
  end;

  function Row(const Cls: string; List: TJSArray): TJSHTMLElement;
  var
    I: NativeInt;
  begin
    Result := El('div', Cls);
    for I := 0 to List.length - 1 do Result.appendChild(Button(List[I]));
  end;

begin
  Shown := Row('emojis', TJSArray(Lists['shown']));
  Box.appendChild(Shown);
  if TJSArray(Lists['more']).length = 0 then Exit;
  More := TJSHTMLButtonElement(Side.iconButton('plus', T('More reactions')));
  More.setAttribute('aria-expanded', 'false');
  More.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      All: boolean;
    begin
      All := Box.classList.toggle('all');
      if All then
      begin More.replaceChildren(Side.icon('up')); More.title := T('Fewer reactions'); end
      else
      begin More.replaceChildren(Side.icon('plus')); More.title := T('More reactions'); end;
      More.setAttribute('aria-label', More.title);
      More.setAttribute('aria-expanded', String(JSValue(All)));
      Resized();
    end));
  Shown.appendChild(More);
  Box.appendChild(Row('emojis rest', TJSArray(Lists['more'])));
end;

procedure Choose(Anchor: TJSHTMLElement; Lists: TJSObject; Pick: TReactionPick);
var
  Box: TJSHTMLElement;
begin
  if (Opened <> nil) and (Opened['anchor'] = Anchor) then begin Close(True); Exit; end;
  Box := El('div', 'msgmenu');
  Box.setAttribute('role', 'group');
  Box.setAttribute('aria-label', Anchor.title);
  Offer(Box, Lists, procedure(Emoji: JSValue) begin Close(True); Pick(Emoji); end,
    procedure begin Under(Box, Anchor.getBoundingClientRect); end);
  Box.addEventListener('focusout', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      if Truthy(TJSFocusEvent(E).relatedTarget) and not Box.contains(TJSNode(TJSFocusEvent(E).relatedTarget)) then Close;
    end));
  Open(Box, Anchor, True);
  TFocusElement(Box.querySelector('button')).focus(new(['preventScroll', True]));
end;

procedure Start;
begin
  Opened := nil;
  document.addEventListener('pointerdown', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      if (Opened <> nil) and not TJSHTMLElement(Opened['box']).contains(TJSNode(E.target)) and
        not TJSHTMLElement(Opened['anchor']).contains(TJSNode(E.target)) then Close;
    end), True);
  document.addEventListener('scroll', TJSRawEventHandler(procedure(E: TJSEvent)
    begin if (Opened <> nil) and not TJSHTMLElement(Opened['box']).contains(TJSNode(E.target)) then Close(True); end), True);
  window.addEventListener('resize', TJSRawEventHandler(procedure(E: TJSEvent) begin Close(True); end));
  document.addEventListener('pointermove', TJSRawEventHandler(procedure(E: TJSEvent)
    begin if (Opened <> nil) and not Truthy(TJSObject(Opened['anchor'])['isConnected']) then Close; end));
  document.addEventListener('keydown', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      if (Opened = nil) or (TJSKeyboardEvent(E).key <> 'Escape') then Exit;
      E.preventDefault; E.stopPropagation; Close(True);
    end), True);
  TJSObject(window)['Reactions'] := new(['chips', @Chips, 'offer', @Offer, 'choose', @Choose, 'under', @Under]);
end;

initialization
  Start;
end.
