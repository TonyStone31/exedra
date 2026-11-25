unit SiteSqlLite;

{ SQLite functions and SQL translation for SiteSql. Times are UTC text;
  exedra_ci compares text without case. Full-text search scans rows,
  suitable for small sites. Named locks work within and between processes
  through connection ownership and hashed lock files. }

{$mode objfpc}{$H+}
{$pointermath on}

interface

{ Gives a newly opened connection (its sqlite3 handle) the functions and
  the collation. }
procedure LiteOpened(Handle: Pointer);
{ True when the connection was left inside a transaction. }
function LiteInTransaction(Handle: Pointer): boolean;
{ What each new connection runs first, one statement a line. }
function LiteSessionStart: string;
{ A CREATE TABLE, ALTER TABLE or other registered statement, as one or
  more statements, one a line. }
function LiteSchema(const Statement: string): string;
{ A statement translated, its parameters left as they are. }
function LiteTranslate(const SQL: string): string;
{ The names of a statement's parameters in the order they first stand. }
function LiteParamNames(const SQL: string): string;

implementation

uses
  {$ifdef unix} BaseUnix, Unix, {$endif} SysUtils, Classes, DateUtils, Math, ctypes, RegExpr, sqlite3dyn, SiteSqlRead;

const
  CI = 'COLLATE exedra_ci';
  STAMP = 'yyyy"-"mm"-"dd hh":"nn":"ss';

  { ---- the functions ---- }

function ArgNull(V: ppsqlite3_value; I: integer): boolean;
begin
  Result := sqlite3_value_type(V[I]) = SQLITE_NULL;
end;

function ArgText(V: ppsqlite3_value; I: integer): string;
var
  P: pansichar;
begin
  P := sqlite3_value_text(V[I]);
  if P = nil then
    Result := ''
  else
    Result := P;
end;

procedure Give(Ctx: psqlite3_context; const S: string);
begin
  sqlite3_result_text(Ctx, pansichar(S), Length(S), sqlite3_destructor_type(-1));
end;

{ A time as the tables hold it; False for text that is no time. }
function ReadTime(const S: string; out D: TDateTime): boolean;
var
  Y, M, Dy, H, N, Sc: integer;
begin
  Result := False;
  D := 0;
  if (Length(S) < 10) or (S[5] <> '-') or (S[8] <> '-') then
    Exit;
  Y := StrToIntDef(Copy(S, 1, 4), -1);
  M := StrToIntDef(Copy(S, 6, 2), -1);
  Dy := StrToIntDef(Copy(S, 9, 2), -1);
  H := 0;
  N := 0;
  Sc := 0;
  if Length(S) >= 16 then
  begin
    H := StrToIntDef(Copy(S, 12, 2), -1);
    N := StrToIntDef(Copy(S, 15, 2), -1);
    if Length(S) >= 19 then
      Sc := StrToIntDef(Copy(S, 18, 2), -1);
  end;
  Result := TryEncodeDateTime(Y, M, Dy, H, N, Sc, 0, D);
end;

function UtcNow: TDateTime;
begin
  Result := LocalTimeToUniversal(Now);
end;

{ NOW(); NOW(6) with thousandths of the second, which is as fine as the
  clock gives and as the database library reads back }
procedure FnNow(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
begin
  if N > 0 then
    Give(Ctx, FormatDateTime(STAMP + '"."zzz', UtcNow))
  else
    Give(Ctx, FormatDateTime(STAMP, UtcNow));
end;

procedure FnUtcNow(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
begin
  Give(Ctx, FormatDateTime(STAMP, UtcNow));
end;

procedure FnToday(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
begin
  Give(Ctx, FormatDateTime('yyyy"-"mm"-"dd', UtcNow));
end;

procedure FnUtcToday(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
begin
  Give(Ctx, FormatDateTime('yyyy"-"mm"-"dd', UtcNow));
end;

{ DATE_FORMAT(time, '%Y-%m-%d %H:%i:%s') }
procedure FnDateFormat(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
const
  DAYS: array[1..7] of string = ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday');
var
  D: TDateTime;
  F, R: string;
  I: integer;
  Y, M, Dy, H, Mi, S, Ms: word;
begin
  if ArgNull(V, 0) or not ReadTime(ArgText(V, 0), D) then
  begin
    sqlite3_result_null(Ctx);
    Exit;
  end;
  F := ArgText(V, 1);
  DecodeDateTime(D, Y, M, Dy, H, Mi, S, Ms);
  R := '';
  I := 1;
  while I <= Length(F) do
  begin
    if (F[I] = '%') and (I < Length(F)) then
    begin
      Inc(I);
      case F[I] of
        'Y': R := R + Format('%.4d', [Y]);
        'y': R := R + Format('%.2d', [Y mod 100]);
        'm': R := R + Format('%.2d', [M]);
        'c': R := R + IntToStr(M);
        'd': R := R + Format('%.2d', [Dy]);
        'e': R := R + IntToStr(Dy);
        'H': R := R + Format('%.2d', [H]);
        'h', 'I': R := R + Format('%.2d', [(H + 11) mod 12 + 1]);
        'i': R := R + Format('%.2d', [Mi]);
        's', 'S': R := R + Format('%.2d', [S]);
        'p': if H < 12 then
            R := R + 'AM'
          else
            R := R + 'PM';
        'M': R := R + DefaultFormatSettings.LongMonthNames[M];
        'b': R := R + DefaultFormatSettings.ShortMonthNames[M];
        'W': R := R + DAYS[DayOfWeek(D)];
        'a': R := R + Copy(DAYS[DayOfWeek(D)], 1, 3);
        'j': R := R + Format('%.3d', [DayOfTheYear(D)]);
        'T': R := R + Format('%.2d:%.2d:%.2d', [H, Mi, S]);
        else
          R := R + F[I];
      end;
    end
    else
      R := R + F[I];
    Inc(I);
  end;
  Give(Ctx, R);
end;

procedure FnUnix(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
var
  D: TDateTime;
  S: string;
begin
  if N = 0 then
    sqlite3_result_int64(Ctx, DateTimeToUnix(UtcNow))
  else if ArgNull(V, 0) or not ReadTime(ArgText(V, 0), D) then
    sqlite3_result_null(Ctx)
  else
  begin
    S := ArgText(V, 0);
    // a time with a fraction gives seconds with one
    if (Length(S) > 20) and (S[20] = '.') then
      sqlite3_result_double(Ctx, DateTimeToUnix(D) + StrToIntDef(Copy(S + '000000', 21, 6), 0) / 1000000)
    else
      sqlite3_result_int64(Ctx, DateTimeToUnix(D));
  end;
end;

procedure FnFromUnix(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
begin
  if ArgNull(V, 0) then
    sqlite3_result_null(Ctx)
  else
    Give(Ctx, FormatDateTime(STAMP, UnixToDateTime(sqlite3_value_int64(V[0]))));
end;

{ bt_time_add(time, amount, 'MINUTE'): what x + INTERVAL amount MINUTE is
  written as; a date without a clock stays one when days are added. }
procedure FnTimeAdd(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
var
  D: TDateTime;
  S, U: string;
  A: int64;
begin
  S := ArgText(V, 0);
  if ArgNull(V, 0) or ArgNull(V, 1) or not ReadTime(S, D) then
  begin
    sqlite3_result_null(Ctx);
    Exit;
  end;
  A := sqlite3_value_int64(V[1]);
  U := UpperCase(ArgText(V, 2));
  if U = 'SECOND' then
    D := IncSecond(D, A)
  else if U = 'MINUTE' then
    D := IncMinute(D, A)
  else if U = 'HOUR' then
    D := IncHour(D, A)
  else if U = 'DAY' then
    D := IncDay(D, A)
  else if U = 'WEEK' then
    D := IncWeek(D, A)
  else if U = 'MONTH' then
    D := IncMonth(D, A)
  else if U = 'YEAR' then
    D := IncYear(D, A);
  if (Length(S) = 10) and ((U = 'DAY') or (U = 'WEEK') or (U = 'MONTH') or (U = 'YEAR')) then
    Give(Ctx, FormatDateTime('yyyy"-"mm"-"dd', D))
  else
    Give(Ctx, FormatDateTime(STAMP, D));
end;

{ TIMESTAMPDIFF('MINUTE', earlier, later) }
procedure FnTimeDiff(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
var
  A, B: TDateTime;
  U: string;
  Seconds: int64;
begin
  if ArgNull(V, 1) or ArgNull(V, 2) or not ReadTime(ArgText(V, 1), A) or not ReadTime(ArgText(V, 2), B) then
  begin
    sqlite3_result_null(Ctx);
    Exit;
  end;
  U := UpperCase(ArgText(V, 0));
  Seconds := Round((B - A) * SecsPerDay);
  if U = 'MINUTE' then
    Seconds := Seconds div 60
  else if U = 'HOUR' then
    Seconds := Seconds div 3600
  else if U = 'DAY' then
    Seconds := Seconds div 86400;
  sqlite3_result_int64(Ctx, Seconds);
end;

procedure FnYear(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
var
  D: TDateTime;
begin
  if ArgNull(V, 0) or not ReadTime(ArgText(V, 0), D) then
    sqlite3_result_null(Ctx)
  else
    sqlite3_result_int64(Ctx, YearOf(D));
end;

{ CONCAT: NULL when a part is NULL, as in MariaDB. }
procedure FnConcat(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
var
  I: integer;
  S: string;
begin
  S := '';
  for I := 0 to N - 1 do
  begin
    if ArgNull(V, I) then
    begin
      sqlite3_result_null(Ctx);
      Exit;
    end;
    S := S + ArgText(V, I);
  end;
  Give(Ctx, S);
end;

{ FIND_IN_SET('b', 'a,b,c') is 2 }
procedure FnFindInSet(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
var
  Want, List: string;
  P, Start, Index: integer;
begin
  if ArgNull(V, 0) or ArgNull(V, 1) then
  begin
    sqlite3_result_null(Ctx);
    Exit;
  end;
  Want := LowerCase(ArgText(V, 0));
  List := LowerCase(ArgText(V, 1)) + ',';
  Index := 1;
  Start := 1;
  if List <> ',' then
    for P := 1 to Length(List) do
      if List[P] = ',' then
      begin
        if Copy(List, Start, P - Start) = Want then
        begin
          sqlite3_result_int64(Ctx, Index);
          Exit;
        end;
        Start := P + 1;
        Inc(Index);
      end;
  sqlite3_result_int64(Ctx, 0);
end;

{ FIELD(x, 'a', 'b') is the place of x among the rest, 0 when not there }
procedure FnField(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
var
  I: integer;
  X: string;
begin
  X := LowerCase(ArgText(V, 0));
  for I := 1 to N - 1 do
    if not ArgNull(V, I) and (LowerCase(ArgText(V, I)) = X) then
    begin
      sqlite3_result_int64(Ctx, I);
      Exit;
    end;
  sqlite3_result_int64(Ctx, 0);
end;

threadvar
  LastPattern: string;
  LastRegex: TRegExpr;

{ The character classes MariaDB's patterns name, [:alnum:] and the like,
  written out: the pattern reader here does not know the names.  Bytes of
  letters beyond a-z count as letters. }
function PlainClasses(const Pattern: string): string;
const
  NAMES: array[0..7] of string = ('[:alnum:]', '[:alpha:]', '[:digit:]', '[:space:]', '[:cntrl:]', '[:upper:]', '[:lower:]', '[:punct:]');
  WRITTEN: array[0..7] of string = ('a-zA-Z0-9\x80-\xFF', 'a-zA-Z\x80-\xFF', '0-9', ' \t\n\r\f\x0B', '\x00-\x1F\x7F', 'A-Z', 'a-z',
    '!-/:-@\[-`{-~');
var
  I: integer;
begin
  Result := Pattern;
  if Pos('[:', Result) > 0 then
    for I := 0 to High(NAMES) do
      Result := StringReplace(Result, NAMES[I], WRITTEN[I], [rfReplaceAll]);
end;

{ regexp(pattern, text): what  text REGEXP pattern  calls; letter case is
  not regarded. }
procedure FnRegexp(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
var
  Pattern: string;
begin
  if ArgNull(V, 0) or ArgNull(V, 1) then
  begin
    sqlite3_result_null(Ctx);
    Exit;
  end;
  Pattern := ArgText(V, 0);
  try
    if (LastRegex = nil) or (Pattern <> LastPattern) then
    begin
      FreeAndNil(LastRegex);
      LastRegex := TRegExpr.Create;
      LastRegex.ModifierI := True;
      LastRegex.Expression := PlainClasses(Pattern);
      LastPattern := Pattern;
    end;
    sqlite3_result_int64(Ctx, Ord(LastRegex.Exec(ArgText(V, 1))));
  except
    sqlite3_result_int64(Ctx, 0);
  end;
end;

procedure FnRand(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
begin
  sqlite3_result_double(Ctx, Random);
end;

procedure FnDatabase(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
begin
  Give(Ctx, 'main');
end;

procedure FnLn(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
var
  X: double;
begin
  X := StrToFloatDef(StringReplace(ArgText(V, 0), ',', '.', []), 0, DefaultFormatSettings);
  if ArgNull(V, 0) or (X <= 0) then
    sqlite3_result_null(Ctx)
  else
    sqlite3_result_double(Ctx, Ln(X));
end;

procedure FnSoundex(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
const
  CODES = '01230120022455012623010202';
var
  S, R: string;
  C, Last: char;
  I: integer;
begin
  S := UpperCase(ArgText(V, 0));
  R := '';
  Last := #0;
  for I := 1 to Length(S) do
    if S[I] in ['A'..'Z'] then
    begin
      C := CODES[Ord(S[I]) - Ord('A') + 1];
      if R = '' then
        R := S[I]
      else if (C <> '0') and (C <> Last) then
        R := R + C;
      Last := C;
    end;
  while (R <> '') and (Length(R) < 4) do
    R := R + '0';
  Give(Ctx, R);
end;

function Lowered(const S: string): unicodestring;
begin
  Result := UnicodeLowerCase(UTF8Decode(S));
end;

procedure FnLower(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
begin
  if ArgNull(V, 0) then
    sqlite3_result_null(Ctx)
  else
    Give(Ctx, UTF8Encode(Lowered(ArgText(V, 0))));
end;

procedure FnUpper(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
begin
  if ArgNull(V, 0) then
    sqlite3_result_null(Ctx)
  else
    Give(Ctx, UTF8Encode(UnicodeUpperCase(UTF8Decode(ArgText(V, 0)))));
end;

{ True when Text fits the LIKE pattern: % any run, _ one character, the
  escape character before one of them taken as itself. }
function Likes(const Pattern, Text: unicodestring; Esc: widechar): boolean;
var
  P, T, StarP, StarT: integer;
begin
  P := 1;
  T := 1;
  StarP := 0;
  StarT := 0;
  while T <= Length(Text) do
  begin
    if (P <= Length(Pattern)) and (Pattern[P] = Esc) and (P < Length(Pattern)) and (Pattern[P + 1] = Text[T]) then
    begin
      Inc(P, 2);
      Inc(T);
    end
    else if (P <= Length(Pattern)) and (Pattern[P] = '%') then
    begin
      StarP := P;
      StarT := T;
      Inc(P);
    end
    else if (P <= Length(Pattern)) and (Pattern[P] <> Esc) and ((Pattern[P] = '_') or (Pattern[P] = Text[T])) then
    begin
      Inc(P);
      Inc(T);
    end
    else if StarP > 0 then
    begin
      P := StarP + 1;
      Inc(StarT);
      T := StarT;
    end
    else
      Exit(False);
  end;
  while (P <= Length(Pattern)) and (Pattern[P] = '%') do
    Inc(P);
  Result := P > Length(Pattern);
end;

{ The same for plain letters, on the bytes as they lie: no copy of the
  text is made, which matters when every row of a table is tried. }
function LikesPlain(Pattern: pansichar; PL: integer; Text: pansichar; TL: integer; Esc: char): boolean;
var
  P, T, StarP, StarT: integer;

  function Low(C: char): char; inline;
  begin
    if C in ['A'..'Z'] then
      Result := Chr(Ord(C) + 32)
    else
      Result := C;
  end;

begin
  P := 0;
  T := 0;
  StarP := -1;
  StarT := 0;
  while T < TL do
  begin
    if (P < PL - 1) and (Pattern[P] = Esc) and (Low(Pattern[P + 1]) = Low(Text[T])) then
    begin
      Inc(P, 2);
      Inc(T);
    end
    else if (P < PL) and (Pattern[P] = '%') then
    begin
      StarP := P;
      StarT := T;
      Inc(P);
    end
    else if (P < PL) and (Pattern[P] <> Esc) and ((Pattern[P] = '_') or (Low(Pattern[P]) = Low(Text[T]))) then
    begin
      Inc(P);
      Inc(T);
    end
    else if StarP >= 0 then
    begin
      P := StarP + 1;
      Inc(StarT);
      T := StarT;
    end
    else
      Exit(False);
  end;
  while (P < PL) and (Pattern[P] = '%') do
    Inc(P);
  Result := P >= PL;
end;

function IsPlain(P: pansichar; L: integer): boolean;
var
  I: integer;
begin
  for I := 0 to L - 1 do
    if Ord(P[I]) > 127 then
      Exit(False);
  Result := True;
end;

{ like(pattern, text[, escape]): what  text LIKE pattern  calls }
procedure FnLike(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
var
  Esc: widechar;
  E: unicodestring;
  P, T: pansichar;
  PL, TL: integer;
begin
  if ArgNull(V, 0) or ArgNull(V, 1) then
  begin
    sqlite3_result_null(Ctx);
    Exit;
  end;
  Esc := '\';
  if N > 2 then
  begin
    E := UTF8Decode(ArgText(V, 2));
    if E <> '' then
      Esc := E[1];
  end;
  P := sqlite3_value_text(V[0]);
  T := sqlite3_value_text(V[1]);
  PL := sqlite3_value_bytes(V[0]);
  TL := sqlite3_value_bytes(V[1]);
  if (Ord(Esc) < 128) and IsPlain(P, PL) and IsPlain(T, TL) then
    sqlite3_result_int64(Ctx, Ord(LikesPlain(P, PL, T, TL, Chr(Ord(Esc)))))
  else
    sqlite3_result_int64(Ctx, Ord(Likes(Lowered(ArgText(V, 0)), Lowered(ArgText(V, 1)), Esc)));
end;

{ The words of a text between blanks, " a word list ", plain letters made
  small.  Letters beyond a-z are kept as they are. }
function WordList(P: pansichar; L: integer): string;
var
  I, N: integer;
  C: char;
  InWord: boolean;
begin
  SetLength(Result, L + 2);
  Result[1] := ' ';
  N := 1;
  InWord := False;
  for I := 0 to L - 1 do
  begin
    C := P[I];
    if (Ord(C) > 127) or (C in ['a'..'z', '0'..'9', '_']) then
    begin
      Inc(N);
      Result[N] := C;
      InWord := True;
    end
    else if C in ['A'..'Z'] then
    begin
      Inc(N);
      Result[N] := Chr(Ord(C) + 32);
      InWord := True;
    end
    else if InWord then
    begin
      Inc(N);
      Result[N] := ' ';
      InWord := False;
    end;
  end;
  if InWord then
  begin
    Inc(N);
    Result[N] := ' ';
  end;
  SetLength(Result, N);
end;

{ How often Needle stands in Hay. }
function Count(const Needle, Hay: string): integer;
var
  P: integer;
begin
  Result := 0;
  if Needle = '' then
    Exit;
  P := Pos(Needle, Hay);
  while P > 0 do
  begin
    Inc(Result);
    P := Pos(Needle, Hay, P + 1);
  end;
end;

{ exedra_match(text, words, with signs): MATCH ... AGAINST.  The words
  are in MariaDB's notation: +must -not "a phrase" begin*.  0 when the
  text does not match, else a score that grows with the hits. }
procedure FnMatch(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
var
  Hay, Q, Part, Words: string;
  Signs, Phrase, Prefix: boolean;
  I, Hits, Score, Musts: integer;
  Sign: char;
begin
  if ArgNull(V, 0) or ArgNull(V, 1) then
  begin
    sqlite3_result_int64(Ctx, 0);
    Exit;
  end;
  // plain letters are made small on the way; a text with others is made
  // small as a whole first, so that ÉCOLE finds école
  if IsPlain(sqlite3_value_text(V[0]), sqlite3_value_bytes(V[0])) then
    Hay := WordList(sqlite3_value_text(V[0]), sqlite3_value_bytes(V[0]))
  else
  begin
    Q := UTF8Encode(Lowered(ArgText(V, 0)));
    Hay := WordList(pansichar(Q), Length(Q));
  end;
  Q := ArgText(V, 1);
  if not IsPlain(pansichar(Q), Length(Q)) then
    Q := UTF8Encode(Lowered(Q));
  Signs := sqlite3_value_int64(V[2]) <> 0;
  Score := 0;
  Musts := 0;
  I := 1;
  while I <= Length(Q) do
  begin
    while (I <= Length(Q)) and (Q[I] <= ' ') do
      Inc(I);
    if I > Length(Q) then
      Break;
    Sign := ' ';
    if (Q[I] = '+') or (Q[I] = '-') then
    begin
      Sign := Q[I];
      Inc(I);
    end;
    Part := '';
    Phrase := (I <= Length(Q)) and (Q[I] = '"');
    if Phrase then
    begin
      Inc(I);
      while (I <= Length(Q)) and (Q[I] <> '"') do
      begin
        Part := Part + Q[I];
        Inc(I);
      end;
      Inc(I);
    end
    else
      while (I <= Length(Q)) and (Q[I] > ' ') do
      begin
        Part := Part + Q[I];
        Inc(I);
      end;
    Prefix := (Part <> '') and (Part[Length(Part)] = '*');
    Words := WordList(pansichar(Part), Length(Part));
    if Words = ' ' then
      Continue;
    // a word that only has to begin so loses its closing blank
    if Prefix then
      SetLength(Words, Length(Words) - 1);
    Hits := Count(Words, Hay);
    if Signs and (Sign = '-') then
    begin
      if Hits > 0 then
      begin
        sqlite3_result_int64(Ctx, 0);
        Exit;
      end;
    end
    else if Signs and (Sign = '+') then
    begin
      if Hits = 0 then
      begin
        sqlite3_result_int64(Ctx, 0);
        Exit;
      end;
      Inc(Musts);
      Inc(Score, Hits);
    end
    else
      Inc(Score, Hits);
  end;
  // every must is there and nothing else was asked: that is a match
  if (Score = 0) and (Musts > 0) then
    Score := 1;
  sqlite3_result_int64(Ctx, Score);
end;

{ Named locks belong to connections. File locks beside the database also
  serialize separate processes and are released on exit. Hash names into a
  fixed set of files to bound their number; collisions only add waits
  between processes. }
const
  LOCK_FILES = 64;

type
  THeld = class
    Owner: Pointer;
    Spot: integer;  // which of the lock files, -1 for none
  end;

  TLockSpot = record
    Fd: cint;        // the file this program holds locked while Count > 0
    Count: integer;  // how many names in this program rest on it
  end;

var
  Locks: TStringList;
  LocksLock: TRTLCriticalSection;
  LockSpots: array[0..LOCK_FILES - 1] of TLockSpot;

function LockSpotOf(const Name: string): integer;
var
  H: cardinal;
  C: char;
begin
  H := 2166136261;
  for C in Name do
    H := (H xor Ord(C)) * 16777619;
  Result := H mod LOCK_FILES;
end;

function LockFile(Handle: Pointer; Spot: integer): string;
var
  P: pansichar;
begin
  P := sqlite3_db_filename(Handle, 'main');
  if (P = nil) or (P^ = #0) then
    Result := ''
  else
    Result := string(P) + '.lock.' + IntToHex(Spot, 2);
end;

{$ifdef unix}
{ Another name of this program already rests on the spot's file: one more. }
function SharedSpot(Spot: integer): boolean;
begin
  EnterCriticalSection(LocksLock);
  try
    Result := LockSpots[Spot].Count > 0;
    if Result then
      Inc(LockSpots[Spot].Count);
  finally
    LeaveCriticalSection(LocksLock);
  end;
end;

{ The spot's file locked for this program, waiting for other programs
  until GiveUp.  False when the time ran out.  OnFile: the name now rests
  on the file and gives it back with LeaveSpot. }
function TakeSpot(const Path: string; Spot: integer; GiveUp: TDateTime; out OnFile: boolean): boolean;
var
  Fd: cint;
begin
  Result := True;
  OnFile := True;
  while not SharedSpot(Spot) do
  begin
    Fd := fpOpen(Path, O_RDWR or O_CREAT, &600);
    // a folder that takes no file leaves the lock to this program's list
    if Fd < 0 then
    begin
      OnFile := False;
      Exit;
    end;
    if fpFlock(Fd, LOCK_EX or LOCK_NB) = 0 then
    begin
      EnterCriticalSection(LocksLock);
      try
        LockSpots[Spot].Fd := Fd;
        LockSpots[Spot].Count := 1;
      finally
        LeaveCriticalSection(LocksLock);
      end;
      Exit;
    end;
    fpClose(Fd);
    if Now > GiveUp then
    begin
      OnFile := False;
      Exit(False);
    end;
    Sleep(20);
  end;
end;

{ One name less on the spot's file; the last one lets the file go.
  Called with LocksLock held. }
procedure LeaveSpot(Spot: integer);
begin
  if (Spot < 0) or (LockSpots[Spot].Count = 0) then
    Exit;
  Dec(LockSpots[Spot].Count);
  // closing the file lets its lock go
  if LockSpots[Spot].Count = 0 then
    fpClose(LockSpots[Spot].Fd);
end;
{$endif}

procedure FnGetLock(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
var
  Name: string;
  Owner: Pointer;
  GiveUp: TDateTime;
  I: integer;
  Got, Mine: boolean;
  Held: THeld;
  {$ifdef unix}
  Path: string;
  OnFile: boolean;
  {$endif}
begin
  Name := LowerCase(ArgText(V, 0));
  Owner := sqlite3_user_data(Ctx);
  GiveUp := Now + sqlite3_value_int64(V[1]) / SecsPerDay;
  Held := nil;
  Mine := False;
  // first among this program's own connections
  repeat
    EnterCriticalSection(LocksLock);
  try
    I := Locks.IndexOf(Name);
    Got := I < 0;
    if Got then
    begin
      Held := THeld.Create;
      Held.Owner := Owner;
      Held.Spot := -1;
      Locks.AddObject(Name, Held);
    end
    else
      Mine := THeld(Locks.Objects[I]).Owner = Owner;
  finally
    LeaveCriticalSection(LocksLock);
  end;
    if not Got and not Mine then
      Sleep(20);
  until Got or Mine or (Now > GiveUp);
  // then among the programs that have the file open
  {$ifdef unix}
  if Got then
  begin
    Path := LockFile(Owner, LockSpotOf(Name));
    if Path <> '' then
    begin
      Got := TakeSpot(Path, LockSpotOf(Name), GiveUp, OnFile);
      EnterCriticalSection(LocksLock);
      try
        if OnFile then
          Held.Spot := LockSpotOf(Name);
        if not Got then
        begin
          Locks.Delete(Locks.IndexOfObject(Held));
          Held.Free;
        end;
      finally
        LeaveCriticalSection(LocksLock);
      end;
    end;
  end;
  {$endif}
  sqlite3_result_int64(Ctx, Ord(Got or Mine));
end;

procedure Release(Owner: Pointer; const Name: string);
var
  I: integer;
  Held: THeld;
begin
  EnterCriticalSection(LocksLock);
  try
    for I := Locks.Count - 1 downto 0 do
    begin
      Held := THeld(Locks.Objects[I]);
      if (Held.Owner = Owner) and ((Name = '') or (Locks[I] = Name)) then
      begin
        {$ifdef unix}
        LeaveSpot(Held.Spot);
        {$endif}
        Held.Free;
        Locks.Delete(I);
      end;
    end;
  finally
    LeaveCriticalSection(LocksLock);
  end;
end;

procedure FnReleaseLock(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
begin
  Release(sqlite3_user_data(Ctx), LowerCase(ArgText(V, 0)));
  sqlite3_result_int64(Ctx, 1);
end;

procedure FnReleaseAll(Ctx: psqlite3_context; N: cint; V: ppsqlite3_value); cdecl;
begin
  Release(sqlite3_user_data(Ctx), '');
  sqlite3_result_int64(Ctx, 1);
end;

{ exedra_ci: texts compared without regard to letter case. }
function CompareCi(User: Pointer; L1: cint; P1: Pointer; L2: cint; P2: Pointer): cint; cdecl;
var
  A, B: pansichar;
  I, M: integer;
  C1, C2: byte;
  S1, S2: string;
  U1, U2: unicodestring;
begin
  A := P1;
  B := P2;
  M := Min(L1, L2);
  // plain letters and digits, the usual case, without a copy
  for I := 0 to M - 1 do
  begin
    C1 := byte(A[I]);
    C2 := byte(B[I]);
    if (C1 > 127) or (C2 > 127) then
    begin
      SetString(S1, A, L1);
      SetString(S2, B, L2);
      U1 := Lowered(S1);
      U2 := Lowered(S2);
      if U1 < U2 then
        Exit(-1)
      else if U1 > U2 then
        Exit(1)
      else
        Exit(0);
    end;
    if C1 in [Ord('A')..Ord('Z')] then
      Inc(C1, 32);
    if C2 in [Ord('A')..Ord('Z')] then
      Inc(C2, 32);
    if C1 <> C2 then
      Exit(integer(C1) - integer(C2));
  end;
  Result := L1 - L2;
end;

procedure LiteOpened(Handle: Pointer);

  procedure Add(const Name: string; Args: integer; F: xFunc);
  begin
    sqlite3_create_function(Handle, pansichar(Name), Args, SQLITE_UTF8, Handle, F, nil, nil);
  end;

begin
  CharFunction := 'char';
  Add('now', -1, @FnNow);
  Add('utc_timestamp', 0, @FnUtcNow);
  Add('curdate', 0, @FnToday);
  Add('utc_date', 0, @FnUtcToday);
  Add('date_format', 2, @FnDateFormat);
  Add('unix_timestamp', -1, @FnUnix);
  Add('from_unixtime', 1, @FnFromUnix);
  Add('bt_time_add', 3, @FnTimeAdd);
  Add('timestampdiff', 3, @FnTimeDiff);
  Add('year', 1, @FnYear);
  Add('concat', -1, @FnConcat);
  Add('find_in_set', 2, @FnFindInSet);
  Add('field', -1, @FnField);
  Add('regexp', 2, @FnRegexp);
  Add('rand', 0, @FnRand);
  Add('database', 0, @FnDatabase);
  Add('ln', 1, @FnLn);
  Add('log', 1, @FnLn);
  Add('soundex', 1, @FnSoundex);
  Add('lower', 1, @FnLower);
  Add('upper', 1, @FnUpper);
  Add('like', 2, @FnLike);
  Add('like', 3, @FnLike);
  Add('exedra_match', 3, @FnMatch);
  Add('get_lock', 2, @FnGetLock);
  Add('release_lock', 1, @FnReleaseLock);
  Add('release_all_locks', 0, @FnReleaseAll);
  sqlite3_create_collation(Handle, 'exedra_ci', SQLITE_UTF8, nil, @CompareCi);
end;

function LiteInTransaction(Handle: Pointer): boolean;
begin
  Result := sqlite3_get_autocommit(Handle) = 0;
end;

function LiteSessionStart: string;
begin
  // readers do not wait for the writer; a writer waits ten seconds for another
  // the wait comes first: setting the journal itself needs the file to itself for a moment
  Result := 'PRAGMA busy_timeout = 10000' + #10 + 'PRAGMA journal_mode = WAL' + #10 + 'PRAGMA synchronous = NORMAL';
end;

{ ---- one statement ---- }

function Tr(const T: TToks; A, B: integer; InConflict: boolean = False): string; forward;

{ Where the value that starts at I ends: a name, a call, a parameter, a
  number, a text or a part in parentheses. }
function ValueEnd(const T: TToks; I, B: integer): integer;
begin
  Result := I + 1;
  if IsSym(T, I, '(') then
    Result := Closing(T, I, B) + 1
  else if T[I].Kind = tkWord then
  begin
    if IsSym(T, I + 1, '(') then
      Result := Closing(T, I + 1, B) + 1
    else if IsSym(T, I + 1, '.') and (I + 2 < B) then
      Result := I + 3;
  end;
end;

function CastType(const T: TToks; A, B: integer): string;
var
  W: string;
begin
  W := UpperCase(T[A].Text);
  if (W = 'SIGNED') or (W = 'UNSIGNED') then
    Result := 'INTEGER'
  else if (W = 'CHAR') or (W = 'DATETIME') or (W = 'DATE') then
    Result := 'TEXT'
  else if (W = 'DOUBLE') or (W = 'DECIMAL') or (W = 'FLOAT') then
    Result := 'REAL'
  else
    Result := Raw(T, A, B);
end;

{ A function call SQLite's parser or its own functions would get wrong:
  Name at I, the closing parenthesis at J.  '' for one left as it is. }
function Call(const T: TToks; I, J: integer; InConflict: boolean): string;
var
  Name, S, Sep, Order: string;
  Args: TRanges;
  K, P, Q: integer;

  function Arg(N: integer): string;
  begin
    Result := Tr(T, Args[N].A, Args[N].B, InConflict);
  end;

  function All(const NewName: string): string;
  var
    M: integer;
  begin
    Result := NewName + '(';
    for M := 0 to High(Args) do
    begin
      if M > 0 then
        Result := Result + ', ';
      Result := Result + Arg(M);
    end;
    Result := Result + ')';
  end;

begin
  Result := '';
  Name := UpperCase(T[I].Text);
  Args := SplitCommas(T, I + 2, J);
  if (Name = 'IF') and (Length(Args) = 3) then
    Result := All('iif')
  else if (Name = 'LEFT') and (Length(Args) = 2) then
    Result := 'substr(' + Arg(0) + ', 1, ' + Arg(1) + ')'
  else if Name = 'GREATEST' then
    Result := All('max')
  else if Name = 'LEAST' then
    Result := All('min')
  else if Name = 'SUBSTRING' then
    Result := All('substr')
  else if Name = 'CHAR_LENGTH' then
    Result := All('length')
  else if Name = 'LAST_INSERT_ID' then
    Result := 'last_insert_rowid()'
  else if (Name = 'CURRENT_TIMESTAMP') then
    Result := 'now()'
  else if (Name = 'LOCATE') and (Length(Args) = 2) then
  begin
    P := Args[0].A;
    if IsWord(T, P, 'BINARY') then
      Inc(P);
    Result := 'instr(' + Arg(1) + ', ' + Tr(T, P, Args[0].B, InConflict) + ')';
  end
  else if (Name = 'JSON_VALUE') and (Length(Args) = 2) then
    Result := All('json_extract')
  else if (Name = 'TRIM') and (Length(Args) = 1) then
  begin
    // TRIM(BOTH ',' FROM x)
    P := FindWords(T, I + 2, J, ['FROM']);
    if (P > 0) and (IsWord(T, I + 2, 'BOTH') or IsWord(T, I + 2, 'LEADING') or IsWord(T, I + 2, 'TRAILING')) then
    begin
      S := 'trim';
      if IsWord(T, I + 2, 'LEADING') then
        S := 'ltrim'
      else if IsWord(T, I + 2, 'TRAILING') then
        S := 'rtrim';
      Result := S + '(' + Tr(T, P + 1, J, InConflict) + ', ' + Tr(T, I + 3, P, InConflict) + ')';
    end;
  end
  else if (Name = 'TIMESTAMPDIFF') and (Length(Args) = 3) then
    Result := 'timestampdiff(''' + UpperCase(T[Args[0].A].Text) + ''', ' + Arg(1) + ', ' + Arg(2) + ')'
  else if (Name = 'CAST') and (Length(Args) = 1) then
  begin
    P := FindWords(T, I + 2, J, ['AS']);
    if P > 0 then
      Result := 'CAST(' + Tr(T, I + 2, P, InConflict) + ' AS ' + CastType(T, P + 1, J) + ')';
  end
  else if Name = 'GROUP_CONCAT' then
  begin
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
    // DISTINCT takes no separator here.  So a comma inside a value is
    // put aside as character 1, the values are joined by commas in their
    // order (downward when that was asked), the commas become the
    // separator and character 1 a comma again
    if IsWord(T, P, 'DISTINCT') then
    begin
      S := 'replace(' + Tr(T, P + 1, Q, InConflict) + ', '','', char(1))';
      if Order <> '' then
      begin
        if UpperCase(RightStr(TrimRight(Order), 5)) = ' DESC' then
          Order := ' ORDER BY ' + S + ' DESC'
        else
          Order := ' ORDER BY ' + S;
      end;
      Result := 'replace(replace(group_concat(DISTINCT ' + S + Order + '), '','', ' + Sep + '), char(1), '','')';
    end
    else
      Result := 'group_concat(' + Tr(T, P, Q, InConflict) + ', ' + Sep + Order + ')';
  end
  else if InConflict and (Name = 'VALUES') and (Length(Args) = 1) then
    Result := 'excluded.' + Arg(0);
end;

function Tr(const T: TToks; A, B: integer; InConflict: boolean): string;
var
  I, J, K, E: integer;
  W, S, Value, Sign: string;
  Parts: TRanges;
begin
  Result := '';
  I := A;
  while I < B do
  begin
    // x - INTERVAL 5 MINUTE: the value before the sign is what the time is added to
    if (T[I].Kind in [tkWord, tkParam, tkNumber, tkString]) or IsSym(T, I, '(') then
    begin
      E := ValueEnd(T, I, B);
      if (E + 2 < B) and (IsSym(T, E, '-') or IsSym(T, E, '+')) and IsWord(T, E + 1, 'INTERVAL') and not ((T[I].Kind = tkWord) and
        (E = I + 1) and (IsWord(T, I, 'SELECT') or IsWord(T, I, 'AND') or IsWord(T, I, 'OR') or IsWord(T, I, 'WHERE'))) then
      begin
        Value := Tr(T, I, E, InConflict);
        while (E + 2 < B) and (IsSym(T, E, '-') or IsSym(T, E, '+')) and IsWord(T, E + 1, 'INTERVAL') do
        begin
          Sign := '';
          if IsSym(T, E, '-') then
            Sign := '-';
          J := ValueEnd(T, E + 2, B);
          Value := 'bt_time_add(' + Value + ', ' + Sign + '(' + Tr(T, E + 2, J, InConflict) + '), ''' + UpperCase(T[J].Text) + ''')';
          E := J + 1;
        end;
        Emit(Result, Value);
        I := E;
        Continue;
      end;
    end;
    if T[I].Kind <> tkWord then
    begin
      // MariaDB divides whole numbers into a fraction
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
        Parts := SplitCommas(T, I + 2, J);
        S := '';
        for E := 0 to High(Parts) do
        begin
          if E > 0 then
            S := S + ' || '' '' || ';
          S := S + 'coalesce(' + Raw(T, Parts[E].A, Parts[E].B) + ', '''')';
        end;
        if FindWords(T, J + 3, K, ['BOOLEAN']) > 0 then
          Emit(Result, 'exedra_match(' + S + ', ' + TokText(T[J + 3]) + ', 1)')
        else
          Emit(Result, 'exedra_match(' + S + ', ' + TokText(T[J + 3]) + ', 0)');
        I := K + 1;
        Continue;
      end;
    end;
    if IsSym(T, I + 1, '(') then
    begin
      J := Closing(T, I + 1, B);
      S := Call(T, I, J, InConflict);
      if S <> '' then
      begin
        Emit(Result, S);
        I := J + 1;
        Continue;
      end;
    end;
    if (W = 'FOR') and IsWord(T, I + 1, 'UPDATE') then
    begin
      // one writer at a time is all SQLite has: nothing to ask for
      Inc(I, 2);
      Continue;
    end;
    if W = 'RLIKE' then
      Emit(Result, 'REGEXP')
    else if W = 'BINARY' then
    else if W = 'CURRENT_TIMESTAMP' then
      Emit(Result, 'now()')
    else
      Emit(Result, T[I].Text);
    Inc(I);
  end;
end;

{ UPDATE t a JOIN u b ON ... SET a.x = ... WHERE ...  as
  UPDATE t AS a SET x = ... FROM u b WHERE ... }
function UpdateJoin(const T: TToks; JoinAt, SetAt: integer): string;
var
  WhereAt, I, P, Next: integer;
  Items, Conds, Sets, Alias, Target: string;
  Parts: TRanges;
begin
  WhereAt := FindWords(T, SetAt, Length(T), ['WHERE']);
  if WhereAt < 0 then
    WhereAt := Length(T);
  Alias := T[JoinAt - 1].Text;
  Target := T[1].Text;
  if JoinAt > 2 then
    Target := Target + ' AS ' + Alias;
  Items := '';
  Conds := '';
  I := JoinAt;
  while I < SetAt do
  begin
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
    if IsSym(T, P + 1, '.') and SameText(T[P].Text, Alias) then
      Inc(P, 2);
    if Sets <> '' then
      Sets := Sets + ', ';
    Sets := Sets + Tr(T, P, Parts[I].B);
  end;
  Result := 'UPDATE ' + Target + ' SET ' + Sets + ' FROM ' + Items + ' WHERE ' + Conds;
  if WhereAt < Length(T) then
    Result := Result + ' AND (' + Tr(T, WhereAt + 1, Length(T)) + ')';
end;

function Statement(const T: TToks): string;
var
  N, P, Q, I: integer;
  Table, Cols, Key: string;
begin
  N := Length(T);
  Result := '';
  if N = 0 then
    Exit;
  if IsWord(T, 0, 'START') and IsWord(T, 1, 'TRANSACTION') then
    // the write lock is taken at once, so two writers queue and neither is refused later
    Exit('BEGIN IMMEDIATE');
  if IsWord(T, 0, 'SET') and IsWord(T, 1, 'TRANSACTION') then
    Exit('SELECT 1');
  if IsWord(T, 0, 'INSERT') and (N > 3) then
  begin
    P := 1;
    if IsWord(T, P, 'IGNORE') then
      Inc(P);
    if IsWord(T, P, 'INTO') then
      Inc(P);
    Table := T[P].Text;
    Cols := '';
    if IsSym(T, P + 1, '(') then
    begin
      Q := Closing(T, P + 1, N);
      Cols := Raw(T, P + 2, Q);
    end
    else
      Q := P;
    I := FindWords(T, Q + 1, N, ['ON', 'DUPLICATE', 'KEY', 'UPDATE']);
    if I > 0 then
    begin
      Key := KeyFor(Table, Cols);
      Result := 'INSERT INTO ' + Tr(T, P, I);
      // rows from a SELECT need a WHERE before ON CONFLICT, or SQLite reads ON as a join
      if (FindWords(T, Q + 1, I, ['SELECT']) > 0) and (FindWords(T, Q + 1, I, ['WHERE']) < 0) then
        Result := Result + ' WHERE true';
      Result := Result + ' ON CONFLICT (' + Key + ') DO UPDATE SET ' + Tr(T, I + 4, N, True);
    end
    else if IsWord(T, 1, 'IGNORE') then
      Result := 'INSERT OR IGNORE INTO ' + Tr(T, P, N)
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
    // UPDATE t a SET: the short name wants AS before it
    if Q = 3 then
      Exit('UPDATE ' + T[1].Text + ' AS ' + T[2].Text + ' ' + Tr(T, 3, N));
  end;
  // DELETE a FROM t a JOIN ... WHERE ...: the rows found by a SELECT of the same shape
  if IsWord(T, 0, 'DELETE') and IsWord(T, 2, 'FROM') and (N > 3) then
    Exit('DELETE FROM ' + T[3].Text + ' WHERE rowid IN (SELECT ' + T[1].Text + '.rowid FROM ' + Tr(T, 3, N) + ')');
  Result := Tr(T, 0, N);
end;

function LiteTranslate(const SQL: string): string;
begin
  Result := Statement(Tokenize(SQL));
end;

function LiteParamNames(const SQL: string): string;
var
  T: TToks;
  I: integer;
begin
  T := Tokenize(SQL);
  Result := ',';
  for I := 0 to High(T) do
    if (T[I].Kind = tkParam) and (Pos(',' + LowerCase(Copy(T[I].Text, 2, MaxInt)) + ',', Result) = 0) then
      Result := Result + LowerCase(Copy(T[I].Text, 2, MaxInt)) + ',';
  Result := Copy(Result, 2, Length(Result) - 2);
end;

{ ---- tables ---- }

{ A column definition from A: its name, then its type and the rest. }
function ColumnText(const Table: string; const T: TToks; A, B: integer; out Touch: boolean): string;
var
  I, J: integer;
  W, TypeSql, Size, Rest, Collate: string;
  IsText, Identity, NotNull, Primary: boolean;
begin
  Touch := False;
  NoteColumn(Table, T[A].Text);
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
  IsText := (W = 'VARCHAR') or (W = 'CHAR') or (W = 'TEXT') or (W = 'TINYTEXT') or (W = 'MEDIUMTEXT') or (W = 'LONGTEXT') or (W = 'JSON');
  if (W = 'TINYINT') or (W = 'SMALLINT') or (W = 'INT') or (W = 'INTEGER') or (W = 'MEDIUMINT') or (W = 'BOOLEAN') then
    TypeSql := 'INTEGER'
  else if W = 'BIGINT' then
    TypeSql := 'BIGINT'
  else if (W = 'VARCHAR') or (W = 'CHAR') then
    TypeSql := 'VARCHAR' + Size
  else if IsText then
    TypeSql := 'TEXT'
  else if (W = 'DATETIME') or (W = 'TIMESTAMP') then
    TypeSql := 'DATETIME'
  else if (W = 'DOUBLE') or (W = 'FLOAT') then
    TypeSql := 'REAL'
  else if Pos('BLOB', W) > 0 then
    TypeSql := 'BLOB'
  else
    TypeSql := W + Size;
  Collate := CI;
  Identity := False;
  NotNull := False;
  Primary := False;
  Rest := '';
  while I < B do
  begin
    W := UpperCase(T[I].Text);
    if W = 'UNSIGNED' then
    else if (W = 'CHARACTER') and IsWord(T, I + 1, 'SET') then
      Inc(I, 2)
    else if W = 'CHARSET' then
      Inc(I)
    else if W = 'COLLATE' then
    begin
      Inc(I);
      if Pos('_bin', LowerCase(T[I].Text)) > 0 then
        Collate := 'COLLATE BINARY';
    end
    else if W = 'AUTO_INCREMENT' then
      Identity := True
    else if (W = 'NOT') and IsWord(T, I + 1, 'NULL') then
    begin
      NotNull := True;
      Rest := Rest + ' NOT NULL';
      Inc(I);
    end
    else if W = 'NULL' then
    else if W = 'DEFAULT' then
    begin
      Inc(I);
      if IsSym(T, I, '(') then
      begin
        J := Closing(T, I, B);
        Rest := Rest + ' DEFAULT ' + Tr(T, I, J + 1);
        I := J;
      end
      else if IsWord(T, I, 'CURRENT_TIMESTAMP') or IsWord(T, I, 'NOW') then
      begin
        Rest := Rest + ' DEFAULT (datetime(''now''))';
        if IsSym(T, I + 1, '(') then
          I := Closing(T, I + 1, B);
      end
      else if IsSym(T, I, '-') then
      begin
        Rest := Rest + ' DEFAULT -' + T[I + 1].Text;
        Inc(I);
      end
      else
        Rest := Rest + ' DEFAULT ' + TokText(T[I]);
    end
    else if (W = 'ON') and IsWord(T, I + 1, 'UPDATE') then
    begin
      Touch := True;
      Inc(I, 2);
      if IsSym(T, I + 1, '(') then
        I := Closing(T, I + 1, B);
    end
    else if (W = 'PRIMARY') and IsWord(T, I + 1, 'KEY') then
    begin
      Primary := True;
      NoteKey(Table, T[A].Text);
      Inc(I);
    end
    else if W = 'UNIQUE' then
    begin
      Rest := Rest + ' UNIQUE';
      NoteKey(Table, T[A].Text);
      if IsWord(T, I + 1, 'KEY') then
        Inc(I);
    end
    else if (W = 'AFTER') or (W = 'COMMENT') then
      Inc(I)
    else if W = 'FIRST' then
    else
      Rest := Rest + ' ' + TokText(T[I]);
    Inc(I);
  end;
  if not NotNull and not Primary then
  begin
    EnterCriticalSection(KeysLock);
    try
      if Pos(',' + LowerCase(T[A].Text) + ',', Nullable) = 0 then
        Nullable := Nullable + LowerCase(T[A].Text) + ',';
    finally
      LeaveCriticalSection(KeysLock);
    end;
  end;
  Result := T[A].Text + ' ' + TypeSql;
  if IsText then
    Result := Result + ' ' + Collate;
  // the counted key has to be written exactly so
  if Primary and Identity then
    Result := T[A].Text + ' INTEGER PRIMARY KEY AUTOINCREMENT'
  else if Primary then
    Result := Result + ' PRIMARY KEY';
  Result := Result + Rest;
end;

{ INDEX [name] (cols), UNIQUE ..., FULLTEXT ..., starting at A: the
  statement that makes the index ('' for none), or for UNIQUE inside a
  table Inline set to the constraint. }
function IndexItem(const Table: string; const T: TToks; A, B: integer; InTable: boolean; out Inline: string): string;
var
  Kind, Name, Cols: string;
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
  Cols := IndexColumns(T, P + 1, Q);
  if Kind = 'FULLTEXT' then
  // a search reads the rows themselves here
  else if Kind = 'UNIQUE' then
  begin
    NoteKey(Table, Cols);
    if InTable then
      Inline := 'UNIQUE (' + Cols + ')'
    else
      Result := 'CREATE UNIQUE INDEX IF NOT EXISTS ' + IndexName(Table, Name, Cols) + ' ON ' + Table + ' (' + Cols + ')';
  end
  else
    Result := 'CREATE INDEX IF NOT EXISTS ' + IndexName(Table, Name, Cols) + ' ON ' + Table + ' (' + Cols + ')';
end;

function CreateTable(const T: TToks): string;
var
  P, Q, I: integer;
  Table, Body, After, Inline, S, W: string;
  Items: TRanges;
  Touch: boolean;
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
    else if (W = 'INDEX') or (W = 'KEY') or (W = 'UNIQUE') or (W = 'FULLTEXT') then
    begin
      S := IndexItem(Table, T, Items[I].A, Items[I].B, True, Inline);
      if S <> '' then
        After := After + #10 + S;
      S := Inline;
    end
    else
    begin
      S := ColumnText(Table, T, Items[I].A, Items[I].B, Touch);
      if Touch then
        After := After + #10 + 'CREATE TRIGGER IF NOT EXISTS ' + Table + '_touch AFTER UPDATE ON ' + Table + ' FOR EACH ROW BEGIN UPDATE ' +
          Table + ' SET ' + T[Items[I].A].Text + ' = datetime(''now'') WHERE rowid = NEW.rowid; END';
    end;
    if S <> '' then
    begin
      if Body <> '' then
        Body := Body + ', ';
      Body := Body + S;
    end;
  end;
  Result := 'CREATE TABLE IF NOT EXISTS ' + Table + ' (' + Body + ')' + After;
end;

function AlterTable(const T: TToks): string;
var
  Table, S, Inline, W, W2: string;
  Items: TRanges;
  I, A, B: integer;
  Touch: boolean;

  procedure Add(const Text: string);
  begin
    if Text = '' then
      Exit;
    if Result <> '' then
      Result := Result + #10;
    Result := Result + Text;
  end;

begin
  Result := '';
  Table := T[2].Text;
  Items := SplitCommas(T, 3, Length(T));
  for I := 0 to High(Items) do
  begin
    A := Items[I].A;
    B := Items[I].B;
    W := UpperCase(T[A].Text);
    W2 := '';
    if A + 1 < B then
      W2 := UpperCase(T[A + 1].Text);
    if (W = 'ADD') and ((W2 = 'INDEX') or (W2 = 'KEY') or (W2 = 'UNIQUE') or (W2 = 'FULLTEXT')) then
      Add(IndexItem(Table, T, A + 1, B, False, Inline))
    else if W = 'ADD' then
    begin
      Inc(A);
      if IsWord(T, A, 'COLUMN') then
        Inc(A);
      if IsWord(T, A, 'IF') then
        Inc(A, 3);
      Add('ALTER TABLE ' + Table + ' ADD COLUMN ' + ColumnText(Table, T, A, B, Touch));
    end
    else if (W = 'MODIFY') or (W = 'CHANGE') then
    // a column takes any value here; its declared type need not change
    else if (W = 'DROP') and ((W2 = 'INDEX') or (W2 = 'KEY')) then
      Add('DROP INDEX IF EXISTS ' + IndexName(Table, T[A + 2].Text, ''))
    else if (W = 'DROP') and (W2 = 'COLUMN') then
      Add('ALTER TABLE ' + Table + ' DROP COLUMN ' + T[A + 2].Text)
    else
    begin
      S := Tr(T, A, B);
      Add('ALTER TABLE ' + Table + ' ' + S);
    end;
  end;
  if Result = '' then
    Result := 'SELECT 1';
end;

function LiteSchema(const Statement: string): string;
var
  T: TToks;
begin
  T := Tokenize(Statement);
  if IsWord(T, 0, 'CREATE') and IsWord(T, 1, 'TABLE') then
    Result := CreateTable(T)
  else if IsWord(T, 0, 'ALTER') and IsWord(T, 1, 'TABLE') then
    Result := AlterTable(T)
  else
    Result := SiteSqlLite.Statement(T);
end;

initialization
  InitCriticalSection(LocksLock);
  Locks := TStringList.Create;
end.
