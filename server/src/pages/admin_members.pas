unit Admin_Members;

{ The permission grid with its roles, and the members' list with the box of the
  member picked: roles, the ban, the account and the addresses they came from. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, Admin_List;

procedure AdminPermissions(Box: TJSHTMLElement; Data: TJSObject);
procedure AdminMembers(Box: TJSHTMLElement; Data: TJSObject; Can: TCan);

implementation

uses Admin_Address;

type
  // navigator.clipboard, as far as a link is copied with it.
  TClipboard = class external name 'Object'(TJSObject)
    function writeText(const Text: string): TJSPromise;
  end;
  TRun = reference to function: JSValue; async;

function SiteUrl(const Address: string): string; external name 'window.SiteBase.url';

// the parts of a comma list that are not empty
function Filled(List: JSValue): TJSArray;
var
  Parts: TJSArray;
  I: NativeInt;
begin
  Parts := TJSArray(JSValue(TJSString(List).split(',')));
  Result := TJSArray.new;
  for I := 0 to Parts.length - 1 do
    if Truthy(Parts[I]) then Result.push(Parts[I]);
end;

// The permission grid: a row for each permission, a column for each role.
// a role as the admin pages show it: the channel roles by the word channel
function RoleTitle(Name: JSValue): JSValue;
begin
  Result := Either(new(['owner', T('channel owner'), 'room-moderator', T('channel moderator')])[string(Name)], Name);
end;

procedure AdminPermissions(Box: TJSHTMLElement; Data: TJSObject);
var
  Wrap, Table, HeadRow, Th, Roles, Form: TJSHTMLElement;
  Name, Caption: TJSHTMLInputElement;
  Scope: TJSHTMLSelectElement;
  Add, Opt: TJSHTMLElement;
  List, Choices: TJSArray;
  R: TJSObject;
  I: NativeInt;

  // a permission's row: its ticks share the list of roles that have it
  procedure PermissionRow(P: TJSObject);
  var
    Tr, Cell: TJSHTMLElement;
    Have: TJSArray;
    N: NativeInt;

    procedure RoleCell(Role: TJSObject);
    var
      Td: TJSHTMLElement;
      Box2: TJSHTMLInputElement;
    begin
      Td := C.el('td');
      Box2 := TJSHTMLInputElement(C.el('input'));
      Box2._type := 'checkbox';
      Box2.checked := Same(Role['name'], 'admin') or (Have.indexOf(Role['name']) >= 0);
      Box2.disabled := Same(Role['name'], 'admin');
      Box2.title := string(RoleTitle(Role['name'])) + ': ' + T(P['caption']);
      Box2.addEventListener('change', TJSRawEventHandler(procedure(E: TJSEvent) async
        begin
          if Box2.checked then Have.push(Role['name'])
          else Have.splice(Have.indexOf(Role['name']), 1);
          try
            await(JSValue, C.post('/api/admin/permission', new(['name', P['name'], 'roles', Have.join(',')])));
          except
            C.failed(JSExceptValue);
            Box2.checked := not Box2.checked;
          end;
        end));
      Td.appendChild(Box2);
      Tr.appendChild(Td);
    end;

  begin
    Tr := C.el('tr');
    Cell := C.el('td', 'pname', T(P['caption']));
    TJSObject(Cell)['title'] := P['name'];
    Tr.appendChild(Cell);
    Have := Filled(P['roles']);
    for N := 0 to List.length - 1 do RoleCell(TJSObject(List[N]));
    Table.appendChild(Tr);
  end;

  procedure RoleRow(Role: TJSObject);
  var
    Tr, Td, X: TJSHTMLElement;
    Where: string;
  begin
    Tr := C.el('tr');
    if Same(Role['scope'], 'room') then Where := T('in one channel') else Where := T('site');
    TKit(Tr).add(C.el('td', '', RoleTitle(Role['name'])), C.el('td', 'dim', Where), C.el('td', 'dim', Role['caption']));
    Td := C.el('td');
    if not Truthy(Role['builtin']) then
    begin
      X := C.el('button', 'small-link', T('Delete'));
      TJSObject(X)['type'] := 'button';
      X.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) async
        begin
          if not window.confirm(T('Delete the role %s? Members who have it lose it.', Role['name'])) then Exit;
          try
            await(JSValue, C.post('/api/admin/role', new(['name', Role['name'], 'delete', '1'])));
            C.route('/admin', False);
          except
            C.failed(JSExceptValue);
          end;
        end));
      Td.appendChild(X);
    end;
    Tr.appendChild(Td);
    Roles.appendChild(Tr);
  end;

begin
  Box.appendChild(C.el('p', 'hint', T('Tick which roles may do what. Admins may always do everything. The channel roles (channel owner, channel moderator) count only in their channel. To give one member one extra right, make a role with it and give them that role under Members.')));
  Wrap := C.el('div', 'gridwrap');
  Table := C.el('table', 'grid perms');
  HeadRow := C.el('tr');
  HeadRow.appendChild(C.el('th', '', ''));
  List := TJSArray(Data['roles']);
  for I := 0 to List.length - 1 do
  begin
    R := TJSObject(List[I]);
    if Same(R['scope'], 'room') then Th := C.el('th', 'roomrole', RoleTitle(R['name'])) else Th := C.el('th', '', RoleTitle(R['name']));
    TJSObject(Th)['title'] := R['caption'];
    HeadRow.appendChild(Th);
  end;
  Table.appendChild(HeadRow);
  for I := 0 to TJSArray(Data['permissions']).length - 1 do PermissionRow(TJSObject(TJSArray(Data['permissions'])[I]));
  Wrap.appendChild(Table);
  Box.appendChild(Wrap);

  Box.appendChild(C.el('h2', '', T('Roles')));
  Roles := C.el('table', 'grid');
  for I := 0 to List.length - 1 do RoleRow(TJSObject(List[I]));
  Box.appendChild(Roles);
  Form := C.el('form', 'invite');
  Name := TJSHTMLInputElement(C.el('input'));
  Name.placeholder := T('new-role');
  Caption := TJSHTMLInputElement(C.el('input'));
  Caption.placeholder := T('What it is for');
  Scope := TJSHTMLSelectElement(C.el('select'));
  Choices := Items(Items('site', T('site')), Items('room', T('in one channel')));
  for I := 0 to Choices.length - 1 do
  begin
    Opt := C.el('option', '', TJSArray(Choices[I])[1]);
    TJSObject(Opt)['value'] := TJSArray(Choices[I])[0];
    Scope.appendChild(Opt);
  end;
  Add := C.el('button', 'primary', T('Make the role'));
  TKit(Form).add(Name, Caption, Scope, Add);
  Form.addEventListener('submit', TJSRawEventHandler(procedure(E: TJSEvent) async
    begin
      E.preventDefault;
      try
        await(JSValue, C.post('/api/admin/role', new(['name', Name.value, 'caption', Caption.value, 'scope', Scope.value])));
        C.route('/admin', False);
      except
        C.failed(JSExceptValue);
      end;
    end));
  Box.appendChild(Form);
end;

// Members as a list: sorted by any column on the server, a role or bans
// picked out; the one picked below with its roles and the ban.
procedure AdminMembers(Box: TJSHTMLElement; Data: TJSObject; Can: TCan);
var
  Giveable, Columns, RoleChoices: TJSArray;
  R: TJSObject;
  Search: string;
  I: NativeInt;

  procedure Detail(U: TJSObject; Holder: TJSHTMLElement; View: TListView);
  var
    Head, Sect, Panel, List, Roles, Acts: TJSHTMLElement;
    Facts, Have: TJSArray;
    Joined, Seen, Title, ClosedBy: JSValue;
    N: NativeInt;

    procedure AddressLine(A: TJSObject);
    var
      Li, B: TJSHTMLElement;
    begin
      Li := C.el('li');
      B := C.el('button', 'lv-link', A['ip']);
      TJSObject(B)['type'] := 'button';
      B.title := T('Its whole story under Address: score, blocks, requests');
      B.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
        var
          Today, Back: string;
        begin
          // the address panel reads the logs from the day before it was last seen, at most 30 days back
          Today := TJSString(TJSDate.new.toISOString).slice(0, 10);
          Back := TJSString(TDate.new(MathMax(TJSDate.parse(string(A['seen'])) - 864e5, TJSDate.now - 30 * 864e5)).toISOString).slice(0, 10);
          AddressPanel(A['ip'], Panel, new(['from', Back, 'to', Today]));
        end));
      TKit(Li).add(B, document.createTextNode(' ' + C.ago(A['seen']) + ', ' + TN(A['times'], '%d time', '%d times')));
      List.appendChild(Li);
    end;

    procedure RoleTick(Role: TJSObject);
    var
      Label_: TJSHTMLElement;
      Tick: TJSHTMLInputElement;
    begin
      Label_ := C.el('label');
      Tick := TJSHTMLInputElement(C.el('input'));
      Tick._type := 'checkbox';
      Tick.checked := Have.indexOf(Role['name']) >= 0;
      Tick.disabled := Same(U['name'], Me['name']) or not Can('manage-members');
      Tick.addEventListener('change', TJSRawEventHandler(procedure(E: TJSEvent) async
        begin
          if Tick.checked then Have.push(Role['name']) else Have.splice(Have.indexOf(Role['name']), 1);
          try
            C.toast(await(JSValue, C.post('/api/admin/member', new(['name', U['name'], 'roles', Have.join(',')]))));
            U['roles'] := Have.join(',');
            View.changed(U);
          except
            C.failed(JSExceptValue);
            Tick.checked := not Tick.checked;
          end;
        end));
      TKit(Label_).add(Tick, document.createTextNode(' ' + string(Role['name'])));
      Roles.appendChild(Label_);
    end;

    procedure Act(Caption: JSValue; const Cls: string; Run: TRun);
    var
      B: TJSHTMLElement;
    begin
      B := C.el('button', Cls, Caption);
      TJSObject(B)['type'] := 'button';
      B.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) async
        begin
          try
            await(JSValue, TJSPromise(Run()));
          except
            C.failed(JSExceptValue);
          end;
        end));
      Acts.appendChild(B);
    end;

    procedure Again;
    begin
      View.unpick;
      View.reload;
    end;

    function Reopen: JSValue; async;
    begin
      C.toast(await(JSValue, C.post('/api/admin/member', new(['name', U['name'], 'reopen', '1']))));
      C.toast(T('It has no password now: make a password link for %s.', U['name']));
      Again;
    end;

    function Ban: JSValue; async;
    var
      Banned: string;
    begin
      if not Truthy(U['banned']) and not window.confirm(T('Ban %s? They are signed out and can only read.', U['name'])) then Exit;
      if Truthy(U['banned']) then Banned := '0' else Banned := '1';
      C.toast(await(JSValue, C.post('/api/admin/member', new(['name', U['name'], 'banned', Banned]))));
      U['banned'] := not Truthy(U['banned']);
      View.changed(U);
    end;

    // for a member who cannot get in: the link is shown once, to hand over
    function PasswordLink: JSValue; async;
    var
      Address: string;
      Shown, Copy, Made, Old: TJSHTMLElement;
    begin
      Address := TJSString(await(string, C.post('/api/admin/member', new(['name', U['name'], 'password_link', '1'])))).trim;
      if TJSString(Address).charAt(0) = '/' then Address := window.location.origin + SiteUrl(Address);
      Shown := C.el('pre', 'newtoken', Address);
      Copy := C.el('button', '', T('Copy'));
      TJSObject(Copy)['type'] := 'button';
      Copy.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
        begin
          TClipboard(TJSObject(window.navigator)['clipboard']).writeText(Address)._then(function(Done: JSValue): JSValue
            begin
              Copy.textContent := T('Copied');
            end);
        end));
      Made := C.el('div', 'lv-actions member-link');
      TKit(Made).add(Shown, Copy, C.el('p', 'hint', T('Give this link to %s. It sets a new password, works once and for a week. Private conversations locked with the old password stay closed.', U['name'])));
      Old := C.find('.member-link', Holder);
      if Truthy(Old) then TKit(Old).swapFor(Made) else TKit(Acts).putAfter(Made);
    end;

    function Rename: JSValue; async;
    var
      Name: JSValue;
    begin
      Name := window.prompt(T('A new name for %s. Mentions of the old name stay as they were written.', U['name']), string(U['name']));
      if not Truthy(Name) or Same(TJSString(Name).trim, U['name']) then Exit;
      C.toast(await(JSValue, C.post('/api/admin/member', new(['name', U['name'], 'rename', TJSString(Name).trim]))));
      Again;
    end;

    function CloseAccount: JSValue; async;
    var
      Reason: JSValue;
    begin
      Reason := window.prompt(T('Close the account of %s? They are signed out for good; their address, password and profile are wiped, and what they wrote stays. Why? (kept with the account)', U['name']), '');
      if not Truthy(Reason) or not Truthy(TJSString(Reason).trim) then Exit;
      C.toast(await(JSValue, C.post('/api/admin/member', new(['name', U['name'], 'close', '1', 'reason', TJSString(Reason).trim]))));
      Again;
    end;

  begin
    Head := C.el('div', 'lv-detail-head');
    Head.appendChild(C.link('/u/' + C.enc(U['name']), '', U['name']));
    if Truthy(U['banned']) then Head.appendChild(C.chip(T('Banned'), 'bad'));
    if Truthy(U['closed']) then Head.appendChild(C.chip(T('Closed'), 'bad'));
    Holder.appendChild(Head);
    if Truthy(U['joined']) then Joined := DateText(U['joined']) else Joined := '';
    if Truthy(U['seen']) then Seen := C.ago(U['seen']) else Seen := T('never back');
    Facts := Items(Items(T('Joined'), Joined), Items(T('Last here'), Seen), Items(T('Messages'), LocaleNumber(U['posts'])));
    if Truthy(U['closed']) then
    begin
      if Same(U['closed_by'], U['name']) then ClosedBy := T('the member') else ClosedBy := U['closed_by'];
      Facts := Facts.concat(Items(Items(T('Closed'), DateText(U['closed'])), Items(T('Closed by'), ClosedBy), Items(T('Reason'), U['closed_reason'])));
    end;
    C.facts(Holder, Facts);
    // admins only (view-member-addresses): the server sends them to nobody else
    if Truthy(U['addresses']) then
    begin
      Sect := C.el('div', 'member-addresses');
      if Num(U['address_count']) > TJSArray(U['addresses']).length then
        Title := T('Addresses: the %d newest of %d', TJSArray(U['addresses']).length, U['address_count'])
      else Title := T('Addresses');
      Sect.appendChild(C.el('h4', '', Title));
      Panel := C.el('div', 'lv-detail');
      List := C.el('ul', 'member-address-list');
      for N := 0 to TJSArray(U['addresses']).length - 1 do AddressLine(TJSObject(TJSArray(U['addresses'])[N]));
      TKit(Sect).add(List, Panel);
      Holder.appendChild(Sect);
    end;
    Have := Filled(U['roles']);
    Roles := C.el('div', 'lv-actions rolechecks');
    // a closed account holds no role; it can be opened again, or renamed
    Roles.hidden := Truthy(U['closed']);
    Roles.appendChild(C.el('span', 'dim', T('Roles') + ':'));
    for N := 0 to Giveable.length - 1 do RoleTick(TJSObject(Giveable[N]));
    Holder.appendChild(Roles);
    if Same(U['name'], Me['name']) then
    begin
      Holder.appendChild(C.el('p', 'hint', T('Ask another admin to change your own account.')));
      Exit;
    end;
    Acts := C.el('div', 'lv-actions');
    if Truthy(U['closed']) then
    begin
      if Can('manage-members') then Act(T('Reopen the account'), '', @Reopen);
    end
    else if Can('ban') then
    begin
      if Truthy(U['banned']) then Act(T('Lift the ban'), '', @Ban) else Act(T('Ban'), 'bad', @Ban);
    end;
    if Can('manage-members') then
    begin
      if not Truthy(U['closed']) then Act(T('Password link'), '', @PasswordLink);
      Act(T('Rename'), '', @Rename);
      if not Truthy(U['closed']) then Act(T('Close the account'), 'bad', @CloseAccount);
    end;
    if Acts.children.length > 0 then Holder.appendChild(Acts);
  end;

  function Remote(State: TJSObject): TJSObject; async;
  var
    A, Filters: TJSObject;
  begin
    Filters := TJSObject(State['filters']);
    A := await(TJSObject, C.get('/api/admin/members?q=' + C.enc(State['q']) + '&sort=' + C.enc(State['sort']) + '&role=' + C.enc(Either(Filters['role'], '')) +
      '&state=' + C.enc(Either(Filters['state'], '')) + '&page=' + string(State['page'])));
    Result := new(['rows', A['members'], 'total', A['total']]);
  end;

  function RolesCell(U: TJSObject): JSValue;
  var
    Span: TJSHTMLElement;
    Names: TJSArray;
    N: NativeInt;
  begin
    Span := C.el('span', 'chips');
    Names := Filled(U['roles']);
    for N := 0 to Names.length - 1 do
      if Same(Names[N], 'admin') then Span.appendChild(C.chip(Names[N], 'admin')) else Span.appendChild(C.chip(Names[N], ''));
    if Truthy(U['banned']) then Span.appendChild(C.chip(T('Banned'), 'bad'));
    if Truthy(U['closed']) then Span.appendChild(C.chip(T('Closed'), 'bad'));
    Result := Span;
  end;

  function AddressesCell(U: TJSObject): JSValue;
  begin
    if not Truthy(U['addresses']) or not Truthy(TJSArray(U['addresses']).length) then Exit('');
    Result := string(TJSObject(TJSArray(U['addresses'])[0])['ip']);
    if Num(U['address_count']) > 1 then Result := string(Result) + ' +' + Str(Num(U['address_count']) - 1);
  end;

begin
  Giveable := TJSArray.new;
  for I := 0 to TJSArray(Data['roles']).length - 1 do
  begin
    R := TJSObject(TJSArray(Data['roles'])[I]);
    if Same(R['scope'], 'site') and not Same(R['name'], 'member') and not Same(R['name'], 'guest') then Giveable.push(R);
  end;
  if Can('view-member-addresses') then Search := T('Find a member by name or address') else Search := T('Find a member by name');
  Columns := Items(
    new(['key', 'name', 'title', T('Member'), 'cell', TRowValue(function(U: TJSObject): JSValue begin Result := C.link('/u/' + C.enc(U['name']), '', U['name']); end)]),
    new(['key', 'roles', 'title', T('Roles'), 'nosort', True, 'cell', TRowValue(@RolesCell)]),
    new(['key', 'posts', 'title', T('Messages'), 'num', True]),
    new(['key', 'joined', 'title', T('Joined'), 'down', True, 'wide', True, 'cell', TRowValue(function(U: TJSObject): JSValue
      begin
        if Truthy(U['joined']) then Result := DateText(U['joined']) else Result := '';
      end)]),
    new(['key', 'seen', 'title', T('Last here'), 'down', True, 'cell', TRowValue(function(U: TJSObject): JSValue
      begin
        if Truthy(U['seen']) then Result := C.ago(U['seen']) else Result := T('never back');
      end)]));
  if Can('view-member-addresses') then
    Columns := Columns.concat(Items(new(['key', 'addresses', 'title', T('Address'), 'nosort', True, 'wide', True, 'cell', TRowValue(@AddressesCell)])));
  RoleChoices := TJSArray.new;
  for I := 0 to Giveable.length - 1 do RoleChoices.push(Items(TJSObject(Giveable[I])['name'], TJSObject(Giveable[I])['name']));
  RoleChoices := RoleChoices.concat(Items(Items('none', T('No role given'))));
  ListView(Box, TListOptions(new([
    'id', 'members', 'key', TRowValue(function(U: TJSObject): JSValue begin Result := U['name']; end), 'sort', '-seen', 'csv', 'members',
    'search', Search,
    'remote', @Remote,
    'columns', Columns,
    'filters', Items(
      new(['key', 'role', 'title', T('Role'), 'all', T('Every role'), 'options', RoleChoices]),
      new(['key', 'state', 'title', T('Banned or closed'), 'all', T('Everyone'),
        'options', Items(Items('active', T('Neither')), Items('banned', T('Banned')), Items('closed', T('Closed')))])),
    'noun', TCountText(function(N: JSValue): JSValue begin Result := TN(N, '%d member', '%d members'); end),
    'detail', @Detail])));
end;

end.
