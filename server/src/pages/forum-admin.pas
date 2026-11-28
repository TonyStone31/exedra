unit ForumAdminPage;

{ The forum's boards and categories in the site's admin shell. }

{$mode objfpc}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

procedure Start;

implementation

uses JS, Web, PageKit, PageGlobals;

type
  TAction = reference to procedure;

function Number(Value: JSValue): double; external name 'Number';

// JavaScript's ===: a number and the same digits as text differ.
function Same(A, B: JSValue): boolean;
begin
  Result := (jsTypeOf(A) = jsTypeOf(B)) and (A = B);
end;

function El(const Tag: string; const Text: JSValue = undefined): TJSHTMLElement;
begin
  Result := MakeElement(Tag);
  if jsTypeOf(Text) <> 'undefined' then TJSObject(Result)['textContent'] := Text;
end;

function Button(const Text: string; Action: TAction): TJSHTMLButtonElement;
begin
  Result := TJSHTMLButtonElement(El('button', Text));
  Result._type := 'button';
  Result.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Action(); end));
end;

function Value(Item: TJSObject; const Key: string; const Fallback: JSValue): JSValue;
begin
  Result := Item[Key];
  if not Truthy(Result) then Result := Fallback;
end;

procedure Build(Box: TJSHTMLElement); async;
var
  Boards, Categories, Permissions: TJSArray;
  Error, Content: TJSHTMLElement;
  Busy: boolean;
  Data: TJSObject;

  procedure Draw; forward;
  procedure Load; async; forward;

  procedure Change(const Path: string; Fields: TJSObject); async;
  var
    Buttons: TJSNodeList;
    Disabled: array of boolean;
    I: integer;
  begin
    if Busy then Exit;
    Busy := True; Error.textContent := '';
    Buttons := Box.querySelectorAll('button'); SetLength(Disabled, Buttons.length);
    for I := 0 to Buttons.length - 1 do
    begin
      Disabled[I] := TJSHTMLButtonElement(Buttons[I]).disabled;
      TJSHTMLButtonElement(Buttons[I]).disabled := True;
    end;
    try
      try
        await(SiteShell.post('/api/forum/admin/' + Path, Fields));
        await(Load);
      except
        Error.textContent := string(TJSObject(JSExceptValue)['message']);
      end;
    finally
      Busy := False;
      for I := 0 to Buttons.length - 1 do TJSHTMLButtonElement(Buttons[I]).disabled := Disabled[I];
    end;
  end;

  function Field(Form: TJSHTMLElement; const Name, Caption: string; Initial: JSValue; const Kind: string = ''): TJSHTMLElement;
  var
    Label_: TJSHTMLElement;
    Input: TJSHTMLElement;
  begin
    Label_ := El('label', Caption + ' ');
    if Kind = 'textarea' then Input := El('textarea') else Input := El('input');
    TJSObject(Input)['name'] := Name;
    if jsTypeOf(Initial) = 'undefined' then TJSObject(Input)['value'] := '' else TJSObject(Input)['value'] := string(Initial);
    if (Kind <> '') and (Kind <> 'textarea') then TJSObject(Input)['type'] := Kind;
    Label_.appendChild(Input); Form.appendChild(Label_); Result := Input;
  end;

  procedure Edit(Board: TJSObject);
  var
    Form: TJSHTMLFormElement;
    Values: TJSObject;
    BoardId: JSValue;
    HasChildren: boolean;
    ParentLabel, CategoryLabel: TJSHTMLElement;
    Parent, Category: TJSHTMLSelectElement;
    Option: TJSHTMLOptionElement;
    Save: TJSHTMLButtonElement;
    Item: TJSObject;
    I: integer;
  begin
    Form := TJSHTMLFormElement(El('form')); Values := TJSObject.new;
    BoardId := Value(Board, 'id', 0); HasChildren := False;
    for I := 0 to Boards.length - 1 do if Same(TJSObject(Boards[I])['parent_id'], BoardId) then HasChildren := True;
    Values['name'] := Field(Form, 'name', T('Name'), Value(Board, 'name', ''));
    TJSHTMLInputElement(Values['name']).required := True; TJSHTMLInputElement(Values['name']).maxLength := 100;
    Values['slug'] := Field(Form, 'slug', T('Slug'), Value(Board, 'slug', ''));
    TJSHTMLInputElement(Values['slug']).required := True; TJSHTMLInputElement(Values['slug']).maxLength := 80;
    Values['description'] := Field(Form, 'description', T('Description'), Value(Board, 'description', ''), 'textarea');
    TJSHTMLTextAreaElement(Values['description']).maxLength := 2000;
    Values['position'] := Field(Form, 'position', T('Position'), Value(Board, 'position', 0), 'number');
    TJSHTMLInputElement(Values['position']).required := True;
    ParentLabel := El('label', T('Parent board') + ' '); Parent := TJSHTMLSelectElement(El('select'));
    Option := TJSHTMLOptionElement(El('option', T('None'))); Option.value := '0'; Parent.appendChild(Option);
    for I := 0 to Boards.length - 1 do
    begin
      Item := TJSObject(Boards[I]);
      if not HasChildren and not Truthy(Item['parent_id']) and not Same(Item['id'], BoardId) then
      begin
        Option := TJSHTMLOptionElement(El('option', Item['name'])); Option.value := string(Item['id']); Parent.appendChild(Option);
      end;
    end;
    Parent.value := string(Value(Board, 'parent_id', 0)); ParentLabel.appendChild(Parent); Form.appendChild(ParentLabel);
    CategoryLabel := El('label', T('Category') + ' '); Category := TJSHTMLSelectElement(El('select')); Category.name := 'category_id';
    Option := TJSHTMLOptionElement(El('option', T('General'))); Option.value := '0'; Category.appendChild(Option);
    for I := 0 to Categories.length - 1 do
    begin
      Item := TJSObject(Categories[I]); Option := TJSHTMLOptionElement(El('option', Item['name'])); Option.value := string(Item['id']); Category.appendChild(Option);
    end;
    Category.value := string(Value(Board, 'category_id', 0)); CategoryLabel.appendChild(Category); Form.appendChild(CategoryLabel);
    Values['read_permission'] := Field(Form, 'read_permission', T('Read permission'), Value(Board, 'read_permission', 'forum-read'));
    TJSHTMLInputElement(Values['read_permission']).required := True; TJSHTMLInputElement(Values['read_permission']).maxLength := 40;
    TJSHTMLElement(Values['read_permission']).setAttribute('list', 'forum-permissions');
    Save := TJSHTMLButtonElement(El('button', T('Save'))); Save._type := 'submit';
    Form.append(Save, Button(T('Cancel'), @Draw));
    Form.addEventListener('submit', TJSRawEventHandler(procedure(E: TJSEvent)
      var
        Fields: TJSObject;
        Keys: TJSStringDynArray;
        N: integer;
      begin
        E.preventDefault; Fields := new(['id', BoardId, 'parent_id', Parent.value, 'category_id', Category.value]);
        Keys := TJSObject.keys(Values);
        for N := 0 to High(Keys) do Fields[Keys[N]] := TJSObject(Values[Keys[N]])['value'];
        Change('board', Fields);
      end));
    Content.replaceChildren(Form);
  end;

  procedure Order(Index, Offset: integer);
  var
    Ordered, Ids: TJSArray;
    Other, I: integer;
    Kept: JSValue;
  begin
    Ordered := Boards.slice; Other := Index + Offset;
    if (Other < 0) or (Other >= Ordered.length) then Exit;
    Kept := Ordered[Index]; Ordered[Index] := Ordered[Other]; Ordered[Other] := Kept;
    Ids := TJSArray.new;
    for I := 0 to Ordered.length - 1 do Ids.push(TJSObject(Ordered[I])['id']);
    Change('order', new(['ids', Ids.join(',')]));
  end;

  procedure EditCategory(Category: TJSObject);
  var
    Form: TJSHTMLFormElement;
    Name, Position: TJSHTMLElement;
    Save: TJSHTMLButtonElement;
  begin
    Form := TJSHTMLFormElement(El('form'));
    Name := Field(Form, 'name', T('Category name'), Value(Category, 'name', ''));
    TJSHTMLInputElement(Name).required := True; TJSHTMLInputElement(Name).maxLength := 100;
    Position := Field(Form, 'position', T('Position'), Value(Category, 'position', 0), 'number');
    Save := TJSHTMLButtonElement(El('button', T('Save'))); Save._type := 'submit'; Form.append(Save, Button(T('Cancel'), @Draw));
    Form.addEventListener('submit', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        E.preventDefault;
        Change('category', new(['id', Value(Category, 'id', 0), 'name', TJSHTMLInputElement(Name).value, 'position', TJSHTMLInputElement(Position).value]));
      end));
    Content.replaceChildren(Form);
  end;

  function CategoryRow(Category: TJSObject; Index: integer): TJSHTMLElement;
  var
    Row: TJSHTMLElement;
    Up, Down: TJSHTMLButtonElement;
  begin
    Row := El('li', string(Category['name']) + ' (' + string(Category['position']) + ') ');
    Up := Button(T('Move category up'), procedure
      begin
        Change('category', new(['id', Category['id'], 'name', Category['name'], 'position', Number(TJSObject(Categories[Index - 1])['position']) - 1]));
      end);
    Down := Button(T('Move category down'), procedure
      begin
        Change('category', new(['id', Category['id'], 'name', Category['name'], 'position', Number(TJSObject(Categories[Index + 1])['position']) + 1]));
      end);
    Up.disabled := Index = 0; Down.disabled := Index = Categories.length - 1;
    Row.append(Button(T('Rename category'), procedure begin EditCategory(Category); end), Up, Down,
      Button(T('Remove category'), procedure
        begin if window.confirm(T('Remove category %s?', Category['name'])) then Change('category/remove', new(['id', Category['id']])); end));
    Result := Row;
  end;

  function BoardRow(Board: TJSObject; Index: integer): TJSHTMLElement;
  var
    Row, Actions: TJSHTMLElement;
    Parent, Category, Item: TJSObject;
    Up, Down: TJSHTMLButtonElement;
    I: integer;
    CategoryId, ParentName, CategoryName: JSValue;
  begin
    Row := El('tr'); Parent := nil; Category := nil;
    for I := 0 to Boards.length - 1 do
    begin Item := TJSObject(Boards[I]); if Same(Item['id'], Board['parent_id']) then begin Parent := Item; Break; end; end;
    if Parent <> nil then CategoryId := Parent['category_id'] else CategoryId := Board['category_id'];
    for I := 0 to Categories.length - 1 do
    begin Item := TJSObject(Categories[I]); if Same(Item['id'], CategoryId) then begin Category := Item; Break; end; end;
    ParentName := ''; if Parent <> nil then ParentName := Parent['name'];
    CategoryName := T('General'); if Category <> nil then CategoryName := Category['name'];
    Row.append(El('td', Board['name']), El('td', CategoryName), El('td', ParentName), El('td', Board['read_permission']), El('td', string(Board['position'])));
    Actions := El('td'); Up := Button(T('Move up'), procedure begin Order(Index, -1); end);
    Down := Button(T('Move down'), procedure begin Order(Index, 1); end);
    Up.disabled := Index = 0; Down.disabled := Index = Boards.length - 1;
    Actions.append(Button(T('Edit'), procedure begin Edit(Board); end), Up, Down, Button(T('Remove'), procedure
      begin if window.confirm(T('Remove board %s?', Board['name'])) then Change('remove', new(['id', Board['id']])); end));
    Row.appendChild(Actions); Result := Row;
  end;

  procedure Draw;
  const
    Captions: array[0..5] of string = ('Name', 'Category', 'Parent board', 'Read permission', 'Position', 'Actions');
  var
    Choices, Table, Head, Wrap, List, Old: TJSHTMLElement;
    Names: TJSSet;
    Values: TJSArray;
    Option: TJSHTMLOptionElement;
    I: integer;
  begin
    Content.replaceChildren;
    Choices := El('datalist'); Choices.id := 'forum-permissions';
    Names := TJSSet.new(TJSArray.new('forum-read', 'forum-members', 'forum-staff'));
    for I := 0 to Permissions.length - 1 do Names.add(TJSObject(Permissions[I])['name']);
    for I := 0 to Boards.length - 1 do Names.add(TJSObject(Boards[I])['read_permission']);
    Values := TJSArray.from(Names);
    for I := 0 to Values.length - 1 do
    begin Option := TJSHTMLOptionElement(El('option')); Option.value := string(Values[I]); Choices.appendChild(Option); end;
    Old := TJSHTMLElement(Box.querySelector('datalist')); if Old <> nil then Old.remove;
    Box.appendChild(Choices);
    Content.append(El('p', TN(Boards.length, '%d board', '%d boards')), Button(T('Add board'), procedure begin Edit(TJSObject.new); end));
    Table := El('table'); Table.className := 'grid'; Head := El('tr');
    for I := 0 to High(Captions) do Head.appendChild(El('th', T(Captions[I])));
    Table.appendChild(Head);
    for I := 0 to Boards.length - 1 do Table.appendChild(BoardRow(TJSObject(Boards[I]), I));
    Wrap := El('div'); Wrap.className := 'gridwrap'; Wrap.appendChild(Table); Content.appendChild(Wrap);
    Content.append(El('h3', T('Categories')), Button(T('Add category'), procedure begin EditCategory(TJSObject.new); end));
    List := El('ul'); for I := 0 to Categories.length - 1 do List.appendChild(CategoryRow(TJSObject(Categories[I]), I));
    Content.appendChild(List);
  end;

  procedure Load; async;
  var
    Results: TJSArray;
  begin
    Results := await(TJSArray, TJSPromise.all(TJSArray.new(SiteShell.get('/api/forum/admin/boards'), SiteShell.get('/api/forum/admin/categories'))));
    Boards := TJSArray(Results[0]); Categories := TJSArray(Results[1]); Draw;
  end;

begin
  Box.className := Box.className + ' forum-admin';
  Boards := TJSArray.new; Categories := TJSArray.new; Permissions := TJSArray.new;
  Error := El('p'); Error.className := 'forum-error'; Error.setAttribute('role', 'alert'); Content := El('div');
  Box.replaceChildren(Error, Content); Busy := False;
  try
    Data := await(TJSObject, SiteShell.get('/api/admin'));
    if Truthy(Data['permissions']) then Permissions := TJSArray(Data['permissions']);
    await(Load);
  except
    Error.textContent := string(TJSObject(JSExceptValue)['message']);
  end;
end;

procedure Start;
var
  Tabs: TJSArray;
  I: integer;
  Style: TJSHTMLLinkElement;
begin
  Tabs := TJSArray(SiteShell.extras['adminTabs']);
  for I := 0 to Tabs.length - 1 do if Same(TJSObject(Tabs[I])['permission'], 'forum-boards') then Exit;
  Style := TJSHTMLLinkElement(MakeElement('link')); Style.rel := 'stylesheet';
  Style.href := '/static/forum.css' + TJSURL.new(TJSHTMLScriptElement(document.currentScript).src).search;
  document.head.appendChild(Style);
  Tabs.push(new(['title', T('Forum boards'), 'permission', 'forum-boards', 'build', @Build, 'group', 'Forum']));
end;

initialization
  Start;
end.
