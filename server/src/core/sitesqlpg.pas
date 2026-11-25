unit SiteSqlPg;

{ Translate MariaDB statements and schemas for PostgreSQL, with case-
  insensitive text collation. Parameters are quoted literals so PostgreSQL
  infers numeric and date types. PgValue doubles quotes; sessions require
  standard_conforming_strings. }

{$mode objfpc}{$H+}

interface

{ Statements run once before the tables: the collation and the helper
  functions the translated statements call. }
function PgSetup: string;
{ What each new connection runs first. }
function PgSessionStart: string;
{ A CREATE TABLE, ALTER TABLE or other registered statement. }
function PgSchema(const Statement: string): string;
{ A statement with its values written in. }
function PgStatement(const SQL: string; const Values: array of variant): string;
{ A statement translated, its parameters left as they are. }
function PgTranslate(const SQL: string): string;

implementation

uses
  SysUtils, Classes, Variants, SiteSqlRead;

const
  CI = 'COLLATE "exedra_ci"';
  PLAIN = 'COLLATE "und-x-icu"';

type
  TColumn = record
    Name, TypeSql, Default: string;
    HasDefault, NotNull, Nullable, Touch: boolean;
    Rest: string;
  end;

{ MariaDB's date letters as to_char's. }
function DateLetters(const Quoted: string): string;
var
  I: integer;
  S, Lit: string;

  procedure Flush;
  begin
    if Lit <> '' then
      Result := Result + '"' + Lit + '"';
    Lit := '';
  end;

begin
  S := Copy(Quoted, 2, Length(Quoted) - 2);
  Result := '';
  Lit := '';
  I := 1;
  while I <= Length(S) do
  begin
    if (S[I] = '%') and (I < Length(S)) then
    begin
      Flush;
      Inc(I);
      case S[I] of
        'Y': Result := Result + 'YYYY';
        'y': Result := Result + 'YY';
        'm': Result := Result + 'MM';
        'c': Result := Result + 'FMMM';
        'd': Result := Result + 'DD';
        'e': Result := Result + 'FMDD';
        'H': Result := Result + 'HH24';
        'h', 'I': Result := Result + 'HH12';
        'i': Result := Result + 'MI';
        's', 'S': Result := Result + 'SS';
        'p': Result := Result + 'AM';
        'M': Result := Result + 'FMMonth';
        'b': Result := Result + 'Mon';
        'W': Result := Result + 'FMDay';
        'a': Result := Result + 'Dy';
        'j': Result := Result + 'DDD';
        'T': Result := Result + 'HH24:MI:SS';
        else
          Lit := Lit + S[I];
      end;
    end
    else if S[I] in ['-', ':', ' ', '/', '.', ','] then
    begin
      Flush;
      Result := Result + S[I];
    end
    else
      Lit := Lit + S[I];
    Inc(I);
  end;
  Flush;
  Result := '''' + Result + '''';
end;

{ ---- one statement ---- }

function Tr(const T: TToks; A, B: integer; InConflict: boolean = False): string; forward;

{ The text vector PostgreSQL searches.  Dots, slashes and the like become
  blanks first: PostgreSQL would keep unit.name or an address as one word,
  where MariaDB finds each part. }
function TextVector(const T: TToks; A, B: integer): string;
var
  Parts: TRanges;
  I: integer;
begin
  Parts := SplitCommas(T, A, B);
  Result := '';
  for I := 0 to High(Parts) do
  begin
    if I > 0 then
      Result := Result + ' || '' '' || ';
    Result := Result + 'coalesce(' + Raw(T, Parts[I].A, Parts[I].B) + ', '''')';
  end;
  Result := 'to_tsvector(''simple'', translate(' + Result + ', ''./@:~'', ''     ''))';
end;

{ A FULLTEXT index is a column here that the server fills with the text
  vector of the indexed columns, and an index on it: a search reads the
  stored vector and never works it out again, with the index or without.
  This is its name for the columns in [A, B): fts_ and the column names
  in alphabet order, behind the table name the first column carries. }
function VectorColumn(const T: TToks; A, B: integer): string;
var
  Parts: TRanges;
  Names: TStringList;
  I: integer;
  Qualifier: string;
begin
  Parts := SplitCommas(T, A, B);
  Qualifier := '';
  Names := TStringList.Create;
  try
    for I := 0 to High(Parts) do
    begin
      if (I = 0) and (Parts[I].B - Parts[I].A = 3) and IsSym(T, Parts[I].A + 1, '.') then
        Qualifier := T[Parts[I].A].Text + '.';
      Names.Add(LowerCase(T[Parts[I].B - 1].Text));
    end;
    Names.Sort;
    Result := Qualifier + 'fts';
    for I := 0 to Names.Count - 1 do
      Result := Result + '_' + Names[I];
  finally
    Names.Free;
  end;
end;

{ True when what stands at [I, J] is used as a number, not as a condition. }
function AsNumber(const T: TToks; A, B, I, J: integer): boolean;
var
  Next, Prev: string;
begin
  Next := '';
  Prev := '';
  if J + 1 < B then
    Next := UpperCase(T[J + 1].Text);
  if I - 1 >= A then
    Prev := UpperCase(T[I - 1].Text);
  Result := (Next = '*') or (Next = '+') or (Next = '-') or (Next = '/') or (Next = '>') or (Next = '<') or (Next = '=') or (Next = '>=') or
    (Next = '<=') or (Next = '<>') or (Next = 'AS') or (Next = 'DESC') or (Next = 'ASC') or (Prev = '*') or (Prev = '+') or (Prev = '-') or
    (Prev = '/') or (Prev = 'BY') or (Prev = 'SELECT') or ((Prev = ',') and (Next <> 'AND') and (Next <> 'OR'));
end;

function TypeName(const T: TToks; A, B: integer): string;
var
  W: string;
begin
  W := UpperCase(T[A].Text);
  if (W = 'SIGNED') or (W = 'UNSIGNED') then
    Result := 'bigint'
  else if W = 'CHAR' then
  begin
    if B - A > 1 then
      Result := 'varchar' + Raw(T, A + 1, B)
    else
      Result := 'text';
  end
  else if W = 'DATETIME' then
    Result := 'timestamp'
  else if W = 'DOUBLE' then
    Result := 'double precision'
  else
    Result := Raw(T, A, B);
end;

{ ORDER BY's list, from A to where the clause ends; EndAt is that place.
  MariaDB sorts NULL as the smallest value and PostgreSQL as the largest,
  so each part that can be NULL says where its NULLs go.  A column that
  never holds NULL is left alone, so its index still serves the order. }
function OrderList(const T: TToks; A, B: integer; InConflict: boolean; out EndAt: integer): string;
var
  I, Depth, Last: integer;
  Parts: TRanges;
  W, Item: string;
  Down, Plain: boolean;
begin
  Depth := 0;
  EndAt := B;
  for I := A to B - 1 do
  begin
    if IsSym(T, I, '(') then
      Inc(Depth)
    else if IsSym(T, I, ')') then
    begin
      Dec(Depth);
      if Depth < 0 then
      begin
        EndAt := I;
        Break;
      end;
    end
    else if (Depth = 0) and (T[I].Kind = tkWord) then
    begin
      W := UpperCase(T[I].Text);
      if (W = 'LIMIT') or (W = 'OFFSET') or (W = 'FOR') or (W = 'UNION') or (W = 'SEPARATOR') or (W = 'ROWS') or (W = 'RANGE') then
      begin
        EndAt := I;
        Break;
      end;
    end;
  end;
  Result := '';
  Parts := SplitCommas(T, A, EndAt);
  for I := 0 to High(Parts) do
  begin
    Last := Parts[I].B;
    Down := IsWord(T, Last - 1, 'DESC');
    if Down or IsWord(T, Last - 1, 'ASC') then
      Dec(Last);
    // a column by itself, a or t.a
    Plain := ((Last - Parts[I].A = 1) and (T[Parts[I].A].Kind = tkWord)) or ((Last - Parts[I].A = 3) and IsSym(T, Parts[I].A + 1, '.'));
    Item := Tr(T, Parts[I].A, Parts[I].B, InConflict);
    if not (Plain and (Pos(',' + LowerCase(T[Last - 1].Text) + ',', Nullable) = 0)) and not ((Last - Parts[I].A = 1) and (T[Parts[I].A].Kind = tkNumber)) then
    begin
      if Down then
        Item := Item + ' NULLS LAST'
      else
        Item := Item + ' NULLS FIRST';
    end;
    if I > 0 then
      Result := Result + ', ';
    Result := Result + Item;
  end;
end;

{ A function call: Name at I, its opening parenthesis at I + 1, the
  closing one at J.  Returns '' for a function left as it is. }
function Call(const T: TToks; A, B, I, J: integer; InConflict: boolean): string;
var
  Name, S, Sep, Order: string;
  Args: TRanges;
  K, P, Q: integer;

  function Arg(N: integer): string;
  begin
    Result := Tr(T, Args[N].A, Args[N].B, InConflict);
  end;

begin
  Result := '';
  Name := UpperCase(T[I].Text);
  Args := SplitCommas(T, I + 2, J);
  if (Name = 'IF') and (Length(Args) = 3) then
    Result := 'CASE WHEN ' + Arg(0) + ' THEN ' + Arg(1) + ' ELSE ' + Arg(2) + ' END'
  else if (Name = 'IFNULL') and (Length(Args) = 2) then
    Result := 'COALESCE(' + Arg(0) + ', ' + Arg(1) + ')'
  else if (Name = 'NOW') or (Name = 'CURRENT_TIMESTAMP') then
  begin
    if Length(Args) = 0 then
      Result := 'LOCALTIMESTAMP(0)'
    else
      Result := 'LOCALTIMESTAMP';
  end
  else if Name = 'UTC_TIMESTAMP' then
    Result := 'CAST(NOW() AT TIME ZONE ''UTC'' AS timestamp(0))'
  else if Name = 'UTC_DATE' then
    Result := 'CAST(NOW() AT TIME ZONE ''UTC'' AS date)'
  else if Name = 'CURDATE' then
    Result := 'CURRENT_DATE'
  else if (Name = 'DATE_FORMAT') and (Length(Args) = 2) and (T[Args[1].A].Kind = tkString) then
    Result := 'to_char(' + Arg(0) + ', ' + DateLetters(T[Args[1].A].Text) + ')'
  else if Name = 'UNIX_TIMESTAMP' then
  begin
    if Length(Args) = 0 then
      Result := 'CAST(EXTRACT(EPOCH FROM NOW()) AS bigint)'
    else if IsWord(T, Args[0].A, 'NOW') and (Args[0].B - Args[0].A = 4) and (T[Args[0].A + 2].Kind = tkNumber) then
      // NOW(6): the seconds with their fraction, as MariaDB gives them
      Result := 'EXTRACT(EPOCH FROM ' + Arg(0) + ')'
    else
      Result := 'CAST(EXTRACT(EPOCH FROM ' + Arg(0) + ') AS bigint)';
  end
  else if (Name = 'FROM_UNIXTIME') and (Length(Args) = 1) then
    Result := 'CAST(to_timestamp(' + Arg(0) + ') AS timestamp(0))'
  else if (Name = 'DATE') and (Length(Args) = 1) then
    Result := 'CAST(' + Arg(0) + ' AS date)'
  else if (Name = 'YEAR') and (Length(Args) = 1) then
    Result := 'CAST(EXTRACT(YEAR FROM ' + Arg(0) + ') AS integer)'
  else if (Name = 'TIMESTAMPDIFF') and (Length(Args) = 3) then
  begin
    S := UpperCase(T[Args[0].A].Text);
    if S = 'SECOND' then
      Q := 1
    else if S = 'MINUTE' then
      Q := 60
    else if S = 'HOUR' then
      Q := 3600
    else
      Q := 86400;
    Result := 'CAST(TRUNC(EXTRACT(EPOCH FROM (' + Arg(2) + ') - (' + Arg(1) + ')) / ' + IntToStr(Q) + ') AS bigint)';
  end
  else if (Name = 'CAST') and (Length(Args) = 1) then
  begin
    P := FindWords(T, I + 2, J, ['AS']);
    if P > 0 then
      Result := 'CAST(' + Tr(T, I + 2, P, InConflict) + ' AS ' + TypeName(T, P + 1, J) + ')';
  end
  else if Name = 'GROUP_CONCAT' then
  begin
    // GROUP_CONCAT([DISTINCT] x [ORDER BY ...] [SEPARATOR 's'])
    P := I + 2;
    Q := J;
    Sep := ''',''';
    K := FindWords(T, P, Q, ['SEPARATOR']);
    if K > 0 then
    begin
      Sep := TokText(T[K + 1]);
      Q := K;
    end;
    Order := '';
    K := FindWords(T, P, Q, ['ORDER', 'BY']);
    if K > 0 then
    begin
      Order := ' ' + Tr(T, K, Q, InConflict);
      Q := K;
    end;
    S := '';
    if IsWord(T, P, 'DISTINCT') then
    begin
      S := 'DISTINCT ';
      Inc(P);
    end;
    // with DISTINCT the order must be by the very text that is joined
    if (S <> '') and (Order <> '') then
      Result := 'string_agg(DISTINCT ' + Tr(T, P, Q, InConflict) + ', ' + Sep + Order + ')'
    else
      Result := 'string_agg(' + S + 'CAST(' + Tr(T, P, Q, InConflict) + ' AS text), ' + Sep + Order + ')';
  end
  else if Name = 'RAND' then
    Result := 'random()'
  else if (Name = 'LOG') and (Length(Args) = 1) then
    // MariaDB's LOG of one number is the natural one
    Result := 'ln(' + Arg(0) + ')'
  else if (Name = 'JSON_VALUE') and (Length(Args) = 2) and (T[Args[1].A].Kind = tkString) and (Copy(T[Args[1].A].Text, 1, 3) = '''$.') then
    Result := '(CAST(' + Arg(0) + ' AS jsonb) ->> ''' + Copy(T[Args[1].A].Text, 4, MaxInt) + ')'
  else if (Name = 'FIND_IN_SET') and (Length(Args) = 2) then
  begin
    if AsNumber(T, A, B, I, J) then
      Result := 'COALESCE(array_position(string_to_array(lower(' + Arg(1) + ' ' + PLAIN + '), '',''), lower(CAST(' + Arg(0) + ' AS text))), 0)'
    else
      Result := '(lower(CAST(' + Arg(0) + ' AS text)) = ANY(string_to_array(lower(' + Arg(1) + ' ' + PLAIN + '), '','')))';
  end
  else if (Name = 'FIELD') and (Length(Args) > 1) then
  begin
    S := '';
    for K := 1 to High(Args) do
    begin
      if K > 1 then
        S := S + ', ';
      S := S + Arg(K);
    end;
    Result := 'COALESCE(array_position(ARRAY[' + S + ']::text[], CAST(' + Arg(0) + ' AS text)), 0)';
  end
  else if ((Name = 'LOCATE') or (Name = 'INSTR')) and (Length(Args) = 2) then
  begin
    // LOCATE(needle, hay); INSTR(hay, needle); BINARY asks for exact letters
    if Name = 'LOCATE' then
    begin
      P := 0;
      Q := 1;
    end
    else
    begin
      P := 1;
      Q := 0;
    end;
    if IsWord(T, Args[P].A, 'BINARY') then
      Result := 'strpos(' + Arg(Q) + ' COLLATE "C", ' + Tr(T, Args[P].A + 1, Args[P].B, InConflict) + ')'
    else
      Result := 'strpos(lower(' + Arg(Q) + ' ' + PLAIN + '), lower(' + Arg(P) + '))';
  end
  else if (Name = 'REPLACE') and (Length(Args) = 3) then
    Result := 'replace(' + Arg(0) + ' ' + PLAIN + ', ' + Arg(1) + ', ' + Arg(2) + ')'
  else if (Name = 'CHAR') and (Length(Args) = 1) and (T[Args[0].A].Kind = tkNumber) then
    Result := 'chr(' + Arg(0) + ')'
  else if Name = 'LAST_INSERT_ID' then
    Result := 'lastval()'
  else if Name = 'DATABASE' then
    Result := 'current_database()'
  else if (Name = 'GET_LOCK') and (Length(Args) = 2) then
    Result := 'exedra_get_lock(' + Arg(0) + ', ' + Arg(1) + ')'
  else if (Name = 'RELEASE_LOCK') and (Length(Args) = 1) then
    Result := 'CASE WHEN pg_advisory_unlock(hashtextextended(' + Arg(0) + ', 0)) THEN 1 ELSE 0 END'
  else if ((Name = 'SUM') or (Name = 'MAX') or (Name = 'MIN')) and (Length(Args) = 1) and IsCondition(T, Args[0].A, Args[0].B) then
    Result := Name + '(CASE WHEN ' + Arg(0) + ' THEN 1 ELSE 0 END)'
  else if InConflict and (Name = 'VALUES') and (Length(Args) = 1) then
    Result := 'EXCLUDED.' + Arg(0);
end;

function Tr(const T: TToks; A, B: integer; InConflict: boolean): string;
var
  I, J, K: integer;
  W, S, Mode: string;
begin
  Result := '';
  I := A;
  while I < B do
  begin
    // (a = b) * 100: a condition counted as 1 or 0
    if IsSym(T, I, '(') and not ((I > A) and (T[I - 1].Kind = tkWord) and not IsWord(T, I - 1, 'AND') and not IsWord(T, I - 1, 'OR') and
      not IsWord(T, I - 1, 'SELECT') and not IsWord(T, I - 1, 'THEN') and not IsWord(T, I - 1, 'ELSE') and not IsWord(T, I - 1, 'BY')) then
    begin
      J := Closing(T, I, B);
      if (IsSym(T, J + 1, '*') or IsSym(T, J + 1, '+') or IsSym(T, I - 1, '*') or IsSym(T, I - 1, '+')) and (J + 1 <= B) and IsCondition(T, I + 1, J) then
      begin
        Emit(Result, '(CASE WHEN ' + Tr(T, I + 1, J, InConflict) + ' THEN 1 ELSE 0 END)');
        I := J + 1;
        Continue;
      end;
    end;
    if T[I].Kind <> tkWord then
    begin
      // MariaDB divides whole numbers into a fraction; PostgreSQL would
      // drop the remainder
      if IsSym(T, I, '/') then
        Emit(Result, '* 1.0 /')
      else
        Emit(Result, TokText(T[I]));
      Inc(I);
      Continue;
    end;
    W := UpperCase(T[I].Text);
    // MATCH(columns) AGAINST (:words IN ... MODE)
    if (W = 'MATCH') and IsSym(T, I + 1, '(') then
    begin
      J := Closing(T, I + 1, B);
      if IsWord(T, J + 1, 'AGAINST') and IsSym(T, J + 2, '(') then
      begin
        K := Closing(T, J + 2, B);
        Mode := 'FALSE';
        if FindWords(T, J + 3, K, ['BOOLEAN']) > 0 then
          Mode := 'TRUE';
        S := 'exedra_tsquery(' + TokText(T[J + 3]) + ', ' + Mode + ')';
        if AsNumber(T, A, B, I, K) then
          Emit(Result, 'ts_rank(' + VectorColumn(T, I + 2, J) + ', ' + S + ')')
        else
          Emit(Result, '(' + VectorColumn(T, I + 2, J) + ' @@ ' + S + ')');
        I := K + 1;
        Continue;
      end;
    end;
    if IsSym(T, I + 1, '(') then
    begin
      J := Closing(T, I + 1, B);
      S := Call(T, A, B, I, J, InConflict);
      if S <> '' then
      begin
        Emit(Result, S);
        I := J + 1;
        Continue;
      end;
    end;
    if (W = 'ORDER') and IsWord(T, I + 1, 'BY') then
    begin
      Emit(Result, 'ORDER BY ' + OrderList(T, I + 2, B, InConflict, J));
      I := J;
      Continue;
    end;
    // x - INTERVAL 5 MINUTE
    if (W = 'INTERVAL') and (I + 2 < B) and (T[I + 1].Kind <> tkString) then
    begin
      if IsSym(T, I + 1, '(') then
        J := Closing(T, I + 1, B)
      else
        J := I + 1;
      if (J + 1 < B) and (T[J + 1].Kind = tkWord) then
      begin
        Emit(Result, 'CAST(' + Tr(T, I + 1, J + 1, InConflict) + ' AS integer) * INTERVAL ''1 ' + LowerCase(T[J + 1].Text) + '''');
        I := J + 2;
        Continue;
      end;
    end;
    // a pattern test reads the text letter by letter, which the
    // case-blind collation does not allow; the test itself ignores case
    if (W = 'NOT') and (IsWord(T, I + 1, 'LIKE') or IsWord(T, I + 1, 'REGEXP') or IsWord(T, I + 1, 'RLIKE')) then
    begin
      if IsWord(T, I + 1, 'LIKE') then
        Emit(Result, PLAIN + ' NOT ILIKE')
      else
        Emit(Result, PLAIN + ' !~*');
      Inc(I, 2);
      Continue;
    end;
    if W = 'LIKE' then
      Emit(Result, PLAIN + ' ILIKE')
    else if (W = 'REGEXP') or (W = 'RLIKE') then
      Emit(Result, PLAIN + ' ~*')
    else if W = 'BINARY' then
    // exact comparison is asked for by the column's own collation
    else if (W = 'CURRENT_TIMESTAMP') then
      Emit(Result, 'LOCALTIMESTAMP(0)')
    else
      Emit(Result, T[I].Text);
    Inc(I);
  end;
end;

{ The assignments after ON DUPLICATE KEY UPDATE.  A column named on the
  right of an assignment means the row already there, and says so. }
function ConflictSets(const T: TToks; A, B: integer; const Table: string): string;
var
  U: TToks;
  Parts: TRanges;
  I, K: integer;
  Cols: string;
begin
  EnterCriticalSection(KeysLock);
  try
    Cols := Columns.Values[LowerCase(Table)];
  finally
    LeaveCriticalSection(KeysLock);
  end;
  U := Copy(T, 0, Length(T));
  Parts := SplitCommas(U, A, B);
  for I := 0 to High(Parts) do
    for K := Parts[I].A + 1 to Parts[I].B - 1 do
      if (U[K].Kind = tkWord) and (Pos(',' + LowerCase(U[K].Text) + ',', Cols) > 0) and not IsSym(U, K - 1, '.') and not IsSym(U, K + 1, '(') and
        not (IsSym(U, K - 1, '(') and IsWord(U, K - 2, 'VALUES')) then
        U[K].Text := Table + '.' + U[K].Text;
  Result := Tr(U, A, B, True);
end;

{ UPDATE t a JOIN u b ON ... SET a.x = ... WHERE ...  as
  UPDATE t a SET x = ... FROM u b WHERE ... }
function UpdateJoin(const T: TToks; JoinAt, SetAt: integer): string;
var
  WhereAt, I, P, Next: integer;
  Items, Conds, Sets, Alias: string;
  Parts: TRanges;
begin
  WhereAt := FindWords(T, SetAt, Length(T), ['WHERE']);
  if WhereAt < 0 then
    WhereAt := Length(T);
  Alias := T[JoinAt - 1].Text;
  Items := '';
  Conds := '';
  I := JoinAt;
  while I < SetAt do
  begin
    // I stands on JOIN
    Next := FindWords(T, I + 1, SetAt, ['JOIN']);
    if Next < 0 then
      Next := SetAt;
    P := FindWords(T, I + 1, Next, ['ON']);
    if P < 0 then
      P := Next;
    if Items <> '' then
      Items := Items + ', ';
    Items := Items + Tr(T, I + 1, P);
    if P < Next then
    begin
      if Conds <> '' then
        Conds := Conds + ' AND ';
      Conds := Conds + '(' + Tr(T, P + 1, Next) + ')';
    end;
    I := Next;
  end;
  Sets := '';
  Parts := SplitCommas(T, SetAt + 1, WhereAt);
  for I := 0 to High(Parts) do
  begin
    P := Parts[I].A;
    // the column set is named without its table
    if IsSym(T, P + 1, '.') and SameText(T[P].Text, Alias) then
      Inc(P, 2);
    if Sets <> '' then
      Sets := Sets + ', ';
    Sets := Sets + Tr(T, P, Parts[I].B);
  end;
  Result := Tr(T, 0, JoinAt) + ' SET ' + Sets + ' FROM ' + Items + ' WHERE ' + Conds;
  if WhereAt < Length(T) then
    Result := Result + ' AND (' + Tr(T, WhereAt + 1, Length(T)) + ')';
end;

{ DELETE a FROM t a JOIN u b ON ... WHERE ...  as
  DELETE FROM t a USING u b WHERE ... }
function DeleteJoin(const T: TToks): string;
var
  JoinAt, WhereAt, I, P, Next: integer;
  Items, Conds: string;
begin
  WhereAt := FindWords(T, 3, Length(T), ['WHERE']);
  if WhereAt < 0 then
    WhereAt := Length(T);
  JoinAt := FindWords(T, 3, WhereAt, ['JOIN']);
  if JoinAt < 0 then
  begin
    Result := 'DELETE FROM ' + Tr(T, 3, Length(T));
    Exit;
  end;
  Items := '';
  Conds := '';
  I := JoinAt;
  while I < WhereAt do
  begin
    Next := FindWords(T, I + 1, WhereAt, ['JOIN']);
    if Next < 0 then
      Next := WhereAt;
    P := FindWords(T, I + 1, Next, ['ON']);
    if P < 0 then
      P := Next;
    if Items <> '' then
      Items := Items + ', ';
    Items := Items + Tr(T, I + 1, P);
    if P < Next then
    begin
      if Conds <> '' then
        Conds := Conds + ' AND ';
      Conds := Conds + '(' + Tr(T, P + 1, Next) + ')';
    end;
    I := Next;
  end;
  Result := 'DELETE FROM ' + Tr(T, 3, JoinAt) + ' USING ' + Items + ' WHERE ' + Conds;
  if WhereAt < Length(T) then
    Result := Result + ' AND (' + Tr(T, WhereAt + 1, Length(T)) + ')';
end;

function Statement(const T: TToks): string;
var
  N, P, Q, I: integer;
  Table, Columns, Key, Sets, Others, Named, One: string;
  Cols: TRanges;
begin
  N := Length(T);
  Result := '';
  if N = 0 then
    Exit;
  // INSERT IGNORE / REPLACE / INSERT ... ON DUPLICATE KEY UPDATE
  if (IsWord(T, 0, 'INSERT') or IsWord(T, 0, 'REPLACE')) and (N > 3) then
  begin
    P := 1;
    if IsWord(T, P, 'IGNORE') then
      Inc(P);
    if IsWord(T, P, 'INTO') then
      Inc(P);
    Table := T[P].Text;
    Columns := '';
    if IsSym(T, P + 1, '(') then
    begin
      Q := Closing(T, P + 1, N);
      Columns := Raw(T, P + 2, Q);
    end
    else
      Q := P;
    I := FindWords(T, Q + 1, N, ['ON', 'DUPLICATE', 'KEY', 'UPDATE']);
    if I > 0 then
    begin
      Key := KeyFor(Table, Columns);
      Result := 'INSERT INTO ' + Tr(T, P, I) + ' ON CONFLICT (' + Key + ') DO UPDATE SET ' + ConflictSets(T, I + 4, N, Table);
    end
    else if IsWord(T, 0, 'REPLACE') then
    begin
      Key := KeyFor(Table, Columns);
      Sets := '';
      Cols := SplitCommas(T, P + 2, Q);
      for I := 0 to High(Cols) do
        if Pos(',' + LowerCase(T[Cols[I].A].Text) + ',', ',' + Key + ',') = 0 then
        begin
          if Sets <> '' then
            Sets := Sets + ', ';
          Sets := Sets + T[Cols[I].A].Text + ' = EXCLUDED.' + T[Cols[I].A].Text;
        end;
      // REPLACE puts a whole new row in: a column it does not name goes
      // back to its default
      EnterCriticalSection(KeysLock);
      try
        Others := SiteSqlRead.Columns.Values[LowerCase(Table)];
      finally
        LeaveCriticalSection(KeysLock);
      end;
      Named := ',' + LowerCase(StringReplace(Columns, ' ', '', [rfReplaceAll])) + ',';
      while Length(Others) > 1 do
      begin
        Delete(Others, 1, 1);
        One := Copy(Others, 1, Pos(',', Others) - 1);
        Delete(Others, 1, Length(One));
        if (One <> '') and (Pos(',' + One + ',', Named) = 0) and (Pos(',' + One + ',', ',' + Key + ',') = 0) then
        begin
          if Sets <> '' then
            Sets := Sets + ', ';
          Sets := Sets + One + ' = DEFAULT';
        end;
      end;
      Result := 'INSERT INTO ' + Tr(T, P, N) + ' ON CONFLICT (' + Key + ') DO ';
      if Sets = '' then
        Result := Result + 'NOTHING'
      else
        Result := Result + 'UPDATE SET ' + Sets;
    end
    else if IsWord(T, 1, 'IGNORE') then
      Result := 'INSERT INTO ' + Tr(T, P, N) + ' ON CONFLICT DO NOTHING'
    else
      Result := Tr(T, 0, N);
    Exit;
  end;
  if IsWord(T, 0, 'UPDATE') then
  begin
    Q := FindWords(T, 1, N, ['SET']);
    P := FindWords(T, 1, N, ['JOIN']);
    if (P > 0) and (Q > P) and not IsWord(T, P - 1, 'LEFT') then
      Exit(UpdateJoin(T, P, Q));
  end;
  if IsWord(T, 0, 'DELETE') and IsWord(T, 2, 'FROM') and (N > 3) then
    if (FindWords(T, 3, N, ['LEFT']) < 0) then
      Exit(DeleteJoin(T));
  Result := Tr(T, 0, N);
  // a row lock on a statement with an outer join names the table to lock
  if IsWord(T, N - 2, 'FOR') and IsWord(T, N - 1, 'UPDATE') and (FindWords(T, 0, N, ['LEFT', 'JOIN']) > 0) then
  begin
    P := FindWords(T, 0, N, ['FROM']);
    if P > 0 then
    begin
      if (P + 2 < N) and (T[P + 2].Kind = tkWord) and not IsWord(T, P + 2, 'LEFT') and not IsWord(T, P + 2, 'JOIN') and not IsWord(T, P + 2, 'WHERE') then
        Result := Result + ' OF ' + T[P + 2].Text
      else
        Result := Result + ' OF ' + T[P + 1].Text;
    end;
  end;
end;

function PgTranslate(const SQL: string): string;
begin
  Result := Statement(Tokenize(SQL));
end;

{ ---- values ---- }

function PgValue(const V: variant): string;
var
  S: string;
  F: TFormatSettings;
  I: integer;
  Plain: boolean;
begin
  case VarType(V) and varTypeMask of
    varEmpty, varNull: Result := 'NULL';
    varSmallint, varInteger, varShortInt, varByte, varWord, varLongWord, varInt64, varQWord: Result := VarToStr(V);
    varBoolean:
      if V then
        Result := '1'
      else
        Result := '0';
    varSingle, varDouble, varCurrency:
    begin
      F := DefaultFormatSettings;
      F.DecimalSeparator := '.';
      Result := FloatToStr(double(V), F);
    end;
    varDate: Result := '''' + FormatDateTime('yyyy"-"mm"-"dd hh":"nn":"ss', TDateTime(V)) + '''';
    else
    begin
      S := VarToStr(V);
      // the server takes no zero byte in a text
      if Pos(#0, S) > 0 then
        S := StringReplace(S, #0, '', [rfReplaceAll]);
      Plain := True;
      for I := 1 to Length(S) do
        if S[I] < ' ' then
          Plain := False;
      if Plain then
        Result := '''' + StringReplace(S, '''', '''''', [rfReplaceAll]) + ''''
      else
      begin
        // a line feed or a tab is written by its escape: the statement's
        // text passes through a list of lines on its way, which would
        // change a carriage return.  In this form a backslash is doubled.
        Result := 'E''';
        for I := 1 to Length(S) do
          case S[I] of
            '''': Result := Result + '''''';
            '\': Result := Result + '\\';
            #10: Result := Result + '\n';
            #13: Result := Result + '\r';
            #9: Result := Result + '\t';
            #1..#8, #11, #12, #14..#31: Result := Result + '\x' + IntToHex(Ord(S[I]), 2);
            else
              Result := Result + S[I];
          end;
        Result := Result + '''';
      end;
    end;
  end;
end;

function PgStatement(const SQL: string; const Values: array of variant): string;
var
  T, U: TToks;
  Names: TStringList;
  I, K: integer;
  Translated: string;
begin
  T := Tokenize(SQL);
  Translated := Statement(T);
  if Length(Values) = 0 then
    Exit(Translated);
  // a value belongs to a name, in the order the names first stand
  Names := TStringList.Create;
  try
    for I := 0 to High(T) do
      if (T[I].Kind = tkParam) and (Names.IndexOf(LowerCase(T[I].Text)) < 0) then
        Names.Add(LowerCase(T[I].Text));
    // the translated text is in the server's own words: no backslash escapes
    U := Tokenize(Translated, True);
    Result := '';
    for I := 0 to High(U) do
      if U[I].Kind = tkParam then
      begin
        K := Names.IndexOf(LowerCase(U[I].Text));
        if (K < 0) or (K > High(Values)) then
          raise Exception.Create('A statement has no value for ' + U[I].Text);
        Emit(Result, PgValue(Values[K]));
      end
      else
        Emit(Result, U[I].Text);
  finally
    Names.Free;
  end;
end;

{ ---- tables ---- }

{ INDEX [name] (cols), UNIQUE ..., FULLTEXT ..., starting at A: the
  statement that makes the index, or for UNIQUE inside a table '' with
  Inline set to the constraint. }
function IndexItem(const Table: string; const T: TToks; A, B: integer; InTable: boolean; out Inline: string): string;
var
  Kind, Name, Columns: string;
  P, Q: integer;
begin
  Inline := '';
  Result := '';
  Kind := UpperCase(T[A].Text);
  P := A + 1;
  if (Kind <> 'INDEX') and (Kind <> 'KEY') and (IsWord(T, P, 'INDEX') or IsWord(T, P, 'KEY')) then
    Inc(P);
  Name := '';
  if (P < B) and not IsSym(T, P, '(') then
  begin
    Name := T[P].Text;
    Inc(P);
  end;
  if not IsSym(T, P, '(') then
    Exit;
  Q := Closing(T, P, B);
  Columns := IndexColumns(T, P + 1, Q);
  if Kind = 'FULLTEXT' then
    Result := 'ALTER TABLE ' + Table + ' ADD COLUMN IF NOT EXISTS ' + VectorColumn(T, P + 1, Q) + ' tsvector GENERATED ALWAYS AS (' +
      TextVector(T, P + 1, Q) + ') STORED; CREATE INDEX IF NOT EXISTS ' + IndexName(Table, Name, Columns) + ' ON ' + Table + ' USING GIN (' + VectorColumn(T, P + 1, Q) + ')'
  else if Kind = 'UNIQUE' then
  begin
    NoteKey(Table, Columns);
    if InTable then
      Inline := 'UNIQUE (' + Columns + ')'
    else
      Result := 'CREATE UNIQUE INDEX IF NOT EXISTS ' + IndexName(Table, Name, Columns) + ' ON ' + Table + ' (' + Columns + ')';
  end
  else
    Result := 'CREATE INDEX IF NOT EXISTS ' + IndexName(Table, Name, Columns) + ' ON ' + Table + ' (' + Columns + ')';
end;

function ReadColumn(const Table: string; const T: TToks; A, B: integer): TColumn;
var
  I, J: integer;
  W, Size, Collate: string;
  IsText, Identity: boolean;
begin
  Result := Default(TColumn);
  Result.Name := T[A].Text;
  NoteColumn(Table, Result.Name);
  I := A + 1;
  W := UpperCase(T[I].Text);
  Inc(I);
  Size := '';
  if IsSym(T, I, '(') then
  begin
    J := Closing(T, I, B);
    Size := Raw(T, I, J + 1);
    I := J + 1;
  end;
  IsText := False;
  if (W = 'TINYINT') or (W = 'SMALLINT') or (W = 'BOOLEAN') or (W = 'BOOL') then
    Result.TypeSql := 'SMALLINT'
  else if (W = 'INT') or (W = 'INTEGER') or (W = 'MEDIUMINT') then
    Result.TypeSql := 'INTEGER'
  else if W = 'BIGINT' then
    Result.TypeSql := 'BIGINT'
  else if (W = 'VARCHAR') or (W = 'CHAR') then
  begin
    // CHAR would come back padded with blanks
    Result.TypeSql := 'VARCHAR' + Size;
    IsText := True;
  end
  else if (W = 'TEXT') or (W = 'TINYTEXT') or (W = 'MEDIUMTEXT') or (W = 'LONGTEXT') or (W = 'JSON') then
  begin
    Result.TypeSql := 'TEXT';
    IsText := True;
  end
  else if (W = 'BLOB') or (W = 'TINYBLOB') or (W = 'MEDIUMBLOB') or (W = 'LONGBLOB') or (W = 'VARBINARY') or (W = 'BINARY') then
    Result.TypeSql := 'BYTEA'
  else if (W = 'DATETIME') or (W = 'TIMESTAMP') then
  begin
    if Size = '' then
      Size := '(0)';
    Result.TypeSql := 'TIMESTAMP' + Size;
  end
  else if W = 'DOUBLE' then
    Result.TypeSql := 'DOUBLE PRECISION'
  else if W = 'FLOAT' then
    Result.TypeSql := 'REAL'
  else
    Result.TypeSql := W + Size;
  Collate := CI;
  Identity := False;
  while I < B do
  begin
    W := UpperCase(T[I].Text);
    if W = 'UNSIGNED' then
    begin
      if Result.TypeSql = 'INTEGER' then
        Result.TypeSql := 'BIGINT';
    end
    else if (W = 'CHARACTER') and IsWord(T, I + 1, 'SET') then
      Inc(I, 2)
    else if W = 'CHARSET' then
      Inc(I)
    else if W = 'COLLATE' then
    begin
      Inc(I);
      if Pos('_bin', LowerCase(T[I].Text)) > 0 then
        Collate := 'COLLATE "C"';
    end
    else if W = 'AUTO_INCREMENT' then
      Identity := True
    else if (W = 'NOT') and IsWord(T, I + 1, 'NULL') then
    begin
      Result.NotNull := True;
      Inc(I);
    end
    else if W = 'NULL' then
      Result.Nullable := True
    else if W = 'DEFAULT' then
    begin
      Inc(I);
      Result.HasDefault := True;
      if IsSym(T, I, '(') then
      begin
        J := Closing(T, I, B);
        Result.Default := Tr(T, I, J + 1);
        I := J;
      end
      else if IsWord(T, I, 'CURRENT_TIMESTAMP') or IsWord(T, I, 'NOW') then
      begin
        if IsSym(T, I + 1, '(') then
        begin
          J := Closing(T, I + 1, B);
          if J > I + 2 then
            Result.Default := 'LOCALTIMESTAMP'
          else
            Result.Default := 'LOCALTIMESTAMP(0)';
          I := J;
        end
        else
          Result.Default := 'LOCALTIMESTAMP(0)';
      end
      else if IsSym(T, I, '-') then
      begin
        Result.Default := '-' + T[I + 1].Text;
        Inc(I);
      end
      else
        Result.Default := TokText(T[I]);
    end
    else if (W = 'ON') and IsWord(T, I + 1, 'UPDATE') then
    begin
      Result.Touch := True;
      Inc(I, 2);
      if IsSym(T, I + 1, '(') then
        I := Closing(T, I + 1, B);
    end
    else if (W = 'PRIMARY') and IsWord(T, I + 1, 'KEY') then
    begin
      Result.Rest := Result.Rest + ' PRIMARY KEY';
      NoteKey(Table, Result.Name);
      Inc(I);
    end
    else if W = 'UNIQUE' then
    begin
      Result.Rest := Result.Rest + ' UNIQUE';
      NoteKey(Table, Result.Name);
      if IsWord(T, I + 1, 'KEY') then
        Inc(I);
    end
    else if (W = 'AFTER') or (W = 'COMMENT') then
      Inc(I)
    else if W = 'FIRST' then
    else
      Result.Rest := Result.Rest + ' ' + TokText(T[I]);
    Inc(I);
  end;
  if not Result.NotNull and (Pos('PRIMARY KEY', Result.Rest) = 0) then
  begin
    EnterCriticalSection(KeysLock);
    try
      if Pos(',' + LowerCase(Result.Name) + ',', Nullable) = 0 then
        Nullable := Nullable + LowerCase(Result.Name) + ',';
    finally
      LeaveCriticalSection(KeysLock);
    end;
  end;
  if IsText then
    Result.TypeSql := Result.TypeSql + ' ' + Collate;
  if Identity then
    Result.TypeSql := Result.TypeSql + ' GENERATED BY DEFAULT AS IDENTITY';
end;

function ColumnText(const C: TColumn): string;
begin
  Result := C.Name + ' ' + C.TypeSql;
  if C.NotNull then
    Result := Result + ' NOT NULL';
  if C.HasDefault then
    Result := Result + ' DEFAULT ' + C.Default;
  Result := Result + C.Rest;
end;

{ ON UPDATE CURRENT_TIMESTAMP is a trigger here. }
function TouchTrigger(const Table, Column: string): string;
begin
  Result := 'CREATE OR REPLACE FUNCTION ' + Table + '_touch() RETURNS trigger LANGUAGE plpgsql AS $f$ BEGIN NEW.' + Column +
    ' := LOCALTIMESTAMP(0); RETURN NEW; END $f$; DROP TRIGGER IF EXISTS ' + Table + '_touch ON ' + Table + '; CREATE TRIGGER ' + Table +
    '_touch BEFORE UPDATE ON ' + Table + ' FOR EACH ROW EXECUTE FUNCTION ' + Table + '_touch()';
end;

function CreateTable(const T: TToks): string;
var
  P, Q, I: integer;
  Table, Body, After, Inline, S: string;
  Items: TRanges;
  W: string;
  C: TColumn;
begin
  P := 2;
  if IsWord(T, P, 'IF') then
    Inc(P, 3);
  Table := T[P].Text;
  Q := Closing(T, P + 1, Length(T));
  Items := SplitCommas(T, P + 2, Q);
  Body := '';
  After := '';
  for I := 0 to High(Items) do
  begin
    W := UpperCase(T[Items[I].A].Text);
    S := '';
    if (W = 'PRIMARY') and IsWord(T, Items[I].A + 1, 'KEY') then
    begin
      S := 'PRIMARY KEY (' + IndexColumns(T, Items[I].A + 3, Items[I].B - 1) + ')';
      NoteKey(Table, IndexColumns(T, Items[I].A + 3, Items[I].B - 1));
    end
    else if ((W = 'INDEX') or (W = 'KEY') or (W = 'UNIQUE') or (W = 'FULLTEXT')) and (IsSym(T, Items[I].A + 1, '(') or IsSym(T, Items[I].A + 2, '(') or
      IsSym(T, Items[I].A + 3, '(')) then
    begin
      Inline := '';
      S := IndexItem(Table, T, Items[I].A, Items[I].B, True, Inline);
      if S <> '' then
        After := After + '; ' + S;
      S := Inline;
    end
    else
    begin
      C := ReadColumn(Table, T, Items[I].A, Items[I].B);
      S := ColumnText(C);
      if C.Touch then
        After := After + '; ' + TouchTrigger(Table, C.Name);
    end;
    if S <> '' then
    begin
      if Body <> '' then
        Body := Body + ', ';
      Body := Body + S;
    end;
  end;
  // the indexes are made with the table and not again: one an upgrade
  // dropped later stays dropped
  Result := 'DO $t$ BEGIN IF to_regclass(''' + Table + ''') IS NULL THEN CREATE TABLE ' + Table + ' (' + Body + ')' + After + '; END IF; END $t$';
end;

function AlterTable(const T: TToks): string;
var
  Table, Actions, After, S, Inline, W, W2: string;
  Items: TRanges;
  I, A, B: integer;
  C: TColumn;

  procedure Action(const Text: string);
  begin
    if Actions <> '' then
      Actions := Actions + ', ';
    Actions := Actions + Text;
  end;

begin
  Table := T[2].Text;
  Items := SplitCommas(T, 3, Length(T));
  Actions := '';
  After := '';
  for I := 0 to High(Items) do
  begin
    A := Items[I].A;
    B := Items[I].B;
    W := UpperCase(T[A].Text);
    W2 := '';
    if A + 1 < B then
      W2 := UpperCase(T[A + 1].Text);
    if (W = 'ADD') and ((W2 = 'INDEX') or (W2 = 'KEY') or (W2 = 'UNIQUE') or (W2 = 'FULLTEXT')) then
    begin
      S := IndexItem(Table, T, A + 1, B, False, Inline);
      if S <> '' then
        After := After + '; ' + S;
    end
    else if W = 'ADD' then
    begin
      Inc(A);
      if IsWord(T, A, 'COLUMN') then
        Inc(A);
      if IsWord(T, A, 'IF') then
        Inc(A, 3);
      C := ReadColumn(Table, T, A, B);
      Action('ADD COLUMN IF NOT EXISTS ' + ColumnText(C));
    end
    else if (W = 'MODIFY') or (W = 'CHANGE') then
    begin
      Inc(A);
      if IsWord(T, A, 'COLUMN') then
        Inc(A);
      C := ReadColumn(Table, T, A, B);
      S := C.TypeSql;
      Action('ALTER COLUMN ' + C.Name + ' TYPE ' + S);
      if C.NotNull then
        Action('ALTER COLUMN ' + C.Name + ' SET NOT NULL')
      else
        Action('ALTER COLUMN ' + C.Name + ' DROP NOT NULL');
      if C.HasDefault then
        Action('ALTER COLUMN ' + C.Name + ' SET DEFAULT ' + C.Default)
      else
        Action('ALTER COLUMN ' + C.Name + ' DROP DEFAULT');
    end
    else if (W = 'DROP') and ((W2 = 'INDEX') or (W2 = 'KEY')) then
      // an index made without a name is called by its columns here and by
      // its first column in MariaDB; a FULLTEXT index goes with its column
      After := After +
        '; DO $t$ DECLARE r record; BEGIN FOR r IN SELECT indexname, substring(indexdef from ''gin \((fts_[a-z0-9_]+)\)'') AS vector FROM pg_indexes WHERE schemaname = current_schema()'
        + ' AND tablename = ''' + LowerCase(Table) + ''' AND (indexname = ''' + IndexName(Table, T[A + 2].Text, '') + ''' OR indexname LIKE ''' +
        StringReplace(IndexName(Table, T[A + 2].Text, ''), '_', '\_', [rfReplaceAll]) +
        '\_%'') LOOP IF r.vector IS NULL THEN EXECUTE ''DROP INDEX '' || quote_ident(r.indexname);' + ' ELSE EXECUTE ''ALTER TABLE ' +
        Table + ' DROP COLUMN '' || quote_ident(r.vector); END IF; END LOOP; END $t$'
    else if (W = 'DROP') and (W2 = 'COLUMN') then
      Action('DROP COLUMN IF EXISTS ' + T[A + 2].Text)
    else
      Action(Tr(T, A, B));
  end;
  Result := '';
  if Actions <> '' then
    Result := 'ALTER TABLE ' + Table + ' ' + Actions;
  if After <> '' then
  begin
    if Result = '' then
      Delete(After, 1, 2);
    Result := Result + After;
  end;
end;

function PgSchema(const Statement: string): string;
var
  T: TToks;
begin
  T := Tokenize(Statement);
  if IsWord(T, 0, 'CREATE') and IsWord(T, 1, 'TABLE') then
    Result := CreateTable(T)
  else if IsWord(T, 0, 'ALTER') and IsWord(T, 1, 'TABLE') then
    Result := AlterTable(T)
  else
    Result := SiteSqlPg.Statement(T);
end;

function PgSessionStart: string;
begin
  // notices and warnings are not wanted in the program's log
  // and times are kept in UTC: the pages hand them to browsers as UTC
  Result := 'SET standard_conforming_strings = on; SET client_min_messages = error; SET TIME ZONE ''UTC''';
end;

function PgSetup: string;
begin
  Result :=
    // letter case and accents ignored, as MariaDB's stock collation does
    'CREATE COLLATION IF NOT EXISTS exedra_ci (provider = icu, locale = ''und-u-ks-level1'', deterministic = false); ' +
    // SOUNDEX comes with PostgreSQL but has to be switched on; a server
    // that will not allow it only loses the sound-alike search
    'DO $f$ BEGIN CREATE EXTENSION IF NOT EXISTS fuzzystrmatch; EXCEPTION WHEN OTHERS THEN NULL; END $f$; ' +
    // GET_LOCK: a named lock, waited for up to so many seconds
    'CREATE OR REPLACE FUNCTION exedra_get_lock(lock_name text, seconds integer) RETURNS integer LANGUAGE plpgsql AS $f$ ' +
    'DECLARE give_up timestamptz := clock_timestamp() + seconds * interval ''1 second''; ' + 'BEGIN LOOP ' +
    'IF pg_try_advisory_lock(hashtextextended(lock_name, 0)) THEN RETURN 1; END IF; ' + 'IF clock_timestamp() >= give_up THEN RETURN 0; END IF; ' +
    'PERFORM pg_sleep(0.05); END LOOP; END $f$; ' +
    // the words of a search, in MariaDB's notation (+must -not "a phrase"
    // begin*), as a text query
    'CREATE OR REPLACE FUNCTION exedra_tsquery(words text, with_signs boolean) RETURNS tsquery LANGUAGE plpgsql IMMUTABLE AS $f$ ' +
    'DECLARE m text[]; piece text; pieces text[]; part tsquery; x tsquery; must tsquery; may tsquery; never tsquery; answer tsquery; n integer; ' +
    'BEGIN ' + 'FOR m IN SELECT regexp_matches(words, ''([+-]?)(?:"([^"]*)"|([^\s"()<>~@]+))'', ''g'') LOOP ' + 'part := NULL; ' +
    'IF m[2] IS NOT NULL THEN part := phraseto_tsquery(''simple'', translate(m[2], ''./@:~'', ''     '')); ' + 'ELSIF right(m[3], 1) = ''*'' THEN ' +
    'pieces := regexp_split_to_array(btrim(regexp_replace(lower(m[3]), ''[^[:alnum:]]+'', '' '', ''g'')), '' ''); ' +
    'n := coalesce(array_length(pieces, 1), 0); ' + 'FOR i IN 1..n LOOP piece := pieces[i]; ' + 'IF piece <> '''' THEN ' +
    'x := to_tsquery(''simple'', quote_literal(piece) || CASE WHEN i = n THEN '':*'' ELSE '''' END); ' + 'IF part IS NULL THEN part := x; ELSE part := part <-> x; END IF; ' +
    'END IF; END LOOP; ' + 'ELSE part := phraseto_tsquery(''simple'', translate(m[3], ''./@:~'', ''     '')); END IF; ' +
    'IF part IS NOT NULL AND numnode(part) > 0 THEN ' + 'IF with_signs AND m[1] = ''-'' THEN IF never IS NULL THEN never := part; ELSE never := never || part; END IF; ' +
    'ELSIF with_signs AND m[1] = ''+'' THEN IF must IS NULL THEN must := part; ELSE must := must && part; END IF; ' +
    'ELSE IF may IS NULL THEN may := part; ELSE may := may || part; END IF; ' + 'END IF; END IF; ' + 'END LOOP; ' + 'answer := coalesce(must, may); ' +
    'IF answer IS NOT NULL AND never IS NOT NULL THEN answer := answer && !!never; END IF; ' + 'RETURN answer; END $f$';
end;

end.
