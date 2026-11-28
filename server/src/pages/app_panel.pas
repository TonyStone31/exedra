unit app_panel;

{ The site's page: the panel at its side, and the report of a problem
  written in it. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, app_helpers;

function OpenPanel(Title: JSValue; Cls: JSValue = undefined): TEl;
procedure OpenReport;
procedure ClosePanel;

implementation

uses app_router, app_notify;

// ------------------------------------------------------------------ panel

function OpenPanel(Title: JSValue; Cls: JSValue): TEl;
var
  Head, Close: TEl;
begin
  // On a phone the room list slides over the chat, and the panel fills the
  // screen under it: a panel opened from the list closes the list.
  Body.classList.remove('menu');
  Panel.hidden := False;
  if Truthy(Cls) then TJSObject(Panel)['className'] := Cls else Panel.className := '';
  Panel.replaceChildren;
  Head := El('header');
  Head.appendChild(El('h2', '', Title));
  Close := IconButton('close', T('Close'));
  Close.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      ClosePanel;
      if TJSString(SiteBase.path).startsWith('/m/') and Truthy(S.room) then window.history.replaceState(TJSObject.new, '', '/p/' + Enc(S.room));
      LayerClosed;
    end));
  Head.appendChild(Close);
  Panel.appendChild(Head);
  Body.classList.add('withpanel');
  LayerOpened;
  Result := Panel;
end;

// Report a problem: what they write, and what the page knows.
procedure OpenReport;
var
  Box, Form, Words, Send: TEl;

  procedure Submit(E: TJSEvent); async;
  var
    Lines: TJSArray;
    Theme, Name: JSValue;
    Where: string;
  begin
    E.preventDefault;
    // The server mails the report before it answers, so say it is on its way.
    Send.disabled := True;
    Send.textContent := T('Sending…');
    Words.disabled := True;
    Theme := TJSObject(TJSHTMLElement(document.documentElement).dataset)['theme'];
    if not Truthy(Theme) then Theme := 'auto';
    Name := Me.name;
    if not Truthy(Name) then Name := 'no';
    if Installed then Where := ', installed app' else Where := ', browser tab';
    Lines := TJSArray.new;
    Lines.push('browser: ' + window.navigator.userAgent);
    Lines.push('screen: ' + String(JSValue(window.innerWidth)) + 'x' + String(JSValue(window.innerHeight)) + ' at ' + String(JSValue(window.devicePixelRatio)));
    Lines.push('theme: ' + String(Theme));
    Lines.push('signed in: ' + String(Name));
    Lines.push('notifications: ' + NotifyState + Where);
    Lines.push('last errors:');
    if Trail.length > 0 then Lines := Lines.concat(Trail) else Lines := Lines.concat(TJSArray.new('none'));
    try
      Toast(await(JSValue, Post('/api/bug', new(['text', Words.value, 'page', SiteBase.path, 'info', Lines.join(#10)]))));
      ClosePanel;
      LayerClosed;
    except
      Failed(JSExceptValue);
    end;
    Send.disabled := False;
    Send.textContent := T('Send the report');
    Words.disabled := False;
  end;

begin
  Box := OpenPanel(T('Report a problem'), 'report');
  Form := El('form', 'reportform');
  Words := El('textarea');
  Words.rows := 8;
  Words.maxLength := 4000;
  Words.placeholder := T('What went wrong, or what looked wrong? What were you doing?');
  Send := El('button', 'primary', T('Send the report'));
  Form.add(Words, El('p', 'hint', T('Sent along: this page''s address, your browser and screen size, and the last errors this page showed. Nothing else.')), Send);
  Form.addEventListener('submit', TJSRawEventHandler(@Submit));
  Box.appendChild(Form);
  Words.focus;
end;

procedure ClosePanel;
begin
  Panel.hidden := True;
  Panel.replaceChildren;
  S.thread := 0;
  S.threadMessages.clear;
  Body.classList.remove('withpanel');
end;

end.
