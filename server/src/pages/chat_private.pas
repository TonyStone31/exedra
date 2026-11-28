unit chat_private;

{ Private conversations: plain and locked messages, files and beams. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, chat_shared;

function PlainHtml(const Text: string; Locked: boolean): string;
procedure OpenDm(Name: JSValue); async;
function OpenSealed(M: TJSObject): TJSObject; async;
procedure PollDm(Generation: double); async;
procedure OlderDms; async;
procedure MarkSeen;
procedure DropDm(Id: JSValue);
procedure StartDmEdit(Node: TEl);
procedure RefreshDm(Id: JSValue); async;
function RenderDm(M: TJSObject; Payload: TJSObject): TEl;
procedure SendDm(const Other, Text: string; Files: TJSArray); async;
procedure PollNow;
procedure BeamFile(const Other: string; Data: TJSObject); async;

implementation

uses weborworker, chat_sidebar, chat_rooms, chat_messages, chat_answer, chat_menu, chat_sync, chat_panels, chat_composer,
  chat_complete;

type
  // A private message as /api/dm sends it.
  TDm = class external name 'Object'(TJSObject)
    id: double;
    from: string;
    iv: JSValue;
    data: string;
    at: JSValue;
    html: JSValue;
    edited: JSValue;
    reactions: JSValue;
    preview: JSValue;
  end;
  // What a private message carries; the other side wrote it.
  TPayload = class external name 'Object'(TJSObject)
    t: string;
    text: string;
    files: TJSArray;
    re: TJSObject;
    token: string;
    name: JSValue;
    size: JSValue;
  end;
  // The other member as /api/key describes them.
  TWho = class external name 'Object'(TJSObject)
    name: string;
    avatar: JSValue;
    seen: double;
    locked: JSValue;
  end;
  // What Keys.partner answers.
  TPartner = class external name 'Object'(TJSObject)
    code: JSValue;
    changed: boolean;
  end;
  // An element as a control or a picture: Web keeps these fields on classes of their own.
  TCtl = class external name 'HTMLElement'(TEl)
    &type: string;
    disabled: boolean;
    value: string;
    placeholder: string;
    autocomplete: string;
    src: JSValue;
    loading: string;
    max: JSValue;
    level: JSValue; external name 'value';
  end;
  TMenuOffer = reference to function: TJSObject;
  TReactPick = reference to procedure(R: JSValue);
  // How a beam goes: done, total and a word for its state.
  TBeamTold = reference to procedure(Done, Total: JSValue; const What: string);

// JavaScript's String(value).
function TextOf(Value: JSValue): string; external name 'String';

function KeyForm: TEl; forward;
function DmData(const Other: string; Payload: TJSObject): TJSObject; async; forward;
function PlainFile(F: TJSObject): TJSNode; forward;
function SealedFile(F: TJSObject): TJSNode; forward;
function BeamCard(M: TDm; Payload: TPayload): TEl; forward;

// Private messages are encrypted, so their text is shaped here: code
// blocks, inline code, bold and links, everything else escaped.
function PlainHtml(const Text: string; Locked: boolean): string;

  function Esc(const Raw: string): string;
  begin
    Result := TJSString(Raw).replace(TJSRegexp.new('&', 'g'), '&amp;');
    Result := TJSString(Result).replace(TJSRegexp.new('<', 'g'), '&lt;');
    Result := TJSString(Result).replace(TJSRegexp.new('>', 'g'), '&gt;');
    Result := TJSString(Result).replace(TJSRegexp.new('"', 'g'), '&quot;');
  end;

var
  Parts: TJSArray;
  Part, Lang, Shaped: string;
  Found: TJSObject;
  I: NativeInt;
begin
  Result := '';
  Parts := TJSArray(JSValue(TJSString(Text).split('```')));
  for I := 0 to Parts.length - 1 do
  begin
    Part := string(Parts[I]);
    if I mod 2 <> 0 then
    begin
      Found := TJSRegexp.new('^([\w+#-]+)\n').execFull(Part);
      if Found <> nil then Lang := string(Found['1']) else Lang := T('code');
      Result := Result + '<div class="code"><div class="codebar"><span>' + Esc(Lang) + '</span>';
      if Locked then
        Result := Result + '<span class="codenote">' + Esc(T('Not colored: the server cannot read a locked conversation.')) + '</span>';
      Result := Result + '<button type="button" class="copy">' + Esc(T('Copy')) + '</button></div><pre><code>';
      Shaped := TJSString(Part).replace(TJSRegexp.new('^[\w+#-]*\n'), '');
      Shaped := TJSString(Shaped).replace(TJSRegexp.new('\n$'), '');
      Result := Result + Esc(Shaped) + '</code></pre></div>';
    end
    else
    begin
      Shaped := TJSString(Esc(Part)).replace(TJSRegexp.new('`([^`\n]+)`', 'g'), '<code>$1</code>');
      Shaped := TJSString(Shaped).replace(TJSRegexp.new('\*\*([^*\n]+)\*\*', 'g'), '<b>$1</b>');
      Shaped := TJSString(Shaped).replace(TJSRegexp.new('(https?:\/\/[^\s<]+)', 'g'),
        '<a rel="nofollow ugc" target="_blank" href="$1">$1</a>');
      Result := Result + TJSString(Shaped).replace(TJSRegexp.new('\n', 'g'), '<br>');
    end;
  end;
end;

procedure OpenDm(Name: JSValue); async;
var
  Generation: double;
  Who: TWho;
  Head, MenuButton, Titles, H, Lock, Flip, Tools, Remove, Search: TEl;
begin
  Generation := S.generation;
  Who := await(TWho, Get('/api/key?name=' + Enc(Name)));
  if Generation <> S.generation then Exit;
  S.view := 'dm';
  S.dm := Who.name;
  S.dmAvatar := Who.avatar;
  if Truthy(Who.seen) then S.dmSeen := Who.seen else S.dmSeen := 0;
  S.dmLast := 0;
  S.dmFirst := 0;
  S.dmOlderDone := False;
  S.title := '@' + Who.name;
  Head := Find('#roomhead');
  MenuButton := IconButton('menu', T('Channels'), 'menubtn');
  MenuButton.addEventListener('click', ToggleMenu);
  Titles := El('div', 'titles');
  H := El('h1');
  H.append(Avatar(Who.name, Who.avatar, 'small'), Link('/u/' + Enc(Who.name), '', Who.name));
  Titles.appendChild(H);
  S.dmLocked := Truthy(Who.locked);
  if S.dmLocked then Lock := El('p', 'topic secure') else Lock := El('p', 'topic');
  if S.dmLocked then
    Lock.append(Icon('lock'), document.createTextNode(T(' Locked: end to end encrypted. Only your two browsers can read it, and IRC users cannot.')))
  else
    Lock.appendChild(document.createTextNode(T('Not locked: this site can read it, and it reaches IRC. ')));
  if Me.name <> '' then
  begin
    if S.dmLocked then Flip := El('button', 'small-link', T('Unlock')) else Flip := El('button', 'small-link', T('Lock it'));
    TCtl(Flip).&type := 'button';
    if S.dmLocked then Flip.title := T('New messages go plain, readable by this site and on IRC')
    else Flip.title := T('New messages are encrypted in your browsers; neither this site nor IRC can read them');
    Flip.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) async
      var
        Turn: string;
      begin
        try
          if S.dmLocked then Turn := '0' else Turn := '1';
          await(JSValue, Post('/api/dm/lock', new(['with', Who.name, 'on', Turn])));
          Route(SiteBase.path, False);
        except
          Failed(JSExceptValue);
        end;
      end));
    Lock.appendChild(Flip);
  end;
  Titles.appendChild(Lock);
  if S.dmLocked and (Me.name <> '') then
    Keys.partner(Who.name)._then(function(Value: JSValue): JSValue
      var
        P: TPartner;
        Code, Warn, Ok: TEl;
      begin
        P := TPartner(Value);
        Code := El('p', 'topic', T('Safety code: %s', P.code));
        Code.title := T('The same code shows on their side. Compare it another way (a call, in person) to be sure nobody sits between you.');
        Titles.appendChild(Code);
        if not P.changed then Exit;
        Warn := El('p', 'topic problem', T('%s has a new key since you last wrote here. That happens after a password reset. If you did not expect it, compare the safety code with them before you write anything private.', Who.name) + ' ');
        Ok := El('button', 'small-link', T('I checked'));
        TCtl(Ok).&type := 'button';
        Ok.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
          begin
            Keys.trust(Who.name)._then(function(Done: JSValue): JSValue
              begin
                Warn.remove;
              end).catch(TJSPromiseResolver(FailedFn));
          end));
        Warn.appendChild(Ok);
        Titles.appendChild(Warn);
      end).catch(function(Err: JSValue): JSValue
      begin
        // only this one is said here: a conversation not opened on this device yet is asked for elsewhere
        if Truthy(Err) and Truthy(TJSObject(Err)['notOwn']) then
          Titles.appendChild(El('p', 'topic problem', TJSObject(Err)['message']));
      end);
  Head.append(MenuButton, Titles);
  if Me.name <> '' then
  begin
    // The same as the arrow on its row in the room list, where a phone hides it.
    Tools := El('div', 'headtools');
    Remove := IconButton('trash', T('Delete this conversation'));
    Remove.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        chat_sidebar.DeleteDm(Who.name);
      end));
    Search := IconButton('search', T('Search'));
    Search.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        chat_panels.OpenSearch;
      end));
    Tools.append(Search, Remove);
    Head.appendChild(Tools);
  end;
  if Me.name = '' then
  begin
    Stream.appendChild(El('p', 'notice', T('Sign in to send private messages.')));
    RenderComposer(Find('#composer-area'), 0, nil);
    Exit;
  end;
  if not Keys.ready then
  begin
    Stream.appendChild(El('p', 'notice', T('Private messages need this page opened over https.')));
    Exit;
  end;
  if S.dmLocked and not Truthy(await(JSValue, Keys.myKey)) then
  begin
    Stream.appendChild(KeyForm);
    Exit;
  end;
  RenderComposer(Find('#composer-area'), 0, Who.name);
  PollDm(Generation);
  SyncNow(True);
end;

// Signed in with GitHub, GitLab or Google: the private key opens with the
// account's password, or the account gets its first one here.
function KeyForm: TEl;
var
  First: boolean;
  Form, Go: TEl;
  Password: TCtl;
  Say: string;
begin
  First := not Truthy(Me.wrapped);
  Form := El('form', 'invite keyform');
  Password := TCtl(El('input'));
  Password.&type := 'password';
  if First then Password.autocomplete := 'new-password' else Password.autocomplete := 'current-password';
  if First then Password.placeholder := T('A new password, 8 characters or more') else Password.placeholder := T('Your password');
  if First then Go := El('button', 'primary', T('Set it')) else Go := El('button', 'primary', T('Unlock'));
  Say := T('Type your password to open your locked messages on this device.');
  if First and Truthy(Me.password) then
    Say := T('Locked conversations need a key made from your password. Type it once here.')
  else if First then
    Say := T('Locked conversations need a password that never leaves your browser, and this account has none yet. Set one here. It also signs you in with your name, and a forgotten one cannot be reset.');
  Form.append(El('p', 'notice', Say), Password, Go);
  Form.addEventListener('submit', TJSRawEventHandler(procedure(E: TJSEvent) async
    begin
      E.preventDefault;
      TCtl(Go).disabled := True;
      try
        if First then await(JSValue, Keys.setupKeys(Me.name, Password.value))
        else await(JSValue, Keys.unlock(Me.name, Password.value, Me.wrapped));
        Route(SiteBase.path, False);
      except
        Failed(JSExceptValue);
      end;
      TCtl(Go).disabled := False;
    end));
  Result := Form;
end;

function OpenSealed(M: TJSObject): TJSObject; async;
var
  Sent: TDm;
begin
  Sent := TDm(M);
  if not Sent.iv then
  begin
    try
      Exit(TJSObject(TJSJSON.parse(Sent.data)));
    except
      Exit(new(['t', 'text', 'text', Sent.data]));
    end;
  end;
  try
    Result := await(TJSObject, Keys.open(S.dm, Sent));
  except
    Result := new(['t', 'text', 'text', T('(locked, and this device cannot open it)')]);
  end;
end;

// The newest messages first; a live ring or the timer brings newer ones.
procedure PollDm(Generation: double); async;
var
  List: TJSArray;
  Stick: boolean;
  M: TDm;
  Payload: TJSObject;
  P: TEl;
  I: NativeInt;
  Wait: NativeInt;
  Tail: string;
begin
  if Generation <> S.generation then Exit;
  window.clearTimeout(S.dmTimer);
  try
    // a tab nobody is looking at leaves the messages unread; back in view, what is shown counts as read
    if document.hidden then Tail := '&peek=1'
    else if Truthy(S.dmLast) then Tail := '&read=' + String(JSValue(S.dmLast))
    else Tail := '';
    List := await(TJSArray, Get('/api/dm?with=' + Enc(S.dm) + '&after=' + String(JSValue(S.dmLast)) + Tail));
    if Generation <> S.generation then Exit;
    Stick := Stream.pinned or NearBottom or not Truthy(S.dmLast);
    for I := 0 to List.length - 1 do
    begin
      M := TDm(List[I]);
      Payload := await(OpenSealed(M));
      // A second look that started before this one finished has it already.
      if (Generation <> S.generation) or (M.id <= S.dmLast) then continue;
      Stream.appendChild(RenderDm(M, Payload));
      S.dmLast := Max(S.dmLast, M.id);
      if not Truthy(S.dmFirst) or (M.id < S.dmFirst) then S.dmFirst := M.id;
    end;
    if Truthy(List.length) then
    begin
      Regroup(Stream);
      if Stick then
      begin
        Stream.scrollTop := Stream.scrollHeight;
        Stream.pinned := True;
      end;
    end;
    if not Truthy(List.length) and not Truthy(S.dmLast) and (Find('.empty', Stream) = nil) then
    begin
      P := El('div', 'empty');
      P.appendChild(El('b', '', T('Nothing between you two yet.')));
      if S.dmLocked then P.appendChild(El('span', '', T(' Locked: only the two of you will ever read what you write here.')))
      else P.appendChild(El('span', '', T(' Lock it at the top when it should stay between your two browsers.')));
      Stream.appendChild(P);
    end
    else if Truthy(List.length) and (Find('.empty', Stream) <> nil) then Find('.empty', Stream).remove;
  except
  end;
  if Truthy(Live.id) then Wait := 60000
  else if document.hidden then Wait := 15000
  else Wait := 3000;
  S.dmTimer := window.setTimeout(procedure
    begin
      PollDm(Generation);
    end, Wait);
end;

// Scrolling to the top of a private conversation brings older messages.
procedure OlderDms; async;
var
  Generation: double;
  List: TJSArray;
  Height, I: NativeInt;
  Top: TEl;
  Node: TEl;
begin
  if not Truthy(S.dmFirst) or S.dmOlderDone or S.loadingOlder then Exit;
  S.loadingOlder := True;
  Generation := S.generation;
  try
    try
      List := await(TJSArray, Get('/api/dm?with=' + Enc(S.dm) + '&before=' + String(JSValue(S.dmFirst))));
      if Generation <> S.generation then Exit;
      Height := Stream.scrollHeight;
      Top := TEl(Stream.querySelector('.msg'));
      for I := 0 to List.length - 1 do
      begin
        Node := RenderDm(TJSObject(List[I]), await(OpenSealed(TJSObject(List[I]))));
        if Top <> nil then Top.before(Node) else Stream.appendChild(Node);
      end;
      if Truthy(List.length) then S.dmFirst := TDm(List[0]).id;
      if List.length < 100 then S.dmOlderDone := True;
      Regroup(Stream);
      Stream.scrollTop := Stream.scrollHeight - Height;
    except
      Failed(JSExceptValue);
    end;
  finally
    S.loadingOlder := False;
  end;
end;

// A quiet mark on the newest of my messages the other has read.  The
// server says how far (S.dmSeen); one mark, which moves down as they read.
procedure MarkSeen;
var
  Old, Node, Mine, Mark: TEl;
  List: TJSNodeList;
  I: NativeInt;
begin
  Old := TEl(Stream.querySelector(':scope > .msg > .seen'));
  Node := nil;
  if (S.view = 'dm') and Truthy(S.dmSeen) then
  begin
    List := Stream.querySelectorAll(':scope > .msg.mine');
    for I := 0 to List.length - 1 do
    begin
      Mine := TEl(List[I]);
      if NumberOf(Mine.dataset['id']) <= S.dmSeen then Node := Mine;
    end;
  end;
  if (Old <> nil) and (Old.parentNode = Node) then Exit;
  if Old <> nil then Old.remove;
  if Node = nil then Exit;
  Mark := El('span', 'seen');
  Mark.title := T('Seen');
  Mark.setAttribute('aria-label', Mark.title);
  Mark.appendChild(Icon('seen'));
  Node.appendChild(Mark);
end;

// A private message taken back, by this member or the other: out of the
// open conversation, the groups redone.
procedure DropDm(Id: JSValue);
var
  Node: TJSElement;
begin
  Node := Stream.querySelector('.msg[data-id="' + String(Id) + '"]');
  if Node = nil then Exit;
  Node.remove;
  Regroup(Stream);
end;

// One's own private message written again: the same box as in a channel.
// The payload keeps its kind and files; a locked conversation seals it again.
procedure StartDmEdit(Node: TEl);
var
  M: TDm;
  Payload: TPayload;
  Text, Box, Save, Cancel: TEl;
  Area: TArea;
  Complete: TCompleter;

  function Words: string;
  begin
    if Truthy(Payload.text) then Result := Payload.text else Result := '';
  end;

  procedure Done;
  begin
    Box.replaceWith(Text);
  end;

  procedure Store; async;
  var
    Body: string;
    Data: TJSObject;
  begin
    Body := TJSString(Area.value).trim;
    if (Body = '') and not (Truthy(Payload.files) and Truthy(Payload.files.length)) then
    begin
      Failed(TJSError.new(T('An edited message cannot be empty. Delete it instead.')));
      Exit;
    end;
    if Body = Words then
    begin
      Done;
      Exit;
    end;
    try
      Data := TJSObject.assign(new(['id', M.id]),
        await(DmData(S.dm, TJSObject.assign(TJSObject.new, Payload, new(['text', Body])))));
      await(JSValue, Post('/api/dm/edit', Data));
      Done;
      RefreshDm(M.id);
    except
      Failed(JSExceptValue);
    end;
  end;

begin
  M := TDm(Node.dm['m']);
  Payload := TPayload(Node.dm['payload']);
  Text := TEl(Node.querySelector('.body'));
  if Text = nil then Exit;
  Box := El('div', 'editbox');
  Area := TArea(TJSHTMLElement(El('textarea')));
  Area.value := Words;
  Save := El('button', 'primary', T('Save'));
  Cancel := El('button', '', T('Cancel'));
  TCtl(Cancel).&type := 'button';
  TCtl(Save).&type := 'button';
  Box.append(Area, Save, Cancel);
  Text.replaceWith(Box);
  Area.focus;
  Area.setSelectionRange(TJSString(Area.value).length, TJSString(Area.value).length);
  Fit(Area);
  Complete := Completer(Area);
  Save.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      Store;
    end));
  Cancel.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      Done;
    end));
  Area.addEventListener('input', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      Fit(Area);
      Complete.update;
    end));
  Area.addEventListener('keydown', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Key: TJSKeyboardEvent;
    begin
      Key := TJSKeyboardEvent(E);
      if Complete.handle(Key) then Exit;
      if Key.key = 'Escape' then Done;
      if (Key.key = 'Enter') and not Key.shiftKey and not InFence(Area) then
      begin
        E.preventDefault;
        Store;
      end;
    end));
end;

// A private message changed, here or on the other side: shown again in place.
procedure RefreshDm(Id: JSValue); async;
var
  Node, Now: TEl;
  Generation: double;
  List: TJSArray;
  Fresh: TEl;
begin
  Node := TEl(Stream.querySelector('.msg[data-id="' + String(Id) + '"]'));
  if (Node = nil) or (S.view <> 'dm') then Exit;
  Generation := S.generation;
  try
    List := await(TJSArray, Get('/api/dm?with=' + Enc(S.dm) + '&id=' + String(Id) + '&peek=1'));
    if (Generation <> S.generation) or not Truthy(List.length) then Exit;
    Fresh := RenderDm(TJSObject(List[0]), await(OpenSealed(TJSObject(List[0]))));
    Now := TEl(Stream.querySelector('.msg[data-id="' + String(Id) + '"]'));
    if Now <> nil then
    begin
      Now.replaceWith(Fresh);
      Regroup(Stream);
    end;
  except
  end;
end;

// A private message's words as they are shown: /me waves from Ann reads
// "Ann waves", an action as in a channel.  The message keeps what was typed.
function DmWords(const From, Text: string): string;
var
  Action: TJSObject;
begin
  Action := TJSRegexp.new('^\/me +(\S.*)$', 'i').execFull(Text);
  if Action <> nil then Result := From + ' ' + TJSString(Action['1']).trim else Result := Text;
end;

function RenderDm(M: TJSObject; Payload: TJSObject): TEl;
var
  Sent: TDm;
  Load: TPayload;
  Node, Text, Box: TEl;
  Said: string;
  Html, Face, Given: JSValue;
  Re: TJSObject;
  I: NativeInt;

  // Its own menu: react, answer, copy, and for one's own words, edit
  // and delete from both sides.
  function Offer: TJSObject;
  var
    Items: TJSArray;
    Pick: TReactPick;
  begin
    Items := TJSArray.new;
    if Load.text <> '' then
    begin
      Items.push(new(['icon', 'reply', 'title', T('Answer this message'), 'run', TProc(procedure
        var
          First: string;
        begin
          First := FirstWords(Said);
          if First = '' then First := T('code');
          Answer('dm ' + S.dm, new(['id', Sent.id, 'from', Sent.from, 'text', First]));
        end)]));
      Items.push(new(['icon', 'copy', 'title', T('Copy the text'), 'run', TProc(procedure
        begin
          window.navigator.clipboard.writeText(Said)._then(function(Done: JSValue): JSValue
            begin
              Toast(T('Text copied.'));
            end);
        end)]));
    end;
    if (Sent.from = Me.name) and ((Load.t = 'text') or (Load.t = 'file')) then
      Items.push(new(['icon', 'edit', 'title', T('Edit'), 'run', TProc(procedure
        begin
          StartDmEdit(Node);
        end)]));
    if Sent.from = Me.name then
      Items.push(new(['icon', 'trash', 'title', T('Delete, for both of you'), 'bad', True, 'run', TProc(procedure async
        begin
          if not window.confirm(T('Delete this message? It goes from both sides.')) then Exit;
          try
            await(JSValue, Post('/api/dm/delete', new(['id', Sent.id])));
            DropDm(Sent.id);
          except
            Failed(JSExceptValue);
          end;
        end)]));
    Pick := nil;
    if May('react') then
      Pick := procedure(R: JSValue)
        begin
          React(Sent.id, R, True);
        end;
    Result := new(['react', Pick, 'items', Items]);
  end;

begin
  Sent := TDm(M);
  // the other side wrote the payload: what is not the expected shape is left out
  if not Truthy(Payload) or (jsTypeOf(Payload) <> 'object') then Payload := TJSObject.new;
  Load := TPayload(Payload);
  if jsTypeOf(JSValue(Load.text)) <> 'string' then Load.text := '';
  if not TJSArray.isArray(Load.files) then JSDelete(Load, 'files');
  if Sent.from = Me.name then Face := Me.avatar else Face := S.dmAvatar;
  if TJSArray.isArray(Sent.reactions) then Given := Sent.reactions else Given := TJSArray.new;
  Node := RenderMessage(TMsg(new(['id', Sent.id, 'at', Sent.at, 'name', Sent.from, 'uid', 1, 'html', '', 'room', S.room,
    'avatar', Face, 'edited', Truthy(Sent.edited), 'dm', True,
    'files', TJSArray.new, 'reactions', Given, 'replies', 0, 'deleted', False])), True);
  Node.dm := new(['m', Sent, 'payload', Load]);
  Said := DmWords(Sent.from, Load.text);
  Node.menu := TMenuOffer(@Offer);
  Text := TEl(Node.querySelector('.body'));
  // an unlocked message comes shaped by the server, like a channel's; a
  // locked one the server cannot read, so its few marks are shaped here
  if not Truthy(Sent.iv) and (jsTypeOf(Sent.html) = 'string') then
  begin
    Html := Sent.html;
    asm Text.innerHTML = Html;   // safe html: rendered by the server
    end;
  end
  else
  begin
    Html := PlainHtml(Said, Truthy(Sent.iv));
    asm Text.innerHTML = Html;   // safe html: plainHtml escapes everything first
    end;
  end;
  Toggle(Text, 'action', Said <> Load.text);
  DressCode(Text);
  // the message this one answers: the other side wrote it, so only the
  // expected shape is shown
  Re := Load.re;
  if Truthy(Re) and (jsTypeOf(Re) = 'object') and (jsTypeOf(Re['text']) = 'string') and (jsTypeOf(Re['from']) = 'string') then
    Text.before(QuoteOf(new(['id', Re['id'], 'from', Re['from'], 'text', Re['text']]), procedure
      begin
        Toast(T('That message is further back.'));
      end));
  if Truthy(Sent.preview) and (jsTypeOf(Sent.preview) = 'object') then Text.after(PreviewOf(TJSObject(Sent.preview)));
  if Truthy(Load.files) then
  begin
    Box := El('div', 'files');
    for I := 0 to Load.files.length - 1 do
      if TJSObject(Load.files[I])['iv'] then Box.appendChild(SealedFile(TJSObject(Load.files[I])))
      else Box.appendChild(PlainFile(TJSObject(Load.files[I])));
    Text.after(Box);
  end;
  if Load.t = 'beam' then Text.after(BeamCard(Sent, Load));
  Result := Node;
end;

// The sender wrote this payload: only our own /f/ links get through.
function PlainFile(F: TJSObject): TJSNode;
var
  Shot, A: TJSHTMLAnchorElement;
  Img: TEl;
begin
  if not TJSString(TextOf(F['url'])).startsWith('/f/') then F := new(['name', TextOf(F['name']), 'size', 0, 'url', '#']);
  if F['image'] then
  begin
    Shot := Link(F['url'], 'shot');
    Img := El('img');
    TCtl(Img).src := F['url'];
    TCtl(Img).loading := 'lazy';
    Shot.appendChild(Img);
    Exit(Shot);
  end;
  A := Link(F['url'], 'file');
  A.append(El('span', 'fname', F['name']), El('span', 'fsize', SizeText(F['size'])));
  Result := A;
end;

function SealedFile(F: TJSObject): TJSNode;
var
  A: TJSHTMLAnchorElement;

  function Kind: TJSString;
  begin
    if F['type'] then Result := TJSString(F['type']) else Result := TJSString('');
  end;

  procedure OpenIt(E: TJSEvent); async;
  var
    Blob: JSValue;
    Url: string;
    Shot, Save: TJSHTMLAnchorElement;
    Img: TEl;
  begin
    if E <> nil then E.preventDefault;
    try
      Blob := await(JSValue, Keys.openFile(S.dm, F));
      Url := TJSURL.createObjectURL(Blob);
      if Kind.startsWith('image/') then
      begin
        Shot := Link(Url, 'shot');
        Img := El('img');
        TCtl(Img).src := Url;
        Shot.appendChild(Img);
        TEl(TJSHTMLElement(A)).replaceWith(Shot);
      end
      else
      begin
        Save := Link(Url, '');
        TJSObject(Save)['download'] := F['name'];
        Save.click;
      end;
    except
      Failed(JSExceptValue);
    end;
  end;

begin
  A := Link('#', 'file');
  A.append(Icon('lock'), El('span', 'fname', F['name']), El('span', 'fsize', SizeText(F['size'])));
  A.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      OpenIt(E);
    end));
  if Kind.startsWith('image/') and (NumberOf(F['size']) < 8 * 1024 * 1024) then
    window.setTimeout(procedure
      begin
        OpenIt(nil);
      end, 0);
  Result := A;
end;

procedure SendDm(const Other, Text: string; Files: TJSArray); async;
var
  Payload, Re, Fields: TJSObject;
begin
  if Truthy(Files.length) then Payload := new(['t', 'file', 'text', Text]) else Payload := new(['t', 'text', 'text', Text]);
  if Truthy(Files.length) then Payload['files'] := Files;
  Re := Answered('dm ' + Other);
  if Re <> nil then
  begin
    Payload['re'] := Re;
    Answer;
  end;
  Fields := new(['to', Other, 'files', Files.map(function(F: JSValue; Index: NativeInt; List: TJSArray): JSValue
    begin
      Result := TJSObject(F)['token'];
    end).join(',')]);
  await(JSValue, Post('/api/dm', TJSObject.assign(Fields, await(DmData(Other, Payload)))));
  PollNow;
end;

// What /api/dm takes: sealed when the conversation is locked, plain JSON when not.
function DmData(const Other: string; Payload: TJSObject): TJSObject; async;
var
  Sealed: TJSObject;
begin
  if not S.dmLocked then Exit(new(['data', TJSJSON.stringify(Payload)]));
  Sealed := await(TJSObject, Keys.seal(Other, Payload));
  Result := new(['iv', Sealed['iv'], 'data', Sealed['data']]);
end;

procedure PollNow;
begin
  window.clearTimeout(S.dmTimer);
  PollDm(S.generation);
end;

// Beam: the sender keeps the page open while the file goes across.
procedure BeamFile(const Other: string; Data: TJSObject); async;
var
  Token: string;
  Why: JSValue;
begin
  try
    Token := '';
    Token := await(string, Keys.beamSend(Other, Data, TBeamTold(procedure(Done, Total: JSValue; const What: string)
      begin
        if S.beams[Token] then TBeamTold(S.beams[Token])(Done, Total, What);
      end)));
    await(JSValue, Post('/api/dm', TJSObject.assign(new(['to', Other]),
      await(DmData(Other, new(['t', 'beam', 'name', Data['name'], 'size', Data['size'], 'token', Token]))))));
    Toast(T('Keep this page open until %s has the file.', Other));
    PollNow;
  except
    Why := JSExceptValue;
    if TJSObject(Why)['message'] then Why := TJSObject(Why)['message'];
    Note(T('The beam did not start: %s', Why));
  end;
end;

function BeamCard(M: TDm; Payload: TPayload): TEl;
var
  Card, Bar, State, Take: TEl;
  Report: TBeamTold;
begin
  Card := El('div', 'beam');
  Card.appendChild(Icon('beam'));
  Card.appendChild(El('b', '', Payload.name));
  Card.appendChild(El('span', 'fsize', SizeText(Payload.size)));
  Bar := El('progress');
  TCtl(Bar).max := 1;
  TCtl(Bar).level := 0;
  State := El('span', 'state');
  Report := procedure(Done, Total: JSValue; const What: string)
    var
      Said: JSValue;
    begin
      if Total then TCtl(Bar).max := Total else TCtl(Bar).max := 1;
      TCtl(Bar).level := Done;
      Said := new(['waiting', T('waiting for them to take it'), 'sending', T('sending'),
        'receiving', T('receiving'), 'connecting', T('connecting'), 'done', T('delivered')])[What];
      if not Said then Said := What;
      TJSObject(State)['textContent'] := Said;
    end;
  if M.from = Me.name then
  begin
    S.beams[Payload.token] := Report;
    State.textContent := T('sent from this page, which has to stay open');
    Card.append(Bar, State);
  end
  else
  begin
    Take := El('button', 'primary', T('Take it'));
    TCtl(Take).&type := 'button';
    Take.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) async
      var
        Got: TJSObject;
        Save: TJSHTMLAnchorElement;
      begin
        Take.remove;
        Card.append(Bar, State);
        try
          Got := await(TJSObject, Keys.beamReceive(Payload.token, Report));
          State.textContent := T('received');
          Save := Link(TJSURL.createObjectURL(Got), 'primary', T('Save %s', Got['name']));
          TJSObject(Save)['download'] := Got['name'];
          Card.appendChild(Save);
          Save.click;
        except
          TJSObject(State)['textContent'] := TJSObject(JSExceptValue)['message'];
        end;
      end));
    Card.appendChild(Take);
    Card.appendChild(El('span', 'state', T('straight from their browser, never stored on the server')));
  end;
  Result := Card;
end;

end.
