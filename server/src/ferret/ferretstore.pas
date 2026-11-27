unit FerretStore;

{$mode objfpc}{$H+}
// Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.

interface

uses Classes, SysUtils, FerretTypes, FerretText, FerretSegment, FerretCache, FerretStem;

type
  TFerretPosting = FerretSegment.TFerretPosting;
  TFerretPostings = FerretSegment.TFerretPostings;
  TFerretFieldTokens = FerretSegment.TFerretFieldTokens;
  TFerretTermDocuments = FerretSegment.TFerretTermDocuments;
  TFerretTermDocument = FerretSegment.TFerretTermDocument;
  TFerretFieldFrequencies = FerretSegment.TFerretFieldFrequencies;

  TFerretStore = class abstract
  protected
    FLanguages: string;
    procedure SetLanguages(const Value: string); virtual;
  public
    Stemmers: TFerretStemmers;
    destructor Destroy; override;
    property Languages: string read FLanguages write SetLanguages;
    procedure BeginQuery; virtual;
    procedure EndQuery; virtual;
    procedure PutText(const Doc: TFerretDocument; StoreText: boolean); virtual;
    procedure Put(const Doc: TFerretDocument; const Tokens: TFerretFieldTokens); virtual; abstract;
    function Remove(const Id: string): boolean; virtual; abstract;
    // A view lasts until the next document read or mutation.
    function Document(Number: integer): TFerretDocument; virtual; abstract;
    function DocumentInfo(Number: integer): TFerretDocument; virtual;
    function FindDocument(const Id: string): integer; virtual; abstract;
    function Postings(const Term: string): TFerretPostings; virtual; abstract;
    function Summaries(const Term: string): TFerretTermDocuments; virtual;
    function TermBlocks(const Term: string): TFerretTermBlocks; virtual;
    function WordBlocks(Terms: TStrings): TFerretTermBlocks; virtual;
    procedure SetCacheLimit(Bytes: int64); virtual;
    function BlockDocuments(const Block: TFerretTermBlock): TFerretTermDocuments; virtual;
    procedure PrefixTerms(const Prefix: string; Terms: TStrings); virtual; abstract;
    // Descending occurrence bounds, then words; Objects hold the bounds.
    procedure CompletionTerms(const Prefix: string; Terms: TStrings); virtual;
    // The Limit shortest terms that start with Prefix, shortest first.
    procedure ShortestTerms(const Prefix: string; Limit: integer; Terms: TStrings); virtual;
    function FuzzyTerms(const word: string; Limit: integer; Terms: TStrings): integer; virtual;
    function AverageLength(const Field: string): double; virtual; abstract;
    function DocumentCount: integer; virtual; abstract;
    function Documents(WithFacts: boolean): TFerretDocumentList; virtual;
    function ReadValue(const Name: string): string; virtual;
    procedure WriteValue(const Name, Value: string); virtual;
    procedure Commit; virtual;
    procedure Optimize; virtual;
    procedure Refresh; virtual;
    procedure SetMemoryLimit(Bytes: int64); virtual;
    function SizeOnDisk: int64; virtual;
  end;

  TFerretSegmentStore = class(TFerretStore)
  private
    FFolder, FStamp: string;
    FCache, FPageCache: TFerretCache;
    FSegments: TFPList;
    FPending, FLock: TObject;
    FView: TFerretDocument;
    FStatistics, FValues: TStringList;
    FValuesChanged: boolean;
    FNextNumber, FCount: integer;
    FGeneration: QWord;
    FMemoryLimit: int64;
    FFailed: boolean;
    FQueryDepth: integer;
    procedure NeedWriter;
    procedure CleanUnused;
    procedure CleanRebuilds;
    procedure LoadManifest;
    procedure SaveManifest(Segments: TFPList);
    procedure ChangeStatistics(Doc: TFerretDocument; Direction: integer);
    procedure BeginDocument(const Doc: TFerretDocument);
    procedure EndDocument(const Doc: TFerretDocument);
    function IsDeleted(Number: integer): boolean;
    procedure FilterDeleted(var Blocks: TFerretTermBlocks);
    procedure PrefixCounts(const Prefix: string; All: TStringList);
    function NewSegmentName: string;
    function ReadDocument(Number: integer; WithText: boolean): TFerretDocument;
    procedure Merge(First, After: integer);
    procedure AutoMerge;
  public
    function BeginRebuild: string;
    procedure PublishRebuild(Source: TFerretSegmentStore);
    procedure EndRebuild(const Folder: string);
    procedure SetLanguages(const Value: string); override;
    procedure BeginQuery; override;
    procedure EndQuery; override;
    constructor Create(const Folder: string);
    destructor Destroy; override;
    procedure PutText(const Doc: TFerretDocument; StoreText: boolean); override;
    procedure Put(const Doc: TFerretDocument; const Tokens: TFerretFieldTokens); override;
    function Remove(const Id: string): boolean; override;
    function Document(Number: integer): TFerretDocument; override;
    function DocumentInfo(Number: integer): TFerretDocument; override;
    function FindDocument(const Id: string): integer; override;
    function Postings(const Term: string): TFerretPostings; override;
    function Summaries(const Term: string): TFerretTermDocuments; override;
    function TermBlocks(const Term: string): TFerretTermBlocks; override;
    function WordBlocks(Terms: TStrings): TFerretTermBlocks; override;
    procedure SetCacheLimit(Bytes: int64); override;
    procedure PrefixTerms(const Prefix: string; Terms: TStrings); override;
    procedure CompletionTerms(const Prefix: string; Terms: TStrings); override;
    procedure ShortestTerms(const Prefix: string; Limit: integer; Terms: TStrings); override;
    function FuzzyTerms(const word: string; Limit: integer; Terms: TStrings): integer; override;
    function AverageLength(const Field: string): double; override;
    function DocumentCount: integer; override;
    function Documents(WithFacts: boolean): TFerretDocumentList; override;
    function ReadValue(const Name: string): string; override;
    procedure WriteValue(const Name, Value: string); override;
    procedure Commit; override;
    procedure Optimize; override;
    procedure Refresh; override;
    procedure SetMemoryLimit(Bytes: int64); override;
    function SizeOnDisk: int64; override;
  end;

  TFerretMemoryStore = class(TFerretSegmentStore)
  public
    constructor Create;
  end;

function ComparePosting(const A, B: TFerretPosting): integer;

implementation

uses FerretIO, FerretCodec, FerretSpell;

type
  TPendingBlock = record
    First, After, Range, Last, Count: integer;
    Previous: TFerretPosting;
    Mask: TFerretDocumentMask;
  end;

  TPendingTerm = class
    Bytes: TFerretBuffer;
    Previous: TFerretPosting;
    Count, Next, BlockCount: integer;
    Blocks: array of TPendingBlock;
    constructor Create;
    destructor Destroy; override;
  end;

  TPending = class
    Base: integer;
    Documents: array of rawbytestring;
    DocCount: integer;
    Ids, Terms, Dictionary: TStringList;
    Buckets: array of integer;
    Deleted: TFerretNumbers;
    Bytes: int64;
    constructor Create(Number: integer);
    destructor Destroy; override;
    function Term(const Name: string): TPendingTerm;
    procedure Delete(Number: integer);
    function IsDeleted(Number: integer): boolean;
    procedure Add(const Doc: TFerretDocument; const Tokens: TFerretFieldTokens);
    procedure AddTokens(Number, Field: integer; const Tokens: TFerretTokens; PositionOffset, ByteOffset: integer);
    procedure AddDocument(const Doc: TFerretDocument);
    function HasChanges: boolean;
  end;

  TCachedDocument = class(TFerretCacheItem)
    Doc: TFerretDocument;
    destructor Destroy; override;
  end;

  // A word list for a prefix, or the words near a misspelling with the dictionary entries visited.
  TCachedCompletion = class(TFerretCacheItem)
    Terms: TStringList;
    Visited: integer;
    destructor Destroy; override;
  end;

  TFieldStatistics = class
    Words: int64;
    Count: integer;
  end;

destructor TCachedDocument.Destroy;
begin
  Doc.Free;
  inherited Destroy;
end;

destructor TCachedCompletion.Destroy;
begin
  Terms.Free;
  inherited Destroy;
end;

function CompareCompletionBound(List: TStringList; A, B: integer): integer;
begin
  Result := PtrInt(List.Objects[B]) - PtrInt(List.Objects[A]);
  if Result = 0 then Result := CompareStr(List[A], List[B]);
end;

function CompareShortest(List: TStringList; A, B: integer): integer;
begin
  Result := Length(List[A]) - Length(List[B]);
  if Result = 0 then Result := CompareStr(List[A], List[B]);
end;

// The cache takes the list over.
procedure CacheTerms(Cache: TFerretCache; const Key: string; var Terms: TStringList; Visited: integer);
var
  Cached: TCachedCompletion;
  I: integer;
begin
  if Cache.Limit = 0 then Exit;
  Cached := TCachedCompletion.Create;
  Cached.Terms := Terms;
  Terms := nil;
  Cached.Visited := Visited;
  Cached.Bytes := 128 + Cached.Terms.Capacity * 16;
  for I := 0 to Cached.Terms.Count - 1 do Inc(Cached.Bytes, Length(Cached.Terms[I]) + 32);
  Cache.Put(Key, Cached);
end;

function ComparePosting(const A, B: TFerretPosting): integer;
begin
  Result := FerretSegment.ComparePosting(A, B);
end;

destructor TFerretStore.Destroy;
begin
  Stemmers.Free;
  inherited Destroy;
end;

procedure TFerretStore.SetLanguages(const Value: string);
var
  NewStemmers: TFerretStemmers;
begin
  NewStemmers := TFerretStemmers.Create(Value);
  try
    if NewStemmers.Languages = FLanguages then Exit;
    if DocumentCount <> 0 then
      raise EFerret.Create('The language list cannot change while the index has documents. Rebuild the index with the new languages.');
    Stemmers.Free;
    Stemmers := NewStemmers;
    NewStemmers := nil;
    FLanguages := Stemmers.Languages;
  finally
    NewStemmers.Free;
  end;
end;

procedure TFerretSegmentStore.SetLanguages(const Value: string);
var
  Previous: string;
begin
  Refresh;
  if Value = FLanguages then Exit;
  if DocumentCount <> 0 then
    raise EFerret.Create('The language list cannot change while the index has documents. Rebuild the index with the new languages.');
  NeedWriter;
  Previous := FLanguages;
  inherited SetLanguages(Value);
  if FLanguages <> Previous then FValuesChanged := True;
end;

procedure TFerretStore.BeginQuery;
begin
end;

procedure TFerretStore.EndQuery;
begin
end;

procedure TFerretSegmentStore.BeginQuery;
var
  I: integer;
begin
  Inc(FQueryDepth);
  if FQueryDepth <> 1 then Exit;
  try
    for I := 0 to FSegments.Count - 1 do TFerretSegment(FSegments[I]).BeginQuery;
  except
    EndQuery;
    raise;
  end;
end;

procedure TFerretSegmentStore.EndQuery;
var
  I: integer;
begin
  Dec(FQueryDepth);
  if FQueryDepth <> 0 then Exit;
  for I := 0 to FSegments.Count - 1 do TFerretSegment(FSegments[I]).EndQuery;
end;

procedure TFerretStore.PutText(const Doc: TFerretDocument; StoreText: boolean);
var
  Prepared: TFerretDocument;
  Tokens: TFerretFieldTokens;
  I: integer;
begin
  Prepared := Doc.Clone;
  try
    SetLength(Tokens, Length(Prepared.Fields));
    for I := 0 to High(Prepared.Fields) do
    begin
      Tokens[I] := SplitText(Prepared.Fields[I].Text, Prepared.Fields[I].WordCount);
      if Stemmers <> nil then Stemmers.AddTokens(Tokens[I], Prepared.Language);
      if Prepared.Fields[I].Name = 'title' then AddTitleTerms(Prepared.Fields[I].Text, Tokens[I]);
      if not StoreText then Prepared.Fields[I].Text := '';
    end;
    Put(Prepared, Tokens);
  finally
    Prepared.Free;
  end;
end;

function TFerretStore.Documents(WithFacts: boolean): TFerretDocumentList;
begin
  Result := nil;
  raise EFerret.Create('This store cannot list documents. Use the built-in segment store.');
end;

function TFerretStore.ReadValue(const Name: string): string;
begin
  Result := '';
end;

procedure TFerretStore.WriteValue(const Name, Value: string);
begin
  raise EFerret.Create('This store cannot save feeder settings. Use the built-in segment store.');
end;

function PostingSummaries(const Items: TFerretPostings): TFerretTermDocuments;
var
  I, J, K, N, First: integer;
begin
  Result := nil;
  I := 0;
  N := 0;
  while I < Length(Items) do
  begin
    if N = Length(Result) then SetLength(Result, N * 2 + 16);
    Result[N].Number := Items[I].Document;
    First := I;
    while (I < Length(Items)) and (Items[I].Document = Result[N].Number) do Inc(I);
    Result[N].Pending := Copy(Items, First, I - First);
    J := First;
    while J < I do
    begin
      K := Length(Result[N].Fields);
      SetLength(Result[N].Fields, K + 1);
      Result[N].Fields[K].Field := Items[J].Field;
      First := J;
      while (J < I) and (Items[J].Field = Items[First].Field) do Inc(J);
      Result[N].Fields[K].Count := J - First;
    end;
    Inc(N);
  end;
  SetLength(Result, N);
end;

function TFerretStore.Summaries(const Term: string): TFerretTermDocuments;
begin
  Result := PostingSummaries(Postings(Term));
end;

procedure TFerretStore.SetCacheLimit(Bytes: int64);
begin
end;

procedure TFerretStore.Commit;
begin
end;

function TFerretStore.DocumentInfo(Number: integer): TFerretDocument;
begin
  Result := Document(Number);
end;

procedure TFerretStore.Optimize;
begin
  Commit;
end;

procedure TFerretStore.Refresh;
begin
end;

procedure TFerretStore.SetMemoryLimit(Bytes: int64);
begin
end;

function TFerretStore.SizeOnDisk: int64;
begin
  Result := 0;
end;

constructor TPendingTerm.Create;
begin
  inherited Create;
  Bytes := TFerretBuffer.Create;
end;

destructor TPendingTerm.Destroy;
begin
  Bytes.Free;
  inherited Destroy;
end;

constructor TPending.Create(Number: integer);
begin
  inherited Create;
  Base := Number;
  Terms := NewDictionary;
  Terms.Sorted := False;
  Terms.OwnsObjects := True;
  Dictionary := NewDictionary;
  Dictionary.Sorted := False;
  Ids := NewDictionary;
  SetLength(Buckets, 1024);
  Bytes := 4096;
end;

destructor TPending.Destroy;
begin
  Terms.Free;
  Dictionary.Free;
  Ids.Free;
  inherited Destroy;
end;

function TPending.Term(const Name: string): TPendingTerm;
var
  Bucket, I, J: integer;
begin
  Bucket := Checksum(Name) and (Length(Buckets) - 1);
  I := Buckets[Bucket];
  while I <> 0 do
  begin
    Result := TPendingTerm(Terms.Objects[I - 1]);
    if Terms[I - 1] = Name then Exit;
    I := Result.Next;
  end;
  if Terms.Count >= Length(Buckets) * 2 then
  begin
    Inc(Bytes, Length(Buckets) * SizeOf(integer));
    SetLength(Buckets, Length(Buckets) * 2);
    FillChar(Buckets[0], Length(Buckets) * SizeOf(integer), 0);
    for J := 0 to Terms.Count - 1 do
    begin
      Bucket := Checksum(Terms[J]) and (Length(Buckets) - 1);
      TPendingTerm(Terms.Objects[J]).Next := Buckets[Bucket];
      Buckets[Bucket] := J + 1;
    end;
    Bucket := Checksum(Name) and (Length(Buckets) - 1);
  end;
  Result := TPendingTerm.Create;
  Result.Next := Buckets[Bucket];
  Terms.AddObject(Name, Result);
  Dictionary.Sorted := False;
  Dictionary.Add(Name);
  Buckets[Bucket] := Terms.Count;
  Inc(Bytes, Length(Name) + 192);
end;

function NumberSlot(const Numbers: TFerretNumbers; Number: integer): integer;
var
  L, H, M: integer;
begin
  L := 0;
  H := Length(Numbers);
  while L < H do
  begin
    M := L + (H - L) div 2;
    if Numbers[M] < Number then L := M + 1
    else
      H := M;
  end;
  Result := L;
end;

procedure TPending.Delete(Number: integer);
var
  N, I: integer;
begin
  N := NumberSlot(Deleted, Number);
  if (N < Length(Deleted)) and (Deleted[N] = Number) then Exit;
  SetLength(Deleted, Length(Deleted) + 1);
  for I := High(Deleted) downto N + 1 do Deleted[I] := Deleted[I - 1];
  Deleted[N] := Number;
  Inc(Bytes, 8);
end;

function TPending.IsDeleted(Number: integer): boolean;
var
  N: integer;
begin
  N := NumberSlot(Deleted, Number);
  Result := (N < Length(Deleted)) and (Deleted[N] = Number);
end;

function CompareTokenPosition(const A, B: TFerretToken): integer;
begin
  Result := A.Position - B.Position;
  if Result = 0 then Result := A.Span - B.Span;
end;

procedure SortTokenPositions(const Tokens: TFerretTokens; var Slots: TFerretNumbers; L, H: integer);
var
  I, J, Pivot, Swap: integer;
begin
  if L >= H then Exit;
  I := L;
  J := H;
  Pivot := Slots[L + (H - L) div 2];
  repeat
    while CompareTokenPosition(Tokens[Slots[I]], Tokens[Pivot]) < 0 do Inc(I);
    while CompareTokenPosition(Tokens[Slots[J]], Tokens[Pivot]) > 0 do Dec(J);
    if I <= J then
    begin
      Swap := Slots[I];
      Slots[I] := Slots[J];
      Slots[J] := Swap;
      Inc(I);
      Dec(J);
    end;
  until I > J;
  if L < J then SortTokenPositions(Tokens, Slots, L, J);
  if I < H then SortTokenPositions(Tokens, Slots, I, H);
end;

function TokenByte(const Tokens: TFerretTokens; Slot, Depth: integer): integer;
begin
  if Depth > Length(Tokens[Slot].Term) then Result := -1
  else
    Result := Ord(Tokens[Slot].Term[Depth]);
end;

procedure SortTokenSlots(const Tokens: TFerretTokens; var Slots: TFerretNumbers; L, H: integer; Depth: integer = 1);
var
  I, Low, High, Pivot, Value, Swap: integer;
begin
  while L < H do
  begin
    Pivot := TokenByte(Tokens, Slots[L + (H - L) div 2], Depth);
    I := L;
    Low := L;
    High := H;
    while I <= High do
    begin
      Value := TokenByte(Tokens, Slots[I], Depth);
      if Value < Pivot then
      begin
        Swap := Slots[I];
        Slots[I] := Slots[Low];
        Slots[Low] := Swap;
        Inc(Low);
        Inc(I);
      end
      else if Value > Pivot then
      begin
        Swap := Slots[I];
        Slots[I] := Slots[High];
        Slots[High] := Swap;
        Dec(High);
      end
      else
        Inc(I);
    end;
    SortTokenSlots(Tokens, Slots, L, Low - 1, Depth);
    SortTokenSlots(Tokens, Slots, High + 1, H, Depth);
    if Pivot < 0 then
    begin
      SortTokenPositions(Tokens, Slots, Low, High);
      Exit;
    end;
    // Equal prefixes advance without adding a stack frame for each byte.
    L := Low;
    H := High;
    Inc(Depth);
  end;
end;

procedure TPending.AddDocument(const Doc: TFerretDocument);
var
  N, Number: integer;
begin
  if DocCount = Length(Documents) then SetLength(Documents, DocCount * 2 + 16);
  Documents[DocCount] := EncodeDocument(Doc);
  Inc(Bytes, Length(Documents[DocCount]) + Length(Doc.Id) + 128);
  Number := Base + DocCount;
  if Ids.Find(Doc.Id, N) then Ids.Objects[N] := TObject(PtrInt(Number))
  else
    Ids.AddObject(Doc.Id, TObject(PtrInt(Number)));
  Inc(DocCount);
end;

procedure TPending.AddTokens(Number, Field: integer; const Tokens: TFerretTokens; PositionOffset, ByteOffset: integer);
var
  J, K, Before, N, Bit: integer;
  Slots: TFerretNumbers;
  Item: TFerretPosting;
  List: TPendingTerm;
  LastTerm: string;
begin
  Item.Document := Number;
  Item.Field := Field;
  SetLength(Slots, Length(Tokens));
  for J := 0 to High(Slots) do Slots[J] := J;
  SortTokenSlots(Tokens, Slots, 0, High(Slots));
  LastTerm := '';
  List := nil;
  for J := 0 to High(Slots) do
  begin
    K := Slots[J];
    if Tokens[K].Term <> LastTerm then
    begin
      LastTerm := Tokens[K].Term;
      List := Term(LastTerm);
    end;
    Item.Position := Tokens[K].Position + PositionOffset;
    Item.Span := Tokens[K].Span;
    Item.ByteStart := Tokens[K].ByteStart + ByteOffset;
    Item.ByteLength := Tokens[K].ByteLength;
    if (List.Count > 0) and (ComparePosting(Item, List.Previous) = 0) then Continue;
    N := List.BlockCount - 1;
    if (N < 0) or (List.Blocks[N].Range <> Number div 128) then
    begin
      Inc(N);
      if N = Length(List.Blocks) then
      begin
        Before := Length(List.Blocks);
        SetLength(List.Blocks, N * 2 + 1);
        Inc(Bytes, (Length(List.Blocks) - Before) * SizeOf(TPendingBlock));
      end;
      List.Blocks[N].First := List.Bytes.Count;
      List.Blocks[N].Previous := List.Previous;
      List.Blocks[N].Range := Number div 128;
      Inc(List.BlockCount);
    end;
    Bit := Number mod 128;
    with List.Blocks[N] do
    begin
      Mask[Bit div 32] := Mask[Bit div 32] or (cardinal(1) shl (Bit mod 32));
      Last := Number;
      Inc(Count);
    end;
    Before := List.Bytes.Capacity;
    PackPosting(List.Bytes, Item, List.Previous);
    Inc(Bytes, List.Bytes.Capacity - Before);
    Inc(List.Count);
    List.Blocks[N].After := List.Bytes.Count;
  end;
end;

procedure TPending.Add(const Doc: TFerretDocument; const Tokens: TFerretFieldTokens);
var
  I, Number: integer;
begin
  Number := Base + DocCount;
  for I := 0 to High(Tokens) do AddTokens(Number, I, Tokens[I], 0, 0);
  AddDocument(Doc);
end;

function TPending.HasChanges: boolean;
begin
  Result := (DocCount > 0) or (Length(Deleted) > 0);
end;

constructor TFerretSegmentStore.Create(const Folder: string);
begin
  inherited Create;
  if Folder <> '' then FFolder := IncludeTrailingPathDelimiter(ExpandFileName(Folder));
  FCache := TFerretCache.Create;
  FPageCache := TFerretCache.Create;
  SetCacheLimit(67108864);
  FSegments := TFPList.Create;
  FValues := NewDictionary;
  FValues.NameValueSeparator := #0;
  FStatistics := NewDictionary;
  FStatistics.OwnsObjects := True;
  FMemoryLimit := 32 * 1024 * 1024;
  FPending := TPending.Create(0);
  if (Folder <> '') and FileExists(Folder) then
    raise EFerret.Create('FileName must name an index folder. Choose another name or move the existing file.');
  Refresh;
end;

destructor TFerretSegmentStore.Destroy;
var
  I: integer;
begin
  FView.Free;
  FPending.Free;
  if FSegments <> nil then
    for I := 0 to FSegments.Count - 1 do TObject(FSegments[I]).Free;
  FSegments.Free;
  FStatistics.Free;
  FCache.Free;
  FPageCache.Free;
  FValues.Free;
  FLock.Free;
  inherited Destroy;
end;

constructor TFerretMemoryStore.Create;
begin
  inherited Create('');
end;

procedure TFerretSegmentStore.NeedWriter;
begin
  if FFailed then raise EFerret.Create('Saving this index failed. Close and reopen it before making more changes.');
  if (FFolder = '') or (FLock <> nil) then Exit;
  if not ForceDirectories(FFolder) then raise EFerret.Create('Cannot create the index folder. Choose a writable folder.');
  FLock := TFerretFile.Lock(FFolder);
  try
    LoadManifest;
    CleanUnused;
  except
    FreeAndNil(FLock);
    raise;
  end;
end;

function RebuildName(const Name: string): boolean;
var
  Id: TGUID;
begin
  Result := (Length(Name) = 44) and (Copy(Name, 1, 8) = 'rebuild-') and TryStringToGUID('{' + Copy(Name, 9, 36) + '}', Id);
end;

procedure TFerretSegmentStore.EndRebuild(const Folder: string);
var
  Found: TSearchRec;
  Path: string;
begin
  Path := ExcludeTrailingPathDelimiter(Folder);
  if (ExtractFileDir(Path) <> ExcludeTrailingPathDelimiter(FFolder)) or not RebuildName(ExtractFileName(Path)) then
    raise EFerret.Create('This folder is not a rebuild of this index.');
  if FindFirst(Path + DirectorySeparator + '*', faAnyFile, Found) = 0 then
  try
    repeat
      if Found.Attr and faDirectory <> 0 then Continue;
      if not DeleteFile(Path + DirectorySeparator + Found.Name) then
        raise EFerret.Create('Cannot clear a stopped rebuild. Check folder permissions.');
    until FindNext(Found) <> 0;
  finally
    FindClose(Found);
  end;
  if not RemoveDir(Path) then
    raise EFerret.Create('Cannot remove a stopped rebuild folder. Check folder permissions.');
end;

procedure TFerretSegmentStore.CleanRebuilds;
var
  Found: TSearchRec;
  Target: rawbytestring;
begin
  if FindFirst(FFolder + 'rebuild-*', faAnyFile, Found) <> 0 then Exit;
  try
    repeat
      if (Found.Attr and faDirectory <> 0) and RebuildName(Found.Name) and not FileGetSymLinkTarget(FFolder + Found.Name, Target) then
        EndRebuild(FFolder + Found.Name);
    until FindNext(Found) <> 0;
  finally
    FindClose(Found);
  end;
end;

function TFerretSegmentStore.BeginRebuild: string;
var
  Id: TGUID;
begin
  if FFolder = '' then raise EFerret.Create('Rebuild needs a disk index folder.');
  NeedWriter;
  Commit;
  CleanRebuilds;
  if CreateGUID(Id) <> 0 then raise EFerret.Create('Cannot choose a rebuild folder name. Try again.');
  Result := FFolder + 'rebuild-' + Copy(GUIDToString(Id), 2, 36);
  if not CreateDir(Result) then raise EFerret.Create('Cannot create a rebuild folder. Check folder permissions.');
end;

procedure TFerretSegmentStore.PublishRebuild(Source: TFerretSegmentStore);
var
  Folder, Name: string;
  I: integer;
begin
  if (Source = nil) or (Source = Self) then raise EFerret.Create('A separate rebuild store is required.');
  NeedWriter;
  Source.Commit;
  Folder := Source.FFolder;
  if (ExtractFileDir(ExcludeTrailingPathDelimiter(Folder)) <> ExcludeTrailingPathDelimiter(FFolder)) or not
    RebuildName(ExtractFileName(ExcludeTrailingPathDelimiter(Folder))) then
    raise EFerret.Create('This build belongs to another index.');
  try
    for I := 0 to Source.FSegments.Count - 1 do
    begin
      Name := TFerretSegment(Source.FSegments[I]).Name;
      TFerretFile.Replace(Folder + Name, FFolder + Name);
    end;
    Source.FValues.Assign(FValues);
    Source.FFolder := FFolder;
    Source.FGeneration := FGeneration;
    try
      Source.SaveManifest(Source.FSegments);
    finally
      Source.FFolder := Folder;
    end;
    LoadManifest;
    CleanUnused;
  except
    FFailed := True;
    raise;
  end;
end;

procedure TFerretSegmentStore.CleanUnused;
var
  Found: TSearchRec;
  I: integer;
  Keep: boolean;
  Suffix: string;
  Id: TGUID;
begin
  if FindFirst(FFolder + 's-*', faAnyFile, Found) <> 0 then Exit;
  try
    repeat
      if (Found.Attr and faDirectory <> 0) or (Length(Found.Name) < 42) then Continue;
      if not TryStringToGUID('{' + Copy(Found.Name, 3, 36) + '}', Id) then Continue;
      Suffix := Copy(Found.Name, 39, MaxInt);
      if (Suffix <> '.seg') and (Suffix <> '.seg.docs') and (Suffix <> '.seg.ids') and (Suffix <> '.seg.terms') and (Suffix <> '.seg.text') and
        (Suffix <> '.seg.summaries') and (Suffix <> '.seg.manifest') and (Suffix <> '.seg.packed') then
        Continue;
      Keep := False;
      for I := 0 to FSegments.Count - 1 do
        if TFerretSegment(FSegments[I]).Name = Found.Name then Keep := True;
      if not Keep then DeleteFile(FFolder + Found.Name);
    until FindNext(Found) <> 0;
  finally
    FindClose(Found);
  end;
end;

procedure TFerretSegmentStore.LoadManifest;
var
  FileData: TFerretFile;
  D: TFerretDecoder;
  NewSegments: TFPList;
  NewStats, NewValues: TStringList;
  I, N, NextNumber, Count, Version: integer;
  Generation: QWord;
  EndOffset, DeclaredSize: int64;
  Name, Field, StartingStamp: string;
  Stats: TFieldStatistics;
  NewSegment: TFerretSegment;
  NewStemmers: TFerretStemmers;
begin
  if FFolder = '' then Exit;
  if not FileExists(FFolder + 'manifest') then
  begin
    if FStamp <> '' then DamagedIndex;
    Exit;
  end;
  StartingStamp := TFerretFile.Stamp(FFolder + 'manifest');
  FileData := TFerretFile.Create(FFolder + 'manifest');
  NewStemmers := nil;
  NewSegments := TFPList.Create;
  NewValues := NewDictionary;
  NewValues.NameValueSeparator := #0;
  NewStats := NewDictionary;
  NewStats.OwnsObjects := True;
  try
    if FileData.ReadBytes(0, 8) <> 'FERMAN01' then DamagedIndex;
    D.Start(FileData.ReadBytes(8, 4));
    Version := D.Fixed(4);
    if Version <> 4 then CheckVersion(Version);
    D.Start(ReadFrame(FileData, 12, EndOffset));
    if EndOffset <> FileData.Size then DamagedIndex;
    Generation := D.Fixed(8);
    NextNumber := D.Number;
    Count := D.Number;
    if Count > NextNumber then DamagedIndex;
    N := D.Number;
    if N > Length(D.Data) div 10 then DamagedIndex;
    for I := 0 to N - 1 do
    begin
      Name := D.Text;
      if (Name = '') or (ExtractFileName(Name) <> Name) or (Pos('..', Name) > 0) or (Pos('/', Name) > 0) or (Pos('\', Name) > 0) or (Pos(':', Name) > 0) then DamagedIndex;
      DeclaredSize := D.Fixed(8);
      if not FileExists(FFolder + Name) then DamagedIndex;
      NewSegment := TFerretSegment.Create(TFerretFile.Create(FFolder + Name), Name, FCache);
      NewSegment.PageCache := FPageCache;
      NewSegments.Add(NewSegment);
      if NewSegment.FileData.Size <> DeclaredSize then DamagedIndex;
    end;
    N := D.Number;
    if N > Length(D.Data) div 3 then DamagedIndex;
    for I := 0 to N - 1 do
    begin
      Field := D.Text;
      Stats := TFieldStatistics.Create;
      NewStats.AddObject(Field, Stats);
      Stats.Words := D.U;
      Stats.Count := D.Number;
      if (Stats.Words < 0) or (Stats.Count > Count) then DamagedIndex;
    end;
    N := D.Number;
    if N > Length(D.Data) div 2 then DamagedIndex;
    for I := 0 to N - 1 do
    begin
      Name := D.Text;
      NewValues.Values[Name] := D.Text;
    end;
    Name := '';
    if Version >= 4 then Name := D.Text;
    NewStemmers := TFerretStemmers.Create(Name);
    D.Finish;
    if StartingStamp <> TFerretFile.Stamp(FFolder + 'manifest') then
      raise EFerret.Create('The index changed while opening. Try opening it again.');
    FCache.Clear;
    FPageCache.Clear;
    for I := 0 to FSegments.Count - 1 do TObject(FSegments[I]).Free;
    FSegments.Free;
    FSegments := NewSegments;
    NewSegments := nil;
    FStatistics.Free;
    FStatistics := NewStats;
    NewStats := nil;
    FValues.Free;
    FValues := NewValues;
    NewValues := nil;
    Stemmers.Free;
    Stemmers := NewStemmers;
    NewStemmers := nil;
    FLanguages := Stemmers.Languages;
    FValuesChanged := False;
    FNextNumber := NextNumber;
    FCount := Count;
    FGeneration := Generation;
    FPending.Free;
    FPending := TPending.Create(FNextNumber);
    FStamp := StartingStamp;
    FreeAndNil(FView);
  finally
    if NewSegments <> nil then
      for I := 0 to NewSegments.Count - 1 do TObject(NewSegments[I]).Free;
    NewSegments.Free;
    NewStemmers.Free;
    NewStats.Free;
    NewValues.Free;
    FileData.Free;
  end;
end;

procedure TFerretSegmentStore.SaveManifest(Segments: TFPList);
var
  B, Header: TFerretBuffer;
  I: integer;
  Stats: TFieldStatistics;
  FileData: TFerretFile;
  Temp: string;
begin
  if FFolder = '' then
  begin
    FValuesChanged := False;
    Exit;
  end;
  B := TFerretBuffer.Create;
  Header := TFerretBuffer.Create;
  Temp := NewSegmentName + '.manifest';
  try
    B.Fixed(FGeneration + 1, 8);
    B.U(FNextNumber);
    B.U(FCount);
    B.U(Segments.Count);
    for I := 0 to Segments.Count - 1 do
      with TFerretSegment(Segments[I]) do
      begin
        B.Text(Name);
        B.Fixed(FileData.Size, 8);
      end;
    B.U(FStatistics.Count);
    for I := 0 to FStatistics.Count - 1 do
    begin
      Stats := TFieldStatistics(FStatistics.Objects[I]);
      B.Text(FStatistics[I]);
      B.U(Stats.Words);
      B.U(Stats.Count);
    end;
    B.U(FValues.Count);
    for I := 0 to FValues.Count - 1 do
    begin
      B.Text(FValues.Names[I]);
      B.Text(FValues.ValueFromIndex[I]);
    end;
    B.Text(FLanguages);
    FileData := TFerretFile.Create(Temp, True);
    try
      Header.Bytes('FERMAN01', 8);
      Header.Fixed(4, 4);
      FileData.WriteBytes(Header.Data);
      WriteFrame(FileData, B.Data);
      FileData.Sync;
    finally
      FileData.Free;
    end;
    TFerretFile.SyncFolder(FFolder);
    TFerretFile.Replace(Temp, FFolder + 'manifest');
    TFerretFile.SyncFolder(FFolder);
    FValuesChanged := False;
    Inc(FGeneration);
    FStamp := TFerretFile.Stamp(FFolder + 'manifest');
  finally
    Header.Free;
    B.Free;
  end;
end;

function TFerretSegmentStore.NewSegmentName: string;
var
  Id: TGUID;
begin
  if FFolder = '' then Exit('');
  if CreateGUID(Id) <> 0 then raise EFerret.Create('Cannot choose a new index file name. Try saving again.');
  Result := FFolder + 's-' + Copy(GUIDToString(Id), 2, 36) + '.seg';
end;

procedure TFerretSegmentStore.ChangeStatistics(Doc: TFerretDocument; Direction: integer);
var
  I, N: integer;
  Stats: TFieldStatistics;
begin
  for I := 0 to High(Doc.Fields) do
  begin
    if not FStatistics.Find(Doc.Fields[I].Name, N) then
      N := FStatistics.AddObject(Doc.Fields[I].Name, TFieldStatistics.Create);
    Stats := TFieldStatistics(FStatistics.Objects[N]);
    Inc(Stats.Words, Direction * int64(Doc.Fields[I].WordCount));
    Inc(Stats.Count, Direction);
    if Stats.Count = 0 then FStatistics.Delete(N);
  end;
end;

function TFerretSegmentStore.IsDeleted(Number: integer): boolean;
var
  I: integer;
begin
  if TPending(FPending).IsDeleted(Number) then Exit(True);
  for I := FSegments.Count - 1 downto 0 do
    if TFerretSegment(FSegments[I]).Deleted(Number) then Exit(True);
  Result := False;
end;

function TFerretSegmentStore.FindDocument(const Id: string): integer;
var
  I, N: integer;
  Pending: TPending;
begin
  Pending := TPending(FPending);
  if Pending.Ids.Find(Id, N) then
  begin
    Result := PtrInt(Pending.Ids.Objects[N]);
    if IsDeleted(Result) then Result := -1;
    Exit;
  end;
  for I := FSegments.Count - 1 downto 0 do
  begin
    Result := TFerretSegment(FSegments[I]).FindDocument(Id);
    if Result < 0 then Continue;
    if IsDeleted(Result) then Result := -1;
    Exit;
  end;
  Result := -1;
end;

function TFerretSegmentStore.Documents(WithFacts: boolean): TFerretDocumentList;
var
  I, N, J, Number: integer;
  Cursor: TFerretDictionaryCursor;
  Doc: TFerretDocument;

  procedure Keep(const Id: string; Number: integer);
  begin
    if IsDeleted(Number) then Exit;
    Result[N].Id := Id;
    if WithFacts then
    begin
      Doc := DocumentInfo(Number);
      Result[N].Facts := Copy(Doc.Facts);
    end;
    Inc(N);
  end;

  procedure Sort(L, H: integer);
  var
    A, B: integer;
    Pivot: string;
    Swap: TFerretDocumentEntry;
  begin
    if L >= H then Exit;
    A := L;
    B := H;
    Pivot := Result[(L + H) div 2].Id;
    repeat
      while Result[A].Id < Pivot do Inc(A);
      while Result[B].Id > Pivot do Dec(B);
      if A <= B then
      begin
        Swap := Result[A];
        Result[A] := Result[B];
        Result[B] := Swap;
        Inc(A);
        Dec(B);
      end;
    until A > B;
    if L < B then Sort(L, B);
    if A < H then Sort(A, H);
  end;

begin
  Result := nil;
  SetLength(Result, FCount);
  N := 0;
  for I := 0 to FSegments.Count - 1 do
  begin
    Cursor := TFerretDictionaryCursor.Create(TFerretSegment(FSegments[I]), True);
    try
      while Cursor.Next do Keep(Cursor.Key, Cursor.Number);
    finally
      Cursor.Free;
    end;
  end;
  for J := 0 to TPending(FPending).Ids.Count - 1 do
  begin
    Number := PtrInt(TPending(FPending).Ids.Objects[J]);
    Keep(TPending(FPending).Ids[J], Number);
  end;
  SetLength(Result, N);
  Sort(0, N - 1);
end;

function TFerretSegmentStore.ReadValue(const Name: string): string;
begin
  Result := FValues.Values[Name];
end;

procedure TFerretSegmentStore.WriteValue(const Name, Value: string);
var
  I: integer;
begin
  if (Name = '') or (Pos(#0, Name) > 0) then
    raise EFerret.Create('Give the saved value a nonempty name without a zero byte.');
  NeedWriter;
  if FValues.Values[Name] = Value then Exit;
  I := FValues.IndexOfName(Name);
  if I >= 0 then FValues.Delete(I);
  if Value <> '' then FValues.Add(Name + #0 + Value);
  FValuesChanged := True;
end;

function TFerretSegmentStore.Document(Number: integer): TFerretDocument;
begin
  Result := ReadDocument(Number, True);
end;

function TFerretSegmentStore.DocumentInfo(Number: integer): TFerretDocument;
begin
  Result := ReadDocument(Number, False);
end;

function TFerretSegmentStore.ReadDocument(Number: integer; WithText: boolean): TFerretDocument;
var
  Pending: TPending;
  I: integer;
  Cached: TCachedDocument;
  Key: string;
  Bytes: int64;
begin
  FreeAndNil(FView);
  Key := 'doc:' + IntToStr(Number);
  if not WithText and (FCache.Limit > 0) then
  begin
    Cached := TCachedDocument(FCache.Find(Key));
    if Cached <> nil then
    begin
      FView := Cached.Doc.Clone;
      Exit(FView);
    end;
  end;
  Pending := TPending(FPending);
  if (Number >= Pending.Base) and (Number - Pending.Base < Pending.DocCount) then
    FView := DecodeDocument(Pending.Documents[Number - Pending.Base], WithText)
  else
    for I := FSegments.Count - 1 downto 0 do
    begin
      FView := TFerretSegment(FSegments[I]).Document(Number, WithText);
      if FView <> nil then Break;
    end;
  if FView = nil then raise EFerret.Create('The document is no longer in this index. Search again to refresh the results.');
  if not WithText and (FCache.Limit > 0) then
  begin
    Bytes := Length(FView.Id) + Length(FView.Language) + 128;
    for I := 0 to High(FView.Fields) do Inc(Bytes, Length(FView.Fields[I].Name) + Length(FView.Fields[I].Text) + 64);
    for I := 0 to High(FView.Facts) do Inc(Bytes, Length(FView.Facts[I].Name) + Length(FView.Facts[I].Text) + 64);
    Cached := TCachedDocument.Create;
    Cached.Doc := FView.Clone;
    Cached.Bytes := Bytes;
    FCache.Put(Key, Cached);
  end;
  Result := FView;
end;

procedure TFerretSegmentStore.BeginDocument(const Doc: TFerretDocument);
var
  Old: integer;
begin
  NeedWriter;
  FCache.Clear;
  FPageCache.Clear;
  if FNextNumber = MaxInt then raise EFerret.Create('This index has reached its document limit. Create a new index from the current documents.');
  Old := FindDocument(Doc.Id);
  if Old >= 0 then
  begin
    ChangeStatistics(DocumentInfo(Old), -1);
    TPending(FPending).Delete(Old);
    Dec(FCount);
  end;
end;

procedure TFerretSegmentStore.EndDocument(const Doc: TFerretDocument);
begin
  Inc(FNextNumber);
  Inc(FCount);
  ChangeStatistics(Doc, 1);
  if TPending(FPending).Bytes >= FMemoryLimit then Commit;
end;

procedure TFerretSegmentStore.Put(const Doc: TFerretDocument; const Tokens: TFerretFieldTokens);
begin
  BeginDocument(Doc);
  TPending(FPending).Add(Doc, Tokens);
  EndDocument(Doc);
end;

procedure TFerretSegmentStore.PutText(const Doc: TFerretDocument; StoreText: boolean);
var
  Prepared: TFerretDocument;
  Tokens: TFerretTokens;
  I, First, After, Words, Position, Number: integer;
  Estimate: int64;
begin
  Estimate := 0;
  for I := 0 to High(Doc.Fields) do
  begin
    UTF8Length(Doc.Fields[I].Text);
    Inc(Estimate, int64(Length(Doc.Fields[I].Text)) * 4);
  end;
  NeedWriter;
  if TPending(FPending).HasChanges and (TPending(FPending).Bytes + Estimate > FMemoryLimit) then Commit;
  Prepared := Doc.Clone;
  try
    BeginDocument(Prepared);
    Number := FNextNumber;
    for I := 0 to High(Prepared.Fields) do
    begin
      First := 1;
      Position := 0;
      while First <= Length(Prepared.Fields[I].Text) do
      begin
        After := First + 16384;
        if After > Length(Prepared.Fields[I].Text) then After := Length(Prepared.Fields[I].Text) + 1
        else
          // Whitespace cannot join identifiers, marks, or overlapping pairs.
          while (After <= Length(Prepared.Fields[I].Text)) and not (Prepared.Fields[I].Text[After] in [#9, #10, #11, #12, #13, ' ']) do Inc(After);
        Tokens := SplitText(Copy(Prepared.Fields[I].Text, First, After - First), Words);
        if Stemmers <> nil then Stemmers.AddTokens(Tokens, Prepared.Language);
        if (First = 1) and (Prepared.Fields[I].Name = 'title') then AddTitleTerms(Prepared.Fields[I].Text, Tokens);
        TPending(FPending).AddTokens(Number, I, Tokens, Position, First - 1);
        Inc(Position, Words);
        First := After;
      end;
      Prepared.Fields[I].WordCount := Position;
      if not StoreText then Prepared.Fields[I].Text := '';
    end;
    Tokens := nil;
    TPending(FPending).AddDocument(Prepared);
    EndDocument(Prepared);
  finally
    Prepared.Free;
  end;
end;

function TFerretSegmentStore.Remove(const Id: string): boolean;
var
  Number: integer;
begin
  NeedWriter;
  FCache.Clear;
  FPageCache.Clear;
  Number := FindDocument(Id);
  Result := Number >= 0;
  if not Result then Exit;
  ChangeStatistics(DocumentInfo(Number), -1);
  TPending(FPending).Delete(Number);
  Dec(FCount);
  if TPending(FPending).Bytes >= FMemoryLimit then Commit;
end;

procedure TFerretSegmentStore.SetCacheLimit(Bytes: int64);
begin
  FCache.SetLimit(Bytes - Bytes div 8);
  FPageCache.SetLimit(Bytes div 8);
end;

function BlocksFromDocuments(Store: TFerretStore; const Docs: TFerretTermDocuments): TFerretTermBlocks;
var
  I, J, K, N, Bit: integer;
  Doc: TFerretDocument;
begin
  Result := nil;
  for I := 0 to High(Docs) do
  begin
    N := Length(Result) - 1;
    if (N < 0) or (Result[N].Range <> Docs[I].Number div 128) then
    begin
      Inc(N);
      SetLength(Result, N + 1);
      Result[N].Range := Docs[I].Number div 128;
    end;
    Result[N].Last := Docs[I].Number;
    Bit := Docs[I].Number mod 128;
    Result[N].Mask[Bit div 32] := Result[N].Mask[Bit div 32] or (cardinal(1) shl (Bit mod 32));
    J := Length(Result[N].Documents);
    SetLength(Result[N].Documents, J + 1);
    Result[N].Documents[J] := Docs[I];
    Doc := Store.DocumentInfo(Docs[I].Number);
    // Copy frequencies before attaching scoring metadata to the query's block.
    Result[N].Documents[J].Fields := Copy(Docs[I].Fields);
    for K := 0 to High(Docs[I].Fields) do
      with Result[N].Documents[J].Fields[K] do
      begin
        Name := Doc.Fields[Field].Name;
        Weight := Doc.Fields[Field].Weight;
        WordCount := Doc.Fields[Field].WordCount;
      end;
  end;
end;

function TFerretStore.BlockDocuments(const Block: TFerretTermBlock): TFerretTermDocuments;
var
  D: TFerretDecoder;
  Items: TFerretPostings;
  Previous: TFerretPosting;
  Parts: TFerretTermBlocks;
  I: integer;
begin
  if Block.Segment <> nil then Exit(Block.Segment.ReadBlock(Block.Offset, Block.Buffer));
  if Block.Encoded = '' then Exit(Block.Documents);
  D.Start(Block.Encoded);
  Previous := Block.Previous;
  SetLength(Items, Block.PostingCount);
  for I := 0 to High(Items) do Items[I] := UnpackPosting(D, Previous);
  D.Finish;
  Parts := BlocksFromDocuments(Self, PostingSummaries(Items));
  if Length(Parts) <> 1 then DamagedIndex;
  Result := Parts[0].Documents;
end;

function TFerretStore.TermBlocks(const Term: string): TFerretTermBlocks;
begin
  Result := BlocksFromDocuments(Self, Summaries(Term));
end;

procedure AppendBlocks(var Target: TFerretTermBlocks; const Source: TFerretTermBlocks);
var
  I, N: integer;
begin
  N := Length(Target);
  SetLength(Target, N + Length(Source));
  for I := 0 to High(Source) do
  begin
    Target[N + I] := Source[I];
    Inc(Target[N + I].Source, N);
  end;
end;

function TFerretStore.WordBlocks(Terms: TStrings): TFerretTermBlocks;
var
  I: integer;
begin
  Result := nil;
  for I := 0 to Terms.Count - 1 do AppendBlocks(Result, TermBlocks(Terms[I]));
end;

procedure TFerretSegmentStore.FilterDeleted(var Blocks: TFerretTermBlocks);
var
  I, J, K: integer;
  Bit: cardinal;
  AnyDeleted: boolean;
begin
  AnyDeleted := Length(TPending(FPending).Deleted) > 0;
  for I := 0 to FSegments.Count - 1 do AnyDeleted := AnyDeleted or (TFerretSegment(FSegments[I]).DeleteCount > 0);
  if not AnyDeleted then Exit;
  for I := 0 to High(Blocks) do
    for J := 0 to 3 do
      for K := 0 to 31 do
      begin
        Bit := cardinal(1) shl K;
        if (Blocks[I].Mask[J] and cardinal(Bit) <> 0) and IsDeleted(Blocks[I].Range * 128 + J * 32 + K) then
          Blocks[I].Mask[J] := Blocks[I].Mask[J] and not cardinal(Bit);
      end;
end;

function TFerretSegmentStore.WordBlocks(Terms: TStrings): TFerretTermBlocks;
var
  Sorted: TStringList;
  Lists: array of TFerretTermBlocks;
  Cursor: TFerretDictionaryCursor;
  Segment: TFerretSegment;
  I, J, Slot: integer;
  Available: boolean;
begin
  if (Terms.Count < 2) or TPending(FPending).HasChanges then Exit(inherited WordBlocks(Terms));
  Result := nil;
  Sorted := NewDictionary;
  try
    SetLength(Lists, Terms.Count);
    for I := 0 to Terms.Count - 1 do Sorted.AddObject(Terms[I], TObject(PtrInt(I)));
    for I := 0 to FSegments.Count - 1 do
    begin
      Segment := TFerretSegment(FSegments[I]);
      Cursor := TFerretDictionaryCursor.Create(Segment, False, Sorted[0]);
      try
        Available := Cursor.Next;
        for J := 0 to Sorted.Count - 1 do
        begin
          if (J > 0) and Available and (Cursor.Key < Sorted[J]) then
          begin
            Available := Cursor.Next;
            if Available and (Cursor.Key < Sorted[J]) then
            begin
              Cursor.Free;
              Cursor := nil;
              Cursor := TFerretDictionaryCursor.Create(Segment, False, Sorted[J]);
              Available := Cursor.Next;
            end;
          end;
          while Available and (Cursor.Key < Sorted[J]) do Available := Cursor.Next;
          if not Available then Break;
          if Cursor.Key <> Sorted[J] then Continue;
          Slot := PtrInt(Sorted.Objects[J]);
          AppendBlocks(Lists[Slot], Segment.TermBlocks(Cursor.Key, Cursor.Summary));
        end;
      finally
        Cursor.Free;
      end;
    end;
    for I := 0 to High(Lists) do AppendBlocks(Result, Lists[I]);
    FilterDeleted(Result);
  finally
    Sorted.Free;
  end;
end;

function TFerretSegmentStore.TermBlocks(const Term: string): TFerretTermBlocks;
var
  I, J, N: integer;
  Part: TFerretTermBlocks;
  Pending: TPending;
  List: TPendingTerm;
begin
  Result := nil;
  for I := 0 to FSegments.Count - 1 do
  begin
    Part := Copy(TFerretSegment(FSegments[I]).TermBlocks(Term));
    N := Length(Result);
    SetLength(Result, N + Length(Part));
    for J := 0 to High(Part) do
    begin
      Result[N + J] := Part[J];
      Result[N + J].Source := N;
    end;
  end;
  Pending := TPending(FPending);
  I := Pending.Buckets[Checksum(Term) and (Length(Pending.Buckets) - 1)];
  while I <> 0 do
  begin
    List := TPendingTerm(Pending.Terms.Objects[I - 1]);
    if Pending.Terms[I - 1] = Term then
    begin
      N := Length(Result);
      SetLength(Result, N + List.BlockCount);
      for J := 0 to List.BlockCount - 1 do
      begin
        Result[N + J].Source := N;
        Result[N + J].Range := List.Blocks[J].Range;
        Result[N + J].Last := List.Blocks[J].Last;
        Result[N + J].Mask := List.Blocks[J].Mask;
        Result[N + J].Previous := List.Blocks[J].Previous;
        Result[N + J].PostingCount := List.Blocks[J].Count;
        Result[N + J].Encoded := List.Bytes.Slice(List.Blocks[J].First, List.Blocks[J].After - List.Blocks[J].First);
      end;
      Break;
    end;
    I := List.Next;
  end;
  FilterDeleted(Result);
end;

function TFerretSegmentStore.Summaries(const Term: string): TFerretTermDocuments;
var
  Blocks: TFerretTermBlocks;
  Docs: TFerretTermDocuments;
  I, J, N, Bit: integer;
begin
  Result := nil;
  Blocks := TermBlocks(Term);
  N := 0;
  for I := 0 to High(Blocks) do
  begin
    Docs := BlockDocuments(Blocks[I]);
    for J := 0 to High(Docs) do
    begin
      Bit := Docs[J].Number mod 128;
      if Blocks[I].Mask[Bit div 32] and (cardinal(1) shl (Bit mod 32)) = 0 then Continue;
      if N = Length(Result) then SetLength(Result, N * 2 + 16);
      Result[N] := Docs[J];
      Inc(N);
    end;
  end;
  SetLength(Result, N);
end;

function TFerretSegmentStore.Postings(const Term: string): TFerretPostings;
var
  I, N, Capacity, LastDocument: integer;
  Dead: boolean;
  Cursor: TFerretPostingCursor;
  Pending: TPending;
  List: TPendingTerm;
  D: TFerretDecoder;
  Previous, Item: TFerretPosting;

  procedure Keep(const Value: TFerretPosting);
  begin
    if Value.Document <> LastDocument then
    begin
      LastDocument := Value.Document;
      Dead := IsDeleted(LastDocument);
    end;
    if Dead then Exit;
    if N = Capacity then
    begin
      Capacity := Capacity * 2 + 64;
      SetLength(Result, Capacity);
    end;
    Result[N] := Value;
    Inc(N);
  end;

begin
  Result := nil;
  N := 0;
  Capacity := 0;
  LastDocument := -1;
  Dead := False;
  for I := 0 to FSegments.Count - 1 do
  begin
    Cursor := TFerretSegment(FSegments[I]).PostingCursor(Term);
    if Cursor = nil then Continue;
    try
      while Cursor.Next do Keep(Cursor.Item);
    finally
      Cursor.Free;
    end;
  end;
  Pending := TPending(FPending);
  // Lookup does not add missing query words to the pending dictionary.
  I := Pending.Buckets[Checksum(Term) and (Length(Pending.Buckets) - 1)];
  while I <> 0 do
  begin
    List := TPendingTerm(Pending.Terms.Objects[I - 1]);
    if Pending.Terms[I - 1] = Term then
    begin
      D.Start(List.Bytes.Data);
      Previous := Default(TFerretPosting);
      for I := 1 to List.Count do
      begin
        Item := UnpackPosting(D, Previous);
        Keep(Item);
      end;
      D.Finish;
      Break;
    end;
    I := List.Next;
  end;
  SetLength(Result, N);
end;

procedure TFerretSegmentStore.PrefixTerms(const Prefix: string; Terms: TStrings);
var
  All: TStringList;
  I: integer;
begin
  Terms.Clear;
  if FCount = 0 then Exit;
  All := TStringList.Create;
  All.CaseSensitive := True;
  try
    for I := 0 to FSegments.Count - 1 do TFerretSegment(FSegments[I]).PrefixTerms(Prefix, All);
    I := 0;
    TPending(FPending).Dictionary.Sorted := True;
    TPending(FPending).Dictionary.Find(Prefix, I);
    while (I < TPending(FPending).Dictionary.Count) and (Copy(TPending(FPending).Dictionary[I], 1, Length(Prefix)) = Prefix) do
    begin
      All.Add(TPending(FPending).Dictionary[I]);
      Inc(I);
    end;
    All.Sort;
    for I := 0 to All.Count - 1 do
      if (I = 0) or (All[I] <> All[I - 1]) then Terms.Add(All[I]);
  finally
    All.Free;
  end;
end;

procedure TFerretStore.CompletionTerms(const Prefix: string; Terms: TStrings);
var
  I: integer;
begin
  PrefixTerms(Prefix, Terms);
  for I := 0 to Terms.Count - 1 do Terms.Objects[I] := TObject(PtrInt(MaxInt));
end;

// Every term that starts with Prefix with its count, once for each segment that holds it.
procedure TFerretSegmentStore.PrefixCounts(const Prefix: string; All: TStringList);
var
  Cursor: TFerretDictionaryCursor;
  I: integer;

  procedure Include(const Term: string; Count: integer);
  begin
    All.AddObject(Term, TObject(PtrInt(Count)));
  end;

begin
  for I := 0 to FSegments.Count - 1 do
  begin
    Cursor := TFerretDictionaryCursor.Create(TFerretSegment(FSegments[I]), False, Prefix);
    try
      while Cursor.Next do
      begin
        if Cursor.Key < Prefix then Continue;
        if Copy(Cursor.Key, 1, Length(Prefix)) <> Prefix then Break;
        Include(Cursor.Key, Cursor.Count);
      end;
    finally
      Cursor.Free;
    end;
  end;
  I := 0;
  TPending(FPending).Dictionary.Sorted := True;
  TPending(FPending).Dictionary.Find(Prefix, I);
  while (I < TPending(FPending).Dictionary.Count) and (Copy(TPending(FPending).Dictionary[I], 1, Length(Prefix)) = Prefix) do
  begin
    Include(TPending(FPending).Dictionary[I], TPending(FPending).Term(TPending(FPending).Dictionary[I]).Count);
    Inc(I);
  end;
end;

procedure TFerretSegmentStore.CompletionTerms(const Prefix: string; Terms: TStrings);
var
  All: TStringList;
  I, J: integer;
  Bound: int64;
  Cached: TCachedCompletion;
  Key: string;
begin
  Terms.Clear;
  if FCount = 0 then Exit;
  Key := '$completion:' + Prefix;
  Cached := TCachedCompletion(FCache.Find(Key));
  if Cached <> nil then
  begin
    Terms.Assign(Cached.Terms);
    Exit;
  end;
  All := TStringList.Create;
  All.CaseSensitive := True;
  try
    PrefixCounts(Prefix, All);
    All.Sort;
    I := 0;
    while I < All.Count do
    begin
      J := I;
      Bound := 0;
      while (J < All.Count) and (All[J] = All[I]) do
      begin
        Inc(Bound, PtrInt(All.Objects[J]));
        if Bound > MaxInt then Bound := MaxInt;
        Inc(J);
      end;
      Terms.AddObject(All[I], TObject(PtrInt(Bound)));
      I := J;
    end;
    All.Assign(Terms);
    All.CustomSort(@CompareCompletionBound);
    Terms.Assign(All);
    CacheTerms(FCache, Key, All, 0);
  finally
    All.Free;
  end;
end;

procedure TFerretStore.ShortestTerms(const Prefix: string; Limit: integer; Terms: TStrings);
var
  All: TStringList;
  I: integer;
begin
  All := TStringList.Create;
  try
    PrefixTerms(Prefix, All);
    All.CustomSort(@CompareShortest);
    Terms.Clear;
    for I := 0 to All.Count - 1 do
      if I < Limit then Terms.Add(All[I]);
  finally
    All.Free;
  end;
end;

procedure TFerretSegmentStore.ShortestTerms(const Prefix: string; Limit: integer; Terms: TStrings);
var
  All: TStringList;
  I: integer;
  Cached: TCachedCompletion;
  Key: string;
begin
  Terms.Clear;
  if FCount = 0 then Exit;
  Key := '$shortest:' + IntToStr(Limit) + ':' + Prefix;
  Cached := TCachedCompletion(FCache.Find(Key));
  if Cached <> nil then
  begin
    Terms.Assign(Cached.Terms);
    Exit;
  end;
  All := TStringList.Create;
  All.CaseSensitive := True;
  try
    PrefixCounts(Prefix, All);
    All.CustomSort(@CompareShortest);
    for I := 0 to All.Count - 1 do
      if (Terms.Count < Limit) and ((I = 0) or (All[I] <> All[I - 1])) then Terms.Add(All[I]);
    All.Assign(Terms);
    CacheTerms(FCache, Key, All, 0);
  finally
    All.Free;
  end;
end;

function TFerretStore.FuzzyTerms(const word: string; Limit: integer; Terms: TStrings): integer;
var
  All: TStringList;
  I: integer;
  Skip: string;
begin
  All := TStringList.Create;
  try
    PrefixTerms('', All);
    Result := All.Count;
    Terms.Clear;
    for I := 0 to All.Count - 1 do
      if (All[I] >= ' ') and (WordDistance(word, All[I], Limit, Skip) <= Limit) then Terms.Add(All[I]);
  finally
    All.Free;
  end;
end;

function TFerretSegmentStore.FuzzyTerms(const word: string; Limit: integer; Terms: TStrings): integer;
var
  All: TStringList;
  I, J, Slot: integer;
  Skip, Key: string;
  Cached: TCachedCompletion;
begin
  Key := '$fuzzy:' + IntToStr(Limit) + ':' + word;
  Cached := TCachedCompletion(FCache.Find(Key));
  if Cached <> nil then
  begin
    Terms.Assign(Cached.Terms);
    Exit(Cached.Visited);
  end;
  All := NewDictionary;
  try
    Result := 0;
    for I := 0 to FSegments.Count - 1 do
      Inc(Result, TFerretSegment(FSegments[I]).FuzzyTerms(word, Limit, All));
    I := 0;
    TPending(FPending).Dictionary.Sorted := True;
    TPending(FPending).Dictionary.Find(' ', I);
    while I < TPending(FPending).Dictionary.Count do
    begin
      Inc(Result);
      if WordDistance(word, TPending(FPending).Dictionary[I], Limit, Skip) <= Limit then All.Add(TPending(FPending).Dictionary[I]);
      if Skip = '' then Inc(I)
      else
      begin
        Slot := I;
        TPending(FPending).Dictionary.Find(Skip, J);
        I := J;
        if I <= Slot then Inc(I);
      end;
    end;
    Terms.Assign(All);
    CacheTerms(FCache, Key, All, Result);
  finally
    All.Free;
  end;
end;

function TFerretSegmentStore.AverageLength(const Field: string): double;
var
  N: integer;
  Stats: TFieldStatistics;
begin
  Result := 1;
  if not FStatistics.Find(Field, N) then Exit;
  Stats := TFieldStatistics(FStatistics.Objects[N]);
  if (Stats.Count > 0) and (Stats.Words > 0) then Result := Stats.Words / Stats.Count;
end;

function TFerretSegmentStore.DocumentCount: integer;
begin
  Result := FCount;
end;

procedure TFerretSegmentStore.SetMemoryLimit(Bytes: int64);
begin
  if Bytes < 65536 then raise EFerret.Create('MemoryLimit must be at least 65536 bytes (64 KB).');
  FMemoryLimit := Bytes;
  if TPending(FPending).Bytes >= FMemoryLimit then Commit;
end;

procedure TFerretSegmentStore.Commit;
var
  Pending: TPending;
  Writer: TFerretSegmentWriter;
  Segment: TFerretSegment;
  Sorted: TStringList;
  List: TPendingTerm;
  D: TFerretDecoder;
  Previous, Item: TFerretPosting;
  I, J: integer;
  NewSegments: TFPList;
begin
  Pending := TPending(FPending);
  if not Pending.HasChanges then
  begin
    if FValuesChanged then
    try
      SaveManifest(FSegments);
    except
      FFailed := True;
      raise;
    end;
    Exit;
  end;
  NeedWriter;
  Writer := nil;
  Segment := nil;
  Sorted := NewDictionary;
  NewSegments := TFPList.Create;
  try
    try
      Writer := TFerretSegmentWriter.Create(NewSegmentName);
      for I := 0 to Pending.DocCount - 1 do
        Writer.AddDocument(Pending.Base + I, Pending.Documents[I]);
      Writer.EndDocuments;
      for I := 0 to High(Pending.Deleted) do Writer.AddDeletion(Pending.Deleted[I]);
      Sorted.Sorted := False;
      Sorted.Assign(Pending.Terms);
      Sorted.Sort;
      for I := 0 to Sorted.Count - 1 do
      begin
        List := TPendingTerm(Sorted.Objects[I]);
        Writer.BeginTerm(Sorted[I]);
        D.Start(List.Bytes.TakeData);
        Previous := Default(TFerretPosting);
        for J := 1 to List.Count do
        begin
          Item := UnpackPosting(D, Previous);
          Writer.AddPosting(Item);
        end;
        D.Finish;
        Writer.EndTerm;
      end;
      for I := 0 to Pending.Ids.Count - 1 do Writer.AddId(Pending.Ids[I], PtrInt(Pending.Ids.Objects[I]));
      Segment := Writer.Finish;
      Segment.Cache := FCache;
      Segment.PageCache := FPageCache;
      NewSegments.Assign(FSegments);
      NewSegments.Add(Segment);
      SaveManifest(NewSegments);
      FSegments.Free;
      FSegments := NewSegments;
      NewSegments := nil;
      Segment := nil;
      FPending.Free;
      FPending := TPending.Create(FNextNumber);
    except
      FFailed := True;
      raise;
    end;
  finally
    Segment.Free;
    NewSegments.Free;
    Sorted.Free;
    Writer.Free;
  end;
  AutoMerge;
end;

procedure TFerretSegmentStore.Merge(First, After: integer);
var
  Writer: TFerretSegmentWriter;
  NewSegment, Segment: TFerretSegment;
  NewSegments: TFPList;
  Cursors: array of TFerretDictionaryCursor;
  Available: array of boolean;
  I, J, Smallest, Number, LastDeleted: integer;
  DeleteSlots: array of integer;
  OldName: string;

  procedure MergeDictionary(Ids: boolean);
  var
    I, Selected: integer;
    Name: string;
    Posting: TFerretPostingCursor;
  begin
    for I := 0 to High(Cursors) do
    begin
      FreeAndNil(Cursors[I]);
      Cursors[I] := TFerretDictionaryCursor.Create(TFerretSegment(FSegments[First + I]), Ids);
      Available[I] := Cursors[I].Next;
    end;
    repeat
      Selected := -1;
      for I := 0 to High(Cursors) do
        if Available[I] then
          if (Selected < 0) or (Cursors[I].Key < Cursors[Selected].Key) then Selected := I;
      if Selected < 0 then Break;
      Name := Cursors[Selected].Key;
      if not Ids then Writer.BeginTerm(Name);
      for I := 0 to High(Cursors) do
        if Available[I] and (Cursors[I].Key = Name) then
        begin
          if Ids then
          begin
            if not IsDeleted(Cursors[I].Number) then Writer.AddId(Name, Cursors[I].Number);
          end
          else
          begin
            Posting := TFerretPostingCursor.Create(TFerretSegment(FSegments[First + I]).FileData, Cursors[I].First, Cursors[I].After, Cursors[I].Count);
            try
              Number := -1;
              while Posting.Next do
              begin
                if Posting.Item.Document <> Number then
                begin
                  Number := Posting.Item.Document;
                  Smallest := Ord(IsDeleted(Number));
                end;
                if Smallest = 0 then Writer.AddPosting(Posting.Item);
              end;
            finally
              Posting.Free;
            end;
          end;
          Available[I] := Cursors[I].Next;
        end;
      if not Ids then Writer.EndTerm;
    until False;
  end;

begin
  Writer := nil;
  NewSegment := nil;
  NewSegments := TFPList.Create;
  SetLength(Cursors, After - First);
  SetLength(Available, After - First);
  SetLength(DeleteSlots, After - First);
  FCache.Clear;
  FPageCache.Clear;
  for I := First to After - 1 do TFerretSegment(FSegments[I]).Cache := nil;
  try
    try
      Writer := TFerretSegmentWriter.Create(NewSegmentName);
      for I := First to After - 1 do
      begin
        Segment := TFerretSegment(FSegments[I]);
        for J := 0 to Segment.DocumentSlots - 1 do
        begin
          Number := Segment.DocumentNumber(J);
          if not IsDeleted(Number) then Writer.AddDocument(Number, Segment.DocumentData(J));
        end;
      end;
      Writer.EndDocuments;
      // Partial merges retain marks against segments outside this tier.
      if (First <> 0) or (After <> FSegments.Count) then
      begin
        LastDeleted := -1;
        repeat
          Smallest := -1;
          Number := MaxInt;
          for I := 0 to High(DeleteSlots) do
          begin
            Segment := TFerretSegment(FSegments[First + I]);
            if DeleteSlots[I] >= Segment.DeleteCount then Continue;
            J := Segment.DeletionNumber(DeleteSlots[I]);
            if J < Number then
            begin
              Number := J;
              Smallest := I;
            end;
          end;
          if Smallest < 0 then Break;
          if Number <> LastDeleted then Writer.AddDeletion(Number);
          LastDeleted := Number;
          Inc(DeleteSlots[Smallest]);
        until False;
      end;
      MergeDictionary(False);
      MergeDictionary(True);
      NewSegment := Writer.Finish;
      NewSegment.Cache := FCache;
      NewSegment.PageCache := FPageCache;
      FCache.Clear;
      FPageCache.Clear;
      for I := 0 to First - 1 do NewSegments.Add(FSegments[I]);
      NewSegments.Add(NewSegment);
      for I := After to FSegments.Count - 1 do NewSegments.Add(FSegments[I]);
      SaveManifest(NewSegments);
      for I := First to After - 1 do
      begin
        Segment := TFerretSegment(FSegments[I]);
        OldName := Segment.Name;
        Segment.Free;
        if FFolder <> '' then DeleteFile(FFolder + OldName);
      end;
      FSegments.Free;
      FSegments := NewSegments;
      NewSegments := nil;
      NewSegment := nil;
    except
      FFailed := True;
      raise;
    end;
  finally
    for I := 0 to FSegments.Count - 1 do TFerretSegment(FSegments[I]).Cache := FCache;
    for I := 0 to High(Cursors) do Cursors[I].Free;
    NewSegments.Free;
    NewSegment.Free;
    Writer.Free;
  end;
end;

procedure TFerretSegmentStore.AutoMerge;
var
  I, Tier: integer;
  Matches, First: array[0..31] of integer;
  Size: int64;
  Again: boolean;
begin
  // A contiguous range preserves document order when a tier includes gaps.
  repeat
    Again := False;
    FillChar(Matches, SizeOf(Matches), 0);
    for I := 0 to FSegments.Count - 1 do
    begin
      Size := TFerretSegment(FSegments[I]).FileData.Size;
      Tier := 0;
      while Size >= 262144 do
      begin
        Inc(Tier);
        Size := Size div 4;
      end;
      if Matches[Tier] = 0 then First[Tier] := I;
      Inc(Matches[Tier]);
      if Matches[Tier] >= 4 then
      begin
        Merge(First[Tier], I + 1);
        Again := True;
        Break;
      end;
    end;
  until not Again;
end;

procedure TFerretSegmentStore.Optimize;
begin
  Commit;
  if FSegments.Count = 0 then Exit;
  NeedWriter;
  Merge(0, FSegments.Count);
end;

procedure TFerretSegmentStore.Refresh;
var
  Attempts: integer;
  BeforeStamp: string;
begin
  if (FFolder = '') or (FLock <> nil) then Exit;
  BeforeStamp := TFerretFile.Stamp(FFolder + 'manifest');
  if BeforeStamp = FStamp then Exit;
  for Attempts := 1 to 3 do
  try
    LoadManifest;
    Exit;
  except
    on E: EFerret do
    begin
      if (Attempts = 3) or (TFerretFile.Stamp(FFolder + 'manifest') = BeforeStamp) then raise;
      BeforeStamp := TFerretFile.Stamp(FFolder + 'manifest');
    end;
  end;
end;

function TFerretSegmentStore.SizeOnDisk: int64;
var
  Info: TSearchRec;
begin
  Result := 0;
  if FFolder = '' then Exit;
  if FindFirst(FFolder + '*', faAnyFile, Info) <> 0 then Exit;
  try
    repeat
      if (Info.Attr and faDirectory = 0) then Inc(Result, Info.Size);
    until FindNext(Info) <> 0;
  finally
    FindClose(Info);
  end;
end;

end.
