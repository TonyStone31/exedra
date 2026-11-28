unit interest;

{ Interesting buttons, discovery shortcuts and the feedback before leaving. }

{$mode objfpc}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

implementation

uses JS, Web, PageKit, PageGlobals;

var
  Reduce, Leaving: boolean;

function Number(Value: JSValue): double; external name 'Number';

function Say(const Text: string): string;
begin
  if Truthy(TJSObject(window)['t']) then
    Result := T(Text)
  else Result := Text;
end;

procedure Cheer(Button: TJSHTMLElement);
var
  Plus: TJSHTMLElement;
  Width: double;
begin
  if Truthy(TJSObject(window)['matchMedia']) and window.matchMedia('(prefers-reduced-motion: reduce)').matches then Exit;
  Button.classList.remove('pop');
  // Reading the width restarts the animation after the class was removed.
  Width := Button.offsetWidth;
  Button.classList.add('pop');
  Plus := MakeElement('span', 'plus-one');
  Plus.setAttribute('aria-hidden', 'true'); Plus.textContent := '+1';
  Button.appendChild(Plus);
  window.setTimeout(procedure begin Plus.remove; end, 900);
end;

procedure Invite;
var
  Note: TJSHTMLElement;
  Join: TJSHTMLAnchorElement;
  Close: TJSHTMLButtonElement;
begin
  if not document.body.classList.contains('guest') then Exit;
  try
    if Truthy(window.sessionStorage.getItem('interest-invited')) then Exit;
    window.sessionStorage.setItem('interest-invited', '1');
  except
    Exit;
  end;
  Note := MakeElement('div', 'interest-invite'); Note.setAttribute('role', 'status');
  Note.appendChild(document.createTextNode(Say('Thanks! Members can also rate entries.') + ' '));
  Join := TJSHTMLAnchorElement(MakeElement('a')); Join.href := '/signin?return=' + encodeURIComponent(window.location.pathname + window.location.search);
  Join.textContent := Say('Join'); Note.appendChild(Join);
  Close := TJSHTMLButtonElement(MakeElement('button')); Close._type := 'button'; Close.textContent := '×'; Close.setAttribute('aria-label', Say('Hide'));
  Close.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Note.remove; end));
  Note.appendChild(Close); document.body.appendChild(Note);
  window.setTimeout(procedure begin Note.classList.add('gone'); end, 9000);
  window.setTimeout(procedure begin Note.remove; end, 9600);
end;

procedure Show(const Entry: string; Answer: TJSObject; Pressed: TJSHTMLElement);
var
  Forms: TJSNodeList;
  Form, Button: TJSHTMLElement;
  I: integer;
begin
  Forms := document.querySelectorAll('.interest-form[data-entry="' + Entry + '"]');
  for I := 0 to Forms.length - 1 do
  begin
    Form := TJSHTMLElement(Forms[I]); Button := TJSHTMLElement(Form.querySelector('.interest-button'));
    if Truthy(Answer['mine']) and (Form = Pressed) then Cheer(Button);
    // pas2js Web lacks classList.toggle(name, force): the browser's own is called, with the answer as it came.
    TJSFunction(TJSObject(Button.classList)['toggle']).call(Button.classList, 'on', Answer['mine']);
    if Truthy(Answer['mine']) then
    begin
      Button.setAttribute('aria-pressed', 'true');
      Button.title := Say('You find this interesting. Press again to take it back.');
    end
    else
    begin
      Button.setAttribute('aria-pressed', 'false');
      Button.title := Say('Tell others this looks interesting');
    end;
    Form.querySelector('.interest-count').textContent := string(Answer['interest']);
  end;
end;

procedure Press(E: TJSEvent); async;
var
  Form: TJSHTMLFormElement;
  Button: TJSHTMLButtonElement;
  Answer: TJSResponse;
  Data: TJSObject;
begin
  Form := TJSHTMLFormElement(Closest(E.target, '.interest-form'));
  if Form = nil then Exit;
  E.preventDefault;
  Button := TJSHTMLButtonElement(Form.querySelector('.interest-button'));
  if Button.disabled then Exit;
  Button.disabled := True;
  try
    try
      Answer := await(TJSResponse, window.fetch(Form.action, new(['method', 'POST', 'credentials', 'same-origin', 'headers', new(['Accept', 'application/json'])])));
      if Answer.ok then
      begin
        Data := await(TJSObject, Answer.json);
        Show(Form.dataset['entry'], Data, Form);
        if Truthy(Data['mine']) then Invite;
      end
      else Button.title := TJSString(await(string, Answer.text)).slice(0, 200);
    except
      Form.submit;
    end;
  finally
    Button.disabled := False;
  end;
end;

function ByHand(const Url: string): string;
begin
  Result := Url;
  if TJSRegExp.new('[?&]hand=1').test(Url) then Exit;
  if TJSString(Url).indexOf('?') >= 0 then Result := Url + '&hand=1' else Result := Url + '?hand=1';
end;

procedure HandField(Form: TJSHTMLFormElement);
var
  Field: TJSHTMLInputElement;
begin
  if Form.querySelector('input[name="hand"]') <> nil then Exit;
  Field := TJSHTMLInputElement(MakeElement('input')); Field._type := 'hidden'; Field.name := 'hand'; Field.value := '1';
  Form.appendChild(Field);
end;

procedure Leave(const How: string; Go: TJSTimerCallback);
var
  Button, Entry, Burst, Star, Drawn, Spark: TJSHTMLElement;
  At, Box: TJSDOMRect;
  X, Y, Width, Height: double;
  I, Delay: integer;
begin
  if Leaving then Exit;
  Leaving := True;
  if Reduce then begin Go(); Exit; end;
  document.body.classList.add('leaving', 'leaving-' + How);
  if How = 'yes' then
  begin
    Button := TJSHTMLElement(document.querySelector('.discover-yes'));
    X := window.innerWidth / 2; Y := window.innerHeight / 2; Width := 0; Height := 0;
    if Button <> nil then
    begin
      At := Button.getBoundingClientRect;
      X := At.left; Y := At.top; Width := At.width; Height := At.height;
    end;
    X := X + Width / 2; Y := Y + Height / 2;
    Entry := TJSHTMLElement(document.querySelector('.catalog-entry'));
    if Entry <> nil then
    begin
      Box := Entry.getBoundingClientRect;
      Entry.style.setProperty('transform-origin', String(JSValue(X - Box.left)) + 'px ' + String(JSValue(Y - Box.top)) + 'px');
    end;
    Burst := MakeElement('div', 'star-burst'); Burst.setAttribute('aria-hidden', 'true');
    // pas2js Web omits individual CSS style properties.
    Burst.style.setProperty('left', String(JSValue(X)) + 'px');
    Burst.style.setProperty('top', String(JSValue(Y)) + 'px');
    Star := MakeElement('span', 'fly-star'); Drawn := TJSHTMLElement(document.querySelector('.discover-yes .star-icon'));
    if Drawn <> nil then Star.appendChild(Drawn.cloneNode(True)) else Star.textContent := '★';
    Burst.appendChild(Star);
    for I := 0 to 6 do
    begin
      Spark := MakeElement('i');
      Spark.style.setProperty('--a', String(JSValue(I * 51 + 20)) + 'deg');
      Spark.style.setProperty('--d', String(JSValue(70 + (I mod 3) * 30)) + 'px');
      Burst.appendChild(Spark);
    end;
    document.body.appendChild(Burst);
    if Truthy(TJSObject(window.navigator)['vibrate']) then
      try window.navigator.vibrate(18); except end;
  end;
  Entry := TJSHTMLElement(document.querySelector('.catalog-entry'));
  if Entry <> nil then Entry.classList.remove('arrive-yes', 'arrive-no');
  if How = 'yes' then Delay := 950 else Delay := 520;
  window.setTimeout(Go, Delay);
end;

procedure Narrow(Form: TJSHTMLFormElement);
var
  Go: TJSHTMLElement;
begin
  Go := TJSHTMLElement(Form.querySelector('button')); if Go <> nil then Go.hidden := True;
  Form.addEventListener('change', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      HandField(Form);
      if Truthy(TJSObject(Form)['requestSubmit']) then Form.requestSubmit else Form.submit;
    end));
end;

procedure Start;
var
  Forms: TJSNodeList;
  I: integer;
begin
  document.addEventListener('submit', TJSRawEventHandler(@Press));
  Reduce := Truthy(TJSObject(window)['matchMedia']) and window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  Leaving := False;
  window.addEventListener('pageshow', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Bursts: TJSNodeList;
      Done: TJSElement;
      N: integer;
    begin
      if not Truthy(TJSObject(E)['persisted']) then Exit;
      Leaving := False;
      document.body.classList.remove('leaving', 'leaving-yes', 'leaving-no');
      Bursts := document.querySelectorAll('.star-burst'); for N := 0 to Bursts.length - 1 do TJSElement(Bursts[N]).remove;
      Done := document.querySelector('.discover-yes.done'); if Done <> nil then Done.classList.remove('done');
    end));
  document.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    var Link: TJSHTMLAnchorElement;
    begin
      Link := TJSHTMLAnchorElement(Closest(E.target, 'a[href^="/catalog-random"]'));
      if Link <> nil then Link.href := ByHand(Link.getAttribute('href'));
    end), True);
  document.addEventListener('submit', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Form: TJSHTMLFormElement;
      Button, Count: TJSHTMLElement;
      Value: double;
    begin
      Form := TJSHTMLFormElement(Closest(E.target, '.discover-bar form'));
      if (Form = nil) or (Form.querySelector('.discover-yes') = nil) then Exit;
      E.preventDefault; HandField(Form);
      Button := TJSHTMLElement(Form.querySelector('.discover-yes'));
      if Button <> nil then
      begin
        Button.classList.add('done'); Count := TJSHTMLElement(document.querySelector('.catalog-entry .interest-count'));
        if Count <> nil then
        begin
          if Count.textContent = '' then Value := 0 else Value := Number(Count.textContent);
          Count.textContent := String(JSValue(Value + 1));
        end;
      end;
      Leave('yes', procedure begin Form.submit; end);
    end));
  document.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Link: TJSHTMLAnchorElement;
      Click: TJSMouseEvent;
    begin
      Link := TJSHTMLAnchorElement(Closest(E.target, '.discover-bar .discover-no'));
      Click := TJSMouseEvent(E);
      if (Link = nil) or Click.metaKey or Click.ctrlKey or (Click.button <> 0) then Exit;
      E.preventDefault;
      Leave('no', procedure begin window.location.href := Link.href; end);
    end));
  Forms := document.querySelectorAll('.discover-choice');
  for I := 0 to Forms.length - 1 do Narrow(TJSHTMLFormElement(Forms[I]));
  document.addEventListener('keydown', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Key: TJSKeyboardEvent;
      Target, Control: TJSHTMLElement;
    begin
      Key := TJSKeyboardEvent(E);
      if Key.altKey or Key.ctrlKey or Key.metaKey or Key.shiftKey then Exit;
      if TJSURLSearchParams.new(window.location.search).getString('discover') <> '1' then Exit;
      Target := TJSHTMLElement(E.target);
      if (Target <> nil) and (Target.isContentEditable or TJSRegExp.new('^(INPUT|TEXTAREA|SELECT)$').test(Target.tagName)) then Exit;
      if Closest(Target, '.catalog-readme, pre, table') <> nil then Exit;
      Control := TJSHTMLElement(document.querySelector('.discover-bar [data-key="' + Key.key + '"]'));
      if Control = nil then Exit;
      E.preventDefault;
      Control.click;
    end));
  document.addEventListener('error', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Picture, Thumb: TJSHTMLElement;
    begin
      Picture := TJSHTMLElement(E.target);
      if (Picture <> nil) and (Picture.tagName = 'IMG') and (Picture.closest('.catalog-icon, .catalog-thumb, .catalog-readme') <> nil) then
      begin
        Thumb := TJSHTMLElement(Picture.closest('.catalog-thumb'));
        if Thumb <> nil then Thumb.remove else Picture.remove;
      end;
    end), True);
end;

initialization
  Start;
end.
