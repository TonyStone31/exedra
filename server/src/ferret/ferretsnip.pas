unit FerretSnip;

{$mode objfpc}{$H+}
// Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.

interface

uses SysUtils, FerretTypes, FerretText, FerretStore;

// Parts holds the postings of each query clause in this document.
function MakeSnippet(const Document: TFerretDocument; const Parts: array of TFerretPostings; Query: TFerretQuery; Provider: TFerretTextProvider): string;
// The whole text of one field with its matched words marked.
function MarkText(const Text: string; const Parts: array of TFerretPostings; Field: integer; Query: TFerretQuery): string;

implementation

const
  WhiteSpace = [#9, #10, #11, #12, #13, ' '];

type
  // A display word, or one match while a passage is located: then the character columns hold bytes.
  TWord = record
    First, After, CharFirst, CharAfter, Marks: integer;
    Clauses: QWord;
  end;
  TWords = array of TWord;

  // Words First to Last of a slice of a field's text.
  TPassage = record
    Words: TWords;
    First, Last: integer;
  end;

// A passage is chosen within three quarters of its length, which leaves room for a word on each side.
function CoreLength(Limit: integer): integer;
begin
  Result := Limit - Limit div 4;
end;

// The words of Text from byte First up to After. A run of white space counts as one character.
function DisplayWords(const Text: string; First, After: integer): TWords;
var
  Tokens: TFerretTokens;
  I, J, N, Count, Offset, CharacterCount: integer;
  Token: TFerretToken;
begin
  Result := nil;
  Tokens := SplitText(Copy(Text, First, After - First), Count);
  // Whole identifiers keep a passage from beginning halfway through a name.
  for I := 1 to High(Tokens) do
  begin
    Token := Tokens[I];
    J := I;
    while (J > 0) and (Tokens[J - 1].ByteStart > Token.ByteStart) do
    begin
      Tokens[J] := Tokens[J - 1];
      Dec(J);
    end;
    Tokens[J] := Token;
  end;
  SetLength(Result, Length(Tokens));
  N := 0;
  for I := 0 to High(Tokens) do
  begin
    Offset := Tokens[I].ByteStart + First - 1;
    if (N > 0) and (Offset < Result[N - 1].After) then
    begin
      if Offset + Tokens[I].ByteLength > Result[N - 1].After then
        Result[N - 1].After := Offset + Tokens[I].ByteLength;
    end
    else
    begin
      Result[N].First := Offset;
      Result[N].After := Offset + Tokens[I].ByteLength;
      Inc(N);
    end;
  end;
  SetLength(Result, N);
  Offset := First;
  CharacterCount := 0;
  for I := 0 to High(Result) do
  begin
    while Offset < Result[I].First do
    begin
      if not (Text[Offset] in WhiteSpace) or (Offset = First) or not (Text[Offset - 1] in WhiteSpace) then Inc(CharacterCount);
      NextUTF8(Text, Offset);
    end;
    Result[I].CharFirst := CharacterCount;
    while Offset < Result[I].After do
    begin
      NextUTF8(Text, Offset);
      Inc(CharacterCount);
    end;
    Result[I].CharAfter := CharacterCount;
  end;
end;

procedure MarkWords(var Words: TWords; const Matches: TFerretPostings; Field, Clause: integer);
var
  I, J, First, After: integer;
begin
  J := 0;
  for I := 0 to High(Matches) do
    if Matches[I].Field = Field then
    begin
      First := Matches[I].ByteStart;
      After := First + Matches[I].ByteLength;
      while (J < Length(Words)) and (Words[J].After <= First) do Inc(J);
      while (J < Length(Words)) and (Words[J].First < After) do
      begin
        Inc(Words[J].Marks);
        Words[J].Clauses := Words[J].Clauses or (QWord(1) shl (Clause and 63));
        Inc(J);
      end;
      // Overlapping identifier aliases may refer to the same display word.
      if J > 0 then Dec(J);
    end;
end;

// The matches of every clause in one field, in byte order, each as a marked item measured in bytes.
function MatchSpans(const Parts: array of TFerretPostings; Field: integer): TWords;
var
  Next: array of integer;
  I, N, Best: integer;
begin
  Result := nil;
  Next := nil;
  SetLength(Next, Length(Parts));
  N := 0;
  for I := 0 to High(Parts) do
  begin
    while (Next[I] < Length(Parts[I])) and (Parts[I][Next[I]].Field < Field) do Inc(Next[I]);
    Best := Next[I];
    while (Best < Length(Parts[I])) and (Parts[I][Best].Field = Field) do Inc(Best);
    Inc(N, Best - Next[I]);
  end;
  SetLength(Result, N);
  for N := 0 to High(Result) do
  begin
    Best := -1;
    for I := 0 to High(Parts) do
      if (Next[I] < Length(Parts[I])) and (Parts[I][Next[I]].Field = Field) then
        if (Best < 0) or (Parts[I][Next[I]].ByteStart < Parts[Best][Next[Best]].ByteStart) then Best := I;
    Result[N].First := Parts[Best][Next[Best]].ByteStart;
    Result[N].After := Result[N].First + Parts[Best][Next[Best]].ByteLength;
    Result[N].CharFirst := Result[N].First;
    Result[N].CharAfter := Result[N].After;
    Result[N].Marks := 1;
    Result[N].Clauses := QWord(1) shl (Best and 63);
    Inc(Next[Best]);
  end;
end;

// The earliest run within Limit that holds the most query clauses of Mask, then the most matches of them, from its
// first to its last such item.
procedure BestWindow(const Words: TWords; Limit: integer; Mask: QWord; out First, Last, Kinds, Marks: integer);
var
  Counts: array[0..63] of integer;
  I, J, Sum, Distinct: integer;

  procedure Count(const Item: TWord; Step: integer);
  var
    Bits: QWord;
    B: integer;
  begin
    Bits := Item.Clauses and Mask;
    if Bits = 0 then Exit;
    Inc(Sum, Step * Item.Marks);
    while Bits <> 0 do
    begin
      B := BsfQWord(Bits);
      Bits := Bits and (Bits - 1);
      if Counts[B] = 0 then Inc(Distinct);
      Inc(Counts[B], Step);
      if Counts[B] = 0 then Dec(Distinct);
    end;
  end;

begin
  First := 0;
  Last := -1;
  Kinds := 0;
  Marks := 0;
  FillChar(Counts, SizeOf(Counts), 0);
  J := 0;
  Sum := 0;
  Distinct := 0;
  for I := 0 to High(Words) do
  begin
    while (J < Length(Words)) and ((J = I) or (Words[J].CharAfter - Words[I].CharFirst <= Limit)) do
    begin
      Count(Words[J], 1);
      Inc(J);
    end;
    if (Words[I].Clauses and Mask <> 0) and ((Distinct > Kinds) or ((Distinct = Kinds) and (Sum > Marks))) then
    begin
      First := I;
      Last := J - 1;
      Kinds := Distinct;
      Marks := Sum;
    end;
    Count(Words[I], -1);
  end;
  while (Last > First) and (Words[Last].Clauses and Mask = 0) do Dec(Last);
end;

// The nearest word at or before First that begins the field, a line or a sentence, with the text from it to Last
// within Limit. -1 when there is none. From is the first byte of the slice.
function SentenceStart(const Text: string; const Words: TWords; From, Limit, First, Last: integer): integer;
var
  I, Before: integer;
begin
  Result := First;
  while (Result >= 0) and (Words[Last].CharAfter - Words[Result].CharFirst <= Limit) do
  begin
    if (Result = 0) and (From = 1) then Exit;
    Before := From;
    if Result > 0 then Before := Words[Result - 1].After;
    for I := Before to Words[Result].First - 1 do
      if (Text[I] in [#10, #13]) or ((Text[I] in ['.', '!', '?']) and (Text[I + 1] in WhiteSpace)) then Exit;
    Dec(Result);
  end;
  Result := -1;
end;

// One more plain word on the left, then on the right, in turn, each with the marked words on the way to it.
// A side that no longer fits stops and the other goes on. Left tells whether the left side may grow at all.
procedure Widen(const Words: TWords; Limit: integer; var First, Last: integer; Left: boolean);
var
  Right: boolean;
  K: integer;
begin
  Right := True;
  while Left or Right do
  begin
    K := First - 1;
    while (K > 0) and (Words[K].Marks > 0) do Dec(K);
    Left := Left and (First > 0) and (Words[Last].CharAfter - Words[K].CharFirst <= Limit);
    if Left then First := K;
    K := Last + 1;
    while (K < High(Words)) and (Words[K].Marks > 0) do Inc(K);
    Right := Right and (Last < High(Words)) and (Words[K].CharAfter - Words[First].CharFirst <= Limit);
    if Right then Last := K;
  end;
end;

// Source text as it is shown: a run of white space becomes one space, and SnippetHtml escapes the four HTML characters.
function Shown(const Piece: string; Html: boolean): string;
var
  I: integer;
begin
  Result := '';
  for I := 1 to Length(Piece) do
    if Piece[I] in WhiteSpace then
    begin
      if (I = 1) or not (Piece[I - 1] in WhiteSpace) then Result := Result + ' ';
    end
    else if not Html then Result := Result + Piece[I]
    else
      case Piece[I] of
        '&': Result := Result + '&amp;';
        '<': Result := Result + '&lt;';
        '>': Result := Result + '&gt;';
        '"': Result := Result + '&quot;';
        else
          Result := Result + Piece[I];
      end;
end;

// Words First to Last with their marks. Whole gives the entire text instead.
function Render(const Text: string; const Words: TWords; First, Last: integer; Query: TFerretQuery; Whole: boolean = False): string;
var
  I, Offset: integer;
begin
  Result := '';
  Offset := 1;
  if not Whole then
  begin
    if Last < First then Exit;
    Offset := Words[First].First;
  end;
  for I := First to Last do
  begin
    Result := Result + Shown(Copy(Text, Offset, Words[I].First - Offset), Query.SnippetHtml);
    if Words[I].Marks > 0 then Result := Result + Query.OpenMarker;
    Result := Result + Shown(Copy(Text, Words[I].First, Words[I].After - Words[I].First), Query.SnippetHtml);
    if Words[I].Marks > 0 then Result := Result + Query.CloseMarker;
    Offset := Words[I].After;
  end;
  if Whole then Result := Result + Shown(Copy(Text, Offset, MaxInt), Query.SnippetHtml);
end;

// The passage near bytes First to After of a field, cut from the words of a slice around them and chosen for the
// clauses of Mask. The slice stays within Floor and Ceiling and grows until the text within reach on the left and a
// word on the right are known. It begins at a sentence start when one is within reach. Without a marked word its
// first word leads.
function Passage(const Text: string; const Parts: array of TFerretPostings; Field, First, After, Limit, Floor, Ceiling: integer; Mask: QWord): TPassage;
var
  Margin: int64;
  I, From, Till, Kinds, Marks, Reach, Start: integer;
begin
  Margin := 4 * int64(Limit);
  repeat
    From := Floor;
    if First - Margin > Floor then From := First - Margin;
    if From > Ceiling then From := Ceiling;
    Till := Ceiling;
    if After + Margin < Till then Till := After + Margin;
    if Till < From then Till := From;
    // White space cannot join identifiers, marks, or overlapping pairs.
    while (From > Floor) and not (Text[From - 1] in WhiteSpace) do Dec(From);
    while (Till < Ceiling) and not (Text[Till] in WhiteSpace) do Inc(Till);
    Result.Words := DisplayWords(Text, From, Till);
    for I := 0 to High(Parts) do MarkWords(Result.Words, Parts[I], Field, I);
    BestWindow(Result.Words, CoreLength(Limit), Mask, Result.First, Result.Last, Kinds, Marks);
    if Result.Last < Result.First then Result.Last := Result.First;
    Reach := 0;
    if Length(Result.Words) > 0 then
    begin
      Reach := Result.Words[Result.Last].CharAfter - Result.Words[0].CharFirst;
      Start := SentenceStart(Text, Result.Words, From, Limit, Result.First, Result.Last);
      if Start >= 0 then Result.First := Start;
      Widen(Result.Words, Limit, Result.First, Result.Last, Start < 0);
    end;
    Margin := Margin * 2;
  until ((From = Floor) or ((Result.First > 0) and (Reach > Limit))) and ((Till = Ceiling) or (Result.Last < High(Result.Words)));
  if Length(Result.Words) = 0 then Result.Last := -1;
end;

// The clauses marked in a passage.
function Covered(const Item: TPassage): QWord;
var
  I: integer;
begin
  Result := 0;
  for I := Item.First to Item.Last do Result := Result or Item.Words[I].Clauses;
end;

// Passage X and, unless it is empty, passage Y after it, with the ellipses the text around them asks for.
// Passages that touch are joined by the text between them.
function Joined(const Text: string; const X, Y: TPassage; Query: TFerretQuery): string;
var
  After: integer;
begin
  Result := Render(Text, X.Words, X.First, X.Last, Query);
  if X.First > 0 then Result := '... ' + Result;
  if Length(Y.Words) = 0 then
  begin
    if X.Last < High(X.Words) then Result := Result + ' ...';
    Exit;
  end;
  After := X.Words[X.Last].After;
  if (X.Last < High(X.Words)) and (Y.First > 0) then Result := Result + ' ... '
  else
    Result := Result + Shown(Copy(Text, After, Y.Words[Y.First].First - After), Query.SnippetHtml);
  Result := Result + Render(Text, Y.Words, Y.First, Y.Last, Query);
  if Y.Last < High(Y.Words) then Result := Result + ' ...';
end;

// The snippet of one field whose matches are Spans, the best of them at bytes First to After. From a length of 80,
// when the passage lacks a clause that matches elsewhere in the field, two passages of half the length are shown:
// the best one, and one before or after it chosen for the clauses it lacks.
function FieldSnippet(const Text: string; const Parts: array of TFerretPostings; const Spans: TWords; Field, First, After: integer; Query: TFerretQuery): string;
var
  One, Main: TPassage;
  Pair: array[0..1] of TPassage;
  Sides: array[0..1] of TWords;
  Lead, Tail, Kinds, Marks: array[0..1] of integer;
  All, Missing: QWord;
  I, Half, Start, Stop, Side, Size: integer;
begin
  One := Passage(Text, Parts, Field, First, After, Query.SnippetLength, 1, Length(Text) + 1, High(QWord));
  Result := Joined(Text, One, Default(TPassage), Query);
  All := 0;
  for I := 0 to High(Spans) do All := All or Spans[I].Clauses;
  if (Query.SnippetLength < 80) or (Covered(One) = 0) or (All and not Covered(One) = 0) then Exit;
  Half := Query.SnippetLength div 2;
  BestWindow(Spans, CoreLength(Half), High(QWord), Lead[0], Tail[0], Kinds[0], Marks[0]);
  Main := Passage(Text, Parts, Field, Spans[Lead[0]].First, Spans[Tail[0]].After, Half, 1, Length(Text) + 1, High(QWord));
  Missing := All and not Covered(Main);
  Start := Main.Words[Main.First].First;
  Stop := Main.Words[Main.Last].After;
  // The matches before the main passage and those after it. The earlier side wins a tie.
  I := 0;
  while (I < Length(Spans)) and (Spans[I].First < Start) do Inc(I);
  Sides[0] := Copy(Spans, 0, I);
  while (I < Length(Spans)) and (Spans[I].First < Stop) do Inc(I);
  Sides[1] := Copy(Spans, I, MaxInt);
  for Side := 0 to 1 do BestWindow(Sides[Side], CoreLength(Half), Missing, Lead[Side], Tail[Side], Kinds[Side], Marks[Side]);
  Side := Ord((Kinds[1] > Kinds[0]) or ((Kinds[1] = Kinds[0]) and (Marks[1] > Marks[0])));
  if Kinds[Side] = 0 then Exit;
  First := Sides[Side][Lead[Side]].First;
  After := Sides[Side][Tail[Side]].After;
  Pair[1 - Side] := Main;
  if Side = 0 then Pair[0] := Passage(Text, Parts, Field, First, After, Half, 1, Start, Missing)
  else
    Pair[1] := Passage(Text, Parts, Field, First, After, Half, Stop, Length(Text) + 1, Missing);
  // Two passages are worth half the context only when they show more clauses than the one.
  if (Covered(Pair[Side]) and Missing = 0) or (PopCnt(Covered(Pair[0]) or Covered(Pair[1])) <= PopCnt(Covered(One))) then Exit;
  // Both passages together keep to the length, the text between them included when they touch.
  if (Pair[0].Last < High(Pair[0].Words)) and (Pair[1].First > 0) then
    Size := Pair[0].Words[Pair[0].Last].CharAfter - Pair[0].Words[Pair[0].First].CharFirst + Pair[1].Words[Pair[1].Last].CharAfter - Pair[1].Words[Pair[1].First].CharFirst
  else
  begin
    Start := Pair[0].Words[Pair[0].First].First;
    Size := UTF8Length(Shown(Copy(Text, Start, Pair[1].Words[Pair[1].Last].After - Start), False));
  end;
  if Size <= Query.SnippetLength then Result := Joined(Text, Pair[0], Pair[1], Query);
end;

function FieldText(const Document: TFerretDocument; Field: integer; Provider: TFerretTextProvider): string;
begin
  Result := Document.Fields[Field].Text;
  if (Result = '') and Assigned(Provider) then Result := Provider(Document.Id, Document.Fields[Field].Name);
end;

function MakeSnippet(const Document: TFerretDocument; const Parts: array of TFerretPostings; Query: TFerretQuery; Provider: TFerretTextProvider): string;
var
  Spans, BestSpans: TWords;
  Text, BestText: string;
  Pass, Field, First, Last, Kinds, Marks, BestKinds, BestMarks, BestField, BestFirst, BestAfter: integer;
begin
  Result := '';
  BestField := -1;
  BestKinds := 0;
  BestMarks := 0;
  BestFirst := 0;
  BestAfter := 0;
  BestText := '';
  BestSpans := nil;
  // The title is the source only when no other field gives a passage.
  for Pass := 0 to 1 do
  begin
    for Field := 0 to High(Document.Fields) do
    begin
      if (Document.Fields[Field].Name = 'title') <> (Pass = 1) then Continue;
      Spans := MatchSpans(Parts, Field);
      if Length(Spans) = 0 then Continue;
      Text := FieldText(Document, Field, Provider);
      if Text = '' then Continue;
      BestWindow(Spans, CoreLength(Query.SnippetLength), High(QWord), First, Last, Kinds, Marks);
      if (BestField < 0) or (Kinds > BestKinds) or ((Kinds = BestKinds) and ((Marks > BestMarks) or ((Marks = BestMarks) and
        (Document.Fields[Field].Weight > Document.Fields[BestField].Weight)))) then
      begin
        BestField := Field;
        BestKinds := Kinds;
        BestMarks := Marks;
        BestFirst := Spans[First].First;
        BestAfter := Spans[Last].After;
        BestText := Text;
        BestSpans := Spans;
      end;
    end;
    if (BestField >= 0) or Query.MarkTitle then Break;
  end;
  if BestField >= 0 then Exit(FieldSnippet(BestText, Parts, BestSpans, BestField, BestFirst, BestAfter, Query));
  // A title shown with its own marks leaves the snippet to the start of the first searched field with text.
  if Query.MarkTitle then
    for Field := 0 to High(Document.Fields) do
      if (Document.Fields[Field].Name <> 'title') and Query.IncludesField(Document.Fields[Field].Name) then
      begin
        Text := FieldText(Document, Field, Provider);
        if Text <> '' then Exit(Joined(Text, Passage(Text, [], Field, 1, 1, Query.SnippetLength, 1, Length(Text) + 1, High(QWord)), Default(TPassage), Query));
      end;
end;

function MarkText(const Text: string; const Parts: array of TFerretPostings; Field: integer; Query: TFerretQuery): string;
var
  Words: TWords;
  I: integer;
begin
  Words := DisplayWords(Text, 1, Length(Text) + 1);
  for I := 0 to High(Parts) do MarkWords(Words, Parts[I], Field, I);
  Result := Render(Text, Words, 0, High(Words), Query, True);
end;

end.
