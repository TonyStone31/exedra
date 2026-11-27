unit FerretCache;

{$mode objfpc}{$H+}
// Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.

interface

uses FerretCRC;

type
  TFerretCacheItem = class
    Bytes: int64;
    Previous, Next, HashNext: TFerretCacheItem;
    Key: string;
  end;

  TFerretCachedBytes = class(TFerretCacheItem)
    Data: rawbytestring;
  end;

  { One byte budget covers decoded dictionaries, summaries and hot position blocks. }
  TFerretCache = class
  private
    FBuckets: array[0..4095] of TFerretCacheItem;
    FFirst, FLast: TFerretCacheItem;
    FBytes, FLimit: int64;
    procedure Detach(Item: TFerretCacheItem);
    procedure Trim;
    procedure RemoveHash(Item: TFerretCacheItem);
    function Bucket(const Key: string): integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure SetLimit(Value: int64);
    function Find(const Key: string): TFerretCacheItem;
    procedure Put(const Key: string; Item: TFerretCacheItem);
    function ReadBytes(const Key: string): rawbytestring;
    procedure SaveBytes(const Key: string; const Data: rawbytestring);
    property Bytes: int64 read FBytes;
    property Limit: int64 read FLimit;
  end;

implementation

constructor TFerretCache.Create;
begin
  inherited Create;
  FLimit := 16 * 1024 * 1024;
end;

destructor TFerretCache.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TFerretCache.Detach(Item: TFerretCacheItem);
begin
  if Item.Previous <> nil then Item.Previous.Next := Item.Next
  else
    FFirst := Item.Next;
  if Item.Next <> nil then Item.Next.Previous := Item.Previous
  else
    FLast := Item.Previous;
end;

procedure TFerretCache.Trim;
var
  Item: TFerretCacheItem;
begin
  while (FBytes > FLimit) and (FLast <> nil) do
  begin
    Item := FLast;
    Detach(Item);
    RemoveHash(Item);
    Dec(FBytes, Item.Bytes);
    Item.Free;
  end;
end;

procedure TFerretCache.Clear;
var
  Item: TFerretCacheItem;
begin
  while FFirst <> nil do
  begin
    Item := FFirst;
    FFirst := Item.Next;
    Item.Free;
  end;
  FLast := nil;
  FBytes := 0;
  FillChar(FBuckets, SizeOf(FBuckets), 0);
end;

procedure TFerretCache.SetLimit(Value: int64);
begin
  FLimit := Value;
  Trim;
end;

function TFerretCache.Bucket(const Key: string): integer;
begin
  Result := FerretCRC32(0, pbyte(PChar(Key)), Length(Key)) and High(FBuckets);
end;

procedure TFerretCache.RemoveHash(Item: TFerretCacheItem);
var
  Previous, Current: TFerretCacheItem;
  Slot: integer;
begin
  Slot := Bucket(Item.Key);
  Previous := nil;
  Current := FBuckets[Slot];
  while Current <> Item do
  begin
    Previous := Current;
    Current := Current.HashNext;
  end;
  if Previous = nil then FBuckets[Slot] := Item.HashNext
  else
    Previous.HashNext := Item.HashNext;
end;

function TFerretCache.Find(const Key: string): TFerretCacheItem;
begin
  if FLimit = 0 then Exit(nil);
  Result := FBuckets[Bucket(Key)];
  while (Result <> nil) and (Result.Key <> Key) do Result := Result.HashNext;
  if Result = nil then Exit;
  Detach(Result);
  Result.Previous := nil;
  Result.Next := FFirst;
  if FFirst <> nil then FFirst.Previous := Result
  else
    FLast := Result;
  FFirst := Result;
end;

procedure TFerretCache.Put(const Key: string; Item: TFerretCacheItem);
var
  Old: TFerretCacheItem;
begin
  Old := Find(Key);
  if Old <> nil then
  begin
    Detach(Old);
    RemoveHash(Old);
    Dec(FBytes, Old.Bytes);
    Old.Free;
  end;
  Item.Key := Key;
  Inc(Item.Bytes, Length(Key) + 96);
  if Item.Bytes > FLimit then
  begin
    Item.Free;
    Exit;
  end;
  Item.Next := FFirst;
  if FFirst <> nil then FFirst.Previous := Item
  else
    FLast := Item;
  FFirst := Item;
  Item.HashNext := FBuckets[Bucket(Key)];
  FBuckets[Bucket(Key)] := Item;
  Inc(FBytes, Item.Bytes);
  Trim;
end;

function TFerretCache.ReadBytes(const Key: string): rawbytestring;
var
  Item: TFerretCacheItem;
begin
  Item := Find(Key);
  Result := '';
  if Item <> nil then Result := TFerretCachedBytes(Item).Data;
end;

procedure TFerretCache.SaveBytes(const Key: string; const Data: rawbytestring);
var
  Item: TFerretCachedBytes;
begin
  if Length(Data) + Length(Key) + 96 > FLimit then Exit;
  Item := TFerretCachedBytes.Create;
  Item.Data := Data;
  Item.Bytes := Length(Data);
  Put(Key, Item);
end;

end.
