unit FerretCompress;

{$mode objfpc}{$H+}
// Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.

interface

uses Classes, SysUtils, FerretTypes;

function CompressBlock(const Data: rawbytestring; Dense: boolean): rawbytestring;
function ExpandBlock(const Data: rawbytestring; Expected: integer): rawbytestring;

implementation

uses ZStream;

function FastBlock(const Data: rawbytestring): rawbytestring;
var
  Table: array[0..16383] of integer;
  I, Anchor, Match, Count, LiteralCount, OutPos, TokenAt, H, J, Distance, Best, EndPos: integer;
  Value, Other: cardinal;
  Output: pbyte;

  procedure ByteOut(Value: integer);
  begin
    Output[OutPos - 1] := Value;
    Inc(OutPos);
  end;

  procedure Extra(Value: integer);
  begin
    while Value >= 255 do
    begin
      ByteOut(255);
      Dec(Value, 255);
    end;
    ByteOut(Value);
  end;

  procedure Literals(First, Count: integer);
  begin
    if Count > 0 then Move(Data[First], Output[OutPos - 1], Count);
    Inc(OutPos, Count);
  end;

begin
  FillChar(Table, SizeOf(Table), 0);
  SetLength(Result, Length(Data) + Length(Data) div 255 + 32);
  Output := pbyte(PChar(Result));
  Output[0] := 2;
  OutPos := 2;
  I := 1;
  Anchor := 1;
  while I <= Length(Data) - 3 do
  begin
    Move(Data[I], Value, 4);
    H := ((QWord(Value) * 2654435761) shr 18) and 16383;
    Match := Table[H];
    Table[H] := I;
    Best := 3;
    if Match > 0 then
    begin
      Move(Data[Match], Other, 4);
      if Value = Other then
      begin
        Best := 4;
        while (I + Best + 7 <= Length(Data)) and (PQWord(@Data[Match + Best])^ = PQWord(@Data[I + Best])^) do Inc(Best, 8);
        while (I + Best <= Length(Data)) and (Data[Match + Best] = Data[I + Best]) do Inc(Best);
      end;
    end;
    if Best < 4 then
    begin
      Inc(I);
      Continue;
    end;
    Count := Best;
    LiteralCount := I - Anchor;
    TokenAt := OutPos;
    ByteOut(0);
    J := LiteralCount;
    if J > 15 then J := 15;
    Output[TokenAt - 1] := J shl 4;
    J := Count - 4;
    if J > 15 then J := 15;
    Output[TokenAt - 1] := Output[TokenAt - 1] or J;
    if LiteralCount >= 15 then Extra(LiteralCount - 15);
    Literals(Anchor, LiteralCount);
    Distance := I - Match;
    ByteOut(Distance and 255);
    ByteOut(Distance shr 8);
    if Count >= 19 then Extra(Count - 19);
    EndPos := I + Count;
    if EndPos <= Length(Data) - 1 then
    begin
      Move(Data[EndPos - 2], Value, 4);
      H := ((QWord(Value) * 2654435761) shr 18) and 16383;
      Table[H] := EndPos - 2;
    end;
    I := EndPos;
    Anchor := I;
  end;
  LiteralCount := Length(Data) - Anchor + 1;
  if LiteralCount > 0 then
  begin
    J := LiteralCount;
    if J > 15 then J := 15;
    ByteOut(J shl 4);
    if LiteralCount >= 15 then Extra(LiteralCount - 15);
    Literals(Anchor, LiteralCount);
  end;
  SetLength(Result, OutPos - 1);
end;

function ExpandFast(const Data: rawbytestring; Expected: integer): rawbytestring;
var
  I, N, Token, Count, Distance, J, Part, Extra: integer;
  Output: pbyte;

  procedure Fail;
  begin
    raise EFerret.Create('A compressed index block is damaged. Rebuild the index.');
  end;

  function LengthOf(Base: integer): integer;
  begin
    Result := Base;
    if Base <> 15 then Exit;
    repeat
      if I > Length(Data) then Fail;
      Extra := Ord(Data[I]);
      Inc(I);
      if Result > Expected - Extra then Fail;
      Inc(Result, Extra);
    until Extra < 255;
  end;

begin
  SetLength(Result, Expected);
  Output := pbyte(PChar(Result));
  I := 2;
  N := 1;
  while I <= Length(Data) do
  begin
    Token := Ord(Data[I]);
    Inc(I);
    Count := LengthOf(Token shr 4);
    if (Count > Length(Data) - I + 1) or (Count > Expected - N + 1) then Fail;
    if Count > 0 then Move(Data[I], Output[N - 1], Count);
    Inc(I, Count);
    Inc(N, Count);
    if I > Length(Data) then Break;
    if I = Length(Data) then Fail;
    Distance := Ord(Data[I]) or (Ord(Data[I + 1]) shl 8);
    Inc(I, 2);
    if (Distance < 1) or (Distance >= N) then Fail;
    Count := LengthOf(Token and 15) + 4;
    if Count > Expected - N + 1 then Fail;
    J := Count;
    if J > Distance then J := Distance;
    Move(Output[N - Distance - 1], Output[N - 1], J);
    // Doubling preserves overlapping matches without copying them byte by byte.
    while J < Count do
    begin
      Part := Count - J;
      if Part > J then Part := J;
      Move(Output[N - 1], Output[N + J - 1], Part);
      Inc(J, Part);
    end;
    Inc(N, Count);
  end;
  if N <> Expected + 1 then Fail;
end;

function CompressBlock(const Data: rawbytestring; Dense: boolean): rawbytestring;
var
  Dest: TMemoryStream;
  Stream: TCompressionStream;
begin
  if not Dense then
  begin
    Result := FastBlock(Data);
    if Length(Result) >= Length(Data) + 1 then Result := #0 + Data;
    Exit;
  end;
  Dest := TMemoryStream.Create;
  try
    Stream := TCompressionStream.Create(clFastest, Dest);
    try
      if Data <> '' then Stream.WriteBuffer(Data[1], Length(Data));
    finally
      Stream.Free;
    end;
    if Dest.Size + 1 >= Length(Data) then Exit(#0 + Data);
    SetLength(Result, Dest.Size + 1);
    Result[1] := #1;
    if Dest.Size > 0 then Move(Dest.Memory^, Result[2], Dest.Size);
  finally
    Dest.Free;
  end;
end;

function ExpandBlock(const Data: rawbytestring; Expected: integer): rawbytestring;
var
  Source: TMemoryStream;
  Stream: TDecompressionStream;
  Extra: byte;
begin
  Result := '';
  if Data = '' then raise EFerret.Create('A compressed index block is missing. Rebuild the index.');
  if Data[1] = #2 then Exit(ExpandFast(Data, Expected));
  if Data[1] = #0 then
  begin
    if Length(Data) <> Expected + 1 then raise EFerret.Create('An index block has the wrong size. Rebuild the index.');
    Exit(Copy(Data, 2, MaxInt));
  end;
  if Data[1] <> #1 then raise EFerret.Create('A compressed index block is damaged. Rebuild the index.');
  Source := TMemoryStream.Create;
  try
    if Length(Data) > 1 then Source.WriteBuffer(Data[2], Length(Data) - 1);
    Source.Position := 0;
    try
      Stream := TDecompressionStream.Create(Source);
      try
        SetLength(Result, Expected);
        if Expected > 0 then Stream.ReadBuffer(Result[1], Expected);
        if Stream.Read(Extra, 1) <> 0 then raise EReadError.Create('Block size mismatch.');
      finally
        Stream.Free;
      end;
    except
      on E: Exception do raise EFerret.Create('A compressed index block is damaged. Rebuild the index.');
    end;
  finally
    Source.Free;
  end;
end;

end.
