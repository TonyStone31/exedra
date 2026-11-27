unit FerretSegment;

{$mode objfpc}{$H+}
// Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.

interface

uses Classes, SysUtils, FerretTypes, FerretText, FerretIO, FerretCodec, FerretCache;

type
  TFerretPosting = record
    Document, Field, Position, Span, ByteStart, ByteLength: integer;
  end;
  TFerretPostings = array of TFerretPosting;
  TFerretFieldTokens = array of TFerretTokens;
  TFerretNumbers = array of integer;

  TFerretSkip = record
    Key: string;
    Offset: int64;
  end;
  TFerretSkips = array of TFerretSkip;

  TFerretSegment = class;

  TFerretFieldFrequency = record
    Field, Count, WordCount: integer;
    Weight: double;
    Name: string;
  end;
  TFerretFieldFrequencies = array of TFerretFieldFrequency;

  TFerretTermDocument = record
    Number: integer;
    Fields: TFerretFieldFrequencies;
    Segment: TFerretSegment;
    Offset: int64;
    Pending: TFerretPostings;
  end;
  TFerretTermDocuments = array of TFerretTermDocument;

  TFerretDocumentMask = array[0..3] of cardinal;

  TFerretScoreBound = record
    Name: string;
    Frequency: double;
    WordCount: integer;
  end;
  TFerretScoreBounds = array of TFerretScoreBound;

  TFerretTermBlock = record
    Range, Last, Order, Source: integer;
    Buffer: TFerretReadBuffer;
    Mask: TFerretDocumentMask;
    Bounds: TFerretScoreBounds;
    Offset: int64;
    Segment: TFerretSegment;
    Documents: TFerretTermDocuments;
    Encoded: rawbytestring;
    Previous: TFerretPosting;
    PostingCount: integer;
  end;
  TFerretTermBlocks = array of TFerretTermBlock;

  TFerretCachedBlock = class(TFerretCacheItem)
    Documents: TFerretTermDocuments;
  end;

  TFerretCachedSkips = class(TFerretCacheItem)
    Blocks: TFerretTermBlocks;
  end;

  TFerretCachedPostings = class(TFerretCacheItem)
    Items: TFerretPostings;
  end;

  TFerretDictionaryEntry = record
    Key: string;
    First, After, Summary: int64;
    Count, Number: integer;
  end;
  TFerretDictionaryEntries = array of TFerretDictionaryEntry;

  TFerretCachedDictionary = class(TFerretCacheItem)
    Entries: TFerretDictionaryEntries;
  end;

  TFerretDictionaryCursor = class
  private
    FSegment: TFerretSegment;
    FIds: boolean;
    FBlock: integer;
    FEntries: TFerretDictionaryEntries;
    FEntry: integer;
  public
    Key: string;
    First, After, Summary: int64;
    Count, Number: integer;
    constructor Create(Segment: TFerretSegment; Ids: boolean; const SeekKey: string = '');
    procedure Seek(const SeekKey: string);
    function Next: boolean;
  end;

  TFerretPostingCursor = class
  private
    FFile: TFerretFile;
    FOffset, FAfter: int64;
    FRemaining, FTotal: integer;
    FDecoder: TFerretDecoder;
    FPrevious: TFerretPosting;
  public
    Item: TFerretPosting;
    constructor Create(FileData: TFerretFile; First, After: int64; Count: integer);
    function Next: boolean;
  end;

  TFerretSegment = class
  private
    FFile: TFerretFile;
    FCache: TFerretCache;
    FCachePrefix: string;
    FTermSkips, FIdSkips: TFerretSkips;
    FDocTable, FDeletes, FTextBase, FSummaryBase: int64;
    FDocCount, FDeleteCount: integer;
    FFirstNumber, FLastNumber, FCachedDocBlock, FCachedDeleteBlock: integer;
    FDocBlockData, FDeleteBlockData, FSkipData: rawbytestring;
    FSkipPosition: integer;
    FDocumentBuffer, FTableBuffer: TFerretReadBuffer;
    procedure NeedSkips;
    function FindTermSummary(const Term: string): int64;
    function TableEntry(Deletion: boolean; Slot: integer): TFerretDecoder;
    function DocumentOffset(Slot: integer): int64;
    procedure SetPageCache(Value: TFerretCache);
    procedure LoadSkips(var D: TFerretDecoder; var Skips: TFerretSkips);
  public
    Name: string;
    constructor Create(FileData: TFerretFile; const AName: string; Cache: TFerretCache = nil);
    destructor Destroy; override;
    procedure BeginQuery;
    procedure EndQuery;
    function DocumentNumber(Slot: integer): integer;
    function DocumentData(Slot: integer): rawbytestring;
    function Document(Number: integer; WithText: boolean = True): TFerretDocument;
    function FindDocument(const Id: string): integer;
    function DeletionNumber(Slot: integer): integer;
    function Deleted(Number: integer): boolean;
    function TermBlocks(const Term: string; Offset: int64 = -1): TFerretTermBlocks;
    function ReadBlock(Offset: int64; Buffer: TFerretReadBuffer = nil): TFerretTermDocuments;
    function ReadBlockIndex(Offset: int64): TFerretTermBlocks;
    function Positions(const Source: TFerretTermDocument; Buffer: TFerretReadBuffer = nil): TFerretPostings;
    function DictionaryBlock(Offset: int64; Ids: boolean): TFerretDictionaryEntries;
    function PostingCursor(const Term: string): TFerretPostingCursor;
    procedure PrefixTerms(const Prefix: string; Terms: TStrings);
    function FuzzyTerms(const word: string; Limit: integer; Terms: TStrings): integer;
    property FileData: TFerretFile read FFile;
    property PageCache: TFerretCache write SetPageCache;
    property Cache: TFerretCache read FCache write FCache;
    property DocumentSlots: integer read FDocCount;
    property DeleteCount: integer read FDeleteCount;
  end;

  TFerretSegmentWriter = class
  private
    FFile, FDocTable, FTerms, FIds, FTextData, FSummaryFile: TFerretFile;
    FWorkName: string;
    FDocCount, FDeleteCount: integer;
    FDocOffset, FDeleteOffset, FTermOffset, FIdOffset, FTextBase, FSummaryBase: int64;
    FTermSkips, FIdSkips: TFerretSkips;
    FTermBlock, FIdBlock, FPostingBytes, FDeleteBlock, FFrameHeader, FSummary, FRecord, FBlockIndex: TFerretBuffer;
    FBlockMask: TFerretDocumentMask;
    FBlockBounds: TFerretScoreBounds;
    FBlockRange, FBlockLast, FBlockCount, FBlockDocuments: integer;
    FDocNumbers: TFerretNumbers;
    FDocuments: array of TFerretFields;
    FDocFields: TFerretFieldFrequencies;
    FSummaryNumber, FDocNumber, FDocFieldCount: integer;
    FSummaryOffset: int64;
    FTermBlockCount, FIdBlockCount, FPostingCount, FChunkCount: integer;
    FTerm: string;
    FPostingStart: int64;
    FPrevious: TFerretPosting;
    procedure FlushDictionary(Ids: boolean);
    procedure FlushPostings;
    procedure FlushSummary;
    procedure AddSummary(Number: integer; Offset: int64; const Fields: array of TFerretFieldFrequency);
    function DocumentFields(Number: integer): TFerretFields;
    procedure FlushDeletes;
    procedure AddEntry(Ids: boolean; const Key: string; First, After: int64; Count: integer; Summary: int64 = 0);
    procedure CopyFile(Source: TFerretFile; TableWidth: integer = 0);
    procedure SaveSkips(B: TFerretBuffer; const Skips: TFerretSkips; Base: int64);
  public
    constructor Create(const Name: string);
    destructor Destroy; override;
    procedure AddDocument(Number: integer; const Data: rawbytestring);
    procedure EndDocuments;
    procedure AddDeletion(Number: integer);
    procedure BeginTerm(const Term: string);
    procedure AddPosting(const Item: TFerretPosting);
    procedure EndTerm;
    procedure AddId(const Id: string; Number: integer);
    function Finish: TFerretSegment;
  end;

function ComparePosting(const A, B: TFerretPosting): integer;
procedure PackPosting(B: TFerretBuffer; const Item: TFerretPosting; var Previous: TFerretPosting);
function UnpackPosting(var D: TFerretDecoder; var Previous: TFerretPosting): TFerretPosting;

implementation

uses FerretSpell;

const
  SegmentMagic = 'FERSEG01';
  HeaderSize = 80;
  BlockEntries = 64;

function ComparePosting(const A, B: TFerretPosting): integer;
begin
  if A.Document <> B.Document then
  begin
    if A.Document < B.Document then Exit(-1)
    else
      Exit(1);
  end;
  if A.Field <> B.Field then Exit(A.Field - B.Field);
  if A.Position <> B.Position then Exit(A.Position - B.Position);
  Result := A.Span - B.Span;
end;

procedure PackPosting(B: TFerretBuffer; const Item: TFerretPosting; var Previous: TFerretPosting);
var
  Flags: QWord;
  Changed: boolean;
begin
  Changed := (Item.Document <> Previous.Document) or (Item.Field <> Previous.Field);
  Flags := Ord(Changed) or (Ord(Item.Span <> 1) shl 1);
  if Changed then
  begin
    B.U(Flags);
    B.U(Item.Document - Previous.Document);
    if Item.Document <> Previous.Document then Previous := Default(TFerretPosting);
    B.U(Item.Field - Previous.Field);
    Previous.Position := 0;
    Previous.ByteStart := 0;
    B.U(Item.Position);
  end
  else
    B.U((QWord(Item.Position - Previous.Position) shl 2) or Flags);
  if Item.Span <> 1 then B.U(Item.Span - 1);
  B.U(Item.ByteStart - Previous.ByteStart);
  B.U(Item.ByteLength);
  Previous := Item;
end;

function AddNumber(A, B: integer): integer;
begin
  if A > MaxInt - B then DamagedIndex;
  Result := A + B;
end;

function UnpackPosting(var D: TFerretDecoder; var Previous: TFerretPosting): TFerretPosting;
var
  Flags: QWord;
  Delta: integer;
begin
  Flags := D.U;
  if Flags shr 2 > MaxInt then DamagedIndex;
  if Flags and 1 <> 0 then
  begin
    Delta := D.Number;
    Result.Document := AddNumber(Previous.Document, Delta);
    if Delta <> 0 then Previous := Default(TFerretPosting);
    Result.Field := AddNumber(Previous.Field, D.Number);
    Previous.Position := 0;
    Previous.ByteStart := 0;
    Result.Position := D.Number;
  end
  else
  begin
    Result.Document := Previous.Document;
    Result.Field := Previous.Field;
    Result.Position := AddNumber(Previous.Position, Flags shr 2);
  end;
  Result.Span := 1;
  if Flags and 2 <> 0 then Result.Span := AddNumber(1, D.Number);
  Result.ByteStart := AddNumber(Previous.ByteStart, D.Number);
  Result.ByteLength := D.Number;
  if (Result.ByteStart < 1) or (Result.ByteLength < 1) then DamagedIndex;
  Previous := Result;
end;

constructor TFerretDictionaryCursor.Create(Segment: TFerretSegment; Ids: boolean; const SeekKey: string);
begin
  inherited Create;
  FSegment := Segment;
  FSegment.NeedSkips;
  FIds := Ids;
  Seek(SeekKey);
end;

procedure TFerretDictionaryCursor.Seek(const SeekKey: string);
var
  L, H, M: integer;
  Skips: TFerretSkips;
begin
  if (Length(FEntries) = 0) or (SeekKey < FEntries[0].Key) or (SeekKey > FEntries[High(FEntries)].Key) then
  begin
    if FIds then Skips := FSegment.FIdSkips
    else
      Skips := FSegment.FTermSkips;
    L := 0;
    H := Length(Skips);
    while L < H do
    begin
      M := L + (H - L) div 2;
      if Skips[M].Key <= SeekKey then L := M + 1
      else
        H := M;
    end;
    FBlock := L - 1;
    if FBlock < 0 then FBlock := 0;
    if FBlock >= Length(Skips) then Exit;
    FEntries := FSegment.DictionaryBlock(Skips[FBlock].Offset, FIds);
    Inc(FBlock);
  end;
  L := 0;
  H := Length(FEntries);
  while L < H do
  begin
    M := L + (H - L) div 2;
    if FEntries[M].Key < SeekKey then L := M + 1
    else
      H := M;
  end;
  FEntry := L;
end;

function TFerretSegment.DictionaryBlock(Offset: int64; Ids: boolean): TFerretDictionaryEntries;
var
  Cached: TFerretCachedDictionary;
  D: TFerretDecoder;
  After: int64;
  I, N: integer;
  Key: string;
  Bytes: int64;
begin
  Key := FCachePrefix + 'd' + IntToStr(Offset);
  if (FCache <> nil) and (FCache.Limit > 0) then
  begin
    Cached := TFerretCachedDictionary(FCache.Find(Key));
    if Cached <> nil then Exit(Cached.Entries);
  end;
  D.Start(ReadFrame(FFile, Offset, After));
  N := D.Number;
  if (N < 1) or (N > BlockEntries) then DamagedIndex;
  Result := nil;
  SetLength(Result, N);
  Cached := nil;
  try
    Bytes := Length(D.Data) + N * 80;
    for I := 0 to N - 1 do
    begin
      Result[I].Key := D.Text;
      if Ids then Result[I].Number := D.Number
      else
      begin
        Result[I].First := D.Fixed(8);
        Result[I].After := D.Fixed(8);
        Result[I].Summary := FSummaryBase + int64(D.Fixed(8));
        Result[I].Count := D.Number;
        if (Result[I].First < HeaderSize) or (Result[I].After < Result[I].First) or (Result[I].After > FFile.Size) or
          (Result[I].Summary < Result[I].After) or (Result[I].Summary > FFile.Size - 8) then DamagedIndex;
      end;
    end;
    D.Finish;
    if (FCache <> nil) and (FCache.Limit > 0) then
    begin
      Cached := TFerretCachedDictionary.Create;
      Cached.Bytes := Bytes;
      Cached.Entries := Result;
      FCache.Put(Key, Cached);
      Cached := nil;
    end;
  finally
    Cached.Free;
  end;
end;

function TFerretDictionaryCursor.Next: boolean;
var
  Skips: TFerretSkips;
begin
  if FIds then Skips := FSegment.FIdSkips
  else
    Skips := FSegment.FTermSkips;
  if FEntry = Length(FEntries) then
  begin
    if FBlock >= Length(Skips) then Exit(False);
    FEntries := FSegment.DictionaryBlock(Skips[FBlock].Offset, FIds);
    FEntry := 0;
    Inc(FBlock);
  end;
  Key := FEntries[FEntry].Key;
  Number := FEntries[FEntry].Number;
  First := FEntries[FEntry].First;
  After := FEntries[FEntry].After;
  Summary := FEntries[FEntry].Summary;
  Count := FEntries[FEntry].Count;
  Inc(FEntry);
  Result := True;
end;

constructor TFerretPostingCursor.Create(FileData: TFerretFile; First, After: int64; Count: integer);
begin
  inherited Create;
  FFile := FileData;
  FOffset := First;
  FAfter := After;
  FTotal := Count;
end;

function TFerretPostingCursor.Next: boolean;
begin
  while FRemaining = 0 do
  begin
    if FDecoder.Data <> '' then FDecoder.Finish;
    if FOffset = FAfter then
    begin
      if FTotal <> 0 then DamagedIndex;
      Exit(False);
    end;
    if FOffset > FAfter then DamagedIndex;
    FDecoder.Start(ReadFrame(FFile, FOffset, FOffset));
    // Summary frames are independent of the position stream used by merging.
    if FDecoder.Number = 1 then
    begin
      FDecoder.Data := '';
      Continue;
    end;
    FRemaining := FDecoder.Number;
    if (FRemaining < 1) or (FRemaining > FTotal) then DamagedIndex;
    FPrevious := Default(TFerretPosting);
  end;
  Item := UnpackPosting(FDecoder, FPrevious);
  Dec(FRemaining);
  Dec(FTotal);
  Result := True;
end;

constructor TFerretSegment.Create(FileData: TFerretFile; const AName: string; Cache: TFerretCache);
var
  D: TFerretDecoder;
  TermOffset, IdOffset, SkipOffset, EndOffset, DeclaredSize: int64;
  Sum: cardinal;
  Header: rawbytestring;
begin
  inherited Create;
  FFile := FileData;
  FCache := Cache;
  FCachePrefix := IntToStr(PtrUInt(Self)) + ':';
  FCachedDocBlock := -1;
  FCachedDeleteBlock := -1;
  Name := AName;
  Header := FFile.ReadBytes(0, HeaderSize);
  if Copy(Header, 1, 8) <> SegmentMagic then DamagedIndex;
  D.Start(Copy(Header, 9, MaxInt));
  CheckVersion(D.Fixed(4));
  DeclaredSize := D.Fixed(8);
  FDocCount := D.Fixed(4);
  FDeleteCount := D.Fixed(4);
  FDocTable := D.Fixed(8);
  FDeletes := D.Fixed(8);
  TermOffset := D.Fixed(8);
  IdOffset := D.Fixed(8);
  SkipOffset := D.Fixed(8);
  Sum := D.Fixed(4);
  FTextBase := D.Fixed(8);
  if (Checksum(Copy(Header, 1, 68) + Copy(Header, 73, 8)) <> Sum) or (FTextBase < HeaderSize) or (FTextBase > FDocTable) or
    (DeclaredSize <> FFile.Size) or (FDocCount < 0) or (FDeleteCount < 0) or (FDocTable < HeaderSize) or (FDeletes <> FDocTable +
    int64(FDocCount) * 12 + ((int64(FDocCount) + 63) div 64) * 8) or (TermOffset < FDeletes + int64(FDeleteCount) * 4 + ((int64(FDeleteCount) + 63) div 64) * 8) or
    (IdOffset < TermOffset) or (SkipOffset < IdOffset) or (SkipOffset > FFile.Size - 8) then DamagedIndex;
  D.Start(ReadFrame(FFile, SkipOffset, EndOffset));
  if EndOffset <> FFile.Size then DamagedIndex;
  FSummaryBase := D.Fixed(8);
  if (FSummaryBase < FDeletes) or (FSummaryBase > TermOffset) then DamagedIndex;
  FFirstNumber := D.Number;
  FLastNumber := D.Number;
  FSkipData := D.Data;
  FSkipPosition := D.Position;
  if FLastNumber < FFirstNumber then DamagedIndex;
end;

procedure TFerretSegment.NeedSkips;
var
  D: TFerretDecoder;
begin
  if FSkipData = '' then Exit;
  D.Start(FSkipData);
  D.Position := FSkipPosition;
  LoadSkips(D, FTermSkips);
  LoadSkips(D, FIdSkips);
  D.Finish;
  FSkipData := '';
end;

procedure TFerretSegment.LoadSkips(var D: TFerretDecoder; var Skips: TFerretSkips);
var
  I, N: integer;
begin
  N := D.Number;
  if N > Length(D.Data) div 9 then DamagedIndex;
  SetLength(Skips, N);
  for I := 0 to N - 1 do
  begin
    Skips[I].Key := D.Text;
    Skips[I].Offset := D.Fixed(8);
    if (Skips[I].Offset < HeaderSize) or (Skips[I].Offset > FFile.Size - 8) then DamagedIndex;
    if (I > 0) and ((Skips[I].Key <= Skips[I - 1].Key) or (Skips[I].Offset <= Skips[I - 1].Offset)) then DamagedIndex;
  end;
end;

procedure TFerretSegment.SetPageCache(Value: TFerretCache);
begin
  FFile.PageCache := Value;
end;

destructor TFerretSegment.Destroy;
begin
  EndQuery;
  FFile.Free;
  inherited Destroy;
end;

procedure TFerretSegment.BeginQuery;
begin
  FDocumentBuffer := TFerretReadBuffer.Create(FFile);
  FTableBuffer := TFerretReadBuffer.Create(FFile);
end;

procedure TFerretSegment.EndQuery;
begin
  FreeAndNil(FDocumentBuffer);
  FreeAndNil(FTableBuffer);
end;

function TFerretSegment.TableEntry(Deletion: boolean; Slot: integer): TFerretDecoder;
var
  Block, Width, Count: integer;
  Offset, After: int64;
begin
  Block := Slot div 64;
  if Deletion then
  begin
    Count := FDeleteCount;
    Width := 4;
    Offset := FDeletes;
  end
  else
  begin
    Count := FDocCount;
    Width := 12;
    Offset := FDocTable;
  end;
  if (Slot < 0) or (Slot >= Count) then DamagedIndex;
  Inc(Offset, int64(Block) * (64 * Width + 8));
  if Deletion then
  begin
    if FCachedDeleteBlock <> Block then
    begin
      FDeleteBlockData := ReadFrame(FFile, Offset, After, FTableBuffer);
      FCachedDeleteBlock := Block;
    end;
    Result.Start(FDeleteBlockData);
  end
  else
  begin
    if FCachedDocBlock <> Block then
    begin
      FDocBlockData := ReadFrame(FFile, Offset, After, FTableBuffer);
      FCachedDocBlock := Block;
    end;
    Result.Start(FDocBlockData);
  end;
  Count := Count - Block * 64;
  if Count > 64 then Count := 64;
  if Length(Result.Data) <> Count * Width then DamagedIndex;
  Result.Position := 1 + (Slot mod 64) * Width;
end;

function TFerretSegment.DocumentNumber(Slot: integer): integer;
var
  D: TFerretDecoder;
  Value: QWord;
begin
  D := TableEntry(False, Slot);
  Value := D.Fixed(4);
  if Value > MaxInt then DamagedIndex;
  Result := Value;
end;

function TFerretSegment.DocumentOffset(Slot: integer): int64;
var
  D: TFerretDecoder;
begin
  D := TableEntry(False, Slot);
  D.Fixed(4);
  Result := D.Fixed(8);
  if (Result < HeaderSize) or (Result >= FDocTable) then DamagedIndex;
end;

function TextOffset(FileData: TFerretFile; Offset: int64): int64;
var
  D: TFerretDecoder;
begin
  D.Start(FileData.ReadBytes(Offset, 8));
  Result := D.Fixed(8);
end;

function TFerretSegment.DocumentData(Slot: integer): rawbytestring;
var
  Offset, After: int64;
  Metadata, TextData: rawbytestring;
begin
  Offset := DocumentOffset(Slot);
  Metadata := ReadFrame(FFile, Offset, After);
  Offset := FTextBase + TextOffset(FFile, After);
  TextData := ReadFrame(FFile, Offset, After);
  if After > FDocTable then DamagedIndex;
  Result := FrameBytes(Metadata, False) + FrameBytes(TextData, False);
end;

function TFerretSegment.Document(Number: integer; WithText: boolean): TFerretDocument;
var
  L, H, M: integer;
  Offset, After: int64;
begin
  Result := nil;
  if (FDocCount = 0) or (Number < FFirstNumber) or (Number > FLastNumber) then Exit;
  L := 0;
  H := FDocCount;
  if int64(FLastNumber) - FFirstNumber + 1 = FDocCount then
  begin
    L := Number - FFirstNumber;
    H := L;
  end;
  while L < H do
  begin
    M := L + (H - L) div 2;
    if DocumentNumber(M) < Number then L := M + 1
    else
      H := M;
  end;
  if (L < FDocCount) and (DocumentNumber(L) = Number) then
  begin
    Offset := DocumentOffset(L);
    Result := DecodeDocumentInfo(ReadFrame(FFile, Offset, After, FDocumentBuffer));
    try
      if WithText then
      begin
        Offset := FTextBase + TextOffset(FFile, After);
        DecodeDocumentText(Result, ReadFrame(FFile, Offset, After));
      end;
      if After > FDocTable then DamagedIndex;
    except
      Result.Free;
      raise;
    end;
  end;
end;

function TFerretSegment.FindDocument(const Id: string): integer;
var
  Cursor: TFerretDictionaryCursor;
begin
  Result := -1;
  Cursor := TFerretDictionaryCursor.Create(Self, True, Id);
  try
    while Cursor.Next do
    begin
      if Cursor.Key = Id then Exit(Cursor.Number);
      if Cursor.Key > Id then Exit;
    end;
  finally
    Cursor.Free;
  end;
end;

function TFerretSegment.DeletionNumber(Slot: integer): integer;
var
  D: TFerretDecoder;
begin
  D := TableEntry(True, Slot);
  Result := D.Fixed(4);
  if Result < 0 then DamagedIndex;
end;

function TFerretSegment.Deleted(Number: integer): boolean;
var
  L, H, M, Value: integer;
begin
  L := 0;
  H := FDeleteCount;
  while L < H do
  begin
    M := L + (H - L) div 2;
    Value := DeletionNumber(M);
    if Value = Number then Exit(True);
    if Value < Number then L := M + 1
    else
      H := M;
  end;
  Result := False;
end;

function TFerretSegment.ReadBlockIndex(Offset: int64): TFerretTermBlocks;
var
  D: TFerretDecoder;
  I, J, N, FieldCount: integer;
  After: int64;
begin
  D.Start(ReadFrame(FFile, Offset, After));
  N := D.Number;
  if N > Length(D.Data) div 26 then DamagedIndex;
  Result := nil;
  SetLength(Result, N);
  for I := 0 to N - 1 do
  begin
    Result[I].Last := D.Number;
    Result[I].Range := Result[I].Last div 128;
    if (I > 0) and (Result[I].Range <= Result[I - 1].Range) then DamagedIndex;
    for J := 0 to 3 do Result[I].Mask[J] := D.Fixed(4);
    Result[I].Offset := FSummaryBase + int64(D.Fixed(8));
    Result[I].Segment := Self;
    if (Result[I].Offset < FSummaryBase) or (Result[I].Offset >= Offset) then DamagedIndex;
    FieldCount := D.Number;
    if FieldCount > Length(D.Data) div 10 then DamagedIndex;
    SetLength(Result[I].Bounds, FieldCount);
    for J := 0 to FieldCount - 1 do
    begin
      Result[I].Bounds[J].Name := D.Text;
      Result[I].Bounds[J].Frequency := D.Float;
      Result[I].Bounds[J].WordCount := D.Number;
    end;
  end;
  D.Finish;
end;

function TFerretSegment.FindTermSummary(const Term: string): int64;
var
  Cursor: TFerretDictionaryCursor;
begin
  Result := -1;
  Cursor := TFerretDictionaryCursor.Create(Self, False, Term);
  try
    while Cursor.Next do
    begin
      if Cursor.Key > Term then Exit;
      if Cursor.Key = Term then Exit(Cursor.Summary);
    end;
  finally
    Cursor.Free;
  end;
end;

function TFerretSegment.TermBlocks(const Term: string; Offset: int64): TFerretTermBlocks;
var
  I, J: integer;
  Key: string;
  Cached: TFerretCachedSkips;
begin
  Result := nil;
  Key := FCachePrefix + 's' + Term;
  if (FCache <> nil) and (FCache.Limit > 0) then
  begin
    Cached := TFerretCachedSkips(FCache.Find(Key));
    if Cached <> nil then Exit(Cached.Blocks);
  end;
  if Offset < 0 then Offset := FindTermSummary(Term);
  if Offset < 0 then Exit;
  Result := ReadBlockIndex(Offset);
  if (FCache <> nil) and (FCache.Limit > 0) then
  begin
    Cached := TFerretCachedSkips.Create;
    Cached.Blocks := Result;
    Cached.Bytes := Length(Result) * (SizeOf(TFerretTermBlock) + 32);
    for I := 0 to High(Result) do
      for J := 0 to High(Result[I].Bounds) do
        Inc(Cached.Bytes, SizeOf(TFerretScoreBound) + Length(Result[I].Bounds[J].Name) + 32);
    FCache.Put(Key, Cached);
  end;
end;

function TFerretSegment.ReadBlock(Offset: int64; Buffer: TFerretReadBuffer): TFerretTermDocuments;
var
  Cached: TFerretCachedBlock;
  Key: string;
  D: TFerretDecoder;
  After, PositionOffset: int64;
  I, J, N, Number, Schema, WeightKind: integer;
  Names: array of string;
  Bytes: int64;
begin
  Key := FCachePrefix + 'b' + IntToStr(Offset);
  if (FCache <> nil) and (FCache.Limit > 0) then
  begin
    Cached := TFerretCachedBlock(FCache.Find(Key));
    if Cached <> nil then Exit(Cached.Documents);
  end;
  D.Start(ReadFrame(FFile, Offset, After, Buffer));
  if D.Number <> 1 then DamagedIndex;
  N := D.Number;
  if N > Length(D.Data) div 2 then DamagedIndex;
  SetLength(Names, N);
  for I := 0 to N - 1 do Names[I] := D.Text;
  N := D.Number;
  if (N < 1) or (N > 128) then DamagedIndex;
  Result := nil;
  SetLength(Result, N);
  Number := 0;
  PositionOffset := 0;
  Cached := nil;
  try
    Bytes := N * (SizeOf(TFerretTermDocument) + 32);
    for I := 0 to N - 1 do
    begin
      Number := AddNumber(Number, D.Number);
      Result[I].Number := Number;
      Inc(PositionOffset, D.U);
      if (PositionOffset < HeaderSize) or (PositionOffset >= Offset) then DamagedIndex;
      Result[I].Offset := PositionOffset;
      Result[I].Segment := Self;
      J := D.Number;
      if J > Length(D.Data) div 5 then DamagedIndex;
      SetLength(Result[I].Fields, J);
      Inc(Bytes, J * (SizeOf(TFerretFieldFrequency) + 32));
      for J := 0 to High(Result[I].Fields) do
      begin
        Result[I].Fields[J].Field := D.Number;
        Result[I].Fields[J].Count := D.Number;
        Schema := D.Number;
        if Schema >= Length(Names) then DamagedIndex;
        Result[I].Fields[J].Name := Names[Schema];
        WeightKind := D.Number;
        case WeightKind of
          0: Result[I].Fields[J].Weight := 1;
          1: Result[I].Fields[J].Weight := 3;
          2: Result[I].Fields[J].Weight := D.Float;
          else
            DamagedIndex;
        end;
        Result[I].Fields[J].WordCount := D.Number;
        if Result[I].Fields[J].Count < 1 then DamagedIndex;
        Inc(Bytes, Length(Result[I].Fields[J].Name));
      end;
    end;
    D.Finish;
    if (FCache <> nil) and (FCache.Limit > 0) then
    begin
      Cached := TFerretCachedBlock.Create;
      Cached.Bytes := Bytes;
      Cached.Documents := Result;
      FCache.Put(Key, Cached);
      Cached := nil;
    end;
  finally
    Cached.Free;
  end;
end;

function TFerretSegment.Positions(const Source: TFerretTermDocument; Buffer: TFerretReadBuffer): TFerretPostings;
var
  Data, Key: string;
  After: int64;
  D: TFerretDecoder;
  Previous: TFerretPosting;
  I, N: integer;
  Offset: int64;
  Cached: TFerretCachedPostings;
begin
  Offset := Source.Offset;
  Key := FCachePrefix + 'p' + IntToStr(Offset);
  if (FCache <> nil) and (FCache.Limit > 0) then
  begin
    Cached := TFerretCachedPostings(FCache.Find(Key));
    if Cached <> nil then Exit(Cached.Items);
  end;
  Data := ReadFrame(FFile, Offset, After, Buffer);
  D.Start(Data);
  if D.Number <> 0 then DamagedIndex;
  N := D.Number;
  if N > Length(Data) div 3 then DamagedIndex;
  Result := nil;
  SetLength(Result, N);
  Previous := Default(TFerretPosting);
  for I := 0 to N - 1 do Result[I] := UnpackPosting(D, Previous);
  D.Finish;
  if (FCache <> nil) and (FCache.Limit > 0) then
  begin
    Cached := TFerretCachedPostings.Create;
    Cached.Items := Result;
    Cached.Bytes := Length(Result) * SizeOf(TFerretPosting) + 32;
    FCache.Put(Key, Cached);
  end;
end;

function TFerretSegment.PostingCursor(const Term: string): TFerretPostingCursor;
var
  Cursor: TFerretDictionaryCursor;
begin
  Result := nil;
  Cursor := TFerretDictionaryCursor.Create(Self, False, Term);
  try
    while Cursor.Next do
    begin
      if Cursor.Key > Term then Exit;
      if Cursor.Key = Term then Exit(TFerretPostingCursor.Create(FFile, Cursor.First, Cursor.After, Cursor.Count));
    end;
  finally
    Cursor.Free;
  end;
end;

procedure TFerretSegment.PrefixTerms(const Prefix: string; Terms: TStrings);
var
  Cursor: TFerretDictionaryCursor;
begin
  Cursor := TFerretDictionaryCursor.Create(Self, False, Prefix);
  try
    while Cursor.Next do
    begin
      if Cursor.Key < Prefix then Continue;
      if Copy(Cursor.Key, 1, Length(Prefix)) <> Prefix then Break;
      Terms.Add(Cursor.Key);
    end;
  finally
    Cursor.Free;
  end;
end;

function TFerretSegment.FuzzyTerms(const word: string; Limit: integer; Terms: TStrings): integer;
var
  Cursor: TFerretDictionaryCursor;
  Seek, Skip: string;
begin
  Result := 0;
  Seek := ' ';
  Cursor := TFerretDictionaryCursor.Create(Self, False, Seek);
  try
    while Cursor.Next do
    begin
      if Cursor.Key < Seek then Continue;
      Inc(Result);
      if WordDistance(word, Cursor.Key, Limit, Skip) <= Limit then Terms.Add(Cursor.Key);
      if Skip = '' then Continue;
      Seek := Skip;
      Cursor.Seek(Seek);
    end;
  finally
    Cursor.Free;
  end;
end;

constructor TFerretSegmentWriter.Create(const Name: string);
var
  Blank: rawbytestring;
begin
  inherited Create;
  FWorkName := Name;
  if Name = '' then
  begin
    FFile := TFerretFile.Memory;
    FDocTable := TFerretFile.Memory;
    FTerms := TFerretFile.Memory;
    FIds := TFerretFile.Memory;
    FTextData := TFerretFile.Memory;
    FSummaryFile := TFerretFile.Memory;
  end
  else
  begin
    FFile := TFerretFile.Create(Name, True);
    FDocTable := TFerretFile.Create(Name + '.docs', True);
    FTerms := TFerretFile.Create(Name + '.terms', True);
    FIds := TFerretFile.Create(Name + '.ids', True);
    FTextData := TFerretFile.Create(Name + '.text', True);
    FSummaryFile := TFerretFile.Create(Name + '.summaries', True);
  end;
  FFile.BlockProtected := True;
  FTerms.BlockProtected := True;
  FIds.BlockProtected := True;
  FSummaryFile.BlockProtected := True;
  FTermBlock := TFerretBuffer.Create;
  FIdBlock := TFerretBuffer.Create;
  FPostingBytes := TFerretBuffer.Create;
  FFrameHeader := TFerretBuffer.Create;
  FSummary := TFerretBuffer.Create;
  FBlockIndex := TFerretBuffer.Create;
  FRecord := TFerretBuffer.Create;
  FDeleteBlock := TFerretBuffer.Create;
  Blank := StringOfChar(#0, HeaderSize);
  FFile.WriteBytes(Blank);
end;

destructor TFerretSegmentWriter.Destroy;
begin
  FFile.Free;
  FDocTable.Free;
  FTerms.Free;
  FIds.Free;
  FTextData.Free;
  FSummaryFile.Free;
  if FWorkName <> '' then
  begin
    DeleteFile(FWorkName + '.docs');
    DeleteFile(FWorkName + '.terms');
    DeleteFile(FWorkName + '.ids');
    DeleteFile(FWorkName + '.text');
    DeleteFile(FWorkName + '.summaries');
  end;
  FTermBlock.Free;
  FIdBlock.Free;
  FPostingBytes.Free;
  FFrameHeader.Free;
  FSummary.Free;
  FBlockIndex.Free;
  FRecord.Free;
  FDeleteBlock.Free;
  inherited Destroy;
end;

procedure TFerretSegmentWriter.AddDocument(Number: integer; const Data: rawbytestring);
var
  B: TFerretBuffer;
  Doc: TFerretDocument;
  D: TFerretDecoder;
  MetadataSize: integer;
begin
  if FDocCount = Length(FDocNumbers) then
  begin
    SetLength(FDocNumbers, FDocCount * 2 + 16);
    SetLength(FDocuments, Length(FDocNumbers));
  end;
  Doc := DecodeDocument(Data, False);
  try
    FDocNumbers[FDocCount] := Number;
    FDocuments[FDocCount] := Doc.Fields;
  finally
    Doc.Free;
  end;
  B := TFerretBuffer.Create;
  try
    B.Fixed(Number, 4);
    B.Fixed(FFile.Position, 8);
    FDocTable.WriteBytes(B.Data);
    D.Start(Data);
    MetadataSize := D.Fixed(4) + 8;
    if MetadataSize > Length(Data) - 8 then DamagedIndex;
    FFile.WriteBytes(Copy(Data, 1, MetadataSize));
    B.Clear;
    B.Fixed(FTextData.Position, 8);
    FFile.WriteBytes(B.Data);
    FTextData.WriteBytes(Copy(Data, MetadataSize + 1, MaxInt));
    Inc(FDocCount);
  finally
    B.Free;
  end;
end;

function TFerretSegmentWriter.DocumentFields(Number: integer): TFerretFields;
var
  L, H, M: integer;
begin
  L := 0;
  H := FDocCount;
  while L < H do
  begin
    M := L + (H - L) div 2;
    if FDocNumbers[M] < Number then L := M + 1
    else
      H := M;
  end;
  if (L = FDocCount) or (FDocNumbers[L] <> Number) then DamagedIndex;
  Result := FDocuments[L];
end;

procedure TFerretSegmentWriter.CopyFile(Source: TFerretFile; TableWidth: integer);
var
  Offset: int64;
  Count: integer;
begin
  Offset := 0;
  while Offset < Source.Size do
  begin
    Count := 65536;
    if TableWidth <> 0 then Count := 64 * TableWidth;
    if Source.Size - Offset < Count then Count := Source.Size - Offset;
    if TableWidth = 0 then FFile.WriteBytes(Source.ReadBytes(Offset, Count))
    else
      WriteFrame(FFile, Source.ReadBytes(Offset, Count));
    Inc(Offset, Count);
  end;
end;

procedure TFerretSegmentWriter.EndDocuments;
var
  Padding: integer;
begin
  FTextBase := FFile.Position;
  CopyFile(FTextData);
  // Table reads must not inflate the last stored-text block.
  Padding := (65536 - FFile.Position mod 65536) mod 65536;
  if Padding > 0 then FFile.WriteBytes(StringOfChar(#0, Padding));
  FDocOffset := FFile.Position;
  CopyFile(FDocTable, 12);
  FDeleteOffset := FFile.Position;
end;

procedure TFerretSegmentWriter.AddDeletion(Number: integer);
begin
  FDeleteBlock.Fixed(Number, 4);
  Inc(FDeleteCount);
  if FDeleteBlock.Count = 256 then FlushDeletes;
end;

procedure TFerretSegmentWriter.FlushDeletes;
begin
  if FDeleteBlock.Count = 0 then Exit;
  WriteFrame(FFile, FDeleteBlock.Data);
  FDeleteBlock.Clear;
end;

procedure TFerretSegmentWriter.BeginTerm(const Term: string);
begin
  FlushDeletes;
  FTerm := Term;
  FPostingCount := 0;
  FPostingStart := FFile.Position;
  FSummaryNumber := 0;
  FSummaryOffset := 0;
  FBlockRange := -1;
  FBlockCount := 0;
  FBlockDocuments := 0;
  FBlockIndex.Clear;
  FSummary.Clear;
end;

procedure TFerretSegmentWriter.FlushSummary;
var
  I: integer;
  B: TFerretBuffer;
  Data: rawbytestring;
begin
  if FBlockDocuments = 0 then Exit;
  FBlockIndex.U(FBlockLast);
  for I := 0 to 3 do FBlockIndex.Fixed(FBlockMask[I], 4);
  FBlockIndex.Fixed(FSummaryFile.Position, 8);
  FBlockIndex.U(Length(FBlockBounds));
  for I := 0 to High(FBlockBounds) do
  begin
    FBlockIndex.Text(FBlockBounds[I].Name);
    FBlockIndex.Float(FBlockBounds[I].Frequency);
    FBlockIndex.U(FBlockBounds[I].WordCount);
  end;
  B := FRecord;
  B.Clear;
  B.U(1);
  B.U(Length(FBlockBounds));
  for I := 0 to High(FBlockBounds) do B.Text(FBlockBounds[I].Name);
  B.U(FBlockDocuments);
  Data := FSummary.Data;
  if Data <> '' then B.Bytes(Data[1], Length(Data));
  WriteFrame(FSummaryFile, B.Data);
  FSummary.Clear;
  FSummaryNumber := 0;
  FSummaryOffset := 0;
  FBlockDocuments := 0;
  FBlockBounds := nil;
  FillChar(FBlockMask, SizeOf(FBlockMask), 0);
  Inc(FBlockCount);
end;

procedure TFerretSegmentWriter.AddSummary(Number: integer; Offset: int64; const Fields: array of TFerretFieldFrequency);
var
  I, J, N: integer;
  Value: double;
begin
  if Number div 128 <> FBlockRange then
  begin
    FlushSummary;
    FBlockRange := Number div 128;
  end;
  FBlockLast := Number;
  I := Number mod 128;
  FBlockMask[I div 32] := FBlockMask[I div 32] or (cardinal(1) shl (I mod 32));
  FSummary.U(Number - FSummaryNumber);
  FSummaryNumber := Number;
  FSummary.U(Offset - FSummaryOffset);
  FSummaryOffset := Offset;
  FSummary.U(Length(Fields));
  for I := 0 to Length(Fields) - 1 do
  begin
    J := Fields[I].Field;
    FSummary.U(J);
    FSummary.U(Fields[I].Count);
    N := 0;
    while (N < Length(FBlockBounds)) and (FBlockBounds[N].Name <> Fields[I].Name) do Inc(N);
    if N = Length(FBlockBounds) then
    begin
      SetLength(FBlockBounds, N + 1);
      FBlockBounds[N].Name := Fields[I].Name;
      FBlockBounds[N].WordCount := Fields[I].WordCount;
    end;
    FSummary.U(N);
    if Fields[I].Weight = 1 then FSummary.U(0)
    else if Fields[I].Weight = 3 then FSummary.U(1)
    else
    begin
      FSummary.U(2);
      FSummary.Float(Fields[I].Weight);
    end;
    FSummary.U(Fields[I].WordCount);
    Value := Fields[I].Weight * Fields[I].Count;
    if Value > FBlockBounds[N].Frequency then FBlockBounds[N].Frequency := Value;
    if Fields[I].WordCount < FBlockBounds[N].WordCount then FBlockBounds[N].WordCount := Fields[I].WordCount;
  end;
  Inc(FBlockDocuments);
end;

procedure TFerretSegmentWriter.FlushPostings;
var
  B: TFerretBuffer;
  I, J: integer;
  Fields: TFerretFields;
begin
  if FChunkCount = 0 then Exit;
  Fields := DocumentFields(FDocNumber);
  for I := 0 to FDocFieldCount - 1 do
  begin
    J := FDocFields[I].Field;
    FDocFields[I].Name := Fields[J].Name;
    FDocFields[I].Weight := Fields[J].Weight;
    FDocFields[I].WordCount := Fields[J].WordCount;
  end;
  AddSummary(FDocNumber, FFile.Position, Slice(FDocFields, FDocFieldCount));
  B := FRecord;
  B.Clear;
  B.U(0);
  B.U(FChunkCount);
  FFrameHeader.Clear;
  FFrameHeader.Fixed(B.Count + FPostingBytes.Count, 4);
  FFrameHeader.Fixed(0, 4);
  FFrameHeader.WriteTo(FFile);
  B.WriteTo(FFile);
  FPostingBytes.WriteTo(FFile);
  FPostingBytes.Clear;
  FChunkCount := 0;
  FDocFieldCount := 0;
  FPrevious := Default(TFerretPosting);
end;

procedure TFerretSegmentWriter.AddPosting(const Item: TFerretPosting);
var
  N: integer;
begin
  if (FChunkCount > 0) and (Item.Document <> FDocNumber) then FlushPostings;
  if (FChunkCount > 0) and (ComparePosting(Item, FPrevious) = 0) then Exit;
  FDocNumber := Item.Document;
  N := FDocFieldCount;
  if (N = 0) or (FDocFields[N - 1].Field <> Item.Field) then
  begin
    if N = Length(FDocFields) then SetLength(FDocFields, N + 4);
    FDocFields[N].Count := 0;
    FDocFields[N].Field := Item.Field;
    Inc(N);
    FDocFieldCount := N;
  end;
  Inc(FDocFields[N - 1].Count);
  PackPosting(FPostingBytes, Item, FPrevious);
  Inc(FPostingCount);
  Inc(FChunkCount);
end;

procedure TFerretSegmentWriter.EndTerm;
var
  B: TFerretBuffer;
  Data: rawbytestring;
  After, Summary: int64;
begin
  FlushPostings;
  FlushSummary;
  After := FFile.Position;
  B := FRecord;
  B.Clear;
  B.U(FBlockCount);
  Data := FBlockIndex.Data;
  if Data <> '' then B.Bytes(Data[1], Length(Data));
  Summary := FSummaryFile.Position;
  WriteFrame(FSummaryFile, B.Data);
  if FPostingCount > 0 then AddEntry(False, FTerm, FPostingStart, After, FPostingCount, Summary);
end;

procedure TFerretSegmentWriter.FlushDictionary(Ids: boolean);
var
  B, Block: TFerretBuffer;
  FileData: TFerretFile;
  Count: integer;
  Data: rawbytestring;
begin
  if Ids then
  begin
    Block := FIdBlock;
    FileData := FIds;
    Count := FIdBlockCount;
  end
  else
  begin
    Block := FTermBlock;
    FileData := FTerms;
    Count := FTermBlockCount;
  end;
  if Count = 0 then Exit;
  B := TFerretBuffer.Create;
  try
    B.U(Count);
    Data := Block.Data;
    B.Bytes(Data[1], Length(Data));
    WriteFrame(FileData, B.Data);
    Block.Clear;
    if Ids then FIdBlockCount := 0
    else
      FTermBlockCount := 0;
  finally
    B.Free;
  end;
end;

procedure TFerretSegmentWriter.AddEntry(Ids: boolean; const Key: string; First, After: int64; Count: integer; Summary: int64);
var
  Block: TFerretBuffer;
  N: integer;
begin
  if Ids then
  begin
    if FIdBlockCount = 0 then
    begin
      N := Length(FIdSkips);
      SetLength(FIdSkips, N + 1);
      FIdSkips[N].Key := Key;
      FIdSkips[N].Offset := FIds.Position;
    end;
    Block := FIdBlock;
    Inc(FIdBlockCount);
  end
  else
  begin
    if FTermBlockCount = 0 then
    begin
      N := Length(FTermSkips);
      SetLength(FTermSkips, N + 1);
      FTermSkips[N].Key := Key;
      FTermSkips[N].Offset := FTerms.Position;
    end;
    Block := FTermBlock;
    Inc(FTermBlockCount);
  end;
  Block.Text(Key);
  if Ids then Block.U(Count)
  else
  begin
    Block.Fixed(First, 8);
    Block.Fixed(After, 8);
    Block.Fixed(Summary, 8);
    Block.U(Count);
  end;
  if (Ids and (FIdBlockCount = BlockEntries)) or (not Ids and (FTermBlockCount = BlockEntries)) then FlushDictionary(Ids);
end;

procedure TFerretSegmentWriter.AddId(const Id: string; Number: integer);
begin
  AddEntry(True, Id, 0, 0, Number);
end;

procedure TFerretSegmentWriter.SaveSkips(B: TFerretBuffer; const Skips: TFerretSkips; Base: int64);
var
  I: integer;
begin
  B.U(Length(Skips));
  for I := 0 to High(Skips) do
  begin
    B.Text(Skips[I].Key);
    B.Fixed(Base + Skips[I].Offset, 8);
  end;
end;

function TFerretSegmentWriter.Finish: TFerretSegment;
var
  B: TFerretBuffer;
  SkipOffset, EndOffset: int64;
  Data: rawbytestring;
  FileData: TFerretFile;
begin
  FlushDeletes;
  FlushDictionary(False);
  FlushDictionary(True);
  FSummaryBase := FFile.Position;
  CopyFile(FSummaryFile);
  FTermOffset := FFile.Position;
  CopyFile(FTerms);
  FIdOffset := FFile.Position;
  CopyFile(FIds);
  SkipOffset := FFile.Position;
  B := TFerretBuffer.Create;
  try
    B.Fixed(FSummaryBase, 8);
    if FDocCount = 0 then
    begin
      B.U(0);
      B.U(0);
    end
    else
    begin
      B.U(FDocNumbers[0]);
      B.U(FDocNumbers[FDocCount - 1]);
    end;
    SaveSkips(B, FTermSkips, FTermOffset);
    SaveSkips(B, FIdSkips, FIdOffset);
    WriteFrame(FFile, B.Data);
    EndOffset := FFile.Position;
    B.Clear;
    B.Bytes(SegmentMagic[1], 8);
    B.Fixed(3, 4);
    B.Fixed(EndOffset, 8);
    B.Fixed(FDocCount, 4);
    B.Fixed(FDeleteCount, 4);
    B.Fixed(FDocOffset, 8);
    B.Fixed(FDeleteOffset, 8);
    B.Fixed(FTermOffset, 8);
    B.Fixed(FIdOffset, 8);
    B.Fixed(SkipOffset, 8);
    Data := B.Data;
    B.Clear;
    B.Fixed(FTextBase, 8);
    Data := Data + B.Data;
    B.Clear;
    B.Bytes(Data[1], 68);
    B.Fixed(Checksum(Data), 4);
    B.Fixed(FTextBase, 8);
    if B.Count <> HeaderSize then DamagedIndex;
    FFile.Seek(0);
    FFile.WriteBytes(B.Data);
    FileData := FFile.CompressFile(FWorkName, FTextBase, FDocOffset);
    FFile.Free;
    FFile := FileData;
    FileData := FFile;
    FFile := nil;
    Result := TFerretSegment.Create(FileData, ExtractFileName(FWorkName));
  finally
    B.Free;
  end;
end;

end.
