unit AdminPage;

{ The site's admin page, loaded when it is opened.  It runs with the chat off
  too: window.Chat is the site's shell under its first name (also window.Site). }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

implementation

uses JS, Web, Admin_List, Admin_Address, Admin_Backup, Admin_Reports, Admin_Visitors, Admin_Site, Admin_Settings,
  Admin_Chat, Admin_Members;

type
  TBuild = reference to procedure(Holder: TJSHTMLElement);
  // a tab of the page: its button, its holder, and how its count is set
  TPart = class external name 'Object'(TJSObject)
    button, holder: TJSHTMLElement;
    title, group: JSValue;
    procedure setCount(N: JSValue);
  end;

function OpenAdmin: JSValue; async;
var
  Generation: JSValue;
  Data: TJSObject;
  Head, Menu, Page, Nav, Rooms: TJSHTMLElement;
  Body: TJSElement;
  Parts, Scripts, Tabs, Settings, Lit, Modules, Groups, Order, Members: TJSArray;
  PartOfGroup, Extra: TJSObject;
  Last: JSValue;
  Selected: TPart;
  I, J: NativeInt;

  function Can(const P: string): boolean;
  begin
    Result := TJSArray(Data['can']).indexOf(P) >= 0;
  end;

  procedure Tab(Title: JSValue; Build: TBuild; Caption, Count, Group: JSValue);
  var
    B, Badge, Holder: TJSHTMLElement;
    Built: boolean;

    procedure SetCount(N: JSValue);
    begin
      Badge.hidden := not (Num(N) > 0);
      if Num(N) > 0 then Badge.textContent := Str(N) else Badge.textContent := '';
    end;

  begin
    B := C.el('button', 'room');
    TJSObject(B)['type'] := 'button';
    B.appendChild(C.el('span', 'name', Either(Either(Caption, new(['Members', T('Members'), 'Permissions', T('Permissions'), 'Settings', T('Settings'),
      'Look', T('Look'), 'Channels', T('Channels'), 'Private', T('Private'), 'Reports', T('Reports'), 'Blocked', T('Blocked')])[string(Title)]), Title)));
    // how many things wait there, when the tab knows
    Badge := C.el('span', 'badge mention');
    Badge.hidden := True;
    B.appendChild(Badge);
    if jsTypeOf(Count) = 'number' then SetCount(Count)
    else if jsTypeOf(Count) = 'function' then
      TJSPromise.resolve._then(TJSPromiseResolver(Count))._then(TJSPromiseResolver(@SetCount)).catch(function(Why: JSValue): JSValue begin end);
    Holder := C.el('section', 'part');
    Holder.hidden := True;
    Page.appendChild(Holder);
    // a tab is built the first time it is opened: one tab's requests at a time, not all of them at once
    Built := False;
    B.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      var
        N: NativeInt;
      begin
        for N := 0 to Parts.length - 1 do
        begin
          TPart(Parts[N]).button.classList.remove('active');
          TPart(Parts[N]).holder.hidden := True;
        end;
        B.classList.add('active');
        Holder.hidden := False;
        if not Built then
        begin
          Built := True;
          Build(Holder);
        end;
        // on a phone the list is a drawer over the page: it closes on a choice
        if Body.classList.contains('menu') then C.toggleMenu;
        Stream.scrollTop := 0;
        try
          window.localStorage.setItem('admin-tab', string(Title));
        except
        end;
      end));
    Parts.push(new(['button', B, 'holder', Holder, 'title', Title, 'setCount', @SetCount, 'group', Either(Group, 'More')]));
  end;

  function PartSettings(const Group: string): boolean;
  var
    N: NativeInt;
  begin
    Result := False;
    for N := 0 to Settings.length - 1 do
      if Same(PartOfGroup[string(TJSObject(Settings[N])['group'])], Group) then Exit(True);
  end;

  // each part's own settings, last in its group
  procedure PartTab(const Group: string);
  begin
    Tab(Group + ' settings', procedure(Box: TJSHTMLElement)
      begin
        AdminSettings(Box, Data, function(G: JSValue): boolean begin Result := Same(PartOfGroup[string(G)], Group); end, Group);
      end, T('Settings'), undefined, Group);
  end;

  function PartByTitle(Title: JSValue): TPart;
  var
    N: NativeInt;
  begin
    for N := 0 to Parts.length - 1 do
      if Same(TPart(Parts[N]).title, Title) then Exit(TPart(Parts[N]));
    Result := TPart(undefined);
  end;

  function AdminTab(Title: JSValue): boolean;
  var
    P: TPart;
  begin
    P := PartByTitle(Title);
    if Truthy(P) then P.button.click;
    Result := Truthy(P);
  end;

  procedure AdminCount(Title, N: JSValue);
  var
    P: TPart;
  begin
    P := PartByTitle(Title);
    if Truthy(P) then P.setCount(N);
  end;

begin
  Generation := S['generation'];
  try
    Scripts := TJSArray(Extras['adminScripts']);
    I := 0;
    while I < Scripts.length do
    begin
      await(JSValue, C.loadScript(TJSObject(Scripts[I])['src']));
      Inc(I);
    end;
  except
    C.failed(JSExceptValue);
    Exit;
  end;
  if not Same(Generation, S['generation']) then Exit;
  Data := await(TJSObject, C.get('/api/admin'));
  if not Same(Generation, S['generation']) then Exit;
  S['title'] := T('Admin');
  Head := C.find('#roomhead');
  Menu := C.iconButton('menu', T('Channels'), 'menubtn');
  Menu.addEventListener('click', TJSRawEventHandler(C['toggleMenu']));
  TKit(Head).add(Menu, C.el('div', 'titles'));
  C.find('.titles', Head).appendChild(C.el('h1', '', T('Running %s', SiteName)));
  if not IsUndef(Data['members_total']) then
    C.find('.titles', Head).appendChild(C.el('p', 'topic', TN(Data['members_total'], '%d members', '%d members')));
  Page := C.el('div', 'admin');
  // a page read from the top: the stream is not held at its bottom, as a room's is
  TJSObject(Stream)['noPin'] := True;
  TJSObject(Stream)['pinned'] := False;
  Stream.appendChild(Page);
  Stream.scrollTop := 0;

  // The page's list: one part of the page at a time, chosen on the left
  // where a room list would be, under the group it belongs to.
  Body := document.body;
  Nav := C.find('#adminnav');
  if not Truthy(Nav) then
  begin
    Nav := C.el('nav');
    Nav.id := 'adminnav';
    Rooms := C.find('#roomlist');
    if Truthy(Rooms) and Truthy(TJSObject(Rooms)['after']) then TKit(Rooms).putAfter(Nav)
    else Page.appendChild(Nav);
  end;
  Nav.hidden := False;
  Nav.setAttribute('aria-label', T('Admin'));
  Nav.replaceChildren;
  Body.classList.add('admin-view');
  Parts := TJSArray.new;

  FilePaths := TJSArray(Either(Data['file_paths'], TJSArray.new));
  Lit := TJSArray(TJSString(Str(Either(Data['parts'], ''))).split(' '));
  // a group of settings belongs to the part that registered it, and is shown with that part
  PartOfGroup := TJSObject.assign(new(['Chat', 'Chat', 'Wiki', 'Wiki', 'Forum', 'Forum']), TJSObject(Extras['settingGroups']));
  // every module the site knows, on or off
  Settings := TJSArray(Either(Data['settings'], TJSArray.new));
  Modules := TJSArray.new;
  for I := 0 to Settings.length - 1 do
    if Same(TJSObject(Settings[I])['group'], 'Parts') then Modules.push(TJSObject(Settings[I])['name']);
  if Truthy(Data['settings']) or Can('view-admin') then
    Tab('Overview', procedure(Box: TJSHTMLElement) begin AdminOverview(Box, Data, @Can); end, T('Overview'), undefined, 'Site');
  Tabs := TJSArray(Extras['adminTabs']);
  I := 0;
  while I < Tabs.length do
  begin
    Extra := TJSObject(Tabs[I]);
    if Truthy(Extra['first']) and Truthy(Extra['permission']) and Can(string(Extra['permission'])) then
      Tab(Extra['title'], TBuild(Extra['build']), T(Extra['title']), Extra['badge'], Either(Extra['group'], 'Site'));
    Inc(I);
  end;
  if Truthy(Data['settings']) and Can('manage-settings') then
    Tab('Settings', procedure(Box: TJSHTMLElement)
      begin
        AdminSettings(Box, Data, function(Group: JSValue): boolean begin Result := not Same(Group, 'Parts') and not Truthy(PartOfGroup[string(Group)]); end, undefined);
      end, undefined, undefined, 'Site');
  if Truthy(Data['settings']) and Can('manage-settings') then Tab('Look', TBuild(@AdminLook), undefined, undefined, 'Site');
  if Truthy(Data['members']) then
    Tab('Members', procedure(Box: TJSHTMLElement) begin AdminMembers(Box, Data, @Can); end, undefined, undefined, 'Site');
  if Truthy(Data['permissions']) then
    Tab('Permissions', procedure(Box: TJSHTMLElement) begin AdminPermissions(Box, Data); end, undefined, undefined, 'Site');
  if Can('read-reports') then Tab('Reports', TBuild(@AdminReports), undefined, Either(Data['open_reports'], 0), 'Site');
  if Can('view-visitors') or Can('manage-blocks') then Tab('Visitors', TBuild(@AdminVisitors), T('Visitors'), undefined, 'Server');
  if Can('view-storage') then Tab('Storage', TBuild(@AdminStorage), T('Storage'), undefined, 'Server');
  if Can('manage-backups') then Tab('Backup', TBuild(@AdminBackup), T('Backup'), undefined, 'Server');
  if Truthy(Data['channels']) then
    Tab('Channels', procedure(Box: TJSHTMLElement) begin AdminChannels(Box, Data); end, undefined, undefined, 'Chat');
  if (Lit.indexOf('chat') >= 0) and Can('manage-private') then Tab('Private', TBuild(@AdminPrivate), undefined, undefined, 'Chat');
  // tabs other scripts bring: title, the permission that shows it, what
  // builds it into the box, and the group it is listed under
  I := 0;
  while I < Tabs.length do
  begin
    Extra := TJSObject(Tabs[I]);
    if not Truthy(Extra['first']) and Truthy(Extra['permission']) and Can(string(Extra['permission'])) and
      (not Truthy(Extra['part']) or (Lit.indexOf(Extra['part']) >= 0)) then
      Tab(Extra['title'], TBuild(Extra['build']), T(Extra['title']), Extra['badge'], Extra['group']);
    Inc(I);
  end;
  // each part's own settings, last in its group
  if Truthy(Data['settings']) then
  begin
    Groups := Items('Chat', 'Wiki', 'Forum').concat(TJSObject.values(Extras['settingGroups']));
    for I := 0 to Groups.length - 1 do
      if (Groups.indexOf(Groups[I]) = I) and PartSettings(string(Groups[I])) and
        ((Modules.indexOf(TJSString(Groups[I]).toLowerCase) < 0) or (Lit.indexOf(TJSString(Groups[I]).toLowerCase) >= 0)) then
        PartTab(string(Groups[I]));
  end;

  // the list on the left: the site first, then the server, then each part
  Order := Items('Site', 'Server', 'Chat', 'Wiki', 'Forum');
  for I := 0 to Parts.length - 1 do
    if Order.indexOf(TPart(Parts[I]).group) < 0 then Order.push(TPart(Parts[I]).group);
  for I := 0 to Order.length - 1 do
  begin
    Members := TJSArray.new;
    for J := 0 to Parts.length - 1 do
      if Same(TPart(Parts[J]).group, Order[I]) then Members.push(Parts[J]);
    if Members.length = 0 then Continue;
    Nav.appendChild(C.el('div', 'group', T(Order[I])));
    for J := 0 to Members.length - 1 do Nav.appendChild(TPart(Members[J]).button);
  end;

  // what this admin may do, for panels built later (the address panel's block buttons)
  S['adminCan'] := @Can;
  // another tab opened from a row (an address looked up from anywhere), and a tab's count changed
  S['adminTab'] := @AdminTab;
  S['adminCount'] := @AdminCount;
  if Parts.length > 0 then Last := TPart(Parts[0]).title else Last := 'Overview';
  try
    Last := Either(window.localStorage.getItem('admin-tab'), Last);
  except
  end;
  Selected := PartByTitle(Last);
  if not Truthy(Selected) then Selected := TPart(Parts[0]);
  if Truthy(Selected) then Selected.button.click;
  C.syncNow(True);
end;

initialization
  C['listView'] := @ListView;
  C['stat'] := @Stat;
  C['adminTable'] := @AdminTable;
  C['openAdmin'] := @OpenAdmin;
end.
