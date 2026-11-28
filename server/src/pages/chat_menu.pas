unit chat_menu;

{ The menu of a message, editing in place, code blocks and the picture box. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, chat_shared;

function MessageMenu(M: TMsg; InThread: boolean): TJSObject;
procedure CloseMenu(Refocus: boolean = False);
// At is where the pointer is ({x, y}); nil drops the menu from the arrow.
procedure OpenMenu(Node: TEl; At: TJSObject = nil);
procedure StartEdit(M: TMsg);
procedure DressCode(Root: TJSElement);
procedure Start;

implementation

uses chat_answer, chat_messages, chat_sync, chat_panels, chat_composer, chat_complete;

type
  TReactProc = reference to procedure(R: JSValue);
  // One action of a menu: {icon, title, run}, and bad for the ones that destroy.
  TMenuItem = class external name 'Object'(TJSObject)
    icon: string;
    title: JSValue;
    bad: boolean;
    run: TProc;
  end;
  // What a message offers: react (given an emoji) or null, and its actions.
  TOffer = class external name 'Object'(TJSObject)
    react: JSValue;
    items: TJSArray;
  end;
  TOfferCall = class external name 'Object'(TJSObject)
    procedure react(R: JSValue);
  end;
  // The message's own menu function, called on the message itself.
  TMenuNode = class external name 'HTMLElement'(TJSHTMLElement)
    function menu: TOffer;
  end;
  // What is kept of a drawn message: {data, node}.
  TEntry = class external name 'Object'(TJSObject)
    node: TEl;
  end;
  // Web's node has firstChild and no lastChild.
  TLastChild = class external name 'Node'(TJSNode)
    lastChild: TJSElement;
  end;
  // A string's own calls, with split answering an array.
  TStr = class external name 'String'(TJSObject)
    function replace(Pattern: TJSRegexp; const By: string): TStr;
    function split(const Separator: string): TJSArray;
    function trim: TStr;
    function toLowerCase: string;
  end;

const
  FOLD_LINES = 20;

var
  CODE_NAMES: TJSObject;

function Item(const Icon, Title: string; Run: TProc): TMenuItem;
begin
  Result := TMenuItem(new(['icon', Icon, 'title', Title, 'run', Run]));
end;

// What a message's menu holds for this member: react (given an emoji) when
// they may, and the actions, the ones that destroy marked bad and put last.
function MessageMenu(M: TMsg; InThread: boolean): TJSObject;
var
  Items: TJSArray;
  MayReact, AsSent: boolean;
  From, PinTitle: string;
  Entry: TMenuItem;
  React: TReactProc;
begin
  Items := TJSArray.new;
  MayReact := (Me.name <> '') and MayHere('react');
  // Answered from the box of its own place: the open thread's for a message
  // of that thread, its channel's for one in the channel's list.
  if Truthy(S.thread) and ((M.parent = S.thread) or (InThread and (M.id = S.thread))) then
    From := 'thread ' + String(JSValue(S.thread))
  else if InThread then From := ''
  else From := 'room ' + M.room;
  if (From <> '') and Truthy(AnswerStrip(From)) then
    Items.push(Item('reply', T('Answer this message'), procedure
      var
        Words: JSValue;
      begin
        Words := FirstWords(M.body);
        if not Words then
          if M.files.length <> 0 then Words := TJSObject(M.files[0])['name'] else Words := T('code');
        Answer(From, new(['id', M.id, 'from', M.name, 'text', Words]));
      end));
  if MayReact and not InThread and not Truthy(M.parent) then
    Items.push(Item('reply', T('Reply in a thread'), procedure begin OpenThread(M.id); end));
  if Truthy(M.body) then
    Items.push(Item('copy', T('Copy the text'), procedure
      begin
        window.navigator.clipboard.writeText(M.body)._then(function(Value: JSValue): JSValue
          begin Toast(T('Text copied.')); end);
      end));
  Items.push(Item('link', T('Copy a link to this'), procedure
    begin
      window.navigator.clipboard.writeText(window.location.origin + SiteBase.url('/m/' + String(JSValue(M.id))))._then(
        function(Value: JSValue): JSValue begin Toast(T('Link copied.')); end);
    end));
  // Where messages stay as sent there is nothing to change or delete.
  AsSent := Truthy(S.info) and S.info.as_sent;
  if (M.name = Me.name) and Truthy(M.uid) and May('edit-own') and not AsSent then
    Items.push(Item('edit', T('Edit'), procedure begin StartEdit(M); end));
  if MayHere('pin') and not Truthy(M.parent) then
  begin
    if M.pinned then PinTitle := T('Unpin') else PinTitle := T('Pin to the channel');
    Items.push(Item('pin', PinTitle, procedure async
      begin
        try
          await(JSValue, Post('/api/pin', new(['id', M.id])));
          SyncNow;
        except
          Failed(JSExceptValue);
        end;
      end));
  end;
  if not AsSent and (((M.name = Me.name) and Truthy(M.uid) and May('delete-own')) or MayHere('delete-any')) then
  begin
    Entry := Item('trash', T('Delete'), procedure async
      begin
        if not window.confirm(T('Delete this message?')) then Exit;
        try
          await(JSValue, Post('/api/delete', new(['id', M.id])));
          SyncNow;
        except
          Failed(JSExceptValue);
        end;
      end);
    Entry.bad := True;
    Items.push(Entry);
  end;
  React := nil;
  if MayReact then React := procedure(R: JSValue) begin chat_messages.React(M.id, R); end;
  Result := new(['react', React, 'items', Items]);
end;

// One menu at a time. It lies over the page and not in the list, whose edge
// would cut it, and its message stays shaded (.held) while it is open.
procedure CloseMenu(Refocus: boolean);
begin
  if not Truthy(Menu) then Exit;
  Menu.box.remove;
  Menu.node.classList.remove('held');
  Menu.arrow.setAttribute('aria-expanded', 'false');
  if Refocus then Menu.arrow.focus(new(['preventScroll', True]));
  Menu := nil;
end;

// The button an arrow key leads to: the next or the one before for right and
// left, the nearest in the row below or above for down and up, around the ends.
function MenuStep(Buttons: TJSArray; Here: TJSElement; const Key: string): JSValue;
var
  I, N, K: NativeInt;
  Down: boolean;
  From, R: TJSDOMRect;
  Best: JSValue;
  Row, Off, Far, Aside: double;
begin
  I := Buttons.indexOf(Here);
  N := Buttons.length;
  if Key = 'Home' then Exit(Buttons[0]);
  if Key = 'End' then Exit(Buttons[N - 1]);
  if Key = 'ArrowRight' then Exit(Buttons[(I + 1) mod N]);
  if Key = 'ArrowLeft' then Exit(Buttons[(I + N - 1) mod N]);
  if (Key <> 'ArrowDown') and (Key <> 'ArrowUp') then Exit(nil);
  Down := Key = 'ArrowDown';
  From := Here.getBoundingClientRect;
  Best := nil;
  Row := 0;
  Off := 0;
  for K := 0 to N - 1 do
  begin
    R := TJSElement(Buttons[K]).getBoundingClientRect;
    if Down then
    begin
      if R.top < From.bottom - 1 then continue;
    end
    else if R.bottom > From.top + 1 then continue;
    Far := Abs(R.top - From.top);
    Aside := Abs(R.left - From.left);
    if not Truthy(Best) or (Far < Row - 1) or ((Far < Row + 1) and (Aside < Off)) then
    begin
      Best := Buttons[K];
      Row := Far;
      Off := Aside;
    end;
  end;
  if Best then Exit(Best);
  if Down then Result := Buttons[0] else Result := Buttons[N - 1];
end;

procedure OpenMenu(Node: TEl; At: TJSObject);
var
  Offer: TOffer;
  Arrow, Box, List, First: TEl;
  Buttons: TJSNodeList;
  Pick: TReactProc;
  Place: TProc;
  I: NativeInt;

  function Entry(B: TJSElement): TJSElement;
  begin
    TJSHTMLButtonElement(B)._type := 'button';
    TJSHTMLElement(B).tabIndex := -1;
    B.setAttribute('role', 'menuitem');
    Result := B;
  end;

  function Choice(B: TEl; Run: TProc): TEl;
  begin
    Entry(B).addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        CloseMenu(True);
        Run();
      end));
    Result := B;
  end;

  procedure Add(It: TMenuItem);
  var
    B: TEl;
  begin
    if It.bad and Truthy(TLastChild(TJSNode(List)).lastChild) and not TLastChild(TJSNode(List)).lastChild.classList.contains('bad') then
      List.appendChild(El('hr'));
    if It.bad then B := Choice(El('button', 'bad'), It.run) else B := Choice(El('button', ''), It.run);
    B.append(Icon(It.icon), El('span', '', It.title));
    List.appendChild(B);
  end;

begin
  CloseMenu;
  Offer := TMenuNode(TJSHTMLElement(Node)).menu;
  Arrow := TEl(Node.querySelector(':scope > .gutter > .more'));
  if not Truthy(Offer.react) and (Offer.items.length = 0) then Exit;
  Box := El('div', 'msgmenu');
  Box.setAttribute('role', 'menu');
  Box.tabIndex := -1;
  Place := procedure
    begin
      if Truthy(At) then Reactions.under(Box, new(['left', At['x'], 'top', At['y'], 'bottom', At['y']]))
      else Reactions.under(Box, Arrow.getBoundingClientRect);
    end;
  // A message that follows another shows no time of its own.
  if Node.classList.contains('cont') then
    Box.appendChild(El('div', 'when', DateTimeText(TJSDate.new(Node.dataset['at']))));
  if Truthy(Offer.react) then
  begin
    // The site's reactions (/api/me), as reactions.js offers them.
    Pick := procedure(R: JSValue)
      begin
        CloseMenu(True);
        TOfferCall(TJSObject(Offer)).react(R);
      end;
    Reactions.offer(Box, Me.reactions, Pick, Place);
    Buttons := Box.querySelectorAll('button');
    for I := 0 to Buttons.length - 1 do Entry(TJSElement(Buttons[I]));
  end;
  List := El('div', 'items');
  for I := 0 to Offer.items.length - 1 do Add(TMenuItem(Offer.items[I]));
  Box.appendChild(List);
  Box.addEventListener('keydown', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Key: string;
      Shown: TJSArray;
      Dest: JSValue;
    begin
      Key := TJSKeyboardEvent(E).key;
      if (Key = 'Escape') or (Key = 'Tab') then
      begin
        if Key = 'Escape' then E.preventDefault;
        CloseMenu(True);
        Exit;
      end;
      Shown := TJSArray.from(Box.querySelectorAll('button')).filter(
        function(B: JSValue; Index: NativeInt; All: TJSArray): boolean
        begin Result := Truthy(TJSHTMLElement(B).offsetParent); end);
      // Opened by the pointer, nothing in it is picked yet: a key starts at the top.
      if Shown.includes(document.activeElement) then Dest := MenuStep(Shown, document.activeElement, Key)
      else if TJSRegexp.new('^(Arrow|Home|End)').test(Key) then Dest := Shown[0]
      else Dest := nil;
      if not Dest then Exit;
      E.preventDefault;
      TJSHTMLElement(Dest).focus;
    end));
  document.body.appendChild(Box);
  Place();
  Node.classList.add('held');
  Arrow.setAttribute('aria-expanded', 'true');
  Menu := TOpenMenu(new(['box', Box, 'node', Node, 'arrow', Arrow]));
  if Truthy(At) then First := Box else First := TEl(Box.querySelector('button'));
  First.focus(new(['preventScroll', True]));
end;

procedure StartEdit(M: TMsg);
var
  Entry: JSValue;
  Text, Box: TEl;
  Area: TJSHTMLTextAreaElement;
  Save, Cancel: TJSHTMLButtonElement;
  Complete: TCompleter;

  procedure Done;
  begin
    Box.replaceWith(Text);
  end;

  procedure Store; async;
  begin
    try
      await(JSValue, Post('/api/edit', new(['id', M.id, 'body', Area.value])));
      Done;
      SyncNow;
    except
      Failed(JSExceptValue);
    end;
  end;

begin
  Entry := S.messages.get(M.id);
  if not Entry then Entry := S.threadMessages.get(M.id);
  if not Entry then Exit;
  Text := TEl(TEntry(Entry).node.querySelector('.body'));
  Box := El('div', 'editbox');
  Area := TJSHTMLTextAreaElement(TJSElement(El('textarea')));
  Area.value := M.body;
  Save := TJSHTMLButtonElement(TJSElement(El('button', 'primary', T('Save'))));
  Cancel := TJSHTMLButtonElement(TJSElement(El('button', '', T('Cancel'))));
  Cancel._type := 'button';
  Save._type := 'button';
  Box.append(Area, Save, Cancel);
  Text.replaceWith(Box);
  Area.focus;
  Fit(Area);
  Complete := Completer(Area);
  Save.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Store; end));
  Cancel.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Done; end));
  Area.addEventListener('input', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      Fit(Area);
      Complete.update;
    end));
  Area.addEventListener('keydown', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      if Complete.handle(TJSKeyboardEvent(E)) then Exit;
      if TJSKeyboardEvent(E).key = 'Escape' then Done;
      if (TJSKeyboardEvent(E).key = 'Enter') and not TJSKeyboardEvent(E).shiftKey and not InFence(Area) then
      begin
        E.preventDefault;
        Store;
      end;
    end));
end;

// A code block as it is shown: its language by its proper name, how many
// lines it has, a number beside each line, and a long one folded until asked for.
procedure DressCode(Root: TJSElement);
var
  Boxes: TJSNodeList;
  I: NativeInt;

  procedure Dress(Box: TEl);
  var
    Pre, Code, Mark, Flip, Nums, Fold: TEl;
    Lines, N: NativeInt;
    Id, List: string;
    Name: JSValue;

    procedure Say;
    var
      Shut: boolean;
    begin
      Shut := Box.classList.contains('folded');
      if Shut then Fold.textContent := TN(Lines, 'Show all %d line', 'Show all %d lines')
      else Fold.textContent := T('Show less');
      if Shut then Fold.setAttribute('aria-expanded', 'false') else Fold.setAttribute('aria-expanded', 'true');
    end;

  begin
    Pre := TEl(Box.querySelector(':scope > pre'));
    Code := Pre;
    if Truthy(Pre) then Code := TEl(Pre.querySelector(':scope > code'));
    if not Truthy(Code) or Truthy(Pre.querySelector('.nums')) then Exit;
    Lines := TStr(JSValue(Code.textContent)).replace(TJSRegexp.new('\n+$'), '').split(#10).length;
    Mark := TEl(Box.querySelector(':scope > .codebar span'));
    if Truthy(Mark) then
    begin
      Id := TStr(JSValue(Mark.textContent)).trim.toLowerCase;
      Name := CODE_NAMES[Id];
      if not Name then Name := TStr(JSValue(Mark.textContent)).trim;
      TJSObject(Mark)['textContent'] := Name;
      if Lines > 1 then Mark.after(El('span', 'codelines', TN(Lines, '%d line', '%d lines')));
    end;
    // A markdown block shows as its document; the button flips to its source.
    Flip := TEl(Box.querySelector(':scope > .codebar .flip'));
    if Truthy(Flip) then
    begin
      Flip.textContent := T('Source');
      Flip.setAttribute('aria-pressed', 'false');
    end;
    if Lines < 2 then Exit;
    Nums := El('span', 'nums');
    Nums.setAttribute('aria-hidden', 'true');
    List := '';
    for N := 1 to Lines do List := List + String(JSValue(N)) + #10;
    Nums.textContent := List;
    Pre.prepend(Nums);
    Box.classList.add('numbered');
    // A few lines past the fold are not worth a button.
    if Lines <= FOLD_LINES + 5 then Exit;
    Box.classList.add('folded');
    Fold := El('button', 'codefold');
    TJSHTMLButtonElement(TJSElement(Fold))._type := 'button';
    Fold.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        Box.classList.toggle('folded');
        Say;
        if Box.classList.contains('folded') and (Box.getBoundingClientRect.top < 0) then
          Box.scrollIntoView(new(['block', 'nearest']));
      end));
    Say;
    Box.appendChild(Fold);
  end;

begin
  Boxes := Root.querySelectorAll('.code');
  for I := 0 to Boxes.length - 1 do Dress(TEl(Boxes[I]));
end;

procedure Start;
var
  Lightbox: TEl;
begin
  document.addEventListener('pointerdown', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      if Truthy(Menu) and not Menu.box.contains(TJSNode(E.target)) and not Menu.arrow.contains(TJSNode(E.target)) then
        CloseMenu;
    end), True);
  document.addEventListener('scroll', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      if Truthy(Menu) and not Menu.box.contains(TJSNode(E.target)) then CloseMenu(True);
    end), True);
  window.addEventListener('resize', TJSRawEventHandler(procedure(E: TJSEvent) begin CloseMenu(True); end));

  CODE_NAMES := new(['pascal', 'Pascal', 'lfm', 'LFM', 'bash', 'Bash', 'javascript', 'JavaScript', 'js', 'JavaScript',
    'typescript', 'TypeScript', 'ts', 'TypeScript', 'css', 'CSS', 'html', 'HTML', 'xml', 'XML', 'sql', 'SQL',
    'json', 'JSON', 'ini', 'INI', 'yaml', 'YAML', 'toml', 'TOML', 'go', 'Go', 'c', 'C', 'cpp', 'C++',
    'csharp', 'C#', 'java', 'Java', 'kotlin', 'Kotlin', 'swift', 'Swift', 'rust', 'Rust', 'zig', 'Zig', 'd', 'D',
    'python', 'Python', 'ruby', 'Ruby', 'lua', 'Lua', 'php', 'PHP', 'perl', 'Perl', 'basic', 'BASIC', 'diff', 'Diff',
    'makefile', 'Makefile', 'asm', 'Assembly', 'batch', 'Batch', 'powershell', 'PowerShell',
    'dockerfile', 'Dockerfile', 'fortran', 'Fortran', 'ada', 'Ada', 'barye', 'Barye', 'markdown', 'Markdown',
    'md', 'Markdown', 'rst', 'reStructuredText', 'restructuredtext', 'reStructuredText']);

  document.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Flip, Copy, Box: TEl;
      Shot: TJSElement;
      Source: boolean;
      Img: TJSHTMLImageElement;
    begin
      Flip := TEl(TJSElement(E.target).closest('.code .flip'));
      if Truthy(Flip) then
      begin
        Box := TEl(Flip.closest('.code'));
        Source := Box.classList.toggle('source');
        if Source then Flip.textContent := T('Rendered') else Flip.textContent := T('Source');
        if Source then Flip.setAttribute('aria-pressed', 'true') else Flip.setAttribute('aria-pressed', 'false');
        Exit;
      end;
      Copy := TEl(TJSElement(E.target).closest('.code .copy'));
      if Truthy(Copy) then
      begin
        window.navigator.clipboard.writeText(Copy.closest('.code').querySelector(':scope > pre > code').textContent)._then(
          function(Value: JSValue): JSValue
          begin
            Copy.textContent := T('Copied');
            window.setTimeout(procedure begin Copy.textContent := T('Copy'); end, 1500);
          end);
        Exit;
      end;
      Shot := TJSElement(E.target).closest('a.shot');
      if Truthy(Shot) and not TJSMouseEvent(E).ctrlKey and not TJSMouseEvent(E).metaKey then
      begin
        E.preventDefault;
        Box := Find('#lightbox');
        Img := TJSHTMLImageElement(TJSElement(El('img')));
        Img.src := TJSHTMLAnchorElement(Shot).href;
        Box.replaceChildren(Img);
        Box.hidden := False;
        LayerOpened;
      end;
    end));
  Lightbox := Find('#lightbox');
  Lightbox.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      Lightbox.hidden := True;
      LayerClosed;
    end));
end;

end.
