unit search;

{ The site's search box offers pages and words while the reader types. }

{$mode objfpc}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

procedure Start;

implementation

uses
  JS, Web, PageKit;

procedure Attach(Form: TJSHTMLFormElement);
var
  Input: TJSHTMLInputElement;
  Scope: TJSHTMLElement;
  Box: TJSHTMLElement;
  Items: TJSArray;
  Index, Asked, Timer: integer;

  procedure Close;
  begin
    Box.hidden := True;
    Items := TJSArray.new;
    Index := -1;
  end;

  procedure Select(I: integer);
  var
    N: integer;
  begin
    Index := I;
    // pas2js Web lacks classList.toggle(name, force).
    for N := 0 to Box.children.length - 1 do
      if N = I then
        TJSHTMLElement(Box.children[N]).classList.add('on')
      else
        TJSHTMLElement(Box.children[N]).classList.remove('on');
    if (I >= 0) and (I < Box.children.length) then
      TJSHTMLElement(Box.children[I]).scrollIntoView(new(['block', 'nearest']));
  end;

  procedure Pick(Item: TJSObject);
  begin
    if Truthy(Item['url']) then
    begin
      window.location.href := string(Item['url']);
      Exit;
    end;
    TJSObject(Input)['value'] := Item['text'];
    Close;
    Form.submit;
  end;

  procedure BindRow(Row: TJSHTMLElement; I: integer; Item: TJSObject);
  begin
    // pas2js needs an explicit handler type for addEventListener overloads.
    Row.addEventListener('mousemove', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        if Index <> I then Select(I);
      end));
    Row.addEventListener('mousedown', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        E.preventDefault;
        Pick(Item);
      end));
  end;

  procedure Show(List: TJSArray);
  var
    I: integer;
    Row, Part: TJSHTMLElement;
    One: TJSObject;
  begin
    Box.replaceChildren;
    Items := List;
    Box.hidden := not Truthy(JSValue(List.length));
    Index := -1;
    for I := 0 to List.length - 1 do
    begin
      One := TJSObject(List[I]);
      Row := MakeElement('div', 'item');
      Part := MakeElement('b');
      TJSObject(Part)['textContent'] := One['text'];
      Row.appendChild(Part);
      if Truthy(One['caption']) then
      begin
        Part := MakeElement('span');
        Part.textContent := string(One['caption']);
        Row.appendChild(Part);
      end;
      BindRow(Row, I, One);
      Box.appendChild(Row);
    end;
  end;

  procedure Look(const Typed: string; Turn: integer); async;
  var
    Answer: TJSResponse;
    Data: TJSObject;
    Where: string;
  begin
    Where := '';
    if Scope <> nil then
      Where := string(TJSObject(Scope)['value']);
    try
      Answer := await(window.fetch('/api/site-suggest?q=' + encodeURIComponent(Typed) + '&in=' + encodeURIComponent(Where)));
      if Answer.ok then
        Data := await(TJSObject, Answer.json)
      else
        Data := new(['offers', TJSArray.new]);
      if (Turn = Asked) and (Input.value = Typed) then
        if Truthy(Data['offers']) then Show(TJSArray(Data['offers']))
        else Show(TJSArray.new);
    except
      // no offers this time
    end;
  end;

  procedure Ask;
  var
    Typed: string;
    Turn: integer;
  begin
    Typed := Input.value;
    Inc(Asked);
    Turn := Asked;
    window.clearTimeout(Timer);
    if Length(TJSString(Typed).trim) < 2 then
    begin
      Close;
      Exit;
    end;
    Timer := window.setTimeout(procedure
      begin
        Look(Typed, Turn);
      end, 150);
  end;

begin
  Input := TJSHTMLInputElement(Form.querySelector('input[name=q]'));
  if (Input = nil) or Truthy(Input.dataset['offers']) then
    Exit;
  Input.dataset['offers'] := '1';
  Input.autocomplete := 'off';
  Scope := TJSHTMLElement(Form.querySelector('[name=in]'));
  Box := MakeElement('div', 'complete');
  Box.hidden := True;
  Form.appendChild(Box);
  Items := TJSArray.new;
  Index := -1;
  Asked := 0;
  Timer := 0;
  Input.addEventListener('input', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      Ask;
    end));
  if Scope <> nil then
    Scope.addEventListener('change', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        Ask;
      end));
  Input.addEventListener('keydown', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Key: string;
      Step: integer;
    begin
      if Box.hidden or (Items.length = 0) then
        Exit;
      Key := TJSKeyboardEvent(E).key;
      if (Key = 'ArrowDown') or (Key = 'ArrowUp') then
      begin
        E.preventDefault;
        if Key = 'ArrowDown' then Step := 1 else Step := -1;
        if Index < 0 then
        begin
          if Step > 0 then Select(0) else Select(Items.length - 1);
        end
        else
          Select((Index + Step + Items.length) mod Items.length);
      end
      else if (Key = 'Enter') and (Index >= 0) then
      begin
        E.preventDefault;
        Pick(TJSObject(Items[Index]));
      end
      else if Key = 'Escape' then
      begin
        Inc(Asked);
        Close;
      end;
    end));
  Input.addEventListener('blur', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      window.setTimeout(procedure
        begin
          Close;
        end, 150);
    end));
end;

procedure Start;
var
  Forms: TJSNodeList;
  I: integer;
begin
  Forms := document.querySelectorAll('form.site-search');
  for I := 0 to Forms.length - 1 do
    Attach(TJSHTMLFormElement(Forms[I]));
end;

initialization
  Start;
end.
