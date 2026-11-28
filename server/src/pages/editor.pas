unit EditorPage;

{ Shared text editor with a preview from the module's renderer. Text stays
  as typed except for completed :keyword: emoji. Editor.attach options and
  the returned editor are in docs/CODE-MAP.md. The plain form still works
  where the module supports it. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

implementation

// pas2js Web does not re-export the event listener options type.
uses JS, WebOrWorker, Web, PageKit, PageGlobals;

type
  TWords = reference to function(const English: string): string; varargs;
  TToolAct = reference to procedure(B: TJSHTMLElement);
  TMake = reference to function(I: NativeInt): string;
  TWork = reference to procedure;
  TTexts = array of string;
  // a tie is [where in the text, where in the preview]
  TNumbers = array of double;
  TTies = array of TNumbers;

  // Web's textarea lacks setSelectionRange and setRangeText.
  TTextBox = class external name 'HTMLTextAreaElement'(TJSHTMLElement)
    value: string;
    selectionStart, selectionEnd: NativeInt;
    procedure setSelectionRange(A, B: double);
    procedure setRangeText(const Text: string; A, B: NativeInt; const Mode: string);
  end;
  // JS lacks String.repeat, and its split answers a type of the Types unit.
  TText = class external name 'String'(TJSString)
    function &repeat(Count: NativeInt): string;
    function parts(const Separator: string): TTexts; external name 'split';
  end;
  TNumber = class external name 'Number'(TJSObject)
    function toFixed(Digits: NativeInt): string;
  end;
  // Web declares toggle without its second argument.
  TTokens = class external name 'DOMTokenList'(TJSDOMTokenList)
    function toggle(const Token: string; Force: boolean): boolean; overload;
  end;
  // Web's event takes its options as a record of every field; the browser's own object is given.
  TPlainEvent = class external name 'Event'(TJSEvent)
    constructor new(const Kind: string; Init: TJSObject);
  end;
  // Web lacks after.
  TChild = class external name 'HTMLElement'(TJSHTMLElement)
    procedure after(Node: TJSNode);
  end;
  TCaretPosition = class external name 'Object'(TJSObject)
    offsetNode: TJSNode;
    offset: NativeInt;
  end;
  // Web lacks caretPositionFromPoint.
  TCaretDocument = class external name 'Document'(TJSDocument)
    function caretPositionFromPoint(X, Y: double): TCaretPosition;
  end;

  // Keys.smaller and EmojiNames, from keys.js and emoji-names.js.
  TKeysSmaller = class external name 'Object'(TJSObject)
    function smaller(F: JSValue): TJSPromise;
  end;
  TTyped = class external name 'Object'(TJSObject)
    word: string;
    from: NativeInt;
    whole: boolean;
  end;
  TEmoji = class external name 'Object'(TJSObject)
    emoji, name: string;
    group, src: JSValue;
    keywords: TJSArray;
  end;
  TEmojiNames = class external name 'Object'(TJSObject)
    function typed(const Text: string; At: NativeInt; Short: boolean): TTyped;
    function matches(List: JSValue; const Word: string): TJSArray;
    function named(List: JSValue; const Word: string): TEmoji;
  end;

  // The options a part gives: its own functions are called as its own.
  TUpFile = class external name 'File'(TJSObject)
    name: JSValue;
    size: double;
    kind: string; external name 'type';
  end;
  TPictures = class external name 'Object'(TJSObject)
    accept, gallery: JSValue;
    types: TJSRegExp;
    function refuses(F: TUpFile): JSValue;
    function send(F: TUpFile; const Name: string): TJSPromise;
  end;
  TOptions = class external name 'Object'(TJSObject)
    function preview(const Text: string; Signal: TJSAbortSignal): TJSPromise;
    procedure afterPreview(View: TJSHTMLElement);
    procedure linkTools(Editor: TJSObject);
  end;
  TLines = class external name 'Object'(TJSObject)
    from: NativeInt;
    to_: NativeInt; external name 'to';
    text: string;
  end;
  THeading = class external name 'Object'(TJSObject)
    at: NativeInt;
    words: string;
  end;
  TPoint = class external name 'Object'(TJSObject)
    top, left: double;
  end;

const
  CaretLook: array[0..18] of string = ('boxSizing', 'width', 'fontFamily', 'fontSize', 'fontWeight', 'fontStyle', 'lineHeight', 'letterSpacing',
    'wordSpacing', 'tabSize', 'textIndent', 'paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft', 'borderTopWidth', 'borderRightWidth',
    'borderBottomWidth', 'borderLeftWidth');
  MirrorLook: array[0..9] of string = ('fontFamily', 'fontSize', 'fontWeight', 'lineHeight', 'letterSpacing', 'tabSize', 'paddingTop', 'paddingRight',
    'paddingBottom', 'paddingLeft');

var
  Keys: TKeysSmaller; external name 'window.Keys';
  EmojiNames: TEmojiNames; external name 'window.EmojiNames';
  T: TWords;
  Mac: boolean;
  ModKey, ShiftKey: string;
  Made: NativeInt;

function Same(A, B: JSValue): boolean; external name 'Object.is';
function ArrayFrom(List: JSValue): TJSArray; external name 'Array.from';
function ToNumber(Value: JSValue): double; external name 'Number';
function ToFloat(Value: JSValue): double; external name 'parseFloat';
function MaxN(A, B: NativeInt): NativeInt; external name 'Math.max';
function MinN(A, B: NativeInt): NativeInt; external name 'Math.min';
function MaxF(A, B: double): double; external name 'Math.max';
function MinF(A, B: double): double; external name 'Math.min';

function El(const Tag: string; Cls: JSValue = undefined; Text: JSValue = undefined): TJSHTMLElement;
begin
  Result := TJSHTMLElement(document.createElement(Tag));
  if Cls then Result.className := string(Cls);
  if jsTypeOf(Text) <> 'undefined' then TJSObject(Result)['textContent'] := Text;
end;

function Svg(const Inner: string): string;
begin
  Result := '<svg viewBox="0 0 24 24" aria-hidden="true">' + Inner + '</svg>';
end;

function Either(A, B: JSValue): JSValue;
begin
  if A then Result := A else Result := B;
end;

function KeepIndent(const M: string; Indent: JSValue): string;
begin
  if jsTypeOf(Indent) = 'string' then Result := string(Indent) else Result := '';
end;

function Attach(Box: TTextBox; Options: TOptions): TJSObject;
var
  Opts: TOptions;
  Pictures: TPictures;
  Form: TJSHTMLFormElement;
  // named on a new code block; with none, the site's own setting says how such a block is colored
  Language: string;
  Editor, GroupWords, Tabs: TJSObject;
  Open, AskRow, Shell, Bar, Tools, Side, Suggest, Modes, Whole, Panes, View, Foot, News, Hint, AttachLink, Gallery, HelpButton, Help, LabelEl,
  SendRow, Sheet, Row, Cell, KeysLine, More, Guide, Mirror: TJSHTMLElement;
  Chooser: TJSHTMLInputElement;
  Pending, Chosen, TypedFrom, TypedAt, NewsTimer, Timer, Again, I: NativeInt;
  EmojiAsked: TJSPromise;
  Choices, Cheats, Pair: TJSArray;
  Eager, Stale, Saving: boolean;
  Narrow: TJSMediaQueryList;
  StoreKey, Mode, First, Icon: string;
  Asking: TJSAbortController;
  Ties: TTies;
  Part, Stored: JSValue;

  procedure Upload(List: TJSArray); async; forward;
  procedure Say(Words: JSValue; Bad: JSValue = undefined); forward;
  procedure Busy; forward;
  function Shown: string; forward;
  procedure SetMode(const Key: string); forward;
  procedure Ask; async; forward;

  // the part's pictures are read where they are used: a part may give them after attaching
  procedure Fresh;
  begin
    if Opts['pictures'] then Pictures := TPictures(Opts['pictures']) else Pictures := nil;
  end;
  procedure Measure; forward;
  procedure Follow; forward;
  procedure Bullets; forward;
  procedure Numbers; forward;

  // ---- editing the text, so the browser's undo still works

  procedure Replace(From, To_: NativeInt; const Text: string; SelectFrom: JSValue = undefined; SelectTo: JSValue = undefined);
  var
    Done: boolean;
    At, Last: double;
  begin
    Box.focus;
    Box.setSelectionRange(From, To_);
    Done := False;
    try
      Done := document.execCommand('insertText', False, Text);
    except
      Done := False;
    end;
    if not Done then Box.setRangeText(Text, From, To_, 'end');
    if jsTypeOf(SelectFrom) = 'undefined' then At := From + Length(Text) else At := From + ToNumber(SelectFrom);
    if jsTypeOf(SelectTo) = 'undefined' then Last := From + Length(Text) else Last := From + ToNumber(SelectTo);
    Box.setSelectionRange(At, Last);
    Box.dispatchEvent(TPlainEvent.new('input', new(['bubbles', True])));
  end;

  // the selected words between two marks, or the marks around a placeholder;
  // the same marks again take them off
  procedure Wrap(const Before, After, Placeholder: string);
  var
    A, B: NativeInt;
    V, Inner, Words: string;
  begin
    A := Box.selectionStart;
    B := Box.selectionEnd;
    V := Box.value;
    Inner := TJSString(V).slice(A, B);
    if (TJSString(V).slice(A - Length(Before), A) = Before) and (TJSString(V).slice(B, B + Length(After)) = After) then
    begin
      Replace(A - Length(Before), B + Length(After), Inner, 0, Length(Inner));
      Exit;
    end;
    if Inner <> '' then Words := Inner else Words := Placeholder;
    Replace(A, B, Before + Words + After, Length(Before), Length(Before) + Length(Words));
  end;

  // the whole lines the selection touches
  function Lines: TLines;
  var
    V: string;
    From, To_, Back: NativeInt;
  begin
    V := Box.value;
    From := TJSString(V).lastIndexOf(#10, Box.selectionStart - 1) + 1;
    Back := 0;
    if (Box.selectionEnd > Box.selectionStart) and (TJSString(V).charAt(Box.selectionEnd - 1) = #10) then Back := 1;
    To_ := TJSString(V).indexOf(#10, Box.selectionEnd - Back);
    if To_ < 0 then To_ := Length(V);
    Result := TLines(new(['from', From, 'to', To_, 'text', TJSString(V).slice(From, To_)]));
  end;

  // a mark at the start of each line (a list, a quote); taken off when every line has it
  procedure Prefix(Make: TMake; Test: TJSRegExp);
  var
    L: TLines;
    Rows: TTexts;
    Out_: TJSArray;
    All: boolean;
    N: NativeInt;
    Joined: string;
  begin
    L := Lines;
    Rows := TText(L.text).parts(#10);
    All := True;
    for N := 0 to Length(Rows) - 1 do
      if not Test.test(Rows[N]) then
      begin
        All := False;
        Break;
      end;
    Out_ := TJSArray.new;
    for N := 0 to Length(Rows) - 1 do
      if All then Out_.push(TJSString(Rows[N]).replace(Test, TReplaceCallBack(JSValue(@KeepIndent))))
      else Out_.push(Make(N) + TJSString(Rows[N]).replace(TJSRegExp.new('^(\s*)([-*+]\s+|\d+[.)]\s+|>\s?)'), '$1'));
    Joined := Out_.join(#10);
    Replace(L.from, L.to_, Joined, 0, Length(Joined));
  end;

  procedure Code;
  var
    A, B: NativeInt;
    Inner, Block: string;
  begin
    A := Box.selectionStart;
    B := Box.selectionEnd;
    Inner := TJSString(Box.value).slice(A, B);
    if TJSString(Inner).indexOf(#10) < 0 then
    begin
      Wrap('`', '`', T('code'));
      Exit;
    end;
    // a block, its language named so it is colored
    Block := '```' + Language + #10 + TJSString(Inner).replace(TJSRegExp.new('\n$'), '') + #10 + '```' + #10;
    Replace(A, B, Block, 3, 3 + Length(Language));
  end;

  procedure Link;
  var
    A, B: NativeInt;
    Words, Text: string;
  begin
    A := Box.selectionStart;
    B := Box.selectionEnd;
    Words := TJSString(Box.value).slice(A, B);
    if Words = '' then Words := T('words');
    Text := '[' + Words + '](https://)';
    Replace(A, B, Text, Length(Words) + 3, Length(Text) - 1);
  end;

  procedure Table(Columns, Rows: NativeInt);
  var
    Text, V, Lead: string;
    N, R, A: NativeInt;

    function Cell(N: NativeInt): string;
    begin
      Result := ' ' + T('Column') + ' ' + String(JSValue(N + 1)) + ' ';
    end;

  begin
    Text := '|';
    for N := 0 to Columns - 1 do Text := Text + Cell(N) + '|';
    Text := Text + #10 + '|';
    for N := 0 to Columns - 1 do Text := Text + ' --- |';
    for R := 0 to Rows - 2 do
    begin
      Text := Text + #10 + '|';
      for N := 0 to Columns - 1 do Text := Text + '   |';
    end;
    A := Box.selectionStart;
    V := Box.value;
    // a table needs a blank line before it
    if (A = 0) or (TJSString(V).slice(A - 2, A) = #10#10) then Lead := ''
    else if TJSString(V).charAt(A - 1) = #10 then Lead := #10
    else Lead := #10#10;
    Replace(A, Box.selectionEnd, Lead + Text + #10, Length(Lead) + 2, Length(Lead) + 2 + Length(Cell(0)) - 2);
  end;

  // ---- a small box under a button: the heading menu, the table grid, a part's own finder

  procedure ClosePop;
  begin
    if Open <> nil then
    begin
      Open.remove;
      Open := nil;
    end;
  end;

  function Pop(Button: TJSHTMLElement): TJSHTMLElement;
  var
    Card: TJSHTMLElement;
  begin
    ClosePop;
    Open := El('div', 'editor-tools-pop');
    TChild(Button).after(Open);
    // under its own button, but never past the right edge of the bar
    Card := Open;
    window.requestAnimationFrame(procedure(Time: TJSDOMHighResTimeStamp)
      var
        Room: double;
      begin
        Room := Button.parentElement.clientWidth;
        TJSObject(Card.style)['left'] := String(JSValue(MaxF(0, MinF(Button.offsetLeft, Room - Card.offsetWidth)))) + 'px';
      end);
    Result := Open;
  end;

  procedure TableGrid(Button: TJSHTMLElement);
  var
    Card, Size, Grid: TJSHTMLElement;
    R, C: NativeInt;

    procedure Add(R, C: NativeInt);
    var
      Cell: TJSHTMLElement;
    begin
      Cell := El('button');
      TJSHTMLButtonElement(Cell)._type := 'button';
      Cell.dataset['r'] := String(JSValue(R));
      Cell.dataset['c'] := String(JSValue(C));
      Cell.setAttribute('aria-label', T('%s table', String(JSValue(C)) + ' × ' + String(JSValue(R))));
      Cell.addEventListener('pointerenter', TJSRawEventHandler(procedure(E: TJSEvent)
        var
          X: JSValue;
        begin
          for X in TJSArray(JSValue(Grid.children)) do
            TTokens(TJSHTMLElement(X).classList).toggle('on', (ToNumber(TJSHTMLElement(X).dataset['r']) <= R) and (ToNumber(TJSHTMLElement(X).dataset['c']) <= C));
          Size.textContent := T('%s table', String(JSValue(C)) + ' × ' + String(JSValue(R)));
        end));
      Cell.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin ClosePop; Table(C, R); end));
      Grid.appendChild(Cell);
    end;

  begin
    Card := Pop(Button);
    Size := El('p', 'editor-tools-size', '');
    Grid := El('div', 'editor-tools-grid');
    for R := 1 to 6 do
      for C := 1 to 6 do Add(R, C);
    Card.append(Grid, Size);
  end;

  // ---- headings: a short menu, as GitLab has; # is left for the page's own title

  procedure SetHeading(Level: NativeInt);
  var
    L: TLines;
    Rest: string;
  begin
    L := Lines;
    Rest := TJSString(L.text).replace(TJSRegExp.new('^#{1,6}\s+'), '');
    if Level <> 0 then Replace(L.from, L.to_, TText('#').&repeat(Level) + ' ' + Rest) else Replace(L.from, L.to_, Rest);
  end;

  procedure HeadingMenu(Button: TJSHTMLElement);
  var
    Card: TJSHTMLElement;
    Now: NativeInt;
    Found: TTexts;

    procedure Add(Level: NativeInt; const Words: string);
    var
      B: TJSHTMLElement;
    begin
      B := El('button', 'editor-tools-h' + String(JSValue(Level)), Words);
      TJSHTMLButtonElement(B)._type := 'button';
      if Level = Now then B.setAttribute('aria-current', 'true');
      B.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin ClosePop; SetHeading(Level); end));
      Card.appendChild(B);
    end;

  begin
    Card := Pop(Button);
    Card.classList.add('editor-tools-menu');
    Found := TTexts(JSValue(TJSRegExp.new('^(#{1,6})\s+').exec(Lines.text)));
    if Found <> nil then Now := Length(Found[1]) else Now := 0;
    Add(2, T('Heading'));
    Add(3, T('Subheading'));
    Add(4, T('Small heading'));
    Add(0, T('Normal text'));
    TJSHTMLElement(Card.querySelector('button')).focus;
  end;

  // ---- pictures: dropped on the text, pasted into it or chosen; each stands
  // as a line saying it is on its way until the part has taken it

  // the kinds asked for are read when the chooser opens, so one input serves both links
  procedure Choose(Accept: JSValue);
  begin
    Fresh;
    if jsTypeOf(Accept) = 'string' then TJSObject(Chooser)['accept'] := Accept
    else if Pictures <> nil then TJSObject(Chooser)['accept'] := Pictures.accept
    else Chooser.accept := '';
    Chooser.click;
  end;

  // A camera photo that can go up smaller: a row over the foot asks which,
  // with both sizes.  One the part would refuse as it is goes smaller unasked.
  function WhichSize(F, Small: TUpFile): TJSPromise;

    function Mb(Sized: TUpFile): string;
    begin
      Result := TNumber(JSValue(Sized.size / 1048576)).toFixed(1) + ' MB';
    end;

  begin
    Fresh;
    if Truthy(Pictures['refuses']) and Truthy(Pictures.refuses(F)) then Exit(TJSPromise.resolve(Small));
    Result := TJSPromise.new(procedure(Done, Fail: TJSPromiseResolver)
      var
        Row, Less, All: TJSHTMLElement;
      begin
        Row := El('p', '', Either(F.name, T('picture')));
        Less := El('button', '', T('Smaller') + ' · ' + Mb(Small));
        All := El('button', '', T('Full size') + ' · ' + Mb(F));
        TJSHTMLButtonElement(All)._type := 'button';
        TJSHTMLButtonElement(Less)._type := 'button';
        Less.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Row.remove; Done(Small); end));
        All.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Row.remove; Done(F); end));
        Row.append(Less, All);
        AskRow.appendChild(Row);
      end);
  end;

  function Sized(F: TUpFile): JSValue; async;
  var
    Small: JSValue;
  begin
    Small := await(JSValue, Keys.smaller(F));
    if Small = F then Result := F else Result := WhichSize(F, TUpFile(Small));
  end;

  procedure Send(F: TUpFile; const Name, Mark: string); async;
  var
    Put: string;
    Done: TJSObject;
    At, End_, KeepA, KeepB, Shift: NativeInt;

    function Fix(X: NativeInt): NativeInt;
    begin
      if X > At then Result := MaxN(At, X + Shift) else Result := X;
    end;

  begin
    Inc(Pending);
    Busy;
    Put := '';
    try
      try
        Fresh;
        Done := await(TJSObject, Pictures.send(F, Name));
        if Done['put'] then Put := string(Done['put']) else Put := '';
        if Done['words'] then Say(Done['words']);
      except
        Say(Either(TJSObject(JSExceptValue)['message'], T('The picture could not be uploaded.')), True);
      end;
    finally
      Dec(Pending);
      Busy;
    end;
    At := TJSString(Box.value).indexOf(Mark);
    if At < 0 then Exit;
    End_ := At + Length(Mark);
    if (Put = '') and (TJSString(Box.value).charAt(At + Length(Mark)) = #10) then Inc(End_);
    KeepA := Box.selectionStart;
    KeepB := Box.selectionEnd;
    Shift := Length(Put) - (End_ - At);
    Replace(At, End_, Put);
    Box.setSelectionRange(Fix(KeepA), Fix(KeepB));
  end;

  procedure Upload(List: TJSArray); async;
  var
    N, A: NativeInt;
    F: TUpFile;
    Refusal: JSValue;
    Name, Mark, V, Lead: string;
  begin
    Fresh;
    if Pictures = nil then Exit;
    if TJSObject(window)['Keys'] then
    begin
      // counted as on its way while it asks, so the form is not sent without it
      Inc(Pending);
      try
        List := await(TJSArray, TJSPromise.all(List.map(TJSArrayMapCallBack(JSValue(@Sized)))));
      finally
        Dec(Pending);
      end;
    end;
    for N := 0 to List.length - 1 do
    begin
      F := TUpFile(List[N]);
      // the part says what it takes; left to itself the editor takes pictures
      Fresh;
      if Pictures['refuses'] then Refusal := Pictures.refuses(F)
      else if Pictures.types.test(F.kind) then Refusal := ''
      else Refusal := T('Only pictures can be added: PNG, JPEG, GIF or WebP. %s is not one.', Either(F.name, ''));
      if Refusal then
      begin
        Say(Refusal, True);
        Continue;
      end;
      // a pasted screenshot has no useful name of its own
      if not Truthy(F.name) or TJSRegExp.new('^image\.\w+$', 'i').test(string(F.name)) then
        Name := 'Screenshot ' + TJSString(TJSString(TJSDate.new.toISOString).slice(0, 19)).replace(TJSRegExp.new('[T:]', 'g'), '-') + '.' +
          TJSString(TText(F.kind).parts('/')[1]).replace('jpeg', 'jpg')
      else Name := string(F.name);
      Mark := '[' + T('Uploading %s…', Name) + ']';
      A := Box.selectionStart;
      V := Box.value;
      if (A = 0) or (TJSString(V).charAt(A - 1) = #10) then Lead := '' else Lead := #10;
      Replace(A, Box.selectionEnd, Lead + Mark + #10);
      Send(F, Name, Mark);
    end;
  end;

  // ---- the frame: tools over the text, the views on the right, a line
  // under it all for help and news

  function Tool(const Caption: string; Keys_: JSValue; const Mark: string; Act: TToolAct): TJSHTMLElement;
  var
    B: TJSHTMLElement;
  begin
    B := El('button', 'editor-tool');
    TJSHTMLButtonElement(B)._type := 'button';
    if Keys_ then B.title := Caption + ' (' + string(Keys_) + ')' else B.title := Caption;
    B.setAttribute('aria-label', Caption);
    // compiled code carries no comments: the line is written out so the note stays beside it
    asm B.innerHTML = Mark;   // safe html: the toolbar's own icons, written here
    end;
    B.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Act(B); end));
    Tools.appendChild(B);
    Result := B;
  end;

  procedure Gap;
  begin
    Tools.appendChild(El('span', 'editor-tool-gap'));
  end;

  // ---- emoji: a button with the whole set, and suggestions as a :keyword is typed

  function EmojiSet: TJSPromise;
  begin
    if EmojiAsked = nil then
      EmojiAsked := TJSPromise.resolve(undefined)._then(TJSPromiseResolver(Opts['emoji']))._then(function(List: JSValue): JSValue
        begin
          if TJSArray.isArray(List) then Result := List else Result := TJSArray.new;
        end).catch(function(E: JSValue): JSValue begin EmojiAsked := nil; Result := TJSArray.new; end);
    Result := EmojiAsked;
  end;

  // the set's own picture, or the emoji as the font draws it
  function EmojiFace(E: TEmoji): TJSHTMLElement;
  begin
    if E.src then
    begin
      Result := El('img', 'emo');
      TJSObject(Result)['src'] := E.src;
      TJSHTMLImageElement(Result).alt := E.emoji;
      Exit;
    end;
    Result := El('span', 'emo', E.emoji);
  end;

  procedure EmojiPanel(Button: TJSHTMLElement);
  var
    Card, Grid: TJSHTMLElement;
    Find: TJSHTMLInputElement;
    A, B: NativeInt;

    procedure Fill(List: TJSArray);
    var
      Q: string;
      Group: JSValue;
      N: NativeInt;
      E: TEmoji;

      procedure Add(E: TEmoji);
      var
        Cell: TJSHTMLElement;
      begin
        Cell := El('button', 'editor-emoji-cell');
        TJSHTMLButtonElement(Cell)._type := 'button';
        if E.keywords.length <> 0 then Cell.title := E.name + '  :' + string(E.keywords[0]) + ':' else Cell.title := E.name;
        Cell.setAttribute('aria-label', E.name);
        Cell.appendChild(EmojiFace(E));
        Cell.addEventListener('click', TJSRawEventHandler(procedure(Ev: TJSEvent) begin ClosePop; Replace(A, B, E.emoji); end));
        Grid.appendChild(Cell);
      end;

    begin
      Grid.replaceChildren;
      Q := TJSString(TJSString(TJSString(Find.value).trim).toLowerCase).replace(TJSRegExp.new(':', 'g'), '');
      Group := Null;
      for N := 0 to List.length - 1 do
      begin
        E := TEmoji(List[N]);
        if (Q <> '') and (TJSString(TJSString(E.name).toLowerCase).indexOf(Q) < 0) and
          not E.keywords.some(function(K: JSValue; At: NativeInt; All: TJSArray): boolean
          begin
            Result := TJSString(K).indexOf(Q) >= 0;
          end) then Continue;
        if (Q = '') and not Same(E.group, Group) then
        begin
          Group := E.group;
          Grid.appendChild(El('div', 'editor-emoji-group', Either(GroupWords[String(Group)], Group)));
        end;
        Add(E);
      end;
      if Grid.querySelector('button') = nil then Grid.appendChild(El('p', 'editor-emoji-none', T('No emoji has that name.')));
    end;

  begin
    Card := Pop(Button);
    Card.classList.add('editor-emoji');
    A := Box.selectionStart;
    B := Box.selectionEnd;
    Find := TJSHTMLInputElement(El('input'));
    Find._type := 'search';
    Find.placeholder := T('Find an emoji');
    Find.setAttribute('aria-label', T('Find an emoji'));
    Grid := El('div', 'editor-emoji-grid');
    Card.append(Find, Grid);
    EmojiSet._then(function(List: JSValue): JSValue
      begin
        Fill(TJSArray(List));
        Find.addEventListener('input', TJSRawEventHandler(procedure(E: TJSEvent) begin Fill(TJSArray(List)); end));
      end);
    Find.addEventListener('keydown', TJSRawEventHandler(procedure(E: TJSEvent)
      var
        First: TJSElement;
      begin
        if TJSKeyboardEvent(E).key = 'Enter' then
        begin
          E.preventDefault;
          First := Grid.querySelector('button');
          if First <> nil then TJSHTMLElement(First).click;
        end;
      end));
    window.requestAnimationFrame(procedure(Time: TJSDOMHighResTimeStamp) begin Find.focus; end);
  end;

  // where the caret is on the screen, measured with a copy of the box's text
  function CaretPoint(Index: NativeInt): TPoint;
  var
    Cs, Look: TJSObject;
    Twin, Mark: TJSHTMLElement;
    P: string;
    R: TJSDOMRect;
  begin
    Cs := TJSObject(window.getComputedStyle(Box));
    Twin := El('div');
    Look := TJSObject(Twin.style);
    for P in CaretLook do Look[P] := Cs[P];
    Look['position'] := 'absolute';
    Look['visibility'] := 'hidden';
    Look['whiteSpace'] := 'pre-wrap';
    Look['overflowWrap'] := 'break-word';
    Look['borderStyle'] := 'solid';
    Look['top'] := '0';
    Look['left'] := '-9999px';
    Twin.textContent := TJSString(Box.value).slice(0, Index);
    Mark := El('span', '', #$200B);
    Twin.appendChild(Mark);
    document.body.appendChild(Twin);
    R := Box.getBoundingClientRect;
    Result := TPoint(new(['top', R.top + Mark.offsetTop - Box.scrollTop + Mark.offsetHeight, 'left', R.left + Mark.offsetLeft - Box.scrollLeft]));
    Twin.remove;
  end;

  procedure CloseSuggest;
  begin
    if Suggest <> nil then
    begin
      Suggest.remove;
      Suggest := nil;
    end;
    Choices := TJSArray.new;
    Eager := False;
  end;

  procedure TakeChoice(N: NativeInt);
  var
    E: TEmoji;
    At: NativeInt;
  begin
    E := TEmoji(Choices[N]);
    At := Box.selectionStart;
    CloseSuggest;
    if Truthy(E) and (TypedFrom >= 0) then Replace(TypedFrom, At, E.emoji);
  end;

  // The one selected row, for the keys and the pointer alike.
  procedure Mark(N: NativeInt);
  var
    Rows: TJSArray;
    At: NativeInt;
  begin
    Chosen := N;
    Rows := ArrayFrom(Suggest.children);
    for At := 0 to Rows.length - 1 do TTokens(TJSElement(Rows[At]).classList).toggle('on', At = N);
  end;

  procedure ShowSuggest;
  var
    N: NativeInt;
    P: TPoint;

    procedure Add(E: TEmoji; N: NativeInt);
    var
      Row: TJSHTMLElement;
      Key, Name: JSValue;
    begin
      Row := El('li');
      Row.setAttribute('role', 'option');
      Key := Either(Either(E['match'], E.keywords[0]), '');
      // a name that only says the keyword again is left out
      if Same(E['name'], Key) then Name := '' else Name := E['name'];
      Row.append(EmojiFace(E), El('span', 'editor-suggest-key', ':' + string(Key) + ':'), El('span', 'editor-suggest-name', Name));
      Row.addEventListener('mousemove', TJSRawEventHandler(procedure(Ev: TJSEvent) begin if Chosen <> N then Mark(N); end));
      Row.addEventListener('click', TJSRawEventHandler(procedure(Ev: TJSEvent) begin TakeChoice(N); end));
      Suggest.appendChild(Row);
    end;

  begin
    if Suggest = nil then
    begin
      Suggest := El('ul', 'editor-suggest');
      Suggest.setAttribute('role', 'listbox');
      // a click keeps the caret in the text
      Suggest.addEventListener('pointerdown', TJSRawEventHandler(procedure(E: TJSEvent) begin E.preventDefault; end));
      document.body.appendChild(Suggest);
    end;
    Suggest.replaceChildren;
    for N := 0 to Choices.length - 1 do Add(TEmoji(Choices[N]), N);
    Mark(0);
    P := CaretPoint(TypedFrom);
    TJSObject(Suggest.style)['top'] := String(JSValue(MinF(P.top + 4, window.innerHeight - Suggest.offsetHeight - 8))) + 'px';
    TJSObject(Suggest.style)['left'] := String(JSValue(MaxF(8, MinF(P.left, window.innerWidth - Suggest.offsetWidth - 8)))) + 'px';
  end;

  // Ev: the input that brought this, none when an arrow key asks
  procedure Offer(Ev: TJSEvent);
  var
    At: NativeInt;
    Typing: TTyped;
  begin
    At := Box.selectionStart;
    // the keyword being typed, as every part finds it (emoji-names.js);
    // one finished with its second colon becomes its emoji at once
    if At = Box.selectionEnd then Typing := EmojiNames.typed(Box.value, At, Eager) else Typing := nil;
    if not Truthy(Typing) or (Typing.whole and not (Truthy(Ev) and (TJSInputEvent(Ev).data = ':'))) then
    begin
      CloseSuggest;
      Exit;
    end;
    TypedFrom := Typing.from;
    EmojiSet._then(function(List: JSValue): JSValue
      var
        Hit: TEmoji;
      begin
        if Box.selectionStart <> At then Exit;
        if Typing.whole then
        begin
          Hit := EmojiNames.named(List, Typing.word);
          CloseSuggest;
          if Truthy(Hit) then Replace(TypedFrom, At, Hit.emoji);
          Exit;
        end;
        Choices := EmojiNames.matches(List, Typing.word).slice(0, 8);
        if Choices.length <> 0 then ShowSuggest else CloseSuggest;
      end);
  end;

  procedure Bullets;
  begin
    Prefix(function(N: NativeInt): string begin Result := '- '; end, TJSRegExp.new('^(\s*)[-*+]\s+'));
  end;

  procedure Numbers;
  begin
    Prefix(function(N: NativeInt): string begin Result := String(JSValue(N + 1)) + '. '; end, TJSRegExp.new('^(\s*)\d+[.)]\s+'));
  end;

  // ---- write, side by side, preview; and the whole window

  procedure Say(Words: JSValue; Bad: JSValue);
  begin
    window.clearTimeout(NewsTimer);
    TJSObject(News)['textContent'] := Words;
    TTokens(News.classList).toggle('bad', Truthy(Bad));
    if not Bad then NewsTimer := window.setTimeout(procedure begin Busy; end, 4000);
  end;

  procedure Busy;
  begin
    if Pending <> 0 then
    begin
      News.classList.remove('bad');
      if TJSObject(window)['tn'] then News.textContent := TN(Pending, 'Uploading %d picture…', 'Uploading %d pictures…')
      else News.textContent := T('Uploading…');
    end
    else if not News.classList.contains('bad') then News.textContent := '';
  end;

  function Shown: string;
  begin
    if (Mode = 'split') and Narrow.matches then Result := 'write' else Result := Mode;
  end;

  procedure Draw;
  var
    Now, Key: string;
    B: JSValue;
  begin
    Now := Shown;
    Panes.dataset['mode'] := Now;
    Bar.dataset['mode'] := Now;
    for Key in Tabs do
      if Key = Now then TJSElement(Tabs[Key]).setAttribute('aria-selected', 'true') else TJSElement(Tabs[Key]).setAttribute('aria-selected', 'false');
    TJSHTMLElement(Tabs['split']).hidden := Narrow.matches;
    for B in TJSArray(JSValue(Tools.querySelectorAll('.editor-tool'))) do TJSHTMLButtonElement(B).disabled := Now = 'preview';
    if Now = 'preview' then ClosePop;
    if (Now <> 'write') and Stale then Ask
    else if Now = 'split' then
    begin
      Measure;
      Follow;
    end;
  end;

  procedure SetMode(const Key: string);
  begin
    Mode := Key;
    try
      window.localStorage.setItem(StoreKey, Mode);
    except
    end;
    Draw;
    if Shown <> 'preview' then Box.focus;
  end;

  procedure AddTab(const Key, Words: string);
  var
    B: TJSHTMLElement;
  begin
    B := El('button', 'editor-mode', Words);
    TJSHTMLButtonElement(B)._type := 'button';
    B.setAttribute('role', 'tab');
    B.dataset['mode'] := Key;
    B.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin SetMode(Key); end));
    Tabs[Key] := B;
    Modes.appendChild(B);
  end;

  procedure SetWhole(On_: boolean; Quiet: boolean = False);
  begin
    TTokens(Shell.classList).toggle('whole', On_);
    if On_ then TChild(Foot).after(SendRow) else TChild(Shell).after(SendRow);
    window.requestAnimationFrame(procedure(Time: TJSDOMHighResTimeStamp) begin Measure; Follow; end);
    TTokens(document.documentElement.classList).toggle('editor-whole', On_);
    if On_ then Whole.setAttribute('aria-pressed', 'true') else Whole.setAttribute('aria-pressed', 'false');
    if On_ then Whole.title := T('Leave full screen (Esc)') else Whole.title := T('Full screen');
    Whole.setAttribute('aria-label', Whole.title);
    if not Quiet then Box.focus;
  end;

  // ---- the preview, a moment after typing stops

  procedure Ask; async;
  var
    Mine: TJSAbortController;
    Html: string;
  begin
    Stale := False;
    if Asking <> nil then Asking.abort;
    Mine := TJSAbortController.new;
    Asking := Mine;
    View.classList.add('busy');
    // the first time there is nothing to dim: say it is coming
    if View.firstChild = nil then View.appendChild(El('p', 'fine', T('Making the preview…')));
    try
      try
        Html := await(string, Opts.preview(Box.value, Mine.signal));
        if Asking <> Mine then Exit;
        asm View.innerHTML = Html;   // safe html: the part's own renderer made it
        end;
        if TJSString(Box.value).trim = '' then View.replaceChildren(El('p', 'fine', Either(Opts['emptyWords'], T('The preview shows here as you write.'))))
        else if Opts['afterPreview'] then Opts.afterPreview(View);
        Measure;
        Follow;
      except
        if TJSObject(JSExceptValue)['name'] = 'AbortError' then Exit;
        Stale := True;
        View.replaceChildren(El('p', 'problem', T('The preview could not be made. It tries again when you type.')));
      end;
    finally
      if Asking = Mine then
      begin
        Asking := nil;
        View.classList.remove('busy');
      end;
    end;
  end;

  // side by side: the preview keeps to the same part of the page as the
  // text.  Each heading in the text is tied to its heading in the preview,
  // and between two headings the preview moves in step; a page whose
  // headings do not pair up one for one goes by how far down the text is.

  // a heading's letters and digits alone, so the text's heading and the page's can be told to be the same
  function Plain(const Words: string): string;
  begin
    Result := TJSString(TJSString(Words).replace(TJSRegExp.new('[^\p{L}\p{N}]+', 'gu'), '')).toLowerCase;
  end;

  // where each heading line of the text starts
  function HeadingStarts: TJSArray;
  var
    At: NativeInt;
    Fence, Line: string;
    Mark: TTexts;
  begin
    Result := TJSArray.new;
    At := 0;
    Fence := '';
    for Line in TText(Box.value).parts(#10) do
    begin
      Mark := TTexts(JSValue(TJSRegExp.new('^ {0,3}(`{3,}|~{3,})(.*)$').exec(Line)));
      if Mark <> nil then
      begin
        if Fence = '' then Fence := Mark[1]
        else if (TJSString(Mark[1]).charAt(0) = TJSString(Fence).charAt(0)) and (Length(Mark[1]) >= Length(Fence)) and (TJSString(Mark[2]).trim = '') then Fence := '';
      end
      else if (Fence = '') and TJSRegExp.new('^ {0,3}#{1,6}([ \t]|$)').test(Line) then
        Result.push(new(['at', At, 'words', Plain(TJSString(TJSString(TJSString(Line).replace(TJSRegExp.new('^\s*#+'), '')).replace(
          TJSRegExp.new('\[\[(?:[^\]|]*\|)?([^\]]*)\]\]', 'g'), '$1')).replace(TJSRegExp.new('\[([^\]]*)\]\([^)]*\)', 'g'), '$1'))]));
      At := At + Length(Line) + 1;
    end;
  end;

  procedure Measure;
  var
    Heads, Paired, Marks: TJSArray;
    Starts: array of NativeInt;
    Next, K, N, From: NativeInt;
    H: JSValue;
    Look: TJSObject;
    P: string;
    Mark: TJSHTMLElement;
    TextMax, ViewMax, Top, A, B: double;
    Made: TTies;
    Last: TNumbers;
  begin
    Ties := nil;
    if Shown <> 'split' then Exit;
    Heads := ArrayFrom(View.querySelectorAll(string(Either(Opts['heads'], 'h1, h2, h3, h4, h5, h6'))));
    // each heading of the text with its own heading in the preview, in order;
    // one that has no partner (a heading inside a quotation, say) is passed over
    Starts := nil;
    Paired := TJSArray.new;
    Next := 0;
    for H in HeadingStarts do
    begin
      K := Next;
      while K < MinN(Heads.length, Next + 4) do
      begin
        if Plain(TJSNode(Heads[K]).textContent) = THeading(H).words then
        begin
          TJSArray(Starts).push(THeading(H).at);
          Paired.push(Heads[K]);
          Next := K + 1;
          Break;
        end;
        Inc(K);
      end;
    end;
    if Length(Starts) = 0 then Exit;
    // the text laid out as the box lays it out, with a mark at each heading
    Look := TJSObject(window.getComputedStyle(Box));
    for P in MirrorLook do TJSObject(Mirror.style)[P] := Look[P];
    TJSObject(Mirror.style)['width'] := String(JSValue(Box.clientWidth)) + 'px';
    Mirror.replaceChildren;
    Marks := TJSArray.new;
    From := 0;
    for N := 0 to Length(Starts) - 1 do
    begin
      Mirror.append(TJSString(Box.value).slice(From, Starts[N]));
      Mark := El('span');
      Mirror.append(Mark);
      Marks.push(Mark);
      From := Starts[N];
    end;
    Mirror.append(TJSString(Box.value).slice(From));
    document.body.appendChild(Mirror);
    TextMax := Box.scrollHeight - Box.clientHeight;
    ViewMax := View.scrollHeight - View.clientHeight;
    Top := View.getBoundingClientRect.top - View.scrollTop;
    Made := [[0, 0]];
    for N := 0 to Marks.length - 1 do
    begin
      A := MinF(TJSHTMLElement(Marks[N]).offsetTop - ToFloat(Look['paddingTop']), TextMax);
      B := MinF(TJSElement(Paired[N]).getBoundingClientRect.top - Top - 12, ViewMax);
      Last := Made[Length(Made) - 1];
      if (A > Last[0]) and (B >= Last[1]) then TJSArray(Made).push(TJSArray.new(A, B));
    end;
    Mirror.remove;
    Mirror.replaceChildren;
    Last := Made[Length(Made) - 1];
    if TextMax > Last[0] then TJSArray(Made).push(TJSArray.new(TextMax, MaxF(ViewMax, Last[1])));
    Ties := Made;
  end;

  procedure Follow;
  var
    Y, Part, Room: double;
    N: NativeInt;
    A, B: TNumbers;
  begin
    if Shown <> 'split' then Exit;
    Y := Box.scrollTop;
    if Length(Ties) > 1 then
    begin
      N := 0;
      while (N < Length(Ties) - 2) and (Ties[N + 1][0] <= Y) do Inc(N);
      A := Ties[N];
      B := Ties[N + 1];
      if B[0] > A[0] then Part := MinF(1, MaxF(0, (Y - A[0]) / (B[0] - A[0]))) else Part := 0;
      TJSObject(View)['scrollTop'] := A[1] + Part * (B[1] - A[1]);
      Exit;
    end;
    Room := Box.scrollHeight - Box.clientHeight;
    if Room > 0 then TJSObject(View)['scrollTop'] := (Y / Room) * (View.scrollHeight - View.clientHeight) else View.scrollTop := 0;
  end;

  // a picture that arrives, or a window made wider, moves every heading
  procedure Remeasure;
  begin
    window.clearTimeout(Again);
    Again := window.setTimeout(procedure begin Measure; Follow; end, 150);
  end;

  // ---- keys: the toolbar's, and lists that go on by themselves

  procedure Save;
  var
    Button: TJSHTMLElement;
  begin
    if Pending <> 0 then
    begin
      Say(T('Wait until the pictures are uploaded.'), True);
      Exit;
    end;
    if Form = nil then Exit;
    Button := TJSHTMLElement(Form.querySelector('button[type="submit"]:not([name])'));
    if TJSObject(Form)['requestSubmit'] then
    begin
      if Button <> nil then Form.requestSubmit(Button) else Form.requestSubmit;
    end
    else if Button <> nil then Button.click;
  end;

  procedure NotSaved;
  begin
    Saving := False;
  end;

begin
  if TJSObject(Box)['editor'] then Exit(TJSObject(TJSObject(Box)['editor']));
  if Truthy(Options) then Opts := Options else Opts := TOptions(TJSObject.new);
  Fresh;
  Form := TJSHTMLFormElement(Box.closest('form'));
  if Opts['language'] then Language := string(Opts['language']) else Language := '';
  Choices := TJSArray.new;
  TypedFrom := -1;
  TypedAt := -1;
  Stale := True;

  Editor := new(['box', Box, 'form', Form, 'el', @El, 'svg', @Svg, 'replace', @Replace, 'wrap', @Wrap, 'lines', @Lines, 'prefix', @Prefix,
    'pop', @Pop, 'closePop', @ClosePop, 'say', @Say, 'tool', @Tool, 'gap', @Gap, 'upload', @Upload, 'choose', @Choose]);

  document.addEventListener('pointerdown', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      if (Open <> nil) and not Open.contains(TJSNode(E.target)) and (TJSElement(E.target).closest('.editor-tools, .editor-side') = nil) then ClosePop;
    end));
  document.addEventListener('keydown', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      if (TJSKeyboardEvent(E).key = 'Escape') and (Open <> nil) then
      begin
        ClosePop;
        Box.focus;
      end;
    end));

  Chooser := TJSHTMLInputElement(El('input'));
  Chooser._type := 'file';
  if Pictures <> nil then TJSObject(Chooser)['accept'] := Pictures.accept else Chooser.accept := '';
  Chooser.multiple := True;
  Chooser.hidden := True;
  if Form <> nil then Form.appendChild(Chooser);
  Chooser.addEventListener('change', TJSRawEventHandler(procedure(E: TJSEvent) begin Upload(ArrayFrom(Chooser.files)); Chooser.value := ''; end));
  AskRow := El('div', 'editor-ask');

  if Pictures <> nil then
  begin
    // the text box takes dropped and pasted pictures
    Box.addEventListener('dragover', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        if Truthy(TJSDragEvent(E).dataTransfer) and ArrayFrom(TJSDragEvent(E).dataTransfer.types).includes('Files') then
        begin
          E.preventDefault;
          Shell.classList.add('dropping');
        end;
      end));
    Box.addEventListener('dragleave', TJSRawEventHandler(procedure(E: TJSEvent) begin Shell.classList.remove('dropping'); end));
    Box.addEventListener('drop', TJSRawEventHandler(procedure(E: TJSEvent)
      var
        List: TJSArray;
        P: TCaretPosition;
      begin
        Shell.classList.remove('dropping');
        if Truthy(TJSDragEvent(E).dataTransfer) then List := ArrayFrom(TJSDragEvent(E).dataTransfer.files) else List := TJSArray.new;
        if List.length = 0 then Exit;
        E.preventDefault;
        // the drop point becomes the cursor, so the picture goes where it fell
        if TJSObject(document)['caretPositionFromPoint'] then
        begin
          P := TCaretDocument(document).caretPositionFromPoint(TJSMouseEvent(E).clientX, TJSMouseEvent(E).clientY);
          if Truthy(P) and (P.offsetNode = Box) then Box.setSelectionRange(P.offset, P.offset);
        end;
        Upload(List);
      end));
    Box.addEventListener('paste', TJSRawEventHandler(procedure(E: TJSEvent)
      var
        List: TJSArray;
        Data: TJSDataTransfer;
      begin
        Data := TJSClipBoardEvent(E).clipboardData;
        if Truthy(Data) then List := ArrayFrom(Either(Data.files, TJSArray.new)) else List := TJSArray.new;
        if List.length = 0 then Exit;
        E.preventDefault;
        Upload(List);
      end));
  end;

  if Opts['compact'] then Shell := El('div', 'editor editor-shell editor-compact') else Shell := El('div', 'editor editor-shell');
  Bar := El('div', 'editor-bar');
  Tools := El('div', 'editor-tools');
  Tools.setAttribute('role', 'toolbar');
  Tools.setAttribute('aria-label', T('Formatting'));
  Side := El('div', 'editor-side');
  Bar.append(Tools, Side);
  Tool(T('Heading'), '', 'H<span class="editor-tool-more" aria-hidden="true">▾</span>', @HeadingMenu).setAttribute('aria-haspopup', 'menu');
  Tool(T('Bold'), ModKey + 'B', '<b>B</b>', procedure(B: TJSHTMLElement) begin Wrap('**', '**', T('bold')); end);
  Tool(T('Italic'), ModKey + 'I', '<i>I</i>', procedure(B: TJSHTMLElement) begin Wrap('_', '_', T('italic')); end);
  Tool(T('Strikethrough'), ModKey + ShiftKey + 'X', '<s>S</s>', procedure(B: TJSHTMLElement) begin Wrap('~~', '~~', T('words')); end);
  Gap;
  Tool(T('Link'), ModKey + 'K', Svg('<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>'),
    TToolAct(JSValue(@Link)));
  if Opts['linkTools'] then Opts.linkTools(Editor);
  Gap;
  Tool(T('Bulleted list'), ModKey + ShiftKey + '8',
    Svg('<path d="M9 6h11M9 12h11M9 18h11"/><circle cx="4.5" cy="6" r="1.2"/><circle cx="4.5" cy="12" r="1.2"/><circle cx="4.5" cy="18" r="1.2"/>'),
    TToolAct(JSValue(@Bullets)));
  Tool(T('Numbered list'), ModKey + ShiftKey + '7', '1.', TToolAct(JSValue(@Numbers)));
  Tool(T('Quote'), '', '❝', procedure(B: TJSHTMLElement)
    begin
      Prefix(function(N: NativeInt): string begin Result := '> '; end, TJSRegExp.new('^>\s?'));
    end);
  Gap;
  Tool(T('Code'), ModKey + 'E', '&lt;/&gt;', TToolAct(JSValue(@Code)));
  Tool(T('Table'), '', Svg('<rect x="3" y="5" width="18" height="14" rx="1.5"/><path d="M3 10h18M3 14.5h18M9 5v14M15 5v14"/>'), @TableGrid);

  GroupWords := new(['status', T('Status'), 'color', T('Colors'), 'symbol', T('Symbols'), 'own', T('This site''s own')]);
  if Opts['emoji'] then
    Tool(T('Emoji'), '', Svg('<rect x="3.5" y="3.5" width="17" height="17" rx="4.5"/><path d="M8 12.4l2.8 2.8L16.2 9.6"/>'), @EmojiPanel).setAttribute(
      'aria-haspopup', 'dialog');

  if Opts['emoji'] then
  begin
    Box.addEventListener('input', TJSRawEventHandler(procedure(Ev: TJSEvent) begin Offer(Ev); TypedAt := Box.selectionStart; end));
    Box.addEventListener('keydown', TJSRawEventHandler(procedure(Ev: TJSEvent)
      var
        E: TJSKeyboardEvent;
        Arrow: boolean;
        Short: TTyped;
      begin
        E := TJSKeyboardEvent(Ev);
        Arrow := ((E.key = 'ArrowDown') or (E.key = 'ArrowUp')) and not E.shiftKey and not E.ctrlKey and not E.altKey and not E.metaKey;
        if (Suggest = nil) or (Choices.length = 0) then
        begin
          // an arrow key after a colon, or a colon and one letter, opens the list
          if Arrow and (Box.selectionStart = TypedAt) and (Box.selectionEnd = TypedAt) then Short := EmojiNames.typed(Box.value, TypedAt, True)
          else Short := nil;
          if not Truthy(Short) or Short.whole or (Length(Short.word) > 1) then Exit;
          Eager := True;
          Offer(nil);
        end
        else if Arrow then
        begin
          if E.key = 'ArrowDown' then Mark((Chosen + 1) mod Choices.length) else Mark((Chosen + Choices.length - 1) mod Choices.length);
        end
        else if (E.key = 'Enter') or (E.key = 'Tab') then TakeChoice(Chosen)
        else if E.key = 'Escape' then
        begin
          CloseSuggest;
          TypedAt := -1;
        end
        else Exit;
        E.preventDefault;
        E.stopImmediatePropagation;
      end));
    Box.addEventListener('blur', TJSRawEventHandler(JSValue(@CloseSuggest)));
    Box.addEventListener('scroll', TJSRawEventHandler(JSValue(@CloseSuggest)));
    window.addEventListener('resize', TJSRawEventHandler(JSValue(@CloseSuggest)));
  end;

  Modes := El('div', 'editor-modes');
  Modes.setAttribute('role', 'tablist');
  Whole := El('button', 'editor-whole');
  TJSHTMLButtonElement(Whole)._type := 'button';
  Icon := Svg('<path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/>');
  asm Whole.innerHTML = Icon;   // safe html: a fixed icon
  end;
  Side.append(Modes, Whole);
  Panes := El('div', 'editor-panes');
  if Opts['viewClass'] then View := El('div', 'editor-view ' + string(Opts['viewClass'])) else View := El('div', 'editor-view');
  View.setAttribute('aria-live', 'polite');
  Foot := El('div', 'editor-foot');
  News := El('span', 'editor-news');
  News.setAttribute('role', 'status');
  Hint := El('span', 'editor-hint');
  if (Pictures <> nil) and Truthy(Pictures['label']) then AttachLink := El('button', 'editor-link', Pictures['label'])
  else AttachLink := El('button', 'editor-link', T('add pictures'));
  TJSHTMLButtonElement(AttachLink)._type := 'button';
  AttachLink.addEventListener('click', TJSRawEventHandler(JSValue(@Choose)));
  // Web's append takes elements and strings: a text node goes through as it is
  Hint.append(TJSElement(document.createTextNode(string(Either(Opts['hint'], T('Markdown.'))))));
  if Pictures <> nil then
  begin
    Hint.append(TJSElement(document.createTextNode(' ')), AttachLink);
    // Android's chooser has the camera and the file browser but no gallery,
    // unless pictures alone are asked for: a second link asks for those
    if Truthy(Pictures.gallery) and TJSRegExp.new('Android').test(window.navigator.userAgent) then
    begin
      if TJSRegExp.new('video').test(string(Pictures.gallery)) then Gallery := El('button', 'editor-link', T('Photos and videos'))
      else Gallery := El('button', 'editor-link', T('Photos'));
      TJSHTMLButtonElement(Gallery)._type := 'button';
      Gallery.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Choose(Pictures.gallery); end));
      Hint.append(TJSElement(document.createTextNode(' · ')), Gallery);
    end;
  end;
  HelpButton := El('button', 'editor-link', T('Formatting help'));
  TJSHTMLButtonElement(HelpButton)._type := 'button';
  HelpButton.setAttribute('aria-expanded', 'false');
  Foot.append(Hint, News, HelpButton);
  Help := El('div', 'editor-help');
  Help.hidden := True;
  // a box inside its label comes out of it: a click on the preview or a
  // menu would otherwise go to the box, as clicks in a label do
  LabelEl := TJSHTMLElement(Box.closest('label'));
  if LabelEl <> nil then
  begin
    if Box.id = '' then
    begin
      Inc(Made);
      Box.id := 'editor-box-' + String(JSValue(Made));
    end;
    TJSHTMLLabelElement(LabelEl).For_ := Box.id;
    TChild(LabelEl).after(Shell);
  end
  else Box.before(Shell);
  Shell.append(Bar, Panes, AskRow, Foot, Help);
  Panes.append(Box, View);
  // the form's own parts the part wants under the editor: full screen
  // takes the row along, so the text can be sent without leaving it
  SendRow := El('div', 'editor-send');
  TChild(Shell).after(SendRow);
  if Opts['sendRow'] then
    for Part in TJSArray(Opts['sendRow']) do
      if Part then SendRow.appendChild(TJSNode(Part));
  SendRow.hidden := SendRow.firstChild = nil;

  Cheats := TJSArray.new(
    TJSArray.new('## ' + T('Heading'), T('a heading; ### for a smaller one')),
    TJSArray.new('**' + T('bold') + '**  _' + T('italic') + '_  ~~' + T('struck') + '~~', T('emphasis')),
    TJSArray.new('`code`', T('code in a sentence')),
    TJSArray.new('```' + string(Either(Language, 'pascal')) + #10 + 'begin' + #10 + 'end.' + #10 + '```',
      T('a block of code; the word after ``` names its language, for its colors')),
    TJSArray.new('- ' + T('item') + #10 + '1. ' + T('item'), T('lists; Tab moves an item in, Shift+Tab out')),
    TJSArray.new('> ' + T('words'), T('a quotation')),
    TJSArray.new('[' + T('words') + '](https://…)', T('a link to another site')));
  if Opts['cheats'] then Cheats := Cheats.concat(Opts['cheats']);
  Sheet := El('table');
  for I := 0 to Cheats.length - 1 do
  begin
    Pair := TJSArray(Cheats[I]);
    Row := El('tr');
    Cell := El('td');
    Cell.appendChild(El('code', '', Pair[0]));
    Row.append(Cell, El('td', '', Pair[1]));
    Sheet.appendChild(Row);
  end;
  KeysLine := El('p', 'fine', T('Keys: %s bold, %s italic, %s link, %s code, %s preview, %s save.', ModKey + 'B', ModKey + 'I', ModKey + 'K', ModKey + 'E',
    ModKey + ShiftKey + 'P', ModKey + 'Enter'));
  Help.append(Sheet, KeysLine);
  if Opts['helpLink'] then
  begin
    More := El('p', 'fine');
    Guide := El('a', '', TJSObject(Opts['helpLink'])['words']);
    TJSObject(Guide)['href'] := TJSObject(Opts['helpLink'])['href'];
    TJSObject(Guide)['target'] := '_blank';
    More.appendChild(Guide);
    Help.appendChild(More);
  end;
  HelpButton.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      Help.hidden := not Help.hidden;
      if Help.hidden then HelpButton.setAttribute('aria-expanded', 'false') else HelpButton.setAttribute('aria-expanded', 'true');
    end));

  Narrow := window.matchMedia('(max-width: 899px)');
  StoreKey := string(Either(Opts['storeKey'], 'editor-mode'));
  Mode := string(Either(Opts['mode'], 'split'));
  try
    Stored := window.localStorage.getItem(StoreKey);
    if Stored then Mode := string(Stored);
  except
  end;
  // a part with no renderer has the text alone
  if not Opts['preview'] then
  begin
    Mode := 'write';
    Modes.hidden := True;
  end;
  Tabs := TJSObject.new;
  AddTab('write', T('Write'));
  AddTab('split', T('Side by side'));
  AddTab('preview', T('Preview'));
  if TJSObject(Narrow)['addEventListener'] then Narrow.addEventListener('change', TJSRawEventHandler(JSValue(@Draw)));

  Whole.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin SetWhole(not Shell.classList.contains('whole')); end));
  SetWhole(False, True);
  document.addEventListener('keydown', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      if (TJSKeyboardEvent(E).key = 'Escape') and (Open = nil) and Shell.classList.contains('whole') then SetWhole(False);
    end));

  Box.addEventListener('input', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      Stale := True;
      window.clearTimeout(Timer);
      if Shown <> 'write' then Timer := window.setTimeout(TJSTimerCallBack(JSValue(@Ask)), 700);
    end));

  Mirror := El('div');
  Mirror.setAttribute('aria-hidden', 'true');
  Mirror.style.cssText := 'position:absolute;visibility:hidden;pointer-events:none;top:0;left:-9999px;white-space:pre-wrap;overflow-wrap:break-word;' +
    'box-sizing:border-box;border:0;margin:0;';
  Box.addEventListener('scroll', TJSRawEventHandler(JSValue(@Follow)), TJSEventListenerOptions(new(['passive', True])));
  View.addEventListener('load', TJSRawEventHandler(JSValue(@Remeasure)), True);
  window.addEventListener('resize', TJSRawEventHandler(JSValue(@Remeasure)));

  Shell.addEventListener('keydown', TJSRawEventHandler(procedure(Ev: TJSEvent)
    var
      E: TJSKeyboardEvent;
      K: string;
    begin
      E := TJSKeyboardEvent(Ev);
      if not (E.ctrlKey or E.metaKey) or E.altKey then Exit;
      K := TJSString(E.key).toLowerCase;
      if K = 'enter' then
      begin
        E.preventDefault;
        Save;
        Exit;
      end;
      if E.shiftKey and (K = 'p') then
      begin
        E.preventDefault;
        if Shown <> 'preview' then SetMode('preview')
        else if Narrow.matches then SetMode('write')
        else SetMode('split');
      end;
    end));

  Box.addEventListener('keydown', TJSRawEventHandler(procedure(Ev: TJSEvent)
    var
      E: TJSKeyboardEvent;
      K, V, Line, Next: string;
      Act: TWork;
      At, Start, Cut: NativeInt;
      Item: TTexts;
    begin
      E := TJSKeyboardEvent(Ev);
      K := TJSString(E.key).toLowerCase;
      if (E.ctrlKey or E.metaKey) and not E.altKey then
      begin
        Act := nil;
        if E.shiftKey then
        begin
          if E.code = 'Digit8' then K := '8'
          else if E.code = 'Digit7' then K := '7';
          if K = 'x' then Act := procedure
            begin
              Wrap('~~', '~~', T('words'));
            end
          else if (K = '*') or (K = '8') then Act := @Bullets
          else if (K = '&') or (K = '7') then Act := @Numbers;
        end
        else if K = 'b' then Act := procedure
          begin
            Wrap('**', '**', T('bold'));
          end
        else if K = 'i' then Act := procedure
          begin
            Wrap('_', '_', T('italic'));
          end
        else if K = 'k' then Act := @Link
        else if K = 'e' then Act := @Code;
        if Act <> nil then
        begin
          E.preventDefault;
          Act();
          Exit;
        end;
      end;
      if E.ctrlKey or E.metaKey or E.altKey or (Box.selectionStart <> Box.selectionEnd) then Exit;
      V := Box.value;
      At := Box.selectionStart;
      Start := TJSString(V).lastIndexOf(#10, At - 1) + 1;
      Line := TJSString(V).slice(Start, At);
      Item := TTexts(JSValue(TJSRegExp.new('^(\s*)([-*+]|\d+[.)]|>)(\s+)').exec(Line)));
      if (E.key = 'Enter') and not E.shiftKey and (Item <> nil) then
      begin
        E.preventDefault;
        // an empty item ends the list
        if Length(Line) = Length(Item[0]) then
        begin
          Replace(Start, At, '');
          Exit;
        end;
        if TJSRegExp.new('\d').test(Item[2]) then Next := String(JSValue(parseInt(Item[2], 10) + 1)) + TJSString(Item[2]).slice(-1) else Next := Item[2];
        Replace(At, At, #10 + Item[1] + Next + Item[3]);
        Exit;
      end;
      // Tab moves a list item in or out; elsewhere it leaves the box, as it should
      if (E.key = 'Tab') and (Item <> nil) and (Item[2] <> '>') then
      begin
        E.preventDefault;
        if E.shiftKey then
        begin
          Cut := MinN(2, Length(Item[1]));
          if Cut <> 0 then Replace(Start, Start + Cut, '', 0, 0);
          Box.setSelectionRange(At - Cut, At - Cut);
        end
        else
        begin
          Replace(Start, Start, '  ', 0, 0);
          Box.setSelectionRange(At + 2, At + 2);
        end;
      end;
    end));

  // ---- not leaving with changes unsaved, nor sending half an upload

  First := Box.value;
  Saving := False;
  // heard first (capture), so a part that sends the form itself does not
  // send it with a file still on its way
  if Form <> nil then Form.addEventListener('submit', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        if Pending <> 0 then
        begin
          E.preventDefault;
          E.stopImmediatePropagation;
          Say(T('Wait until the pictures are uploaded.'), True);
          Exit;
        end;
        Saving := True;
      end), True);
  // a part whose save was refused says so: the text is still unsaved
  Editor['notSaved'] := @NotSaved;
  window.addEventListener('beforeunload', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      if not Saving and (Box.value <> First) then
      begin
        E.preventDefault;
        TJSObject(E)['returnValue'] := '';
      end;
    end));

  Editor['shell'] := Shell;
  Editor['view'] := View;
  Draw;
  if Shown <> 'write' then Ask;
  TJSObject(Box)['editor'] := Editor;
  Result := Editor;
end;

initialization
  if TJSObject(window)['t'] then T := TWords(TJSObject(window)['t'])
  else T := function(const English: string): string
    begin
      Result := English;
    end;
  Mac := TJSRegExp.new('Mac|iPhone|iPad').test(window.navigator.platform);
  if Mac then ModKey := '⌘' else ModKey := 'Ctrl+';
  if Mac then ShiftKey := '⇧' else ShiftKey := 'Shift+';
  Made := 0;
  TJSObject(window)['Editor'] := new(['attach', @Attach]);
end.
