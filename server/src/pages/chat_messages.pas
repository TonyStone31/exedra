unit chat_messages;

{ One message as it is drawn: its head, words, files, reactions and link preview. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, chat_shared;

function RenderMessage(M: TMsg; InThread: boolean): TEl;
function RenderFiles(Files: TJSArray): TEl;
function RenderReactions(M: TMsg): TJSHTMLElement;
procedure React(Id, R: JSValue; Dm: boolean = False); async;
function PreviewOf(P: TJSObject): TEl;

implementation

uses chat_answer, chat_menu, chat_sync, chat_panels, chat_private;

type
  // A control's, picture's or link's own properties ([] on an element reads and writes attributes).
  TCtl = class external name 'HTMLElement'(TEl)
    &type: string;
    src: JSValue;
    alt: JSValue;
    loading: string;
    referrerPolicy: string;
    href: string;
    target: string;
    rel: string;
  end;
  // A file of a message.
  TFile = class external name 'Object'(TJSObject)
    image: boolean;
    once: boolean;
    url: JSValue;
    name: JSValue;
    size: JSValue;
    expires: JSValue;
  end;
  // What the first link of a message leads to.
  TPreview = class external name 'Object'(TJSObject)
    site: JSValue;
    url: string;
    title: JSValue;
    description: JSValue;
    image: JSValue;
  end;
  TBadge = reference to function(M: TMsg): JSValue;
  TOffer = reference to function: TJSObject;

// A very long message is folded to a screenful, with a button to read it all and fold it again.
procedure FoldLong(Text, Content: TEl);
begin
  window.requestAnimationFrame(procedure(Time: TJSDOMHighResTimeStamp)
    var
      Whole: TEl;
    begin
      if (Text.parentNode = nil) or (Text.scrollHeight <= 640) then Exit;
      Text.classList.add('folded');
      Whole := El('button', 'unfold whole', T('Show all'));
      TCtl(Whole).&type := 'button';
      Whole.setAttribute('aria-expanded', 'false');
      Whole.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
        var
          Open: boolean;
        begin
          Open := Text.classList.contains('folded');
          if Open then Text.classList.remove('folded') else Text.classList.add('folded');
          if Open then Whole.textContent := T('Show less') else Whole.textContent := T('Show all');
          Whole.setAttribute('aria-expanded', String(JSValue(Open)));
          if not Open then Text.scrollIntoView(TJSObject(New(['block', 'nearest'])));
        end));
      Content.insertBefore(Whole, Text.nextSibling);
    end);
end;

function RenderMessage(M: TMsg; InThread: boolean): TEl;
var
  Node, Gutter, More, Content, Head, Time, Text, Show, Line: TEl;
  A: TJSHTMLAnchorElement;
  At: TJSDate;
  Badge: TBadge;
  B: JSValue;
  I: NativeInt;
begin
  Node := El('article', 'msg');
  Node.dataset['id'] := String(JSValue(M.id));
  Node.dataset['at'] := M.at;
  Node.dataset['name'] := M.name;
  if not M.uid then Node.classList.add('system');
  if M.name = Me.name then Node.classList.add('mine');
  if M.mentions_me then Node.classList.add('mention');
  if M.deleted then Node.classList.add('deleted');
  if Truthy(M.replies) and not InThread then Node.classList.add('hasthread');

  Gutter := El('div', 'gutter');
  if M.uid then
  begin
    A := Link('/u/' + Enc(M.name), 'face');
    A.appendChild(Avatar(M.name, M.avatar));
    Gutter.appendChild(A);
  end
  else Gutter.appendChild(Avatar(M.name, '', 'bot'));
  At := TJSDate.new(M.at);
  if not M.deleted then
  begin
    More := IconButton('down', T('More'), 'more');
    More.setAttribute('aria-haspopup', 'menu');
    More.setAttribute('aria-expanded', 'false');
    More.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        if (Menu <> nil) and (Menu.node = Node) then CloseMenu(True)
        else OpenMenu(Node);
      end));
    Gutter.appendChild(More);
    Node.menu := TOffer(function: TJSObject begin Result := MessageMenu(M, InThread); end);
  end;
  Node.appendChild(Gutter);

  Content := El('div', 'content');
  Head := El('header');
  if M.uid then Head.appendChild(Link('/u/' + Enc(M.name), 'who', M.name))
  else Head.appendChild(El('b', 'who', M.name));
  if M.badge then Head.appendChild(El('span', 'role', M.badge));
  for I := 0 to Extras.badges.length - 1 do
  begin
    Badge := TBadge(Extras.badges[I]);
    B := Badge(M);
    if B then Head.appendChild(TJSNode(B));
  end;
  if (M.room <> S.room) and not InThread then Head.appendChild(Link('/p/' + Enc(M.room), 'where', '#' + M.room));
  Time := El('time', '', Clock(At));
  Time.title := DateTimeText(At);
  Head.appendChild(Time);
  if M.edited and not M.deleted then Head.appendChild(El('span', 'edited', T('(edited)')));
  if M.pinned then Head.appendChild(El('span', 'pinned', T('pinned')));
  Content.appendChild(Head);

  Text := El('div', 'body');
  if M.deleted then Text.textContent := T('This message was deleted.')
  else
  begin
    asm Text.innerHTML = M.html;   // safe html: rendered by the server, members' HTML escaped
    end;
    DressCode(Text);
  end;
  if Truthy(M.re) and not M.deleted then
    Content.appendChild(QuoteOf(M.re, procedure begin Route('/m/' + String(M.re['id']), True); end));
  Content.appendChild(Text);
  if not M.deleted then FoldLong(Text, Content);
  if Truthy(M.preview) and not M.deleted then Content.appendChild(PreviewOf(M.preview));
  // Someone the member ignores: folded, one click to read anyway.
  if M.ignored and not M.deleted then
  begin
    Node.classList.add('ignored');
    Show := El('button', 'unfold', T('A message from %s, whom you ignore. Show it', M.name));
    TCtl(Show).&type := 'button';
    Show.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        Node.classList.remove('ignored');
        Show.remove;
      end));
    Content.insertBefore(Show, Text);
  end;
  if Truthy(M.files) and Truthy(M.files.length) then Content.appendChild(RenderFiles(M.files));
  if Truthy(M.reactions) and Truthy(M.reactions.length) then Content.appendChild(RenderReactions(M));
  if Truthy(M.replies) and not InThread then
  begin
    Line := El('button', 'threadline');
    TCtl(Line).&type := 'button';
    Line.appendChild(Icon('reply'));
    Line.appendChild(El('b', '', TN(M.replies, '%d reply', '%d replies')));
    Line.appendChild(El('span', '', T('last %s', Ago(M.last_reply))));
    Line.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin OpenThread(M.id); end));
    Content.appendChild(Line);
  end;
  Node.appendChild(Content);
  C.pinWatch.observe(Node);   // its list keeps the bottom when this gets taller
  Result := Node;
end;

function RenderFiles(Files: TJSArray): TEl;
var
  Box: TEl;
  F: TFile;
  A: TJSHTMLAnchorElement;
  Img: TEl;
  I: NativeInt;
begin
  Box := El('div', 'files');
  for I := 0 to Files.length - 1 do
  begin
    F := TFile(Files[I]);
    if F.image then
    begin
      A := Link(F.url, 'shot');
      Img := El('img');
      TCtl(Img).src := F.url;
      TCtl(Img).alt := F.name;
      TCtl(Img).loading := 'lazy';
      A.appendChild(Img);
      Box.appendChild(A);
    end
    else
    begin
      A := Link(F.url, 'file');
      A.appendChild(Icon('attach'));
      A.appendChild(El('span', 'fname', F.name));
      A.appendChild(El('span', 'fsize', SizeText(F.size)));
      if F.once then A.appendChild(El('span', 'fexp', T('deletes after one download')))
      else if F.expires then A.appendChild(El('span', 'fexp', T('until %s', DateTimeText(F.expires))));
      Box.appendChild(A);
    end;
  end;
  Result := Box;
end;

// The chips under a message (reactions.js), and who gave each.
function RenderReactions(M: TMsg): TJSHTMLElement;
begin
  Result := Reactions.chips(M.reactions, new([
    'toggle', procedure(R: TJSObject) begin React(M.id, R['r'], M.dm); end,
    'who', function(R: TJSObject): TJSPromise
      var
        Url: string;
      begin
        if M.dm then Url := '/api/dm/reacted' else Url := '/api/reacted';
        Result := Get(Url + '?id=' + String(JSValue(M.id)) + '&r=' + Enc(R['r']));
      end]));
end;

// Dm: the message is a private one, which has its own numbers and its own place.
procedure React(Id, R: JSValue; Dm: boolean); async;
begin
  if Me.name = '' then
  begin
    Toast(T('Join to react.'));
    Exit;
  end;
  try
    if Dm then
    begin
      await(JSValue, Post('/api/dm/react', new(['id', Id, 'r', R])));
      RefreshDm(Id);
      Exit;
    end;
    await(JSValue, Post('/api/react', new(['id', Id, 'r', R])));
    SyncNow;
  except
    Failed(JSExceptValue);
  end;
end;

// What the first link in a message leads to, folded to one line: the site
// and the title. A click opens the rest; the picture is asked for only then.
function PreviewOf(P: TJSObject): TEl;
var
  Pre: TPreview;
  Box, Line, More, Go: TEl;
  Host, Title: JSValue;
begin
  Pre := TPreview(P);
  Box := El('div', 'preview');
  Line := El('button', 'line');
  TCtl(Line).&type := 'button';
  Host := Pre.site;
  if not Host then
    try
      Host := TJSURL.new(Pre.url).host;
    except
      Host := '';
    end;
  if Pre.title then Title := Pre.title else Title := Pre.url;
  Line.append(El('span', 'site', Host), El('span', 'title', Title));
  Line.title := Pre.url;
  More := El('div', 'more');
  More.hidden := True;
  if Pre.description then More.appendChild(El('p', '', Pre.description));
  Go := El('a', 'small-link', T('Open the page'));
  TCtl(Go).href := Pre.url;
  TCtl(Go).target := '_blank';
  TCtl(Go).rel := 'noopener nofollow ugc';
  More.appendChild(Go);
  Line.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Open: boolean;
      Img: TEl;
    begin
      Open := Box.classList.toggle('open');
      More.hidden := not Open;
      if Open and Truthy(Pre.image) and (More.querySelector('img') = nil) then
      begin
        Img := El('img');
        TCtl(Img).alt := '';
        TCtl(Img).referrerPolicy := 'no-referrer';
        TCtl(Img).src := Pre.image;
        More.prepend(Img);
      end;
    end));
  Box.append(Line, More);
  Result := Box;
end;

end.
