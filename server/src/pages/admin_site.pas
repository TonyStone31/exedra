unit Admin_Site;

{ The admin page's Storage, Overview and Look tabs. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, Admin_List;

procedure AdminStorage(Box: TJSHTMLElement);
procedure AdminOverview(Box: TJSHTMLElement; Data: TJSObject; Can: TCan);
procedure AdminLook(Box: TJSHTMLElement);

implementation

type
  // what another script adds to the overview: called as its own method
  TOverviewExtra = class external name 'Object'(TJSObject)
    procedure build(Holder: TJSHTMLElement);
  end;

// Web declares location.reload with a required argument only.
procedure ReloadPage; external name 'location.reload';

procedure AdminStorage(Box: TJSHTMLElement);

  procedure Draw; async;
  var
    Data: TJSObject;
    List, Sorted, Rows: TJSArray;
    Item: TJSObject;
    Used, Share, Sum: double;
    Tiles, Disk, Meter, Fill: TJSHTMLElement;
    Cls: string;
    I: NativeInt;
  begin
    try
      Data := await(TJSObject, C.get('/api/admin/storage'));
      List := TJSArray(Data['items']);
      if Num(Data['disk_total']) > 0 then
      begin
        Used := Num(Data['disk_total']) - Num(Data['disk_free']);
        Share := Used / Num(Data['disk_total']);
        Tiles := C.el('div', 'tiles-admin');
        if Share > 0.9 then Cls := 'warn' else Cls := '';
        Disk := Stat(Tiles, Str(MathRound(Share * 100)) + '%', T('Disk used'),
          C.sizeText(Used) + ' ' + T('of') + ' ' + C.sizeText(Data['disk_total']), Cls);
        if Share > 0.95 then Cls := 'meter bad' else if Share > 0.8 then Cls := 'meter warn' else Cls := 'meter';
        Meter := C.el('div', Cls);
        Fill := C.el('i');
        TJSObject(Fill.style)['width'] := Str(MathRound(Share * 100)) + '%';
        Meter.appendChild(Fill);
        Disk.appendChild(Meter);
        Stat(Tiles, C.sizeText(Data['disk_free']), T('Free'), undefined, undefined);
        Sum := 0;
        for I := 0 to List.length - 1 do Sum := Sum + Num(TJSObject(List[I])['bytes']);
        Stat(Tiles, C.sizeText(Sum), T('The site uses'), T('database and folders'), undefined);
        Box.appendChild(Tiles);
      end;
      if List.length > 0 then
      begin
        Sorted := SortBy(List.slice(0), function(A, B: TJSObject): double begin Result := Num(B['bytes']) - Num(A['bytes']); end);
        Rows := TJSArray.new;
        for I := 0 to Sorted.length - 1 do
        begin
          Item := TJSObject(Sorted[I]);
          Rows.push(new(['name', T(Item['caption']), 'value', Item['bytes']]));
        end;
        Bars(Box, Rows, TFormat(C['sizeText']));
      end;
      Box.appendChild(C.el('p', 'hint', T('Measured in the background at most once an hour. Database sizes are engine estimates including indexes. Folder sizes exclude symbolic links.')));
      if List.length = 0 then Box.appendChild(C.el('p', 'notice', T('No storage measurement yet.')));
      Rows := TJSArray.new;
      for I := 0 to List.length - 1 do
      begin
        Item := TJSObject(List[I]);
        if Truthy(Item['complete']) then Cls := T('Complete') else Cls := T('Partial');
        Rows.push(Items(T(Item['caption']), C.sizeText(Item['bytes']), DateTimeText(Item['measured']), Cls));
      end;
      AdminTable(Box, Items(T('Group or folder'), T('Size'), T('Measured'), T('Status')), Rows);
    except
      C.failed(JSExceptValue);
    end;
  end;

begin
  Draw;
end;

// The first thing an admin sees: which modules (parts) this site runs, each with
// its switch, and what waits for attention.
procedure AdminOverview(Box: TJSHTMLElement; Data: TJSObject; Can: TCan);
var
  Lit, Settings, Switches, List, Brought: TJSArray;
  Cards, Stats, Waiting, Holder: TJSHTMLElement;
  Names, Fronts, Extra: TJSObject;
  Cls: string;
  Lively, I: NativeInt;

  procedure Card(P: TJSObject);
  var
    Part, Head, Tools, Flip: TJSHTMLElement;
    Name, Words, About: string;

    procedure Switch(E: TJSEvent); async;
    var
      Fields: TJSObject;
    begin
      TJSObject(Flip)['disabled'] := True;
      try
        Fields := TJSObject.new;
        if Truthy(P['on']) then Fields[Name] := '0' else Fields[Name] := '1';
        await(JSValue, C.post('/api/admin/settings', Fields));
        // the page's list and the top bar follow the parts: read it all again
        ReloadPage;
      except
        C.failed(JSExceptValue);
        TJSObject(Flip)['disabled'] := False;
      end;
    end;

  begin
    Name := string(P['name']);
    if Truthy(P['on']) then Part := C.el('div', 'part-card on') else Part := C.el('div', 'part-card off');
    Head := C.el('h3', '', Either(Names[Name], T(TJSString(TJSString(Name).charAt(0)).toUpperCase + TJSString(Name).slice(1))));
    if Truthy(P['on']) then Head.appendChild(C.el('span', 'part-state', T('On')))
    else Head.appendChild(C.el('span', 'part-state', T('Off')));
    Part.appendChild(Head);
    // the caption says what the part is, after its name and a colon
    Words := T(P['caption']);
    if TJSString(Words).indexOf(': ') > 0 then About := TJSString(Words).slice(TJSString(Words).indexOf(': ') + 2) else About := Words;
    Part.appendChild(C.el('p', '', TJSString(TJSString(About).charAt(0)).toUpperCase + TJSString(About).slice(1)));
    Tools := C.el('div', 'part-tools');
    if Truthy(P['change']) then
    begin
      if Truthy(P['on']) then Flip := C.el('button', '', T('Turn off')) else Flip := C.el('button', 'primary', T('Turn on'));
      TJSObject(Flip)['type'] := 'button';
      Flip.addEventListener('click', TJSRawEventHandler(@Switch));
      Tools.appendChild(Flip);
    end;
    if Truthy(P['on']) then Tools.appendChild(C.link(Either(Fronts[Name], '/' + Name), 'small-link', T('Open')));
    Part.appendChild(Tools);
    Cards.appendChild(Part);
  end;

begin
  Lit := TJSArray(TJSString(Str(Either(Data['parts'], ''))).split(' '));
  Settings := TJSArray(Either(Data['settings'], TJSArray.new));
  Switches := TJSArray.new;
  for I := 0 to Settings.length - 1 do
    if Same(TJSObject(Settings[I])['group'], 'Parts') then Switches.push(Settings[I]);
  if Truthy(Data['unlisted_proxies']) then
    Box.appendChild(C.el('p', 'problem', T('Requests arrive through %s, which the config file does not name under proxies. Until it does, every visitor looks like that one address and the guard cannot tell them apart.', Data['unlisted_proxies'])));
  Box.appendChild(C.el('h2', '', T('Community modules')));
  Box.appendChild(C.el('p', 'hint', T('Each module can be on or off. A module that is off has no pages and no entries here; what it holds is kept.')));
  Cards := C.el('div', 'part-cards');
  Box.appendChild(Cards);
  Names := new(['chat', T('Chat'), 'wiki', T('Wiki'), 'forum', T('Forum')]);
  Fronts := new(['chat', '/', 'wiki', '/wiki', 'forum', '/forum']);
  List := TJSArray.new;
  if Switches.length > 0 then
    for I := 0 to Switches.length - 1 do
      List.push(new(['name', TJSObject(Switches[I])['name'], 'caption', TJSObject(Switches[I])['caption'],
        'on', Same(TJSObject(Switches[I])['value'], '1'), 'change', True]))
  else
    for I := 0 to Lit.length - 1 do
      if Truthy(Lit[I]) then List.push(new(['name', Lit[I], 'caption', '', 'on', True, 'change', False]));
  for I := 0 to List.length - 1 do Card(TJSObject(List[I]));
  Box.appendChild(C.el('h2', '', T('The site')));
  Stats := C.el('div', 'tiles-admin');
  Box.appendChild(Stats);
  if not IsUndef(Data['members_total']) then Stat(Stats, Data['members_total'], T('Members'), undefined, undefined);
  if Can('read-reports') then
  begin
    if Num(Either(Data['open_reports'], 0)) > 0 then Cls := 'warn' else Cls := '';
    Waiting := Stat(Stats, Either(Data['open_reports'], 0), T('Reports'), '', Cls);
    TJSObject(Waiting.style)['cursor'] := 'pointer';
    Waiting.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin S.adminTab('Reports'); end));
  end;
  Lively := 0;
  for I := 0 to List.length - 1 do
    if Truthy(TJSObject(List[I])['on']) then Inc(Lively);
  Stat(Stats, Lively, T('Modules on'), undefined, undefined);
  if Truthy(Data['version']) then Stat(Stats, Data['version'], T('Exedra version'), undefined, undefined);
  // what other scripts add to this page
  Brought := TJSArray(Extras['adminOverview']);
  I := 0;
  while I < Brought.length do
  begin
    Extra := TJSObject(Brought[I]);
    if not Truthy(Extra['permission']) or Can(string(Extra['permission'])) then
    begin
      Holder := C.el('section', 'overview-extra');
      Box.appendChild(Holder);
      TOverviewExtra(Extra).build(Holder);
    end;
    Inc(I);
  end;
end;

// The site's icon (made in every size from one square picture) and the
// logo in the header.
procedure AdminLook(Box: TJSHTMLElement);
var
  Logo: TJSHTMLElement;
  Shown: string;

  procedure Part(const What: string; Title, Hint: JSValue; const Preview: string);
  var
    Form, Img, FileBox, Save, Remove: TJSHTMLElement;

    procedure Send(Fields: TJSFormData); async;
    var
      Mark: string;
    begin
      Fields.append('what', What);
      try
        C.toast(await(JSValue, C.post('/api/admin/look', Fields)));
        if TJSString(Preview).includes('?') then Mark := '&' else Mark := '?';
        TJSObject(Img)['src'] := Preview + Mark + Str(TJSDate.now);
      except
        C.failed(JSExceptValue);
      end;
    end;

  begin
    Form := C.el('form', 'settings look');
    Form.appendChild(C.el('h3', '', Title));
    Form.appendChild(C.el('p', 'hint', Hint));
    Img := C.el('img', 'lookpreview ' + What);
    TJSObject(Img)['alt'] := '';
    Img.addEventListener('error', TJSRawEventHandler(procedure(E: TJSEvent) begin Img.hidden := True; end));
    Img.addEventListener('load', TJSRawEventHandler(procedure(E: TJSEvent) begin Img.hidden := False; end));
    TJSObject(Img)['src'] := Preview;
    FileBox := C.el('input');
    TJSObject(FileBox)['type'] := 'file';
    TJSObject(FileBox)['name'] := 'picture';
    TJSObject(FileBox)['accept'] := 'image/png,image/jpeg';
    Save := C.el('button', 'primary', T('Upload'));
    Remove := C.el('button', '', T('Use none'));
    TJSObject(Remove)['type'] := 'button';
    Form.addEventListener('submit', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        E.preventDefault;
        Send(TJSFormData.new(TJSHTMLFormElement(Form)));
      end));
    Remove.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      var
        Fields: TJSFormData;
      begin
        Fields := TJSFormData.new;
        Fields.append('remove', '1');
        Send(Fields);
      end));
    TKit(Form).add(Img, FileBox, Save, Remove);
    Box.appendChild(Form);
  end;

begin
  Logo := C.find('.brandlogo');
  Part('icon', T('Icon'), T('One square PNG or JPEG, 512 by 512 pixels or more. It becomes the browser tab icon, the installed app''s icon and the notification icon, in every size they need.'), '/icon-192.png');
  if Truthy(Logo) then Shown := string(TJSObject(Logo)['src']) else Shown := '/site/logo.png';
  Part('logo', T('Logo'), T('Shown in the header, 32 pixels high, beside the name or instead of it (Settings, "Show the name beside the logo"). It sits on the dark header bar in both themes, so use light lettering. A wide PNG with a clear background works best.'), Shown);
end;

end.
