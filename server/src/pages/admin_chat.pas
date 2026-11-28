unit Admin_Chat;

{ The chat's tabs of the admin page: the public channels, and who has private
  channels and conversations. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, Admin_List;

procedure AdminChannels(Box: TJSHTMLElement; Data: TJSObject);
procedure AdminPrivate(Box: TJSHTMLElement);

implementation

type
  // FormData.append with a value of any kind, as the browser takes it.
  TFields = class external name 'FormData'(TJSObject)
    constructor new;
    procedure append(const Name: string; Value: JSValue);
  end;
  TShow = reference to function: JSValue; async;

procedure AdminChannels(Box: TJSHTMLElement; Data: TJSObject);
var
  Table: TJSHTMLElement;
  Channels: TJSArray;
  I: NativeInt;

  procedure AddRow(Channel: TJSObject);
  var
    Tr, Slug, Topic, Policy, AsSent, AsSentLabel, ArchivedLabel, Archived, IconCell, Img, Pick, Save, Gone, Tools, O, Td: TJSHTMLElement;
    Choices, Cells: TJSArray;
    N: NativeInt;

    procedure Picked(E: TJSEvent); async;
    var
      Fields: TFields;
    begin
      Fields := TFields.new;
      Fields.append('file', TJSArray(TJSObject(Pick)['files'])[0]);
      Fields.append('room_icon', Channel['slug']);
      try
        TJSObject(Img)['src'] := TJSObject(TJSJSON.parse(await(string, C.post('/api/upload', Fields))))['url'];
        Img.hidden := False;
        IconCell.querySelector('span').textContent := '';
        C.toast(T('Icon saved.'));
      except
        C.failed(JSExceptValue);
      end;
    end;

    procedure SaveClick(E: TJSEvent); async;
    var
      IsArchived, IsAsSent: string;
    begin
      try
        if Truthy(TJSObject(Archived)['checked']) then IsArchived := '1' else IsArchived := '0';
        if Truthy(TJSObject(AsSent)['checked']) then IsAsSent := '1' else IsAsSent := '0';
        C.toast(await(JSValue, C.post('/api/admin/channel', new(['slug', TJSObject(Slug)['value'], 'topic', TJSObject(Topic)['value'],
          'policy', TJSObject(Policy)['value'], 'archived', IsArchived, 'as_sent', IsAsSent]))));
        if not Truthy(Channel['slug']) then C.route('/admin', False);
      except
        C.failed(JSExceptValue);
      end;
    end;

    // the channel taken away with everything said in it, after a question
    procedure DeleteClick(E: TJSEvent); async;
    begin
      if not window.confirm(T('Delete #%s with every message in it? This cannot be undone.', Channel['slug'])) then Exit;
      try
        C.toast(await(JSValue, C.post('/api/admin/channel/delete', new(['slug', Channel['slug']]))));
        Tr.remove;
      except
        C.failed(JSExceptValue);
      end;
    end;

  begin
    Tr := C.el('tr');
    Slug := C.el('input');
    TJSObject(Slug)['value'] := Either(Channel['slug'], '');
    TJSObject(Slug)['readOnly'] := Truthy(Channel['slug']);
    TJSObject(Slug)['placeholder'] := T('new-channel');
    Topic := C.el('input');
    TJSObject(Topic)['value'] := Either(Channel['topic'], '');
    TJSObject(Topic)['placeholder'] := T('What it is for');
    Policy := C.el('select');
    Choices := Items(Items('all', T('everyone posts')), Items('readonly', T('read only: some post, all reply')),
      Items('closed', T('closed: only some post or reply')));
    for N := 0 to Choices.length - 1 do
    begin
      O := C.el('option', '', TJSArray(Choices[N])[1]);
      TJSObject(O)['value'] := TJSArray(Choices[N])[0];
      Policy.appendChild(O);
    end;
    if Same(Channel['policy'], 'readonly') or Same(Channel['policy'], 'closed') then TJSObject(Policy)['value'] := Channel['policy']
    else TJSObject(Policy)['value'] := 'all';
    // nobody changes or deletes a message there once it is sent
    AsSent := C.el('input');
    TJSObject(AsSent)['type'] := 'checkbox';
    TJSObject(AsSent)['checked'] := Truthy(Channel['as_sent']);
    AsSentLabel := C.el('label', 'aslabel', '');
    TKit(AsSentLabel).add(AsSent, ' ' + T('as sent'));
    AsSentLabel.title := T('Messages stay as they were sent: nobody changes or deletes one, a moderator neither.');
    ArchivedLabel := C.el('label', 'aslabel', '');
    Archived := C.el('input');
    TJSObject(Archived)['type'] := 'checkbox';
    TJSObject(Archived)['checked'] := Truthy(Channel['archived']);
    Archived.title := T('Archived');
    TKit(ArchivedLabel).add(Archived, ' ' + T('archived'));
    // The channel's icon: a click on it picks a new picture.
    IconCell := C.el('label', 'chanicon');
    if Truthy(Channel['slug']) then
    begin
      Img := C.el('img');
      TJSObject(Img)['alt'] := '';
      if Truthy(Channel['avatar']) then TJSObject(Img)['src'] := Channel['avatar'] else Img.hidden := True;
      Pick := C.el('input');
      TJSObject(Pick)['type'] := 'file';
      TJSObject(Pick)['accept'] := 'image/png,image/jpeg,image/webp';
      Pick.hidden := True;
      IconCell.title := T('Change the icon');
      if Truthy(Channel['avatar']) then TKit(IconCell).add(Img, C.el('span', '', ''), Pick)
      else TKit(IconCell).add(Img, C.el('span', '', T('Icon')), Pick);
      Pick.addEventListener('change', TJSRawEventHandler(@Picked));
    end;
    if Truthy(Channel['slug']) then Save := C.el('button', '', T('Save')) else Save := C.el('button', '', T('Create'));
    TJSObject(Save)['type'] := 'button';
    Save.addEventListener('click', TJSRawEventHandler(@SaveClick));
    Tools := C.el('span', 'tools', '');
    Tools.appendChild(Save);
    if Truthy(Channel['slug']) then
    begin
      Gone := C.el('button', 'danger', T('Delete'));
      TJSObject(Gone)['type'] := 'button';
      Gone.title := T('Delete the channel and every message in it');
      Gone.addEventListener('click', TJSRawEventHandler(@DeleteClick));
      Tools.appendChild(Gone);
    end;
    Cells := Items(IconCell, Slug, Topic, Policy, AsSentLabel, ArchivedLabel, Tools);
    for N := 0 to Cells.length - 1 do
    begin
      Td := C.el('td');
      Td.appendChild(TJSNode(Cells[N]));
      Tr.appendChild(Td);
    end;
    Table.appendChild(Tr);
  end;

begin
  Box.appendChild(C.el('p', 'hint', T('Public channels everyone follows when they join. Members open their own private channels from the + in the sidebar.')));
  Table := C.el('table', 'grid');
  Channels := TJSArray(Data['channels']);
  for I := 0 to Channels.length - 1 do AddRow(TJSObject(Channels[I]));
  AddRow(TJSObject.new);
  Box.appendChild(Table);
end;

// Who has private channels and conversations: who, when and how much, never
// what.  Deleting here is for everyone in them and cannot be undone.
procedure AdminPrivate(Box: TJSHTMLElement);
var
  List: TJSObject;
  Body, Find: TJSHTMLElement;
  First: JSValue;

  function Show: JSValue; async; forward;

  function When(Iso: JSValue): string;
  begin
    if Truthy(Iso) then Result := C.ago(Iso) else Result := T('nothing yet');
  end;

  function Count(N: JSValue): string;
  begin
    Result := TN(N, '%d message', '%d messages');
  end;

  function People(Channel: TJSObject): JSValue;
  var
    Members, Names: TJSArray;
    N: NativeInt;
  begin
    Members := TJSArray(Channel['members']);
    Names := TJSArray.new;
    for N := 0 to Members.length - 1 do
      if Same(Members[N], Channel['owner']) then Names.push(T('%s (owner)', Members[N])) else Names.push(Members[N]);
    if Truthy(Channel['owner']) and (Members.indexOf(Channel['owner']) < 0) then Names.unshift(T('%s (owner, left)', Channel['owner']));
    Result := Either(Names.join(', '), T('nobody'));
  end;

  function RemoveButton(Ask: JSValue; Fields: TJSObject; Show: TShow): TJSHTMLElement;
  var
    Remove: TJSHTMLElement;

    procedure Click(E: TJSEvent); async;
    begin
      if not window.confirm(string(Ask)) then Exit;
      try
        C.toast(await(JSValue, C.post('/api/admin/private/delete', Fields)));
        await(JSValue, Show());
      except
        C.failed(JSExceptValue);
      end;
    end;

  begin
    Remove := C.el('button', 'small-link bad', T('Delete'));
    TJSObject(Remove)['type'] := 'button';
    Remove.addEventListener('click', TJSRawEventHandler(@Click));
    Result := Remove;
  end;

  function Part(Rows: TJSArray; Empty: JSValue): TJSHTMLElement;
  var
    Wrap, Table: TJSHTMLElement;
    N: NativeInt;
  begin
    Wrap := C.el('div', 'gridwrap');
    if Rows.length = 0 then
    begin
      Wrap.appendChild(C.el('p', 'dim', Empty));
      Exit(Wrap);
    end;
    Table := C.el('table', 'grid privategrid');
    for N := 0 to Rows.length - 1 do Table.appendChild(TJSNode(Rows[N]));
    Wrap.appendChild(Table);
    Result := Wrap;
  end;

  function Row(Cells: TJSArray): TJSHTMLElement;
  var
    Tr, Td: TJSHTMLElement;
    Cell: TJSObject;
    N: NativeInt;
  begin
    Tr := C.el('tr');
    for N := 0 to Cells.length - 1 do
    begin
      Cell := TJSObject(Cells[N]);
      if Truthy(Cell['dim']) then Td := C.el('td', 'dim') else Td := C.el('td', '');
      if Truthy(Cell['node']) then Td.appendChild(TJSNode(Cell['node'])) else TJSObject(Td)['textContent'] := Cell['text'];
      Tr.appendChild(Td);
    end;
    Result := Tr;
  end;

  procedure Fill;
  var
    Q: string;
    Channels, Talks, Given, Members: TJSArray;
    Channel: TJSObject;
    Empty, Head, Locked: JSValue;
    Among: boolean;
    N, M: NativeInt;

    function Has(Text: JSValue): boolean;
    begin
      Result := (Q = '') or (TJSString(TJSString(Str(Text)).toLowerCase).indexOf(Q) >= 0);
    end;

  begin
    Q := TJSString(TJSString(TJSObject(Find)['value']).trim).toLowerCase;
    Channels := TJSArray.new;
    Given := TJSArray(List['channels']);
    for N := 0 to Given.length - 1 do
    begin
      Channel := TJSObject(Given[N]);
      Among := Has(Channel['slug']) or Has(Channel['title']) or Has(Channel['owner']);
      if not Among then
      begin
        Members := TJSArray(Channel['members']);
        for M := 0 to Members.length - 1 do
          if Has(Members[M]) then
          begin
            Among := True;
            Break;
          end;
      end;
      if not Among then Continue;
      if Truthy(Channel['archived']) then Head := T('#%s (archived)', Channel['slug']) else Head := '#' + string(Channel['slug']);
      Channels.push(Row(Items(
        new(['node', C.el('b', '', Head)]),
        new(['text', People(Channel)]),
        new(['text', Count(Channel['messages']), 'dim', True]),
        new(['text', When(Channel['last']), 'dim', True]),
        new(['node', RemoveButton(T('Delete #%s for good?'#10#10'Its messages, threads and files go for everyone in it. This cannot be undone.', Channel['slug']),
          new(['kind', 'channel', 'slug', Channel['slug']]), @Show)]))));
    end;
    Talks := TJSArray.new;
    Given := TJSArray(List['conversations']);
    for N := 0 to Given.length - 1 do
    begin
      Channel := TJSObject(Given[N]);
      if not (Has(Channel['a']) or Has(Channel['b'])) then Continue;
      if Truthy(Channel['locked']) then Locked := T('locked') else Locked := T('plain');
      Talks.push(Row(Items(
        new(['node', C.el('b', '', T('%s and %s', Channel['a'], Channel['b']))]),
        new(['text', Locked, 'dim', True]),
        new(['text', Count(Channel['messages']), 'dim', True]),
        new(['text', When(Channel['last']), 'dim', True]),
        new(['node', RemoveButton(T('Delete the conversation between %s and %s for good?'#10#10'Every message and file goes from both sides. This cannot be undone.', Channel['a'], Channel['b']),
          new(['kind', 'conversation', 'a', Channel['a'], 'b', Channel['b']]), @Show)]))));
    end;
    if Q <> '' then Empty := T('None match.') else Empty := T('There are none.');
    TKit(Body).fill(C.el('h2', '', T('Private channels')), Part(Channels, Empty),
      C.el('h2', '', T('Private conversations')), Part(Talks, Empty));
  end;

  function Show: JSValue; async;
  begin
    List := await(TJSObject, C.get('/api/admin/private'));
    Fill;
  end;

begin
  List := nil;
  Body := C.el('div');
  Find := C.el('input');
  TJSObject(Find)['type'] := 'search';
  TJSObject(Find)['placeholder'] := T('Find a member or channel');
  Find.addEventListener('input', TJSRawEventHandler(@Fill));
  TKit(Box).add(C.el('p', 'hint', T('Who talks in private and how much. What they say does not come here.')), Find, Body);
  First := Show;
  TJSPromise(First).catch(TJSPromiseResolver(C['failed']));
end;

end.
