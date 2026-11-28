unit ThemePage;

{ Runs before the page draws, so a dark page never flashes light.
  auto follows the system; light and dark are the member's choice. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}

interface

uses JS, Web;

implementation

uses PageKit;

type
  TThemeApi = class external name 'Object'(TJSObject)
    procedure set_(Value: JSValue); external name 'set';
  end;

var
  Theme: string;
  // window.Theme as the page has it now, for the pickers.
  Published: TThemeApi; external name 'Theme';

function Stored: string;
begin
  Result := 'auto';
  try
    Result := window.localStorage.getItem('theme');
    if not Truthy(Result) then Result := 'auto';
  except
  end;
end;

function Valid(Value: JSValue): string;
begin
  if TJSArray.new('auto', 'light', 'dark').includes(Value) then Result := String(Value)
  else Result := 'auto';
end;

procedure Apply(Value: JSValue);
var
  Pickers: TJSNodeList;
  I: NativeInt;
begin
  Theme := Valid(Value);
  if Theme = 'auto' then JSDelete(TJSHTMLElement(document.documentElement).dataset, 'theme')
  else TJSHTMLElement(document.documentElement).dataset['theme'] := Theme;
  Pickers := document.querySelectorAll('[data-theme-picker]');
  for I := 0 to Pickers.length - 1 do TJSHTMLSelectElement(Pickers[I]).value := Theme;
  window.dispatchEvent(TJSEvent.new('themechange'));
end;

function GetTheme: string;
begin
  Result := Theme;
end;

procedure SetTheme(Value: JSValue);
begin
  Apply(Value);
  try
    window.localStorage.setItem('theme', Theme);
  except
  end;
end;

procedure Show(Picker: TJSHTMLSelectElement);
begin
  Picker.value := Theme;
  TJSHTMLElement(Picker.closest('.theme-choice')).hidden := False;
  Picker.addEventListener('change', TJSRawEventHandler(procedure(E: TJSEvent)
    begin Published.set_(Picker.value); end));
end;

procedure Start;
begin
  Theme := Stored;
  TJSObject(window)['Theme'] := new(['get', @GetTheme, 'set', @SetTheme]);
  Apply(Theme);
  window.addEventListener('storage', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      if (TJSStorageEvent(E).key = 'theme') or isNull(TJSStorageEvent(E).key) then Apply(Stored);
    end));
  document.addEventListener('DOMContentLoaded', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Pickers: TJSNodeList;
      I: NativeInt;
    begin
      Pickers := document.querySelectorAll('[data-theme-picker]');
      for I := 0 to Pickers.length - 1 do Show(TJSHTMLSelectElement(Pickers[I]));
    end));
end;

initialization
  Start;
end.
