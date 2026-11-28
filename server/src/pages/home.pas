unit home;

{ Joining, password links, signing out, copying text and filtering lists. }

{$mode objfpc}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

implementation

uses JS, Web, PageKit, PageGlobals;

function ReturnAddress: string;
var
  Back: string;
  Value: JSValue;
  Url: TJSURL;
begin
  Result := '';
  Value := TJSURLSearchParams.new(window.location.search).get('return');
  if isNull(Value) or isUndefined(Value) then Exit;
  Back := string(Value);
  if (TJSString(Back).charAt(0) <> '/') or TJSRegExp.new('^.[/\\]').test(Back) or
    TJSRegExp.new('[\u0000-\u001f\u007f\\]').test(Back) then Exit;
  try
    Url := TJSURL.new(Back, window.location.origin);
  except
    Exit;
  end;
  if (Url.origin <> window.location.origin) or (TJSString(Url.pathname).indexOf('/signin') = 0) then Exit;
  Result := Url.pathname + Url.search + Url.hash;
end;

procedure Joined;
var
  Chat: TJSElement;
begin
  if ReturnAddress <> '' then
  begin
    window.location.href := SiteBase.url(ReturnAddress);
    Exit;
  end;
  Chat := document.querySelector('.topbar nav a');
  if Chat <> nil then window.location.href := Chat.getAttribute('href')
  else window.location.href := SiteBase.url('/');
end;

procedure NewPassword(Form: TJSHTMLFormElement);

  procedure Save(E: TJSEvent); async;
  begin
    E.preventDefault;
    try
      await(Keys.setNewPassword(Form.dataset['token'], Form.dataset['name'],
        TJSHTMLInputElement(Form.elements.namedItem('password')).value));
      window.location.href := SiteBase.url('/');
    except
      window.alert(string(TJSObject(JSExceptValue)['message']));
    end;
  end;

begin
  Form.addEventListener('submit', TJSRawEventHandler(@Save));
end;

procedure Forgot(Form: TJSHTMLFormElement);
var
  Box: TJSElement;
  Opened: NativeInt;

  procedure Send(E: TJSEvent); async;
  var
    Website: TJSHTMLInputElement;
    Address: string;
    Age: NativeInt;
  begin
    E.preventDefault;
    try
      Website := TJSHTMLInputElement(Form.elements.namedItem('website'));
      Address := '';
      if Website <> nil then Address := Website.value;
      Age := -1;
      if Opened <> 0 then Age := TJSDate.now - Opened;
      window.alert(await(string, Keys.post('/api/forgot', new([
        'who', TJSHTMLInputElement(Form.elements.namedItem('who')).value,
        'website', Address, 'opened', Age]))));
    except
      window.alert(string(TJSObject(JSExceptValue)['message']));
    end;
  end;

begin
  Box := Form.closest('details');
  Opened := 0;
  if (Box <> nil) and (TJSObject(Box)['open'] = True) then Opened := TJSDate.now;
  if Box <> nil then
    Box.addEventListener('toggle', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        if (TJSObject(Box)['open'] = True) and (Opened = 0) then Opened := TJSDate.now;
      end));
  Form.addEventListener('submit', TJSRawEventHandler(@Send));
end;

// pas2js Web requires a reload argument; the browser permits none.
procedure Reload; external name 'window.location.reload';

procedure SignOut(E: TJSEvent); async;
begin
  E.preventDefault;
  await(Keys.signOut);
  Reload;
end;

procedure CopyText(Pre: TJSHTMLElement);
var
  Button: TJSHTMLButtonElement;
begin
  Button := TJSHTMLButtonElement(MakeElement('button', 'copybtn'));
  Button._type := 'button';
  Button.textContent := Word('Copy');
  Button.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      window.navigator.clipboard.writeText(Pre.textContent)._then(function(Value: JSValue): JSValue
        begin
          Button.textContent := Word('Copied');
        end);
    end));
  Pre.before(Button);
end;

procedure Filter(E: TJSEvent);
var
  Words: string;
  Items: TJSNodeList;
  I: integer;
  Item: TJSHTMLElement;
begin
  Words := TJSString(TJSString(TJSHTMLInputElement(E.currentTarget).value).toLowerCase).trim;
  Items := document.querySelectorAll('[data-find]');
  for I := 0 to Items.length - 1 do
  begin
    Item := TJSHTMLElement(Items[I]);
    Item.hidden := (Words <> '') and not TJSString(Item.dataset['find']).includes(Words);
  end;
end;

procedure Start;
var
  Nodes: TJSNodeList;
  I: integer;
  A, Find: TJSHTMLElement;
begin
  if ReturnAddress <> '' then
  begin
    Nodes := document.querySelectorAll('a.sso[href^="' + SiteBase.url('/signin-with/') + '"]');
    for I := 0 to Nodes.length - 1 do
    begin
      A := TJSHTMLElement(Nodes[I]);
      TJSHTMLAnchorElement(A).href := TJSString(SiteBase.strip(A.getAttribute('href'))).split('?')[0] +
        '?return=' + encodeURIComponent(ReturnAddress);
    end;
  end;
  Keys.bindJoinForms(TJSFunction(@Joined));
  Nodes := document.querySelectorAll('form.newpassword');
  for I := 0 to Nodes.length - 1 do NewPassword(TJSHTMLFormElement(Nodes[I]));
  Nodes := document.querySelectorAll('form.forgot');
  for I := 0 to Nodes.length - 1 do Forgot(TJSHTMLFormElement(Nodes[I]));
  Nodes := document.querySelectorAll('.signout');
  for I := 0 to Nodes.length - 1 do
    Nodes[I].addEventListener('click', TJSRawEventHandler(@SignOut));
  Nodes := document.querySelectorAll('pre.copy');
  for I := 0 to Nodes.length - 1 do CopyText(TJSHTMLElement(Nodes[I]));
  Find := TJSHTMLElement(document.getElementById('find'));
  if Find <> nil then Find.addEventListener('input', TJSRawEventHandler(@Filter));
end;

initialization
  Start;
end.
