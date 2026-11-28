unit Admin_Reports;

{ The admin page's Reports tab. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, Admin_List;

procedure AdminReports(Box: TJSHTMLElement);

implementation

// Bug reports as a mail client lists mail: the newest first, unread in
// bold, a state each and a note for why; the one picked shown whole below.
procedure AdminReports(Box: TJSHTMLElement);
var
  States, Rows: TJSArray;
  View: TListView;

  function StateName(State: JSValue): JSValue;
  var
    I: NativeInt;
  begin
    for I := 0 to States.length - 1 do
      if Same(TJSArray(States[I])[0], State) then Exit(TJSArray(States[I])[1]);
    Result := State;
  end;

  procedure OpenCount;
  var
    I, Open: NativeInt;
  begin
    if not Truthy(S['adminCount']) then Exit;
    Open := 0;
    for I := 0 to Rows.length - 1 do
      if not Truthy(TJSObject(Rows[I])['done']) then Inc(Open);
    S.adminCount('Reports', Open);
  end;

  function Save(R, Fields: TJSObject; List: TListView): boolean; async;
  begin
    try
      await(JSValue, C.post('/api/bugs', TJSObject.assign(new(['id', R['id']]), Fields)));
    except
      C.failed(JSExceptValue);
      Exit(False);
    end;
    if Truthy(Fields['state']) then
    begin
      R['state'] := Fields['state'];
      R['done'] := Same(Fields['state'], 'resolved') or Same(Fields['state'], 'closed') or Same(Fields['state'], 'spam');
    end;
    if not IsUndef(Fields['note']) then R['note'] := Fields['note'];
    List.changed(R);
    OpenCount;
    Result := True;
  end;

  procedure Detail(R: TJSObject; Holder: TJSHTMLElement; List: TListView);
  var
    Head, Page, Ip, Look, Row, More, NoteForm, Note, Keep: TJSHTMLElement;
    Local: boolean;
    Shown, Address, Changed: JSValue;
    I: NativeInt;

    // the state, as a row of buttons: the one it is in pressed
    procedure StateButton(St: TJSArray);
    var
      B: TJSHTMLElement;
    begin
      if Same(R['state'], St[0]) then B := C.el('button', 'on', St[1]) else B := C.el('button', '', St[1]);
      TJSObject(B)['type'] := 'button';
      if Same(R['state'], St[0]) then B.setAttribute('aria-pressed', 'true') else B.setAttribute('aria-pressed', 'false');
      B.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
        begin
          if not Same(R['state'], St[0]) then Save(R, new(['state', St[0]]), List);
        end));
      Row.appendChild(B);
    end;

    procedure SaveNote(E: TJSEvent); async;
    begin
      E.preventDefault;
      if await(boolean, Save(R, new(['note', TJSObject(Note)['value']]), List)) then C.toast(T('Saved.'));
    end;

  begin
    Head := C.el('div', 'lv-detail-head');
    TKit(Head).add(C.el('b', '', R['name']), C.el('span', 'dim', DateTimeText(R['at'])));
    Holder.appendChild(Head);
    // the page the reporter named: a link only when it is a path of this site
    Local := Regex('^\/(?!\/)', Either(R['page'], ''));
    if Local then Page := C.el('a', '', R['page']) else Page := C.el('span', '', R['page']);
    if Local then
    begin
      TJSObject(Page)['href'] := R['page'];
      TJSObject(Page)['target'] := '_blank';
      TJSObject(Page)['rel'] := 'noopener';
    end;
    Ip := C.el('span');
    if Truthy(R['ip']) then
    begin
      TKit(Ip).add(string(R['ip']) + ' ');
      Look := C.el('button', 'small-link', T('Look up'));
      TJSObject(Look)['type'] := 'button';
      Look.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin LookUpAddress(R['ip']); end));
      Ip.appendChild(Look);
    end;
    if Truthy(R['page']) then Shown := Page else Shown := '';
    if Truthy(R['ip']) then Address := Ip else Address := '';
    if Truthy(R['updated']) then Changed := DateTimeText(R['updated']) else Changed := '';
    C.facts(Holder, Items(Items(T('Page'), Shown), Items(T('Address'), Address), Items(T('Changed'), Changed)));
    Row := C.el('div', 'lv-actions');
    Row.appendChild(C.el('span', 'dim', T('State') + ':'));
    for I := 0 to States.length - 1 do StateButton(TJSArray(States[I]));
    Holder.appendChild(Row);
    Holder.appendChild(C.el('div', 'bugtext', R['text']));
    if Truthy(R['info']) then
    begin
      More := C.el('details', 'buginfo-box');
      More.appendChild(C.el('summary', '', T('What the browser sent with it')));
      More.appendChild(C.el('pre', 'buginfo', R['info']));
      Holder.appendChild(More);
    end;
    NoteForm := C.el('form', 'lv-note');
    Note := C.el('textarea');
    TJSObject(Note)['value'] := Either(R['note'], '');
    TJSObject(Note)['rows'] := 2;
    TJSObject(Note)['placeholder'] := T('A note for the admins: what was done, or why not');
    Note.setAttribute('aria-label', T('Note'));
    Keep := C.el('button', '', T('Save the note'));
    TKit(NoteForm).add(Note, Keep);
    NoteForm.addEventListener('submit', TJSRawEventHandler(@SaveNote));
    Holder.appendChild(NoteForm);
    // opened is read, as in a mail client
    if Same(R['state'], 'new') then Save(R, new(['state', 'read']), List);
  end;

  procedure Load; async;
  var
    List: TJSArray;
    R: TJSObject;
    I: NativeInt;
  begin
    try
      List := await(TJSArray, C.get('/api/bugs'));
      Rows := TJSArray.new;
      for I := 0 to List.length - 1 do
      begin
        R := TJSObject(List[I]);
        if not Truthy(R['state']) then
          if Truthy(R['done']) then R['state'] := 'resolved' else R['state'] := 'new';
        Rows.push(R);
      end;
      View.set_(Rows);
      OpenCount;
    except
      View.failed(TJSObject(JSExceptValue)['message']);
    end;
  end;

begin
  States := Items(Items('new', T('New')), Items('read', T('Read')), Items('needs-info', T('Needs more information')),
    Items('resolved', T('Resolved')), Items('closed', T('Closed')), Items('spam', T('Spam')));
  Rows := TJSArray.new;
  View := ListView(Box, TListOptions(new([
    'id', 'reports', 'key', TRowValue(function(R: TJSObject): JSValue begin Result := Str(R['id']); end), 'sort', '-at', 'csv', 'reports',
    'search', T('Search the reports'),
    'columns', Items(
      new(['key', 'at', 'title', T('Sent'), 'down', True, 'cell', TRowValue(function(R: TJSObject): JSValue
        var
          Span: TJSHTMLElement;
        begin
          Span := C.el('span', '', C.ago(R['at']));
          Span.title := DateTimeText(R['at']);
          Result := Span;
        end)]),
      new(['key', 'name', 'title', T('From')]),
      new(['key', 'text', 'title', T('Report'), 'cls', 'lv-text', 'cell', TRowValue(function(R: TJSObject): JSValue
        begin
          Result := TJSString(TJSString(R['text']).replace(TJSRegExp.new('\s+', 'g'), ' ')).slice(0, 120);
        end)]),
      new(['key', 'page', 'title', T('Page'), 'wide', True, 'cls', 'lv-text', 'cell', TRowValue(function(R: TJSObject): JSValue
        begin
          Result := TJSString(R['page']).replace(TJSRegExp.new('^https?:\/\/[^/]+'), '');
        end)]),
      new(['key', 'state', 'title', T('State'), 'value', TRowValue(function(R: TJSObject): JSValue begin Result := StateName(R['state']); end),
        'cell', TRowValue(function(R: TJSObject): JSValue
        begin
          if Same(R['state'], 'new') then Result := C.chip(StateName(R['state']), 'new')
          else if Truthy(R['done']) then Result := C.chip(StateName(R['state']), '')
          else Result := C.chip(StateName(R['state']), 'open');
        end)])),
    'filters', Items(new(['key', 'state', 'title', T('State'), 'all', T('Every state'), 'value', 'open',
      'options', Items(Items('open', T('Not resolved or closed'))).concat(States),
      'test', TRowTest(function(R: TJSObject; V: string): JSValue
        begin
          if V = 'open' then Result := not Truthy(R['done']) else Result := Same(R['state'], V);
        end)])),
    'rowClass', TRowValue(function(R: TJSObject): JSValue
      var
        Cls: string;
      begin
        if Same(R['state'], 'new') then Cls := 'unread' else Cls := '';
        if Truthy(R['done']) then Cls := Cls + ' done';
        Result := Cls;
      end),
    'noun', TCountText(function(N: JSValue): JSValue begin Result := TN(N, '%d report', '%d reports'); end), 'empty', T('No reports yet.'),
    'detail', @Detail])));
  Load;
end;

end.
