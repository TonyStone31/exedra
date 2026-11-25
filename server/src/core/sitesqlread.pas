unit SiteSqlRead;

{ Reads a statement written in MariaDB's words into its words and signs,
  for the units that put it in another database server's words, and keeps
  what the table definitions said: each table's keys and columns. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

type
  TTokKind = (tkWord, tkNumber, tkString, tkParam, tkQuoted, tkSymbol);

  TTok = record
    Kind: TTokKind;
    Text: string;
  end;
  TToks = array of TTok;

  TRange = record
    A, B: integer;
  end;
  TRanges = array of TRange;

var
  { table name = its unique keys, each a comma list of columns, joined by ; }
  Keys: TStringList;
  { table name = ,its,columns, }
  Columns: TStringList;
  { ,names,of,columns, that may hold NULL in some table }
  Nullable: string = ',';
  KeysLock: TRTLCriticalSection;
  { the function that gives a character by its number: chr on PostgreSQL,
    char on SQLite }
  CharFunction: string = 'chr';

function Tokenize(const S: string; Standard: boolean = False): TToks;
function IsWord(const T: TToks; I: integer; const W: string): boolean;
function IsSym(const T: TToks; I: integer; const S: string): boolean;
function Closing(const T: TToks; I, B: integer): integer;
function SplitCommas(const T: TToks; A, B: integer): TRanges;
function FindWords(const T: TToks; A, B: integer; const Words: array of string): integer;
procedure Emit(var Dest: string; const S: string);
function TokText(const Tok: TTok): string;
function Raw(const T: TToks; A, B: integer): string;
function KeyFor(const Table, Columns: string): string;
procedure NoteKey(const Table, Columns: string);
procedure NoteColumn(const Table, Column: string);
function IsCondition(const T: TToks; A, B: integer): boolean;
function IndexName(const Table, Name, Columns: string): string;
function IndexColumns(const T: TToks; A, B: integer): string;

implementation

{ A text literal as MariaDB reads it, with its backslash escapes, written
  the way every server reads it: quotes doubled and nothing else special.
  A line feed or another control character cannot stand in such a literal
  safely, so it is joined in by its number. }
function StandardLiteral(const Quoted: string): string;
var
  I: integer;
  Value, Run: string;
  C: char;

  procedure Flush;
  begin
    if Run <> '' then
    begin
      if Result <> '' then
        Result := Result + ' || ';
      Result := Result + '''' + Run + '''';
      Run := '';
    end;
  end;

begin
  // what the literal says
  Value := '';
  I := 2;
  while I < Length(Quoted) do
  begin
    C := Quoted[I];
    if (C = '\') and (I + 1 < Length(Quoted)) then
    begin
      Inc(I);
      case Quoted[I] of
        'n': Value := Value + #10;
        'r': Value := Value + #13;
        't': Value := Value + #9;
        '0': Value := Value + #0;
        'Z': Value := Value + #26;
        'b': Value := Value + #8;
        // these two stay as written: they are for LIKE to read
        '%', '_': Value := Value + '\' + Quoted[I];
        else
          Value := Value + Quoted[I];
      end;
    end
    else if (C = '''') and (I + 1 < Length(Quoted)) and (Quoted[I + 1] = '''') then
    begin
      Value := Value + '''';
      Inc(I);
    end
    else
      Value := Value + C;
    Inc(I);
  end;
  // and how it is written
  Result := '';
  Run := '';
  for I := 1 to Length(Value) do
    if Value[I] < ' ' then
    begin
      Flush;
      if Result <> '' then
        Result := Result + ' || ';
      Result := Result + CharFunction + '(' + IntToStr(Ord(Value[I])) + ')';
    end
    else if Value[I] = '''' then
      Run := Run + ''''''
    else
      Run := Run + Value[I];
  Flush;
  if Result = '' then
    Result := ''''''
  else if Pos(' || ', Result) > 0 then
    Result := '(' + Result + ')';
end;

function Tokenize(const S: string; Standard: boolean = False): TToks;
var
  I, N, Start, Count: integer;
  C: char;

  procedure Add(Kind: TTokKind; const Text: string);
  begin
    if Count = Length(Result) then
      SetLength(Result, Count * 2 + 16);
    Result[Count].Kind := Kind;
    Result[Count].Text := Text;
    Inc(Count);
  end;

begin
  Result := nil;
  Count := 0;
  N := Length(S);
  I := 1;
  while I <= N do
  begin
    C := S[I];
    if C <= ' ' then
      Inc(I)
    else if (C = '/') and (I < N) and (S[I + 1] = '*') then
    begin
      // a comment is passed over
      Start := Pos('*/', S, I + 2);
      if Start = 0 then
        I := N + 1
      else
        I := Start + 2;
    end
    else if (C = '-') and (I + 1 < N) and (S[I + 1] = '-') and (S[I + 2] <= ' ') then
    begin
      while (I <= N) and (S[I] <> #10) do
        Inc(I);
    end
    else if C = '''' then
    begin
      Start := I;
      Inc(I);
      while I <= N do
      begin
        if (S[I] = '\') and (I < N) and not Standard then
          Inc(I, 2)
        else if S[I] = '''' then
        begin
          if (I < N) and (S[I + 1] = '''') then
            Inc(I, 2)
          else
            Break;
        end
        else
          Inc(I);
      end;
      Inc(I);
      // Standard: the text is already written for the server
      if Standard or (Pos('\', Copy(S, Start, I - Start)) = 0) then
        Add(tkString, Copy(S, Start, I - Start))
      else
        Add(tkString, StandardLiteral(Copy(S, Start, I - Start)));
    end
    else if C = '`' then
    begin
      Start := I + 1;
      Inc(I);
      while (I <= N) and (S[I] <> '`') do
        Inc(I);
      Add(tkQuoted, Copy(S, Start, I - Start));
      Inc(I);
    end
    else if C = '"' then
    begin
      Start := I;
      Inc(I);
      while (I <= N) and (S[I] <> '"') do
        Inc(I);
      Inc(I);
      Add(tkWord, Copy(S, Start, I - Start));
    end
    else if (C = ':') and (I < N) and (S[I + 1] in ['A'..'Z', 'a'..'z', '_']) and ((I = 1) or (S[I - 1] <> ':')) then
    begin
      Start := I;
      Inc(I);
      while (I <= N) and (S[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
        Inc(I);
      Add(tkParam, Copy(S, Start, I - Start));
    end
    else if C in ['A'..'Z', 'a'..'z', '_'] then
    begin
      Start := I;
      while (I <= N) and (S[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '$']) do
        Inc(I);
      Add(tkWord, Copy(S, Start, I - Start));
    end
    else if C in ['0'..'9'] then
    begin
      Start := I;
      while (I <= N) and (S[I] in ['0'..'9', '.']) do
        Inc(I);
      Add(tkNumber, Copy(S, Start, I - Start));
    end
    else
    begin
      // operators of more than one character stay whole
      if (I + 1 < N) and (Copy(S, I, 3) = '!~*') then
      begin
        Add(tkSymbol, '!~*');
        Inc(I, 3);
      end
      else if (I < N) and ((C + S[I + 1] = '<=') or (C + S[I + 1] = '>=') or (C + S[I + 1] = '<>') or (C + S[I + 1] = '!=') or (C + S[I + 1] = '||') or
        (C + S[I + 1] = '::') or (C + S[I + 1] = '@@') or (C + S[I + 1] = '!~') or (C + S[I + 1] = '~*')) then
      begin
        Add(tkSymbol, C + S[I + 1]);
        Inc(I, 2);
      end
      else
      begin
        Add(tkSymbol, C);
        Inc(I);
      end;
    end;
  end;
  SetLength(Result, Count);
end;

function IsWord(const T: TToks; I: integer; const W: string): boolean;
begin
  Result := (I >= 0) and (I < Length(T)) and (T[I].Kind = tkWord) and SameText(T[I].Text, W);
end;

function IsSym(const T: TToks; I: integer; const S: string): boolean;
begin
  Result := (I >= 0) and (I < Length(T)) and (T[I].Kind = tkSymbol) and (T[I].Text = S);
end;

{ The index of the parenthesis that closes the one at I. }
function Closing(const T: TToks; I, B: integer): integer;
var
  Depth: integer;
begin
  Depth := 0;
  Result := I;
  while Result < B do
  begin
    if IsSym(T, Result, '(') then
      Inc(Depth)
    else if IsSym(T, Result, ')') then
    begin
      Dec(Depth);
      if Depth = 0 then
        Exit;
    end;
    Inc(Result);
  end;
  Result := B - 1;
end;

{ The parts of [A, B) between commas that are not inside parentheses. }
function SplitCommas(const T: TToks; A, B: integer): TRanges;
var
  I, Depth, Start, Count: integer;
begin
  Result := nil;
  SetLength(Result, 8);
  Count := 0;
  Depth := 0;
  Start := A;
  for I := A to B do
  begin
    if (I < B) and IsSym(T, I, '(') then
      Inc(Depth)
    else if (I < B) and IsSym(T, I, ')') then
      Dec(Depth);
    if (I = B) or ((Depth = 0) and IsSym(T, I, ',')) then
    begin
      if Count = Length(Result) then
        SetLength(Result, Count * 2);
      Result[Count].A := Start;
      Result[Count].B := I;
      Inc(Count);
      Start := I + 1;
    end;
  end;
  SetLength(Result, Count);
  if (Count = 1) and (Result[0].A >= Result[0].B) then
    SetLength(Result, 0);
end;

{ The first place in [A, B), outside parentheses, where the words stand. }
function FindWords(const T: TToks; A, B: integer; const Words: array of string): integer;
var
  I, K, Depth: integer;
  Hit: boolean;
begin
  Depth := 0;
  for I := A to B - 1 do
  begin
    if IsSym(T, I, '(') then
      Inc(Depth)
    else if IsSym(T, I, ')') then
      Dec(Depth)
    else if Depth = 0 then
    begin
      Hit := I + Length(Words) <= B;
      K := 0;
      while Hit and (K <= High(Words)) do
      begin
        Hit := IsWord(T, I + K, Words[K]);
        Inc(K);
      end;
      if Hit then
        Exit(I);
    end;
  end;
  Result := -1;
end;

procedure Emit(var Dest: string; const S: string);
var
  Last: char;
begin
  if S = '' then
    Exit;
  if Dest = '' then
  begin
    Dest := S;
    Exit;
  end;
  Last := Dest[Length(Dest)];
  if (Last in ['(', '.']) or (S[1] in [')', ',', '.']) or ((S[1] = '(') and (Last in ['A'..'Z', 'a'..'z', '0'..'9', '_'])) or
    ((S = '::') or ((Length(Dest) > 1) and (Copy(Dest, Length(Dest) - 1, 2) = '::'))) then
    Dest := Dest + S
  else
    Dest := Dest + ' ' + S;
end;

function TokText(const Tok: TTok): string;
begin
  case Tok.Kind of
    tkQuoted: Result := '"' + Tok.Text + '"';
    else
      Result := Tok.Text;
  end;
end;

function Raw(const T: TToks; A, B: integer): string;
var
  I: integer;
begin
  Result := '';
  for I := A to B - 1 do
    Emit(Result, TokText(T[I]));
end;

{ The key of Table whose columns are all among the inserted Columns: the
  one an insert can collide on. }
function KeyFor(const Table, Columns: string): string;
var
  All, Have: TStringList;
  I, K: integer;
  Fits: boolean;
  S: string;
begin
  Result := '';
  EnterCriticalSection(KeysLock);
  try
    S := Keys.Values[LowerCase(Table)];
  finally
    LeaveCriticalSection(KeysLock);
  end;
  if S = '' then
    Exit;
  All := TStringList.Create;
  Have := TStringList.Create;
  try
    Have.CommaText := LowerCase(StringReplace(Columns, ' ', '', [rfReplaceAll]));
    All.Delimiter := ';';
    All.StrictDelimiter := True;
    All.DelimitedText := S;
    for I := 0 to All.Count - 1 do
    begin
      Fits := All[I] <> '';
      with TStringList.Create do
      try
        CommaText := All[I];
        for K := 0 to Count - 1 do
          if Have.IndexOf(Strings[K]) < 0 then
            Fits := False;
      finally
        Free;
      end;
      if Fits then
        Exit(All[I]);
    end;
    // no key is wholly inserted: the first one, the primary key
    if All.Count > 0 then
      Result := All[0];
  finally
    All.Free;
    Have.Free;
  end;
end;

procedure NoteKey(const Table, Columns: string);
var
  Name, S: string;
begin
  Name := LowerCase(Table);
  S := LowerCase(StringReplace(Columns, ' ', '', [rfReplaceAll]));
  EnterCriticalSection(KeysLock);
  try
    if Pos(';' + S + ';', ';' + Keys.Values[Name] + ';') = 0 then
    begin
      if Keys.Values[Name] = '' then
        Keys.Values[Name] := S
      else
        Keys.Values[Name] := Keys.Values[Name] + ';' + S;
    end;
  finally
    LeaveCriticalSection(KeysLock);
  end;
end;

procedure NoteColumn(const Table, Column: string);
var
  Name: string;
begin
  Name := LowerCase(Table);
  EnterCriticalSection(KeysLock);
  try
    if Columns.Values[Name] = '' then
      Columns.Values[Name] := ',';
    if Pos(',' + LowerCase(Column) + ',', Columns.Values[Name]) = 0 then
      Columns.Values[Name] := Columns.Values[Name] + LowerCase(Column) + ',';
  finally
    LeaveCriticalSection(KeysLock);
  end;
end;

{ True when a comparison stands in [A, B) outside parentheses: the part
  is a condition, which PostgreSQL will not add up or multiply. }
function IsCondition(const T: TToks; A, B: integer): boolean;
var
  I, Depth: integer;
  W: string;
begin
  Result := False;
  if (A >= B) or IsWord(T, A, 'CASE') or IsWord(T, A, 'SELECT') then
    Exit;
  Depth := 0;
  for I := A to B - 1 do
  begin
    if IsSym(T, I, '(') then
      Inc(Depth)
    else if IsSym(T, I, ')') then
      Dec(Depth)
    else if Depth = 0 then
    begin
      W := UpperCase(T[I].Text);
      if (T[I].Kind = tkSymbol) and ((W = '=') or (W = '<>') or (W = '!=') or (W = '<') or (W = '>') or (W = '<=') or (W = '>=')) then
        Exit(True);
      if (T[I].Kind = tkWord) and ((W = 'IS') or (W = 'LIKE') or (W = 'IN') or (W = 'BETWEEN') or (W = 'REGEXP') or (W = 'EXISTS') or ((W = 'NOT') and (I = A))) then
        Exit(True);
    end;
  end;
end;

function IndexName(const Table, Name, Columns: string): string;
var
  I: integer;
begin
  if Name <> '' then
    Result := Table + '_' + Name
  else
    Result := Table + '_' + Columns;
  for I := 1 to Length(Result) do
    if not (Result[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      Result[I] := '_';
  while Pos('__', Result) > 0 do
    Result := StringReplace(Result, '__', '_', [rfReplaceAll]);
  if Result[Length(Result)] = '_' then
    SetLength(Result, Length(Result) - 1);
  Result := LowerCase(Copy(Result, 1, 63));
end;

{ The columns of an index: (a, b(191)) without lengths. }
function IndexColumns(const T: TToks; A, B: integer): string;
var
  Parts: TRanges;
  I: integer;
begin
  Result := '';
  Parts := SplitCommas(T, A, B);
  for I := 0 to High(Parts) do
  begin
    if I > 0 then
      Result := Result + ', ';
    Result := Result + T[Parts[I].A].Text;
  end;
end;

initialization
  InitCriticalSection(KeysLock);
  Keys := TStringList.Create;
  Columns := TStringList.Create;
end.
