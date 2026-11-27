unit FerretSuggest;

{$mode objfpc}{$H+}
// Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.

interface

uses Classes, SysUtils, FerretTypes, FerretText, FerretSegment, FerretStore, FerretQuery;

function VisibleWordCount(Store: TFerretStore; Query: TFerretQuery; Terms: TStrings; StopAfter: integer): integer;
function SuggestWords(Store: TFerretStore; const word: string; Query: TFerretQuery): TFerretStrings;
// Returns the corrected query in folded words; Shown has each replaced word as a readable document spells it.
function CorrectWords(Store: TFerretStore; Query: TFerretQuery; var Parsed: TFerretParsedQuery; out Shown: string): string;
function WholeWords(const Text: string): TFerretTokens;
function WordBoundary(C: char): boolean;
// The source text of a word in one document: with Whole the identifier around it, else its own letters,
// in lower case when the document has it so anywhere, since a title or a sentence starts with a capital.
function SpellingInDocument(Store: TFerretStore; Scope: TFerretQuery; const Doc: TFerretTermDocument; const Block: TFerretTermBlock; Whole: boolean): string;

implementation

uses FerretSpell;

function WholeWords(const Text: string): TFerretTokens;
var
  All: TFerretTokens;
  I, J, N, Words: integer;
  Contained: boolean;
begin
  All := SplitText(Text, Words);
  Result := nil;
  for I := 0 to High(All) do
  begin
    Contained := False;
    for J := 0 to High(All) do
      if (All[J].ByteStart <= All[I].ByteStart) and (All[J].ByteStart + All[J].ByteLength >= All[I].ByteStart + All[I].ByteLength) and
        (All[J].ByteLength > All[I].ByteLength) then Contained := True;
    if Contained then Continue;
    N := Length(Result);
    SetLength(Result, N + 1);
    Result[N] := All[I];
  end;
end;

function WordBoundary(C: char): boolean;
begin
  Result := C in [#0..#32, ',', ';', ':', '(', ')', '[', ']', '{', '}', '"', '''', '/', '\', '=', '+', '-', '*', '<', '>'];
end;

function SpellingInDocument(Store: TFerretStore; Scope: TFerretQuery; const Doc: TFerretTermDocument; const Block: TFerretTermBlock; Whole: boolean): string;
var
  Positions: TFerretPostings;
  Source: TFerretDocument;
  Parts: TFerretTokens;
  Body, Spelling: string;
  P, F, First, Finish, T: integer;
begin
  Result := '';
  if Doc.Segment <> nil then Positions := Doc.Segment.Positions(Doc, Block.Buffer)
  else
    Positions := Doc.Pending;
  Source := Store.Document(Doc.Number);
  for P := 0 to High(Positions) do
  begin
    F := Positions[P].Field;
    if not Scope.IncludesField(Source.Fields[F].Name) then Continue;
    Body := Source.Fields[F].Text;
    First := Positions[P].ByteStart;
    if (First < 1) or (First > Length(Body)) then Continue;
    Finish := First + Positions[P].ByteLength;
    if not Whole then
    begin
      Spelling := Copy(Body, First, Finish - First);
      if Result = '' then Result := Spelling;
      if Spelling = FoldText(Spelling) then Exit(Spelling);
      Continue;
    end;
    // Expand an identifier alias to the original whole run.
    while (First > 1) and not WordBoundary(Body[First - 1]) do Dec(First);
    while (Finish <= Length(Body)) and not WordBoundary(Body[Finish]) do Inc(Finish);
    if Finish - First > 256 then Continue;
    Parts := WholeWords(Copy(Body, First, Finish - First));
    for T := 0 to High(Parts) do
      if (First + Parts[T].ByteStart - 1 <= Positions[P].ByteStart) and (First + Parts[T].ByteStart + Parts[T].ByteLength - 1 >=
        Positions[P].ByteStart + Positions[P].ByteLength) then
        Exit(Parts[T].Original);
  end;
end;

function VisibleWordCount(Store: TFerretStore; Query: TFerretQuery; Terms: TStrings; StopAfter: integer): integer;
var
  Blocks: TFerretTermBlocks;
  Docs: TFerretTermDocuments;
  Seen: TStringList;
  I, J, K, Bit: integer;
  Included: boolean;
begin
  Result := 0;
  Blocks := Store.WordBlocks(Terms);
  if (Terms.Count = 1) and (Store is TFerretSegmentStore) and (Length(Query.Fields) = 0) and (Length(Query.Filters) = 0) and not Assigned(Query.OnAllow) then
  begin
    for I := 0 to High(Blocks) do
    begin
      for J := 0 to 3 do Inc(Result, PopCnt(Blocks[I].Mask[J]));
      if Result >= StopAfter then Exit;
    end;
    Exit;
  end;
  Seen := TStringList.Create;
  try
    Seen.Sorted := True;
    for I := 0 to High(Blocks) do
    begin
      Docs := Store.BlockDocuments(Blocks[I]);
      for J := 0 to High(Docs) do
      begin
        Bit := Docs[J].Number mod 128;
        if Blocks[I].Mask[Bit div 32] and (cardinal(1) shl (Bit mod 32)) = 0 then Continue;
        if Seen.IndexOf(IntToStr(Docs[J].Number)) >= 0 then Continue;
        Included := False;
        for K := 0 to High(Docs[J].Fields) do
          if Query.IncludesField(Docs[J].Fields[K].Name) then Included := True;
        if not Included then Continue;
        Seen.Add(IntToStr(Docs[J].Number));
        if (Length(Query.Filters) > 0) or Assigned(Query.OnAllow) then
          if not Query.Allows(Store.DocumentInfo(Docs[J].Number)) then Continue;
        Inc(Result);
        if Result >= StopAfter then Exit;
      end;
    end;
  finally
    Seen.Free;
  end;
end;

// Counts a word's documents over the whole index from block masks, reading none.
function LiveWordCount(Store: TFerretStore; Terms: TStrings): integer;
var
  Blocks: TFerretTermBlocks;
  I, J: integer;
begin
  Result := 0;
  Blocks := Store.WordBlocks(Terms);
  for I := 0 to High(Blocks) do
    for J := 0 to 3 do Inc(Result, PopCnt(Blocks[I].Mask[J]));
end;

function SuggestWords(Store: TFerretStore; const word: string; Query: TFerretQuery): TFerretStrings;
var
  Candidates, Terms: TStringList;
  I, J, Count, Distance, Frequency, Key, Live, N: integer;
  Keys, Lives: array of integer;
  Folded, Skip: string;
begin
  Result := nil;
  Keys := nil;
  Lives := nil;
  Folded := FoldText(word);
  if Folded = '' then Exit;
  Candidates := TStringList.Create;
  Terms := TStringList.Create;
  try
    Store.FuzzyTerms(Folded, EditLimit(Folded), Candidates);
    for I := 0 to Candidates.Count - 1 do
    begin
      if Candidates[I] = Folded then Continue;
      Terms.Clear;
      Terms.Add(Candidates[I]);
      Frequency := VisibleWordCount(Store, Query, Terms, 32);
      if Frequency = 0 then Continue;
      Live := Frequency;
      // Among words the asker reads in 32 documents or more, the count over the whole index decides.
      if Frequency >= 32 then
      begin
        Frequency := 32;
        Live := LiveWordCount(Store, Terms);
      end;
      Distance := WordDistance(Folded, Candidates[I], EditLimit(Folded), Skip);
      Key := Distance * 33 + 32 - Frequency;
      N := Length(Result);
      J := 0;
      while (J < N) and ((Keys[J] < Key) or ((Keys[J] = Key) and ((Lives[J] > Live) or ((Lives[J] = Live) and (Result[J] < Candidates[I]))))) do Inc(J);
      if J >= 5 then Continue;
      Count := N;
      if Count < 5 then Inc(Count);
      SetLength(Result, Count);
      SetLength(Keys, Count);
      SetLength(Lives, Count);
      for N := Count - 1 downto J + 1 do
      begin
        Result[N] := Result[N - 1];
        Keys[N] := Keys[N - 1];
        Lives[N] := Lives[N - 1];
      end;
      Result[J] := Candidates[I];
      Keys[J] := Key;
      Lives[J] := Live;
    end;
  finally
    Terms.Free;
    Candidates.Free;
  end;
end;

// Looks for a word's spelling in the documents the asker may read, giving up after eight were read with their text.
function ReadableSpelling(Store: TFerretStore; Query: TFerretQuery; const Term: string): string;
var
  Blocks: TFerretTermBlocks;
  Docs: TFerretTermDocuments;
  B, D, K, Bit, Reads: integer;
  Included: boolean;
begin
  Result := Term;
  Reads := 0;
  Blocks := Store.TermBlocks(Term);
  for B := 0 to High(Blocks) do
  begin
    Docs := Store.BlockDocuments(Blocks[B]);
    for D := 0 to High(Docs) do
    begin
      Bit := Docs[D].Number mod 128;
      if Blocks[B].Mask[Bit div 32] and (cardinal(1) shl (Bit mod 32)) = 0 then Continue;
      Included := False;
      for K := 0 to High(Docs[D].Fields) do
        if Query.IncludesField(Docs[D].Fields[K].Name) then Included := True;
      if not Included then Continue;
      if (Length(Query.Filters) > 0) or Assigned(Query.OnAllow) then
        if not Query.Allows(Store.DocumentInfo(Docs[D].Number)) then Continue;
      Result := SpellingInDocument(Store, Query, Docs[D], Blocks[B], False);
      // An upper-case OR would be read as the operator when the shown text is searched.
      if (Result <> '') and (Result <> 'OR') then Exit;
      Result := Term;
      Inc(Reads);
      if Reads = 8 then Exit;
    end;
  end;
end;

function CorrectWords(Store: TFerretStore; Query: TFerretQuery; var Parsed: TFerretParsedQuery; out Shown: string): string;
var
  Terms: TStringList;
  Suggestions: TFerretStrings;
  I, J, K, Start, Count: integer;
  Changed: boolean;
begin
  Result := Query.Text;
  Shown := Query.Text;
  Changed := False;
  Terms := TStringList.Create;
  try
    // Replacing from the end keeps the parser's source offsets valid.
    for I := High(Parsed.Clauses) downto 0 do
      if not Parsed.Clauses[I].Phrase and not Parsed.Clauses[I].Negative then
        for J := High(Parsed.Clauses[I].Words) downto 0 do
          with Parsed.Clauses[I].Words[J] do
          begin
            if (I > 0) and (Parsed.Clauses[I - 1].TextStart = Parsed.Clauses[I].TextStart) then
              if Parsed.Clauses[I - 1].Words[0].ByteStart + Parsed.Clauses[I - 1].Words[0].ByteLength > ByteStart then Continue;
            if (I < High(Parsed.Clauses)) and (Parsed.Clauses[I + 1].TextStart = Parsed.Clauses[I].TextStart) then
              if ByteStart + ByteLength > Parsed.Clauses[I + 1].Words[0].ByteStart then Continue;
            Terms.Clear;
            if Parsed.Clauses[I].Prefix then Store.PrefixTerms(Term, Terms)
            else
              Terms.Add(Term);
            for K := 0 to High(Stems) do Terms.Add(Stems[K]);
            Count := VisibleWordCount(Store, Query, Terms, 3);
            if (Count >= 3) or (Parsed.Clauses[I].Prefix and (Count > 0)) then Continue;
            Suggestions := SuggestWords(Store, Term, Query);
            if Length(Suggestions) = 0 then Continue;
            Correction := Suggestions[0];
            Start := Parsed.Clauses[I].TextStart + ByteStart - 1;
            Delete(Result, Start, ByteLength);
            Insert(Correction, Result, Start);
            Delete(Shown, Start, ByteLength);
            Insert(ReadableSpelling(Store, Query, Correction), Shown, Start);
            Changed := True;
          end;
  finally
    Terms.Free;
  end;
  if not Changed then
  begin
    Result := '';
    Shown := '';
  end;
end;

end.
