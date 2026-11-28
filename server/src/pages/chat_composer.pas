unit chat_composer;

{ The box members type in: files, photos, sending, commands and notes. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, chat_shared;

procedure Fit(Area: TJSHTMLTextAreaElement);
function InFence(Area: TJSHTMLTextAreaElement): boolean;
// Parent is the thread's first message or 0; Dm the other member's name, or null or undefined.
procedure RenderComposer(Area: TEl; Parent: double; Dm: JSValue = undefined);
function DmCommand(const Text: string): boolean; async;
procedure Note(const Text: string; InThread: boolean = False);
procedure Start;

implementation

uses chat_rooms, chat_answer, chat_sync, chat_menu, chat_private, chat_complete;

type
  // Web's FormData takes no file name with a file.
  TFileForm = class external name 'FormData'(TJSFormData)
    procedure append(const Name: string; Data, FileName: JSValue); overload;
  end;
  // What the server answers to a post.
  TSaid = class external name 'Object'(TJSObject)
    info: string;
    go: string;
  end;
  TTold = reference to procedure(Share: double);

var
  // What was typed and not sent, by the box's key.
  Drafts: TJSMap;

function Least(A, B, C: double): double; external name 'Math.min';

// A box grows with its text, to 300px or to what the list above it can give
// up: a box taller than that would have its last lines under a phone's keyboard.
procedure Fit(Area: TJSHTMLTextAreaElement);
var
  List: TJSElement;
begin
  TJSObject(Area.style)['height'] := 'auto';
  List := Area.closest('#main, #panel').querySelector('#stream, .threadlist');
  TJSObject(Area.style)['height'] := String(JSValue(Max(Area.clientHeight,
    Least(Area.scrollHeight, 300, Area.clientHeight + List.clientHeight - 24)))) + 'px';
end;

// True while the caret sits inside an open ``` block, where Enter makes a new line.
function InFence(Area: TJSHTMLTextAreaElement): boolean;
var
  Fences: JSValue;
  Count: NativeInt;
begin
  Fences := JSValue(TJSString(TJSString(Area.value).slice(0, Area.selectionStart)).match(TJSRegexp.new('```', 'g')));
  if Fences then Count := TJSArray(Fences).length else Count := 0;
  Result := Count mod 2 = 1;
end;

// Sends one file; Told hears how much of it has gone up, 0 to 1.
function Upload(Data: TJSObject; const Expire: string; SealedFor: JSValue; Told: TTold): TJSPromise;
var
  Form: TFileForm;
  Name: JSValue;
begin
  if SealedFor then Exit(Keys.sealFile(SealedFor, Data, Expire));
  Form := TFileForm.new;
  Form.append('expire', Expire);
  Name := Data['name'];
  if not Name then Name := 'pasted.png';
  Form.append('file', Data, Name);
  Result := TJSPromise.new(procedure(Resolve, Reject: TJSPromiseResolver)
    var
      Ask: TJSXMLHttpRequest;
    begin
      Ask := TJSXMLHttpRequest.new;
      Ask.open('POST', '/api/upload');
      if Told <> nil then Ask.upload.addEventListener('progress', TJSRawEventHandler(procedure(E: TJSEvent)
        begin
          if TJSProgressEvent(E).lengthComputable then Told(TJSProgressEvent(E).loaded / TJSProgressEvent(E).Total);
        end));
      Ask.addEventListener('load', TJSRawEventHandler(procedure(E: TJSEvent)
        var
          Refused: TJSError;
        begin
          if (Ask.Status >= 200) and (Ask.Status < 300) then
          begin
            try
              Resolve(TJSJSON.parse(Ask.responseText));
            except
              Reject(JSExceptValue);
            end;
            Exit;
          end;
          Refused := TJSError.new(Ask.responseText);
          TJSObject(Refused)['status'] := Ask.Status;
          Reject(Refused);
        end));
      Ask.addEventListener('error', TJSRawEventHandler(procedure(E: TJSEvent)
        begin
          Reject(TJSError.new(T('The file did not go up. Check the connection and try again.')));
        end));
      Ask.send(Form);
    end);
end;

// The box members type in, for a room, a thread (Parent) or a private conversation (Dm).
procedure RenderComposer(Area: TEl; Parent: double; Dm: JSValue);
var
  DmName, DraftKey, Words: string;
  Form, Files, Row, Attach, Code, Answering, Options, Beam: TEl;
  Area2: TArea;
  Send: TJSHTMLButtonElement;
  FilePick, BeamPick: TJSHTMLInputElement;
  Expire: TJSHTMLSelectElement;
  Draft: JSValue;
  Pending: TJSArray;
  Chips: TJSMap;
  Busy, Asking: TJSSet;
  Complete: TCompleter;
  Sending: boolean;

  procedure Choice(const Value, Caption: string);
  var
    Opt: TEl;
  begin
    Opt := El('option', '', Caption);
    TJSHTMLOptionElement(TJSHTMLElement(Opt)).value := Value;
    Expire.appendChild(Opt);
  end;

  // A camera photo that can go up smaller: its chip asks which, with both
  // sizes.  Send without an answer takes the smaller one.
  function WhichSize(Chip: TEl; Data, Small: TJSObject): TJSPromise;
  var
    Ask, Less, All: TEl;
    Smaller: TProc;
    Done: TJSPromiseResolver;

    procedure Choose(Picked: JSValue);
    begin
      Asking.delete(Smaller);
      Ask.remove;
      Done(Picked);
    end;

  begin
    Result := TJSPromise.new(procedure(Resolve, Reject: TJSPromiseResolver)
      begin
        Done := Resolve;
        Ask := El('span', 'sizes');
        Smaller := procedure begin Choose(Small); end;
        Less := El('button', '', T('Smaller') + ' · ' + SizeText(Small['size']));
        All := El('button', '', T('Full size') + ' · ' + SizeText(Data['size']));
        TJSHTMLButtonElement(TJSHTMLElement(All))._type := 'button';
        TJSHTMLButtonElement(TJSHTMLElement(Less))._type := 'button';
        Less.addEventListener('click', TJSRawEventHandler(Smaller));
        All.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Choose(Data); end));
        Ask.append(Less, All);
        Chip.appendChild(Ask);
        Asking.add(Smaller);
      end);
  end;

  procedure Add(List: TJSArray);
  var
    Run: TJSPromise;
    Waiting: TJSArray;

    // The chip of a file that is up can be taken off again.
    procedure Closable(Chip: TEl; Done: JSValue);
    var
      X: TEl;
    begin
      X := El('button', '', '×');
      TJSHTMLButtonElement(TJSHTMLElement(X))._type := 'button';
      X.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
        begin
          Pending.splice(Pending.indexOf(Done), 1);
          Chip.remove;
        end));
      Chip.appendChild(X);
    end;

    function Worker: JSValue; async;
    var
      Next, Data: TJSObject;
      Chip, Share: TEl;
      Small, Sent, Done: JSValue;

      // the chip and its share are this file's own, also when a report comes late
      function Goes(Which: JSValue; Mine, Part: TEl): TJSPromise;
      var
        Sealed: JSValue;
      begin
        if Truthy(Dm) and S.dmLocked then Sealed := Dm else Sealed := '';
        Result := Upload(TJSObject(Which), Expire.value, Sealed, procedure(Sent: double)
          begin
            Part.textContent := String(JSValue(Round(Sent * 100))) + '%';
            Mine.style.setProperty('--up', String(JSValue(Round(Sent * 100))) + '%');
          end);
      end;

    begin
      while Waiting.length > 0 do
      begin
        Next := TJSObject(Waiting.shift);
        Data := TJSObject(Next['file']);
        Chip := TEl(Next['chip']);
        Share := El('span', 'share', '');
        try
          Small := await(JSValue, Keys.smaller(Data));
          if Same(Small, Data) then Sent := Data
          else Sent := await(JSValue, WhichSize(Chip, Data, TJSObject(Small)));
          Chip.appendChild(Share);
          // a photo too big for this site as it is still goes, smaller
          Done := await(JSValue, Goes(Sent, Chip, Share).catch(function(Err: JSValue): JSValue
            begin
              if Same(Sent, Small) then raise TJSError(Err);
              Toast(T('That photo did not go up at full size. Sending it smaller.'));
              Result := Goes(Small, Chip, Share);
            end));
          Share.remove;
          Chip.style.removeProperty('--up');
          Pending.push(Done);
          Chips.&set(Done, Chip);
          Chip.classList.remove('busy');
          Closable(Chip, Done);
        except
          Chip.remove;
          Failed(JSExceptValue);
        end;
      end;
    end;

    function Go: JSValue; async;
    begin
      // two files go up side by side; the chips show in the order they were chosen
      Waiting := TJSArray.from(List).map(function(Data: JSValue; I: NativeInt; A: TJSArray): JSValue
        var
          Name: JSValue;
          Chip: TEl;
        begin
          Name := TJSObject(Data)['name'];
          if not Name then Name := T('picture');
          Chip := El('span', 'chip busy', Name);
          Files.appendChild(Chip);
          Result := new(['file', Data, 'chip', Chip]);
        end);
      await(JSValue, TJSPromise.all([Worker(), Worker()]));
    end;

  begin
    Run := TJSPromise(Go());
    Busy.add(Run);
    Run._then(function(Value: JSValue): JSValue begin Busy.delete(Run); end);
  end;

  // Android's chooser has the gallery only for an input that asks for pictures
  // and videos alone: there the button asks which first.
  procedure Pick(Input: TJSHTMLInputElement; Button: TJSElement);

    procedure OpenWith(const Accept: string);
    begin
      Input.accept := Accept;
      Input.click;
    end;

  begin
    if not TJSRegexp.new('Android').test(window.navigator.userAgent) then
    begin
      Input.click;
      Exit;
    end;
    PopMenu(Button, TJSArray._of(
      TJSArray._of(T('Photos and videos'), TProc(procedure begin OpenWith('image/*,video/*'); end)),
      TJSArray._of(T('Camera or file'), TProc(procedure begin OpenWith(''); end))));
  end;

  procedure Submit; async;
  var
    Text: string;
    Found: JSValue;
    Parts, Each, Sent: TJSArray;
    I, At: NativeInt;
    Re: TJSObject;
    Said: TSaid;
    P, ParentOr, ReId: JSValue;
  begin
    // Enter again while it goes would send it twice
    if Sending then Exit;
    if Busy.size > 0 then
    begin
      // a message does not go out with half its files
      Sending := True;
      Send.disabled := True;
      Toast(T('Sending when the files are up'));
      Each := TJSArray.from(Asking);
      for I := 0 to Each.length - 1 do TProc(Each[I])();
      while Busy.size > 0 do await(JSValue, TJSPromise.all(JSValue(TJSArray.from(Busy))));
      Sending := False;
      Send.disabled := False;
    end;
    Text := TJSString(Area2.value).trim;
    if (Text = '') and (Pending.length = 0) then Exit;
    Drafts.delete(DraftKey);
    // The commands the page does itself: a private message is encrypted
    // here, so the server never sees one.
    Found := JSValue(TJSString(Text).match(TJSRegexp.new('^\/(\w+)\s*([\s\S]*)$')));
    Parts := TJSArray(Found);
    if Truthy(Found) and Truthy(Extras.commands[String(Parts[1])]) then
    begin
      Area2.value := '';
      Fit(Area2);
      TJSFunction(Extras.commands[String(Parts[1])]).call(Extras.commands, Parts[2]);
      Exit;
    end;
    Found := JSValue(TJSString(Text).match(TJSRegexp.new('^\/(msg|query)\b\s*@?([\w.-]*)\s*([\s\S]*)$')));
    if Found then
    begin
      Parts := TJSArray(Found);
      Area2.value := '';
      Fit(Area2);
      if not Parts[2] then
      begin
        Note(T('Use: /msg name text'), Truthy(Parent));
        Exit;
      end;
      await(JSValue, Route('/dm/' + Enc(Parts[2]), True));
      if Truthy(Parts[3]) and (S.view = 'dm') then
        try
          await(SendDm(S.dm, String(Parts[3]), TJSArray.new));
        except
          Failed(JSExceptValue);
        end;
      Exit;
    end;
    Send.disabled := True;
    Sending := True;
    // what goes now; what is typed or uploaded while it goes stays for the next
    Sent := Pending.slice(0);
    try
      try
        if Truthy(Dm) and await(DmCommand(Text)) then Sent.Length := 0
        else if Dm then await(SendDm(DmName, Text, Sent))
        else
        begin
          Re := Answered(DraftKey);
          if Truthy(Parent) then ParentOr := Parent else ParentOr := '';
          if Truthy(Re) then ReId := Re['id'] else ReId := '';
          Said := TSaid(TJSJSON.parse(await(string, Post('/api/post', new(['room', S.room, 'parent', ParentOr,
            'body', Text, 'files', Sent.map(function(F: JSValue; N: NativeInt; A: TJSArray): JSValue
              begin
                Result := TJSObject(F)['token'];
              end).join(','), 're', ReId])))));
          if Re = Answered(DraftKey) then Answer;
          if Truthy(Said.info) then Note(Said.info, Truthy(Parent));
          if Truthy(Said.go) then
          begin
            Area2.value := '';
            Send.disabled := False;
            if Truthy(Said.info) then Toast(Said.info);
            // After /part the room is gone from the sidebar.
            if Said.go = '/' then
              S.rooms := S.rooms.filter(function(R: JSValue; N: NativeInt; A: TJSArray): boolean
                begin
                  Result := not Same(TJSObject(R)['slug'], S.room);
                end);
            RoomsWanted := True;
            Route(Said.go, True);
            Exit;
          end;
        end;
        if TJSString(Area2.value).trim = Text then Area2.value := '';
        for I := 0 to Sent.length - 1 do
        begin
          P := Sent[I];
          At := Pending.indexOf(P);
          if At >= 0 then Pending.splice(At, 1);
          if Chips.has(P) then
          begin
            TEl(Chips.get(P)).remove;
            Chips.delete(P);
          end;
        end;
        Fit(Area2);
        if not Dm then SyncNow(TJSString(Text).startsWith('/'));
      except
        Failed(JSExceptValue);
      end;
    finally
      Sending := False;
    end;
    Send.disabled := False;
    Area2.focus;
  end;

begin
  Area.replaceChildren;
  if Me.name = '' then
  begin
    Area.appendChild(JoinForm(T('Pick a name and a password to join the conversation.')));
    Exit;
  end;
  if Me.verified = False then
  begin
    Area.appendChild(ConfirmBox);
    Exit;
  end;
  if not Truthy(Dm) and Truthy(S.info) then
    if (Truthy(Parent) and Same(S.info.can_reply, False)) or (not Truthy(Parent) and not S.info.can_start) then
    begin
      Area.appendChild(El('p', 'notice', S.info.why_not));
      Exit;
    end;
  // the name as text: only used where a conversation is open
  DmName := String(Dm);
  Form := El('form', 'composer');
  Files := El('div', 'attachments');
  Row := El('div', 'box');
  Attach := IconButton('attach', T('Attach a file (or paste or drop one)'));
  Area2 := TArea(TJSHTMLElement(El('textarea')));
  Area2.rows := 1;
  Area2.maxLength := 8000;
  if Dm then Words := T('Private message to %s', Dm)
  else if Truthy(Parent) then Words := T('Reply in the thread')
  else if Truthy(S.info) and (S.info.kind = 'shelf') then Words := T('Put something on your shelf')
  else if Truthy(S.info) then Words := T('Message %s', RoomTitle(S.info))
  else Words := T('Message %s', '');
  Area2.placeholder := Words;
  // What was typed and not sent waits here for the next visit.
  if Dm then DraftKey := 'dm ' + DmName
  else if Truthy(Parent) then DraftKey := 'thread ' + String(JSValue(Parent))
  else DraftKey := 'room ' + S.room;
  Draft := Drafts.get(DraftKey);
  if not Draft then Draft := '';
  Area2.value := String(Draft);
  Code := IconButton('code', T('Code block'));
  Send := TJSHTMLButtonElement(TJSHTMLElement(El('button', 'send', T('Send'))));
  Row.append(Attach, Area2, Code);
  Answering := El('div', 'answering');
  Answering.dataset['key'] := DraftKey;
  // an answer begun in another channel or conversation, or in another thread, is dropped
  if Truthy(S.answer) and (S.answer.key <> DraftKey) and
    (not Truthy(Parent) or TJSString(S.answer.key).startsWith('thread ')) then S.answer := nil;
  if Dm then
  begin
    Beam := IconButton('beam', T('Beam a file: straight to them, never stored here'));
    Beam.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Pick(BeamPick, Beam); end));
    Row.appendChild(Beam);
  end;
  Row.appendChild(Send);
  FilePick := TJSHTMLInputElement(TJSHTMLElement(El('input')));
  FilePick._type := 'file';
  FilePick.multiple := True;
  FilePick.hidden := True;
  BeamPick := TJSHTMLInputElement(TJSHTMLElement(El('input')));
  BeamPick._type := 'file';
  BeamPick.hidden := True;
  Options := El('div', 'options');
  Expire := TJSHTMLSelectElement(TJSHTMLElement(El('select')));
  Choice('', T('Keep files'));
  Choice('hour', T('Delete after an hour'));
  Choice('day', T('Delete after a day'));
  Choice('week', T('Delete after a week'));
  Choice('once', T('Delete after one download'));
  Options.appendChild(Expire);
  Options.appendChild(El('span', 'hints', T('Enter sends · Shift+Enter new line · ``` for code · / for commands')));
  Form.append(Answering, Files, Row, Options, FilePick, BeamPick);
  Area.appendChild(Form);
  ShowAnswer;
  Pending := TJSArray.new;
  // each upload's chip, apart from the upload itself, which may be sent as it is
  Chips := TJSMap.new;
  // the uploads still on their way: Send waits for them
  Busy := TJSSet.new;
  Asking := TJSSet.new;

  Attach.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Pick(FilePick, Attach); end));
  FilePick.addEventListener('change', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      Add(TJSArray.from(FilePick.files));
      FilePick.value := '';
    end));
  BeamPick.addEventListener('change', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      First: JSValue;
    begin
      First := TJSObject(BeamPick.files)['0'];
      if First then BeamFile(DmName, TJSObject(First));
      BeamPick.value := '';
    end));
  Area2.addEventListener('paste', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Given: JSValue;
      List: TJSArray;
    begin
      Given := TJSObject(TJSObject(E)['clipboardData'])['files'];
      if not Given then Given := TJSArray.new;
      List := TJSArray.from(Given);
      if List.length > 0 then
      begin
        E.preventDefault;
        Add(List);
      end;
    end));
  Form.addEventListener('dragover', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      E.preventDefault;
      Form.classList.add('drop');
    end));
  Form.addEventListener('dragleave', TJSRawEventHandler(procedure(E: TJSEvent) begin Form.classList.remove('drop'); end));
  Form.addEventListener('drop', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      E.preventDefault;
      Form.classList.remove('drop');
      Add(TJSArray.from(TJSObject(TJSObject(E)['dataTransfer'])['files']));
    end));
  Code.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      At: NativeInt;
      Selected: string;
    begin
      At := Area2.selectionStart;
      Selected := TJSString(Area2.value).slice(At, Area2.selectionEnd);
      Area2.setRangeText('```'#10 + Selected + #10'```', At, Area2.selectionEnd, 'end');
      Area2.selectionEnd := At + 4 + Length(Selected);
      Area2.selectionStart := At + 4 + Length(Selected);
      Area2.focus;
      Fit(Area2);
    end));

  // a private conversation offers the commands that need no channel
  Complete := Completer(Area2, function(Command: TJSObject): boolean
    begin
      Result := not Truthy(Dm) or Truthy(Command['anywhere']);
    end);

  Sending := False;
  Form.addEventListener('submit', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      E.preventDefault;
      Submit;
    end));
  Area2.addEventListener('keydown', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Key: TJSKeyboardEvent;
      Mine: TJSArray;
      Map: TJSMap;
    begin
      Key := TJSKeyboardEvent(E);
      if Complete.handle(Key) then Exit;
      if (Key.key = 'Escape') and Truthy(Answered(DraftKey)) then Answer;
      if (Key.key = 'Enter') and not Key.shiftKey and not InFence(Area2) then
      begin
        E.preventDefault;
        Submit;
      end;
      if (Key.key = 'ArrowUp') and (Area2.value = '') and Truthy(Dm) then
      begin
        Mine := TJSArray.from(Stream.querySelectorAll('.msg')).filter(function(X: JSValue; N: NativeInt; A: TJSArray): boolean
          var
            D: TJSObject;
          begin
            D := TEl(X).dm;
            Result := Truthy(D) and Same(TJSObject(D['m'])['from'], Me.name) and
              (Same(TJSObject(D['payload'])['t'], 'text') or Same(TJSObject(D['payload'])['t'], 'file'));
          end);
        if Mine.length > 0 then
        begin
          E.preventDefault;
          StartDmEdit(TEl(Mine[Mine.length - 1]));
        end;
      end
      else if (Key.key = 'ArrowUp') and (Area2.value = '') then
      begin
        if Truthy(Parent) then Map := S.threadMessages else Map := S.messages;
        Mine := TJSArray.from(Map.values).filter(function(X: JSValue; N: NativeInt; A: TJSArray): boolean
          var
            D: TMsg;
          begin
            D := TMsg(TJSObject(X)['data']);
            Result := (D.name = Me.name) and not D.deleted and Truthy(D.uid);
          end);
        if Mine.length > 0 then
        begin
          E.preventDefault;
          StartEdit(TMsg(TJSObject(Mine[Mine.length - 1])['data']));
        end;
      end;
    end));
  Area2.addEventListener('input', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      Drafts.&set(DraftKey, Area2.value);
      Fit(Area2);
      Complete.update;
      if (TJSDate.now - S.typingSent > 3000) and (Area2.value <> '') then
      begin
        S.typingSent := TJSDate.now;
        if Dm then Post('/api/dm/typing', new(['to', Dm])).catch(function(Err: JSValue): JSValue begin end)
        else Post('/api/typing', new(['room', S.room])).catch(function(Err: JSValue): JSValue begin end);
      end;
    end));
  Fit(Area2);
  if not Truthy(Parent) then Area2.focus;
end;

// Private text may be sealed, so commands are detected in the page. Unknown
// commands and /me with words remain messages; the others go to the server
// without a channel and answer only this member.
function DmCommand(const Text: string): boolean; async;
var
  Found: JSValue;
  Parts: TJSArray;
  Said: TSaid;
begin
  Found := JSValue(TJSString(Text).match(TJSRegexp.new('^\/(\S+)(?:\s+([\s\S]*))?$')));
  if not Found then Exit(False);
  Parts := TJSArray(Found);
  if (TJSString(Parts[1]).toLowerCase = 'me') and Truthy(Parts[2]) then Exit(False);
  if not Truthy(S.commands) then S.commands := await(TJSArray, Get('/api/commands'));
  if not S.commands.some(function(C: JSValue; N: NativeInt; A: TJSArray): boolean
    begin
      Result := Same(TJSObject(C)['name'], TJSString(Parts[1]).toLowerCase);
    end) then Exit(False);
  Said := TSaid(TJSJSON.parse(await(string, Post('/api/post', new(['body', Text])))));
  if Truthy(Said.info) then Note(Said.info);
  if Truthy(Said.go) then
  begin
    RoomsWanted := True;
    Route(Said.go, True);
  end;
  Result := True;
end;

// A note only this member sees, such as /help's answer.
procedure Note(const Text: string; InThread: boolean);
var
  Box, N, X: TEl;
begin
  if InThread then Box := Find('.threadlist', Panel) else Box := Stream;
  N := El('div', 'note');
  N.appendChild(El('pre', '', Text));
  X := El('button', '', T('Dismiss'));
  TJSHTMLButtonElement(TJSHTMLElement(X))._type := 'button';
  X.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin N.remove; end));
  N.appendChild(X);
  Box.appendChild(N);
  Box.scrollTop := Box.scrollHeight;
end;

procedure Start;
var
  View: JSValue;
  Target: TJSEventTarget;
begin
  // the keyboard opening, or changing its height, changes the room a box has
  View := TJSObject(window)['visualViewport'];
  if View then Target := TJSEventTarget(View) else Target := window;
  Target.addEventListener('resize', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Areas: TJSNodeList;
      I: NativeInt;
    begin
      Areas := document.querySelectorAll('.composer textarea');
      for I := 0 to Areas.length - 1 do Fit(TJSHTMLTextAreaElement(Areas[I]));
    end));
  Drafts := TJSMap.new;
end;

end.
