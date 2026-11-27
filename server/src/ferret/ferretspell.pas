unit FerretSpell;

{$mode objfpc}{$H+}
// Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.

interface

uses SysUtils, Math, FerretText;

// Skip is the first key past a prefix that cannot contain a match.
function WordDistance(const word, Candidate: string; Limit: integer; out Skip: string): integer;
function EditLimit(const word: string): integer;

implementation

function EditLimit(const word: string): integer;
begin
  Result := 1;
  if UTF8Length(word) >= 8 then Result := 2;
end;

function WordDistance(const word, Candidate: string; Limit: integer; out Skip: string): integer;
var
  Codes: array of cardinal;
  Rows: array[0..3] of array of integer;
  Offset, I, J, N, Current, Previous, Older, Oldest, Best, Cost: integer;
  Code, LastCode, BeforeLastCode: cardinal;
begin
  Skip := '';
  Offset := 1;
  N := 0;
  SetLength(Codes, Length(word));
  while Offset <= Length(word) do
  begin
    Codes[N] := NextUTF8(word, Offset);
    Inc(N);
  end;
  for I := 0 to 3 do SetLength(Rows[I], N + 1);
  for J := 0 to N do Rows[0][J] := J;
  Offset := 1;
  I := 0;
  LastCode := 0;
  BeforeLastCode := 0;
  Current := 0;
  while Offset <= Length(Candidate) do
  begin
    Code := NextUTF8(Candidate, Offset);
    Inc(I);
    Current := I mod 4;
    Previous := (I + 3) mod 4;
    Older := (I + 2) mod 4;
    Oldest := (I + 1) mod 4;
    Rows[Current][0] := I;
    Best := I;
    for J := 1 to N do
    begin
      Cost := Ord(Code <> Codes[J - 1]);
      Rows[Current][J] := Min(Rows[Previous][J] + 1, Min(Rows[Current][J - 1] + 1, Rows[Previous][J - 1] + Cost));
      if (I > 1) and (J > 1) and (Code = Codes[J - 2]) and (LastCode = Codes[J - 1]) then
        Rows[Current][J] := Min(Rows[Current][J], Rows[Older][J - 2] + 1);
      // Two edits may insert or remove a character inside a transposed pair.
      if (I > 1) and (J > 2) and (Code = Codes[J - 3]) and (LastCode = Codes[J - 1]) then
        Rows[Current][J] := Min(Rows[Current][J], Rows[Older][J - 3] + 2);
      if (I > 2) and (J > 1) and (Code = Codes[J - 2]) and (BeforeLastCode = Codes[J - 1]) then
        Rows[Current][J] := Min(Rows[Current][J], Rows[Oldest][J - 2] + 2);
      Best := Min(Best, Rows[Current][J]);
    end;
    if Best > Limit then
    begin
      Skip := Copy(Candidate, 1, Offset - 1);
      Skip[Length(Skip)] := Chr(Ord(Skip[Length(Skip)]) + 1);
      Exit(Limit + 1);
    end;
    BeforeLastCode := LastCode;
    LastCode := Code;
  end;
  Result := Rows[Current][N];
end;

end.
