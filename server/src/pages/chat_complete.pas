unit chat_complete;

{ Offers for @member, #room, :emoji and /command as they are typed. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, chat_shared;

type
  TCommandTest = reference to function(Command: TJSObject): boolean;
  TCompleter = class external name 'Object'(TJSObject)
    procedure update;
    function handle(E: TJSKeyboardEvent): boolean;
  end;

function EmojiSet: TJSArray; async;
// Commands says which commands the box offers; nil for a box with none.
function Completer(Area: TJSHTMLTextAreaElement; Commands: TCommandTest = nil): TCompleter;

implementation

type
  // The word being typed: its kind (@ # : /), its text and where it starts.
  TWord = class external name 'Object'(TJSObject)
    kind: string;
    text: string;
    at: NativeInt;
    whole: boolean;
  end;
  // One offer: what the row shows and what picking it puts in the box.
  TOffer = class external name 'Object'(TJSObject)
    &label: JSValue;
    hint: JSValue;
    insert: string;
  end;
  // A room as the side list and other scripts know it.
  TRoomRow = class external name 'Object'(TJSObject)
    slug: string;
    kind: string;
    title: JSValue;
  end;
  TMoreRooms = reference to function(const Text: string): JSValue;

// The emoji a name can be typed for (emoji-names.js).  A reaction of this
// site that the list lacks answers to "reaction".
function EmojiSet: TJSArray; async;
var
  List, Mine: TJSArray;
begin
  List := await(TJSArray, EmojiNames.list());
  if Truthy(Me.reactions) then Mine := TJSArray(Me.reactions['shown']).concat(Me.reactions['more'])
  else Mine := TJSArray.new;
  Result := List.concat(Mine.filter(function(R: JSValue; I: NativeInt; A: TJSArray): boolean
    begin
      Result := not List.some(function(E: JSValue; J: NativeInt; B: TJSArray): boolean
        begin
          Result := Same(TJSObject(E)['emoji'], R);
        end);
    end).map(function(R: JSValue; I: NativeInt; A: TJSArray): JSValue
    begin
      Result := new(['emoji', R, 'name', 'reaction', 'keywords', TJSArray._of('reaction')]);
    end));
end;

function Completer(Area: TJSHTMLTextAreaElement; Commands: TCommandTest): TCompleter;
var
  Box: TEl;
  Holder: TJSNode;
  Items: TJSArray;
  Index, Start, Ahead, Timer: NativeInt;
  Eager: boolean;      // opened by an arrow key: a colon alone is enough
  TypedAt: NativeInt;  // where the caret was left by typing: arrows open the list only there
  Waiting: boolean;    // a lookup is under way
  Taking: boolean;     // Enter or Tab pressed after arrow keys, while the list was on its way
  Asked: NativeInt;    // counts the lookups: an answer that is not the latest is dropped

  procedure Close; forward;
  procedure Pick; forward;

  function WordAt: TWord;
  var
    Before: string;
    Found: JSValue;
    Parts: TJSArray;
    E: TJSObject;
  begin
    Before := TJSString(Area.value).slice(0, Area.selectionStart);
    Found := JSValue(TJSString(Before).match(TJSRegexp.new('(^|\s)([@#])([\w.-]*)$')));
    if not Found then
    begin
      if Commands <> nil then Found := JSValue(TJSString(Before).match(TJSRegexp.new('^(\/)([\w]*)$')))
      else Found := nil;
    end;
    Parts := TJSArray(Found);
    if Truthy(Found) and Same(Parts[1], '/') then Exit(TWord(new(['kind', '/', 'text', Parts[2], 'at', 0])));
    if Found then
      Exit(TWord(new(['kind', Parts[2], 'text', Parts[3], 'at', Length(Before) - TJSString(Parts[3]).length - 1])));
    // :name for an emoji; the closing colon of :name: makes it the emoji at once
    E := EmojiNames.typed(Area.value, Area.selectionStart, Eager);
    if not Truthy(E) then Exit(TWord(E));
    Result := TWord(new(['kind', ':', 'text', E['word'], 'at', E['from'], 'whole', E['whole']]));
  end;

  // The one selected row, for the keys and the pointer alike, kept in view.
  procedure Select(I: NativeInt);
  var
    N: NativeInt;
    Rows: TJSArray;
    Row: TJSHTMLElement;
  begin
    Index := I;
    Rows := TJSArray.from(Box.children);
    for N := 0 to Rows.length - 1 do Toggle(TJSElement(Rows[N]), 'on', N = I);
    Row := TJSHTMLElement(TJSObject(Box.children)[String(JSValue(I))]);
    TJSObject(Box)['scrollTop'] := Min(Row.offsetTop, Max(Box.scrollTop, Row.offsetTop + Row.offsetHeight - Box.clientHeight));
  end;

  procedure Show(List: TJSArray);
  var
    I: NativeInt;
    Now: boolean;

    procedure AddRow(It: TOffer; N: NativeInt);
    var
      Row: TEl;
    begin
      Row := El('div', 'item');
      Row.appendChild(El('b', '', It.&label));
      if It.hint then Row.appendChild(El('span', '', It.hint));
      Row.addEventListener('mousemove', TJSRawEventHandler(procedure(E: TJSEvent)
        begin
          if Index <> N then Select(N);
        end));
      Row.addEventListener('mousedown', TJSRawEventHandler(procedure(E: TJSEvent)
        begin
          E.preventDefault;
          Index := N;
          Pick;
        end));
      Box.appendChild(Row);
    end;

  begin
    Items := List.slice(0, 8);
    Box.replaceChildren;
    Box.hidden := Items.length = 0;
    for I := 0 to Items.length - 1 do AddRow(TOffer(Items[I]), I);
    // arrow keys pressed while the list was on its way count from its first row
    if Items.length > 0 then Select(((Ahead mod Items.length) + Items.length) mod Items.length);
    Now := Taking;
    Waiting := False;
    Taking := False;
    Ahead := 0;
    if Now then Pick;
  end;

  procedure Close;
  begin
    Box.hidden := True;
    Items := TJSArray.new;
    Eager := False;
    Waiting := False;
    Taking := False;
    Ahead := 0;
  end;

  procedure Pick;
  var
    It: TOffer;
  begin
    It := TOffer(Items[Index]);
    if not Truthy(It) then Exit;
    TArea(Area).setRangeText(It.insert, Start, Area.selectionStart, 'end');
    Close;
    Area.focus;
  end;

  // What fits the word, for every kind alike: label, hint, insert.
  function Found(W: TWord; Turn: NativeInt): TJSArray; async;
  var
    Low: string;
    All, Emoji: TJSArray;
    I: NativeInt;
    Seen, Named: TJSObject;
    More: TMoreRooms;
  begin
    Low := TJSString(W.text).toLowerCase;
    if W.kind = '@' then
      Exit(await(TJSArray, Get('/api/users?q=' + Enc(W.text))).map(function(U: JSValue; N: NativeInt; A: TJSArray): JSValue
        begin
          Result := new(['label', '@' + String(TJSObject(U)['name']), 'insert', '@' + String(TJSObject(U)['name']) + ' ']);
        end));
    if W.kind = '#' then
    begin
      All := S.rooms.filter(function(R: JSValue; N: NativeInt; A: TJSArray): boolean
        begin
          Result := TRoomRow(R).kind <> 'shelf';
        end).map(function(R: JSValue; N: NativeInt; A: TJSArray): JSValue
        begin
          Result := new(['slug', TRoomRow(R).slug, 'title', TRoomRow(R).title]);
        end);
      I := 0;
      while I < Extras.rooms.length do
      begin
        More := TMoreRooms(Extras.rooms[I]);
        All := All.concat(await(JSValue, More(W.text)));
        Inc(I);
      end;
      Seen := TJSObject.new;
      Exit(All.filter(function(R: JSValue; N: NativeInt; A: TJSArray): boolean
        begin
          if Truthy(Seen[TRoomRow(R).slug]) or not TJSString(TRoomRow(R).slug).startsWith(Low) then Exit(False);
          Seen[TRoomRow(R).slug] := True;
          Result := True;
        end).map(function(R: JSValue; N: NativeInt; A: TJSArray): JSValue
        begin
          Result := new(['label', '#' + TRoomRow(R).slug, 'hint', TRoomRow(R).title, 'insert', '#' + TRoomRow(R).slug + ' ']);
        end));
    end;
    if W.kind = ':' then
    begin
      Emoji := await(EmojiSet);
      if not W.whole then
        Exit(EmojiNames.matches(Emoji, W.text).map(function(E: JSValue; N: NativeInt; A: TJSArray): JSValue
          var
            Hint: JSValue;
          begin
            Hint := TJSObject(E)['match'];
            if not Hint then Hint := TJSArray(TJSObject(E)['keywords'])[0];
            Result := new(['label', TJSObject(E)['emoji'], 'hint', Hint, 'insert', String(TJSObject(E)['emoji']) + ' ']);
          end));
      Named := EmojiNames.named(Emoji, W.text);
      if Truthy(Named) and (Turn = Asked) and (Area.selectionStart = TypedAt) then
        TArea(Area).setRangeText(String(Named['emoji']), Start, TypedAt, 'end');
      Exit(TJSArray.new);
    end;
    if not Truthy(S.commands) then S.commands := await(TJSArray, Get('/api/commands'));
    Result := S.commands.filter(function(C: JSValue; N: NativeInt; A: TJSArray): boolean
      begin
        Result := Commands(TJSObject(C)) and TJSString(TJSObject(C)['name']).startsWith(Low);
      end).map(function(C: JSValue; N: NativeInt; A: TJSArray): JSValue
      begin
        Result := new(['label', '/' + String(TJSObject(C)['name']), 'hint', TJSObject(C)['usage'],
          'insert', '/' + String(TJSObject(C)['name']) + ' ']);
      end);
  end;

  procedure Update;
  var
    At, Turn, Wait: NativeInt;
    W: TWord;
  begin
    TypedAt := Area.selectionStart;
    At := TypedAt;
    W := WordAt;
    Inc(Asked);
    Turn := Asked;
    window.clearTimeout(Timer);
    if not Truthy(W) then
    begin
      Close;
      Exit;
    end;
    Start := W.at;
    Waiting := True;
    if W.kind = '@' then Wait := 150 else Wait := 0;
    Timer := window.setTimeout(procedure async
      var
        List: TJSArray;
      begin
        List := TJSArray.new;
        try
          List := await(Found(W, Turn));
        except
        end;
        // the caret has left meanwhile: nothing to offer there
        if Turn = Asked then
          if Area.selectionStart = At then Show(List) else Show(TJSArray.new);
      end, Wait);
  end;

  function Handle(E: TJSKeyboardEvent): boolean;
  var
    Arrow, Take: boolean;
    Step: NativeInt;
    W: TWord;
  begin
    Arrow := ((E.key = 'ArrowDown') or (E.key = 'ArrowUp')) and not E.shiftKey and not E.ctrlKey and not E.altKey
      and not E.metaKey;
    if E.key = 'ArrowDown' then Step := 1 else Step := -1;
    Take := (E.key = 'Enter') or (E.key = 'Tab');
    if Box.hidden or (Items.length = 0) then
    begin
      // the list is on its way: arrow keys are kept for it and the caret
      // stays, and Enter or Tab after them takes the row they lead to
      if Waiting and (Arrow or (Take and (Ahead <> 0))) then
      begin
        if Arrow then Ahead := Ahead + Step else Taking := True;
        E.preventDefault;
        Exit(True);
      end;
      if not Arrow then Exit(False);
      // an arrow key after a colon, or a colon and one letter, opens the list
      Eager := (Area.selectionStart = TypedAt) and (Area.selectionEnd = TypedAt);
      if Eager then W := WordAt else W := nil;
      if not Truthy(W) or (W.kind <> ':') or W.whole or (Length(W.text) > 1) then
      begin
        Eager := False;
        Exit(False);
      end;
      E.preventDefault;
      Update;
      Exit(True);
    end;
    if Arrow then
    begin
      E.preventDefault;
      Select((Index + Step + Items.length) mod Items.length);
      Exit(True);
    end;
    if Take then
    begin
      E.preventDefault;
      Pick;
      Exit(True);
    end;
    if E.key = 'Escape' then
    begin
      Close;
      TypedAt := -1;
      Exit(True);
    end;
    Result := False;
  end;

begin
  Box := El('div', 'complete');
  Box.hidden := True;
  Holder := Area.closest('.composer');
  if Holder = nil then Holder := Area.parentNode;
  Holder.appendChild(Box);
  Items := TJSArray.new;
  Index := 0;
  Start := 0;
  Eager := False;
  TypedAt := -1;
  Waiting := False;
  Ahead := 0;
  Taking := False;
  Timer := 0;
  Asked := 0;
  Area.addEventListener('blur', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      window.setTimeout(procedure begin Close; end, 150);
    end));
  Result := TCompleter(new(['update', @Update, 'handle', @Handle]));
end;

end.
