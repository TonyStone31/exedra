unit ForumPage;

{ Forms on the server-rendered forum pages. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

implementation

uses JS, Web, PageKit, PageGlobals;

type
  // pas2js Web declares only the string URLSearchParams constructor.
  TParams = class external name 'URLSearchParams'(TJSURLSearchParams)
    constructor new(Data: TJSObject);
  end;
  // Web omits replaceWith and focus(options).
  TPageElement = class external name 'HTMLElement'(TJSHTMLElement)
    procedure replaceWith(Node: TJSNode);
    procedure focus(Options: TJSObject); overload;
  end;
  // Web's FormData omits the file name argument of append.
  TFileForm = class external name 'FormData'(TJSFormData)
    procedure append(const Name: string; Blob: TJSBlob; const FileName: string); overload;
  end;
  // Web's Event takes its options as a record, which carries more than was set.
  TPlainEvent = class external name 'Event'(TJSEvent)
    constructor new(const Kind: string; Options: TJSObject);
  end;
  // Web's Range omits getBoundingClientRect.
  TPlacedRange = class external name 'Range'(TJSRange)
    function getBoundingClientRect: TJSDOMRect;
  end;
  // js.pas types the result of String.repeat as Integer.
  TText = class external name 'String'(TJSString)
    function times(Count: double): string; external name 'repeat';
  end;
  // The scripts beside this one, as the page publishes them.
  TForumSide = class external name 'Object'(TJSObject)
    function iconButton(const Name, Title, Cls: string): TJSHTMLElement;
  end;
  TForumReactions = class external name 'Object'(TJSObject)
    function chips(List: TJSArray; Opts: TJSObject): TJSHTMLElement;
    procedure choose(Anchor: TJSHTMLElement; Lists: TJSObject; Pick: JSValue);
  end;
  TForumEmoji = class external name 'Object'(TJSObject)
    function list: JSValue;
  end;
  TForumEditor = class external name 'Object'(TJSObject)
    function attach(Box: TJSHTMLElement; Options: TJSObject): TJSObject;
  end;
  // What the editor hands to linkTools.
  TEditorTools = class external name 'Object'(TJSObject)
    choose: JSValue;
    procedure tool(const Title, Key: string; Icon, Work: JSValue);
    function svg(const Inner: string): JSValue;
  end;

var
  IconSide: TForumSide; external name 'window.Side';
  Reactions: TForumReactions; external name 'window.Reactions';
  EmojiNames: TForumEmoji; external name 'window.EmojiNames';
  Editor: TForumEditor; external name 'window.Editor';

function Number(Value: JSValue): double; external name 'Number';
function Max(A, B: double): double; external name 'Math.max';
function Min(A, B: double): double; external name 'Math.min';
// pas2js Web requires a reload argument; the browser permits none.
procedure Reload; external name 'window.location.reload';

function TextOr(Value: JSValue; const Fallback: string): string;
begin
  if Truthy(Value) then Result := string(Value) else Result := Fallback;
end;

function Post(const Path: string; Fields: JSValue): JSValue; async;
var
  Response: TJSResponse;
begin
  Response := await(PageKit.Post(Path, Fields));
  if not Response.ok then raise TJSError.new(TextOr(await(string, Response.text), T('Could not save the forum.')));
  Result := await(JSValue, Response.json);
end;

function TopicAddress(Id, Page, PostId: JSValue): string;
begin
  Result := '/forum/t/' + String(JSValue(Number(Id)));
  if Number(Page) > 1 then Result := Result + '?page=' + String(JSValue(Number(Page)));
  if Truthy(PostId) then Result := Result + '#post-' + String(JSValue(Number(PostId)));
end;

procedure CodeBlock(Block: TJSElement);
var
  Copy, Flip: TJSHTMLElement;

  procedure CopyCode(E: TJSEvent); async;
  begin
    try
      await(JSValue, window.navigator.clipboard.writeText(Block.querySelector('pre code').textContent));
      Copy.textContent := T('Copied');
    except
      window.alert(T('Could not copy the code.'));
    end;
  end;

begin
  Copy := TJSHTMLElement(Block.querySelector('.copy'));
  if Copy <> nil then
  begin
    Copy.dataset['forumCode'] := '1';
    Copy.textContent := T('Copy');
    Copy.addEventListener('click', TJSRawEventHandler(@CopyCode));
  end;
  Flip := TJSHTMLElement(Block.querySelector('.flip'));
  if Flip <> nil then
  begin
    Flip.dataset['forumCode'] := '1';
    Flip.textContent := T('Source');
    Flip.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        if Block.classList.toggle('source') then Flip.textContent := T('Document') else Flip.textContent := T('Source');
      end));
  end;
end;

// Box is the page or a part of it.
procedure CodeButtons(Box: TJSNode);
var
  Blocks: TJSNodeList;
  I: NativeInt;
begin
  Blocks := TJSElement(Box).querySelectorAll('.code');
  for I := 0 to Blocks.length - 1 do CodeBlock(TJSElement(Blocks[I]));
end;

// Files in a post: the page says the largest size and the kinds the
// admin accepts; the forum keeps the file and the post names it.
function FileRules(Textarea: TJSHTMLElement): TJSObject;
var
  Kinds: TJSArray;
  Most: double;
  Gallery: string;

  function Refuses(AFile: TJSObject): string;
  var
    Found: TJSObject;
    Kind: string;
  begin
    Found := TJSRegexp.new('\.([A-Za-z0-9]+)$').execFull(TextOr(AFile['name'], ''));
    if Found <> nil then Kind := TJSString(Found['1']).toLowerCase else Kind := '';
    // a pasted screenshot has no name of its own; it is a picture
    if (Kind = '') and TJSRegexp.new('^image\/(png|jpeg|gif|webp)$').test(string(AFile['type'])) then Exit('');
    if Kinds.indexOf(Kind) < 0 then Exit(T('%s is not a kind of file accepted here.', TextOr(AFile['name'], '')));
    if Number(AFile['size']) > Most * 1024 * 1024 then
      Exit(T('%s is too big: files can be %d MB at most here.', TextOr(AFile['name'], ''), Most));
    Result := '';
  end;

  function Send(AFile: TJSBlob; const Name: string): JSValue; async;
  var
    Body: TFileForm;
    Response: TJSResponse;
    Answer: TJSObject;
    Words, Address, Mark: string;
  begin
    Body := TFileForm.new;
    Body.append('file', AFile, Name);
    Response := await(PageKit.Post('/api/forum/upload', Body));
    if not Response.ok then
      raise TJSError.new(TextOr(TJSString(TJSString(await(string, Response.text)).trim).slice(0, 200), T('The file could not be uploaded.')));
    Answer := await(TJSObject, Response.json);
    Words := TJSString(Answer['name']).replace(TJSRegexp.new('[\[\]]', 'g'), '');
    // a blank or a parenthesis in the name would end the link early
    Address := TJSString(TJSString(TJSString(Answer['url']).replace(TJSRegexp.new(' ', 'g'), '%20')).replace(TJSRegexp.new('\(', 'g'), '%28')).replace(
      TJSRegexp.new('\)', 'g'), '%29');
    if Truthy(Answer['image']) then Mark := '!' else Mark := '';
    Result := new(['put', Mark + '[' + Words + '](' + Address + ')', 'words', T('%s is uploaded.', Answer['name'])]);
  end;

begin
  Kinds := TJSArray(TJSString(TextOr(TJSObject(Textarea.dataset)['uploadTypes'], '')).split(' ')).filter(TJSArrayCallBack(@Truthy));
  Most := Number(TextOr(TJSObject(Textarea.dataset)['uploadMb'], '0'));
  if (Kinds.length = 0) or not Truthy(Most) then Exit(nil);
  Gallery := 'image/*';
  if Kinds.some(function(K: JSValue; I: NativeInt; A: TJSArray): boolean
    begin Result := TJSRegexp.new('^(mp4|webm|mov|m4v)$').test(string(K)); end) then Gallery := Gallery + ',video/*';
  Result := new([
    'accept', Kinds.map(function(K: JSValue; I: NativeInt; A: TJSArray): JSValue begin Result := '.' + string(K); end).join(','),
    'gallery', Gallery,
    'label', T('add files'),
    'refuses', @Refuses,
    'send', @Send]);
end;

procedure FileTool(Made: TEditorTools);
begin
  Made.tool(T('Add a file'), '', Made.svg(
    '<path d="M20 11.5l-8.2 8.2a5 5 0 0 1-7-7l8.5-8.6a3.4 3.4 0 0 1 4.8 4.8l-8.4 8.5a1.7 1.7 0 0 1-2.4-2.4l7.7-7.8"/>'), Made.choose);
end;

// The post box gets the shared editor (editor.js): its toolbar, and the
// post as it will look from the forum's own renderer.
procedure AttachEditor(Textarea: TJSHTMLElement);
var
  Form: TJSElement;
  Files: TJSObject;
  Hint, LinkTools: JSValue;

  function Preview(const Text: string; Signal: JSValue): JSValue; async;
  var
    Fields: TParams;
    Response: TJSResponse;
  begin
    Fields := TParams.new(TJSFormData.new(TJSHTMLFormElement(Form)));
    Fields.set_('body', Text);
    Response := await(TJSResponse, window.fetch('/api/forum/preview',
      new(['method', 'POST', 'body', Fields, 'credentials', 'same-origin', 'signal', Signal])));
    if not Response.ok then raise TJSError.new(await(string, Response.text));
    Result := await(TJSObject, Response.json)['html'];
  end;

  // emoji by name, as in the chat: :thu offers 👍
  function Emoji: JSValue;
  begin
    Result := EmojiNames.list;
  end;

begin
  if not Truthy(TJSObject(window)['Editor']) then Exit;
  Form := Textarea.closest('form');
  Files := FileRules(Textarea);
  Hint := undefined;
  LinkTools := undefined;
  if Files <> nil then
  begin
    Hint := T('Markdown. Drag, paste or');
    LinkTools := @FileTool;
  end;
  Editor.attach(Textarea, new([
    'compact', True,
    'mode', 'write',
    'storeKey', 'forum-edit-mode',
    'viewClass', 'forum-body body',
    'emptyWords', T('The post shows here as you write.'),
    'preview', @Preview,
    'afterPreview', @CodeButtons,
    'emoji', @Emoji,
    // the button that sends the form and its error stay in view full screen too
    'sendRow', TJSArray._of(Form.querySelector(':scope > button'), Form.querySelector(':scope > .forum-error')),
    'hint', Hint,
    'linkTools', LinkTools,
    'pictures', Files]));
end;

procedure ForumForm(Form: TJSHTMLFormElement);

  procedure Submit(Event: TJSEvent); async;
  var
    Path, Target: string;
    Fields: TParams;
    Error: TJSElement;
    Buttons, Boxes: TJSNodeList;
    Data: TJSObject;
    Page: JSValue;
    Made: TJSObject;
    Same: boolean;
    Thanks: TJSElement;
    I: NativeInt;
  begin
    Event.preventDefault;
    if Truthy(TJSObject(Form.dataset)['busy']) then Exit;
    Path := SiteBase.strip(Form.getAttribute('action'));
    if Truthy(TJSObject(Form.dataset)['confirm']) and not window.confirm(Form.dataset['confirm']) then Exit;
    Fields := TParams.new(TJSFormData.new(Form));
    Error := Form.querySelector('.forum-error');
    Buttons := Form.querySelectorAll('button');
    Error.textContent := '';
    Form.dataset['busy'] := '1';
    for I := 0 to Buttons.length - 1 do TJSHTMLButtonElement(Buttons[I]).disabled := True;
    try
      try
        Data := TJSObject(await(Post(Path, Fields)));
        if Truthy(Data['topic_id']) then
        begin
          if Truthy(Data['page']) then Page := Data['page'] else Page := 1;
          Target := SiteBase.url(TopicAddress(Data['topic_id'], Page, Data['post_id']));
          // the same page with another anchor is only a jump: read it again for the new post
          Same := TJSString(Target).split('#')[0] = window.location.pathname + window.location.search;
          window.location.assign(Target);
          if Same then Reload;
        end
        else if Truthy(Data['topic_deleted']) then window.location.assign(SiteBase.url('/forum'))
        else if Truthy(Data['reported']) then
        begin
          // the page stays as it is; the form gives way to a word of thanks
          Thanks := document.createElement('p');
          Thanks.textContent := T('Reported. The moderators will take a look.');
          TPageElement(TJSHTMLElement(Form)).replaceWith(Thanks);
        end
        else Reload;
      except
        TJSObject(Error)['textContent'] := TJSObject(JSExceptValue)['message'];
        // the text is still unsaved: the editor goes on warning before the page is left
        Boxes := Form.querySelectorAll('textarea');
        for I := 0 to Boxes.length - 1 do
        begin
          Made := TJSObject(TJSObject(Boxes[I])['editor']);
          if Truthy(Made) and Truthy(Made['notSaved']) then TJSFunction(Made['notSaved']).call(Made);
        end;
      end;
    finally
      jsDelete(Form.dataset, 'busy');
      for I := 0 to Buttons.length - 1 do TJSHTMLButtonElement(Buttons[I]).disabled := False;
    end;
  end;

begin
  Form.addEventListener('submit', TJSRawEventHandler(@Submit));
end;

function QuoteLines(const Text: string): string;
begin
  Result := TJSArray(TJSString(Text).split(#10)).map(function(Line: JSValue; I: NativeInt; A: TJSArray): JSValue
    begin Result := '> ' + string(Line); end).join(#10);
end;

function QuoteMarkdown(Author, Topic, PostId, Body: JSValue): string;
var
  Name, Number_: string;
begin
  // Names are literal Markdown, including brackets and formatting characters.
  Name := TJSString(Author).replace(TJSRegexp.new('([\\`*_[\]<>])', 'g'), '\$1');
  Number_ := String(JSValue(Number(PostId)));
  Result := '> **' + Name + '** ' + T('wrote') + ' ([' + T('post') + '](/forum/t/' + String(JSValue(Number(Topic))) + '?post=' + Number_ +
    '#post-' + Number_ + ')):'#10 + QuoteLines(TJSString(Body).replace(TJSRegexp.new('\r\n?', 'g'), #10)) + #10#10;
end;

procedure AddQuote(Author, Topic, PostId, Text: JSValue);
var
  Reply: TJSHTMLElement;
  Textarea: TJSHTMLTextAreaElement;
  Gap: string;
begin
  Reply := TJSHTMLElement(document.querySelector('#quick-reply'));
  if Reply = nil then Exit;
  Textarea := TJSHTMLTextAreaElement(Reply.querySelector('.forum-editor'));
  if Textarea.value <> '' then Gap := #10#10 else Gap := '';
  Textarea.value := Textarea.value + Gap + QuoteMarkdown(Author, Topic, PostId, Text);
  // the editor hears of the new text as it would of typing
  Textarea.dispatchEvent(TPlainEvent.new('input', new(['bubbles', True])));
  Textarea.focus;
  Reply.scrollIntoView(new(['block', 'start']));
end;

procedure QuoteButton(Button: TJSHTMLElement);
begin
  Button.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Said: TJSObject;
    begin
      Said := Button.dataset;
      AddQuote(Said['author'], Said['topic'], Said['post'], Said['body']);
    end));
end;

// The Markdown of a drawn piece of a post, so that what is quoted keeps
// its code blocks (with their language), pictures, links and emphasis.
function MarkdownOf(Node: TJSNode; InCode: boolean): string;
var
  El, Lang, Pre: TJSElement;
  Tag, Mark: string;
  Cells: TJSArray;
  I: NativeInt;

  function Kids(Code: boolean): string;
  var
    K: NativeInt;
  begin
    Result := '';
    for K := 0 to Node.childNodes.length - 1 do Result := Result + MarkdownOf(Node.childNodes[K], Code);
  end;

  function Fence(const Language, Text: string): string;
  begin
    Result := #10#10'```' + Language + #10 + TJSString(Text).replace(TJSRegexp.new('\n+$'), '') + #10'```'#10#10;
  end;

begin
  if Node.nodeType = 3 then
  begin
    if InCode then Exit(Node.nodeValue);
    Exit(TJSString(Node.nodeValue).replace(TJSRegexp.new('\s+', 'g'), ' '));
  end;
  if (Node.nodeType <> 1) and (Node.nodeType <> 11) then Exit('');
  if Node.nodeType = 11 then Exit(Kids(InCode));
  El := TJSElement(Node);
  Tag := El.tagName;
  if El.classList.contains('code') then
  begin
    Lang := El.querySelector('.codebar span');
    Pre := El.querySelector('pre');
    if Pre = nil then Exit('');
    if Lang <> nil then Exit(Fence(TJSString(Lang.textContent).trim, Pre.textContent));
    Exit(Fence('', Pre.textContent));
  end;
  if El.classList.contains('codebar') or (Tag = 'BUTTON') then Exit('');
  if Tag = 'PRE' then Exit(Fence('', El.textContent));
  if Tag = 'IMG' then Exit('![' + TextOr(El.getAttribute('alt'), '') + '](' + SiteBase.strip(TextOr(El.getAttribute('src'), '')) + ')');
  if Tag = 'A' then Exit('[' + Kids(False) + '](' + SiteBase.strip(TextOr(El.getAttribute('href'), '')) + ')');
  if (Tag = 'B') or (Tag = 'STRONG') then Exit('**' + Kids(False) + '**');
  if (Tag = 'I') or (Tag = 'EM') then Exit('*' + Kids(False) + '*');
  if (Tag = 'DEL') or (Tag = 'S') then Exit('~~' + Kids(False) + '~~');
  if Tag = 'CODE' then Exit('`' + El.textContent + '`');
  if Tag = 'BR' then Exit(#10);
  if TJSRegexp.new('^H[1-6]$').test(Tag) then
    Exit(#10#10 + TText('#').times(Number(TJSString(Tag).charAt(1))) + ' ' + Kids(False) + #10#10);
  if Tag = 'LI' then
  begin
    if (El.parentElement <> nil) and (El.parentElement.tagName = 'OL') then Mark := '1. ' else Mark := '- ';
    Exit(Mark + TJSString(Kids(False)).trim + #10);
  end;
  if (Tag = 'UL') or (Tag = 'OL') then Exit(#10#10 + Kids(False) + #10);
  if Tag = 'BLOCKQUOTE' then Exit(#10#10 + QuoteLines(TJSString(Kids(False)).trim) + #10#10);
  if Tag = 'TR' then
  begin
    Cells := TJSArray.new;
    for I := 0 to El.children.length - 1 do Cells.push(TJSString(MarkdownOf(El.children[I], False)).trim);
    Exit('| ' + Cells.join(' | ') + ' |'#10);
  end;
  if Tag = 'THEAD' then Exit(Kids(False) + '|' + TText('---|').times(El.querySelectorAll('th').length) + #10);
  if Tag = 'TABLE' then Exit(#10#10 + Kids(False) + #10);
  if (Tag = 'P') or (Tag = 'DIV') then Exit(#10#10 + Kids(False) + #10#10);
  Result := Kids(InCode);
end;

// What a selection holds, as Markdown.  A selection inside one code block
// is that part of the code, fenced with the block's language.
function SelectionMarkdown(Range: TJSRange): string;
var
  From: TJSNode;
  At, Block, Lang: TJSElement;
  Text, Line: string;
  Code: boolean;
  Lines: TJSArray;
  I: NativeInt;
begin
  From := Range.commonAncestorContainer;
  if From.nodeType = 1 then At := TJSElement(From) else At := From.parentElement;
  if At <> nil then Block := At.closest('.code') else Block := nil;
  if (Block <> nil) and (At.closest('pre') <> nil) then
  begin
    Lang := Block.querySelector('.codebar span');
    Text := TJSString(Range.toString).replace(TJSRegexp.new('\n+$'), '');
    if TJSString(Text).trim = '' then Exit('');
    if Lang <> nil then Exit('```' + TJSString(Lang.textContent).trim + #10 + Text + #10'```');
    Exit('```'#10 + Text + #10'```');
  end;
  // spaces left between the blocks go; lines of code keep theirs
  Code := False;
  Lines := TJSArray(TJSString(MarkdownOf(Range.cloneContents, False)).split(#10));
  for I := 0 to Lines.length - 1 do
  begin
    Line := string(Lines[I]);
    if TJSRegexp.new('^\s*```').test(Line) then
    begin
      Code := not Code;
      Lines[I] := TJSString(Line).trim;
    end
    else if not Code then
      Lines[I] := TJSString(TJSString(Line).replace(TJSRegexp.new('\s+$'), '')).replace(TJSRegexp.new('^ (?=\S)'), '');
  end;
  Result := TJSString(TJSString(Lines.join(#10)).replace(TJSRegexp.new('\n{3,}', 'g'), #10#10)).trim;
end;

// Text selected inside one post brings up a button that quotes just those
// words in the reply.  Only where the reader may reply.
procedure QuoteSelection;
var
  Offer: TJSHTMLButtonElement;
  Picked: TJSObject;
  Later: NativeInt;

  // the text of a post a node sits in; not the editor's preview, which
  // is drawn the same way
  function BodyOf(Node: TJSNode): TJSElement;
  var
    At, Body: TJSElement;
  begin
    Result := nil;
    if not Truthy(Node) then Exit;
    if Node.nodeType = 1 then At := TJSElement(Node) else At := Node.parentElement;
    if At <> nil then Body := At.closest('.forum-body') else Body := nil;
    if (Body <> nil) and (Body.parentElement <> nil) and Body.parentElement.classList.contains('forum-post-content') then Result := Body;
  end;

  procedure Look;
  var
    Chosen: TJSSelection;
    Body: TJSElement;
    Text: string;
    Button: TJSHTMLElement;
    Box: TJSDOMRect;
  begin
    Offer.hidden := True;
    Picked := nil;
    Chosen := window.getSelection;
    if (Chosen = nil) or Chosen.isCollapsed or (Chosen.rangeCount = 0) then Exit;
    Body := BodyOf(Chosen.anchorNode);
    if Body <> nil then Text := SelectionMarkdown(Chosen.getRangeAt(0)) else Text := '';
    if (Text = '') or (Body = nil) or (Body <> BodyOf(Chosen.focusNode)) then Exit;
    Button := TJSHTMLElement(Body.closest('.forum-post').querySelector('.forum-quote'));
    if Button = nil then Exit;
    Picked := new(['author', Button.dataset['author'], 'topic', Button.dataset['topic'], 'post', Button.dataset['post'], 'text', Text]);
    Box := TPlacedRange(Chosen.getRangeAt(0)).getBoundingClientRect;
    Offer.hidden := False;
    Offer.style.setProperty('top', String(JSValue(window.scrollY + Box.bottom + 6)) + 'px');
    Offer.style.setProperty('left', String(JSValue(window.scrollX +
      Max(8, Min(Box.left, document.documentElement.clientWidth - Offer.offsetWidth - 8)))) + 'px');
  end;

  // after the browser has settled the selection; a phone has no mouseup
  procedure Soon(E: TJSEvent);
  begin
    window.clearTimeout(Later);
    Later := window.setTimeout(@Look, 150);
  end;

begin
  if not Truthy(document.querySelector('#quick-reply')) or not Truthy(document.body) or
    (jsTypeOf(TJSObject(window)['getSelection']) <> 'function') then Exit;
  Offer := TJSHTMLButtonElement(document.createElement('button'));
  Offer._type := 'button';
  Offer.className := 'forum-quote-selection';
  Offer.textContent := T('Quote selection');
  Offer.hidden := True;
  document.body.appendChild(Offer);
  Picked := nil;
  Later := 0;
  document.addEventListener('mouseup', TJSRawEventHandler(@Soon));
  document.addEventListener('keyup', TJSRawEventHandler(@Soon));
  document.addEventListener('selectionchange', TJSRawEventHandler(@Soon));
  // pressing the button must not drop the selection it is about
  Offer.addEventListener('mousedown', TJSRawEventHandler(procedure(E: TJSEvent) begin E.preventDefault; end));
  Offer.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      if Picked = nil then Exit;
      AddQuote(Picked['author'], Picked['topic'], Picked['post'], Picked['text']);
      window.getSelection.removeAllRanges;
      Offer.hidden := True;
    end));
end;

// Reactions under a post: each row the server drew is drawn again by reactions.js,
// which makes its chips work.  A row marked data-add ends in the button that offers more.
procedure PostReactions;
var
  Offered: TJSHTMLElement;
  Lists: TJSObject;
  Rows: TJSNodeList;
  I: NativeInt;

  function Words(Text: JSValue): TJSArray;
  begin
    Result := TJSArray(TJSString(Text).split(' ')).filter(TJSArrayCallBack(@Truthy));
  end;

  procedure Draw(Row: TJSHTMLElement; List: TJSArray);
  var
    Id: JSValue;
    Add, Here: boolean;
    Fresh, More: TJSHTMLElement;

    procedure React(Emoji: JSValue); async;
    begin
      try
        Draw(Fresh, TJSArray(TJSObject(await(Post('/api/forum/react', TParams.new(new(['post', Id, 'r', Emoji])))))['reactions']));
      except
        window.alert(string(TJSObject(JSExceptValue)['message']));
      end;
    end;

    // where nothing may be added, one's own still comes off
    procedure Toggle(R: TJSObject);
    begin
      if Add or ((Lists <> nil) and Truthy(R['mine'])) then React(R['r']);
    end;

    function Who(R: TJSObject): JSValue; async;
    var
      Response: TJSResponse;
    begin
      Response := await(Get('/api/forum/reacted?post=' + string(Id) + '&r=' + encodeURIComponent(string(R['r']))));
      if not Response.ok then raise TJSError.new(await(string, Response.text));
      Result := await(JSValue, Response.json);
    end;

  begin
    Id := TJSObject(Row.dataset)['post'];
    Add := (Lists <> nil) and jsIn('add', Row.dataset);
    Fresh := Reactions.chips(List, new(['toggle', @Toggle, 'who', @Who]));
    TJSObject.assign(Fresh.dataset, Row.dataset);
    if Add and (TJSArray(Lists['shown']).length + TJSArray(Lists['more']).length > 0) then
    begin
      More := IconSide.iconButton('react', T('Add a reaction'), 'forum-react-add');
      More.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Reactions.choose(More, Lists, @React); end));
      Fresh.appendChild(More);
    end;
    Here := Row.contains(document.activeElement);
    TPageElement(Row).replaceWith(Fresh);
    if Here and (Fresh.lastElementChild <> nil) then TPageElement(Fresh.lastElementChild).focus(new(['preventScroll', True]));
  end;

  function Drawn(Row: TJSHTMLElement): TJSArray;
  begin
    Result := TJSArray.from(Row.children).map(function(Chip: JSValue; N: NativeInt; A: TJSArray): JSValue
      begin
        Result := new(['r', TJSObject(TJSHTMLElement(Chip).dataset)['r'], 'n', Number(TJSObject(TJSHTMLElement(Chip).dataset)['n']),
          'mine', TJSHTMLElement(Chip).classList.contains('mine')]);
      end);
  end;

begin
  Offered := TJSHTMLElement(document.getElementById('forum-reactions'));
  if Offered <> nil then
    Lists := new(['shown', Words(TJSObject(Offered.dataset)['shown']), 'more', Words(TJSObject(Offered.dataset)['more'])])
  else
    Lists := nil;
  Rows := document.querySelectorAll('.forum-post .reacts');
  for I := 0 to Rows.length - 1 do Draw(TJSHTMLElement(Rows[I]), Drawn(TJSHTMLElement(Rows[I])));
end;

procedure NewTopicLink(Anchor: TJSNode);
begin
  Anchor.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      TJSObject(document.querySelector('#new-topic'))['open'] := True;
    end));
end;

procedure PanelButton(Button: TJSHTMLElement);
begin
  Button.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Panel, Field: TJSHTMLElement;
      Opening: boolean;
      Content: TJSElement;
      Others: TJSNodeList;
      I: NativeInt;
    begin
      Panel := TJSHTMLElement(document.getElementById(Button.dataset['forumPanel']));
      Opening := Panel.hidden;
      Content := Button.closest('.forum-post-content');
      Others := Content.querySelectorAll('.forum-action-panel');
      for I := 0 to Others.length - 1 do TJSHTMLElement(Others[I]).hidden := True;
      Others := Content.querySelectorAll('[data-forum-panel]');
      for I := 0 to Others.length - 1 do TJSElement(Others[I]).setAttribute('aria-expanded', 'false');
      Panel.hidden := not Opening;
      Button.setAttribute('aria-expanded', String(JSValue(Opening)));
      if Opening then
      begin
        Field := TJSHTMLElement(Panel.querySelector('textarea, input:not([type=hidden]), button'));
        if Field <> nil then Field.focus;
      end;
    end));
end;

// Who started the topic ticks the reply that solved it: the page comes
// again with the mark on it and on the topic.
procedure SolveBox(Box: TJSHTMLInputElement);

  procedure Changed(E: TJSEvent); async;
  var
    Response: TJSResponse;
    Mark: string;
  begin
    Box.disabled := True;
    try
      if Box.checked then Mark := '1' else Mark := '0';
      Response := await(PageKit.Post('/api/forum/solved', TParams.new(new(['post', TJSObject(Box.dataset)['forumSolve'], 'on', Mark]))));
      if not Response.ok then raise TJSError.new(TJSString(TJSString(await(string, Response.text)).trim).slice(0, 200));
      Reload;
    except
      Box.checked := not Box.checked;
      Box.disabled := False;
      window.alert(string(TJSObject(JSExceptValue)['message']));
    end;
  end;

begin
  Box.addEventListener('change', TJSRawEventHandler(@Changed));
end;

procedure Start;
var
  Nodes: TJSNodeList;
  I: NativeInt;
begin
  Nodes := document.querySelectorAll('form[data-forum-form]');
  for I := 0 to Nodes.length - 1 do ForumForm(TJSHTMLFormElement(Nodes[I]));
  Nodes := document.querySelectorAll('.forum-quote');
  for I := 0 to Nodes.length - 1 do QuoteButton(TJSHTMLElement(Nodes[I]));
  QuoteSelection;
  PostReactions;
  Nodes := document.querySelectorAll('[data-forum-new]');
  for I := 0 to Nodes.length - 1 do NewTopicLink(Nodes[I]);
  Nodes := document.querySelectorAll('[data-forum-panel]');
  for I := 0 to Nodes.length - 1 do PanelButton(TJSHTMLElement(Nodes[I]));
  // Back to a list the browser kept as it was: what was unread then may
  // have been read since, so the list is fetched again.
  window.addEventListener('pageshow', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      // Web's PageTransitionEvent omits persisted; the event's own property is read.
      if Truthy(TJSObject(E)['persisted']) and (document.querySelector('.forum-topics, .forum-boards') <> nil) then Reload;
    end));
  Nodes := document.querySelectorAll('input[data-forum-solve]');
  for I := 0 to Nodes.length - 1 do SolveBox(TJSHTMLInputElement(Nodes[I]));
  Nodes := document.querySelectorAll('.forum-editor');
  for I := 0 to Nodes.length - 1 do AttachEditor(TJSHTMLElement(Nodes[I]));
  CodeButtons(document);
  Nodes := document.querySelectorAll('[data-forum-tools]');
  for I := 0 to Nodes.length - 1 do TJSHTMLElement(Nodes[I]).hidden := False;
end;

initialization
  Start;
end.
