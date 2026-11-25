unit SyntaxBarye;

{ Lexical forms follow the language description dated 2026-11-16.
  Context colors are local hints. They do not resolve names or validate code. }

{$mode objfpc}{$H+}

interface

uses
  Types, SysUtils, syntax.highlighter, SyntaxTable;

type
  TBaryeSyntaxHighlighter = class(TByteSyntaxHighlighter)
  private
    procedure IncludeToken;
    procedure StringToken;
  protected
    procedure Classify(var Tokens: TSyntaxTokenArray); override;
    class function GetLanguages: TStringDynArray; override;
  public
    procedure DoExecute(const Source: string); override;
  end;

implementation

const
  NameStart = ['A'..'Z', 'a'..'z', '_'];
  NameRest = NameStart + ['0'..'9'];
  Reserved = 'return defer pass leave';
  Constants = 'Some None Ok Err true false';
  Opcodes = 'mov lea jmp nop ret syscall call cmp jne je jnz jz add sub push pop xor and or test';
  Registers =
    'rax eax ax al ah rbx ebx bx bl bh rcx ecx cx cl ch rdx edx dx dl dh rsi esi si sil rdi edi di dil rbp ebp bp bpl rsp esp sp spl rip eip r8 r9 r10 r11 r12 r13 r14 r15 r8d r9d r10d r11d r12d r13d r14d r15d r8w r9w r10w r11w r12w r13w r14w r15w r8b r9b r10b r11b r12b r13b r14b r15b';

class function TBaryeSyntaxHighlighter.GetLanguages: TStringDynArray;
begin
  Result := ['barye', 'bry'];
end;

procedure TBaryeSyntaxHighlighter.IncludeToken;
var
  First: SizeInt;
  Quote: char;
begin
  First := Cursor;
  Inc(Cursor, 2);
  Emit(First, shDirective);
  First := Cursor;
  while (Cursor <= Limit) and (Ch in [' ', #9]) do Inc(Cursor);
  Emit(First, shDefault);
  if not At('include') or not (Ch(7) in [' ', #9]) then Exit;
  First := Cursor;
  Inc(Cursor, 7);
  Emit(First, shDirective);
  First := Cursor;
  while (Cursor <= Limit) and (Ch in [' ', #9]) do Inc(Cursor);
  Emit(First, shDefault);
  if not (Ch in ['"', '<']) then Exit;
  Quote := Ch;
  First := Cursor;
  Inc(Cursor);
  Emit(First, shSymbol);
  First := Cursor;
  while (Cursor <= Limit) and not (Ch in [#0, #10, #13, '"', '<', '>']) do Inc(Cursor);
  Emit(First, shStrings);
  if ((Quote = '"') and (Ch <> '"')) or ((Quote = '<') and (Ch <> '>')) then Exit;
  First := Cursor;
  Inc(Cursor);
  Emit(First, shSymbol);
  First := Cursor;
  while (Cursor <= Limit) and (Ch in [' ', #9]) do Inc(Cursor);
  Emit(First, shDefault);
  if At('#]') then
  begin
    First := Cursor;
    Inc(Cursor, 2);
    Emit(First, shDirective);
  end;
end;

procedure TBaryeSyntaxHighlighter.StringToken;
var
  First: SizeInt;
begin
  First := Cursor;
  Inc(Cursor);
  while Cursor <= Limit do
  begin
    if (Ch < #32) or (Ch = #127) then Break;
    if Ch = '"' then
    begin
      Inc(Cursor);
      Break;
    end;
    if (Ch = '\') and (Ch(1) in ['\', '"', 'n', 'r', 't', '0']) then
    begin
      Emit(First, shStrings);
      First := Cursor;
      Inc(Cursor, 2);
      Emit(First, shEscape);
      First := Cursor;
    end
    else
      Inc(Cursor);
  end;
  Emit(First, shStrings);
end;

procedure TBaryeSyntaxHighlighter.DoExecute(const Source: string);
var
  First: SizeInt;
  Value: string;
  Kind: TSyntaxHighlightKind;
begin
  Start(Source);
  while Cursor <= Limit do
  begin
    First := Cursor;
    if (Cursor = 1) and (Ch = '#') then
    begin
      LineEnd;
      Emit(First, shComment);
    end
    else if At('//') then
    begin
      LineEnd;
      Emit(First, shComment);
    end
    else if At('/*') then
    begin
      Block('/*', '*/', False);
      Emit(First, shComment);
    end
    else if At('[#') then IncludeToken
    else if Ch = '"' then StringToken
    else if Ch in [' ', #9, #10, #13] then
    begin
      White;
      Emit(First, shDefault);
    end
    else if Ch in NameStart then
    begin
      Inc(Cursor);
      while (Cursor <= Limit) and (Ch in NameRest) do Inc(Cursor);
      Value := Copy(Text, First, Cursor - First);
      Kind := shDefault;
      if WordsContain(Reserved, Value) then Kind := shKeyword
      else if WordsContain(Constants, Value) then Kind := shKey;
      Emit(First, Kind);
    end
    else if Ch in ['0'..'9'] then
    begin
      while (Cursor <= Limit) and (Ch in ['0'..'9']) do Inc(Cursor);
      Emit(First, shNumbers);
    end
    else if At('<<=') or At('>>=') then
    begin
      Inc(Cursor, 3);
      Emit(First, shOperator);
    end
    else if At('[{') or At('}]') then
    begin
      Inc(Cursor, 2);
      Emit(First, shSymbol);
    end
    else if At('#]') then
    begin
      Inc(Cursor, 2);
      Emit(First, shSymbol);
    end
    else if At('<<') or At('>>') or At('<=') or At('>=') or At('!=') or At('==') or At(':=') or At('+=') or At('-=') or At('*=') or At('/=') or At('%=') then
    begin
      Inc(Cursor, 2);
      Emit(First, shOperator);
    end
    else if At('..') then
    begin
      Inc(Cursor, 2);
      Emit(First, shSymbol);
    end
    else
    begin
      Kind := shDefault;
      if Ch in ['+', '-', '*', '/', '%', '=', '<', '>'] then Kind := shOperator
      else if Ch in ['{', '}', '(', ')', '[', ']', ',', ';', ':', '?', '.'] then Kind := shSymbol;
      Unknown;
      Emit(First, Kind);
    end;
  end;
  Finish;
end;

type
  TBaryeRole = (brBlock, brFunction, brCode, brStruct, brMain, brControl, brWith, brMatch, brLet);

  TBaryeFrame = record
    CloseText: string;
    Role: TBaryeRole;
    ResultBearing, CountedMatch: boolean;
    MarkerState: integer;
  end;
  TPendingHeader = (phNone, phFunction, phCode, phStruct);

function IsName(const Value: string): boolean;
var
  I: SizeInt;
begin
  Result := False;
  if (Value = '') or not (Value[1] in NameStart) then Exit;
  for I := 2 to Length(Value) do if not (Value[I] in NameRest) then Exit;
  Result := True;
end;

function HasEol(const Value: string): boolean;
begin
  Result := (Pos(#10, Value) > 0) or (Pos(#13, Value) > 0);
end;

function Trivia(const Token: TSyntaxToken): boolean;
begin
  Result := (Token.Kind = shComment) or ((Token.Kind = shDefault) and (Token.Text <> '') and (Token.Text[1] in [' ', #9, #10, #13]));
end;

procedure TBaryeSyntaxHighlighter.Classify(var Tokens: TSyntaxTokenArray);
var
  NextToken: array of SizeInt;
  GapEol: array of boolean;
  Frames: array of TBaryeFrame;
  I, J, N, Following, Previous, Depth, RoundDepth, SquareDepth, ReceiverDepth, HeaderRound, TypeRound, TypeAngle, OpaqueAt: SizeInt;
  Value, AfterText, BeforeText: string;
  Role, PendingRole: TBaryeRole;
  Header: TPendingHeader;
  RootStart, ProgramHeader, HeaderName, ExpectName, Receiver, HeaderResult, TypePosition, StatementStart, PendingBody, ElseAllowed,
  InAssembly, AssemblyHead, BranchOperand, LetBinding, Importing, Policy, OnLine, CurrentResult, ValidClose, PendingCounted: boolean;

  function Root: boolean;
  begin
    Result := (Depth = 0) and (RoundDepth = 0) and (SquareDepth = 0);
  end;

  function InRoutine: boolean;
  begin
    Result := (Depth > 0) and (Frames[Depth - 1].Role <> brStruct) and (Frames[Depth - 1].Role <> brMain);
  end;

  function ReceiverShape(OpenIndex: SizeInt): boolean;
  var
    ParamIndex, ColonIndex: SizeInt;
  begin
    Result := False;
    if OpenIndex >= N then Exit;
    ParamIndex := NextToken[OpenIndex];
    if (ParamIndex >= N) or not IsName(Tokens[ParamIndex].Text) then Exit;
    ColonIndex := NextToken[ParamIndex];
    Result := (ColonIndex < N) and (Tokens[ColonIndex].Text = ':');
  end;

  procedure Push(const CloseText: string; NewRole: TBaryeRole);
  begin
    if Depth = Length(Frames) then SetLength(Frames, Depth * 2 + 16);
    Frames[Depth].CloseText := CloseText;
    Frames[Depth].Role := NewRole;
    Frames[Depth].ResultBearing := CurrentResult;
    Frames[Depth].CountedMatch := (NewRole = brMatch) and PendingCounted;
    Frames[Depth].MarkerState := 0;
    Inc(Depth);
  end;

begin
  N := Length(Tokens);
  SetLength(NextToken, N);
  SetLength(GapEol, N);
  Following := N;
  OnLine := False;
  for I := N - 1 downto 0 do
  begin
    NextToken[I] := Following;
    GapEol[I] := OnLine;
    if Trivia(Tokens[I]) then OnLine := OnLine or HasEol(Tokens[I].Text)
    else
    begin
      Following := I;
      OnLine := False;
    end;
  end;
  Frames := nil;
  Depth := 0;
  RoundDepth := 0;
  SquareDepth := 0;
  ReceiverDepth := 0;
  HeaderRound := 0;
  TypeRound := 0;
  TypeAngle := 0;
  Previous := -1;
  OpaqueAt := -1;
  RootStart := True;
  ProgramHeader := False;
  HeaderName := False;
  Header := phNone;
  ExpectName := False;
  Receiver := False;
  HeaderResult := False;
  TypePosition := False;
  StatementStart := True;
  PendingBody := False;
  PendingRole := brBlock;
  ElseAllowed := False;
  CurrentResult := False;
  AssemblyHead := True;
  BranchOperand := False;
  LetBinding := False;
  Importing := False;
  Policy := False;
  PendingCounted := False;
  for I := 0 to N - 1 do
  begin
    Value := Tokens[I].Text;
    if OpaqueAt >= 0 then
    begin
      Tokens[I].Kind := shDefault;
      Continue;
    end;
    if Trivia(Tokens[I]) then
    begin
      if HasEol(Value) then
      begin
        StatementStart := True;
        AssemblyHead := True;
        BranchOperand := False;
        LetBinding := False;
        if (Header = phNone) and (TypeRound = 0) and (TypeAngle = 0) then TypePosition := False;
      end;
      Continue;
    end;
    J := NextToken[I];
    AfterText := '';
    if J < N then AfterText := Tokens[J].Text;
    BeforeText := '';
    if Previous >= 0 then BeforeText := Tokens[Previous].Text;
    if (Depth > 0) and (Frames[Depth - 1].Role = brMain) and (Frames[Depth - 1].CloseText = '}]') and (Value <> '}]') then
    begin
      if (Frames[Depth - 1].MarkerState = 0) and (Value = 'pass') then
        Frames[Depth - 1].MarkerState := 1
      else if (Frames[Depth - 1].MarkerState = 1) and (Value = ';') then
        Frames[Depth - 1].MarkerState := 2
      else
        Frames[Depth - 1].MarkerState := -1;
    end;
    InAssembly := (Depth > 0) and (Frames[Depth - 1].Role = brCode);
    if InAssembly and (Value <> '}') then
    begin
      if IsName(Value) then
      begin
        Tokens[I].Kind := shDefault;
        if AssemblyHead then
        begin
          if WordsContain(Opcodes, Value) and (AfterText <> ':') then Tokens[I].Kind := shAssembler;
          BranchOperand := Value = 'jmp';
          AssemblyHead := False;
        end
        else if BranchOperand then
        begin
          Tokens[I].Kind := shAttribute;
          BranchOperand := False;
        end
        else if WordsContain(Registers, Value) then Tokens[I].Kind := shKey;
      end
      else if Value = ':' then AssemblyHead := True
      else if Value = ';' then
      begin
        AssemblyHead := True;
        BranchOperand := False;
      end;
      Previous := I;
      Continue;
    end;
    // Literal and directive spans cannot introduce declarations or delimiters.
    if Tokens[I].Kind in [shStrings, shEscape, shDirective] then
    begin
      Previous := I;
      StatementStart := False;
      Continue;
    end;
    if HeaderName and IsName(Value) then
    begin
      if not WordsContain(Reserved, Value) then Tokens[I].Kind := shAttribute;
      HeaderName := False;
      StatementStart := False;
    end
    else if ExpectName and IsName(Value) then
    begin
      if not WordsContain(Reserved, Value) then Tokens[I].Kind := shAttribute;
      ExpectName := False;
      StatementStart := False;
    end
    else if IsName(Value) then
    begin
      if WordsContain(Reserved, Value) then Tokens[I].Kind := shKeyword
      else if RootStart and Root and StatementStart and ((Value = 'program') or (Value = 'unit')) and IsName(AfterText) and not GapEol[I] then
      begin
        Tokens[I].Kind := shKeyword;
        ProgramHeader := Value = 'program';
        HeaderName := True;
        RootStart := False;
      end
      else if Root and StatementStart and (Header = phNone) and ((Value = 'fn') or (Value = 'codefn') or (Value = 'struct')) and
        ((IsName(AfterText) and not GapEol[I]) or ((Value = 'fn') and (AfterText = '(') and ReceiverShape(J))) then
      begin
        Tokens[I].Kind := shKeyword;
        if Value = 'fn' then Header := phFunction
        else if Value = 'codefn' then Header := phCode
        else
          Header := phStruct;
        ExpectName := True;
        HeaderResult := False;
        HeaderRound := RoundDepth;
        TypePosition := False;
      end
      else if Root and StatementStart and (Value = 'pub') and WordsContain('fn codefn struct', AfterText) and not GapEol[I] then
      begin
        Tokens[I].Kind := shKeyword;
        Previous := I;
        Continue;
      end
      else if Root and StatementStart and WordsContain('uses use from', Value) and IsName(AfterText) and not GapEol[I] then
      begin
        Tokens[I].Kind := shKeyword;
        Importing := True;
      end
      else if Importing and WordsContain('use as', Value) then Tokens[I].Kind := shKeyword
      else if Importing then Tokens[I].Kind := shAttribute
      else if TypePosition then
      begin
        Tokens[I].Kind := shKey;
        if (Header in [phFunction, phCode]) and (RoundDepth = HeaderRound) then HeaderResult := True;
      end
      else if (BeforeText = '.') and (Previous >= 0) then Tokens[I].Kind := shAttribute
      else if InRoutine and StatementStart and (Value = 'let') and not GapEol[I] and (IsName(AfterText) or (AfterText = ':') or
        (AfterText = '[{') or ((AfterText = '(') and (J > I + 1))) then
      begin
        Tokens[I].Kind := shKeyword;
        LetBinding := True;
      end
      else if LetBinding and (Value = 'mut') then Tokens[I].Kind := shKeyword
      else if LetBinding then Tokens[I].Kind := shAttribute
      else if (Depth > 0) and (Frames[Depth - 1].Role = brLet) and StatementStart and (Value = 'mut') then Tokens[I].Kind := shKeyword
      else if (Depth > 0) and (Frames[Depth - 1].Role = brLet) and ((AfterText = ':') or (AfterText = '=')) then Tokens[I].Kind := shAttribute
      else if InRoutine and (Value = 'result') and CurrentResult and (AfterText <> '(') then Tokens[I].Kind := shKey
      else if ((Value = 'if') or (Value = 'while')) and InRoutine and (StatementStart or ((Depth > 0) and (Frames[Depth - 1].Role = brMatch))) and
        not GapEol[I] and (IsName(AfterText) or ((AfterText <> '') and (AfterText[1] in ['0'..'9'])) or (AfterText = '.')) then
      begin
        Tokens[I].Kind := shKeyword;
        PendingBody := True;
        PendingRole := brControl;
      end
      else if InRoutine and StatementStart and (Value = 'with') and not GapEol[I] and IsName(AfterText) then
      begin
        Tokens[I].Kind := shKeyword;
        PendingBody := True;
        PendingRole := brWith;
      end
      else if InRoutine and StatementStart and (Value = 'match') and not GapEol[I] and (WordsContain('first all one', AfterText) or
        ((AfterText <> '') and (AfterText[1] in ['0'..'9']))) then
      begin
        Tokens[I].Kind := shKeyword;
        PendingBody := True;
        PendingRole := brMatch;
        Policy := WordsContain('first all one', AfterText);
        PendingCounted := (AfterText <> '') and (AfterText[1] in ['0'..'9']);
      end
      else if Policy and WordsContain('first all one', Value) then
      begin
        Tokens[I].Kind := shKeyword;
        Policy := False;
      end
      else if (Value = 'else') and (AfterText <> '(') and (ElseAllowed or ((Depth > 0) and (Frames[Depth - 1].Role = brMatch))) then
      begin
        Tokens[I].Kind := shKeyword;
        PendingBody := True;
        PendingRole := brControl;
      end
      else if (Value = 'error') and (AfterText <> '(') and StatementStart and (Depth > 0) and Frames[Depth - 1].CountedMatch then Tokens[I].Kind := shKeyword
      else if (Header <> phNone) and (RoundDepth > HeaderRound) and (AfterText = ':') then Tokens[I].Kind := shAttribute
      else if (Depth > 0) and (Frames[Depth - 1].Role = brStruct) and (AfterText = ':') then Tokens[I].Kind := shAttribute;
      StatementStart := False;
    end
    else if (Value = '{') or (Value = '[{') then
    begin
      Role := brBlock;
      if Header <> phNone then
      begin
        // An unfinished receiver or formal list cannot start an assembly body.
        if not ExpectName and (RoundDepth = HeaderRound) then
        begin
          case Header of
            phFunction: Role := brFunction;
            phCode:
              if (Value = '{') and (SquareDepth = 0) then Role := brCode;
            phStruct:
              if (Value = '{') and (SquareDepth = 0) then Role := brStruct;
            else;
          end;
          CurrentResult := HeaderResult;
        end;
        Header := phNone;
        ExpectName := False;
        Receiver := False;
      end
      else if Root and ProgramHeader and not PendingBody and (RoundDepth = 0) then
      begin
        // A root brace after an expression is too ambiguous to call main.
        if StatementStart or (BeforeText = ';') then Role := brMain;
      end
      else if LetBinding and (Value = '[{') then Role := brLet
      else if PendingBody then Role := PendingRole;
      if Value = '{' then Push('}', Role)
      else
        Push('}]', Role);
      TypePosition := False;
      TypeAngle := 0;
      TypeRound := 0;
      PendingBody := False;
      Policy := False;
      ElseAllowed := False;
      AssemblyHead := True;
      BranchOperand := False;
      StatementStart := True;
      LetBinding := False;
    end
    else if (Value = '}') or (Value = '}]') then
    begin
      ValidClose := (Depth > 0) and (Frames[Depth - 1].CloseText = Value);
      ElseAllowed := False;
      if ValidClose then
      begin
        Role := Frames[Depth - 1].Role;
        Dec(Depth);
        ElseAllowed := Role = brControl;
        if (Role = brMain) and (AfterText = '.') and (J = I + 1) and ((Value = '}') or (Frames[Depth].MarkerState > 0)) then OpaqueAt := J;
        if Depth > 0 then CurrentResult := Frames[Depth - 1].ResultBearing
        else
          CurrentResult := False;
      end;
      TypePosition := False;
      PendingBody := False;
      LetBinding := False;
      StatementStart := True;
    end
    else if Value = '(' then
    begin
      Inc(RoundDepth);
      if (Header = phFunction) and ExpectName then
      begin
        ExpectName := False;
        Receiver := True;
        ReceiverDepth := RoundDepth;
      end;
      if TypePosition then Inc(TypeRound);
      StatementStart := False;
    end
    else if Value = ')' then
    begin
      if RoundDepth > 0 then Dec(RoundDepth);
      if Receiver and (RoundDepth < ReceiverDepth) then
      begin
        Receiver := False;
        ExpectName := True;
      end;
      if TypeRound > 0 then Dec(TypeRound)
      else
        TypePosition := False;
      StatementStart := False;
    end
    else if Value = ':' then
    begin
      TypePosition := (AfterText <> '[{') and (AfterText <> '{') and ((Header <> phNone) or LetBinding or IsName(BeforeText));
      if TypePosition and (Header in [phFunction, phCode]) and (RoundDepth = HeaderRound) then HeaderResult := True;
      TypeRound := 0;
      TypeAngle := 0;
    end
    else if Value = '<' then
    begin
      if TypePosition and (BeforeText = 'Result') then Inc(TypeAngle);
    end
    else if Value = '>' then
    begin
      if TypeAngle > 0 then Dec(TypeAngle);
    end
    else if Value = ',' then
    begin
      if (TypeRound = 0) and (TypeAngle = 0) then TypePosition := False;
    end
    else if (Value = '=') or (Value = ':=') then
    begin
      TypePosition := False;
      LetBinding := False;
    end
    else if Value = ';' then
    begin
      StatementStart := True;
      TypePosition := False;
      ElseAllowed := False;
      LetBinding := False;
      Importing := False;
      Policy := False;
      if Header <> phNone then
      begin
        Header := phNone;
        ExpectName := False;
      end;
    end
    else if Value = '*' then
    begin
      if Importing then Tokens[I].Kind := shSymbol;
    end
    else if Value = '[' then
    begin
      Inc(SquareDepth);
      StatementStart := False;
    end
    else if Value = ']' then
    begin
      if SquareDepth > 0 then Dec(SquareDepth);
      StatementStart := False;
    end
    else if Value = '.' then
    begin
      StatementStart := False;
    end;
    if (Value <> '}') and (Value <> '}]') and (Value <> 'else') then ElseAllowed := False;
    if not Trivia(Tokens[I]) then Previous := I;
  end;
  if OpaqueAt >= 0 then Tokens[OpaqueAt].Kind := shSymbol;
end;

initialization
  TBaryeSyntaxHighlighter.Register;
end.
