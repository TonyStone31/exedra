unit WikiFilesPage;

{ Upload forms, deletion confirmation and the file library's picture viewer. }

{$mode objfpc}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

implementation

// pas2js Web does not re-export the event listener options type.
uses JS, WebOrWorker, Web, PageKit, PageGlobals;

function Say(const Text: string): string;
begin
  if Truthy(TJSObject(window)['t']) then Result := T(Text) else Result := Text;
end;

procedure Upload(Form: TJSHTMLFormElement);
var
  Message: TJSHTMLElement;

  procedure Send(E: TJSEvent); async;
  var
    Button: TJSHTMLButtonElement;
    Response: TJSResponse;
    Content: string;
    Conflict, Info: TJSObject;
  begin
    E.preventDefault;
    Button := TJSHTMLButtonElement(Form.querySelector('button'));
    Button.disabled := True;
    Message.textContent := '';
    try
      try
        Response := await(TJSResponse, window.fetch(Form.action, new(['method', 'POST', 'body', TJSFormData.new(Form)])));
        if not Response.ok then
        begin
          Content := await(string, Response.text);
          try
            Conflict := TJSObject(TJSJSON.parse(Content));
            if Truthy(Conflict['conflict']) then
            begin
              TJSObject(Form.elements.namedItem('name'))['value'] := Conflict['suggested'];
              Message.textContent := T('That name is already used. A free name has been filled in.');
              Exit;
            end;
          except
            // The server also returns plain text refusals.
          end;
          raise TJSError.new(Content);
        end;
        Info := await(TJSObject, Response.json);
        window.location.assign(SiteBase.url(string(Info['page'])));
      except
        Message.textContent := string(TJSObject(JSExceptValue)['message']);
      end;
    finally
      Button.disabled := False;
    end;
  end;

begin
  Message := MakeElement('p');
  Message.setAttribute('role', 'status');
  Form.appendChild(Message);
  Form.addEventListener('submit', TJSRawEventHandler(@Send));
end;

procedure ConfirmDelete(Form: TJSHTMLFormElement);
begin
  Form.addEventListener('submit', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      if not window.confirm(Form.dataset['confirm']) then E.preventDefault;
    end));
end;

procedure Viewer;
var
  Grid: TJSElement;
  Items: TJSNodeList;
  Box, Stage, Prev, Next, Close, Bar, Name, Info: TJSHTMLElement;
  Img: TJSHTMLImageElement;
  Open: TJSHTMLAnchorElement;
  At: integer;
  Back: TJSHTMLElement;
  StartX: JSValue;
  I: integer;

  procedure Show(N: integer);
  var
    A: TJSHTMLElement;
  begin
    At := (N + Items.length) mod Items.length;
    A := TJSHTMLElement(Items[At]);
    Img.src := A.dataset['view'];
    Name.textContent := A.querySelector('.wiki-file-name').textContent;
    Info.textContent := A.dataset['size'] + ' · ' + String(JSValue(At + 1)) + ' / ' + String(JSValue(Items.length));
    Open.href := SiteBase.strip(A.getAttribute('href'));
    TJSHTMLImageElement.new.src := TJSHTMLElement(Items[(At + 1) mod Items.length]).dataset['view'];
  end;

  procedure Leave;
  begin
    Box.hidden := True;
    document.documentElement.classList.remove('wiki-viewing');
    if Back <> nil then Back.focus;
  end;

  procedure Bind(A: TJSHTMLElement; N: integer);
  begin
    A.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      var
        Click: TJSMouseEvent;
      begin
        Click := TJSMouseEvent(E);
        if Click.ctrlKey or Click.metaKey or Click.shiftKey or (Click.button <> 0) then Exit;
        E.preventDefault;
        Back := A;
        Show(N);
        Box.hidden := False;
        document.documentElement.classList.add('wiki-viewing');
        Close.focus;
      end));
  end;

begin
  Grid := document.querySelector('.wiki-file-grid');
  if Grid = nil then Exit;
  Items := Grid.querySelectorAll('a[data-view]');
  if Items.length = 0 then Exit;
  Box := MakeElement('div', 'wiki-viewer');
  Box.setAttribute('role', 'dialog');
  Box.setAttribute('aria-modal', 'true');
  Box.hidden := True;
  Stage := MakeElement('div', 'wiki-viewer-stage');
  Img := TJSHTMLImageElement(MakeElement('img'));
  Img.alt := '';
  Stage.appendChild(Img);
  Prev := MakeElement('button', 'wiki-viewer-prev'); Prev.textContent := '‹';
  Next := MakeElement('button', 'wiki-viewer-next'); Next.textContent := '›';
  Close := MakeElement('button', 'wiki-viewer-close'); Close.textContent := '×';
  TJSHTMLButtonElement(Prev)._type := 'button';
  TJSHTMLButtonElement(Next)._type := 'button';
  TJSHTMLButtonElement(Close)._type := 'button';
  Prev.setAttribute('aria-label', Say('Previous'));
  Next.setAttribute('aria-label', Say('Next'));
  Close.setAttribute('aria-label', Say('Close'));
  Bar := MakeElement('div', 'wiki-viewer-bar');
  Name := MakeElement('b');
  Info := MakeElement('span');
  Open := TJSHTMLAnchorElement(MakeElement('a')); Open.textContent := Say('Open its page');
  Bar.append(Name, Info, Open);
  Box.append(Stage, Prev, Next, Close, Bar);
  document.body.appendChild(Box);
  At := 0;
  Back := nil;
  for I := 0 to Items.length - 1 do Bind(TJSHTMLElement(Items[I]), I);
  Prev.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Show(At - 1); end));
  Next.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Show(At + 1); end));
  Close.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Leave; end));
  Box.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      if (E.target = Box) or (E.target = Stage) then Leave;
    end));
  document.addEventListener('keydown', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Key: string;
    begin
      if Box.hidden then Exit;
      Key := TJSKeyboardEvent(E).key;
      if Key = 'Escape' then Leave
      else if Key = 'ArrowLeft' then Show(At - 1)
      else if Key = 'ArrowRight' then Show(At + 1)
      else Exit;
      E.preventDefault;
    end));
  StartX := Null;
  Stage.addEventListener('touchstart', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      StartX := TJSTouchEvent(E).touches[0].clientX;
    end), TJSEventListenerOptions(new(['passive', True])));
  Stage.addEventListener('touchend', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Dx: double;
    begin
      if isNull(StartX) then Exit;
      Dx := TJSTouchEvent(E).changedTouches[0].clientX - double(StartX);
      StartX := Null;
      if Abs(Dx) > 50 then
        if Dx < 0 then Show(At + 1) else Show(At - 1);
    end));
end;

procedure Start;
var
  Forms: TJSNodeList;
  I: integer;
begin
  Forms := document.querySelectorAll('.wiki-file-upload');
  for I := 0 to Forms.length - 1 do Upload(TJSHTMLFormElement(Forms[I]));
  Forms := document.querySelectorAll('form.wiki-file-delete[data-confirm]');
  for I := 0 to Forms.length - 1 do ConfirmDelete(TJSHTMLFormElement(Forms[I]));
  Viewer;
end;

initialization
  Start;
end.
