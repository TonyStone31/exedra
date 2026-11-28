unit Admin_Settings;

{ The settings boxes of the admin page: the site's own and each part's, with the
  file scanner's and the search index's panels under their sections. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, Admin_List;

procedure AdminSettings(Box: TJSHTMLElement; Data: TJSObject; Only: TOnly; Key: JSValue);
procedure FileScanning(Form: TJSHTMLElement);
procedure SearchIndex(Form: TJSHTMLElement);

implementation

type
  // new URLSearchParams(source) and new FormData(form): the Web unit has neither with these arguments.
  TParams = class external name 'URLSearchParams'(TJSObject)
    constructor new(Source: JSValue);
  end;
  TFormFields = class external name 'FormData'(TJSObject)
    constructor new(Form: JSValue);
  end;
  // one section of a settings box
  TSection = class external name 'Object'(TJSObject)
    group: JSValue;
    button, form: TJSHTMLElement;
    fields: TJSArray;
  end;

function SiteUrl(const Address: string): string; external name 'window.SiteBase.url';

// Only says which groups of settings this box holds; key keeps each box's
// last section apart.
procedure AdminSettings(Box: TJSHTMLElement; Data: TJSObject; Only: TOnly; Key: JSValue);
var
  Layout, Side, Search, Nav, Picker, Panel, Empty: TJSHTMLElement;
  Groups: TJSMap;
  Settings, Sections, Pairs: TJSArray;
  S: TJSObject;
  Chosen: JSValue;
  Kept: string;
  I: NativeInt;

  procedure Show;
  var
    Query: string;
    Found, Match: boolean;
    Section: TSection;
    Field: TJSObject;
    Matches, N, M: NativeInt;
  begin
    Query := TJSString(TJSString(TJSObject(Search)['value']).trim).toLowerCase;
    Found := False;
    for N := 0 to Sections.length - 1 do
    begin
      Section := TSection(Sections[N]);
      Matches := 0;
      for M := 0 to Section.fields.length - 1 do
      begin
        Field := TJSObject(Section.fields[M]);
        Match := (Query = '') or TJSString(Field['words']).includes(Query);
        TJSHTMLElement(Field['label']).hidden := not Match;
        // Hidden search results must not be submitted or block number validation.
        TJSObject(Field['input'])['disabled'] := not Match;
        if Match then Inc(Matches);
      end;
      if Query <> '' then Section.form.hidden := Matches = 0 else Section.form.hidden := not Same(Section.group, Chosen);
      Toggle(Section.button, 'on', Same(Section.group, Chosen));
      if Same(Section.group, Chosen) then Section.button.setAttribute('aria-pressed', 'true')
      else Section.button.setAttribute('aria-pressed', 'false');
      if not Section.form.hidden then Found := True;
    end;
    TJSObject(Picker)['value'] := Chosen;
    Empty.hidden := Found;
  end;

  procedure Select(Group: JSValue);
  begin
    Chosen := Group;
    C.shared(Kept, Group);
    TJSObject(Search)['value'] := '';
    Show;
  end;

  procedure AddSection(Group: JSValue; Settings: TJSArray);
  var
    Button, Option, Form, Save: TJSHTMLElement;
    Fields: TJSArray;
    N: NativeInt;

    procedure AddField(S: TJSObject);
    var
      FieldLabel, Caption, Input, O: TJSHTMLElement;
      Choices: TJSArray;
      Names: TJSArray;
      Long: boolean;
      M: NativeInt;
    begin
      FieldLabel := C.el('label');
      Caption := C.el('span', 'setting-caption', T(S['caption']));
      Caption.appendChild(C.el('small', 'hint', T(S['name'])));
      FieldLabel.appendChild(Caption);
      if Same(S['kind'], 'yesno') or TJSString(S['kind']).startsWith('choice:') then
      begin
        Input := C.el('select');
        if Same(S['kind'], 'yesno') then Choices := Items(Items('1', T('yes')), Items('0', T('no')))
        else
        begin
          Choices := TJSArray.new;
          Names := TJSArray(TJSString(TJSString(S['kind']).slice(7)).split('|'));
          for M := 0 to Names.length - 1 do Choices.push(Items(Names[M], T(Names[M])));
        end;
        for M := 0 to Choices.length - 1 do
        begin
          O := C.el('option', '', TJSArray(Choices[M])[1]);
          TJSObject(O)['value'] := TJSArray(Choices[M])[0];
          Input.appendChild(O);
        end;
      end
      else
      begin
        // a long line (a list of emoji, of addresses) gets the column's
        // whole width and wraps; it stays one line: Enter saves, as in a box
        Long := Same(S['kind'], 'longtext');
        if Long then Input := C.el('textarea') else Input := C.el('input');
        if Long then
        begin
          FieldLabel.classList.add('wide');
          TJSObject(Input)['rows'] := 3;
          Input.addEventListener('keydown', TJSRawEventHandler(procedure(E: TJSEvent)
            begin
              if TJSKeyboardEvent(E).key = 'Enter' then
              begin
                E.preventDefault;
                TJSHTMLFormElement(Form).requestSubmit;
              end;
            end));
          Input.addEventListener('input', TJSRawEventHandler(procedure(E: TJSEvent)
            begin
              if TJSString(TJSObject(Input)['value']).includes(#10) then
                TJSObject(Input)['value'] := TJSString(TJSObject(Input)['value']).replace(TJSRegExp.new('\s*\n\s*', 'g'), ' ');
            end));
        end;
        if Same(S['kind'], 'number') then TJSObject(Input)['type'] := 'number';
        // No browser autofill: its suggestion box holds the page's scrolling
        // while it is open, and these are the site's settings, not the admin's own details.
        TJSObject(Input)['autocomplete'] := 'off';
        TJSObject(Input)['spellcheck'] := False;
        // Secrets never come back from the server: an empty box keeps the one set.
        // A text box masked by CSS, not a password box, so no password manager offers itself.
        if Same(S['kind'], 'secret') then
        begin
          Input.classList.add('secret');
          Input.setAttribute('data-1p-ignore', '');
          Input.setAttribute('data-lpignore', 'true');
          if Truthy(S['set']) then TJSObject(Input)['placeholder'] := T('set (empty keeps it)')
          else TJSObject(Input)['placeholder'] := T('not set');
        end;
      end;
      TJSObject(Input)['name'] := S['name'];
      TJSObject(Input)['value'] := S['value'];
      FieldLabel.appendChild(Input);
      Form.appendChild(FieldLabel);
      Fields.push(new(['label', FieldLabel, 'input', Input,
        'words', TJSString(Items(S['caption'], T(S['caption']), S['name']).join(' ')).toLowerCase]));
    end;

    procedure Submit(E: TJSEvent); async;
    begin
      E.preventDefault;
      TJSObject(Save)['disabled'] := True;
      try
        try
          C.toast(await(JSValue, C.post('/api/admin/settings', TParams.new(TFormFields.new(Form)))));
        except
          C.failed(JSExceptValue);
        end;
      finally
        TJSObject(Save)['disabled'] := False;
      end;
    end;

  begin
    Button := C.el('button');
    TJSObject(Button)['type'] := 'button';
    TKit(Button).add(C.el('span', '', T(Group)), C.chip(T('%d', Settings.length)));
    Button.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Select(Group); end));
    Nav.appendChild(Button);
    Option := C.el('option', '', T('%s (%d)', T(Group), Settings.length));
    TJSObject(Option)['value'] := Group;
    Picker.appendChild(Option);
    Form := C.el('form', 'settings settings-section');
    TJSObject(Form)['autocomplete'] := 'off';
    Form.appendChild(C.el('h3', '', T(Group)));
    if Same(Group, 'Sign-in') then
      Form.appendChild(C.el('p', 'hint', T('Make an OAuth app at each provider and give it this return address: %s followed by its name: github, gitlab, codeberg, google or microsoft. A provider shows on the sign-in page once its id and secret are here and it is switched on.',
        window.location.origin + SiteUrl('/_oauth/'))));
    Fields := TJSArray.new;
    for N := 0 to Settings.length - 1 do AddField(TJSObject(Settings[N]));
    Save := C.el('button', 'primary', T('Save settings'));
    TJSObject(Save)['type'] := 'submit';
    Form.appendChild(Save);
    if Same(Group, 'File scanning') then FileScanning(Form);
    if Same(Group, 'Search') then SearchIndex(Form);
    Form.addEventListener('submit', TJSRawEventHandler(@Submit));
    Panel.appendChild(Form);
    Sections.push(new(['group', Group, 'button', Button, 'form', Form, 'fields', Fields]));
  end;

begin
  Layout := C.el('div', 'settings-layout');
  Side := C.el('div', 'settings-side');
  Search := C.el('input', 'lv-find');
  TJSObject(Search)['type'] := 'search';
  TJSObject(Search)['autocomplete'] := 'off';
  TJSObject(Search)['placeholder'] := T('Search settings');
  Search.setAttribute('aria-label', T('Search settings'));
  Nav := C.el('nav', 'subtabs settings-nav');
  Nav.setAttribute('aria-label', T('Settings sections'));
  Picker := C.el('select', 'lv-filter settings-picker');
  Picker.setAttribute('aria-label', T('Settings section'));
  Panel := C.el('div', 'settings-panels');
  Empty := C.el('p', 'hint', T('No settings match your search.'));
  Empty.hidden := True;
  Panel.appendChild(Empty);
  TKit(Side).add(Search, Nav, Picker);
  TKit(Layout).add(Side, Panel);
  Box.appendChild(Layout);

  Groups := TJSMap.new;
  Settings := TJSArray(Data['settings']);
  for I := 0 to Settings.length - 1 do
  begin
    S := TJSObject(Settings[I]);
    if Assigned(Only) and not Only(S['group']) then Continue;
    if not Groups.has(S['group']) then Groups.&set(S['group'], TJSArray.new);
    TJSArray(Groups.get(S['group'])).push(S);
  end;
  if Truthy(Key) then Kept := 'admin-settings-section-' + string(Key) else Kept := 'admin-settings-section';
  Chosen := C.shared(Kept);
  if not Groups.has(Chosen) then Chosen := Groups.keys.next.value;
  Sections := TJSArray.new;

  Pairs := TJSArray.from(Groups);
  for I := 0 to Pairs.length - 1 do AddSection(TJSArray(Pairs[I])[0], TJSArray(TJSArray(Pairs[I])[1]));
  Search.addEventListener('input', TJSRawEventHandler(@Show));
  Picker.addEventListener('change', TJSRawEventHandler(procedure(E: TJSEvent) begin Select(TJSObject(Picker)['value']); end));
  Show;
end;

// Under the File scanning settings: whether the scanner runs, a test with
// the EICAR file, and the uploads it stopped or could not check.
procedure FileScanning(Form: TJSHTMLElement);
var
  Status, Test, Said, List, Panel: TJSHTMLElement;
  First: JSValue;

  function Show: JSValue; async;
  var
    D, F: TJSObject;
    Files, Rows: TJSArray;
    Ready, Error, Result_: JSValue;
    N: NativeInt;
  begin
    D := await(TJSObject, C.get('/api/admin/scans'));
    if Truthy(D['ready']) then Ready := T('Scanner ready: %s', Either(D['version'], '?')) else Ready := D['problem'];
    if Truthy(D['last_error']) then Error := T('Last error, %s: %s', DateTimeText(D['last_error_at']), D['last_error']) else Error := '';
    if Truthy(D['on']) then Status.textContent := TJSString(Items(T('Scanning is on.'), Ready, Error).join(' ')).trim
    else Status.textContent := TJSString(Items(T('Scanning is off.'), Ready, Error).join(' ')).trim;
    TKit(List).fill(C.el('h3', '', T('Files stopped or not checked')));
    Files := TJSArray(D['files']);
    if Files.length = 0 then
    begin
      List.appendChild(C.el('p', 'hint', T('Nothing yet.')));
      Exit;
    end;
    Rows := TJSArray.new;
    for N := 0 to Files.length - 1 do
    begin
      F := TJSObject(Files[N]);
      if Truthy(F['found']) then Result_ := T('refused, found %s', F['names'])
      else if Truthy(F['kept']) then Result_ := T('kept unchecked: %s', F['names'])
      else Result_ := T('refused unchecked: %s', F['names']);
      Rows.push(Items(DateTimeText(F['when']), F['member'], F['route'], F['name'], C.sizeText(F['size']), Result_, F['sha256']));
    end;
    AdminTable(List, Items(T('When'), T('Member'), T('Where'), T('File'), T('Size'), T('Result'), 'SHA-256'), Rows);
  end;

  procedure TestClick(E: TJSEvent); async;
  var
    R: TJSObject;
  begin
    TJSObject(Test)['disabled'] := True;
    Said.textContent := '';
    try
      try
        R := TJSObject(TJSJSON.parse(await(string, C.post('/api/admin/scans/test', TJSObject.new))));
        if Truthy(R['caught']) then Said.textContent := T('The scanner caught the test file: %s', R['words'])
        else if Truthy(R['error']) then Said.textContent := T('The scanner could not check the test file: %s', R['words'])
        else Said.textContent := T('The scanner did not catch the test file.');
        if Truthy(R['caught']) and not Truthy(R['limits']) then
          Said.textContent := Said.textContent + ' ' + T('It does not report the files it stops reading at a limit, so those would count as clean: set AlertExceedsMax yes in clamd.conf.');
        await(JSValue, Show);
      except
        C.failed(JSExceptValue);
      end;
    finally
      TJSObject(Test)['disabled'] := False;
    end;
  end;

begin
  Status := C.el('p', 'hint');
  Status.setAttribute('role', 'status');
  Test := C.el('button', '', T('Test the scanner'));
  TJSObject(Test)['type'] := 'button';
  Said := C.el('p');
  Said.setAttribute('role', 'status');
  List := C.el('div', 'scan-list');
  Panel := C.el('div', 'scan-panel');
  TKit(Panel).add(C.el('h3', '', T('The scanner')), Status,
    C.el('p', 'hint', T('The test scans the EICAR test file, a harmless file that every virus scanner reports.')), Test, Said, List);
  Form.appendChild(Panel);
  Test.addEventListener('click', TJSRawEventHandler(@TestClick));
  First := Show;
  TJSPromise(First).catch(TJSPromiseResolver(C['failed']));
end;

// Under the Search settings: how each module's index stands, read again
// while one is being built.
procedure SearchIndex(Form: TJSHTMLElement);
var
  Panel: TJSHTMLElement;
  First: JSValue;

  function Show: JSValue; async;
  var
    D, P: TJSObject;
    Parts: TJSArray;
    Count, Words: string;
    Line: TJSHTMLElement;
    Builds: boolean;
    N: NativeInt;
  begin
    D := await(TJSObject, C.get('/api/admin/search'));
    TKit(Panel).fill(C.el('h3', '', T('Search index')));
    if Truthy(D['cgi']) then
    begin
      Panel.appendChild(C.el('p', 'hint', T('This program runs as CGI and keeps no index: the database search answers.')));
      Exit;
    end;
    Parts := TJSArray(D['parts']);
    if Parts.length = 0 then Panel.appendChild(C.el('p', 'hint', T('Nothing here is searched through the index yet.')));
    Builds := False;
    for N := 0 to Parts.length - 1 do
    begin
      P := TJSObject(Parts[N]);
      Count := LocaleNumber(P['documents']);
      if Same(P['state'], 'ready') then Words := T('%s documents, ready', Count)
      else if Same(P['state'], 'building') then Words := T('building, %s', Either(P['step'], ''))
      else if Same(P['state'], 'failed') then Words := T('failed: %s', P['problem'])
      else if Same(P['state'], 'waiting') then Words := T('waiting to be built')
      else Words := T('off');
      if Truthy(P['queued']) then Words := Words + ', ' + T('%s changes waiting', LocaleNumber(P['queued']));
      if Truthy(P['refused']) then Words := Words + ', ' + T('%s found but not shown', LocaleNumber(P['refused']));
      Line := C.el('p', 'hint', string(P['part']) + ': ' + Words);
      Line.setAttribute('role', 'status');
      Panel.appendChild(Line);
      if Same(P['state'], 'building') then Builds := True;
    end;
    if Truthy(TJSObject(Form)['isConnected']) and Builds then
      window.setTimeout(procedure
        var
          Again: JSValue;
        begin
          Again := Show;
          TJSPromise(Again).catch(TJSPromiseResolver(C['failed']));
        end, 2000);
  end;

begin
  Panel := C.el('div', 'scan-panel');
  Form.appendChild(Panel);
  First := Show;
  TJSPromise(First).catch(TJSPromiseResolver(C['failed']));
end;

end.
