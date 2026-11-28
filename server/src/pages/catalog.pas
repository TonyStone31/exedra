unit catalog;

{ Filters refresh the catalog list; rating forms follow the server's answer. }

{$mode objfpc}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

implementation

uses JS, Web, PageKit;

var
  Form: TJSHTMLFormElement;
  Status: TJSHTMLElement;
  Running: TJSAbortController;
  Waiting: integer;

function Number(Value: JSValue): double; external name 'Number';

// JavaScript's ===: a number and the same digits as text differ.
function Same(A, B: JSValue): boolean;
begin
  Result := (jsTypeOf(A) = jsTypeOf(B)) and (A = B);
end;

function Address(AForm: TJSHTMLFormElement): string;
var
  Query: TJSURLSearchParams;
  Entries: TJSIterator;
  Entry: TJSIteratorValue;
  Pair: TJSArray;
  Name, Text, Tail: string;
begin
  Query := TJSURLSearchParams.new('');
  // pas2js Web declares entries as an array, but FormData returns an iterator.
  Entries := TJSIterator(JSValue(TJSFormData.new(AForm).entries));
  Entry := Entries.next;
  while not Entry.done do
  begin
    Pair := TJSArray(Entry.value);
    Name := string(Pair[0]);
    Text := TJSString(string(Pair[1])).trim;
    if (Text <> '') and not ((Name = 'q') and (Length(Text) < 2)) then Query.set_(Name, Text);
    Entry := Entries.next;
  end;
  Tail := Query.toString;
  Result := AForm.getAttribute('action');
  if Tail <> '' then Result := Result + '?' + Tail;
end;

procedure Refresh; async;
const
  Parts: array[0..2] of string = ('.catalog-types', '.catalog-cards', '.findpages');
var
  Url, Text: string;
  Mine: TJSAbortController;
  Answer: TJSResponse;
  Page: TJSHTMLOrXMLDocument;
  Fresh, Old: TJSElement;
  I: integer;
begin
  Url := Address(Form);
  if Running <> nil then Running.abort;
  Mine := TJSAbortController.new;
  Running := Mine;
  if Status <> nil then
    if isUndefined(Status.dataset['busy']) then Status.textContent := ''
    else Status.textContent := Status.dataset['busy'];
  try
    Answer := await(Get(Url, new(['signal', Mine.signal, 'credentials', 'same-origin'])));
    Text := await(string, Answer.text);
    if Mine <> Running then Exit;
    if not Answer.ok then
    begin
      if Status <> nil then Status.textContent := TJSString(Text).slice(0, 200);
      Exit;
    end;
    Page := TDOMParser.new.parseFromString(Text, 'text/html');
    for I := 0 to High(Parts) do
    begin
      Fresh := Page.querySelector(Parts[I]);
      Old := document.querySelector(Parts[I]);
      // pas2js Web lacks replaceWith; the parent operation has the same result.
      if (Fresh <> nil) and (Old <> nil) then Old.parentNode.replaceChild(Fresh, Old);
    end;
    window.history.replaceState(Null, '', Url);
    if Status <> nil then Status.textContent := '';
  except
    if not isNull(JSExceptValue) and not isUndefined(JSExceptValue) then
      if string(TJSObject(JSExceptValue)['name']) = 'AbortError' then Exit;
    window.location.assign(Url);
  end;
end;

procedure Show(const Entry: string; Answer: TJSObject);
var
  Forms, Buttons, Lines: TJSNodeList;
  Stars, Line: TJSHTMLElement;
  Button: TJSHTMLButtonElement;
  Clear: TJSHTMLElement;
  I, J: integer;
  Value: double;
  Lit: boolean;
begin
  Forms := document.querySelectorAll('.rate-form[data-entry="' + Entry + '"]');
  for I := 0 to Forms.length - 1 do
  begin
    Stars := TJSHTMLElement(Forms[I]);
    Buttons := Stars.querySelectorAll('.rate-star');
    for J := 0 to Buttons.length - 1 do
    begin
      Button := TJSHTMLButtonElement(Buttons[J]);
      Value := Number(Button.value);
      Lit := Value <= Number(Answer['mine']);
      // pas2js Web lacks classList.toggle(name, force).
      if Lit then Button.classList.add('on') else Button.classList.remove('on');
      if Lit then Button.textContent := '★' else Button.textContent := '☆';
      if Same(Value, Answer['mine']) then Button.setAttribute('aria-pressed', 'true')
      else Button.setAttribute('aria-pressed', 'false');
    end;
    Clear := TJSHTMLElement(Stars.querySelector('.rate-clear'));
    if Clear <> nil then Clear.hidden := Same(Answer['mine'], 0);
  end;
  Lines := document.querySelectorAll('[data-rating-summary="' + Entry + '"]');
  for I := 0 to Lines.length - 1 do
  begin
    Line := TJSHTMLElement(Lines[I]);
    if Truthy(Answer['summary']) then
      Line.textContent := string(Answer['summary'])
    else if not isUndefined(Line.dataset['none']) then Line.textContent := Line.dataset['none']
    else Line.textContent := '';
  end;
end;

procedure Rate(E: TJSEvent); async;
var
  Stars: TJSHTMLFormElement;
  Submitter: TJSHTMLButtonElement;
  Body: TJSURLSearchParams;
  Answer: TJSResponse;
  Data: TJSObject;
  Kept: TJSHTMLInputElement;
begin
  Stars := TJSHTMLFormElement(Closest(E.target, '.rate-form'));
  // pas2js Web has no SubmitEvent.submitter declaration.
  Submitter := TJSHTMLButtonElement(TJSObject(E)['submitter']);
  if (Stars = nil) or isUndefined(Submitter) or (Submitter = nil) then Exit;
  E.preventDefault;
  Body := TJSURLSearchParams.new('');
  Body.set_('stars', Submitter.value);
  try
    Answer := await(Post(Stars.action, Body, new(['Accept', 'application/json'])));
    if not Answer.ok then
    begin
      if Status <> nil then Status.textContent := TJSString(await(string, Answer.text)).slice(0, 200);
      Exit;
    end;
    Data := await(TJSObject, Answer.json);
    Show(Stars.dataset['entry'], Data);
  except
    Kept := TJSHTMLInputElement(MakeElement('input'));
    Kept._type := 'hidden';
    Kept.name := 'stars';
    Kept.value := Submitter.value;
    Stars.appendChild(Kept);
    Stars.submit;
  end;
end;

procedure Start;
var
  Go: TJSHTMLElement;
begin
  TJSObject(window)['CatalogFilters'] := new(['address', @Address]);
  Form := TJSHTMLFormElement(document.querySelector('.catalog-form'));
  Status := TJSHTMLElement(document.querySelector('.catalog-updating'));
  Running := nil;
  Waiting := 0;
  if Form <> nil then
  begin
    Go := TJSHTMLElement(Form.querySelector('.catalog-go'));
    if Go <> nil then Go.hidden := True;
    Form.addEventListener('change', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        if TJSElement(E.target).matches('select') then Refresh;
      end));
    Form.addEventListener('input', TJSRawEventHandler(procedure(E: TJSEvent)
      var
        Text: string;
      begin
        if not TJSElement(E.target).matches('input[name=q]') then Exit;
        Text := TJSString(TJSHTMLInputElement(E.target).value).trim;
        window.clearTimeout(Waiting);
        if Length(Text) = 1 then Exit;
        Waiting := window.setTimeout(procedure begin Refresh; end, 300);
      end));
    Form.addEventListener('submit', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        E.preventDefault;
        window.clearTimeout(Waiting);
        Refresh;
      end));
  end;
  document.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Link: TJSHTMLElement;
      Field: TJSHTMLInputElement;
    begin
      Link := TJSHTMLElement(Closest(E.target, '.catalog-types a'));
      if (Link = nil) or (Form = nil) then Exit;
      E.preventDefault;
      Field := TJSHTMLInputElement(Form.querySelector('[name=type]'));
      if Field <> nil then
        if isUndefined(Link.dataset['type']) then Field.value := ''
        else Field.value := Link.dataset['type'];
      Refresh;
    end));
  document.addEventListener('submit', TJSRawEventHandler(@Rate));
end;

initialization
  Start;
end.
