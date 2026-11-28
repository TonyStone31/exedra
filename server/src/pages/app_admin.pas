unit app_admin;

{ The site's page: the admin page, read when it is opened, and the helpers
  it and the parts' admin tabs draw with. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, WebOrWorker, app_helpers;

function LoadScript(Src: JSValue): JSValue;
function OpenAdmin: JSValue; async;
function SubTabs(Box: TJSElement; Id: JSValue; List: TJSArray): TJSObject;
function Waiting(Holder: TJSElement; Words: JSValue = undefined): TEl;
function Facts(Holder: TJSElement; Pairs: TJSArray): TEl;
function Chip(Words: JSValue; Cls: JSValue = undefined): TEl;
procedure StartAdmin;

implementation

type
  // Web's constructor takes a text only; a missing one is read as empty here.
  TParams = class external name 'URLSearchParams'(TJSObject)
    constructor new(Init: JSValue);
    function get(const Name: string): JSValue;
  end;
  // Web has the one-argument toggle only.
  TTokens = class external name 'DOMTokenList'(TJSDOMTokenList)
    function toggle(const Name: string; Force: boolean): boolean; overload;
  end;
  // The site's shell as admin.js completes it.
  TShell = class external name 'Object'(TJSObject)
    function openAdmin: JSValue;
  end;
  // One of the tabs inside a tab.
  TTab = class external name 'Object'(TJSObject)
    button, holder, badge: TEl;
  end;
  TCounted = class external name 'Object'(TJSObject)
    function toLocaleString(Locale: JSValue): string;
  end;
  TPick = reference to procedure(Key: JSValue);
  THolder = reference to function(Key: JSValue): TEl;
  TCount = reference to procedure(Key: JSValue; N: double);

var
  Shell: TShell; external name 'window.Chat';
  ScriptVersion: JSValue;
  Scripts: TJSMap;

// ------------------------------------------------------------------ admin

function LoadScript(Src: JSValue): JSValue;
begin
  if not Scripts.has(Src) then
    Scripts.&set(Src, TJSPromise.new(procedure(Resolve, Reject: TJSPromiseResolver)
      var
        Script: TEl;
      begin
        Script := El('script');
        if Same(ScriptVersion, nil) then Script.src := String(Src) else Script.src := String(Src) + '?v=' + Enc(ScriptVersion);
        Script.whenLoaded := Resolve;
        Script.whenFailed := procedure
          begin
            Scripts.delete(Src);
            Script.remove;
            Reject(TJSError.new(T('Could not load %s.', Src)));
          end;
        document.head.appendChild(Script);
      end));
  Result := Scripts.get(Src);
end;

function OpenAdmin: JSValue; async;
var
  Generation: NativeInt;
begin
  Generation := S.generation;
  if document.readyState = 'loading' then
    await(JSValue, TJSPromise.new(procedure(Resolve, Reject: TJSPromiseResolver)
      begin
        document.addEventListener('DOMContentLoaded', TJSRawEventHandler(procedure(E: TJSEvent) begin Resolve(E); end),
          TJSEventListenerOptions(new(['once', True])));
      end));
  if Generation <> S.generation then Exit;
  try
    await(JSValue, LoadScript('/static/admin.js'));
  except
    Failed(JSExceptValue);
    Exit;
  end;
  if Generation <> S.generation then Exit;
  await(JSValue, Shell.openAdmin);
end;

// tabs inside a tab: a row of smaller ones, the one last chosen remembered
function SubTabs(Box: TJSElement; Id: JSValue; List: TJSArray): TJSObject;
var
  Nav: TEl;
  Tabs: TJSObject;
  Current: JSValue;
  I: NativeInt;
  Holder: THolder;
  Count: TCount;

  procedure Select(Key: JSValue);
  var
    K: string;
    B: TEl;
  begin
    if not Truthy(Tabs[String(Key)]) then Key := TJSObject(List[0])['key'];
    for K in Tabs do
    begin
      TTokens(TTab(Tabs[K]).button.classList).toggle('on', Same(K, Key));
      if Same(K, Key) then TTab(Tabs[K]).button.setAttribute('aria-selected', 'true')
      else TTab(Tabs[K]).button.setAttribute('aria-selected', 'false');
      TTab(Tabs[K]).holder.hidden := not Same(K, Key);
    end;
    Current := Key;
    try
      LocalStore.setItem('sub-' + String(Id), Key);
    except
    end;
    // on a phone the row scrolls: the chosen one in sight
    B := TTab(Tabs[String(Key)]).button;
    if Truthy(TJSObject(B)['scrollIntoView']) and (Nav.scrollWidth > Nav.clientWidth) then
      B.scrollIntoView(new(['block', 'nearest', 'inline', 'nearest']));
  end;

  procedure Add(Tab: TJSObject);
  var
    B, Badge, Part: TEl;
  begin
    B := El('button', '', Tab['title']);
    B.kind := 'button';
    B.setAttribute('role', 'tab');
    Badge := El('span', 'sub-count');
    Badge.hidden := True;
    B.appendChild(Badge);
    Part := El('div', 'subpart');
    Part.setAttribute('role', 'tabpanel');
    Part.hidden := True;
    B.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Select(Tab['key']); end));
    Nav.appendChild(B);
    Box.appendChild(Part);
    Tabs[String(Tab['key'])] := new(['button', B, 'holder', Part, 'badge', Badge]);
  end;

begin
  Nav := El('nav', 'subtabs');
  Nav.setAttribute('role', 'tablist');
  Box.appendChild(Nav);
  Tabs := TJSObject.new;
  Current := '';
  try
    Current := LocalStore.getItem('sub-' + String(Id));
    if not Truthy(Current) then Current := '';
  except
  end;
  for I := 0 to List.length - 1 do Add(TJSObject(List[I]));
  Select(Current);
  Holder := function(Key: JSValue): TEl begin Result := TTab(Tabs[String(Key)]).holder; end;
  Count := procedure(Key: JSValue; N: double)
    var
      B: TEl;
    begin
      B := TTab(Tabs[String(Key)]).badge;
      B.hidden := not (N > 0);
      if N > 0 then B.textContent := TCounted(JSValue(N)).toLocaleString(Locale) else B.textContent := '';
    end;
  Result := new(['holder', Holder, 'select', TPick(@Select), 'count', Count]);
end;

// a part of a page whose words are on their way: a turning mark and what it waits for
function Waiting(Holder: TJSElement; Words: JSValue): TEl;
begin
  Result := El('p', 'lv-wait');
  if not Truthy(Words) then Words := T('Loading…');
  Result.add(El('span', 'lv-spinner'), ' ' + String(Words));
  Holder.replaceChildren(Result);
end;

// facts about one thing, as label and value lines in a picked row's box
function Facts(Holder: TJSElement; Pairs: TJSArray): TEl;
var
  I: NativeInt;
  P: TJSArray;
  Value: TEl;
begin
  Result := El('dl', 'lv-facts');
  for I := 0 to Pairs.length - 1 do
  begin
    P := TJSArray(Pairs[I]);
    if Same(P[1], '') or Same(P[1], nil) or (jsTypeOf(P[1]) = 'undefined') then continue;
    Result.appendChild(El('dt', '', P[0]));
    Value := El('dd');
    if jsTypeOf(P[1]) = 'object' then Value.appendChild(TJSNode(P[1])) else Value.textContent := Text(P[1]);
    Result.appendChild(Value);
  end;
  Holder.appendChild(Result);
end;

function Chip(Words: JSValue; Cls: JSValue): TEl;
begin
  if Truthy(Cls) then Result := El('span', 'lv-chip ' + String(Cls), Words) else Result := El('span', 'lv-chip', Words);
end;

procedure StartAdmin;
begin
  if Truthy(document.currentScript) then
    ScriptVersion := TParams.new(TJSArray(TJSString(TJSObject(document.currentScript)['src']).split('?'))[1]).get('v')
  else ScriptVersion := nil;
  Scripts := TJSMap.new;
end;

end.
