unit FerretComplete;

{$mode objfpc}{$H+}
// Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.

interface

uses Classes, SysUtils, FerretTypes, FerretStore;

// Up to Count titles, then up to Count queries.
function CompleteQueries(Store: TFerretStore; const Typed: string; Scope: TFerretQuery; Count: integer): TFerretOffers;

implementation

uses FerretText, FerretQuery, FerretRank, FerretSuggest, FerretSegment;

type
  TCompletion = record
    Text: string;
    Kind, Frequency: integer;
  end;
  TCompletions = array of TCompletion;

  // A title found by how it begins, with its folded text and the document's preference.
  TFoundTitle = record
    Text, Folded, Id: string;
    Factor: double;
  end;
  TFoundTitles = array of TFoundTitle;

function CompareFrequency(List: TStringList; A, B: integer): integer;
begin
  Result := PtrInt(List.Objects[B]) - PtrInt(List.Objects[A]);
  if Result = 0 then Result := CompareStr(List[A], List[B]);
end;

function CompleteQueries(Store: TFerretStore; const Typed: string; Scope: TFerretQuery; Count: integer): TFerretOffers;
var
  Words, Local: TFerretTokens;
  Terms, Vocabulary, Seen, Choices, Permissions, Context: TStringList;
  Offers: TCompletions;
  Titles: TFoundTitles;
  Query: TFerretQuery;
  Parsed: TFerretParsedQuery;
  Ranked: TFerretRankedHits;
  Suggestions: TFerretStrings;
  Blocks: TFerretTermBlocks;
  Docs: TFerretTermDocuments;
  Marked: TFerretPostings;
  Source: TFerretDocument;
  I, J, K, L, N, Total, Frequency, Start, After, Field, Last, Windows: integer;
  Text, Prefix, Base, Candidate, Display, Window, Key, VocabularyPrefix: string;
  Trailing, Match: boolean;
  Best: TCompletion;

  function Prepared(const Value: string; PrefixLast: boolean): TFerretParsedQuery;
  var
    C, W: integer;
  begin
    Result := ParseQuery(Value, PrefixLast);
    if Store.Stemmers = nil then Exit;
    for C := 0 to High(Result.Clauses) do
      for W := 0 to High(Result.Clauses[C].Words) do
        if Result.Clauses[C].Words[W].StemAllowed then
          Result.Clauses[C].Words[W].Stems := Store.Stemmers.Terms(Result.Clauses[C].Words[W].Original, '');
  end;

  procedure Offer(const Value: string; Kind, Frequency: integer);
  var
    Slot: integer;
    Folded: string;
  begin
    if (Value = '') or (Value = Typed) then Exit;
    Folded := FoldText(Value);
    for Slot := 0 to High(Offers) do
      if FoldText(Offers[Slot].Text) = Folded then
      begin
        if Kind > Offers[Slot].Kind then
        begin
          Offers[Slot].Kind := Kind;
          Offers[Slot].Text := Value;
        end;
        if Frequency > Offers[Slot].Frequency then Offers[Slot].Frequency := Frequency;
        Exit;
      end;
    Slot := Length(Offers);
    SetLength(Offers, Slot + 1);
    Offers[Slot].Text := Value;
    Offers[Slot].Kind := Kind;
    Offers[Slot].Frequency := Frequency;
  end;

  function Live(const Doc: TFerretTermDocument; const Block: TFerretTermBlock): boolean;
  var
    B: integer;
  begin
    B := Doc.Number mod 128;
    Result := Block.Mask[B div 32] and (cardinal(1) shl (B mod 32)) <> 0;
  end;

  function Readable(const Doc: TFerretTermDocument; const Block: TFerretTermBlock): boolean;
  var
    F, Slot: integer;
    Key: string;
  begin
    Result := False;
    if not Live(Doc, Block) then Exit;
    for F := 0 to High(Doc.Fields) do
      if Scope.IncludesField(Doc.Fields[F].Name) then Result := True;
    if not Result then Exit;
    if (Length(Scope.Filters) > 0) or Assigned(Scope.OnAllow) then
    begin
      Key := IntToStr(Doc.Number);
      if Permissions.Find(Key, Slot) then Exit(PtrInt(Permissions.Objects[Slot]) = 1);
      Result := Scope.Allows(Store.DocumentInfo(Doc.Number));
      Permissions.AddObject(Key, TObject(PtrInt(Ord(Result))));
    end;
  end;

  function FrequencyOf(const Term: string): integer;
  var
    B, D: integer;
    Parts: TFerretTermBlocks;
    Documents: TFerretTermDocuments;
  begin
    Terms.Clear;
    Terms.Add(Term);
    if (Base = '') and (Length(Scope.Fields) = 0) and (Length(Scope.Filters) = 0) and not Assigned(Scope.OnAllow) then
      Exit(VisibleWordCount(Store, Scope, Terms, MaxInt));
    Result := 0;
    Parts := Store.TermBlocks(Term);
    for B := 0 to High(Parts) do
    begin
      Documents := Store.BlockDocuments(Parts[B]);
      for D := 0 to High(Documents) do
      begin
        if (Base <> '') and (Context.IndexOf(IntToStr(Documents[D].Number)) < 0) then Continue;
        if Readable(Documents[D], Parts[B]) then Inc(Result);
      end;
    end;
  end;

  procedure FindContext;
  var
    W, B, D, F, T, Bit: integer;
    Parts: TFerretTermBlocks;
    Documents: TFerretTermDocuments;
    Next: TStringList;
    Forms: TFerretStrings;
    Included: boolean;
    Number: string;
  begin
    Next := TStringList.Create;
    try
      Next.Sorted := True;
      Next.Duplicates := dupIgnore;
      for W := 0 to Last - 1 do
      begin
        Next.Clear;
        Terms.Clear;
        Terms.Add(Words[W].Term);
        if (Store.Stemmers <> nil) and Words[W].StemAllowed then
        begin
          Forms := Store.Stemmers.Terms(Words[W].Original, '');
          for T := 0 to High(Forms) do Terms.Add(Forms[T]);
        end;
        Parts := Store.WordBlocks(Terms);
        for B := 0 to High(Parts) do
        begin
          Documents := Store.BlockDocuments(Parts[B]);
          for D := 0 to High(Documents) do
          begin
            Bit := Documents[D].Number mod 128;
            if Parts[B].Mask[Bit div 32] and (cardinal(1) shl (Bit mod 32)) = 0 then Continue;
            Number := IntToStr(Documents[D].Number);
            if (W > 0) and (Context.IndexOf(Number) < 0) then Continue;
            Included := False;
            for F := 0 to High(Documents[D].Fields) do
              if Scope.IncludesField(Documents[D].Fields[F].Name) then Included := True;
            if Included then Next.Add(Number);
          end;
        end;
        Context.Assign(Next);
        if Context.Count = 0 then Break;
      end;
    finally
      Next.Free;
    end;
  end;

  function WordDisplay(const Term: string): string;
  var
    B, D: integer;
  begin
    Result := '';
    Blocks := Store.TermBlocks(Term);
    for B := 0 to High(Blocks) do
    begin
      Docs := Store.BlockDocuments(Blocks[B]);
      for D := 0 to High(Docs) do
      begin
        if (Base <> '') and (Context.IndexOf(IntToStr(Docs[D].Number)) < 0) then Continue;
        if not Readable(Docs[D], Blocks[B]) then Continue;
        Result := SpellingInDocument(Store, Scope, Docs[D], Blocks[B], True);
        if Result <> '' then Exit;
      end;
    end;
  end;

  // Titles that begin with the typed text, then titles where a later word begins with it, shortest first.
  // Each class stops at 64 readable documents or 512 examined, so a scope that hides most costs a bounded number of checks.
  procedure FindTitles(const Typed: string);
  var
    List: TStringList;
    Info: TFerretDocument;
    Found: TFoundTitle;
    C, T, B, D, F, N, First, Kept, Examined: integer;
    Lead: string;
  begin
    if Typed = '' then Exit;
    List := TStringList.Create;
    try
      for C := 0 to 1 do
      begin
        Lead := #2 + 'Tt'[C + 1] + ':' + Typed;
        Store.ShortestTerms(Lead, 512, List);
        First := Length(Titles);
        Kept := 0;
        Examined := 0;
        for T := 0 to List.Count - 1 do
        begin
          if (Kept >= 64) or (Examined >= 512) then Break;
          // After a space the typed words are whole.
          if Trailing and (Length(List[T]) > Length(Lead)) and (List[T][Length(Lead) + 1] <> ' ') then Continue;
          Blocks := Store.TermBlocks(List[T]);
          for B := 0 to High(Blocks) do
          begin
            Docs := Store.BlockDocuments(Blocks[B]);
            for D := 0 to High(Docs) do
            begin
              if (Kept >= 64) or (Examined >= 512) or not Live(Docs[D], Blocks[B]) then Continue;
              Inc(Examined);
              if not Readable(Docs[D], Blocks[B]) then Continue;
              Inc(Kept);
              // The record is a borrowed view: copy from it before another document is read.
              Info := Store.DocumentInfo(Docs[D].Number);
              Found.Text := '';
              for F := 0 to High(Info.Fields) do
                if Info.Fields[F].Name = 'title' then Found.Text := Info.Fields[F].Text;
              if Found.Text = '' then Continue;
              Found.Folded := FoldText(Found.Text);
              Found.Id := Info.Id;
              Found.Factor := Scope.Preference(Info);
              N := 0;
              while (N < Length(Titles)) and (Titles[N].Folded <> Found.Folded) do Inc(N);
              if N < Length(Titles) then
              begin
                // Two documents with one title: the offer names neither.
                if Titles[N].Id <> Found.Id then Titles[N].Id := '';
                Continue;
              end;
              // Preferred documents lead their class; equal ones keep the order they were found in.
              SetLength(Titles, N + 1);
              while (N > First) and (Titles[N - 1].Factor < Found.Factor) do
              begin
                Titles[N] := Titles[N - 1];
                Dec(N);
              end;
              Titles[N] := Found;
            end;
          end;
        end;
      end;
    finally
      List.Free;
    end;
  end;

  function TitleFound(const Folded: string): boolean;
  var
    T: integer;
  begin
    Result := False;
    for T := 0 to High(Titles) do
      if Titles[T].Folded = Folded then Exit(True);
  end;

  procedure Give(const Value, Id: string; Kind: TFerretOfferKind);
  var
    Slot: integer;
  begin
    Slot := Length(Result);
    SetLength(Result, Slot + 1);
    Result[Slot].Text := Value;
    Result[Slot].Kind := Kind;
    Result[Slot].Id := Id;
  end;

begin
  Result := nil;
  Offers := nil;
  Titles := nil;
  UTF8Length(Typed);
  if (Count <= 0) or (Trim(Typed) = '') then Exit;
  // Operators and quotes belong to search; completion handles ordinary words.
  Parsed := ParseQuery(Typed, True);
  if Parsed.Branches <> 1 then Exit;
  for I := 0 to High(Parsed.Clauses) do
    if Parsed.Clauses[I].Negative or Parsed.Clauses[I].Phrase then Exit;
  Words := WholeWords(Typed);
  if Length(Words) = 0 then Exit;
  Last := High(Words);
  Trailing := Words[Last].ByteStart + Words[Last].ByteLength <= Length(Typed);
  Terms := TStringList.Create;
  Vocabulary := TStringList.Create;
  Seen := TStringList.Create;
  Choices := TStringList.Create;
  Permissions := TStringList.Create;
  Context := TStringList.Create;
  Query := TFerretQuery.Create('');
  try
    Seen.Sorted := True;
    Permissions.Sorted := True;
    Context.Sorted := True;
    Query.Fields := Scope.Fields;
    Query.Filters := Scope.Filters;
    Query.OnAllow := Scope.OnAllow;
    Query.Preferences := Scope.Preferences;
    Query.Snippets := False;
    Query.PrefixLast := False;
    Query.PrepareFilters;
    // Correct unknown complete words before finishing the last word.
    Text := '';
    VocabularyPrefix := '';
    for I := 0 to Last do
    begin
      Terms.Clear;
      if (I = Last) and not Trailing then
      begin
        Store.CompletionTerms(Words[I].Term, Vocabulary);
        VocabularyPrefix := Words[I].Term;
        for J := 0 to Vocabulary.Count - 1 do
        begin
          Terms.Clear;
          Terms.Add(Vocabulary[J]);
          if VisibleWordCount(Store, Scope, Terms, 1) > 0 then Break;
        end;
      end
      else
      begin
        Terms.Add(Words[I].Term);
        if (Store.Stemmers <> nil) and Words[I].StemAllowed then
        begin
          Suggestions := Store.Stemmers.Terms(Words[I].Original, '');
          for J := 0 to High(Suggestions) do Terms.Add(Suggestions[J]);
        end;
      end;
      if VisibleWordCount(Store, Scope, Terms, 1) = 0 then
      begin
        // Short input is ambiguous; an edit can otherwise reduce a prefix to one letter.
        if UTF8Length(Words[I].Term) < 3 then Exit;
        Suggestions := SuggestWords(Store, Words[I].Term, Scope);
        if Length(Suggestions) = 0 then Exit;
        if UTF8Length(Suggestions[0]) < 2 then Exit;
        Words[I].Term := Suggestions[0];
        Words[I].Original := Suggestions[0];
      end;
      if Text <> '' then Text := Text + ' ';
      Text := Text + Words[I].Original;
    end;
    FindTitles(TitleKey(Text));
    Base := '';
    for I := 0 to Last - 1 do Base := Base + Words[I].Original + ' ';
    FindContext;
    Prefix := Words[Last].Term;
    if not Trailing then
    begin
      if VocabularyPrefix <> Prefix then
      begin
        Store.CompletionTerms(Prefix, Vocabulary);
      end;
      for I := 0 to Vocabulary.Count - 1 do
      begin
        if (Choices.Count >= Count) and (PtrInt(Vocabulary.Objects[I]) < PtrInt(Choices.Objects[Choices.Count - 1])) then Break;
        Frequency := FrequencyOf(Vocabulary[I]);
        if Frequency = 0 then Continue;
        Choices.AddObject(Vocabulary[I], TObject(PtrInt(Frequency)));
        Choices.CustomSort(@CompareFrequency);
        if Choices.Count > Count then Choices.Delete(Choices.Count - 1);
      end;
      for I := 0 to Choices.Count - 1 do
      begin
        Frequency := PtrInt(Choices.Objects[I]);
        if Frequency = 0 then Break;
        Display := WordDisplay(Choices[I]);
        if Display = '' then Continue;
        Candidate := Base + Display;
        Offer(Candidate, 0, Frequency);
      end;
    end;
    // A bounded result page supplies titles and following words from source spans.
    Ranked := nil;
    if Trailing or (Choices.Count > 0) then
    begin
      Query.Text := Text;
      if not Trailing then Query.Text := Base + Choices[0];
      Query.Limit := 8;
      Query.Snippets := True;
      Parsed := Prepared(Query.Text, False);
      if not Trailing then
        with Parsed.Clauses[High(Parsed.Clauses)].Words[0] do
        begin
          SetLength(Stems, Choices.Count - 1);
          for I := 1 to Choices.Count - 1 do Stems[I - 1] := Choices[I];
        end;
      Ranked := RankDocuments(Store, Query, Parsed, Total);
    end;
    for I := 0 to High(Ranked) do
    begin
      Source := Store.Document(Ranked[I].Number);
      for Field := 0 to High(Source.Fields) do
      begin
        if not Scope.IncludesField(Source.Fields[Field].Name) then Continue;
        Window := Source.Fields[Field].Text;
        if (Source.Fields[Field].Name = 'title') and (UTF8Length(Window) <= 80) then
        begin
          Local := WholeWords(Window);
          for J := 0 to Length(Local) - Length(Words) do
          begin
            Match := True;
            for K := 0 to Last do
              if (K = Last) and not Trailing then
                Match := Match and (Copy(Local[J + K].Term, 1, Length(Prefix)) = Prefix)
              else
                Match := Match and (Local[J + K].Term = Words[K].Term);
            if Match then Offer(Window, 2, 1);
          end;
        end;
      end;
      Seen.Clear;
      Windows := 0;
      Marked := HitMatches(Ranked[I]);
      for J := 0 to High(Marked) do
      begin
        Field := Marked[J].Field;
        Window := Source.Fields[Field].Text;
        Start := Marked[J].ByteStart;
        if (Start < 1) or (Start > Length(Window)) then Continue;
        if FoldText(Copy(Window, Start, Marked[J].ByteLength)) <> Words[0].Term then Continue;
        if (Start > 1) and not WordBoundary(Window[Start - 1]) then Continue;
        Inc(Windows);
        if Windows > 8 then Break;
        After := Start;
        while (After <= Length(Window)) and (After - Start < 512) do
        begin
          Inc(After);
          if (After - Start >= 256) and (Window[After - 1] in [#9, #10, #13, ' ']) then Break;
        end;
        if (After <= Length(Window)) and not (Window[After - 1] in [#9, #10, #13, ' ']) then Continue;
        Local := WholeWords(Copy(Window, Start, After - Start));
        if Length(Local) <= Length(Words) then Continue;
        Match := True;
        for K := 0 to Last do
          if (K = Last) and not Trailing then
            Match := Match and (Copy(Local[K].Term, 1, Length(Prefix)) = Prefix)
          else
            Match := Match and (Local[K].Term = Words[K].Term);
        if not Match then Continue;
        Candidate := '';
        for K := 0 to Last + 1 do
        begin
          if Candidate <> '' then Candidate := Candidate + ' ';
          Candidate := Candidate + Local[K].Original;
        end;
        Key := FoldText(Candidate);
        if Seen.IndexOf(Key) >= 0 then Continue;
        Seen.Add(Key);
        N := -1;
        for L := 0 to High(Offers) do
          if FoldText(Offers[L].Text) = Key then N := L;
        if N >= 0 then Inc(Offers[N].Frequency)
        else
          Offer(Candidate, 1, 1);
      end;
    end;
    for I := 0 to High(Offers) do
      for J := I + 1 to High(Offers) do
        if (Offers[J].Kind > Offers[I].Kind) or ((Offers[J].Kind = Offers[I].Kind) and (Offers[J].Frequency > Offers[I].Frequency)) or
          ((Offers[J].Kind = Offers[I].Kind) and (Offers[J].Frequency = Offers[I].Frequency) and (Offers[J].Text < Offers[I].Text)) then
        begin
          Best := Offers[I];
          Offers[I] := Offers[J];
          Offers[J] := Best;
        end;
    for I := 0 to High(Titles) do
      if I < Count then Give(Titles[I].Text, Titles[I].Id, foTitle);
    // Titles of the best documents follow, then the queries; neither repeats a title already given.
    N := Length(Result);
    for I := 0 to High(Offers) do
      if (Offers[I].Kind = 2) and (N < Count) and not TitleFound(FoldText(Offers[I].Text)) then
      begin
        Give(Offers[I].Text, '', foTitle);
        Inc(N);
      end;
    N := 0;
    for I := 0 to High(Offers) do
      if (Offers[I].Kind < 2) and (N < Count) and not TitleFound(FoldText(Offers[I].Text)) then
      begin
        Give(Offers[I].Text, '', foWords);
        Inc(N);
      end;
  finally
    Query.Free;
    Choices.Free;
    Permissions.Free;
    Context.Free;
    Seen.Free;
    Vocabulary.Free;
    Terms.Free;
  end;
end;

end.
