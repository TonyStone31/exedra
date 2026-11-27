unit FerretCRC;

{$mode objfpc}{$H+}
// Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.

interface

function FerretCRC32(Value: cardinal; Data: pbyte; Count: SizeInt): cardinal;

implementation

var
  Tables: array[0..7, 0..255] of cardinal;

procedure PrepareTables;
var
  I, J, K: integer;
  Value: cardinal;
begin
  for I := 0 to 255 do
  begin
    Value := I;
    for J := 0 to 7 do
      if Value and 1 <> 0 then Value := (Value shr 1) xor $EDB88320
      else
        Value := Value shr 1;
    Tables[0, I] := Value;
  end;
  for K := 1 to 7 do
    for I := 0 to 255 do
    begin
      Value := Tables[K - 1, I];
      Tables[K, I] := (Value shr 8) xor Tables[0, Value and 255];
    end;
end;

function FerretCRC32(Value: cardinal; Data: pbyte; Count: SizeInt): cardinal;
begin
  Value := not Value;
  // Independent byte contributions avoid eight dependent table lookups per group.
  while Count >= 8 do
  begin
    Value := Value xor cardinal(Data[0]) xor (cardinal(Data[1]) shl 8) xor (cardinal(Data[2]) shl 16) xor (cardinal(Data[3]) shl 24);
    Value := Tables[7, Value and 255] xor Tables[6, (Value shr 8) and 255] xor Tables[5, (Value shr 16) and 255] xor Tables[4, Value shr 24] xor
      Tables[3, Data[4]] xor Tables[2, Data[5]] xor Tables[1, Data[6]] xor Tables[0, Data[7]];
    Inc(Data, 8);
    Dec(Count, 8);
  end;
  while Count > 0 do
  begin
    Value := (Value shr 8) xor Tables[0, (Value xor Data^) and 255];
    Inc(Data);
    Dec(Count);
  end;
  Result := not Value;
end;

initialization
  PrepareTables;
end.
