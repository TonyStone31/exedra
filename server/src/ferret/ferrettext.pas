unit FerretText;

{$mode objfpc}{$H+}
// Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.

interface

uses SysUtils, FerretTypes;

type
  TFerretToken = record
    Term, Original: string;
    Stems: TFerretStrings;
    Correction: string;
    Position, Span, ByteStart, ByteLength: integer;
    Primary, StemAllowed: boolean;
  end;
  TFerretTokens = array of TFerretToken;

function NextUTF8(const Text: string; var Offset: integer): cardinal;
function FoldText(const Text: string): string;
function SplitText(const Text: string; out WordCount: integer): TFerretTokens;
function UTF8Length(const Text: string): integer;
// A title or typed text folded, with ASCII punctuation and spaces as single spaces, at most 64 bytes.
function TitleKey(const Text: string): string;
// Adds the terms that find a title by how it begins and by how each later word begins.
procedure AddTitleTerms(const Title: string; var Tokens: TFerretTokens);

implementation

type
  TUnicodeRange = record
    First, Last: cardinal;
    Flags: byte;
  end;

  TUnicodeFold = record
    Code: cardinal;
    Text: string[24];
  end;

  TCharacter = record
    Code: cardinal;
    First, After: integer;
    Flags: byte;
  end;
  TCharacters = array of TCharacter;

  {$I ferretunicode.inc}

function NextUTF8(const Text: string; var Offset: integer): cardinal;
var
  I, Count: integer;
  B: byte;
  Minimum: cardinal;
begin
  if (Offset < 1) or (Offset > Length(Text)) then
    raise EFerret.Create('UTF-8 offset outside the text.');
  B := Ord(Text[Offset]);
  Inc(Offset);
  if B < $80 then Exit(B);
  if B in [$C2..$DF] then
  begin
    Count := 1;
    Result := B and $1F;
    Minimum := $80;
  end
  else if B in [$E0..$EF] then
  begin
    Count := 2;
    Result := B and $0F;
    Minimum := $800;
  end
  else if B in [$F0..$F4] then
  begin
    Count := 3;
    Result := B and 7;
    Minimum := $10000;
  end
  else
    raise EFerret.Create('Invalid UTF-8.');
  if Offset + Count - 1 > Length(Text) then raise EFerret.Create('Incomplete UTF-8.');
  for I := 1 to Count do
  begin
    B := Ord(Text[Offset]);
    Inc(Offset);
    if B and $C0 <> $80 then raise EFerret.Create('Invalid UTF-8 continuation.');
    Result := Result shl 6 or (B and $3F);
  end;
  if (Result < Minimum) or (Result > $10FFFF) or ((Result >= $D800) and (Result <= $DFFF)) then raise EFerret.Create('Invalid UTF-8 code point.');
end;

function CharacterFlags(Code: cardinal): byte;
var
  L, H, M: integer;
begin
  if Code < 128 then
  begin
    if (Code >= Ord('A')) and (Code <= Ord('Z')) then Exit(5);
    if (Code >= Ord('a')) and (Code <= Ord('z')) then Exit(6);
    if (Code >= Ord('0')) and (Code <= Ord('9')) then Exit(4);
    Exit(0);
  end;
  L := 0;
  H := High(UnicodeRanges);
  while L <= H do
  begin
    M := L + (H - L) div 2;
    if Code < UnicodeRanges[M].First then H := M - 1
    else if Code > UnicodeRanges[M].Last then L := M + 1
    else
      Exit(UnicodeRanges[M].Flags);
  end;
  Result := 0;
end;

function FoldCharacter(Code: cardinal; const Original: string): string;
var
  L, H, M: integer;
begin
  L := 0;
  H := High(UnicodeFolds);
  while L <= H do
  begin
    M := L + (H - L) div 2;
    if Code < UnicodeFolds[M].Code then H := M - 1
    else if Code > UnicodeFolds[M].Code then L := M + 1
    else
      Exit(UnicodeFolds[M].Text);
  end;
  Result := Original;
end;

function FoldText(const Text: string): string;
var
  Offset, First, Used: integer;
  Code: cardinal;
  Part: string;
begin
  Result := '';
  SetLength(Result, Length(Text) * 3 + 24);
  Offset := 1;
  Used := 0;
  while Offset <= Length(Text) do
  begin
    First := Offset;
    Code := NextUTF8(Text, Offset);
    if Code < 128 then
    begin
      if (Code >= Ord('A')) and (Code <= Ord('Z')) then Inc(Code, 32);
      Inc(Used);
      Result[Used] := Chr(Code);
      Continue;
    end;
    Part := FoldCharacter(Code, Copy(Text, First, Offset - First));
    if Used + Length(Part) > Length(Result) then SetLength(Result, (Used + Length(Part)) * 2);
    if Part <> '' then Move(Part[1], Result[Used + 1], Length(Part));
    Inc(Used, Length(Part));
  end;
  SetLength(Result, Used);
end;

function UTF8Length(const Text: string): integer;
var
  Offset: integer;
begin
  Offset := 1;
  Result := 0;
  while Offset <= Length(Text) do
  begin
    NextUTF8(Text, Offset);
    Inc(Result);
  end;
end;

function ReadCharacters(const Text: string): TCharacters;
var
  Offset, Count: integer;
begin
  Result := nil;
  SetLength(Result, Length(Text));
  Offset := 1;
  Count := 0;
  while Offset <= Length(Text) do
  begin
    Result[Count].First := Offset;
    Result[Count].Code := NextUTF8(Text, Offset);
    Result[Count].After := Offset;
    Result[Count].Flags := CharacterFlags(Result[Count].Code);
    Inc(Count);
  end;
  SetLength(Result, Count);
end;

function SplitText(const Text: string; out WordCount: integer): TFerretTokens;
var
  Chars: TCharacters;
  Used, I, J, K, SegmentStart, PartStart, RunStart, RunPosition, SegmentPosition, Count, LastBase, RunToken: integer;
  Identifier: boolean;

  procedure Emit(First, After, Position, Span: integer; Primary: boolean);
  var
    Token: TFerretToken;
  begin
    if First >= After then Exit;
    Token.ByteStart := Chars[First].First;
    Token.ByteLength := Chars[After - 1].After - Token.ByteStart;
    Token.Original := Copy(Text, Token.ByteStart, Token.ByteLength);
    Token.Term := FoldText(Token.Original);
    Token.StemAllowed := Primary;
    if Token.Term = '' then Exit;
    Token.Position := Position;
    Token.Span := Span;
    Token.Primary := Primary;
    if Used = Length(Result) then SetLength(Result, Used * 2 + 16);
    Result[Used] := Token;
    Inc(Used);
  end;

  function CamelBoundary(Index, Previous: integer): boolean;
  begin
    Result := False;
    if (Previous < PartStart) or (Chars[Index].Flags and 8 <> 0) then Exit;
    if (Chars[Previous].Flags and 2 <> 0) and (Chars[Index].Flags and 1 <> 0) then Exit(True);
    if (Index + 1 < J) and (Chars[Previous].Flags and 1 <> 0) and (Chars[Index].Flags and 1 <> 0) and (Chars[Index + 1].Flags and 2 <> 0) then Result := True;
  end;

begin
  Result := nil;
  Chars := ReadCharacters(Text);
  WordCount := 0;
  Used := 0;
  I := 0;
  while I < Length(Chars) do
  begin
    if (Chars[I].Flags and 4 = 0) and (Chars[I].Code <> Ord('_')) then
    begin
      Inc(I);
      Continue;
    end;
    if Chars[I].Flags and 16 <> 0 then
    begin
      J := I;
      while (J < Length(Chars)) and (Chars[J].Flags and (16 or 8) <> 0) do Inc(J);
      K := I;
      while K < J do
      begin
        SegmentStart := K;
        Inc(K);
        while (K < J) and (Chars[K].Flags and 8 <> 0) do Inc(K);
        SegmentPosition := WordCount;
        Inc(WordCount);
        if K < J then
        begin
          Count := K + 1;
          while (Count < J) and (Chars[Count].Flags and 8 <> 0) do Inc(Count);
          Emit(SegmentStart, Count, SegmentPosition, 2, True);
          Emit(SegmentStart, K, SegmentPosition, 1, False);
        end
        else
          Emit(SegmentStart, K, SegmentPosition, 1, J - I = K - SegmentStart);
      end;
      I := J;
      Continue;
    end;
    RunStart := I;
    RunToken := Used;
    RunPosition := WordCount;
    J := I;
    while I < Length(Chars) do
    begin
      if Chars[I].Code = Ord('_') then
      begin
        Inc(I);
        Continue;
      end;
      if (Chars[I].Flags and 4 = 0) or (Chars[I].Flags and 16 <> 0) then Break;
      SegmentStart := I;
      SegmentPosition := WordCount;
      J := I;
      while (J < Length(Chars)) and (Chars[J].Flags and (4 or 8) <> 0) and (Chars[J].Flags and 16 = 0) do Inc(J);
      PartStart := I;
      LastBase := -1;
      for K := I to J - 1 do
      begin
        if CamelBoundary(K, LastBase) then
        begin
          Emit(PartStart, K, WordCount, 1, True);
          Inc(WordCount);
          PartStart := K;
        end;
        if Chars[K].Flags and 8 = 0 then LastBase := K;
      end;
      Emit(PartStart, J, WordCount, 1, True);
      Inc(WordCount);
      if WordCount - SegmentPosition > 1 then
        Emit(SegmentStart, J, SegmentPosition, WordCount - SegmentPosition, False);
      I := J;
      if (I < Length(Chars)) and (Chars[I].Code = Ord('_')) then Continue;
      if (I + 1 >= Length(Chars)) or (Chars[I].Code <> Ord('.')) or ((Chars[I + 1].Flags and 4 = 0) and (Chars[I + 1].Code <> Ord('_'))) or
        (Chars[I + 1].Flags and 16 <> 0) then Break;
      Inc(I);
    end;
    if (WordCount > RunPosition) and ((SegmentStart <> RunStart) or (I <> J)) then
      Emit(RunStart, I, RunPosition, WordCount - RunPosition, False);
    Identifier := (WordCount - RunPosition > 1) or (I <> J);
    for K := RunStart to I - 1 do
      if (Chars[K].Code = Ord('_')) or ((Chars[K].Flags and 4 <> 0) and (Chars[K].Flags and 3 = 0)) then Identifier := True;
    if Identifier then
      for K := RunToken to Used - 1 do Result[K].StemAllowed := False;
  end;
  SetLength(Result, Used);
end;

function TitleKey(const Text: string): string;
var
  Folded: string;
  I, N: integer;
begin
  Folded := FoldText(Text);
  Result := '';
  SetLength(Result, Length(Folded));
  N := 0;
  for I := 1 to Length(Folded) do
    if (Folded[I] >= #128) or (Folded[I] in ['0'..'9', 'a'..'z']) then
    begin
      Inc(N);
      Result[N] := Folded[I];
    end
    else if (N > 0) and (Result[N] <> ' ') then
    begin
      Inc(N);
      Result[N] := ' ';
    end;
  if N > 64 then
  begin
    N := 64;
    // A cut never splits a character.
    while (N > 0) and (Ord(Result[N + 1]) and $C0 = $80) do Dec(N);
  end;
  SetLength(Result, N);
  Result := TrimRight(Result);
end;

procedure AddTitleTerms(const Title: string; var Tokens: TFerretTokens);
var
  Key: string;
  I, Starts: integer;

  procedure Add(const Term: string);
  var
    N: integer;
  begin
    N := Length(Tokens);
    SetLength(Tokens, N + 1);
    Tokens[N] := Tokens[0];
    Tokens[N].Term := Term;
    Tokens[N].Primary := False;
    Tokens[N].StemAllowed := False;
  end;

begin
  Key := TitleKey(Title);
  if (Key = '') or (Length(Tokens) = 0) then Exit;
  Add(#2'T:' + Key);
  Starts := 0;
  for I := 2 to Length(Key) do
    if (Key[I - 1] = ' ') and (Starts < 8) then
    begin
      Inc(Starts);
      Add(#2't:' + Copy(Key, I, MaxInt));
    end;
end;

end.
