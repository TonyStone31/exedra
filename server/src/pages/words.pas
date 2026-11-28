unit WordsPage;

{ The site's words in the reader's language.  window.WORDS comes from
  /words.js, which the page loads first; the English text is the key, so a
  word with no translation shows as English.  %s and %d fill in order;
  %1:s picks an argument by number, for languages that reorder a sentence. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web;

implementation

uses PageKit;

type
  TValues = array of JSValue;
  // TJSDate takes no JSValue and its time text takes no options.
  TDate = class external name 'Date'(TJSObject)
    constructor new(Value: JSValue);
    function getFullYear: NativeInt;
    function getMonth: NativeInt;
    function getDate: NativeInt;
    function toLocaleDateString(Locale: JSValue): string;
    function toLocaleTimeString(Locale: JSValue; Options: TJSObject): string;
  end;
  TPageBase = class external name 'Object'(TJSObject)
    function url(const Address: string): string;
    function path: string;
  end;
  TPublished = class external name 'Object'(TJSObject)
    t: TJSFunction;
    function dateText(Value: JSValue): string;
    function dateTimeText(Value: JSValue): string;
  end;

var
  Words: TJSObject;
  SiteBase: TPageBase; external name 'SiteBase';
  Page: TPublished; external name 'window';
  DateClass: JSValue; external name 'Date';

// A cast to string joins with '', which asks an object for valueOf first.
function Text(Value: JSValue): string; external name 'String';
function Number(Value: JSValue): double; external name 'Number';
function Owns(Obj: TJSObject; Key: JSValue): boolean; external name 'Object.prototype.hasOwnProperty.call';
function Slice(Args: JSValue; First: NativeInt): TJSArray; external name 'Array.prototype.slice.call';
// A [] accessor takes only a string or a whole number as its key; this reads by the value itself.
function Prop(Obj, Key: JSValue): JSValue; external name 'Reflect.get';

function T(English: JSValue): string;
var
  Args: TJSArray;
  Found: JSValue;
  Next: NativeInt;
begin
  Args := Slice(JSArguments, 1);
  if Owns(Words, English) and Truthy(Prop(Words, English)) then Found := Prop(Words, English)
  else Found := English;
  Next := 0;
  Result := TJSString(Found).replace(TJSRegexp.new('%(?:(\d+):)?[sd]', 'g'),
    function(const Whole, Digits: string; Offset: Integer; Whole2: string): string
    var
      At: double;
    begin
      if jsTypeOf(Digits) = 'undefined' then begin At := Next; Inc(Next); end
      else At := Number(Digits);
      if At < Args.length then Result := Text(Prop(Args, At)) else Result := Whole;
    end);
end;

// A sentence about a number, with %d in both forms: tn(3, '%d reply', '%d replies').
function TN(N: double; One, Many: JSValue): JSValue;
var
  Form: JSValue;
begin
  if N = 1 then Form := One else Form := Many;
  Result := Page.t.apply(nil, TValues(TJSArray.new(Form, N).concat(Slice(JSArguments, 3))));
end;

// Dates as the admin chose to show them (window.DATE_FORMAT, m-d-yyyy to
// begin with); "reader" gives the reader's own language.  A date-only text
// is that day wherever the reader is; a time is in the reader's time zone.
function Parts(Value: JSValue): TJSObject;
var
  Date: TDate;
begin
  if isString(Value) and TJSRegexp.new('^\d{4}-\d{2}-\d{2}$').test(String(Value)) then
    Exit(new(['y', Number(TJSString(Value).slice(0, 4)), 'm', Number(TJSString(Value).slice(5, 7)),
      'd', Number(TJSString(Value).slice(8, 10)), 'date', TDate.new(String(Value) + 'T00:00:00')]));
  if jsInstanceOf(Value, DateClass) then Date := TDate(Value) else Date := TDate.new(Value);
  if jsIsNaN(Date) then Result := nil
  else Result := new(['y', Date.getFullYear, 'm', Date.getMonth + 1, 'd', Date.getDate, 'date', Date]);
end;

function Lang: JSValue;
begin
  Result := TJSHTMLElement(document.documentElement).lang;
  if not Truthy(Result) then Result := undefined;
end;

function Two(N: JSValue): string;
begin
  Result := TJSString(Text(N)).padStart(2, '0');
end;

function DateText(Value: JSValue): string;
var
  P: TJSObject;
  Pattern: JSValue;
begin
  P := Parts(Value);
  if P = nil then
  begin
    if Truthy(Value) then Exit(Text(Value));
    Exit(Text(''));
  end;
  Pattern := TJSObject(window)['DATE_FORMAT'];
  if not Truthy(Pattern) then Pattern := 'm-d-yyyy';
  if Pattern = 'reader' then Exit(TDate(P['date']).toLocaleDateString(Lang));
  Result := TJSString(Pattern).replace(TJSRegexp.new('yyyy|mm|dd|m|d', 'g'),
    function(const K: string): string
    begin
      if K = 'yyyy' then Result := Text(P['y'])
      else if K = 'mm' then Result := Two(P['m'])
      else if K = 'dd' then Result := Two(P['d'])
      else if K = 'm' then Result := Text(P['m'])
      else Result := Text(P['d']);
    end);
end;

function DateTimeText(Value: JSValue): string;
var
  P: TJSObject;
begin
  P := Parts(Value);
  if P = nil then
  begin
    if Truthy(Value) then Exit(Text(Value));
    Exit(Text(''));
  end;
  Result := Page.dateText(Value) + ' ' +
    TDate(P['date']).toLocaleTimeString(Lang, new(['hour', 'numeric', 'minute', '2-digit']));
end;

// The picker works without scripts by its button.  With them it goes on a
// change, and comes back to wherever the page has moved to since it loaded.
procedure Language(Form: TJSHTMLFormElement);
var
  Button: TJSHTMLElement;
begin
  Button := TJSHTMLElement(Form.querySelector('button'));
  if Button <> nil then Button.hidden := True;
  Form.querySelector('select').addEventListener('change', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      TJSHTMLInputElement(Form.querySelector('[name=return]')).value := SiteBase.path + window.location.search;
      Form.submit;
    end));
end;

procedure Ready(E: TJSEvent);
var
  List: TJSNodeList;
  I: NativeInt;
  El: TJSHTMLElement;
  At: string;
begin
  // in the reader's own language: the dates the server left as yyyy-mm-dd
  if TJSObject(window)['DATE_FORMAT'] = 'reader' then
  begin
    List := document.querySelectorAll('time[data-show]');
    for I := 0 to List.length - 1 do
    begin
      El := TJSHTMLElement(List[I]);
      At := El.getAttribute('datetime');
      if El.dataset['show'] = 'datetime' then El.textContent := Page.dateTimeText(At)
      else El.textContent := Page.dateText(TJSString(At).slice(0, 10));
    end;
  end;
  // Sign in and Join bring the reader back to this page afterwards.
  if SiteBase.path <> '/signin' then
  begin
    List := document.querySelectorAll('a[href="' + SiteBase.url('/signin') + '"]');
    for I := 0 to List.length - 1 do
      TJSHTMLAnchorElement(List[I]).href := '/signin?return=' + encodeURIComponent(SiteBase.path + window.location.search);
  end;
  List := document.querySelectorAll('.site-language');
  for I := 0 to List.length - 1 do Language(TJSHTMLFormElement(List[I]));
end;

procedure Start;
begin
  Words := TJSObject(TJSObject(window)['WORDS']);
  if not Truthy(Words) then Words := TJSObject.new;
  TJSObject(window)['t'] := @T;
  TJSObject(window)['tn'] := @TN;
  TJSObject(window)['dateText'] := @DateText;
  TJSObject(window)['dateTimeText'] := @DateTimeText;
  document.addEventListener('DOMContentLoaded', TJSRawEventHandler(@Ready));
end;

initialization
  Start;
end.
