unit chat_answer;

{ Answering a message: its first words, the quote over the answer, the strip over the box. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, chat_shared;

function FirstWords(const Text: string): string;
procedure Flash(There: TEl);
function SaidIn(Re: TJSObject): string;
function QuoteOf(Re: TJSObject; Far: TProc): TEl;
// The strip over the box whose draft has this key; undefined when there is none.
function AnswerStrip(const Key: string): JSValue;
procedure ShowAnswer;
// Without a message the answer is dropped.
procedure Answer(const Key: string = ''; Re: TJSObject = nil);
function Answered(const Key: string): TJSObject;

implementation

type
  // A button's own properties ([] on an element reads and writes attributes).
  TCtl = class external name 'HTMLElement'(TEl)
    &type: string;
    disabled: boolean;
  end;
  // The message another one answers: its number, who wrote it and how it starts.
  TRe = class external name 'Object'(TJSObject)
    id: JSValue;
    from: string;
    text: string;
    gone: boolean;
  end;

// A message's first words on one line: code blocks and markup signs out.
function FirstWords(const Text: string): string;
var
  Words: string;
begin
  Words := TJSString(Text).replace(TJSRegexp.new('```[\s\S]*?(```|$)', 'g'), ' ');
  Words := TJSString(Words).replace(TJSRegexp.new('[*_~`]+', 'g'), '');
  Words := TJSString(Words).replace(TJSRegexp.new('\s+', 'g'), ' ');
  Result := TJSString(TJSString(Words).trim).slice(0, 140);
end;

// Shows a message in its list, lit for a moment.
procedure Flash(There: TEl);
begin
  There.scrollIntoView(new(['block', 'center']));
  There.classList.add('flash');
  window.setTimeout(procedure begin There.classList.remove('flash'); end, 1600);
end;

// The words of an answered message beside its author's name. An action's own
// words begin with that name (Ann waves), which is not said twice.
function SaidIn(Re: TJSObject): string;
var
  R: TRe;
begin
  R := TRe(Re);
  if TJSString(R.text).startsWith(R.from + ' ') then Result := TJSString(R.text).slice(TJSString(R.from).length + 1)
  else Result := R.text;
end;

// The message another one answers, on a line above its words, as text and
// never as HTML. A click goes to it in its list; Far is for one not loaded there.
function QuoteOf(Re: TJSObject; Far: TProc): TEl;
var
  R: TRe;
  Quote: TEl;
begin
  R := TRe(Re);
  Quote := El('button', 'quote');
  TCtl(Quote).&type := 'button';
  if R.gone then
  begin
    Quote.textContent := T('a deleted message');
    TCtl(Quote).disabled := True;
    Exit(Quote);
  end;
  Quote.append(El('b', '', TJSString(R.from).slice(0, 60)),
    document.createTextNode(' ' + TJSString(SaidIn(R)).slice(0, 140)));
  Quote.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      List, There: TJSElement;
    begin
      List := Quote.closest('.threadlist');
      if List = nil then List := Stream;
      There := List.querySelector('.msg[data-id="' + String(JSValue(ParseInt(R.id, 10))) + '"]');
      if There <> nil then Flash(TEl(There))
      else Far();
    end));
  Result := Quote;
end;

function AnswerStrip(const Key: string): JSValue;
var
  Strips: TJSNodeList;
  I: NativeInt;
begin
  Result := undefined;
  Strips := document.querySelectorAll('.composer .answering');
  for I := 0 to Strips.length - 1 do
    if TEl(Strips[I]).dataset['key'] = Key then Exit(Strips[I]);
end;

// S.answer is the message being answered and the box it is answered from.
// Its strip says so until the answer is sent or dropped.
procedure ShowAnswer;
var
  Strips: TJSNodeList;
  I: NativeInt;

  procedure Show(Strip: TEl);
  var
    Re: TRe;
    Area, Stop: TEl;
  begin
    if Truthy(S.answer) and (S.answer.key = Strip.dataset['key']) then Re := TRe(S.answer.re) else Re := nil;
    Strip.replaceChildren;
    Strip.hidden := not Truthy(Re);
    if not Truthy(Re) then Exit;
    Area := TEl(TJSElement(Strip.parentNode).querySelector('textarea'));
    Stop := IconButton('close', T('Do not answer it after all'));
    Stop.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        Answer;
        Area.focus;
      end));
    Strip.append(El('span', '', T('Answering %s:', Re.from) + ' ' + SaidIn(Re)), Stop);
    Area.focus;
  end;

begin
  Strips := document.querySelectorAll('.composer .answering');
  for I := 0 to Strips.length - 1 do Show(TEl(Strips[I]));
end;

procedure Answer(const Key: string; Re: TJSObject);
begin
  if Truthy(Re) then S.answer := TAnswer(new(['key', Key, 're', Re])) else S.answer := nil;
  ShowAnswer;
end;

// The message this box's next one answers, if any.
function Answered(const Key: string): TJSObject;
begin
  if Truthy(S.answer) and (S.answer.key = Key) then Result := S.answer.re else Result := nil;
end;

end.
