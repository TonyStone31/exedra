unit FerretQuery;

{$mode objfpc}{$H+}
// Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.

interface

uses SysUtils, FerretTypes, FerretText;

type
  TFerretClause = record
    Words: TFerretTokens;
    Negative, Phrase, Prefix: boolean;
    Branch, TextStart: integer;
  end;
  TFerretClauses = array of TFerretClause;

  TFerretParsedQuery = record
    Clauses: TFerretClauses;
    Branches: integer;
    Titles: TFerretStrings;
  end;

function ParseQuery(const Text: string; PrefixLast: boolean): TFerretParsedQuery;

implementation

function QueryWords(const Text: string; Phrase: boolean): TFerretTokens;
var
  All: TFerretTokens;
  I, N, Count: integer;
begin
  Result := nil;
  All := SplitText(Text, Count);
  if not Phrase then
    for I := High(All) downto 0 do
      if (All[I].ByteStart = 1) and (All[I].ByteLength = Length(Text)) then
      begin
        SetLength(Result, 1);
        Result[0] := All[I];
        Exit;
      end;
  N := 0;
  SetLength(Result, Length(All));
  for I := 0 to High(All) do
    if All[I].Primary then
    begin
      Result[N] := All[I];
      Inc(N);
    end;
  SetLength(Result, N);
end;

function ParseQuery(const Text: string; PrefixLast: boolean): TFerretParsedQuery;
var
  I, First, N, J, Branch, Last, PositiveCount: integer;
  Raw: string;
  Negative, Quoted, AtEnd, Unfinished: boolean;
  Words: TFerretTokens;

  procedure Append(const Terms: TFerretTokens; Phrase: boolean);
  begin
    N := Length(Result.Clauses);
    SetLength(Result.Clauses, N + 1);
    Result.Clauses[N].Words := Terms;
    Result.Clauses[N].Negative := Negative;
    Result.Clauses[N].Phrase := Phrase;
    Result.Clauses[N].Branch := Branch;
    Result.Clauses[N].TextStart := First;
    if not Negative then Inc(PositiveCount);
    Last := N;
  end;

begin
  Result.Clauses := nil;
  Result.Branches := 0;
  Result.Titles := nil;
  I := 1;
  Branch := 0;
  Last := -1;
  PositiveCount := 0;
  AtEnd := False;
  while I <= Length(Text) do
  begin
    if Text[I] in [#9, #10, #13, ' '] then
    begin
      Inc(I);
      AtEnd := False;
      Continue;
    end;
    Negative := Text[I] = '-';
    if Negative then Inc(I);
    if I > Length(Text) then
    begin
      if PrefixLast then Break;
      raise EFerret.Create('Add a word after the minus.');
    end;
    Unfinished := False;
    Quoted := Text[I] = '"';
    if Quoted then
    begin
      Inc(I);
      First := I;
      while (I <= Length(Text)) and (Text[I] <> '"') do Inc(I);
      Unfinished := I > Length(Text);
      if Unfinished and not PrefixLast then raise EFerret.Create('Close the quoted phrase with a quote.');
      Raw := Copy(Text, First, I - First);
      Inc(I);
      if (I <= Length(Text)) and not (Text[I] in [#9, #10, #13, ' ']) then
        raise EFerret.Create('Separate a phrase from the next word with a space.');
    end
    else
    begin
      First := I;
      while (I <= Length(Text)) and not (Text[I] in [#9, #10, #13, ' ']) do Inc(I);
      Raw := Copy(Text, First, I - First);
      if Pos('"', Raw) > 0 then raise EFerret.Create('A quote must start a phrase.');
    end;
    if (Raw = 'OR') and not Quoted and not Negative then
    begin
      if PositiveCount = 0 then raise EFerret.Create('OR needs words on both sides.');
      Inc(Branch);
      PositiveCount := 0;
      Last := -1;
      Continue;
    end;
    Words := QueryWords(Raw, Quoted);
    if Length(Words) = 0 then
    begin
      if Unfinished and PrefixLast then Continue;
      if Quoted or Negative then raise EFerret.Create('Expected a searchable word.');
      AtEnd := False;
      Continue;
    end;
    if Quoted then Append(Words, True)
    else
      for J := 0 to High(Words) do Append(Copy(Words, J, 1), False);
    AtEnd := not Quoted and not Negative;
  end;
  if (Length(Result.Clauses) = 0) and (Branch = 0) then Exit;
  if PositiveCount = 0 then
  begin
    if not PrefixLast then raise EFerret.Create('Add a positive word to each OR branch.');
    if Branch = 0 then
    begin
      Result.Clauses := nil;
      Exit;
    end;
    Dec(Branch);
  end;
  Result.Branches := Branch + 1;
  if PrefixLast and AtEnd and (Last >= 0) then Result.Clauses[Last].Prefix := True;
end;

end.
