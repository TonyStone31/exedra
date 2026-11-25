unit DeskPictures;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

const
  PictureByteBudget = 32 * 1024 * 1024;
  PictureDecodedBudget = 192 * 1024 * 1024;
  MaxPicturePixels = 4 * 1024 * 1024;
  MaxPictureSide = 4096;
  MaxPictureEntries = 256;
  PictureRetryDelay = 60000;

type
  TPictureDropped = procedure(const Path: string) of object;

  TPictureEntry = class(TBytesStream)
  public
    Used, RetryAt: QWord;
    Pending: boolean;
    DecodedBytes: int64;
    destructor Destroy; override;
  end;

  TPictureCache = class
  private
    Entries, Dropped: TStringList;
    Clock: QWord;
    Dropping: boolean;
    procedure Touch(Entry: TPictureEntry);
    procedure Trim;
    procedure DeliverDrops;
    procedure Drop(I: integer);
  public
    OnDrop: TPictureDropped;
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function IndexOf(const Path: string): integer;
    function Read(const Path: string): TPictureEntry;
    function BeginFetch(const Path: string): boolean;
    function Complete(const Path: string; const Bytes: TBytes): boolean;
    procedure Failed(const Path: string);
    function ByteSize: int64;
    function DecodedSize: int64;
    function Count: integer;
  end;

{ Check dimensions before any decoder allocates its canvas. }
function PictureCost(const Bytes: TBytes): int64;

implementation

uses
  Types, FPImage, FPReadPNG, FPReadJPEG, FPReadGIF, FPReadBMP, FPReadWebP, DeskNet;

function GifSize(const Bytes: TBytes): TPoint;
var
  P, W, H, Frames, X, Y: integer;

  function ByteAt(I: integer): byte;
  begin
    if (I < 0) or (I >= Length(Bytes)) then raise EReadError.Create('Truncated picture.');
    Result := Bytes[I];
  end;

  function WordAt(I: integer): integer;
  begin
    Result := ByteAt(I) + integer(ByteAt(I + 1)) * 256;
  end;

  procedure SkipBlocks;
  var
    N: integer;
  begin
    repeat
      N := ByteAt(P);
      Inc(P, N + 1);
    until N = 0;
  end;

begin
  Result := Point(WordAt(6), WordAt(8));
  P := 13;
  if ByteAt(10) and $80 <> 0 then Inc(P, 3 * (1 shl ((ByteAt(10) and 7) + 1)));
  Frames := 0;
  while P < Length(Bytes) do
    case ByteAt(P) of
      $3B:
      begin
        if Frames = 0 then Result := Point(0, 0);
        Exit;
      end;
      $21:
      begin
        Inc(P, 2);
        SkipBlocks;
      end;
      $2C:
      begin
        X := WordAt(P + 1);
        Y := WordAt(P + 3);
        W := WordAt(P + 5);
        H := WordAt(P + 7);
        Inc(Frames);
        if (W = 0) or (H = 0) or (X + W > Result.X) or (Y + H > Result.Y) or (Frames > 512) then Exit(Point(0, 0));
        if ByteAt(P + 9) and $80 <> 0 then Inc(P, 3 * (1 shl ((ByteAt(P + 9) and 7) + 1)));
        Inc(P, 11);
        SkipBlocks;
      end;
      else
        Exit(Point(0, 0));
    end;
  Result := Point(0, 0);
end;

function PictureCost(const Bytes: TBytes): int64;
var
  Stream: TBytesStream;
  Reader: TFPCustomImageReaderClass;
  Size: TPoint;
  WebP: TFPReaderWebP;
  Frames: TFPFramesInfo;
begin
  Result := 0;
  if (Length(Bytes) = 0) or (Length(Bytes) > MaxPictureBytes) then Exit;
  Stream := TBytesStream.Create(Bytes);
  try
    try
      Reader := TFPCustomImage.FindReaderFromStream(Stream);
      if Reader = nil then Exit;
      Stream.Position := 0;
      if Reader = TFPReaderWebP then
      begin
        WebP := TFPReaderWebP.Create;
        try
          Frames := WebP.BeginFrames(Stream);
          try
            if Frames.FrameCount > 512 then Exit;
            Size := Point(Frames.Width, Frames.Height);
          finally
            WebP.EndFrames;
          end;
        finally
          WebP.Free;
        end;
      end
      else if Reader = TFPReaderGIF then Size := GifSize(Bytes)
      else
        Size := Reader.ImageSize(Stream);
      if (Size.X <= 0) or (Size.Y <= 0) or (Size.X > MaxPictureSide) or (Size.Y > MaxPictureSide) or (int64(Size.X) * Size.Y > MaxPicturePixels) then Exit;
      // Allow for a 32-bit bitmap and a 64-bit decoding buffer.
      Result := int64(Size.X) * Size.Y * 12;
    except
      Result := 0;
    end;
  finally
    Stream.Free;
  end;
end;

destructor TPictureEntry.Destroy;
begin
  if Size > 0 then FillChar(Memory^, Size, 0);
  inherited Destroy;
end;

constructor TPictureCache.Create;
begin
  Dropped := TStringList.Create;
  Entries := TStringList.Create;
  Entries.CaseSensitive := True;
  Entries.OwnsObjects := True;
end;

destructor TPictureCache.Destroy;
begin
  TThread.RemoveQueuedEvents(nil, @DeliverDrops);
  Dropped.Free;
  Entries.Free;
  inherited Destroy;
end;

procedure TPictureCache.Clear;
begin
  TThread.RemoveQueuedEvents(nil, @DeliverDrops);
  Dropped.Clear;
  Entries.Clear;
end;

function TPictureCache.Count: integer;
begin
  Result := Entries.Count;
end;

function TPictureCache.IndexOf(const Path: string): integer;
begin
  Result := Entries.IndexOf(Path);
end;

procedure TPictureCache.Touch(Entry: TPictureEntry);
begin
  Inc(Clock);
  Entry.Used := Clock;
end;

function TPictureCache.Read(const Path: string): TPictureEntry;
var
  I: integer;
begin
  Result := nil;
  I := Entries.IndexOf(Path);
  if I < 0 then Exit;
  if TPictureEntry(Entries.Objects[I]).Size = 0 then Exit;
  Result := TPictureEntry(Entries.Objects[I]);
  Touch(Result);
end;

function TPictureCache.BeginFetch(const Path: string): boolean;
var
  I, Oldest, J: integer;
  Entry: TPictureEntry;
begin
  Result := False;
  if Dropping then Exit;
  I := Entries.IndexOf(Path);
  if I < 0 then
  begin
    if Entries.Count >= MaxPictureEntries then
    begin
      Oldest := -1;
      for J := 0 to Entries.Count - 1 do
      begin
        Entry := TPictureEntry(Entries.Objects[J]);
        if Entry.Pending then Continue;
        if (Oldest < 0) or (Entry.Used < TPictureEntry(Entries.Objects[Oldest]).Used) then Oldest := J;
      end;
      if Oldest < 0 then Exit;
      Drop(Oldest);
      Entries.Delete(Oldest);
    end;
    I := Entries.AddObject(Path, TPictureEntry.Create);
  end;
  Entry := TPictureEntry(Entries.Objects[I]);
  if Entry.Pending or (Entry.Size > 0) or (GetTickCount64 < Entry.RetryAt) then Exit;
  Entry.Pending := True;
  Touch(Entry);
  Result := True;
end;

procedure TPictureCache.Failed(const Path: string);
var
  I: integer;
  Entry: TPictureEntry;
begin
  I := Entries.IndexOf(Path);
  if I < 0 then Exit;
  Entry := TPictureEntry(Entries.Objects[I]);
  Entry.Pending := False;
  Entry.RetryAt := GetTickCount64 + PictureRetryDelay;
end;

function TPictureCache.Complete(const Path: string; const Bytes: TBytes): boolean;
var
  I: integer;
  Cost: int64;
  Entry: TPictureEntry;
begin
  Result := False;
  I := Entries.IndexOf(Path);
  if I < 0 then Exit;
  Cost := PictureCost(Bytes);
  if (Cost = 0) or (Cost > PictureDecodedBudget) then
  begin
    Failed(Path);
    Exit;
  end;
  Entry := TPictureEntry(Entries.Objects[I]);
  if not Entry.Pending then Exit;
  Entry.WriteBuffer(Bytes[0], Length(Bytes));
  Entry.Position := 0;
  Entry.Pending := False;
  Entry.DecodedBytes := Cost;
  Touch(Entry);
  Trim;
  Result := Entry.Size > 0;
end;

function TPictureCache.ByteSize: int64;
var
  I: integer;
begin
  Result := 0;
  for I := 0 to Entries.Count - 1 do Inc(Result, TPictureEntry(Entries.Objects[I]).Size);
end;

function TPictureCache.DecodedSize: int64;
var
  I: integer;
begin
  Result := 0;
  for I := 0 to Entries.Count - 1 do Inc(Result, TPictureEntry(Entries.Objects[I]).DecodedBytes);
end;

procedure TPictureCache.Drop(I: integer);
var
  Entry: TPictureEntry;
begin
  Entry := TPictureEntry(Entries.Objects[I]);
  if Entry.Size = 0 then Exit;
  FillChar(Entry.Memory^, Entry.Size, 0);
  Entry.Size := 0;
  Entry.DecodedBytes := 0;
  Entry.RetryAt := GetTickCount64 + PictureRetryDelay;
  Dropped.Add(Entries[I]);
  if Dropped.Count = 1 then TThread.ForceQueue(nil, @DeliverDrops);
end;

procedure TPictureCache.DeliverDrops;
var
  Path: string;
begin
  Dropping := True;
  try
    while Dropped.Count > 0 do
    begin
      Path := Dropped[0];
      Dropped.Delete(0);
      if Assigned(OnDrop) then OnDrop(Path);
    end;
  finally
    Dropping := False;
  end;
end;

procedure TPictureCache.Trim;
var
  I, Oldest: integer;
  Entry: TPictureEntry;
begin
  while (ByteSize > PictureByteBudget) or (DecodedSize > PictureDecodedBudget) do
  begin
    Oldest := -1;
    for I := 0 to Entries.Count - 1 do
    begin
      Entry := TPictureEntry(Entries.Objects[I]);
      if Entry.Size = 0 then Continue;
      if (Oldest < 0) or (Entry.Used < TPictureEntry(Entries.Objects[Oldest]).Used) then Oldest := I;
    end;
    if Oldest < 0 then Break;
    Drop(Oldest);
  end;
end;

end.
