unit Ferret;

{$mode objfpc}{$H+}
// Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.

interface

uses Classes, SysUtils, Math, SyncObjs, FerretTypes, FerretStore, FerretStem;

type
  EFerret = FerretTypes.EFerret;
  TFerretDocument = FerretTypes.TFerretDocument;
  TFerretField = FerretTypes.TFerretField;
  TFerretFields = FerretTypes.TFerretFields;
  TFerretFact = FerretTypes.TFerretFact;
  TFerretFacts = FerretTypes.TFerretFacts;
  TFerretFactKind = FerretTypes.TFerretFactKind;
  TFerretQuery = FerretTypes.TFerretQuery;
  TFerretHit = FerretTypes.TFerretHit;
  TFerretHits = FerretTypes.TFerretHits;
  TFerretSearchInfo = FerretTypes.TFerretSearchInfo;
  TFerretStrings = FerretTypes.TFerretStrings;
  TFerretOfferKind = FerretTypes.TFerretOfferKind;
  TFerretOffer = FerretTypes.TFerretOffer;
  TFerretOffers = FerretTypes.TFerretOffers;
  TFerretDocumentEntry = FerretTypes.TFerretDocumentEntry;
  TFerretDocumentList = FerretTypes.TFerretDocumentList;
  TFerretNextDocument = FerretTypes.TFerretNextDocument;
  TFerretRebuildProgress = FerretTypes.TFerretRebuildProgress;
  TFerretAllow = FerretTypes.TFerretAllow;
  TFerretTextProvider = FerretTypes.TFerretTextProvider;

  { The index.  In code: TFerretIndex.Create('') and use it.  On a form: set
    FileName and Active.  Adding or searching opens an index that is not
    open yet, so a program never has to. }
  TFerretIndex = class(TComponent)
  private
    FGuard: TCriticalSection;
    FStore: TFerretStore;
    FFileName: string;
    FWantActive: boolean;
    FStoreText: boolean;
    FMemoryLimit, FCacheLimit: int64;
    FOnText: TFerretTextProvider;
    FLanguages: string;
    FLanguagesSet, FRebuilding: boolean;
    function GetLanguages: string;
    procedure SetLanguages(const Value: string);
    procedure SetStoreText(Value: boolean);
    procedure SetTextProvider(Value: TFerretTextProvider);
    procedure SetCacheLimit(Value: int64);
    function GetActive: boolean;
    function GetCount: integer;
    function GetSizeOnDisk: int64;
    procedure SetMemoryLimit(Value: int64);
    procedure SetActive(Value: boolean);
    procedure SetFileName(const Value: string);
    procedure NeedOpen;
    function BuildReplacement(const NewLanguages: string; UseSavedLanguages: boolean; Next: TFerretNextDocument; Progress: TFerretRebuildProgress; Total: int64): boolean;
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override; overload;
    // An index of this file, open; '' keeps it in memory.
    constructor Create(const AFileName: string); overload;
    // The index owns the supplied store.
    constructor Create(Store: TFerretStore); overload;
    // An untyped nil creates an ownerless component.
    constructor Create(AOwner: Pointer); overload;
    destructor Destroy; override;
    procedure Open;
    procedure Close;
    procedure Commit;
    procedure Optimize;
    procedure Refresh;
    // Next returns an owned document, or nil at the end. False progress cancels.
    function Rebuild(Next: TFerretNextDocument; Progress: TFerretRebuildProgress = nil; Total: int64 = -1): boolean; overload;
    function Rebuild(const NewLanguages: string; Next: TFerretNextDocument; Progress: TFerretRebuildProgress = nil; Total: int64 = -1): boolean; overload;
    // A snapshot in id order; facts are copied only when requested.
    function Documents(WithFacts: boolean = False): TFerretDocumentList;
    function ReadValue(const Key: string): string;
    procedure WriteValue(const Key, Value: string);
    procedure Add(const Id: string; const Fields: array of string); overload;
    procedure Add(Document: TFerretDocument); overload;
    function Remove(const Id: string): boolean;
    function Search(const Text: string): TFerretHits; overload;
    function Search(Query: TFerretQuery): TFerretHits; overload;
    function Search(Query: TFerretQuery; out Total: integer): TFerretHits; overload;
    function Search(Query: TFerretQuery; out Total: integer; out Info: TFerretSearchInfo): TFerretHits; overload;
    // Scope supplies the asker's filters, fields and permission callback.
    function IsKnownWord(const word: string; Scope: TFerretQuery = nil): boolean;
    function SuggestWords(const word: string; Scope: TFerretQuery = nil): TFerretStrings;
    // Whole queries to offer while typing, drawn only from readable documents.
    function Complete(const Typed: string; Scope: TFerretQuery = nil; Count: integer = 8): TFerretStrings;
    // Up to Count titles, then up to Count queries. A title carries its document id when only one readable document has it.
    function Offers(const Typed: string; Scope: TFerretQuery = nil; Count: integer = 8): TFerretOffers;
    property Count: integer read GetCount;
    property SizeOnDisk: int64 read GetSizeOnDisk;
  published
    // Comma-separated language codes for word forms; empty keeps exact words only.
    property Languages: string read GetLanguages write SetLanguages;
    // Where the index is kept; empty keeps it in memory.
    property FileName: string read FFileName write SetFileName;
    // Open or not.  In the designer this is only remembered: nothing is opened there.
    property Active: boolean read GetActive write SetActive default False;
    // Pending bytes before saving a segment; one large document may exceed this limit.
    property MemoryLimit: int64 read FMemoryLimit write SetMemoryLimit default 33554432;
    // Bytes retained for decoded dictionaries, term summaries and position blocks; zero disables caching.
    property CacheLimit: int64 read FCacheLimit write SetCacheLimit default 67108864;
    // Keep source fields for titles and snippets in subsequent additions.
    property StoreText: boolean read FStoreText write SetStoreText default True;
    // Supply the original field text when it was not stored.
    property OnText: TFerretTextProvider read FOnText write SetTextProvider;
  end;

const
  FerretPrefixLimit = FerretTypes.FerretPrefixLimit;
  ffString = FerretTypes.ffString;
  ffInteger = FerretTypes.ffInteger;
  ffDate = FerretTypes.ffDate;
  foTitle = FerretTypes.foTitle;
  foWords = FerretTypes.foWords;

implementation

uses FerretText, FerretQuery, FerretRank, FerretSnip, FerretSuggest, FerretComplete;

constructor TFerretIndex.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FGuard := TCriticalSection.Create;
  FStoreText := True;
  FMemoryLimit := 33554432;
  FCacheLimit := 67108864;
end;

constructor TFerretIndex.Create(const AFileName: string);
begin
  Create(TComponent(nil));
  FFileName := AFileName;
  Open;
end;

constructor TFerretIndex.Create(Store: TFerretStore);
begin
  if Store = nil then raise EFerret.Create('An index needs a store.');
  Create(TComponent(nil));
  FStore := Store;
end;

constructor TFerretIndex.Create(AOwner: Pointer);
begin
  if AOwner <> nil then raise EFerret.Create('Use a component owner or a Ferret store.');
  Create(TComponent(nil));
end;

destructor TFerretIndex.Destroy;
begin
  // Linked workers must finish before the store or its lock is released.
  try
    inherited Destroy;
  finally
    try
      if FGuard <> nil then Close;
    finally
      FGuard.Free;
    end;
  end;
end;

function TFerretIndex.Documents(WithFacts: boolean): TFerretDocumentList;
begin
  FGuard.Acquire;
  try
    NeedOpen;
    Result := nil;
    if FStore <> nil then
    begin
      FStore.Refresh;
      Result := FStore.Documents(WithFacts);
    end;
  finally
    FGuard.Release;
  end;
end;

function TFerretIndex.ReadValue(const Key: string): string;
begin
  FGuard.Acquire;
  try
    NeedOpen;
    Result := '';
    if FStore <> nil then
    begin
      FStore.Refresh;
      Result := FStore.ReadValue(Key);
    end;
  finally
    FGuard.Release;
  end;
end;

procedure TFerretIndex.WriteValue(const Key, Value: string);
begin
  FGuard.Acquire;
  try
    NeedOpen;
    if FStore <> nil then FStore.WriteValue(Key, Value);
  finally
    FGuard.Release;
  end;
end;

procedure TFerretIndex.Open;
begin
  FGuard.Acquire;
  try
    if csDesigning in ComponentState then Exit;
    if FStore <> nil then Exit;
    FStore := TFerretSegmentStore.Create(FFileName);
    try
      if FLanguagesSet then FStore.Languages := FLanguages;
      FStore.SetMemoryLimit(FMemoryLimit);
      FStore.SetCacheLimit(FCacheLimit);
    except
      FreeAndNil(FStore);
      raise;
    end;
  finally
    FGuard.Release;
  end;
end;

procedure TFerretIndex.Close;
begin
  FGuard.Acquire;
  try
    if FRebuilding then raise EFerret.Create('Wait for the rebuild to finish before closing the index.');
    try
      if FStore <> nil then FStore.Commit;
    finally
      FreeAndNil(FStore);
      FWantActive := False;
    end;
  finally
    FGuard.Release;
  end;
end;

procedure TFerretIndex.Commit;
begin
  FGuard.Acquire;
  try
    if FStore <> nil then FStore.Commit;
  finally
    FGuard.Release;
  end;
end;

procedure TFerretIndex.Optimize;
begin
  FGuard.Acquire;
  try
    NeedOpen;
    if FStore <> nil then FStore.Optimize;
  finally
    FGuard.Release;
  end;
end;

procedure TFerretIndex.Refresh;
begin
  FGuard.Acquire;
  try
    NeedOpen;
    if FStore <> nil then FStore.Refresh;
  finally
    FGuard.Release;
  end;
end;

function TFerretIndex.Rebuild(Next: TFerretNextDocument; Progress: TFerretRebuildProgress; Total: int64): boolean;
begin
  Result := BuildReplacement('', True, Next, Progress, Total);
end;

function TFerretIndex.Rebuild(const NewLanguages: string; Next: TFerretNextDocument; Progress: TFerretRebuildProgress; Total: int64): boolean;
begin
  Result := BuildReplacement(NewLanguages, False, Next, Progress, Total);
end;

function TFerretIndex.BuildReplacement(const NewLanguages: string; UseSavedLanguages: boolean; Next: TFerretNextDocument; Progress: TFerretRebuildProgress;
  Total: int64): boolean;
var
  Builder: TFerretIndex;
  Store: TFerretSegmentStore;
  Folder, LanguageList: string;
  Doc: TFerretDocument;
  Done, PendingLimit, CacheBytes: int64;
  KeepText: boolean;
begin
  if not Assigned(Next) then raise EFerret.Create('Rebuild needs a document source.');
  if Total < -1 then raise EFerret.Create('A rebuild total must be nonnegative, or -1 when unknown.');
  FGuard.Acquire;
  try
    if FRebuilding then raise EFerret.Create('A rebuild is already running on this index.');
    NeedOpen;
    if not (FStore is TFerretSegmentStore) then
      raise EFerret.Create('Rebuild needs the built-in segment store.');
    Store := TFerretSegmentStore(FStore);
    Folder := Store.BeginRebuild;
    if UseSavedLanguages then LanguageList := Store.Languages
    else
      LanguageList := NewLanguages;
    PendingLimit := FMemoryLimit;
    CacheBytes := FCacheLimit;
    KeepText := FStoreText;
    FRebuilding := True;
  finally
    FGuard.Release;
  end;
  Builder := nil;
  try
    Builder := TFerretIndex.Create(Folder);
    Builder.Languages := LanguageList;
    Builder.MemoryLimit := PendingLimit;
    Builder.CacheLimit := CacheBytes;
    Builder.StoreText := KeepText;
    Result := False;
    Done := 0;
    if Assigned(Progress) then
      if not Progress(Done, Total) then Exit;
    repeat
      Doc := Next();
      if Doc = nil then Break;
    try
      Builder.Add(Doc);
    finally
      Doc.Free;
    end;
      Inc(Done);
      if Assigned(Progress) then
        if not Progress(Done, Total) then Exit;
    until False;
    Builder.Commit;
    FGuard.Acquire;
    try
      Store.PublishRebuild(TFerretSegmentStore(Builder.FStore));
      FLanguages := Store.Languages;
      FLanguagesSet := False;
    finally
      FGuard.Release;
    end;
    Result := True;
  finally
    try
      // A staged store has either been published or discarded; do not save it again.
      if Builder <> nil then FreeAndNil(Builder.FStore);
      Builder.Free;
    finally
      FGuard.Acquire;
      try
        FRebuilding := False;
        Store.EndRebuild(Folder);
      finally
        FGuard.Release;
      end;
    end;
  end;
end;

procedure TFerretIndex.SetStoreText(Value: boolean);
begin
  FGuard.Acquire;
  try
    FStoreText := Value;
  finally
    FGuard.Release;
  end;
end;

function TFerretIndex.GetLanguages: string;
begin
  FGuard.Acquire;
  try
    if FStore = nil then Exit(FLanguages);
    FStore.Refresh;
    Result := FStore.Languages;
  finally
    FGuard.Release;
  end;
end;

procedure TFerretIndex.SetLanguages(const Value: string);
var
  Stemmers: TFerretStemmers;
begin
  FGuard.Acquire;
  try
    Stemmers := TFerretStemmers.Create(Value);
    try
      if FStore <> nil then FStore.Languages := Stemmers.Languages;
      FLanguages := Stemmers.Languages;
      FLanguagesSet := True;
    finally
      Stemmers.Free;
    end;
  finally
    FGuard.Release;
  end;
end;

procedure TFerretIndex.SetTextProvider(Value: TFerretTextProvider);
begin
  FGuard.Acquire;
  try
    FOnText := Value;
  finally
    FGuard.Release;
  end;
end;

procedure TFerretIndex.SetCacheLimit(Value: int64);
begin
  if Value < 0 then raise EFerret.Create('Set CacheLimit to zero or a positive byte budget.');
  FGuard.Acquire;
  try
    FCacheLimit := Value;
    if FStore <> nil then FStore.SetCacheLimit(Value);
  finally
    FGuard.Release;
  end;
end;

procedure TFerretIndex.SetMemoryLimit(Value: int64);
begin
  FGuard.Acquire;
  try
    if Value < 65536 then raise EFerret.Create('MemoryLimit must be at least 65536 bytes (64 KB).');
    if FStore <> nil then FStore.SetMemoryLimit(Value);
    FMemoryLimit := Value;
  finally
    FGuard.Release;
  end;
end;

function TFerretIndex.GetSizeOnDisk: int64;
begin
  FGuard.Acquire;
  try
    if FStore = nil then Exit(0);
    Result := FStore.SizeOnDisk;
  finally
    FGuard.Release;
  end;
end;

procedure TFerretIndex.NeedOpen;
begin
  if FStore = nil then Open;
end;

function TFerretIndex.GetActive: boolean;
begin
  FGuard.Acquire;
  try
    // while a form loads, and in the designer, Active is what was asked for
    if (csDesigning in ComponentState) or (csLoading in ComponentState) then
      Result := FWantActive
    else
      Result := FStore <> nil;
  finally
    FGuard.Release;
  end;
end;

procedure TFerretIndex.SetActive(Value: boolean);
begin
  FGuard.Acquire;
  try
    FWantActive := Value;
    if (csDesigning in ComponentState) or (csLoading in ComponentState) then Exit;
    if Value then Open
    else
      Close;
  finally
    FGuard.Release;
  end;
end;

procedure TFerretIndex.SetFileName(const Value: string);
begin
  FGuard.Acquire;
  try
    if Value = FFileName then Exit;
    if FStore <> nil then raise EFerret.Create('Close the index before giving it another file.');
    FFileName := Value;
  finally
    FGuard.Release;
  end;
end;

procedure TFerretIndex.Loaded;
begin
  inherited Loaded;
  if FWantActive and not (csDesigning in ComponentState) then Open;
end;

procedure TFerretIndex.Add(const Id: string; const Fields: array of string);
var
  Doc: TFerretDocument;
  I: integer;
  Weight: double;
begin
  if Odd(Length(Fields)) then raise EFerret.Create('Fields must be name/text pairs.');
  Doc := TFerretDocument.Create(Id);
  try
    I := 0;
    while I < Length(Fields) do
    begin
      Weight := 1;
      if Fields[I] = 'title' then Weight := 3;
      Doc.AddField(Fields[I], Fields[I + 1], Weight);
      Inc(I, 2);
    end;
    Add(Doc);
  finally
    Doc.Free;
  end;
end;

procedure ValidateDocument(Document: TFerretDocument);
var
  I, J: integer;
begin
  if Document = nil then raise EFerret.Create('A document is required.');
  UTF8Length(Document.Id);
  UTF8Length(Document.Language);
  if Document.Id = '' then raise EFerret.Create('A document needs an id.');
  for I := 0 to High(Document.Fields) do
  begin
    UTF8Length(Document.Fields[I].Name);
    if Document.Fields[I].Name = '' then raise EFerret.Create('A field needs a name.');
    if IsNan(Document.Fields[I].Weight) or IsInfinite(Document.Fields[I].Weight) or (Document.Fields[I].Weight <= 0) or (Document.Fields[I].Weight > 1000000) then
      raise EFerret.Create('A field weight must be positive and finite.');
    for J := 0 to I - 1 do
      if Document.Fields[I].Name = Document.Fields[J].Name then
        raise EFerret.Create('Duplicate field: ' + Document.Fields[I].Name);
  end;
  for I := 0 to High(Document.Facts) do
  begin
    UTF8Length(Document.Facts[I].Name);
    if Document.Facts[I].Kind = ffString then UTF8Length(Document.Facts[I].Text);
    if Document.Facts[I].Name = '' then raise EFerret.Create('A fact needs a name.');
    if (Document.Facts[I].Kind = ffDate) and (IsNan(Document.Facts[I].Date) or IsInfinite(Document.Facts[I].Date)) then
      raise EFerret.Create('A date must be finite.');
    for J := 0 to I - 1 do
      if Document.Facts[I].Name = Document.Facts[J].Name then raise EFerret.Create('Duplicate fact.');
  end;
end;

procedure TFerretIndex.Add(Document: TFerretDocument);
begin
  FGuard.Acquire;
  try
    ValidateDocument(Document);
    NeedOpen;
    if FStore = nil then Exit;
    FStore.PutText(Document, FStoreText);
  finally
    FGuard.Release;
  end;
end;

function TFerretIndex.Remove(const Id: string): boolean;
begin
  FGuard.Acquire;
  try
    NeedOpen;
    if FStore = nil then Exit(False);
    Result := FStore.Remove(Id);
  finally
    FGuard.Release;
  end;
end;

function TFerretIndex.GetCount: integer;
begin
  FGuard.Acquire;
  try
    if FStore = nil then Exit(0);
    Result := FStore.DocumentCount;
  finally
    FGuard.Release;
  end;
end;

function TFerretIndex.IsKnownWord(const word: string; Scope: TFerretQuery): boolean;
var
  Terms: TStringList;
  OwnScope: boolean;
begin
  FGuard.Acquire;
  OwnScope := Scope = nil;
  Terms := TStringList.Create;
  try
    if OwnScope then Scope := TFerretQuery.Create('');
    NeedOpen;
    Result := False;
    if FStore = nil then Exit;
    FStore.Refresh;
    Scope.PrepareFilters;
    FStore.BeginQuery;
    try
      if (word = '') or (word[1] < ' ') then Exit;
      Terms.Add(FoldText(word));
      Result := VisibleWordCount(FStore, Scope, Terms, 1) > 0;
    finally
      FStore.EndQuery;
      Scope.ClearPreparedFilters;
    end;
  finally
    if OwnScope then Scope.Free;
    Terms.Free;
    FGuard.Release;
  end;
end;

function TFerretIndex.SuggestWords(const word: string; Scope: TFerretQuery): TFerretStrings;
var
  OwnScope: boolean;
begin
  FGuard.Acquire;
  OwnScope := Scope = nil;
  try
    if OwnScope then Scope := TFerretQuery.Create('');
    NeedOpen;
    Result := nil;
    if FStore = nil then Exit;
    FStore.Refresh;
    Scope.PrepareFilters;
    FStore.BeginQuery;
    try
      Result := FerretSuggest.SuggestWords(FStore, word, Scope);
    finally
      FStore.EndQuery;
      Scope.ClearPreparedFilters;
    end;
  finally
    if OwnScope then Scope.Free;
    FGuard.Release;
  end;
end;

function TFerretIndex.Complete(const Typed: string; Scope: TFerretQuery; Count: integer): TFerretStrings;
var
  All: TFerretOffers;
  I, N, Titles, Words: integer;
begin
  All := Offers(Typed, Scope, Count);
  Titles := 0;
  for I := 0 to High(All) do
    if (All[I].Kind = foTitle) and (All[I].Text <> Typed) then Inc(Titles);
  Words := Length(All) - Titles;
  // Words keep up to half of the places.
  Titles := Min(Titles, Count - Min(Words, Count div 2));
  Result := nil;
  SetLength(Result, Min(Count, Length(All)));
  N := 0;
  for I := 0 to High(All) do
    if (All[I].Text <> Typed) and (N < Count) and ((All[I].Kind = foWords) or (N < Titles)) then
    begin
      Result[N] := All[I].Text;
      Inc(N);
    end;
  SetLength(Result, N);
end;

function TFerretIndex.Offers(const Typed: string; Scope: TFerretQuery; Count: integer): TFerretOffers;
var
  OwnScope: boolean;
begin
  FGuard.Acquire;
  OwnScope := Scope = nil;
  try
    if OwnScope then Scope := TFerretQuery.Create('');
    Result := nil;
    if Count <= 0 then Exit;
    NeedOpen;
    if FStore = nil then Exit;
    FStore.Refresh;
    Scope.PrepareFilters;
    FStore.BeginQuery;
    try
      Result := CompleteQueries(FStore, Typed, Scope, Count);
    finally
      FStore.EndQuery;
      Scope.ClearPreparedFilters;
    end;
  finally
    if OwnScope then Scope.Free;
    FGuard.Release;
  end;
end;

function TFerretIndex.Search(const Text: string): TFerretHits;
var
  Query: TFerretQuery;
begin
  Query := TFerretQuery.Create(Text);
  try
    Result := Search(Query);
  finally
    Query.Free;
  end;
end;

function TFerretIndex.Search(Query: TFerretQuery): TFerretHits;
var
  Total: integer;
begin
  Result := Search(Query, Total);
end;

function TFerretIndex.Search(Query: TFerretQuery; out Total: integer): TFerretHits;
var
  Info: TFerretSearchInfo;
begin
  Result := Search(Query, Total, Info);
end;

function TFerretIndex.Search(Query: TFerretQuery; out Total: integer; out Info: TFerretSearchInfo): TFerretHits;
var
  Parsed: TFerretParsedQuery;
  Suggested: TFerretParsedQuery;
  Scope: TFerretQuery;
  Ranked: TFerretRankedHits;
  I, J, SuggestedTotal: integer;
  Doc: TFerretDocument;
  Corrected, Shown: string;
begin
  FGuard.Acquire;
  try
    Result := nil;
    Total := 0;
    Info := Default(TFerretSearchInfo);
    if Query = nil then raise EFerret.Create('A query is required.');
    if Query.Snippets or Query.MarkTitle then
    begin
      UTF8Length(Query.OpenMarker);
      UTF8Length(Query.CloseMarker);
    end;
    NeedOpen;
    if FStore = nil then Exit;
    FStore.Refresh;
    Query.PrepareFilters;
    FStore.BeginQuery;
    try
      Parsed := ParseQuery(Query.Text, Query.PrefixLast);
      if FStore.Stemmers <> nil then
        for I := 0 to High(Parsed.Clauses) do
          if not Parsed.Clauses[I].Phrase and not Parsed.Clauses[I].Negative then
            for J := 0 to High(Parsed.Clauses[I].Words) do
              if Parsed.Clauses[I].Words[J].StemAllowed then
                Parsed.Clauses[I].Words[J].Stems := FStore.Stemmers.Terms(Parsed.Clauses[I].Words[J].Original, '');
      Corrected := '';
      if Query.CorrectSpelling then Corrected := CorrectWords(FStore, Query, Parsed, Shown);
      Ranked := RankDocuments(FStore, Query, Parsed, Total);
      if Corrected <> '' then
      begin
        Scope := TFerretQuery.Create(Corrected);
        try
          Scope.Fields := Query.Fields;
          Scope.Filters := Query.Filters;
          Scope.OnAllow := Query.OnAllow;
          Scope.Limit := 0;
          Scope.Snippets := False;
          Suggested := ParseQuery(Corrected, Query.PrefixLast);
          for I := 0 to High(Suggested.Clauses) do Suggested.Clauses[I].Prefix := False;
          Scope.PrepareFilters;
          RankDocuments(FStore, Scope, Suggested, SuggestedTotal);
          if SuggestedTotal > 0 then Info.DidYouMean := Shown;
        finally
          Scope.Free;
        end;
      end;
      SetLength(Result, Length(Ranked));
      for I := 0 to High(Ranked) do
      begin
        if Ranked[I].Tier = 2 then Info.ShowingResultsFor := Shown;
        Result[I].Id := Ranked[I].Id;
        Result[I].Score := Ranked[I].Score;
        if Query.Snippets then Doc := FStore.Document(Ranked[I].Number)
        else
          Doc := FStore.DocumentInfo(Ranked[I].Number);
        for J := 0 to High(Doc.Fields) do
          if Doc.Fields[J].Name = 'title' then
          begin
            Result[I].Title := Doc.Fields[J].Text;
            if (Result[I].Title = '') and Assigned(FOnText) then Result[I].Title := FOnText(Doc.Id, 'title');
            if Query.MarkTitle then Result[I].MarkedTitle := MarkText(Result[I].Title, Ranked[I].Parts, J, Query);
          end;
        if Query.Snippets then
          Result[I].Snippet := MakeSnippet(Doc, Ranked[I].Parts, Query, FOnText);
      end;
    finally
      FStore.EndQuery;
      Query.ClearPreparedFilters;
    end;
  finally
    FGuard.Release;
  end;
end;

end.
