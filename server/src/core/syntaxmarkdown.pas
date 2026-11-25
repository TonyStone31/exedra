unit SyntaxMarkdown;

{ Markdown source colored, never rendered: a code block shows exactly what
  was typed, and this only tints its parts.  Headings, quotes, list marks,
  fenced code, inline code, strong and emphasis, links (and the wiki's
  [[links]]), tags and table bars.  Line by line, as Markdown is read; a
  fence runs on until its closing line. }

{$mode objfpc}{$H+}

interface

uses
  Types, SysUtils, syntax.highlighter, SyntaxTable;

type
  TMarkdownSyntaxHighlighter = class(TByteSyntaxHighlighter)
  private
    { searches that found nothing: the same mark looked for again later in
      the same line finds nothing either, so a line of a million [ does not
      search its rest a million times }
    FailRun: array of string;
    FailFrom, FailBefore: array of SizeInt;
    procedure Inline(Eol: SizeInt);
    function FindRun(const Run: string; From, Before: SizeInt): SizeInt;
  protected
    class function GetLanguages: TStringDynArray; override;
  public
    procedure DoExecute(const Source: string); override;
  end;

implementation

const
  { what starts something other than plain words inside a line }
  Special = ['\', '`', '*', '_', '~', '[', '!', '<', '|'];
  Punctuation = ['!'..'/', ':'..'@', '['..'`', '{'..'~'];

class function TMarkdownSyntaxHighlighter.GetLanguages: TStringDynArray;
begin
  Result := ['markdown', 'md', 'mkd', 'mdown'];
end;

{ where Run starts again at or after From and before Before, 0 when it
  does not }
function TMarkdownSyntaxHighlighter.FindRun(const Run: string; From, Before: SizeInt): SizeInt;
var
  P, I: SizeInt;
begin
  Result := 0;
  for I := 0 to High(FailRun) do
    if (FailBefore[I] = Before) and (From >= FailFrom[I]) and (FailRun[I] = Run) then
      Exit;
  P := From;
  while P + Length(Run) <= Before do
  begin
    if (Text[P] = Run[1]) and (Copy(Text, P, Length(Run)) = Run) then
      Exit(P);
    Inc(P);
  end;
  for I := 0 to High(FailRun) do
    if (FailRun[I] = Run) then
    begin
      FailFrom[I] := From;
      FailBefore[I] := Before;
      Exit;
    end;
  I := Length(FailRun);
  SetLength(FailRun, I + 1);
  SetLength(FailFrom, I + 1);
  SetLength(FailBefore, I + 1);
  FailRun[I] := Run;
  FailFrom[I] := From;
  FailBefore[I] := Before;
end;

procedure TMarkdownSyntaxHighlighter.Inline(Eol: SizeInt);
var
  First, Close, N: SizeInt;
  Mark: char;
  Run: string;
begin
  while Cursor < Eol do
  begin
    First := Cursor;
    if (Ch = '\') and (Cursor + 1 < Eol) and (Ch(1) in Punctuation) then
    begin
      Inc(Cursor, 2);
      Emit(First, shEscape);
    end
    else if Ch = '`' then
    begin
      // a code span closes on a run of as many backticks
      N := 0;
      while (Cursor + N < Eol) and (Ch(N) = '`') do
        Inc(N);
      Run := StringOfChar('`', N);
      Close := FindRun(Run, Cursor + N, Eol);
      if Close > 0 then
        Cursor := Close + N
      else
        Inc(Cursor, N);
      if Close > 0 then
        Emit(First, shStrings)
      else
        Emit(First, shDefault);
    end
    else if (Ch in ['*', '_']) and not ((Ch = '_') and (Cursor > 1) and (Text[Cursor - 1] in ['A'..'Z', 'a'..'z', '0'..'9'])) then
    begin
      // **strong**, *emphasis*, ***both***: closed on the same run, the
      // opening not followed by a space
      Mark := Ch;
      N := 0;
      while (Cursor + N < Eol) and (Ch(N) = Mark) and (N < 3) do
        Inc(N);
      Run := StringOfChar(Mark, N);
      Close := 0;
      if (Cursor + N < Eol) and not (Ch(N) in [' ', #9]) then
        Close := FindRun(Run, Cursor + N + 1, Eol);
      if (Close > 0) and not (Text[Close - 1] in [' ', #9]) then
      begin
        Cursor := Close + N;
        if N >= 2 then
          Emit(First, shKeyword)
        else
          Emit(First, shAttribute);
      end
      else
      begin
        Inc(Cursor, N);
        Emit(First, shDefault);
      end;
    end
    else if (Ch = '~') and (Ch(1) = '~') then
    begin
      Close := FindRun('~~', Cursor + 2, Eol);
      if Close > 0 then
      begin
        Cursor := Close + 2;
        Emit(First, shComment);
      end
      else
      begin
        Inc(Cursor, 2);
        Emit(First, shDefault);
      end;
    end
    else if (Ch = '[') and (Ch(1) = '[') then
    begin
      // the wiki's [[Page|words]]
      Close := FindRun(']]', Cursor + 2, Eol);
      if Close > 0 then
        Cursor := Close + 2
      else
        Inc(Cursor, 2);
      if Close > 0 then
        Emit(First, shKey)
      else
        Emit(First, shDefault);
    end
    else if (Ch = '[') or ((Ch = '!') and (Ch(1) = '[')) then
    begin
      // [words](address) and ![picture](address): the words as a name,
      // the address as a string
      if Ch = '!' then
        Inc(Cursor);
      Close := FindRun(']', Cursor + 1, Eol);
      if Close = 0 then
      begin
        Inc(Cursor);
        Emit(First, shDefault);
      end
      else
      begin
        Cursor := Close + 1;
        Emit(First, shKey);
        if Ch = '(' then
        begin
          First := Cursor;
          Close := FindRun(')', Cursor + 1, Eol);
          if Close > 0 then
            Cursor := Close + 1
          else
            Cursor := Eol;
          Emit(First, shStrings);
        end;
      end;
    end
    else if (Ch = '<') and ((Ch(1) in ['A'..'Z', 'a'..'z', '/', '!'])) then
    begin
      // <https://...> and <tag ...>, shown as written
      Close := FindRun('>', Cursor + 1, Eol);
      if Close = 0 then
      begin
        Inc(Cursor);
        Emit(First, shDefault);
      end
      else
      begin
        Cursor := Close + 1;
        if (Pos('://', Copy(Text, First, Cursor - First)) > 0) or (Copy(Text, First + 1, 7) = 'mailto:') then
          Emit(First, shStrings)
        else
          Emit(First, shDirective);
      end;
    end
    else if Ch = '|' then
    begin
      Inc(Cursor);
      Emit(First, shSymbol);
    end
    else
    begin
      Unknown;
      while (Cursor < Eol) and not (Ch in Special) do
        Unknown;
      Emit(First, shDefault);
    end;
  end;
  Cursor := Eol;
end;

procedure TMarkdownSyntaxHighlighter.DoExecute(const Source: string);
var
  First, Eol, P, Indent, N: SizeInt;
  Fence: string;
  Line, Bare: string;
  C: char;
  Ruled: boolean;
begin
  Start(Source);
  FailRun := nil;
  FailFrom := nil;
  FailBefore := nil;
  Fence := '';
  while Cursor <= Limit do
  begin
    First := Cursor;
    Eol := Cursor;
    while (Eol <= Limit) and not (Text[Eol] in [#10, #13]) do
      Inc(Eol);
    Line := Copy(Text, Cursor, Eol - Cursor);
    Bare := TrimLeft(Line);
    Indent := Length(Line) - Length(Bare);
    if Fence <> '' then
    begin
      // inside a fence: all of it as written, to the closing line
      Cursor := Eol;
      Emit(First, shRawString);
      if (Indent < 4) and (Copy(Bare, 1, Length(Fence)) = Fence) and (Trim(Copy(Bare, Length(Fence) + 1, MaxInt)) = '') then
        Fence := '';
    end
    else if (Indent < 4) and ((Copy(Bare, 1, 3) = '```') or (Copy(Bare, 1, 3) = '~~~')) then
    begin
      N := 0;
      while (N < Length(Bare)) and (Bare[N + 1] = Bare[1]) do
        Inc(N);
      Fence := StringOfChar(Bare[1], N);
      Cursor := Eol;
      Emit(First, shRawString);
    end
    else if (Indent < 4) and (Bare <> '') and (Bare[1] = '#') then
    begin
      N := 0;
      while (N < Length(Bare)) and (Bare[N + 1] = '#') do
        Inc(N);
      Cursor := Eol;
      if (N <= 6) and ((N = Length(Bare)) or (Bare[N + 1] in [' ', #9])) then
        Emit(First, shSection)
      else
      begin
        Cursor := First;
        Inline(Eol);
      end;
    end
    else
    begin
      // a rule: three or more of one of - * _ = and nothing else
      Ruled := False;
      if (Indent < 4) and (Bare <> '') and (Bare[1] in ['-', '*', '_', '=']) then
      begin
        C := Bare[1];
        N := 0;
        Ruled := True;
        for P := 1 to Length(Bare) do
          if Bare[P] = C then
            Inc(N)
          else if not (Bare[P] in [' ', #9]) then
            Ruled := False;
        Ruled := Ruled and (N >= 3);
      end;
      if Ruled then
      begin
        Cursor := Eol;
        Emit(First, shSymbol);
      end
      else
      begin
        Inc(Cursor, Indent);
        Emit(First, shDefault);
        First := Cursor;
        if Ch = '>' then
        begin
          // a quote, the whole line
          Cursor := Eol;
          Emit(First, shComment);
        end
        else
        begin
          // a list's mark: - * + or 1. 1) and a space, then a task's box
          if (Ch in ['-', '*', '+']) and (Ch(1) in [' ', #9]) then
            Inc(Cursor)
          else if Ch in ['0'..'9'] then
          begin
            N := 0;
            while (N < 9) and (Ch(N) in ['0'..'9']) do
              Inc(N);
            if (Ch(N) in ['.', ')']) and (Ch(N + 1) in [' ', #9]) then
              Inc(Cursor, N + 1);
          end;
          if Cursor > First then
          begin
            Emit(First, shSymbol);
            First := Cursor;
            while (Cursor < Eol) and (Ch in [' ', #9]) do
              Inc(Cursor);
            Emit(First, shDefault);
            if (Ch = '[') and (Ch(1) in [' ', 'x', 'X']) and (Ch(2) = ']') then
            begin
              First := Cursor;
              Inc(Cursor, 3);
              Emit(First, shSymbol);
            end;
          end;
          Inline(Eol);
        end;
      end;
    end;
    First := Cursor;
    while (Cursor <= Limit) and (Ch in [#10, #13]) do
      Inc(Cursor);
    Emit(First, shDefault);
  end;
  Finish;
end;

initialization
  TMarkdownSyntaxHighlighter.Register;
end.
