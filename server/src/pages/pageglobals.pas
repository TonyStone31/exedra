unit PageGlobals;

{$mode objfpc}
{$modeswitch externalclass}

interface

uses JS, Web;

type
  TPageSide = class external name 'Object'(TJSObject)
    function el(const Tag: string; Cls: JSValue = undefined; Text: JSValue = undefined): TJSHTMLElement;
    function icon(const Name: string): TJSHTMLElement;
    function iconButton(const Name, Title: string): TJSHTMLElement;
  end;
  TPageKeys = class external name 'Object'(TJSObject)
    procedure bindJoinForms(Done: TJSFunction);
    function setNewPassword(const Token, Name, Password: string): TJSPromise;
    function post(const Url: string; Data: TJSObject): TJSPromise;
    function signOut: TJSPromise;
  end;
  TPageBase = class external name 'Object'(TJSObject)
    function url(const Address: string): string;
    function strip(const Address: string): string;
  end;

  TPageTabs = class external name 'Object'(TJSObject)
    function holder(const Key: string): TJSHTMLElement;
    procedure count(const Key: string; N: NativeInt);
  end;
  TPageList = class external name 'Object'(TJSObject)
    function reload: TJSPromise;
    procedure unpick;
    procedure loading;
    procedure set_(Rows: TJSArray); external name 'set';
    procedure failed(const Text: string);
  end;
  TPageShell = class external name 'Object'(TJSObject)
    extras: TJSObject;
    procedure adminTable(Holder: TJSHTMLElement; Headings, Rows: TJSArray);
    function stat(Holder: TJSHTMLElement; Value: JSValue; const Caption: string;
      Note: JSValue = undefined; Cls: JSValue = undefined): TJSHTMLElement;
    function subTabs(Holder: TJSHTMLElement; const Id: string; Tabs: TJSArray): TPageTabs;
    function chip(Text: JSValue; Cls: JSValue = undefined): TJSHTMLElement;
    procedure facts(Holder: TJSHTMLElement; Rows: TJSArray);
    procedure toast(const Text: string; Kind: JSValue = undefined);
    function listView(Holder: TJSHTMLElement; Options: TJSObject): TPageList;
    function link(const Url, Cls: string; Text: JSValue): TJSHTMLAnchorElement;
    function enc(const Text: string): string;
    procedure waiting(Holder: TJSHTMLElement);
    function get(const Url: string): TJSPromise;
    function post(const Url: string; Data: TJSObject): TJSPromise;
    function el(const Tag: string): TJSHTMLElement; overload;
    function el(const Tag, Cls: string): TJSHTMLElement; overload;
    function el(const Tag, Cls: string; Text: JSValue): TJSHTMLElement; overload;
  end;

var
  Side: TPageSide; external name 'window.Side';
  SiteShell: TPageShell; external name 'window.Site';
  Keys: TPageKeys; external name 'window.Keys';
  SiteBase: TPageBase; external name 'window.SiteBase';

function T(const English: string): string; varargs; external name 'window.t';
function DateTimeText(Value: JSValue): string; external name 'window.dateTimeText';
function TN(N: NativeInt; const One, Many: string): string; varargs; external name 'window.tn';

implementation

end.
