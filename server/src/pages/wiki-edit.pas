unit WikiEditPage;

{ Wiki editor tools: [[links]], pictures and the wiki renderer's preview.
  The shared toolbar is in editor.js; the plain form and Preview button
  also work without scripts. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

implementation

uses JS, Web, PageKit;

type
  TAct = reference to procedure(Button: TJSElement);
  TWords = reference to function(const English: string): string;
  TWordsWith = reference to function(const English: string; Value: JSValue): string;
  // The editor's own functions, kept as it gave them and called with as many arguments as each use has.
  TMake = reference to function(const Tag: string): TJSHTMLElement;
  TMakeClass = reference to function(const Tag, Cls: string): TJSHTMLElement;
  TMakeText = reference to function(const Tag, Cls: string; Text: JSValue): TJSHTMLElement;
  TReplace = reference to procedure(A, B: NativeInt; const Text: string);
  TReplaceSelect = reference to procedure(A, B: NativeInt; const Text: string; SelectFrom, SelectTo: NativeInt);
  TClosePop = reference to procedure;

  // editor.js and emoji-names.js are JavaScript: only what this unit uses of them.
  TEditor = class external name 'Object'(TJSObject)
    function pop(Button: TJSElement): TJSHTMLElement;
    procedure choose;
    function tool(const Caption, Keys, Mark: string; Act: TAct): TJSHTMLElement;
    function svg(const Inner: string): string;
  end;
  TEditorKit = class external name 'Object'(TJSObject)
    function attach(Box: TJSElement; Options: TJSObject): TEditor;
  end;
  TEmojiNames = class external name 'Object'(TJSObject)
    function after(List: JSValue): TJSPromise;
  end;
  // pas2js Web declares only the string URLSearchParams constructor.
  TParams = class external name 'URLSearchParams'(TJSURLSearchParams)
    constructor new(Data: TJSObject);
  end;
  // Web's FormData has no append that names the file.
  TUpload = class external name 'FormData'(TJSFormData)
    procedure append(const Name: string; Value: TJSBlob; const FileName: string); overload;
  end;

var
  EditorKit: TEditorKit; external name 'window.Editor';
  EmojiNames: TEmojiNames; external name 'window.EmojiNames';

// A JSValue compared with True compiles to a loose comparison; this one is strict.
function Identical(A, B: JSValue): boolean; external name 'Object.is';

procedure Start;
var
  Form, Summary, Actions, Fine, Reload, RowSummary, RowActions: TJSElement;
  Box: TJSHTMLTextAreaElement;
  Say: JSValue;
  T: TWords;
  TWith: TWordsWith;
  Ed: TEditor;
  El: TMake;
  ElClass: TMakeClass;
  ElText: TMakeText;
  Replace: TReplace;
  ReplaceSelect: TReplaceSelect;
  ClosePop: TClosePop;
  FileRef, PathRef: TJSRegexp;

  function Pop(Button: TJSElement): TJSHTMLElement;
  begin
    Result := Ed.pop(Button);
  end;

  // ---- [[links]]: a finder for the page to link to

  procedure FindPage(Button: TJSElement);
  var
    Card, List: TJSHTMLElement;
    Find: TJSHTMLInputElement;
    A, B, Timer, Asked: NativeInt;
    Words: string;

    procedure Put(const Title: string);
    var
      Text: string;
    begin
      ClosePop();
      if (Words <> '') and (Words <> Title) then Text := '[[' + Title + '|' + Words + ']]'
      else Text := '[[' + Title + ']]';
      Replace(A, B, Text);
    end;

    procedure Offer(Li, Pick: TJSHTMLElement; const Title: string);
    begin
      TJSHTMLButtonElement(Pick)._type := 'button';
      Pick.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Put(Title); end));
      Li.appendChild(Pick);
      List.appendChild(Li);
    end;

    procedure Search;
    var
      Q: string;
      Mine: NativeInt;
    begin
      Q := TJSString(Find.value).trim;
      Inc(Asked);
      Mine := Asked;
      List.replaceChildren;
      if Length(Q) < 2 then Exit;
      window.fetch('/api/wiki/search?q=' + encodeURIComponent(Q))._then(function(Answer: JSValue): JSValue
        begin
          if TJSResponse(Answer).ok then Result := TJSResponse(Answer).json else Result := TJSArray.new;
        end)._then(function(Found: JSValue): JSValue
        var
          Pages: TJSArray;
          I: integer;
        begin
          if Mine <> Asked then Exit;
          if Truthy(Found) then Pages := TJSArray(Found) else Pages := TJSArray.new;
          Pages := Pages.slice(0, 8);
          for I := 0 to Pages.length - 1 do
            Offer(El('li'), ElText('button', '', TJSObject(Pages[I])['title']), string(TJSObject(Pages[I])['title']));
          // a page that does not exist yet: the link starts it
          Offer(ElClass('li', 'wikitools-new'), ElText('button', '', TWith('Link to "%s", a new page', Q)), Q);
        end).catch(function(Why: JSValue): JSValue
        begin
        end);
    end;

  begin
    Card := Pop(Button);
    A := Box.selectionStart;
    B := Box.selectionEnd;
    Words := TJSString(Box.value).slice(A, B);
    Find := TJSHTMLInputElement(El('input'));
    Find._type := 'search';
    Find.placeholder := T('Find a page');
    Find.setAttribute('aria-label', T('Find a page'));
    List := ElClass('ul', 'wikitools-found');
    Card.append(Find, List);
    Find.focus;
    Timer := 0;
    Asked := 0;
    Find.addEventListener('input', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        window.clearTimeout(Timer);
        Timer := window.setTimeout(@Search, 250);
      end));
    Find.addEventListener('keydown', TJSRawEventHandler(procedure(E: TJSEvent)
      var
        First: TJSElement;
      begin
        if TJSKeyboardEvent(E).key <> 'Enter' then Exit;
        E.preventDefault;
        First := List.querySelector('button');
        if First <> nil then TJSHTMLElement(First).click;
      end));
    if Words <> '' then
    begin
      Find.value := Words;
      Search;
    end;
  end;

  // ---- images: [[File:Name.png]], as MediaWiki writes them

  function UsedNames: TJSArray;
  var
    V: string;
    Seen: TJSSet;
    M: TJSArray;
  begin
    V := Box.value;
    Seen := TJSSet.new;
    FileRef.lastIndex := 0;
    M := TJSArray(FileRef.execFull(V));
    while M <> nil do
    begin
      Seen.add(TJSString(TJSString(string(M[1])).trim).replace(TJSRegexp.new(' ', 'g'), '_'));
      M := TJSArray(FileRef.execFull(V));
    end;
    PathRef.lastIndex := 0;
    M := TJSArray(PathRef.execFull(V));
    while M <> nil do
    begin
      try
        Seen.add(decodeURIComponent(string(M[1])));
      except
        Seen.add(M[1]);
      end;
      M := TJSArray(PathRef.execFull(V));
    end;
    Result := TJSArray.from(Seen);
  end;

  procedure PutImage(const Name: string);
  var
    A, B, After: NativeInt;
    V, Text, Lead: string;
  begin
    A := Box.selectionStart;
    B := Box.selectionEnd;
    V := Box.value;
    Text := '[[File:' + TJSString(Name).replace(TJSRegexp.new('_', 'g'), ' ') + ']]';
    // a picture on a line of its own unless the member is mid-sentence
    if (A = 0) or (V[A] = #10) then Lead := '' else Lead := #10#10;
    After := Length(Lead) + Length(Text);
    ReplaceSelect(A, B, Lead + Text, After, After);
  end;

  procedure Thumb(List: TJSHTMLElement; F: TJSObject);
  var
    B, Img, Cap: TJSHTMLElement;
  begin
    B := ElClass('button', 'wikiimg');
    TJSHTMLButtonElement(B)._type := 'button';
    B.title := TWith('Put %s in the page', F['name']);
    Img := El('img');
    // Web's image element has no loading property.
    TJSObject(Img)['loading'] := 'lazy';
    TJSHTMLImageElement(Img).alt := '';
    TJSObject(Img)['src'] := F['url'];
    Cap := ElText('span', '', TJSString(F['name']).replace(TJSRegexp.new('_', 'g'), ' '));
    B.append(Img, Cap);
    B.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        ClosePop();
        PutImage(string(F['name']));
      end));
    List.appendChild(B);
  end;

  procedure Thumbs(List: TJSHTMLElement; Files: TJSArray; const Empty: string);
  var
    I: integer;
  begin
    List.replaceChildren;
    if not Truthy(TJSObject(Files)['length']) then
    begin
      List.appendChild(ElText('p', 'fine', Empty));
      Exit;
    end;
    for I := 0 to Files.length - 1 do Thumb(List, TJSObject(Files[I]));
  end;

  function Files(const Query: string): JSValue; async;
  var
    R: TJSResponse;
  begin
    R := await(TJSResponse, window.fetch('/api/wiki/files?' + Query));
    if not R.ok then raise TJSError.new(String(JSValue(R.status)));
    Result := R.json;
  end;

  procedure ImagePanel(Button: TJSElement);
  var
    Card, Head, Pick, OnPage, PageList, Lib, LibHead, LibList, All: TJSHTMLElement;
    Find: TJSHTMLInputElement;
    Names: TJSArray;
    Timer: NativeInt;

    procedure Failed(List: TJSHTMLElement);
    begin
      List.replaceChildren(ElText('p', 'fine', T('The list could not be loaded.')));
    end;

    procedure Load(const Q: string);
    var
      Query: string;
    begin
      if Q <> '' then LibHead.textContent := T('Found') else LibHead.textContent := T('Newest in the wiki');
      Query := 'limit=24';
      if Q <> '' then Query := Query + '&q=' + encodeURIComponent(Q);
      TJSPromise(Files(Query))._then(function(Found: JSValue): JSValue
        var
          Rows: TJSArray;
        begin
          if Truthy(Found) then Rows := TJSArray(Found) else Rows := TJSArray.new;
          if Q <> '' then Thumbs(LibList, Rows, T('No image has that name.')) else Thumbs(LibList, Rows, T('No images yet.'));
        end).catch(function(Why: JSValue): JSValue
        begin
          Failed(LibList);
        end);
    end;

  begin
    Card := Pop(Button);
    Card.classList.add('wikitools-images');
    Head := ElClass('div', 'wikiimg-head');
    Pick := ElText('button', 'wikiimg-upload', T('Upload images'));
    TJSHTMLButtonElement(Pick)._type := 'button';
    Pick.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        ClosePop();
        Ed.choose;
      end));
    Find := TJSHTMLInputElement(El('input'));
    Find._type := 'search';
    Find.placeholder := T('Find an image');
    Find.setAttribute('aria-label', T('Find an image'));
    Head.append(Find, Pick);
    OnPage := El('section');
    OnPage.appendChild(ElText('h3', '', T('On this page')));
    PageList := ElClass('div', 'wikiimg-list');
    OnPage.appendChild(PageList);
    Lib := El('section');
    LibHead := ElText('h3', '', T('Newest in the wiki'));
    LibList := ElClass('div', 'wikiimg-list');
    Lib.append(LibHead, LibList);
    All := ElText('a', 'wikiimg-all', T('All images'));
    TJSHTMLAnchorElement(All).href := '/wiki-files';
    TJSHTMLAnchorElement(All).target := '_blank';
    Card.append(Head, OnPage, Lib, ElText('p', 'fine wikiimg-tip', T('You can also drag pictures onto the text, or paste a screenshot.')), All);
    Find.focus;
    Names := UsedNames;
    if Names.length > 0 then
    begin
      PageList.appendChild(ElText('p', 'fine', T('Loading…')));
      TJSPromise(Files('names=' + encodeURIComponent(Names.join('|'))))._then(function(Found: JSValue): JSValue
        var
          Known: TJSMap;
          Rows, Shown: TJSArray;
          I: integer;
          F: JSValue;
        begin
          // a picture the server does not know is still shown, by its name
          if Truthy(Found) then Rows := TJSArray(Found) else Rows := TJSArray.new;
          Known := TJSMap.new;
          for I := 0 to Rows.length - 1 do Known.&set(TJSObject(Rows[I])['name'], Rows[I]);
          Shown := TJSArray.new;
          for I := 0 to Names.length - 1 do
          begin
            F := Known.get(Names[I]);
            if not Truthy(F) then F := new(['name', Names[I], 'url', '']);
            Shown.push(F);
          end;
          Thumbs(PageList, Shown, '');
        end).catch(function(Why: JSValue): JSValue
        begin
          Failed(PageList);
        end);
    end
    else Thumbs(PageList, TJSArray.new, T('This page has no pictures yet.'));
    Timer := 0;
    Find.addEventListener('input', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        window.clearTimeout(Timer);
        Timer := window.setTimeout(procedure begin Load(TJSString(Find.value).trim); end, 250);
      end));
    Load('');
  end;

  // ---- uploading: the editor shows a line for each picture on its way;
  // this sends one and answers what to write in its place

  function Send(F: TJSBlob; const Name: string; Again: JSValue): JSValue; async;
  var
    Body: TUpload;
    R: TJSResponse;
    Text, Shown: string;
    Answer: TJSObject;
    Other: JSValue;
  begin
    Body := TUpload.new;
    Body.append('file', F, Name);
    Body.append('name', Name);
    R := await(TJSResponse, window.fetch('/api/wiki/upload', new(['method', 'POST', 'body', Body])));
    // a refusal comes as a sentence, an answer as JSON
    Text := await(string, R.text);
    try
      Answer := TJSObject(TJSJSON.parse(Text));
    except
      Answer := new(['error', TJSString(TJSString(Text).trim).slice(0, 200)]);
    end;
    // another picture has that name already: keep both
    if (R.status = 409) and Truthy(Answer['conflict']) and not Identical(Again, True) then
    begin
      Other := Answer['suggested'];
      if not Truthy(Other) then Other := Name;
      Exit(Send(F, string(Other), True));
    end;
    if not R.ok then
    begin
      if Truthy(Answer['error']) then raise TJSError.new(string(Answer['error']));
      if R.status = 413 then raise TJSError.new(T('That picture is too big.'));
      raise TJSError.new(T('The picture could not be uploaded.'));
    end;
    Shown := TJSString(Answer['name']).replace(TJSRegexp.new('_', 'g'), ' ');
    Result := new(['put', '[[File:' + Shown + ']]', 'words', TWith('%s is uploaded.', Shown)]);
  end;

  function Preview(const Text: string; Signal: JSValue): JSValue; async;
  var
    R: TJSResponse;
  begin
    R := await(TJSResponse, window.fetch('/api/wiki/preview', new(['method', 'POST', 'body', TParams.new(new(['body', Text])), 'signal', Signal])));
    if not R.ok then raise TJSError.new(await(string, R.text));
    Result := await(TJSObject, R.json)['html'];
  end;

  procedure LinkTools(Editor: TEditor);
  begin
    Editor.tool(T('Link to a wiki page'), '', '[[ ]]', @FindPage);
    Editor.tool(T('Image'), '', Editor.svg('<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="10" r="1.8"/><path d="M21 16l-5-5-9 9"/>'), @ImagePanel)
      .setAttribute('aria-haspopup', 'dialog');
  end;

  // the wiki's emoji set, with the site's own pictures, then the names
  // every part knows: a keyword of the wiki's keeps the wiki's emoji
  function Emoji: JSValue; async;
  var
    R: TJSResponse;
    List: JSValue;
  begin
    R := await(TJSResponse, window.fetch('/api/wiki/emoji'));
    if R.ok then List := await(JSValue, R.json) else List := TJSArray.new;
    Result := EmojiNames.after(List);
  end;

begin
  Form := document.querySelector('form.wikiedit');
  if (Form = nil) or not Truthy(TJSObject(window)['Editor']) then Exit;
  Box := TJSHTMLTextAreaElement(Form.querySelector('textarea[name="body"]'));
  if Box = nil then Exit;
  Say := TJSObject(window)['t'];
  if not Truthy(Say) then Say := JSValue(TWords(function(const English: string): string begin Result := English; end));
  T := TWords(Say);
  TWith := TWordsWith(Say);

  // what changed, Save and Cancel go in one row under the editor
  Summary := Form.querySelector('input[name="summary"]');
  Actions := Form.querySelector('button[type="submit"]:not([name])');
  // the plain form's own words say the same as the help: hide them here
  Fine := Form.querySelector(':scope > p.fine');
  if Fine <> nil then TJSHTMLElement(Fine).hidden := True;
  RowSummary := nil;
  if Summary <> nil then RowSummary := Summary.closest('label');
  RowActions := nil;
  if (Actions <> nil) and (Actions.parentElement <> Form) then RowActions := Actions.parentElement;

  Ed := EditorKit.attach(Box, new([
    'storeKey', 'wiki-edit-mode',
    'heads', '.wikibody h1, .wikibody h2, .wikibody h3, .wikibody h4, .wikibody h5, .wikibody h6',
    'hint', T('Markdown and [[wiki links]]. Drag, paste or'),
    'emptyWords', T('The page shows here as you write.'),
    'helpLink', new(['href', '/wiki-help', 'words', T('Everything you can write here')]),
    'sendRow', TJSArray.new(RowSummary, RowActions),
    'cheats', TJSArray.new(
      TJSArray.new('[[Page Name]]  [[Page Name|' + T('words') + ']]', T('a link to a wiki page')),
      TJSArray.new('[[File:Name.png]]', T('a picture; add |thumb|300px|caption for a small framed one')),
      TJSArray.new('Category:Name', T('on a line at the end: puts the page in a category')),
      TJSArray.new('#REDIRECT [[Other Page]]', T('as the first line: sends readers to another page'))),
    'preview', @Preview,
    'linkTools', @LinkTools,
    'pictures', new(['accept', 'image/png,image/jpeg,image/gif,image/webp', 'types', TJSRegexp.new('^image\/(png|jpeg|gif|webp)$'), 'send', @Send]),
    'emoji', @Emoji]));
  El := TMake(Ed['el']);
  ElClass := TMakeClass(Ed['el']);
  ElText := TMakeText(Ed['el']);
  Replace := TReplace(Ed['replace']);
  ReplaceSelect := TReplaceSelect(Ed['replace']);
  ClosePop := TClosePop(Ed['closePop']);
  FileRef := TJSRegexp.new('\[\[\s*:?\s*(?:File|Image)\s*:\s*([^|\]]+)', 'gi');
  PathRef := TJSRegexp.new('\]\(\/wiki-images\/[0-9a-f]\/[0-9a-f]{2}\/([^)\s]+)\)', 'g');

  // the form's own Preview button reloads the page; the live preview does its work
  Reload := Form.querySelector('button[name="preview"]');
  if Reload <> nil then TJSHTMLElement(Reload).hidden := True;
end;

initialization
  Start;
end.
