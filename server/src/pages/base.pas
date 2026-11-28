unit BasePage;

{ A site under a path of its domain (https://example.com/community): the
  scripts go on writing addresses that start at /, and this puts the
  path, the base, before them where they leave the page: requests, links,
  pictures, forms and the address bar.  The page's first script after the
  runtime.  With no base it only defines the helpers, which change nothing. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web;

implementation

uses PageKit;

type
  TWrapped = reference to function: JSValue;
  TWrappedTwo = reference to function(A, B: JSValue): JSValue;
  TWrappedThree = reference to function(A, B, C: JSValue): JSValue;
  TSetAttribute = reference to function(const Name: string; Value: JSValue): JSValue;
  TSetter = reference to procedure(Value: JSValue);
  TValues = array of JSValue;

var
  Base: string;
  RequestProto: TJSObject; external name 'XMLHttpRequest.prototype';
  ElementProto: TJSObject; external name 'Element.prototype';
  AnchorProto: TJSObject; external name 'HTMLAnchorElement.prototype';
  LinkProto: TJSObject; external name 'HTMLLinkElement.prototype';
  ImageProto: TJSObject; external name 'HTMLImageElement.prototype';
  ScriptProto: TJSObject; external name 'HTMLScriptElement.prototype';
  SourceProto: TJSObject; external name 'HTMLSourceElement.prototype';
  MediaProto: TJSObject; external name 'HTMLMediaElement.prototype';
  FormProto: TJSObject; external name 'HTMLFormElement.prototype';

// an address that starts at / with the base before it; anything else as it is
function Url(Address: JSValue): JSValue;
begin
  if (Base <> '') and isString(Address) and (TJSString(Address).charAt(0) = '/') and (TJSString(Address).charAt(1) <> '/') then
    Result := Base + String(Address)
  else
    Result := Address;
end;

// the other way: the base taken off an address read from the page or the bar
function Strip(Address: JSValue): JSValue;
var
  Rest, First: string;
begin
  Result := Address;
  if (Base = '') or not isString(Address) or (TJSString(Address).indexOf(Base) <> 0) then Exit;
  Rest := TJSString(Address).slice(Length(Base));
  First := TJSString(Rest).charAt(0);
  if Rest = '' then Result := '/'
  else if First = '/' then Result := Rest
  else if (First = '?') or (First = '#') then Result := '/' + Rest;
end;

function Path: JSValue;
begin
  Result := Strip(window.location.pathname);
end;

procedure WrapHistory(const Name: string);
var
  Now: TJSFunction;
begin
  Now := TJSFunction(TJSObject(window.history)[Name]);
  TJSObject(window.history)[Name] := TWrappedThree(function(State, Title, Address: JSValue): JSValue
    begin
      // isUndefined is also true for null, which has to be passed on.
      if jsTypeOf(Address) = 'undefined' then Result := Now.call(window.history, State, Title)
      else Result := Now.call(window.history, State, Title, Url(Address));
    end);
end;

// el.href = '/x', img.src = '/x', form.action = '/x'
procedure Prefix(Proto: TJSObject; const Name: string);
var
  D: TJSObject;
begin
  D := TJSObject(TJSObject.getOwnPropertyDescriptor(Proto, Name));
  if not Truthy(D) or not Truthy(D['set']) then Exit;
  TJSObject.defineProperty(Proto, Name, new(['configurable', True, 'enumerable', D['enumerable'], 'get', D['get'],
    'set', TSetter(procedure(Value: JSValue) begin TJSFunction(D['set']).call(JSThis, Url(Value)); end)]));
end;

procedure Start;
var
  FetchNow, OpenNow, SetNow: TJSFunction;
begin
  Base := '';
  try
    Base := TJSString(TJSURL.new(TJSHTMLScriptElement(document.currentScript).src).pathname).replace(
      TJSRegexp.new('\/static\/base\.js$'), '');
  except
  end;
  TJSObject(window)['SiteBase'] := new(['base', Base, 'url', @Url, 'strip', @Strip, 'path', @Path]);
  if Base = '' then Exit;

  FetchNow := TJSFunction(TJSObject(window)['fetch']);
  TJSObject(window)['fetch'] := TWrappedTwo(function(Input, Init: JSValue): JSValue
    begin Result := FetchNow.call(JSThis, Url(Input), Init); end);
  OpenNow := TJSFunction(RequestProto['open']);
  RequestProto['open'] := TWrapped(function: JSValue
    begin
      JSArguments[1] := Url(JSArguments[1]);
      Result := OpenNow.apply(JSThis, TValues(JSValue(JSArguments)));
    end);
  WrapHistory('pushState');
  WrapHistory('replaceState');
  Prefix(AnchorProto, 'href');
  Prefix(LinkProto, 'href');
  Prefix(ImageProto, 'src');
  Prefix(ScriptProto, 'src');
  Prefix(SourceProto, 'src');
  Prefix(MediaProto, 'src');
  Prefix(FormProto, 'action');
  SetNow := TJSFunction(ElementProto['setAttribute']);
  ElementProto['setAttribute'] := TSetAttribute(function(const Name: string; Value: JSValue): JSValue
    begin
      if (Name = 'href') or (Name = 'src') or (Name = 'action') or (Name = 'poster') then Value := Url(Value);
      Result := SetNow.call(JSThis, Name, Value);
    end);
end;

initialization
  Start;
end.
