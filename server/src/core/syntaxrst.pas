unit SyntaxRst;

{ Highlight reStructuredText source line by line, without rendering it.
  Recognize headings, directives, literal blocks, references and inline
  markup within one line; math roles and formulas get separate tokens. }

{$mode objfpc}{$H+}

interface

uses
  Types, SysUtils, StrUtils, syntax.highlighter, SyntaxTable;

type
  TRstBlock = (rbNone, rbRaw, rbComment);

  TRstSyntaxHighlighter = class(TByteSyntaxHighlighter)
  private
    LineStart, Eol, Pending: SizeInt;
    { an end mark searched for and not found: looked for again later in
      the same line it is not found either, so a line of a million *a
      does not search its rest a million times }
    FailFrom, FailEol: array[0..4] of SizeInt;
    function StartOk(P: SizeInt): boolean;
    function EndOk(P: SizeInt): boolean;
    function RoleEnd(P: SizeInt; Prefix: boolean): SizeInt;
    function AfterEnd(Kind: integer; Q, L: SizeInt): SizeInt;
    function FindEnd(Kind: integer; const Mark: string; From: SizeInt; out Q: SizeInt): SizeInt;
    function FieldEnd(P: SizeInt): SizeInt;
    function Adornment(First, Last, Least: SizeInt): boolean;
    procedure Token(Upto: SizeInt; Kind: TSyntaxHighlightKind);
    procedure Inline;
    procedure Explicit(Dots: SizeInt; out Body: TRstBlock; out Options: boolean);
  protected
    class function GetLanguages: TStringDynArray; override;
  public
    procedure DoExecute(const Source: string); override;
  end;

implementation

const
  Space = [' ', #9];
  Alnum = ['A'..'Z', 'a'..'z', '0'..'9'];
  { what a role or directive name is made of (a domain's py:func too) }
  NameChars = ['A'..'Z', 'a'..'z', '0'..'9', '_', '.', '+', '-', ':'];
  { punctuation that may stand right before or after inline markup }
  Before = [' ', #9, '-', ':', '/', '''', '"', '<', '(', '[', '{'];
  After = [' ', #9, '-', '.', ',', ':', ';', '!', '?', '\', '/', '''', '"', ')', ']', '}', '>'];
  Punctuation = ['!'..'/', ':'..'@', '['..'`', '{'..'~'];
  { directives whose body is shown as written: code, formulas, data }
  RawBodies: array[0..13] of string = ('code', 'code-block', 'sourcecode', 'math', 'raw', 'parsed-literal',
    'csv-table', 'doctest', 'testcode', 'testoutput', 'literalinclude', 'include', 'highlight', 'productionlist');
  { directives whose argument is a path or a language name }
  PathArgs: array[0..8] of string = ('code', 'code-block', 'sourcecode', 'image', 'figure', 'include',
    'literalinclude', 'highlight', 'raw');

class function TRstSyntaxHighlighter.GetLanguages: TStringDynArray;
begin
  Result := ['rst', 'restructuredtext'];
end;

function TRstSyntaxHighlighter.StartOk(P: SizeInt): boolean;
begin
  Result := (P <= LineStart) or (Text[P - 1] in Before);
end;

function TRstSyntaxHighlighter.EndOk(P: SizeInt): boolean;
begin
  Result := (P >= Eol) or (Text[P] in After);
end;

{ At P a colon: where a role's name ends.  As a prefix, the position of
  the ` after :name:; as a suffix, the position after :name:.  0 when
  there is none, within 40 characters. }
function TRstSyntaxHighlighter.RoleEnd(P: SizeInt; Prefix: boolean): SizeInt;
var
  R: SizeInt;
begin
  Result := 0;
  R := P + 1;
  while (R < Eol) and (R - P <= 40) and (Text[R] in NameChars) do
  begin
    if (Text[R] = ':') and (R > P + 1) then
      if Prefix and (R + 1 < Eol) and (Text[R + 1] = '`') then
        Exit(R + 1)
      else if not Prefix and EndOk(R + 1) then
        Exit(R + 1);
    Inc(R);
  end;
end;

{ An end mark of length L at Q: where the markup ends, with its _ or
  :role: after it, or 0 when it cannot end there. }
function TRstSyntaxHighlighter.AfterEnd(Kind: integer; Q, L: SizeInt): SizeInt;
var
  P: SizeInt;
begin
  P := Q + L;
  if Kind in [3, 4] then
    if (P < Eol) and (Text[P] = '_') then
    begin
      Inc(P);
      if (P < Eol) and (Text[P] = '_') then
        Inc(P);
    end
    else if (Kind = 3) and (P < Eol) and (Text[P] = ':') and (RoleEnd(P, False) > 0) then
      P := RoleEnd(P, False);
  if EndOk(P) then
    Result := P
  else if EndOk(Q + L) then
    Result := Q + L
  else
    Result := 0;
end;

{ Mark as an end at or after From in this line: where the markup ends, and
  in Q where the mark is; 0 when it does not end. }
function TRstSyntaxHighlighter.FindEnd(Kind: integer; const Mark: string; From: SizeInt; out Q: SizeInt): SizeInt;
var
  L: SizeInt;
begin
  Result := 0;
  Q := 0;
  if (FailEol[Kind] = Eol) and (From >= FailFrom[Kind]) then
    Exit;
  L := Length(Mark);
  Q := From;
  while Q + L <= Eol do
  begin
    if (Text[Q] = Mark[1]) and ((L = 1) or (Text[Q + 1] = Mark[2])) and not (Text[Q - 1] in [' ', #9, '\']) then
    begin
      Result := AfterEnd(Kind, Q, L);
      if Result > 0 then
        Exit;
    end;
    Inc(Q);
  end;
  Q := 0;
  FailEol[Kind] := Eol;
  FailFrom[Kind] := From;
end;

{ At P a colon that starts a line: after a field's :name: and its space,
  0 when it is not a field (a :role:`text` is not). }
function TRstSyntaxHighlighter.FieldEnd(P: SizeInt): SizeInt;
var
  R: SizeInt;
begin
  Result := 0;
  if (P + 1 >= Eol) or (Text[P + 1] in Space) then
    Exit;
  R := P + 1;
  while (R < Eol) and (R - P <= 80) and (Text[R] <> ':') do
    Inc(R);
  if (R < Eol) and (Text[R] = ':') and (R > P + 1) and not (Text[R - 1] in Space) and ((R + 1 = Eol) or (Text[R + 1] in Space)) then
    Result := R + 1;
end;

{ Text[First..Last-1] one punctuation mark repeated, at least Least of it,
  trailing spaces allowed: a title's line over or under it, or a rule }
function TRstSyntaxHighlighter.Adornment(First, Last, Least: SizeInt): boolean;
var
  P, N: SizeInt;
begin
  Result := False;
  while (Last > First) and (Text[Last - 1] in Space) do
    Dec(Last);
  if (Last - First < Least) or not (Text[First] in Punctuation) then
    Exit;
  N := 0;
  for P := First to Last - 1 do
    if Text[P] <> Text[First] then
      Exit
    else
      Inc(N);
  Result := N >= Least;
end;

{ What waits since Pending as plain text, then Cursor..Upto-1 as Kind }
procedure TRstSyntaxHighlighter.Token(Upto: SizeInt; Kind: TSyntaxHighlightKind);
var
  First: SizeInt;
begin
  Emit(Pending, shDefault);
  First := Cursor;
  Cursor := Upto;
  Emit(First, Kind);
  Pending := Cursor;
end;

procedure TRstSyntaxHighlighter.Inline;
var
  P, Q, A, N: SizeInt;

  function Solid(I: SizeInt): boolean;
  begin
    Result := (I < Eol) and not (Text[I] in Space);
  end;

begin
  while Cursor < Eol do
  begin
    P := Cursor;
    A := 0;
    if (Ch = '\') and Solid(P + 1) and (Text[P + 1] < #128) then
      Token(P + 2, shEscape)
    else if (Ch = '`') and (Ch(1) = '`') and StartOk(P) and Solid(P + 2) then
    begin
      A := FindEnd(0, '``', P + 3, Q);
      if A > 0 then
        Token(A, shStrings)
      else
        Inc(Cursor, 2);
    end
    else if (Ch = '*') and (Ch(1) = '*') and StartOk(P) and Solid(P + 2) then
    begin
      A := FindEnd(1, '**', P + 3, Q);
      if A > 0 then
        Token(A, shKeyword)
      else
        Inc(Cursor, 2);
    end
    else if (Ch = '*') and StartOk(P) and Solid(P + 1) then
    begin
      A := FindEnd(2, '*', P + 2, Q);
      if A > 0 then
        Token(A, shAttribute)
      else
        Inc(Cursor);
    end
    else if (Ch = ':') and StartOk(P) then
    begin
      // :role:`text`, :math:`1\,\mathrm{Ba}` among them
      N := RoleEnd(P, True);
      if (N > 0) and Solid(N + 1) then
        A := FindEnd(3, '`', N + 2, Q);
      if A > 0 then
      begin
        Token(N, shDirective);
        Token(A, shStrings);
      end
      else
        Inc(Cursor);
    end
    else if (Ch = '`') and StartOk(P) and Solid(P + 1) then
    begin
      // `text`_ a reference, `text`:role: or a plain `text`
      A := FindEnd(3, '`', P + 2, Q);
      if A = 0 then
        Inc(Cursor)
      else if (Q + 1 < Eol) and (Text[Q + 1] = '_') then
        Token(A, shKey)
      else if A > Q + 1 then
      begin
        Token(Q + 1, shStrings);
        Token(A, shDirective);
      end
      else
        Token(A, shStrings);
    end
    else if (Ch = '_') and (Ch(1) = '`') and StartOk(P) and Solid(P + 2) then
    begin
      // _`an inline target`
      A := FindEnd(3, '`', P + 3, Q);
      if A > 0 then
        Token(A, shKey)
      else
        Inc(Cursor, 2);
    end
    else if Ch = '|' then
    begin
      // |substitution| or a table's or line block's bar
      if StartOk(P) and Solid(P + 1) then
        A := FindEnd(4, '|', P + 2, Q);
      if A > 0 then
        Token(A, shKey)
      else
        Token(P + 1, shSymbol);
    end
    else if (Ch = '[') and StartOk(P) then
    begin
      // [1]_ [#]_ [*]_ [Citation]_
      Q := P + 1;
      while (Q < Eol) and (Q - P <= 40) and (Text[Q] in Alnum + ['#', '*', '_', '.', '-']) do
        Inc(Q);
      if (Q > P + 1) and (Q + 1 < Eol) and (Text[Q] = ']') and (Text[Q + 1] = '_') and EndOk(Q + 2) then
        Token(Q + 2, shKey)
      else
        Inc(Cursor);
    end
    else if Ch in Alnum then
    begin
      if StartOk(P) and (At('https://') or At('http://') or At('mailto:')) then
      begin
        Q := P;
        while (Q < Eol) and not (Text[Q] in [' ', #9, '<', '>', '`']) do
          Inc(Q);
        Token(Q, shStrings);
      end
      else
      begin
        // a word; with _ or __ after it, a reference
        Q := P;
        while (Q < Eol) and ((Text[Q] in Alnum) or (Text[Q] >= #128) or ((Text[Q] in ['-', '.', '+', '_']) and (Q + 1 < Eol) and (Text[Q + 1] in Alnum))) do
          Inc(Q);
        N := Q;
        if (N < Eol) and (Text[N] = '_') then
        begin
          Inc(N);
          if (N < Eol) and (Text[N] = '_') then
            Inc(N);
        end;
        if (N > Q) and StartOk(P) and EndOk(N) then
          Token(N, shKey)
        else
          Cursor := Q;
      end;
    end
    else
      Unknown;
  end;
  Cursor := Eol;
  Emit(Pending, shDefault);
  Pending := Cursor;
end;

{ A line of explicit markup, its .. at Dots: a directive, a comment, a
  target, a footnote or a substitution's definition.  Block says what the
  lines indented under it are. }
procedure TRstSyntaxHighlighter.Explicit(Dots: SizeInt; out Body: TRstBlock; out Options: boolean);
var
  C, R: SizeInt;
  Name: string;
begin
  Body := rbNone;
  Options := False;
  Cursor := Dots + 2;
  while (Cursor < Eol) and (Ch in Space) do
    Inc(Cursor);
  C := Cursor;
  Cursor := Dots;
  if (C < Eol) and (Text[C] = '[') then
  begin
    R := C + 1;
    while (R < Eol) and (Text[R] <> ']') do
      Inc(R);
    if R < Eol then
    begin
      Token(R + 1, shKey);
      Inline;
      Exit;
    end;
  end
  else if (C < Eol) and (Text[C] = '_') then
  begin
    // .. _name: address, .. _`a name`: address, .. __: address
    R := C + 1;
    if (R < Eol) and (Text[R] = '`') then
    begin
      Inc(R);
      while (R < Eol) and not ((Text[R] = '`') and (R + 1 < Eol) and (Text[R + 1] = ':')) do
        Inc(R);
      Inc(R);
    end
    else
      while (R < Eol) and not ((Text[R] = ':') and ((R + 1 = Eol) or (Text[R + 1] in Space))) do
        Inc(R);
    if R < Eol then
    begin
      Token(R + 1, shKey);
      Token(Eol, shStrings);
      Emit(Pending, shDefault);
      Pending := Cursor;
      Exit;
    end;
  end
  else if (C < Eol) and (Text[C] = '|') then
  begin
    // .. |name| directive:: argument
    R := C + 1;
    while (R < Eol) and (Text[R] <> '|') do
      Inc(R);
    if R < Eol then
    begin
      Token(R + 1, shKey);
      while (Cursor < Eol) and (Ch in Space) do
        Inc(Cursor);
      C := Cursor;
    end;
  end;
  // a directive: name::
  R := C;
  while (R + 1 < Eol) and (R - C <= 60) and (Text[R] in NameChars) do
  begin
    if (R > C) and (Text[R] = ':') and (Text[R + 1] = ':') and ((R + 2 = Eol) or (Text[R + 2] in Space)) then
    begin
      Name := LowerCase(Copy(Text, C, R - C));
      Token(R + 2, shDirective);
      if AnsiIndexText(Name, PathArgs) >= 0 then
      begin
        Token(Eol, shStrings);
        Emit(Pending, shDefault);
        Pending := Cursor;
      end
      else
        Inline;
      if AnsiIndexText(Name, RawBodies) >= 0 then
      begin
        Body := rbRaw;
        Options := True;
      end;
      Exit;
    end;
    Inc(R);
  end;
  // anything else after .. is a comment, and so is what is indented under it
  if Cursor = Dots then
  begin
    Token(Eol, shComment);
    Body := rbComment;
  end
  else
    Inline;
end;

procedure TRstSyntaxHighlighter.DoExecute(const Source: string);
var
  First, Indent, Base, Next, NextEol, N, Q, Breaks: SizeInt;
  Line, Bare: string;
  Body: TRstBlock;
  Options, Done: boolean;
begin
  Start(Source);
  FillChar(FailEol, SizeOf(FailEol), 0);
  FillChar(FailFrom, SizeOf(FailFrom), 0);
  Body := rbNone;
  Options := False;
  Base := 0;
  while Cursor <= Limit do
  begin
    First := Cursor;
    LineStart := First;
    Pending := First;
    Eol := Cursor;
    while (Eol <= Limit) and not (Text[Eol] in [#10, #13]) do
      Inc(Eol);
    Line := Copy(Text, Cursor, Eol - Cursor);
    Bare := TrimLeft(Line);
    Indent := Length(Line) - Length(Bare);
    Done := False;
    if Body <> rbNone then
      if Trim(Line) = '' then
      begin
        Cursor := Eol;
        Emit(First, shDefault);
        Options := False;
        Done := True;
      end
      else if Indent > Base then
      begin
        Cursor := First + Indent;
        if (Body = rbRaw) and Options and (Bare[1] = ':') and (FieldEnd(Cursor) > 0) then
        begin
          Token(FieldEnd(Cursor), shAttribute);
          Cursor := Eol;
          Emit(Pending, shDefault);
        end
        else
        begin
          Options := False;
          Cursor := Eol;
          if Body = rbRaw then
            Emit(First, shRawString)
          else
            Emit(First, shComment);
        end;
        Done := True;
      end
      else
        Body := rbNone;
    if not Done then
    begin
      // the line after this one, for a title's underline
      Next := Eol;
      if (Next <= Limit) and (Text[Next] = #13) then
        Inc(Next);
      if (Next <= Limit) and (Text[Next] = #10) then
        Inc(Next);
      NextEol := Next;
      while (NextEol <= Limit) and not (Text[NextEol] in [#10, #13]) do
        Inc(NextEol);
      if Trim(Line) = '' then
      begin
        Cursor := Eol;
        Emit(First, shDefault);
      end
      else if (Copy(Bare, 1, 2) = '..') and ((Length(Bare) = 2) or (Bare[3] in Space)) then
      begin
        Explicit(First + Indent, Body, Options);
        Base := Indent;
      end
      else if (Indent = 0) and Adornment(First, Eol, 2) then
      begin
        Cursor := Eol;
        Emit(First, shSymbol);
      end
      else if (Bare[1] in ['=', '-', '+']) and (Length(Bare) >= 3) and
        (Trim(StringReplace(StringReplace(StringReplace(Bare, '=', '', [rfReplaceAll]), '-', '', [rfReplaceAll]), '+', '', [rfReplaceAll])) = '') then
      begin
        // a table's rule: ====  ==== or +----+----+
        Cursor := Eol;
        Emit(First, shSymbol);
      end
      else if (Next > Eol) and (NextEol > Next) and Adornment(Next, NextEol, 2) then
      begin
        Cursor := Eol;
        Emit(First, shSection);
      end
      else if (Copy(Bare, 1, 4) = '>>> ') or (TrimRight(Bare) = '>>>') then
      begin
        Cursor := Eol;
        Emit(First, shRawString);
      end
      else
      begin
        Cursor := First + Indent;
        // a list's mark: - * + or 1. #. a) (i) and a space, or a field
        if (Ch in ['-', '*', '+']) and ((Cursor + 1 = Eol) or (Ch(1) in Space)) then
          Token(Cursor + 1, shSymbol)
        else if Ch = ':' then
        begin
          if FieldEnd(Cursor) > 0 then
            Token(FieldEnd(Cursor), shAttribute);
        end
        else
        begin
          Q := Cursor;
          if Text[Q] = '(' then
            Inc(Q);
          N := Q;
          if (N < Eol) and (Text[N] = '#') then
            Inc(N)
          else if (N < Eol) and (Text[N] in ['0'..'9']) then
            while (N < Eol) and (N - Q < 9) and (Text[N] in ['0'..'9']) do
              Inc(N)
          else if (N + 1 < Eol) and (Text[N] in ['A'..'Z', 'a'..'z']) and (Text[N + 1] in ['.', ')']) then
            Inc(N);
          if (N > Q) and (N < Eol) and (((Q > Cursor) and (Text[N] = ')')) or ((Q = Cursor) and (Text[N] in ['.', ')']))) and
            ((N + 1 = Eol) or (Text[N + 1] in Space)) then
            Token(N + 1, shSymbol);
        end;
        Inline;
      end;
      // a line ending in :: has a literal block indented under it
      if (Body = rbNone) and (Copy(TrimRight(Bare), Length(TrimRight(Bare)) - 1, 2) = '::') and not ((Copy(Bare, 1, 2) = '..') and
        ((Length(Bare) = 2) or (Bare[3] in Space))) then
      begin
        Body := rbRaw;
        Options := False;
        Base := Indent;
      end;
    end;
    Cursor := Eol;
    First := Cursor;
    Breaks := 0;
    while (Cursor <= Limit) and (Ch in [#10, #13]) do
    begin
      if (Ch = #10) or (Ch(1) <> #10) then
        Inc(Breaks);
      Inc(Cursor);
    end;
    Emit(First, shDefault);
    // a blank line ends a directive's options
    if Breaks > 1 then
      Options := False;
  end;
  Finish;
end;

initialization
  TRstSyntaxHighlighter.Register;
end.
