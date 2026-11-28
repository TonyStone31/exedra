unit EmojiNamesPage;

{ Find emoji names as they are typed: :thu offers thumbsup, :tada: becomes
  its emoji.  emoji-names.txt holds emoji and names under ## group headings,
  loaded on first use.  The chat and editor display suggestions themselves. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web;

function List: TJSPromise;
function Typed(const Text: string; At: NativeInt; Short: JSValue = undefined): TJSObject;
function Matches(Items: TJSArray; const Word: string): TJSArray;
function Named(Items: TJSArray; Word: JSValue): JSValue;
function After(Items: TJSArray): TJSPromise;

implementation

uses PageKit;

type
  TTranslate = reference to function(const S: string): JSValue;

var
  Translate: TTranslate;
  Asked: TJSPromise;

function Fetch(const Address: string): TJSPromise; external name 'fetch';
function Max(A, B: NativeInt): NativeInt; external name 'Math.max';

// The list as the editor knows an emoji set: emoji, name, group, keywords.
function List: TJSPromise;
begin
  if not Truthy(Asked) then
    Asked := Fetch('/static/emoji-names.txt')._then(function(R: JSValue): JSValue
      begin
        if Truthy(TJSObject(R)['ok']) then Result := TJSResponse(R).text else Result := '';
      end)._then(function(Text: JSValue): JSValue
      var
        Found: TJSArray;
        Group: JSValue;
        Lines, Parts: TJSArray;
        Line: string;
        T: TTranslate;
        I: NativeInt;
      begin
        Found := TJSArray.new;
        Group := '';
        T := Translate;
        Lines := TJSArray(TJSString(Text).split(#10));
        for I := 0 to Lines.length - 1 do
        begin
          Line := String(Lines[I]);
          Parts := TJSArray(TJSString(Line).split(' '));
          if TJSString(Line).startsWith('## ') then Group := T(TJSString(Line).slice(3))
          else if (Line <> '') and not TJSString(Line).startsWith('#') then
            Found.push(new(['emoji', Parts[0], 'name', Parts[1], 'group', Group, 'keywords', Parts.slice(1)]));
        end;
        Result := Found;
      end);
  Result := Asked;
end;

// Inside code a name is only words: a fence above, an indented line, or
// an open ` on the line.
function InCode(const Before: string): boolean;
var
  Fence: boolean;
  Lines: TJSArray;
  Line: string;
  I: NativeInt;
begin
  Fence := False;
  Lines := TJSArray(TJSString(Before).split(#10)).slice(0, -1);
  for I := 0 to Lines.length - 1 do
    if TJSRegexp.new('^ {0,3}(`{3,}|~{3,})').test(String(Lines[I])) then Fence := not Fence;
  Line := TJSString(Before).slice(TJSString(Before).lastIndexOf(#10) + 1);
  Result := Fence or TJSRegexp.new('^( {4}|\t)').test(Line) or ((Length(TJSString(Line).split('`')) - 1) mod 2 = 1);
end;

// The name being typed where the caret is (at), or null: a colon where a
// word starts, not in a time or an address, then two letters or more
// (short: any, even none).  whole says its closing colon is there too.
// from is where the colon is.
function Typed(const Text: string; At: NativeInt; Short: JSValue): TJSObject;
var
  M: TJSArray;
  Word, Colon: string;
  Least: NativeInt;
begin
  Result := nil;
  M := TJSArray(TJSRegexp.new('(^|[^A-Za-z0-9:/\\_]):([A-Za-z0-9+_-]{0,30})(:?)$').exec(
    TJSString(Text).slice(Max(0, At - 34), At)));
  if not Truthy(M) then Exit;
  Word := String(M[2]);
  Colon := String(M[3]);
  if Truthy(Short) then Least := 0 else Least := 2;
  if Colon <> '' then
  begin
    if Word = '' then Exit;
  end
  else if Length(Word) < Least then Exit;
  if InCode(TJSString(Text).slice(0, At)) then Exit;
  Result := new(['word', TJSString(Word).toLowerCase, 'from', At - Length(Word) - Length(Colon) - 1, 'whole', Colon <> '']);
end;

// The emoji that fit a word, each with the keyword that fit (match): the
// word itself first, then keywords that start with it, the shortest
// first (heart before heart_eyes), then those and names that hold it.
// No word yet: the set as it is.
function Matches(Items: TJSArray; const Word: string): TJSArray;
var
  Found, Keywords: TJSArray;
  E: TJSObject;
  Starts, Holds, FirstName: JSValue;
  Rank, I: NativeInt;
begin
  if not Truthy(Word) then Exit(Items);
  Found := TJSArray.new;
  for I := 0 to Items.length - 1 do
  begin
    E := TJSObject(Items[I]);
    Keywords := TJSArray(E['keywords']);
    Starts := Keywords.find(function(K: JSValue; Index: NativeInt; A: TJSArray): boolean
      begin Result := TJSString(K).indexOf(Word) = 0; end);
    Holds := Starts;
    if not Truthy(Holds) then
      Holds := Keywords.find(function(K: JSValue; Index: NativeInt; A: TJSArray): boolean
        begin Result := TJSString(K).indexOf(Word) > 0; end);
    if Truthy(Holds) then
    begin
      if String(Holds) = Word then Rank := 0 else if Truthy(Starts) then Rank := 1 else Rank := 2;
      Found.push(TJSObject.assign(TJSObject.new, E, new(['match', Holds, 'rank', Rank])));
    end
    else if TJSString(TJSString(E['name']).toLowerCase).indexOf(Word) >= 0 then
    begin
      FirstName := Keywords[0];
      if not Truthy(FirstName) then FirstName := '';
      Found.push(TJSObject.assign(TJSObject.new, E, new(['match', FirstName, 'rank', 2])));
    end;
  end;
  Result := Found.sort(function(X, Y: JSValue): NativeInt
    begin
      Result := NativeInt(TJSObject(X)['rank']) - NativeInt(TJSObject(Y)['rank']);
      if (Result = 0) and (NativeInt(TJSObject(X)['rank']) < 2) then
        Result := Length(String(TJSObject(X)['match'])) - Length(String(TJSObject(Y)['match']));
    end);
end;

// The emoji a whole :name: stands for.
function Named(Items: TJSArray; Word: JSValue): JSValue;
begin
  Result := Items.find(function(E: JSValue; Index: NativeInt; A: TJSArray): boolean
    begin Result := TJSArray(TJSObject(E)['keywords']).indexOf(Word) >= 0; end);
end;

function Plain(S: JSValue): string;
begin
  Result := TJSString(S).replace(TJSRegexp.new('️', 'g'), '');
end;

// A part's own set with this list after it: an emoji of both keeps the
// part's entry and gains the names nothing in the set answers to.
function After(Items: TJSArray): TJSPromise;
begin
  Result := List._then(function(More: JSValue): JSValue
    var
      All, Free: TJSArray;
      E, Own: TJSObject;
      I: NativeInt;
    begin
      All := Items.slice;
      for I := 0 to TJSArray(More).length - 1 do
      begin
        E := TJSObject(TJSArray(More)[I]);
        Free := TJSArray(E['keywords']).filter(function(K: JSValue; Index: NativeInt; A: TJSArray): boolean
          begin Result := not Truthy(Named(Items, K)); end);
        Own := TJSObject(All.find(function(X: JSValue; Index: NativeInt; A: TJSArray): boolean
          begin Result := Plain(TJSObject(X)['emoji']) = Plain(E['emoji']); end));
        if Truthy(Own) then Own['keywords'] := TJSArray(Own['keywords']).concat(Free)
        else if Truthy(Free.length) then All.push(TJSObject.assign(TJSObject.new, E, new(['keywords', Free])));
      end;
      Result := All;
    end);
end;

procedure Start;
begin
  Translate := TTranslate(TJSObject(window)['t']);
  if not Truthy(Translate) then Translate := function(const S: string): JSValue begin Result := S; end;
  Asked := nil;
  // Web has a value called named; the unit's name says which is meant.
  TJSObject(window)['EmojiNames'] := new(['list', @List, 'typed', @Typed, 'matches', @Matches, 'named', @EmojiNamesPage.Named,
    'after', @After]);
end;

initialization
  Start;
end.
