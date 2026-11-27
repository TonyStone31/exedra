unit FerretRank;

{$mode objfpc}{$H+}
// Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.

interface

uses Classes, SysUtils, Math, FerretTypes, FerretText, FerretQuery, FerretStore, FerretSegment, FerretIO;

type
  TFerretRankedHit = record
    Number: integer;
    Tier: integer;
    Id: string;
    Score: double;
    // The matched postings of each query clause, filled for the hits of the page only.
    Parts: array of TFerretPostings;
  end;
  TFerretRankedHits = array of TFerretRankedHit;

function RankDocuments(Store: TFerretStore; Query: TFerretQuery; const Parsed: TFerretParsedQuery; out Total: integer): TFerretRankedHits;
// Every matched posting of a page hit in position order, each once.
function HitMatches(const Hit: TFerretRankedHit): TFerretPostings;

const
  FerretPrefixLimit = FerretTypes.FerretPrefixLimit;

implementation

const
  LengthNormalization = 0.6;

function ComparePrefix(List: TStringList; A, B: integer): integer;
begin
  Result := Length(List[A]) - Length(List[B]);
  if Result = 0 then Result := CompareStr(List[A], List[B]);
end;

procedure PrefixWords(Store: TFerretStore; const word: string; Terms: TStringList);
begin
  Store.PrefixTerms(word, Terms);
  Terms.CustomSort(@ComparePrefix);
  while Terms.Count > FerretPrefixLimit do Terms.Delete(Terms.Count - 1);
end;

type
  TWordMatches = record
    Items: TFerretPostings;
    Exact, Forms: TFerretPostings;
    DocumentFrequency: integer;
  end;
  TWordMatchList = array of TWordMatches;

  TClauseMatches = record
    Items: TFerretPostings;
    Words: TWordMatchList;
  end;
  TAllMatches = array of TClauseMatches;
  TNumbers = array of integer;

function MergePostings(const A, B: TFerretPostings): TFerretPostings;
var
  I, J, N, Comparison: integer;
begin
  if Length(A) = 0 then Exit(B);
  if Length(B) = 0 then Exit(A);
  Result := nil;
  SetLength(Result, Length(A) + Length(B));
  I := 0;
  J := 0;
  N := 0;
  while (I < Length(A)) or (J < Length(B)) do
  begin
    if I = Length(A) then Comparison := 1
    else if J = Length(B) then Comparison := -1
    else
      Comparison := ComparePosting(A[I], B[J]);
    if Comparison <= 0 then
    begin
      Result[N] := A[I];
      Inc(I);
    end
    else
    begin
      Result[N] := B[J];
      Inc(J);
    end;
    if Comparison = 0 then Inc(J);
    Inc(N);
  end;
  SetLength(Result, N);
end;

function WordPostings(Store: TFerretStore; const word: string; Prefix: boolean): TFerretPostings;
var
  Terms: TStringList;
  I, N: integer;
  Lists: array of TFerretPostings;
  Width, J: integer;
begin
  if not Prefix then Exit(Store.Postings(word));
  Result := nil;
  Terms := TStringList.Create;
  try
    PrefixWords(Store, word, Terms);
    SetLength(Lists, Terms.Count);
    for I := 0 to Terms.Count - 1 do Lists[I] := Store.Postings(Terms[I]);
    // Balanced merges keep a short prefix from repeatedly copying the same postings.
    Width := 1;
    while Width < Length(Lists) do
    begin
      J := 0;
      while J + Width < Length(Lists) do
      begin
        Lists[J] := MergePostings(Lists[J], Lists[J + Width]);
        Lists[J + Width] := nil;
        Inc(J, Width * 2);
      end;
      Width := Width * 2;
    end;
    if Length(Lists) > 0 then Result := Lists[0];
    N := 0;
    for I := 0 to High(Result) do
    begin
      if (N > 0) and (Result[I].Document = Result[N - 1].Document) and (Result[I].Field = Result[N - 1].Field) and (Result[I].Position = Result[N - 1].Position) then
        Result[N - 1] := Result[I]
      else
      begin
        Result[N] := Result[I];
        Inc(N);
      end;
    end;
    SetLength(Result, N);
  finally
    Terms.Free;
  end;
end;

function PositionIndex(const Items: TFerretPostings; Document, Field, Position: integer): integer;
var
  L, H, M: integer;
  Key: TFerretPosting;
begin
  Key := Default(TFerretPosting);
  Key.Document := Document;
  Key.Field := Field;
  Key.Position := Position;
  L := 0;
  H := Length(Items);
  while L < H do
  begin
    M := L + (H - L) div 2;
    if ComparePosting(Items[M], Key) < 0 then L := M + 1
    else
      H := M;
  end;
  Result := -1;
  if (L < Length(Items)) and (Items[L].Document = Document) and (Items[L].Field = Field) and (Items[L].Position = Position) then Result := L;
end;

function ClausePostings(const Words: TWordMatchList; const Clause: TFerretClause): TFerretPostings;
var
  I, J, K, N, Position: integer;
  Item, Last: TFerretPosting;
  Found: boolean;
begin
  Result := nil;
  for I := 0 to High(Words) do
    if Length(Words[I].Items) = 0 then Exit;
  if Length(Words) = 1 then Exit(Words[0].Items);
  SetLength(Result, Length(Words[0].Items));
  N := 0;
  for I := 0 to High(Words[0].Items) do
  begin
    Item := Words[0].Items[I];
    Last := Item;
    Found := True;
    for J := 1 to High(Words) do
    begin
      Position := Last.Position + Last.Span + Clause.Words[J].Position - Clause.Words[J - 1].Position - Clause.Words[J - 1].Span;
      K := PositionIndex(Words[J].Items, Item.Document, Item.Field, Position);
      if K < 0 then
      begin
        Found := False;
        Break;
      end;
      Last := Words[J].Items[K];
    end;
    if Found then
    begin
      Item.Span := Last.Position + Last.Span - Item.Position;
      Item.ByteLength := Last.ByteStart + Last.ByteLength - Item.ByteStart;
      Result[N] := Item;
      Inc(N);
    end;
  end;
  SetLength(Result, N);
end;

function DocumentFrequency(const Items: TFerretPostings): integer;
var
  I, Last: integer;
begin
  Last := -1;
  Result := 0;
  for I := 0 to High(Items) do
    if Items[I].Document <> Last then
    begin
      Inc(Result);
      Last := Items[I].Document;
    end;
end;

function CandidateNumbers(const Matches: TAllMatches; const Parsed: TFerretParsedQuery): TNumbers;
var
  Lists: array of TFerretPostings;
  I, Width, J, Last, N: integer;
begin
  Result := nil;
  SetLength(Lists, Length(Matches));
  for I := 0 to High(Matches) do
    if not Parsed.Clauses[I].Negative then Lists[I] := Matches[I].Items;
  Width := 1;
  while Width < Length(Lists) do
  begin
    J := 0;
    while J + Width < Length(Lists) do
    begin
      Lists[J] := MergePostings(Lists[J], Lists[J + Width]);
      Lists[J + Width] := nil;
      Inc(J, Width * 2);
    end;
    Width := Width * 2;
  end;
  if Length(Lists) = 0 then Exit;
  SetLength(Result, Length(Lists[0]));
  Last := -1;
  N := 0;
  for I := 0 to High(Lists[0]) do
    if Lists[0][I].Document <> Last then
    begin
      Last := Lists[0][I].Document;
      Result[N] := Last;
      Inc(N);
    end;
  SetLength(Result, N);
end;

procedure DocumentRange(const Items: TFerretPostings; Number: integer; out First, After: integer);
var
  L, H, M: integer;
begin
  L := 0;
  H := Length(Items);
  while L < H do
  begin
    M := L + (H - L) div 2;
    if Items[M].Document < Number then L := M + 1
    else
      H := M;
  end;
  First := L;
  while (L < Length(Items)) and (Items[L].Document = Number) do Inc(L);
  After := L;
end;

function FieldMatches(Query: TFerretQuery; const Doc: TFerretDocument; const Items: TFerretPostings; Number: integer): TFerretPostings;
var
  I, First, After, N: integer;
begin
  Result := nil;
  DocumentRange(Items, Number, First, After);
  SetLength(Result, After - First);
  N := 0;
  for I := First to After - 1 do
    if Query.IncludesField(Doc.Fields[Items[I].Field].Name) then
    begin
      Result[N] := Items[I];
      Inc(N);
    end;
  SetLength(Result, N);
end;

// Both rankers round field normalization to the same precision.
function LengthNorm(Store: TFerretStore; const Field: string; WordCount: integer): double;
begin
  Result := 1 - LengthNormalization + LengthNormalization * WordCount / Store.AverageLength(Field);
end;

function BM25F(Store: TFerretStore; const Doc: TFerretDocument; const Items: TFerretPostings; Frequency: integer): double;
var
  I, J, Field, Count: integer;
  TF, IDF: double;
begin
  TF := 0;
  I := 0;
  while I < Length(Items) do
  begin
    Field := Items[I].Field;
    J := I + 1;
    while (J < Length(Items)) and (Items[J].Field = Field) do Inc(J);
    Count := J - I;
    TF := TF + Doc.Fields[Field].Weight * Count / LengthNorm(Store, Doc.Fields[Field].Name, Doc.Fields[Field].WordCount);
    I := J;
  end;
  IDF := Ln(1 + (Store.DocumentCount - Frequency + 0.5) / (Frequency + 0.5));
  Result := IDF * (2.2 * TF) / (1.2 + TF);
end;

function Nearness(const A, B: TFerretPostings): double;
var
  I, J, Gap, Best: integer;
begin
  Result := 0;
  I := 0;
  J := 0;
  Best := MaxInt;
  while (I < Length(A)) and (J < Length(B)) do
  begin
    if A[I].Field < B[J].Field then
    begin
      Inc(I);
      Continue;
    end;
    if B[J].Field < A[I].Field then
    begin
      Inc(J);
      Continue;
    end;
    if A[I].Position < B[J].Position then Gap := B[J].Position - A[I].Position - A[I].Span
    else
      Gap := A[I].Position - B[J].Position - B[J].Span;
    if Gap < 0 then Gap := 0;
    if Gap < Best then Best := Gap;
    if A[I].Position < B[J].Position then Inc(I)
    else
      Inc(J);
  end;
  if Best < MaxInt then Result := 0.2 / (1 + Best);
end;

function ScoreDocument(Store: TFerretStore; Query: TFerretQuery; const Parsed: TFerretParsedQuery; const Matches: TAllMatches; Number: integer;
  out Hit: TFerretRankedHit; Supplied: TFerretDocument = nil; CheckAllow: boolean = True; WantParts: boolean = False): boolean;
var
  Doc: TFerretDocument;
  Local: array of TFerretPostings;
  Scores: array of double;
  I, J, B, Previous, Tier: integer;
  Valid: boolean;
  Score: double;
  WordItems: TFerretPostings;
begin
  Result := False;
  Doc := Supplied;
  if Doc = nil then Doc := Store.DocumentInfo(Number);
  SetLength(Local, Length(Matches));
  SetLength(Scores, Length(Matches));
  for I := 0 to High(Matches) do
    Local[I] := FieldMatches(Query, Doc, Matches[I].Items, Number);
  Hit.Number := Number;
  Hit.Id := Doc.Id;
  Hit.Score := 0;
  Hit.Tier := MaxInt;
  Hit.Parts := nil;
  if WantParts then SetLength(Hit.Parts, Length(Local));
  for B := 0 to Parsed.Branches - 1 do
  begin
    Valid := True;
    for I := 0 to High(Local) do
      if Parsed.Clauses[I].Branch = B then
        if (Length(Local[I]) > 0) = Parsed.Clauses[I].Negative then Valid := False;
    if not Valid then Continue;
    if not Result then
    begin
      if CheckAllow and not Query.Allows(Doc) then Exit;
      Result := True;
    end;
    Score := 0;
    Tier := 0;
    Previous := -1;
    for I := 0 to High(Local) do
      if (Parsed.Clauses[I].Branch = B) and not Parsed.Clauses[I].Negative then
      begin
        Scores[I] := 0;
        for J := 0 to High(Matches[I].Words) do
        begin
          if Length(Matches[I].Words) = 1 then WordItems := Local[I]
          else
            WordItems := FieldMatches(Query, Doc, Matches[I].Words[J].Items, Number);
          Scores[I] := Scores[I] + BM25F(Store, Doc, WordItems, Matches[I].Words[J].DocumentFrequency);
          if (Length(Parsed.Clauses[I].Words[J].Stems) > 0) or (Parsed.Clauses[I].Words[J].Correction <> '') then
            if Length(FieldMatches(Query, Doc, Matches[I].Words[J].Exact, Number)) = 0 then
            begin
              if Length(FieldMatches(Query, Doc, Matches[I].Words[J].Forms, Number)) > 0 then Tier := Max(Tier, 1)
              else
                Tier := 2;
            end;
        end;
        if Parsed.Clauses[I].Phrase then Scores[I] := Scores[I] * 1.5;
        Score := Score + Scores[I];
        if Previous >= 0 then
          Score := Score + Nearness(Local[Previous], Local[I]) * (Scores[Previous] + Scores[I]);
        Previous := I;
        if WantParts then Hit.Parts[I] := Local[I];
      end;
    if (Tier < Hit.Tier) or ((Tier = Hit.Tier) and (Score > Hit.Score)) then
    begin
      Hit.Score := Score;
      Hit.Tier := Tier;
    end;
  end;
  // A preference scales the score of the best branch and leaves the tier alone.
  if Result and (Length(Query.Preferences) > 0) then Hit.Score := Hit.Score * Query.Preference(Doc);
end;

function HitMatches(const Hit: TFerretRankedHit): TFerretPostings;
var
  I: integer;
begin
  Result := nil;
  for I := 0 to High(Hit.Parts) do Result := MergePostings(Result, Hit.Parts[I]);
end;

function Better(const A, B: TFerretRankedHit): boolean;
begin
  if A.Tier <> B.Tier then Exit(A.Tier < B.Tier);
  if A.Score = B.Score then Result := CompareStr(A.Id, B.Id) < 0
  else
    Result := A.Score > B.Score;
end;

procedure SiftDown(var Heap: TFerretRankedHits; Root, Count: integer);
var
  Child: integer;
  Swap: TFerretRankedHit;
begin
  while Root * 2 + 1 < Count do
  begin
    Child := Root * 2 + 1;
    if (Child + 1 < Count) and Better(Heap[Child], Heap[Child + 1]) then Inc(Child);
    if not Better(Heap[Root], Heap[Child]) then Exit;
    Swap := Heap[Root];
    Heap[Root] := Heap[Child];
    Heap[Child] := Swap;
    Root := Child;
  end;
end;

procedure KeepHit(var Heap: TFerretRankedHits; const Hit: TFerretRankedHit; Capacity: integer);
var
  N, Parent: integer;
  Swap: TFerretRankedHit;
begin
  if Capacity = 0 then Exit;
  N := Length(Heap);
  if N = Capacity then
  begin
    if Better(Hit, Heap[0]) then
    begin
      Heap[0] := Hit;
      SiftDown(Heap, 0, N);
    end;
    Exit;
  end;
  SetLength(Heap, N + 1);
  Heap[N] := Hit;
  while N > 0 do
  begin
    Parent := (N - 1) div 2;
    if not Better(Heap[Parent], Heap[N]) then Break;
    Swap := Heap[Parent];
    Heap[Parent] := Heap[N];
    Heap[N] := Swap;
    N := Parent;
  end;
end;

function QueryCapacity(Query: TFerretQuery): integer;
begin
  if (Query.Offset < 0) or (Query.Limit < 0) or (Query.Offset > MaxInt - Query.Limit) then
    raise EFerret.Create('Offset and limit must be nonnegative and fit an integer.');
  if Query.SnippetLength < 1 then raise EFerret.Create('Snippet length must be positive.');
  if Query.Limit = 0 then Result := 0
  else
    Result := Query.Offset + Query.Limit;
end;

procedure PageHits(var Hits: TFerretRankedHits; Query: TFerretQuery);
var
  I: integer;
  Swap: TFerretRankedHit;
begin
  for I := High(Hits) downto 1 do
  begin
    Swap := Hits[0];
    Hits[0] := Hits[I];
    Hits[I] := Swap;
    SiftDown(Hits, 0, I);
  end;
  if Query.Offset >= Length(Hits) then Hits := nil
  else
    Hits := Copy(Hits, Query.Offset, Query.Limit);
end;

function RankPlain(Store: TFerretStore; Query: TFerretQuery; const Parsed: TFerretParsedQuery; out Total: integer): TFerretRankedHits;
var
  Matches: TAllMatches;
  Numbers: TNumbers;
  I, J, K, Capacity: integer;
  Hit: TFerretRankedHit;
begin
  Result := nil;
  Total := 0;
  Capacity := QueryCapacity(Query);
  SetLength(Matches, Length(Parsed.Clauses));
  for I := 0 to High(Matches) do
  begin
    SetLength(Matches[I].Words, Length(Parsed.Clauses[I].Words));
    for J := 0 to High(Matches[I].Words) do
    begin
      Matches[I].Words[J].Items := WordPostings(Store, Parsed.Clauses[I].Words[J].Term, Parsed.Clauses[I].Prefix);
      Matches[I].Words[J].Exact := Matches[I].Words[J].Items;
      for K := 0 to High(Parsed.Clauses[I].Words[J].Stems) do
        Matches[I].Words[J].Items := MergePostings(Matches[I].Words[J].Items, Store.Postings(Parsed.Clauses[I].Words[J].Stems[K]));
      Matches[I].Words[J].Forms := Matches[I].Words[J].Items;
      if Parsed.Clauses[I].Words[J].Correction <> '' then
        Matches[I].Words[J].Items := MergePostings(Matches[I].Words[J].Items, Store.Postings(Parsed.Clauses[I].Words[J].Correction));
      Matches[I].Words[J].DocumentFrequency := DocumentFrequency(Matches[I].Words[J].Items);
    end;
    Matches[I].Items := ClausePostings(Matches[I].Words, Parsed.Clauses[I]);
  end;
  Numbers := CandidateNumbers(Matches, Parsed);
  for I := 0 to High(Numbers) do
    if ScoreDocument(Store, Query, Parsed, Matches, Numbers[I], Hit, nil, True, Query.Snippets or Query.MarkTitle) then
    begin
      Inc(Total);
      KeepHit(Result, Hit, Capacity);
    end;
  PageHits(Result, Query);
end;

type
  TWordSource = class
    Frequencies, Positions: TFerretReadBuffer;
    constructor Create(FileData: TFerretFile);
    destructor Destroy; override;
  end;

  TFastWord = record
    Prefix, Expanded: boolean;
    ExactAfter, FormsAfter: integer;
    Blocks: TFerretTermBlocks;
    Frequency, LoadedRange: integer;
    Docs: TFerretTermDocuments;
    Sources: array of TFerretTermDocuments;
    Readers: array of TFerretReadBuffer;
    Contexts: array of TWordSource;
  end;
  TFastWords = array of TFastWord;

  TFastClause = record
    Words: TFastWords;
  end;
  TFastClauses = array of TFastClause;

constructor TWordSource.Create(FileData: TFerretFile);
begin
  inherited Create;
  Frequencies := TFerretReadBuffer.Create(FileData);
  Positions := TFerretReadBuffer.Create(FileData);
end;

destructor TWordSource.Destroy;
begin
  Frequencies.Free;
  Positions.Free;
  inherited Destroy;
end;

function SummarySlot(const Docs: TFerretTermDocuments; Number: integer): integer;
var
  L, H, M: integer;
begin
  L := 0;
  H := Length(Docs);
  while L < H do
  begin
    M := L + (H - L) div 2;
    if Docs[M].Number < Number then L := M + 1
    else
      H := M;
  end;
  Result := -1;
  if (L < Length(Docs)) and (Docs[L].Number = Number) then Result := L;
end;

function MergeFrequencies(const A, B: TFerretFieldFrequencies): TFerretFieldFrequencies;
var
  I, J, N: integer;
begin
  Result := nil;
  SetLength(Result, Length(A) + Length(B));
  I := 0;
  J := 0;
  N := 0;
  while (I < Length(A)) or (J < Length(B)) do
  begin
    if (J = Length(B)) or ((I < Length(A)) and (A[I].Field < B[J].Field)) then
    begin
      Result[N] := A[I];
      Inc(I);
    end
    else if (I < Length(A)) and (A[I].Field = B[J].Field) then
    begin
      Result[N] := A[I];
      Inc(Result[N].Count, B[J].Count);
      Inc(I);
      Inc(J);
    end
    else
    begin
      Result[N] := B[J];
      Inc(J);
    end;
    Inc(N);
  end;
  SetLength(Result, N);
end;

function MergeSummaries(const A, B: TFerretTermDocuments): TFerretTermDocuments;
var
  I, J, N: integer;
begin
  Result := nil;
  SetLength(Result, Length(A) + Length(B));
  I := 0;
  J := 0;
  N := 0;
  while (I < Length(A)) or (J < Length(B)) do
  begin
    if (J = Length(B)) or ((I < Length(A)) and (A[I].Number < B[J].Number)) then
    begin
      Result[N] := A[I];
      Inc(I);
    end
    else if (I < Length(A)) and (A[I].Number = B[J].Number) then
    begin
      Result[N].Number := A[I].Number;
      Result[N].Fields := MergeFrequencies(A[I].Fields, B[J].Fields);
      Inc(I);
      Inc(J);
    end
    else
    begin
      Result[N] := B[J];
      Inc(J);
    end;
    Inc(N);
  end;
  SetLength(Result, N);
end;

procedure SortBlocks(var Blocks: TFerretTermBlocks; L, H: integer);
var
  I, J, Pivot, Order: integer;
  Swap: TFerretTermBlock;
begin
  if L >= H then Exit;
  I := L;
  J := H;
  Pivot := Blocks[L + (H - L) div 2].Range;
  Order := Blocks[L + (H - L) div 2].Order;
  repeat
    while (Blocks[I].Range < Pivot) or ((Blocks[I].Range = Pivot) and (Blocks[I].Order < Order)) do Inc(I);
    while (Blocks[J].Range > Pivot) or ((Blocks[J].Range = Pivot) and (Blocks[J].Order > Order)) do Dec(J);
    if I <= J then
    begin
      Swap := Blocks[I];
      Blocks[I] := Blocks[J];
      Blocks[J] := Swap;
      Inc(I);
      Dec(J);
    end;
  until I > J;
  if L < J then SortBlocks(Blocks, L, J);
  if I < H then SortBlocks(Blocks, I, H);
end;

function FirstBlock(const word: TFastWord; Range: integer): integer;
var
  L, H, M: integer;
begin
  L := 0;
  H := Length(word.Blocks);
  while L < H do
  begin
    M := L + (H - L) div 2;
    if word.Blocks[M].Range < Range then L := M + 1
    else
      H := M;
  end;
  Result := L;
end;

function WordMask(const word: TFastWord; Range: integer; MaxTier: integer = 2): TFerretDocumentMask;
var
  I, J: integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  I := FirstBlock(word, Range);
  while (I < Length(word.Blocks)) and (word.Blocks[I].Range = Range) do
  begin
    if ((MaxTier >= 1) or (word.Blocks[I].Order < word.ExactAfter)) and ((MaxTier >= 2) or (word.Blocks[I].Order < word.FormsAfter)) then
      for J := 0 to 3 do Result[J] := Result[J] or word.Blocks[I].Mask[J];
    Inc(I);
  end;
end;

function MaskCount(const Mask: TFerretDocumentMask): integer;
var
  I: integer;
  Bits: cardinal;
begin
  Result := 0;
  for I := 0 to 3 do
  begin
    Bits := Mask[I];
    while Bits <> 0 do
    begin
      Bits := Bits and (Bits - 1);
      Inc(Result);
    end;
  end;
end;

function LoadWord(Store: TFerretStore; const Token: TFerretToken; Prefix: boolean): TFastWord;
var
  Terms: TStringList;
  I, Range, Source: integer;

  procedure Append(const Part: TFerretTermBlocks);
  var
    J, N: integer;
  begin
    N := Length(Result.Blocks);
    SetLength(Result.Blocks, N + Length(Part));
    for J := 0 to High(Part) do
    begin
      Result.Blocks[N + J] := Part[J];
      Inc(Result.Blocks[N + J].Source, N);
    end;
  end;

begin
  Result := Default(TFastWord);
  Result.Prefix := Prefix;
  Result.LoadedRange := -1;
  Terms := TStringList.Create;
  try
    if Prefix then PrefixWords(Store, Token.Term, Terms)
    else
      Terms.Add(Token.Term);
    Result.Blocks := Store.WordBlocks(Terms);
    Result.ExactAfter := Length(Result.Blocks);
    for I := 0 to High(Token.Stems) do Append(Store.TermBlocks(Token.Stems[I]));
    Result.FormsAfter := Length(Result.Blocks);
    if Token.Correction <> '' then Append(Store.TermBlocks(Token.Correction));
    Result.Expanded := (Length(Token.Stems) > 0) or (Token.Correction <> '');
    SetLength(Result.Contexts, Length(Result.Blocks));
    for I := 0 to High(Result.Blocks) do
    begin
      Result.Blocks[I].Order := I;
      if Result.Blocks[I].Segment = nil then Continue;
      Source := Result.Blocks[I].Source;
      if Result.Contexts[Source] = nil then Result.Contexts[Source] := TWordSource.Create(Result.Blocks[I].Segment.FileData);
      Result.Blocks[I].Buffer := Result.Contexts[Source].Frequencies;
    end;
    SortBlocks(Result.Blocks, 0, High(Result.Blocks));
    I := 0;
    while I < Length(Result.Blocks) do
    begin
      Range := Result.Blocks[I].Range;
      Inc(Result.Frequency, MaskCount(WordMask(Result, Range)));
      repeat
        Inc(I)
      until (I = Length(Result.Blocks)) or (Result.Blocks[I].Range <> Range);
    end;
  except
    for I := 0 to High(Result.Contexts) do Result.Contexts[I].Free;
    Terms.Free;
    raise;
  end;
  Terms.Free;
end;

procedure ReleaseReaders(var word: TFastWord);
var
  I: integer;
begin
  for I := 0 to High(word.Contexts) do word.Contexts[I].Free;
  word.Contexts := nil;
  word.Readers := nil;
end;

procedure ReleaseClauses(var Clauses: TFastClauses);
var
  I, J: integer;
begin
  for I := 0 to High(Clauses) do
    for J := 0 to High(Clauses[I].Words) do ReleaseReaders(Clauses[I].Words[J]);
end;

procedure LoadRange(Store: TFerretStore; var word: TFastWord; Range: integer);
var
  I, N: integer;
begin
  if word.LoadedRange = Range then Exit;
  word.Readers := nil;
  word.Docs := nil;
  word.Sources := nil;
  I := FirstBlock(word, Range);
  while (I < Length(word.Blocks)) and (word.Blocks[I].Range = Range) do
  begin
    N := Length(word.Sources);
    SetLength(word.Sources, N + 1);
    SetLength(word.Readers, N + 1);
    if word.Blocks[I].Segment <> nil then word.Readers[N] := word.Contexts[word.Blocks[I].Source].Positions;
    word.Sources[N] := Store.BlockDocuments(word.Blocks[I]);
    word.Docs := MergeSummaries(word.Docs, word.Sources[N]);
    Inc(I);
  end;
  word.LoadedRange := Range;
end;

function TierPositions(Store: TFerretStore; const word: TFastWord; Number, Tier: integer): TFerretPostings;
var
  I, J, Slot, N, First, Order: integer;
  Docs: TFerretTermDocuments;
  Part: TFerretPostings;
  Reader: TFerretReadBuffer;
begin
  Result := nil;
  I := FirstBlock(word, Number div 128);
  First := I;
  while (I < Length(word.Blocks)) and (word.Blocks[I].Range = Number div 128) do
  begin
    Order := word.Blocks[I].Order;
    if ((Tier = 0) and (Order >= word.ExactAfter)) or ((Tier = 1) and ((Order < word.ExactAfter) or (Order >= word.FormsAfter))) or
      ((Tier = 2) and (Order < word.FormsAfter)) then
    begin
      Inc(I);
      Continue;
    end;
    Reader := nil;
    if word.LoadedRange = Number div 128 then
    begin
      Docs := word.Sources[I - First];
      Reader := word.Readers[I - First];
    end
    else
      Docs := Store.BlockDocuments(word.Blocks[I]);
    Slot := SummarySlot(Docs, Number);
    if Slot >= 0 then
    begin
      if Docs[Slot].Segment <> nil then Part := Docs[Slot].Segment.Positions(Docs[Slot], Reader)
      else
        Part := Docs[Slot].Pending;
      Result := MergePostings(Result, Part);
    end;
    Inc(I);
  end;
  if not word.Prefix or (Tier <> 0) then Exit;
  Result := Copy(Result);
  N := 0;
  for J := 0 to High(Result) do
  begin
    if (N > 0) and (Result[J].Document = Result[N - 1].Document) and (Result[J].Field = Result[N - 1].Field) and (Result[J].Position = Result[N - 1].Position) then
      Result[N - 1] := Result[J]
    else
    begin
      Result[N] := Result[J];
      Inc(N);
    end;
  end;
  SetLength(Result, N);
end;

function IDF(Store: TFerretStore; const word: TFastWord): double;
begin
  Result := Ln(1 + (Store.DocumentCount - word.Frequency + 0.5) / (word.Frequency + 0.5));
end;

function BlockBound(Store: TFerretStore; Query: TFerretQuery; const word: TFastWord; Range: integer): double;
var
  I, J: integer;
  TF: double;
begin
  TF := 0;
  I := FirstBlock(word, Range);
  while (I < Length(word.Blocks)) and (word.Blocks[I].Range = Range) do
  begin
    // Pending and custom stores may omit bounds; saturation remains a safe limit.
    if Length(word.Blocks[I].Bounds) = 0 then Exit(2.2 * IDF(Store, word));
    for J := 0 to High(word.Blocks[I].Bounds) do
      with word.Blocks[I].Bounds[J] do
        if Query.IncludesField(Name) then
          TF := TF + Frequency / LengthNorm(Store, Name, WordCount);
    Inc(I);
  end;
  Result := IDF(Store, word) * (2.2 * TF) / (1.2 + TF);
end;

function FrequencyScore(Store: TFerretStore; Query: TFerretQuery; const word: TFastWord; Number: integer; out Present: boolean): double;
var
  Slot, I: integer;
  TF: double;
begin
  Result := 0;
  Present := False;
  Slot := SummarySlot(word.Docs, Number);
  if Slot < 0 then Exit;
  TF := 0;
  for I := 0 to High(word.Docs[Slot].Fields) do
    with word.Docs[Slot].Fields[I] do
      if Query.IncludesField(Name) then
      begin
        Present := True;
        TF := TF + Weight * Count / LengthNorm(Store, Name, WordCount);
      end;
  Result := IDF(Store, word) * (2.2 * TF) / (1.2 + TF);
end;

function LocalMatches(Store: TFerretStore; const Clauses: TFastClauses; const Parsed: TFerretParsedQuery; Number: integer; PhrasesOnly: boolean): TAllMatches;
var
  I, J: integer;
begin
  Result := nil;
  SetLength(Result, Length(Clauses));
  for I := 0 to High(Clauses) do
  begin
    if PhrasesOnly and not Parsed.Clauses[I].Phrase then Continue;
    SetLength(Result[I].Words, Length(Clauses[I].Words));
    for J := 0 to High(Clauses[I].Words) do
    begin
      Result[I].Words[J].Exact := TierPositions(Store, Clauses[I].Words[J], Number, 0);
      Result[I].Words[J].Forms := MergePostings(Result[I].Words[J].Exact, TierPositions(Store, Clauses[I].Words[J], Number, 1));
      Result[I].Words[J].Items := MergePostings(Result[I].Words[J].Forms, TierPositions(Store, Clauses[I].Words[J], Number, 2));
      Result[I].Words[J].DocumentFrequency := Clauses[I].Words[J].Frequency;
    end;
    Result[I].Items := ClausePostings(Result[I].Words, Parsed.Clauses[I]);
  end;
end;

function CandidateMask(const Clauses: TFastClauses; const Parsed: TFerretParsedQuery; Range: integer; Subtract: boolean; MaxTier: integer = 2): TFerretDocumentMask;
var
  Branch, ClauseMask, Mask: TFerretDocumentMask;
  B, I, J, K: integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  for B := 0 to Parsed.Branches - 1 do
  begin
    FillChar(Branch, SizeOf(Branch), 255);
    for I := 0 to High(Clauses) do
      if Parsed.Clauses[I].Branch = B then
      begin
        FillChar(ClauseMask, SizeOf(ClauseMask), 255);
        for J := 0 to High(Clauses[I].Words) do
        begin
          if Parsed.Clauses[I].Negative then Mask := WordMask(Clauses[I].Words[J], Range)
          else
            Mask := WordMask(Clauses[I].Words[J], Range, MaxTier);
          for K := 0 to 3 do ClauseMask[K] := ClauseMask[K] and Mask[K];
        end;
        if not Parsed.Clauses[I].Negative then
          for K := 0 to 3 do Branch[K] := Branch[K] and ClauseMask[K]
        else if Subtract and not Parsed.Clauses[I].Phrase then
          for K := 0 to 3 do Branch[K] := Branch[K] and not ClauseMask[K];
      end;
    for K := 0 to 3 do Result[K] := Result[K] or Branch[K];
  end;
end;

function MinimumTier(const Clauses: TFastClauses; const Parsed: TFerretParsedQuery; Range, Bit: integer): integer;
var
  Tier: integer;
  Mask: TFerretDocumentMask;
begin
  for Tier := 0 to 1 do
  begin
    Mask := CandidateMask(Clauses, Parsed, Range, False, Tier);
    if Bit < 0 then
    begin
      if MaskCount(Mask) > 0 then Exit(Tier);
    end
    else if Mask[Bit div 32] and (cardinal(1) shl (Bit mod 32)) <> 0 then Exit(Tier);
  end;
  Result := 2;
end;

function NextRange(const Clauses: TFastClauses; Current: integer): integer;
var
  I, J, K: integer;
begin
  Result := MaxInt;
  for I := 0 to High(Clauses) do
    for J := 0 to High(Clauses[I].Words) do
    begin
      K := FirstBlock(Clauses[I].Words[J], Current + 1);
      if K < Length(Clauses[I].Words[J].Blocks) then
        Result := Min(Result, Clauses[I].Words[J].Blocks[K].Range);
    end;
end;

function UpperScore(const Scores: array of double; const Valid: array of boolean; const Parsed: TFerretParsedQuery): double;
var
  B, I, Previous: integer;
  Score: double;
begin
  Result := 0;
  for B := 0 to Parsed.Branches - 1 do
    if Valid[B] then
    begin
      Score := 0;
      Previous := -1;
      for I := 0 to High(Scores) do
        if (Parsed.Clauses[I].Branch = B) and not Parsed.Clauses[I].Negative then
        begin
          Score := Score + Scores[I];
          if Previous >= 0 then Score := Score + 0.2 * (Scores[Previous] + Scores[I]);
          Previous := I;
        end;
      if Score > Result then Result := Score;
    end;
end;

function BelowHeap(Bound: double; const Heap: TFerretRankedHits; Capacity: integer; Tier: integer = 0): boolean;
begin
  Result := False;
  if (Capacity = 0) or (Length(Heap) <> Capacity) then Exit;
  if Tier <> Heap[0].Tier then Exit(Tier > Heap[0].Tier);
  Result := Bound + Abs(Bound) * 1e-12 < Heap[0].Score;
end;

type
  TBoundedCandidate = record
    Number, Tier: integer;
    Bound: double;
  end;
  TBoundedCandidates = array of TBoundedCandidate;

procedure ClauseScores(Store: TFerretStore; Query: TFerretQuery; const Clauses: TFastClauses; Number: integer; var Scores: array of double; var HasClause: array of boolean);
var
  I, J: integer;
  Present: boolean;
begin
  for I := 0 to High(Clauses) do
  begin
    HasClause[I] := True;
    Scores[I] := 0;
    for J := 0 to High(Clauses[I].Words) do
    begin
      Scores[I] := Scores[I] + FrequencyScore(Store, Query, Clauses[I].Words[J], Number, Present);
      HasClause[I] := HasClause[I] and Present;
    end;
  end;
end;

function ValidBranches(const HasClause: array of boolean; const Parsed: TFerretParsedQuery; var Valid: array of boolean): boolean;
var
  I, B: integer;
begin
  Result := False;
  for B := 0 to High(Valid) do
  begin
    Valid[B] := True;
    for I := 0 to High(HasClause) do
      if (Parsed.Clauses[I].Branch = B) and (HasClause[I] = Parsed.Clauses[I].Negative) then Valid[B] := False;
    Result := Result or Valid[B];
  end;
end;

function CandidateUpper(Store: TFerretStore; Query: TFerretQuery; const Clauses: TFastClauses; const Parsed: TFerretParsedQuery; Number: integer): double;
var
  Scores: array of double;
  HasClause, Valid: array of boolean;
begin
  SetLength(Scores, Length(Clauses));
  SetLength(HasClause, Length(Clauses));
  SetLength(Valid, Parsed.Branches);
  ClauseScores(Store, Query, Clauses, Number, Scores, HasClause);
  ValidBranches(HasClause, Parsed, Valid);
  Result := UpperScore(Scores, Valid, Parsed);
end;

procedure SortCandidates(var Candidates: TBoundedCandidates; L, H: integer);
var
  I, J: integer;
  Pivot: TBoundedCandidate;
  Swap: TBoundedCandidate;
begin
  if L >= H then Exit;
  I := L;
  J := H;
  Pivot := Candidates[L + (H - L) div 2];
  repeat
    while (Candidates[I].Tier < Pivot.Tier) or ((Candidates[I].Tier = Pivot.Tier) and (Candidates[I].Bound > Pivot.Bound)) do Inc(I);
    while (Candidates[J].Tier > Pivot.Tier) or ((Candidates[J].Tier = Pivot.Tier) and (Candidates[J].Bound < Pivot.Bound)) do Dec(J);
    if I <= J then
    begin
      Swap := Candidates[I];
      Candidates[I] := Candidates[J];
      Candidates[J] := Swap;
      Inc(I);
      Dec(J);
    end;
  until I > J;
  if L < J then SortCandidates(Candidates, L, J);
  if I < H then SortCandidates(Candidates, I, H);
end;

function ScoreCandidate(Store: TFerretStore; Query: TFerretQuery; const Clauses: TFastClauses; const Parsed: TFerretParsedQuery; Number: integer;
  Bound, Factor: double; out Hit: TFerretRankedHit): boolean;
var
  Doc: TFerretDocument;
  Local: TAllMatches;
begin
  if (Length(Clauses) = 1) and not Parsed.Clauses[0].Phrase and not Clauses[0].Words[0].Prefix and not Clauses[0].Words[0].Expanded then
  begin
    Doc := Store.DocumentInfo(Number);
    Hit := Default(TFerretRankedHit);
    Hit.Number := Number;
    Hit.Id := Doc.Id;
    Hit.Score := Bound * Factor;
    Exit(True);
  end;
  Local := LocalMatches(Store, Clauses, Parsed, Number, False);
  Doc := Store.DocumentInfo(Number);
  Result := ScoreDocument(Store, Query, Parsed, Local, Number, Hit, Doc, False);
end;

procedure ScoreRange(Store: TFerretStore; Query: TFerretQuery; const Clauses: TFastClauses; const Parsed: TFerretParsedQuery;
  const Mask: TFerretDocumentMask; Range, Capacity: integer; Limit: double; var Heap: TFerretRankedHits);
var
  Candidates: TBoundedCandidates;
  Bit, N, I: integer;
  Factor: double;
  Hit: TFerretRankedHit;
begin
  SetLength(Candidates, MaskCount(Mask));
  N := 0;
  for Bit := 0 to 127 do
    if Mask[Bit div 32] and (cardinal(1) shl (Bit mod 32)) <> 0 then
    begin
      Candidates[N].Number := Range * 128 + Bit;
      Candidates[N].Tier := MinimumTier(Clauses, Parsed, Range, Bit);
      Candidates[N].Bound := CandidateUpper(Store, Query, Clauses, Parsed, Candidates[N].Number);
      Inc(N);
    end;
  // Strong candidates establish a useful threshold before reading positions.
  SortCandidates(Candidates, 0, High(Candidates));
  for I := 0 to High(Candidates) do
  begin
    if BelowHeap(Candidates[I].Bound * Limit, Heap, Capacity, Candidates[I].Tier) then Continue;
    Factor := 1;
    if Length(Query.Preferences) > 0 then
    begin
      // The document's own factor is tested before any position is read.
      Factor := Query.Preference(Store.DocumentInfo(Candidates[I].Number));
      if BelowHeap(Candidates[I].Bound * Factor, Heap, Capacity, Candidates[I].Tier) then Continue;
    end;
    if ScoreCandidate(Store, Query, Clauses, Parsed, Candidates[I].Number, Candidates[I].Bound, Factor, Hit) then KeepHit(Heap, Hit, Capacity);
  end;
end;

function RestrictedCandidate(Store: TFerretStore; Query: TFerretQuery; const Clauses: TFastClauses; const Parsed: TFerretParsedQuery;
  Number: integer; var Scores: array of double; var HasClause, Valid: array of boolean; out Bound, Factor: double): boolean;
var
  Doc: TFerretDocument;
  Local: TAllMatches;
  I: integer;
begin
  ClauseScores(Store, Query, Clauses, Number, Scores, HasClause);
  Local := LocalMatches(Store, Clauses, Parsed, Number, True);
  Doc := Store.DocumentInfo(Number);
  Factor := Query.Preference(Doc);
  for I := 0 to High(Clauses) do
    if Parsed.Clauses[I].Phrase then
    begin
      HasClause[I] := Length(FieldMatches(Query, Doc, Local[I].Items, Number)) > 0;
      Scores[I] := Scores[I] * 1.5;
    end;
  Result := ValidBranches(HasClause, Parsed, Valid) and Query.Allows(Doc);
  if Result then Bound := UpperScore(Scores, Valid, Parsed);
end;

function RankFast(Store: TFerretStore; Query: TFerretQuery; const Parsed: TFerretParsedQuery; out Total: integer): TFerretRankedHits;
var
  Clauses: TFastClauses;
  Scores: array of double;
  HasClause, ValidBranch: array of boolean;
  Local: TAllMatches;
  Hit: TFerretRankedHit;
  I, J, B, Range, Bit, Number, Capacity: integer;
  Mask: TFerretDocumentMask;
  CanSkip: boolean;
  Bound, Factor, Limit: double;
begin
  Result := nil;
  Total := 0;
  Capacity := QueryCapacity(Query);
  Limit := Query.PreferenceLimit;
  SetLength(Clauses, Length(Parsed.Clauses));
  SetLength(Scores, Length(Clauses));
  SetLength(HasClause, Length(Clauses));
  SetLength(ValidBranch, Parsed.Branches);
  CanSkip := (Length(Query.Filters) = 0) and (Length(Query.Fields) = 0) and not Assigned(Query.OnAllow);
  try
    for I := 0 to High(Clauses) do
    begin
      CanSkip := CanSkip and not Parsed.Clauses[I].Phrase;
      SetLength(Clauses[I].Words, Length(Parsed.Clauses[I].Words));
      for J := 0 to High(Clauses[I].Words) do
        Clauses[I].Words[J] := LoadWord(Store, Parsed.Clauses[I].Words[J], Parsed.Clauses[I].Prefix);
    end;
    Range := -1;
    repeat
      Range := NextRange(Clauses, Range);
      if Range = MaxInt then Break;
      Mask := CandidateMask(Clauses, Parsed, Range, Length(Query.Fields) = 0);
      if MaskCount(Mask) = 0 then Continue;
      if CanSkip then
      begin
        Inc(Total, MaskCount(Mask));
        if Capacity = 0 then Continue;
        for B := 0 to High(ValidBranch) do ValidBranch[B] := True;
        for I := 0 to High(Clauses) do
        begin
          Scores[I] := 0;
          for J := 0 to High(Clauses[I].Words) do
            Scores[I] := Scores[I] + BlockBound(Store, Query, Clauses[I].Words[J], Range);
        end;
        if BelowHeap(UpperScore(Scores, ValidBranch, Parsed) * Limit, Result, Capacity, MinimumTier(Clauses, Parsed, Range, -1)) then Continue;
      end;
      for I := 0 to High(Clauses) do
        for J := 0 to High(Clauses[I].Words) do LoadRange(Store, Clauses[I].Words[J], Range);
      if CanSkip then
      begin
        ScoreRange(Store, Query, Clauses, Parsed, Mask, Range, Capacity, Limit, Result);
        Continue;
      end;
      for Bit := 0 to 127 do
      begin
        if Mask[Bit div 32] and (cardinal(1) shl (Bit mod 32)) = 0 then Continue;
        Number := Range * 128 + Bit;
        if not RestrictedCandidate(Store, Query, Clauses, Parsed, Number, Scores, HasClause, ValidBranch, Bound, Factor) then Continue;
        Inc(Total);
        if Capacity = 0 then Continue;
        if BelowHeap(Bound * Factor, Result, Capacity, MinimumTier(Clauses, Parsed, Range, Bit)) then Continue;
        if not ScoreCandidate(Store, Query, Clauses, Parsed, Number, Bound, Factor, Hit) then Continue;
        KeepHit(Result, Hit, Capacity);
      end;
    until False;
    PageHits(Result, Query);
    if Query.Snippets or Query.MarkTitle then
      for I := 0 to High(Result) do
      begin
        Local := LocalMatches(Store, Clauses, Parsed, Result[I].Number, False);
        ScoreDocument(Store, Query, Parsed, Local, Result[I].Number, Hit, nil, False, True);
        Result[I].Parts := Hit.Parts;
      end;
  finally
    ReleaseClauses(Clauses);
  end;

end;

function RelevantClauses(Store: TFerretStore; const Parsed: TFerretParsedQuery): TFerretParsedQuery;
var
  Common, Required: array of boolean;
  Terms: TStringList;
  Blocks: TFerretTermBlocks;
  I, B, K, Frequency, N: integer;
begin
  Result := Parsed;
  N := Store.DocumentCount;
  if N < 8 then Exit;
  SetLength(Common, Length(Parsed.Clauses));
  SetLength(Required, Parsed.Branches);
  Terms := nil;
  try
    for I := 0 to High(Parsed.Clauses) do
      with Parsed.Clauses[I] do
      begin
        if Negative then Continue;
        if not Phrase and not Prefix and (Length(Words) = 1) and Words[0].StemAllowed and (Words[0].Span = 1) and (UTF8Length(Words[0].Term) <= 2) then
        begin
          if Terms = nil then Terms := TStringList.Create;
          Terms.Clear;
          Terms.Add(Words[0].Term);
          Blocks := Store.WordBlocks(Terms);
          Frequency := 0;
          for B := 0 to High(Blocks) do
            for K := 0 to 3 do Inc(Frequency, PopCnt(Blocks[B].Mask[K]));
          Common[I] := Frequency >= (N div 2 + N mod 2);
        end;
        if not Common[I] then Required[Branch] := True;
      end;
    // Keep Boolean branches intact when short words are their only positive clauses.
    Result.Clauses := nil;
    for I := 0 to High(Parsed.Clauses) do
      if not Common[I] or not Required[Parsed.Clauses[I].Branch] then
      begin
        K := Length(Result.Clauses);
        SetLength(Result.Clauses, K + 1);
        Result.Clauses[K] := Parsed.Clauses[I];
      end;
  finally
    Terms.Free;
  end;
end;

function RankDocuments(Store: TFerretStore; Query: TFerretQuery; const Parsed: TFerretParsedQuery; out Total: integer): TFerretRankedHits;
var
  Relevant: TFerretParsedQuery;
begin
  Relevant := RelevantClauses(Store, Parsed);
  if Query.Prune then Result := RankFast(Store, Query, Relevant, Total)
  else
    Result := RankPlain(Store, Query, Relevant, Total);
end;

end.
