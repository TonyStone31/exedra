unit PageKit;

{$mode objfpc}

interface

uses JS, Web;

function MakeElement(const Tag: string; const Cls: string = ''): TJSHTMLElement;
function Word(const English: string): string;
function Truthy(Value: JSValue): boolean; external name 'Boolean';
function Closest(Target: TJSEventTarget; const Selector: string): TJSElement;
function Get(const Url: string; Options: TJSObject = nil): TJSResponse; async;
function Post(const Url: string; Body: JSValue; Headers: TJSObject = nil): TJSResponse; async;

implementation

uses PageGlobals;

// Requests use the site's fetch wrapper; each caller handles its response.
function Get(const Url: string; Options: TJSObject): TJSResponse; async;
begin
  if Options = nil then Options := new(['credentials', 'same-origin']);
  Result := await(TJSResponse, window.fetch(Url, Options));
end;

function Post(const Url: string; Body: JSValue; Headers: TJSObject): TJSResponse; async;
var
  Options: TJSObject;
begin
  Options := new(['method', 'POST', 'credentials', 'same-origin', 'body', Body]);
  if Headers <> nil then Options['headers'] := Headers;
  Result := await(TJSResponse, window.fetch(Url, Options));
end;

function Closest(Target: TJSEventTarget; const Selector: string): TJSElement;
begin
  Result := nil;
  if (Target <> nil) and Truthy(TJSObject(Target)['closest']) then
    Result := TJSElement(Target).closest(Selector);
end;

function Word(const English: string): string;
begin
  Result := T(English);
end;

function MakeElement(const Tag: string; const Cls: string): TJSHTMLElement;
begin
  Result := TJSHTMLElement(document.createElement(Tag));
  if Cls <> '' then Result.className := Cls;
end;

end.
