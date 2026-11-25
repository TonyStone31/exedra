unit SyntaxTable;

{ Shared scanner driven by TLanguageDescription keyword, comment and string
  tables. SyntaxLangs provides descriptions; TByteSyntaxHighlighter emits
  typed tokens for fcl-syntax to render as HTML. }

{$mode objfpc}{$H+}

interface

uses
  Types, SysUtils, syntax.highlighter;

type
  { Byte spans and geometric token storage are shared by the small scanners. }
  TByteSyntaxHighlighter = class(TSyntaxHighlighter)
  private
    FOutput: TSyntaxTokenArray;
    FCount: SizeInt;
  protected
    Text: string;
    Cursor, Limit: SizeInt;
    procedure Start(const Source: string);
    procedure Finish;
    { Changes the kinds of a whole source's tokens before Finish emits them. }
    procedure Classify(var Tokens: TSyntaxTokenArray); virtual;
    function Ch(Offset: SizeInt = 0): char;
    function At(const Value: string; Offset: SizeInt = 0): boolean;
    procedure Emit(First: SizeInt; Kind: TSyntaxHighlightKind);
    procedure LineEnd;
    procedure Quoted(const OpenText, CloseText: string; Escape: char; Multiline, Doubled: boolean);
    procedure Block(const OpenText, CloseText: string; Nested: boolean);
    procedure White;
    procedure Unknown;
  end;

  TCommentForm = record
    OpenText, CloseText: string;
    Nested, LineStartOnly, WordBoundary: boolean;
  end;

  TStringForm = record
    OpenText, CloseText: string;
    Escape: char;
    Multiline, Doubled: boolean;
    Kind: TSyntaxHighlightKind;
  end;

  TNumberForms = record
    Hex, Binary, Octal, LeadingOctal, Separators, Fraction, Exponent,
    HexExponent, LeadingDot, Based, TrailingBase: boolean;
    Separator: char;
    ExponentLetters, Suffixes: string;
  end;
  TLanguageFlavor = (lfPlain, lfCpp, lfCSharp, lfRust, lfLua, lfZig,
    lfBasic, lfAda, lfBatch, lfDocker, lfToml, lfRuby, lfPerl, lfPhp,
    lfPowerShell, lfFortran, lfAssembly);

  TLanguageDescription = record
    Names, Keywords, Builtins: string;
    CaseSensitive: boolean;
    Comments: array of TCommentForm;
    Strings: array of TStringForm;
    Numbers: TNumberForms;
    Directive, Attribute: string;
    IdentifierStart, IdentifierRest, Operators, Symbols: TSysCharSet;
    Flavor: TLanguageFlavor;
  end;

  TTableSyntaxHighlighter = class(TByteSyntaxHighlighter)
  private
    FDescription: TLanguageDescription;
    FLineStart: boolean;
    function CommentToken: boolean;
    function StringToken: boolean;
    function SpecialString: boolean;
    procedure NumberToken;
  protected
    class function Describe: TLanguageDescription; virtual; abstract;
    class function GetLanguages: TStringDynArray; override;
    function WordKind(const Value: string): TSyntaxHighlightKind; virtual;
  public
    constructor Create; override;
    procedure DoExecute(const Source: string); override;
  end;

function Language(const Names, Keywords, Builtins: string): TLanguageDescription;
procedure LineComment(var Desc: TLanguageDescription; const OpenText: string; LineStartOnly: boolean = False; WordBoundary: boolean = False);
procedure BlockComment(var Desc: TLanguageDescription; const OpenText, CloseText: string; Nested: boolean = False);
procedure StringForm(var Desc: TLanguageDescription; const OpenText, CloseText: string; Escape: char = '\'; Multiline: boolean = False;
  Doubled: boolean = False; Kind: TSyntaxHighlightKind = shStrings);
function WordsContain(const Words, Value: string): boolean;
function LanguageNames(const Names: string): TStringDynArray;

implementation

function WordsContain(const Words, Value: string): boolean;
begin
  Result := (Value <> '') and (Length(Value) <= 64) and (Pos(' ' + Value + ' ', ' ' + Words + ' ') > 0);
end;

function LanguageNames(const Names: string): TStringDynArray;
var
  I, First, Count: SizeInt;
begin
  Result := nil;
  Count := 0;
  I := 1;
  while I <= Length(Names) do
  begin
    while (I <= Length(Names)) and (Names[I] = ' ') do Inc(I);
    First := I;
    while (I <= Length(Names)) and (Names[I] <> ' ') do Inc(I);
    if I > First then
    begin
      SetLength(Result, Count + 1);
      Result[Count] := Copy(Names, First, I - First);
      Inc(Count);
    end;
  end;
end;

function Language(const Names, Keywords, Builtins: string): TLanguageDescription;
begin
  Result := Default(TLanguageDescription);
  Result.Names := Names;
  Result.Keywords := Keywords;
  Result.Builtins := Builtins;
  Result.CaseSensitive := True;
  Result.IdentifierStart := ['A'..'Z', 'a'..'z', '_', #128..#255];
  Result.IdentifierRest := Result.IdentifierStart + ['0'..'9'];
  Result.Operators := ['+', '-', '*', '/', '%', '=', '<', '>', '!', '&', '|', '^', '~', '?'];
  Result.Symbols := ['(', ')', '[', ']', '{', '}', '.', ',', ':', ';'];
  Result.Numbers.Fraction := True;
  Result.Numbers.LeadingDot := True;
  Result.Numbers.Exponent := True;
  Result.Numbers.ExponentLetters := 'eE';
  Result.Numbers.Separator := '_';
end;

procedure LineComment(var Desc: TLanguageDescription; const OpenText: string; LineStartOnly: boolean; WordBoundary: boolean);
var
  N: SizeInt;
begin
  N := Length(Desc.Comments);
  SetLength(Desc.Comments, N + 1);
  Desc.Comments[N].OpenText := OpenText;
  Desc.Comments[N].LineStartOnly := LineStartOnly;
  Desc.Comments[N].WordBoundary := WordBoundary;
end;

procedure BlockComment(var Desc: TLanguageDescription; const OpenText, CloseText: string; Nested: boolean);
var
  N: SizeInt;
begin
  N := Length(Desc.Comments);
  SetLength(Desc.Comments, N + 1);
  Desc.Comments[N].OpenText := OpenText;
  Desc.Comments[N].CloseText := CloseText;
  Desc.Comments[N].Nested := Nested;
end;

procedure StringForm(var Desc: TLanguageDescription; const OpenText, CloseText: string; Escape: char; Multiline, Doubled: boolean; Kind: TSyntaxHighlightKind);
var
  N: SizeInt;
begin
  N := Length(Desc.Strings);
  SetLength(Desc.Strings, N + 1);
  Desc.Strings[N].OpenText := OpenText;
  Desc.Strings[N].CloseText := CloseText;
  Desc.Strings[N].Escape := Escape;
  Desc.Strings[N].Multiline := Multiline;
  Desc.Strings[N].Doubled := Doubled;
  Desc.Strings[N].Kind := Kind;
end;

procedure TByteSyntaxHighlighter.Start(const Source: string);
begin
  Text := Source;
  Cursor := 1;
  Limit := Length(Text);
  FOutput := nil;
  FCount := 0;
end;

procedure TByteSyntaxHighlighter.Classify(var Tokens: TSyntaxTokenArray);
begin
end;

{ Hands the tokens to the base class, which sets their lines and passes them on. }
procedure TByteSyntaxHighlighter.Finish;
var
  I: SizeInt;
begin
  SetLength(FOutput, FCount);
  Classify(FOutput);
  for I := 0 to High(FOutput) do
    EmitToken(FOutput[I]);
  FOutput := nil;
  FCount := 0;
  Text := '';
end;

function TByteSyntaxHighlighter.Ch(Offset: SizeInt): char;
begin
  if (Cursor + Offset >= 1) and (Cursor + Offset <= Limit) then
    Result := Text[Cursor + Offset]
  else
    Result := #0;
end;

function TByteSyntaxHighlighter.At(const Value: string; Offset: SizeInt): boolean;
var
  I, P: SizeInt;
begin
  Result := False;
  P := Cursor + Offset;
  if (Value = '') or (P < 1) or (Length(Value) > Limit - P + 1) then Exit;
  for I := 1 to Length(Value) do
    if Text[P + I - 1] <> Value[I] then Exit;
  Result := True;
end;

procedure TByteSyntaxHighlighter.Emit(First: SizeInt; Kind: TSyntaxHighlightKind);
begin
  if Cursor <= First then Exit;
  if FCount = Length(FOutput) then SetLength(FOutput, FCount * 2 + 64);
  FOutput[FCount] := TSyntaxToken.Create(Copy(Text, First, Cursor - First), Kind);
  Inc(FCount);
end;

procedure TByteSyntaxHighlighter.LineEnd;
begin
  while (Cursor <= Limit) and not (Ch in [#10, #13]) do Inc(Cursor);
end;

procedure TByteSyntaxHighlighter.White;
begin
  while (Cursor <= Limit) and (Ch in [#9, #10, #13, ' ']) do Inc(Cursor);
end;

procedure TByteSyntaxHighlighter.Unknown;
begin
  Inc(Cursor);
  while (Cursor <= Limit) and (Ch >= #128) do Inc(Cursor);
end;

procedure TByteSyntaxHighlighter.Quoted(const OpenText, CloseText: string; Escape: char; Multiline, Doubled: boolean);
begin
  Inc(Cursor, Length(OpenText));
  while Cursor <= Limit do
  begin
    if not Multiline and (Ch in [#10, #13]) then Break;
    if At(CloseText) then
    begin
      Inc(Cursor, Length(CloseText));
      if Doubled and At(CloseText) then Inc(Cursor, Length(CloseText))
      else
        Break;
    end
    else if (Escape <> #0) and (Ch = Escape) then
    begin
      Inc(Cursor);
      if Cursor <= Limit then
      begin
        if not Multiline and (Ch in [#10, #13]) then
        begin
          if At(#13#10) then Inc(Cursor);
        end;
        Inc(Cursor);
      end;
    end
    else
      Inc(Cursor);
  end;
end;

procedure TByteSyntaxHighlighter.Block(const OpenText, CloseText: string; Nested: boolean);
var
  Depth: SizeInt;
begin
  Depth := 1;
  Inc(Cursor, Length(OpenText));
  while Cursor <= Limit do
  begin
    if At(CloseText) then
    begin
      Inc(Cursor, Length(CloseText));
      Dec(Depth);
      if Depth = 0 then Break;
    end
    else if Nested and At(OpenText) then
    begin
      Inc(Depth);
      Inc(Cursor, Length(OpenText));
    end
    else
      Inc(Cursor);
  end;
end;

class function TTableSyntaxHighlighter.GetLanguages: TStringDynArray;
begin
  Result := LanguageNames(Describe.Names);
end;

constructor TTableSyntaxHighlighter.Create;
begin
  inherited Create;
  FDescription := Describe;
end;

function TTableSyntaxHighlighter.WordKind(const Value: string): TSyntaxHighlightKind;
var
  WordText: string;
begin
  WordText := Value;
  if not FDescription.CaseSensitive then WordText := LowerCase(WordText);
  if WordsContain(FDescription.Keywords, WordText) then Result := shKeyword
  else if WordsContain(FDescription.Builtins, WordText) then Result := shKey
  else
    Result := shDefault;
end;

function TTableSyntaxHighlighter.CommentToken: boolean;
var
  I, First, N: SizeInt;
  Form: TCommentForm;
  Hit: boolean;
begin
  Result := False;
  if At(FDescription.Attribute) then Exit;
  for I := 0 to High(FDescription.Comments) do
  begin
    Form := FDescription.Comments[I];
    N := Length(Form.OpenText);
    Hit := At(Form.OpenText);
    if not FDescription.CaseSensitive then
      Hit := LowerCase(Copy(Text, Cursor, N)) = Form.OpenText;
    if Hit and (not Form.LineStartOnly or FLineStart) and (not Form.WordBoundary or not (Ch(N) in FDescription.IdentifierRest)) then
    begin
      First := Cursor;
      if Form.CloseText = '' then LineEnd
      else
        Block(Form.OpenText, Form.CloseText, Form.Nested);
      Emit(First, shComment);
      Exit(True);
    end;
  end;
end;

function TTableSyntaxHighlighter.SpecialString: boolean;
var
  First, P, Hashes, N, Depth, TagStart, LineStart: SizeInt;
  Opening, Closing, Tag: string;
  Quote: char;
  Kind: TSyntaxHighlightKind;
begin
  Result := False;
  First := Cursor;
  // Rust and Swift raw strings have a run of hashes in their delimiters.
  if ((FDescription.Flavor = lfRust) and (At('r') or At('br') or At('cr'))) or ((FDescription.Names = 'swift') and At('#')) then
  begin
    P := Cursor;
    if FDescription.Flavor = lfRust then
    begin
      if Ch in ['b', 'c'] then Inc(P);
      Inc(P);
    end;
    Hashes := 0;
    while (P <= Limit) and (Text[P] = '#') do
    begin
      Inc(P);
      Inc(Hashes);
    end;
    if (P <= Limit) and (Text[P] = '"') then
    begin
      Opening := Copy(Text, Cursor, P - Cursor + 1);
      Closing := '"' + StringOfChar('#', Hashes);
      Quoted(Opening, Closing, #0, True, False);
      Emit(First, shRawString);
      Exit(True);
    end;
    if FDescription.Names = 'swift' then
    begin
      // Consume a failed hash run once, rather than retrying each suffix.
      Cursor := P;
      Emit(First, shSymbol);
      Exit(True);
    end;
  end;
  if (FDescription.Flavor = lfCpp) and (At('R"') or At('u8R"') or At('uR"') or At('UR"') or At('LR"')) then
  begin
    P := Cursor;
    while (P <= Limit) and (Text[P] <> '"') do Inc(P);
    TagStart := P + 1;
    Inc(P);
    while (P <= Limit) and (P - TagStart <= 16) and not (Text[P] in ['(', ' ', #9, #10, #13, '\', ')']) do Inc(P);
    if (P <= Limit) and (Text[P] = '(') then
    begin
      Opening := Copy(Text, Cursor, P - Cursor + 1);
      Closing := ')' + Copy(Text, TagStart, P - TagStart) + '"';
      Quoted(Opening, Closing, #0, True, False);
      Emit(First, shRawString);
      Exit(True);
    end;
  end;
  if (FDescription.Flavor = lfCSharp) and (At('"""') or At('$"""')) then
  begin
    P := Cursor;
    while (P <= Limit) and (Text[P] = '$') do Inc(P);
    N := P;
    while (P <= Limit) and (Text[P] = '"') do Inc(P);
    N := P - N;
    Cursor := P;
    while Cursor <= Limit do
    begin
      if Ch = '"' then
      begin
        P := Cursor;
        while (Cursor <= Limit) and (Ch = '"') do Inc(Cursor);
        if Cursor - P >= N then
        begin
          Cursor := P + N;
          Break;
        end;
      end
      else
        Inc(Cursor);
    end;
    Emit(First, shRawString);
    Exit(True);
  end;
  if (FDescription.Flavor = lfLua) and (At('[') or At('--[')) then
  begin
    P := Cursor;
    Kind := shRawString;
    if At('--') then
    begin
      Inc(P, 2);
      Kind := shComment;
    end;
    Inc(P);
    N := 0;
    while (P <= Limit) and (Text[P] = '=') do
    begin
      Inc(P);
      Inc(N);
    end;
    if (P <= Limit) and (Text[P] = '[') then
    begin
      Opening := Copy(Text, Cursor, P - Cursor + 1);
      Quoted(Opening, ']' + StringOfChar('=', N) + ']', #0, True, False);
      Emit(First, Kind);
      Exit(True);
    end;
  end;
  if (FDescription.Flavor = lfZig) and At('\\') then
  begin
    LineEnd;
    Emit(First, shRawString);
    Exit(True);
  end;
  // Percent and quote operators shield their contents, including paired forms.
  P := Cursor;
  if (FDescription.Flavor = lfRuby) and At('%') then
  begin
    Inc(P);
    if (P <= Limit) and (Text[P] in ['q', 'Q', 'w', 'W', 'i', 'I', 'x', 'r', 's']) then Inc(P);
  end
  else if (FDescription.Flavor = lfPerl) and At('q') then
  begin
    Inc(P);
    if (P <= Limit) and (Text[P] in ['q', 'w', 'x', 'r']) then Inc(P);
  end;
  if (P > Cursor) and (P <= Limit) and (Text[P] in ['(', '[', '{', '<', '/', '!', '|']) then
  begin
    Quote := Text[P];
    Closing := Quote;
    case Quote of
      '(': Closing := ')';
      '[': Closing := ']';
      '{': Closing := '}';
      '<': Closing := '>';
      else;
    end;
    Cursor := P + 1;
    Depth := 1;
    while Cursor <= Limit do
    begin
      if Ch = '\' then
      begin
        Inc(Cursor);
        if Cursor <= Limit then Inc(Cursor);
      end
      else if At(Closing) then
      begin
        Inc(Cursor);
        Dec(Depth);
        if Depth = 0 then Break;
      end
      else
      begin
        if (Closing <> Quote) and (Ch = Quote) then Inc(Depth);
        Inc(Cursor);
      end;
    end;
    Emit(First, shStrings);
    Exit(True);
  end;
  if (FDescription.Flavor = lfPowerShell) and (At('@"' + #10) or At('@"' + #13) or At('@''' + #10) or At('@''' + #13)) then
  begin
    Closing := Ch(1) + '@';
    Inc(Cursor, 2);
    while Cursor <= Limit do
    begin
      if (Ch(-1) in [#10, #13]) and At(Closing) then
      begin
        Inc(Cursor, 2);
        Break;
      end;
      Inc(Cursor);
    end;
    Emit(First, shStrings);
    Exit(True);
  end;
  if ((FDescription.Flavor = lfPhp) and At('<<<')) or ((FDescription.Flavor in [lfRuby, lfPerl]) and At('<<')) then
  begin
    P := Cursor + 2;
    if FDescription.Flavor = lfPhp then Inc(P);
    if (P <= Limit) and (Text[P] in ['-', '~']) then Inc(P);
    while (P <= Limit) and (Text[P] in [' ', #9]) do Inc(P);
    Quote := #0;
    if (P <= Limit) and (Text[P] in ['"', '''']) then
    begin
      Quote := Text[P];
      Inc(P);
    end;
    TagStart := P;
    while (P <= Limit) and (Text[P] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Inc(P);
    Tag := Copy(Text, TagStart, P - TagStart);
    if (Tag <> '') and ((Quote = #0) or ((P <= Limit) and (Text[P] = Quote))) then
    begin
      Cursor := P;
      LineEnd;
      while Cursor <= Limit do
      begin
        if At(#13#10) then Inc(Cursor, 2)
        else
          Inc(Cursor);
        LineStart := Cursor;
        while (Cursor <= Limit) and (Ch in [' ', #9]) do Inc(Cursor);
        if At(Tag) and not (Ch(Length(Tag)) in FDescription.IdentifierRest) then
        begin
          Inc(Cursor, Length(Tag));
          Break;
        end;
        Cursor := LineStart;
        LineEnd;
      end;
      Emit(First, shStrings);
      Exit(True);
    end;
  end;
end;

function TTableSyntaxHighlighter.StringToken: boolean;
var
  I, First, P: SizeInt;
  Form: TStringForm;
begin
  Result := False;
  for I := 0 to High(FDescription.Strings) do
  begin
    Form := FDescription.Strings[I];
    if At(Form.OpenText) then
    begin
      // A Rust lifetime and an Ada attribute are not unfinished character literals.
      if (Form.Kind = shCharacters) and (FDescription.Flavor in [lfRust, lfAda]) and (Ch = '''') then
      begin
        P := Cursor + 1;
        if (P <= Limit) and (Text[P] = '\') then
        begin
          Inc(P);
          if (P + 1 <= Limit) and (Text[P] = 'u') and (Text[P + 1] = '{') then
          begin
            Inc(P, 2);
            while (P <= Limit) and (Text[P] in ['0'..'9', 'a'..'f', 'A'..'F', '_']) do Inc(P);
            if (P <= Limit) and (Text[P] = '}') then Inc(P);
          end
          else if (P <= Limit) and (Text[P] = 'x') then Inc(P, 3)
          else
            Inc(P);
        end
        else
        begin
          if P <= Limit then Inc(P);
          while (P <= Limit) and (Text[P] in [#128..#191]) do Inc(P);
        end;
        if (P > Limit) or (Text[P] <> '''') then Continue;
        First := Cursor;
        Cursor := P + 1;
        Emit(First, shCharacters);
        Exit(True);
      end;
      First := Cursor;
      Quoted(Form.OpenText, Form.CloseText, Form.Escape, Form.Multiline, Form.Doubled);
      Emit(First, Form.Kind);
      Exit(True);
    end;
  end;
end;

procedure TTableSyntaxHighlighter.NumberToken;
var
  First, Base, P: SizeInt;
  Allowed: TSysCharSet;
  Form: TNumberForms;
  IsHex: boolean;
begin
  First := Cursor;
  Form := FDescription.Numbers;
  Base := 10;
  IsHex := False;
  Allowed := ['0'..'9'];
  if Form.Hex and (At('0x') or At('0X') or At('&h') or At('&H')) then
  begin
    Inc(Cursor, 2);
    Base := 16;
    IsHex := True;
    Allowed := Allowed + ['a'..'f', 'A'..'F'];
  end
  else if Form.Binary and (At('0b') or At('0B') or At('&b') or At('&B')) then
  begin
    Inc(Cursor, 2);
    Base := 2;
    Allowed := ['0', '1'];
  end
  else if Form.Octal and (At('0o') or At('0O') or At('&o') or At('&O')) then
  begin
    Inc(Cursor, 2);
    Base := 8;
    Allowed := ['0'..'7'];
  end
  else if Form.LeadingOctal and (Ch = '0') and (Ch(1) in ['0'..'7']) then
  begin
    Base := 8;
    Allowed := ['0'..'7'];
  end;
  if Form.Separators then Include(Allowed, Form.Separator);
  while (Cursor <= Limit) and (Ch in Allowed) do Inc(Cursor);
  if Form.Based and (Ch = '#') then
  begin
    Inc(Cursor);
    while (Cursor <= Limit) and (Ch in ['0'..'9', 'a'..'f', 'A'..'F', '_', '.']) do Inc(Cursor);
    if Ch = '#' then Inc(Cursor);
  end
  else if Form.Fraction and ((Base = 10) or (Base = 16)) and (Ch = '.') and (Ch(1) <> '.') and ((Ch(1) in Allowed) or (Cursor = First)) then
  begin
    Inc(Cursor);
    while (Cursor <= Limit) and (Ch in Allowed) do Inc(Cursor);
  end;
  if Form.Exponent and (((not IsHex) and (Pos(Ch, Form.ExponentLetters) > 0)) or (IsHex and Form.HexExponent and (Ch in ['p', 'P']))) and (Cursor <= Limit) then
  begin
    P := Cursor + 1;
    if (P <= Limit) and (Text[P] in ['+', '-']) then Inc(P);
    if (P <= Limit) and (Text[P] in ['0'..'9']) then
    begin
      Cursor := P + 1;
      while (Cursor <= Limit) and (Ch in ['0'..'9', '_']) do Inc(Cursor);
    end;
  end;
  if Form.TrailingBase then
    while (Cursor <= Limit) and (Ch in ['0'..'9', 'A'..'F', 'a'..'f', 'H', 'h', 'X', 'x']) do Inc(Cursor);
  while (Cursor <= Limit) and (Pos(Ch, Form.Suffixes) > 0) do Inc(Cursor);
  if Cursor = First then Inc(Cursor);
  Emit(First, shNumbers);
end;

procedure TTableSyntaxHighlighter.DoExecute(const Source: string);
var
  First, P: SizeInt;
  Value: string;
  Kind: TSyntaxHighlightKind;
begin
  Start(Source);
  FLineStart := True;
  while Cursor <= Limit do
  begin
    First := Cursor;
    if Ch in [#9, ' '] then
    begin
      while (Cursor <= Limit) and (Ch in [#9, ' ']) do Inc(Cursor);
      Emit(First, shDefault);
      Continue;
    end;
    if Ch in [#10, #13] then
    begin
      if At(#13#10) then Inc(Cursor, 2)
      else
        Inc(Cursor);
      Emit(First, shDefault);
      FLineStart := True;
      Continue;
    end;
    if (FDescription.Flavor = lfAssembly) and (Ch = '#') and not (Ch(1) in ['0'..'9', '+', '-']) then
    begin
      LineEnd;
      Emit(First, shComment);
      Continue;
    end;
    if SpecialString or CommentToken or StringToken then
    begin
      FLineStart := False;
      Continue;
    end;
    if FLineStart and At(FDescription.Directive) then
    begin
      LineEnd;
      Emit(First, shDirective);
    end
    else if At(FDescription.Attribute) then
    begin
      Inc(Cursor, Length(FDescription.Attribute));
      while (Cursor <= Limit) and (Ch in FDescription.IdentifierRest + ['.']) do Inc(Cursor);
      Emit(First, shAttribute);
    end
    else if (Ch in ['0'..'9']) or (FDescription.Numbers.LeadingDot and (Ch = '.') and (Ch(1) in ['0'..'9'])) or
      ((FDescription.Flavor = lfBasic) and (Ch = '&') and (Ch(1) in ['h', 'H', 'o', 'O', 'b', 'B'])) then
      NumberToken
    else if Ch in FDescription.IdentifierStart then
    begin
      Inc(Cursor);
      while (Cursor <= Limit) and (Ch in FDescription.IdentifierRest) do Inc(Cursor);
      Value := Copy(Text, First, Cursor - First);
      Kind := WordKind(Value);
      if (FDescription.Flavor = lfDocker) and not FLineStart then Kind := shDefault;
      if (FDescription.Flavor = lfToml) then
      begin
        P := Cursor;
        while (P <= Limit) and (Text[P] in [' ', #9]) do Inc(P);
        if (P <= Limit) and (Text[P] = '=') then Kind := shKey;
      end;
      Emit(First, Kind);
    end
    else
    begin
      Kind := shDefault;
      if Ch in FDescription.Operators then Kind := shOperator
      else if Ch in FDescription.Symbols then Kind := shSymbol;
      Unknown;
      Emit(First, Kind);
    end;
    FLineStart := False;
  end;
  Finish;
end;

end.
