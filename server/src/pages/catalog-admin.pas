unit CatalogAdminPage;

{ Catalog entries, reports, pictures, activity and totals in the admin shell. }

{$mode objfpc}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

implementation

uses JS, Web, PageKit, PageGlobals;

type
  TItemValue = reference to function(Item: TJSObject): JSValue;
  TFilterTest = reference to function(R: TJSObject; V: string): JSValue;
  TCountText = reference to function(N: NativeInt): string;

// The shell's words and numbers take a value as the server sent it.
function Say(English: JSValue): string; varargs; external name 'window.t';
function Count(N: JSValue; const One, Many: string): string; varargs; external name 'window.tn';
function Number(Value: JSValue): double; external name 'Number';

// JavaScript's ===: a number and the same digits as text differ.
function Same(A, B: JSValue): boolean;
begin
  Result := (jsTypeOf(A) = jsTypeOf(B)) and (A = B);
end;

// JavaScript's +, which joins when either side is text.
function Plus(A, B: JSValue): JSValue; assembler;
asm
  return A + B;
end;

function El(const Tag: string; const Cls: string = ''; Text: JSValue = undefined): TJSHTMLElement;
begin
  Result := SiteShell.el(Tag, Cls, Text);
end;

function OrValue(Item: TJSObject; const Key: string; Fallback: JSValue): JSValue;
begin
  Result := Item[Key]; if not Truthy(Result) then Result := Fallback;
end;

function ArrayOrEmpty(Value: JSValue): TJSArray;
begin
  if Truthy(Value) then Result := TJSArray(Value) else Result := TJSArray.new;
end;

function First(Value: JSValue): TJSObject;
var
  Items: TJSArray;
begin
  Items := ArrayOrEmpty(Value);
  if (Items.length > 0) and Truthy(Items[0]) then Result := TJSObject(Items[0]) else Result := TJSObject.new;
end;

procedure Table(Holder: TJSHTMLElement; const Title: string; Headings, Rows: TJSArray);
begin
  Holder.appendChild(El('h2', '', Title)); SiteShell.adminTable(Holder, Headings, Rows);
end;

procedure Activity(Holder: TJSHTMLElement); forward;

procedure Catalog(Holder: TJSHTMLElement);
var
  More, Kinds, Works, Shows, Tabs: TJSArray;
  Subs: TPageTabs;
  Tiles, Numbers, Notice, AddPlace: TJSHTMLElement;
  Can: TJSArray;
  Drawn, Counts, AddOffered: boolean;
  Entries: TPageList;
  I: integer;
  Extra: TJSObject;

  function Caption(V: JSValue): JSValue;
  var
    Words: TJSObject;
  begin
    Words := TJSObject(SiteShell.extras['catalogCaptions']);
    if Truthy(Words) and Truthy(Words[string(V)]) then Result := Words[string(V)]
    else Result := T(TJSString(TJSString(V).charAt(0)).toUpperCase + TJSString(V).slice(1));
  end;

  procedure Choices(Data: TJSObject);
  var
    Options: TJSObject;
    Values: TJSArray;
    N: integer;
  begin
    if not Truthy(Data['choices']) or (Kinds.length > 0) or (Works.length > 0) then Exit;
    Options := TJSObject(Data['choices']); Values := ArrayOrEmpty(Options['kind']);
    for N := 0 to Values.length - 1 do Kinds.push(TJSArray.new(Values[N], Caption(Values[N])));
    Values := ArrayOrEmpty(Options['works_with']);
    for N := 0 to Values.length - 1 do Works.push(TJSArray.new(Values[N], Caption(Values[N])));
  end;

  function Named(List: TJSArray; V: JSValue): JSValue;
  var
    N: integer;
    Pair: TJSArray;
  begin
    Result := V;
    for N := 0 to List.length - 1 do begin Pair := TJSArray(List[N]); if Same(Pair[0], V) then begin Result := Pair[1]; Exit; end; end;
  end;

  function Flagged(Item: TJSObject): boolean;
  begin
    Result := TJSRegExp.new('^Flagged for review').test(string(OrValue(Item, 'hidden_note', '')));
  end;

  function NumberRows(List: TJSArray): TJSArray;
  var N: integer; Item: TJSObject;
  begin
    Result := TJSArray.new;
    for N := 0 to List.length - 1 do begin Item := TJSObject(List[N]); Result.push(TJSArray.new(Say(Item['name']), Item['count'])); end;
  end;

  procedure Summary(Data: TJSObject);
  var
    N: integer;
    HasFlagged, HasStatus: boolean;
    Statuses: TJSArray;
  begin
    Tiles.replaceChildren;
    SiteShell.stat(Tiles, Data['total'], T('Entries'));
    SiteShell.stat(Tiles, Data['hidden'], T('Hidden'));
    if Truthy(Data['reported']) then SiteShell.stat(Tiles, OrValue(Data, 'reported', 0), T('Reported by members'), '', 'warn')
    else SiteShell.stat(Tiles, OrValue(Data, 'reported', 0), T('Reported by members'), '', '');
    if Truthy(Data['flagged']) then
    begin
      SiteShell.stat(Tiles, Data['flagged'], T('Flagged for review'));
      HasFlagged := False;
      for N := 0 to Shows.length - 1 do if TJSArray(Shows[N])[0] = 'flagged' then HasFlagged := True;
      if not HasFlagged then Shows.push(TJSArray.new('flagged', T('Flagged for review')));
    end;
    if Drawn then Exit;
    Drawn := True;
    Table(Numbers, T('By kind'), TJSArray.new(T('Kind'), T('Entries')), NumberRows(TJSArray(Data['kinds'])));
    if TJSArray(Data['sources']).length > 0 then Table(Numbers, T('By source'), TJSArray.new(T('Source'), T('Entries')), NumberRows(TJSArray(Data['sources'])));
    Statuses := TJSArray(Data['statuses']); HasStatus := False;
    for N := 0 to Statuses.length - 1 do if TJSObject(Statuses[N])['name'] <> 'unknown' then HasStatus := True;
    if HasStatus then Table(Numbers, T('By status'), TJSArray.new(T('Status'), T('Entries')), NumberRows(Statuses));
  end;

  function Was(Item: TJSObject; const Key: string): JSValue;
  begin
    if Key <> 'kind' then begin Result := OrValue(Item, Key, ''); Exit; end;
    if Kinds.length > 0 then begin Result := OrValue(Item, 'kind', 'unknown'); Exit; end;
    if Truthy(Item['kind']) and (Item['kind'] <> 'unknown') then Result := Item['kind'] else Result := '';
  end;

  procedure EntryFields(Form: TJSHTMLElement; Fields, Item: TJSObject);

    procedure Field(const Key, Caption: string; Kind: JSValue = '');
    var
      Label_, Input: TJSHTMLElement;
      Option: TJSHTMLOptionElement;
      N: integer;
      Pair: TJSArray;
    begin
      Label_ := El('label', '', Caption);
      if isArray(Kind) then Input := El('select') else if Kind = 'area' then Input := El('textarea') else Input := El('input');
      TJSObject(Input)['name'] := Key;
      if isArray(Kind) then
        for N := 0 to TJSArray(Kind).length - 1 do
        begin Pair := TJSArray(TJSArray(Kind)[N]); Option := TJSHTMLOptionElement(El('option', '', Pair[1])); Option.value := string(Pair[0]); Input.appendChild(Option); end
      else if Kind = 'area' then TJSObject(Input)['rows'] := 3
      else if Kind = 'file' then begin TJSObject(Input)['type'] := 'file'; TJSObject(Input)['accept'] := 'image/png,image/jpeg,image/gif,image/webp'; end
      else if Key = 'url' then TJSObject(Input)['maxLength'] := 2000
      else if Key = 'kind' then TJSObject(Input)['maxLength'] := 20 else TJSObject(Input)['maxLength'] := 300;
      if Kind <> 'file' then TJSObject(Input)['value'] := Was(Item, Key);
      Fields[Key] := Input; Label_.appendChild(Input); Form.appendChild(Label_);
    end;

  begin
    Field('title', T('Title')); Field('url', T('Where it lives (an address), if it lives somewhere'));
    Field('summary', T('What it is, in a few lines'), 'area');
    if Kinds.length > 0 then Field('kind', T('Kind'), Kinds) else Field('kind', T('Kind'));
    if (Works.length > 0) and Truthy(Item['id']) then Field('works_with', T('Works with'), Works);
    Field('categories', T('Categories (comma separated)')); Field('license', T('License, if it has one'));
    Field('picture', T('Picture (PNG, JPEG, GIF or WebP)'), 'file');
    TJSObject(Fields['title'])['required'] := True;
    TJSObject(Fields['url'])['type'] := 'url'; TJSObject(Fields['url'])['placeholder'] := 'https://';
  end;

  procedure SendPicture(Id: JSValue; Input: TJSHTMLInputElement); async;
  var
    Sent: TJSFormData;
  begin
    if Input.files.length = 0 then Exit;
    Sent := TJSFormData.new; Sent.append('id', string(Id)); Sent.append('file', Input.files[0]);
    await(SiteShell.post('/api/admin/catalog/picture', Sent));
  end;

  procedure Button(Parent: TJSHTMLElement; const Caption: string; Work: TJSFunction; const Cls: string = '');
  var Control: TJSHTMLButtonElement;
    procedure Click(E: TJSEvent); async;
    begin
      Control.disabled := True;
      try
        try
          await(JSValue, TJSPromise(Work.call(nil)));
        except Notice.textContent := string(TJSObject(JSExceptValue)['message']); end;
      finally Control.disabled := False; end;
    end;
  begin
    Control := TJSHTMLButtonElement(El('button', Cls, Caption)); Control._type := 'button';
    Control.addEventListener('click', TJSRawEventHandler(@Click)); Parent.appendChild(Control);
  end;

  procedure Detail(Item: TJSObject; Box: TJSHTMLElement; View: TPageList);
  var
    State: string;
    Title, Note: JSValue;
    Head, Acts, Notes: TJSHTMLElement;
    Link: TJSHTMLAnchorElement;
    Facts: TJSArray;
    Lines: TJSStringDynArray;
    N: integer;

    procedure Dismiss; async;
    begin await(SiteShell.post('/api/admin/catalog/dismiss', new(['id', Item['id']]))); Counts := True; await(View.reload); end;
    procedure Hide; async;
    var Hidden: string;
    begin
      if Truthy(Item['hidden']) then Hidden := '0' else Hidden := '1';
      await(SiteShell.post('/api/catalog/hide', new(['id', Item['id'], 'hidden', Hidden]))); Counts := True; await(View.reload);
    end;
    procedure Delete; async;
    begin
      if not window.confirm(T('Delete %s, its ratings and README? This cannot be undone.', Title)) then Exit;
      await(SiteShell.post('/api/admin/catalog/delete', new(['id', Item['id']]))); View.unpick; Counts := True; await(View.reload);
    end;

    procedure EditEntry;
    var
      Edit: TJSHTMLFormElement;
      Fields: TJSObject;
      Save: TJSHTMLButtonElement;
      Shown: TJSHTMLImageElement;
      procedure RemovePicture; async;
      begin await(SiteShell.post('/api/admin/catalog/picture', new(['id', Item['id'], 'remove', '1']))); await(View.reload); end;
      procedure Submit(E: TJSEvent); async;
      var Sent: TJSObject; Keys: TJSStringDynArray; N: integer; Key: string;
      begin
        E.preventDefault; Save.disabled := True;
        try
          try
            Sent := new(['id', Item['id'], 'categories', TJSObject(Fields['categories'])['value']]);
            Keys := TJSObject.keys(Fields);
            for N := 0 to High(Keys) do
            begin Key := Keys[N]; if (Key <> 'picture') and not Same(TJSObject(Fields[Key])['value'], Was(Item, Key)) then Sent[Key] := TJSObject(Fields[Key])['value']; end;
            if (jsTypeOf(Sent['kind']) <> 'undefined') and (TJSString(string(Sent['kind'])).trim = '') then Sent['kind'] := 'unknown';
            await(SiteShell.post('/api/admin/catalog/save', Sent)); await(SendPicture(Item['id'], TJSHTMLInputElement(Fields['picture'])));
            Counts := True; await(View.reload); SiteShell.toast(T('Saved.'));
          except Notice.textContent := string(TJSObject(JSExceptValue)['message']); end;
        finally Save.disabled := False; end;
      end;
    begin
      Box.appendChild(El('h3', '', T('Edit this entry'))); Edit := TJSHTMLFormElement(El('form', 'lv-edit')); Fields := TJSObject.new;
      EntryFields(Edit, Fields, Item);
      if Truthy(Item['picture']) then
      begin
        Shown := TJSHTMLImageElement(El('img', 'catalog-admin-picture')); Shown.src := string(Item['picture']); Shown.alt := ''; Edit.appendChild(Shown);
        Button(Edit, T('Remove the picture'), TJSFunction(@RemovePicture));
      end;
      Save := TJSHTMLButtonElement(El('button', 'primary', T('Save'))); Edit.appendChild(Save); Edit.addEventListener('submit', TJSRawEventHandler(@Submit)); Box.appendChild(Edit);
    end;

  begin
    Title := OrValue(Item, 'title', Item['name']); Head := El('div', 'lv-detail-head');
    Link := TJSHTMLAnchorElement(El('a', '', Title)); Link.href := '/catalog/' + string(Item['id']); Link.target := '_blank'; Head.appendChild(Link);
    if Truthy(Item['hidden']) then
    begin
      if Flagged(Item) then State := T('Flagged') else State := T('Hidden'); Head.appendChild(SiteShell.chip(State, 'bad'));
    end
    else Head.appendChild(SiteShell.chip(T('Visible')));
    Box.appendChild(Head); Facts := TJSArray.new(TJSArray.new(T('Key'), Item['entry_key']), TJSArray.new(T('Kind'), Named(Kinds, Item['kind'])));
    if Works.length > 0 then Facts.push(TJSArray.new(T('Works with'), Named(Works, Item['works_with'])));
    Facts.push(TJSArray.new(T('Categories'), Item['categories']));
    if Truthy(Item['hidden']) then begin State := T('Hidden reason'); Note := OrValue(Item, 'hidden_note', T('No reason recorded.'));  end
    else begin State := T('Note'); Note := Item['hidden_note']; end;
    Facts.push(TJSArray.new(State, Note)); SiteShell.facts(Box, Facts);
    if Number(Item['reports']) > 0 then
    begin
      Box.appendChild(El('h3', '', Count(Item['reports'], '%d member report', '%d member reports'))); Notes := El('ul');
      Lines := TJSString(string(OrValue(Item, 'report_notes', ''))).split(#10);
      for N := 0 to High(Lines) do if Lines[N] <> '' then Notes.appendChild(El('li', '', Lines[N])); Box.appendChild(Notes);
    end;
    Acts := El('div', 'lv-actions');
    if (Number(Item['reports']) > 0) and Can.includes('edit-catalog') then Button(Acts, T('Dismiss the reports'), TJSFunction(@Dismiss));
    if Can.includes('edit-catalog') then
      if Truthy(Item['hidden']) then Button(Acts, T('Unhide'), TJSFunction(@Hide)) else Button(Acts, T('Hide'), TJSFunction(@Hide));
    if Can.includes('delete-catalog') then Button(Acts, T('Delete'), TJSFunction(@Delete), 'bad');
    Box.appendChild(Acts);
    if Can.includes('edit-catalog') then EditEntry;
    Box.appendChild(Notice);
  end;

  procedure OfferAdd;
  var
    Adding: TJSHTMLElement;
    AddForm: TJSHTMLFormElement;
    Added: TJSObject;
    AddSave: TJSHTMLButtonElement;
    AddNote: TJSHTMLElement;
    procedure Submit(E: TJSEvent); async;
    var Sent, Made: TJSObject; Keys: TJSStringDynArray; N: integer;
    begin
      E.preventDefault; AddSave.disabled := True; AddNote.textContent := '';
      try
        try
          Sent := TJSObject.new; Keys := TJSObject.keys(Added);
          for N := 0 to High(Keys) do if Keys[N] <> 'picture' then Sent[Keys[N]] := TJSObject(Added[Keys[N]])['value'];
          Made := TJSObject(TJSJSON.parse(await(string, SiteShell.post('/api/admin/catalog/add', Sent))));
          try await(SendPicture(Made['id'], TJSHTMLInputElement(Added['picture'])));
          except SiteShell.toast(string(TJSObject(JSExceptValue)['message']), 'bad'); end;
          for N := 0 to High(Keys) do TJSObject(Added[Keys[N]])['value'] := Was(TJSObject.new, Keys[N]);
          TJSObject(Adding)['open'] := False; Counts := True; SiteShell.toast(T('Added.'));
          if Entries <> nil then await(Entries.reload);
          window.open('/catalog/' + string(Made['id']), '_blank');
        except AddNote.textContent := string(TJSObject(JSExceptValue)['message']); end;
      finally AddSave.disabled := False; end;
    end;
  begin
    if AddOffered or not Can.includes('edit-catalog') then Exit;
    AddOffered := True; Adding := El('details', 'catalog-add'); AddForm := TJSHTMLFormElement(El('form', 'lv-edit')); Added := TJSObject.new;
    Adding.appendChild(El('summary', '', T('Add an entry'))); EntryFields(AddForm, Added, TJSObject.new);
    AddSave := TJSHTMLButtonElement(El('button', 'primary', T('Add'))); AddNote := El('p'); AddNote.setAttribute('role', 'status');
    AddForm.append(AddSave, AddNote); Adding.appendChild(AddForm); AddForm.addEventListener('submit', TJSRawEventHandler(@Submit)); AddPlace.appendChild(Adding);
  end;

  function Remote(S: TJSObject): TJSObject; async;
  var Data, Filters: TJSObject; Url: string;
  begin
    Filters := TJSObject(S['filters']);
    Url := '/api/admin/catalog?q=' + SiteShell.enc(string(S['q'])) + '&page=' + string(S['page']) + '&show=' + SiteShell.enc(string(OrValue(Filters, 'show', 'all'))) +
      '&kind=' + SiteShell.enc(string(OrValue(Filters, 'kind', ''))) + '&sort=' + SiteShell.enc(string(S['sort']));
    if not Counts then Url := Url + '&counts=0';
    Data := await(TJSObject, SiteShell.get(Url)); Counts := False; Can := TJSArray(Data['can']); Choices(Data); OfferAdd;
    if Truthy(Data['kinds']) then Summary(Data);
    Result := new(['rows', Data['items'], 'total', Data['matches']]);
  end;

  function State(Item: TJSObject): JSValue;
  begin
    if Truthy(Item['hidden']) then if Flagged(Item) then Result := T('Flagged') else Result := T('Hidden') else Result := T('Visible');
  end;

begin
  More := ArrayOrEmpty(SiteShell.extras['catalogTabs']); Tabs := TJSArray.new(new(['key', 'entries', 'title', T('Entries')]));
  for I := 0 to More.length - 1 do begin Extra := TJSObject(More[I]); Tabs.push(new(['key', Extra['key'], 'title', Extra['title']])); end;
  Tabs.push(new(['key', 'activity', 'title', T('Activity')]), new(['key', 'numbers', 'title', T('Numbers')]));
  Subs := SiteShell.subTabs(Holder, 'catalog', Tabs); Activity(Subs.holder('activity'));
  Tiles := El('div', 'tiles-admin'); Numbers := Subs.holder('numbers'); Subs.holder('entries').appendChild(Tiles);
  Notice := El('p'); Notice.setAttribute('role', 'status'); Can := TJSArray.new; Drawn := False; Counts := True;
  Kinds := TJSArray.new; Works := TJSArray.new; Shows := TJSArray.new(TJSArray.new('hidden', T('Hidden entries')), TJSArray.new('reported', T('Reported by members')));
  AddPlace := El('div'); Subs.holder('entries').appendChild(AddPlace); Entries := nil; AddOffered := False;
  Entries := SiteShell.listView(Subs.holder('entries'), new([
    'id', 'catalog', 'key', TItemValue(function(Item: TJSObject): JSValue begin Result := string(Item['id']); end), 'sort', 'name', 'csv', 'catalog',
    'search', T('Search by name, title or key'), 'remote', @Remote,
    'columns', TJSArray.new(
      new(['key', 'name', 'title', T('Entry'), 'cell', TItemValue(function(Item: TJSObject): JSValue begin Result := OrValue(Item, 'title', Item['name']); end)]),
      new(['key', 'key', 'title', T('Key'), 'wide', True, 'value', TItemValue(function(Item: TJSObject): JSValue begin Result := Item['entry_key']; end)]),
      new(['key', 'kind', 'title', T('Kind'), 'value', TItemValue(function(Item: TJSObject): JSValue begin Result := Named(Kinds, Item['kind']); end)]),
      new(['key', 'reports', 'title', T('Reports'), 'num', True, 'cell', TItemValue(function(Item: TJSObject): JSValue
        begin if Truthy(Item['reports']) then Result := SiteShell.chip(string(Item['reports']), 'bad') else Result := ''; end)]),
      new(['key', 'state', 'title', T('State'), 'value', @State, 'cell', TItemValue(function(Item: TJSObject): JSValue
        begin if Truthy(Item['hidden']) then Result := SiteShell.chip(State(Item), 'bad') else Result := SiteShell.chip(T('Visible')); end)])),
    'filters', TJSArray.new(new(['key', 'show', 'title', T('Show'), 'all', T('All entries'), 'options', Shows]), new(['key', 'kind', 'title', T('Kind'), 'all', T('Every kind'), 'options', Kinds])),
    'rowClass', TItemValue(function(Item: TJSObject): JSValue begin if Number(Item['reports']) > 0 then Result := 'unread' else Result := ''; end),
    'noun', TCountText(function(N: NativeInt): string begin Result := TN(N, '%d entry', '%d entries'); end), 'detail', @Detail]));
  for I := 0 to More.length - 1 do
  begin Extra := TJSObject(More[I]); TJSFunction(Extra['build']).call(Extra, Subs.holder(string(Extra['key']))); end;
end;

function Shown(R: TJSObject): JSValue;
begin
  Result := Plus(Plus(Plus(OrValue(R, 'start', 0), OrValue(R, 'skip', 0)), OrValue(R, 'yes', 0)), OrValue(R, 'narrow', 0));
end;

function Rate(Yes, Skip: JSValue): string;
begin
  if Truthy(Plus(Yes, Skip)) then Result := String(JSValue(Round(100 * Number(Yes) / Number(Plus(Yes, Skip))))) + '%' else Result := '';
end;

function Reader(R: TJSObject): JSValue;
begin
  if Truthy(R['name']) then Result := R['name'] else Result := T('Guest %s', TJSString(R['who']).slice(1, 7));
end;

function Narrowing(V: JSValue): JSValue;
var Words: TJSObject; Parts: TJSStringDynArray; Names: TJSArray; I: integer; Part: string;
begin
  Words := TJSObject(SiteShell.extras['catalogCaptions']); Names := TJSArray.new;
  if not Truthy(V) then V := '';
  Parts := TJSString(string(V)).split('/');
  for I := 0 to High(Parts) do
  begin
    Part := Parts[I]; if Part = '' then Continue;
    if Truthy(Words) and Truthy(Words['only-' + Part]) then Names.push(Words['only-' + Part]) else Names.push(T('%s only', Part));
  end;
  if Names.length > 0 then Result := Names.join(' · ') else Result := T('Anything');
end;

procedure Activity(Holder: TJSHTMLElement);
var
  Bar, HideLabel, PeriodLabel, Note, Tiles: TJSHTMLElement;
  Period: TJSHTMLSelectElement;
  Hide: TJSHTMLInputElement;
  Subs: TPageTabs;
  Steps: TJSArray;
  Days, People, Projects, Narrow, Crawlers: TPageList;
  Asked: integer;
  Choices: array[0..4] of string;
  Captions: array[0..4] of string;
  I: integer;
  Option: TJSHTMLOptionElement;

  function ReaderDetail(R: TJSObject; Box: TJSHTMLElement): JSValue;
  var Narrowings: TJSStringDynArray; Names: TJSArray; N: integer;
  begin
    Box.appendChild(El('div', 'lv-detail-head', Reader(R)));
    Narrowings := TJSString(string(OrValue(R, 'narrowings', ''))).split(', '); Names := TJSArray.new;
    for N := 0 to High(Narrowings) do if Narrowings[N] <> '' then Names.push(Narrowing(Narrowings[N]));
    SiteShell.facts(Box, TJSArray.new(TJSArray.new(T('First'), DateTimeText(R['first'])), TJSArray.new(T('Last'), DateTimeText(R['last'])),
      TJSArray.new(T('Days'), R['days']), TJSArray.new(T('Projects shown'), Shown(R)), TJSArray.new(T('Interesting, show me another'), R['yes']),
      TJSArray.new(T('Not for me, show me another'), R['skip']), TJSArray.new(T('Interesting rate'), Rate(R['yes'], R['skip'])),
      TJSArray.new(T('Interesting pressed elsewhere'), R['press']), TJSArray.new(T('Taken back'), R['unpress']), TJSArray.new(T('Narrowed to'), Names.join('; '))));
    if not Truthy(R['name']) then Box.appendChild(El('p', 'hint', T('Someone not signed in; only a scrambled form of the address is kept.')));
  end;

  procedure Load; async;
  var
    Mine: integer;
    D, N, K: TJSObject;
    Url, Caption, Extra: string;
  begin
    Inc(Asked); Mine := Asked;
    Days.loading; People.loading; Projects.loading; Narrow.loading; Crawlers.loading; SiteShell.waiting(Tiles);
    Url := '/api/admin/catalog/activity?days=' + Period.value + '&hide='; if Hide.checked then Url := Url + '1' else Url := Url + '0';
    try
      D := await(TJSObject, SiteShell.get(Url)); if Mine <> Asked then Exit;
      N := First(D['totals']); K := First(D['kept']);
      if Truthy(D['since']) then Note.textContent := T('Counting since %s.', DateTimeText(D['since'])) else Note.textContent := T('Nothing counted yet: the counting began with this version.');
      Tiles.replaceChildren;
      Extra := ''; if Truthy(N['members']) then Extra := Count(N['members'], '%d member', '%d members');
      SiteShell.stat(Tiles, OrValue(N, 'discoverers', 0), T('Readers discovering'), Extra);
      Extra := ''; if Truthy(N['start']) then Extra := Count(N['start'], '%d start', '%d starts');
      SiteShell.stat(Tiles, Shown(N), T('Projects shown'), Extra);
      SiteShell.stat(Tiles, OrValue(N, 'yes', 0), T('Interesting, show me another')); SiteShell.stat(Tiles, OrValue(N, 'skip', 0), T('Not for me, show me another'));
      Caption := Rate(OrValue(N, 'yes', 0), OrValue(N, 'skip', 0)); if Caption = '' then Caption := '–';
      SiteShell.stat(Tiles, Caption, T('Interesting rate'));
      Extra := ''; if Truthy(N['unpress']) then Extra := Count(N['unpress'], '%d taken back', '%d taken back');
      SiteShell.stat(Tiles, OrValue(N, 'press', 0), T('Interesting pressed elsewhere'), Extra);
      SiteShell.stat(Tiles, OrValue(K, 'interest', 0), T('Interesting kept'), Count(OrValue(K, 'interest_people', 0), 'from %d reader', 'from %d readers') + ' · ' + Count(OrValue(K, 'interest_all', 0), '%d in all', '%d in all'));
      Extra := ''; if Truthy(K['reports']) then Extra := Count(K['reports'], '%d report', '%d reports');
      SiteShell.stat(Tiles, OrValue(K, 'ratings', 0), T('Ratings'), Extra); SiteShell.stat(Tiles, OrValue(N, 'crawler_steps', 0), T('Crawler steps'));
      Subs.count('crawlers', ArrayOrEmpty(D['crawlers']).length);
      Days.set_(ArrayOrEmpty(D['by_day'])); People.set_(ArrayOrEmpty(D['people'])); Projects.set_(ArrayOrEmpty(D['projects'])); Narrow.set_(ArrayOrEmpty(D['narrowings'])); Crawlers.set_(ArrayOrEmpty(D['crawlers']));
    except
      if Mine <> Asked then Exit;
      Tiles.replaceChildren; Caption := string(TJSObject(JSExceptValue)['message']);
      Days.failed(Caption); People.failed(Caption); Projects.failed(Caption); Narrow.failed(Caption); Crawlers.failed(Caption);
    end;
  end;

begin
  Bar := El('div', 'visit-controls'); Period := TJSHTMLSelectElement(El('select')); Hide := TJSHTMLInputElement(El('input'));
  HideLabel := El('label', 'visit-tick'); PeriodLabel := El('label', '', T('Period') + ' '); PeriodLabel.appendChild(Period);
  Choices[0] := '1'; Choices[1] := '7'; Choices[2] := '30'; Choices[3] := '90'; Choices[4] := '0';
  Captions[0] := T('Today'); Captions[1] := T('Last 7 days'); Captions[2] := T('Last 30 days'); Captions[3] := T('Last 90 days'); Captions[4] := T('Everything kept');
  for I := 0 to 4 do begin Option := TJSHTMLOptionElement(El('option', '', Captions[I])); Option.value := Choices[I]; Period.appendChild(Option); end;
  Period.value := '7'; Hide._type := 'checkbox'; Hide.checked := True;
  // pas2js Web's append overload omits text nodes.
  HideLabel.append(Hide, TJSElement(document.createTextNode(' ' + T('Hide my own'))));
  Bar.append(PeriodLabel, HideLabel); Holder.appendChild(Bar); Note := El('p', 'hint'); Tiles := El('div', 'tiles-admin'); Holder.append(Note, Tiles);
  Subs := SiteShell.subTabs(Holder, 'catalog-activity', TJSArray.new(new(['key', 'days', 'title', T('By day')]), new(['key', 'people', 'title', T('Readers')]),
    new(['key', 'projects', 'title', T('Projects')]), new(['key', 'narrowing', 'title', T('Narrowing')]), new(['key', 'crawlers', 'title', T('Crawlers')])));
  Steps := TJSArray.new(new(['key', 'start', 'title', T('Started'), 'num', True]), new(['key', 'yes', 'title', T('Interesting'), 'num', True]),
    new(['key', 'skip', 'title', T('Not for me'), 'num', True]), new(['key', 'narrow', 'title', T('Narrowed'), 'num', True, 'wide', True]),
    new(['key', 'press', 'title', T('Pressed'), 'num', True, 'wide', True]), new(['key', 'unpress', 'title', T('Taken back'), 'num', True, 'wide', True]));
  Days := SiteShell.listView(Subs.holder('days'), new(['id', 'catalog-days', 'key', TItemValue(function(R: TJSObject): JSValue begin Result := R['day']; end),
    'sort', '-day', 'csv', 'catalog-activity-days', 'search', False,
    'columns', TJSArray.new(new(['key', 'day', 'title', T('Day'), 'down', True]), new(['key', 'people', 'title', T('Readers'), 'num', True])).concat(Steps,
      TJSArray.new(new(['key', 'crawler_steps', 'title', T('Crawler steps'), 'num', True, 'wide', True]))),
    'noun', TCountText(function(N: NativeInt): string begin Result := TN(N, '%d day', '%d days'); end), 'empty', T('No one used Random project or Interesting in this period.')]));
  People := SiteShell.listView(Subs.holder('people'), new(['id', 'catalog-readers', 'key', TItemValue(function(R: TJSObject): JSValue begin Result := R['who']; end),
    'sort', '-last', 'csv', 'catalog-activity-readers', 'search', T('Filter by member'),
    'columns', TJSArray.new(new(['key', 'name', 'title', T('Reader'), 'value', @Reader]),
      new(['key', 'last', 'title', T('Last'), 'down', True, 'cell', TItemValue(function(R: TJSObject): JSValue begin Result := DateTimeText(R['last']); end)]),
      new(['key', 'days', 'title', T('Days'), 'num', True, 'wide', True]), new(['key', 'shown', 'title', T('Projects shown'), 'num', True, 'value', @Shown]),
      new(['key', 'rate', 'title', T('Interesting rate'), 'num', True, 'value', TItemValue(function(R: TJSObject): JSValue
        begin if Truthy(Plus(R['yes'], R['skip'])) then Result := Round(100 * Number(R['yes']) / Number(Plus(R['yes'], R['skip']))) else Result := -1; end),
        'cell', TItemValue(function(R: TJSObject): JSValue begin Result := Rate(R['yes'], R['skip']); end)])).concat(Steps),
    'filters', TJSArray.new(new(['key', 'kind', 'title', T('Readers'), 'all', T('Everyone'), 'options', TJSArray.new(TJSArray.new('member', T('Members')), TJSArray.new('guest', T('Guests'))),
      'test', TFilterTest(function(R: TJSObject; V: string): JSValue begin if V = 'member' then Result := Truthy(R['name']) else Result := not Truthy(R['name']); end)])),
    'noun', TCountText(function(N: NativeInt): string begin Result := TN(N, '%d reader', '%d readers'); end), 'empty', T('No one used Random project or Interesting in this period.'), 'detail', @ReaderDetail]));
  Projects := SiteShell.listView(Subs.holder('projects'), new(['id', 'catalog-projects', 'key', TItemValue(function(R: TJSObject): JSValue begin Result := string(R['id']); end),
    'sort', '-yes', 'csv', 'catalog-activity-projects', 'search', T('Filter by project'),
    'columns', TJSArray.new(new(['key', 'title', 'title', T('Project'), 'cell', TItemValue(function(R: TJSObject): JSValue
      var A: TJSHTMLAnchorElement; begin A := SiteShell.link('/catalog/' + string(R['id']), '', R['title']); A.target := '_blank'; Result := A; end)]),
      new(['key', 'yes', 'title', T('Interesting'), 'num', True, 'down', True]), new(['key', 'skip', 'title', T('Not for me'), 'num', True]),
      new(['key', 'press', 'title', T('Pressed'), 'num', True, 'wide', True]), new(['key', 'unpress', 'title', T('Taken back'), 'num', True, 'wide', True]),
      new(['key', 'people', 'title', T('Readers'), 'num', True, 'wide', True]), new(['key', 'interest', 'title', T('Interesting now'), 'num', True])),
    'noun', TCountText(function(N: NativeInt): string begin Result := TN(N, '%d project', '%d projects'); end), 'empty', T('No project got an answer in this period.')]));
  Narrow := SiteShell.listView(Subs.holder('narrowing'), new(['id', 'catalog-narrowing', 'key', TItemValue(function(R: TJSObject): JSValue begin Result := R['narrowing']; end),
    'sort', '-steps', 'search', False, 'columns', TJSArray.new(new(['key', 'narrowing', 'title', T('Showing'), 'value', TItemValue(function(R: TJSObject): JSValue begin Result := Narrowing(R['narrowing']); end)]),
      new(['key', 'steps', 'title', T('Projects shown'), 'num', True, 'down', True]), new(['key', 'people', 'title', T('Readers'), 'num', True])),
    'noun', TCountText(function(N: NativeInt): string begin Result := TN(N, '%d choice', '%d choices'); end), 'empty', T('No one used Random project in this period.')]));
  Crawlers := SiteShell.listView(Subs.holder('crawlers'), new(['id', 'catalog-crawlers', 'key', TItemValue(function(R: TJSObject): JSValue begin Result := R['name']; end),
    'sort', '-steps', 'csv', 'catalog-activity-crawlers', 'search', False, 'columns', TJSArray.new(
      new(['key', 'name', 'title', T('Crawler'), 'value', TItemValue(function(R: TJSObject): JSValue begin Result := OrValue(R, 'name', T('No crawler name, no script')); end)]),
      new(['key', 'steps', 'title', T('Steps'), 'num', True, 'down', True]), new(['key', 'addresses', 'title', T('Addresses'), 'num', True]),
      new(['key', 'start', 'title', T('Started'), 'num', True, 'wide', True]), new(['key', 'skip', 'title', T('Not for me'), 'num', True, 'wide', True]),
      new(['key', 'last', 'title', T('Last'), 'wide', True, 'cell', TItemValue(function(R: TJSObject): JSValue begin Result := DateTimeText(R['last']); end)])),
    'noun', TCountText(function(N: NativeInt): string begin Result := TN(N, '%d crawler', '%d crawlers'); end), 'empty', T('No crawler followed the random links in this period.')]));
  Holder.appendChild(El('p', 'hint', T('A reader is counted when the page''s script sends the click, or for a press; crawlers follow the links without either. The steps without a crawler name are mostly crawlers posing as browsers, or someone with scripts turned off.')));
  Asked := 0;
  Period.addEventListener('change', TJSRawEventHandler(procedure(E: TJSEvent) begin Load; end)); Hide.addEventListener('change', TJSRawEventHandler(procedure(E: TJSEvent) begin Load; end)); Load;
end;

function Badge: JSValue; async;
var D: TJSObject;
begin D := await(TJSObject, SiteShell.get('/api/admin/catalog?show=reported&counts=0')); Result := D['matches']; end;

initialization
  if Truthy(SiteShell) then
  begin
    TJSObject(SiteShell.extras['settingGroups'])['Catalog'] := 'Catalog';
    TJSArray(SiteShell.extras['adminTabs']).push(new(['title', 'Catalog', 'permission', 'view-catalog', 'build', @Catalog, 'group', 'Catalog', 'part', 'catalog', 'badge', @Badge]));
  end;
end.
