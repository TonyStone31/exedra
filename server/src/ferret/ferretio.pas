unit FerretIO;

{$mode objfpc}{$H+}
// Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.

interface

uses Classes, SysUtils, FerretTypes, FerretCache;

type
  TFerretWriteStep = (fwCreate, fwWrite, fwSync, fwRename, fwDirectorySync);
  TFerretWriteHook = procedure(Step: TFerretWriteStep);

  { File handles and platform differences stay here. }
  TFerretFile = class
  private
    FStream: TStream;
    FPageCache: TFerretCache;
    FHandle: THandle;
    FSize: int64;
    FWritable, FBlockProtected: boolean;
    FPosition: int64;
    FWriteBuffer: array[0..65535] of byte;
    FWriteCount: integer;
    FWriteStart: int64;
    FBlockOffsets: array of int64;
    FCache: array[0..65535] of byte;
    FCacheStart: int64;
    FCacheCount: integer;
    procedure FlushWrites;
    procedure LoadPacked;
    procedure ReadPackedBlock(Block: integer);
    class procedure Step(Value: TFerretWriteStep); static;
  public
  class var WriteHook: TFerretWriteHook;
    constructor Create(const Name: string; WriteNew: boolean = False);
    constructor Memory;
    destructor Destroy; override;
    procedure ReadAt(Offset: int64; var Data; Count: integer);
    function ReadBytes(Offset: int64; Count: integer): rawbytestring;
    procedure Write(const Data; Count: integer);
    procedure WriteBytes(const Data: rawbytestring);
    procedure Seek(Offset: int64);
    function Position: int64;
    function Size: int64;
    function RetainsBlocks: boolean;
    property BlockProtected: boolean read FBlockProtected write FBlockProtected;
    property PageCache: TFerretCache read FPageCache write FPageCache;
    procedure Sync;
    function CompressFile(const Name: string; DenseFrom: int64 = 0; DenseBefore: int64 = 0): TFerretFile;
    class function Lock(const Folder: string): TFerretFile; static;
    class procedure Replace(const Source, Target: string); static;
    class procedure SyncFolder(const Folder: string); static;
    class function Stamp(const Name: string): string; static;
  end;

  TFerretReadBuffer = class
  private
    FFile: TFerretFile;
    FData: rawbytestring;
    FFirst: int64;
  public
    constructor Create(FileData: TFerretFile);
    function ReadBytes(Offset: int64; Count: integer): rawbytestring;
  end;

procedure DamagedIndex;
procedure CheckVersion(Value: cardinal);

implementation

{$ifdef unix}
uses BaseUnix, Unix, FerretCRC, FerretCompress;
{$endif}
{$ifdef windows}
uses Windows, FerretCRC, FerretCompress;
{$endif}

{$ifdef unix}
const
  CloseOnExec = 1;
{$endif}

constructor TFerretReadBuffer.Create(FileData: TFerretFile);
begin
  inherited Create;
  FFile := FileData;
  FFirst := -1;
end;

function TFerretReadBuffer.ReadBytes(Offset: int64; Count: integer): rawbytestring;
var
  Done, Part, Available: integer;
begin
  if FFile.RetainsBlocks then Exit(FFile.ReadBytes(Offset, Count));
  if (Offset < 0) or (Count < 0) or (Offset > FFile.Size - Count) then DamagedIndex;
  Result := '';
  SetLength(Result, Count);
  Done := 0;
  while Done < Count do
  begin
    if (Offset < FFirst) or (Offset >= FFirst + Length(FData)) then
    begin
      FFirst := Offset div 65536 * 65536;
      Available := 65536;
      if FFile.Size - FFirst < Available then Available := FFile.Size - FFirst;
      FData := FFile.ReadBytes(FFirst, Available);
    end;
    Part := Length(FData) - (Offset - FFirst);
    if Part > Count - Done then Part := Count - Done;
    Move(FData[Offset - FFirst + 1], Result[Done + 1], Part);
    Inc(Done, Part);
    Inc(Offset, Part);
  end;
end;

procedure DamagedIndex;
begin
  raise EFerret.Create('The index is damaged. Restore a backup or rebuild it from the original documents.');
end;

procedure CheckVersion(Value: cardinal);
begin
  if Value > 3 then
    raise EFerret.Create('This index needs a newer version of Ferret. Update Ferret or rebuild the index from the original documents.');
  if Value <> 3 then
    raise EFerret.Create('This index uses an older format. Rebuild it from the original documents.');
end;

class procedure TFerretFile.Step(Value: TFerretWriteStep);
begin
  if Assigned(WriteHook) then WriteHook(Value);
end;

constructor TFerretFile.Create(const Name: string; WriteNew: boolean);
begin
  inherited Create;
  FHandle := THandle(-1);
  FCacheStart := -1;
  FWritable := WriteNew;
  try
    {$ifdef windows}
    if WriteNew then
      FHandle := CreateFileW(PWideChar(UTF8Decode(Name)), GENERIC_READ or GENERIC_WRITE,
        FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE, nil, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, 0)
    else
      FHandle := CreateFileW(PWideChar(UTF8Decode(Name)), GENERIC_READ,
        FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
    if FHandle = INVALID_HANDLE_VALUE then RaiseLastOSError;
    FStream := THandleStream.Create(FHandle);
    {$else}
    if WriteNew then FHandle := fpOpen(PChar(Name), O_RDWR or O_CREAT or O_EXCL, &600)
    else
      FHandle := fpOpen(PChar(Name), O_RDONLY);
    if FHandle = THandle(-1) then RaiseLastOSError;
    if fpFcntl(FHandle, F_SETFD, CloseOnExec) < 0 then RaiseLastOSError;
    FStream := THandleStream.Create(FHandle);
    {$endif}
    FSize := FStream.Size;
    if not WriteNew then LoadPacked;
    if WriteNew then Step(fwCreate);
  except
    on E: EFerret do raise;
    on E: Exception do raise EFerret.Create('Cannot open the index file "' + Name + '". Check the folder and its permissions. ' + E.Message);
  end;
end;

constructor TFerretFile.Memory;
begin
  inherited Create;
  FHandle := THandle(-1);
  FCacheStart := -1;
  FWritable := True;
  FStream := TMemoryStream.Create;
end;

destructor TFerretFile.Destroy;
begin
  FlushWrites;
  FStream.Free;
  {$ifdef unix}
  if FHandle <> THandle(-1) then FileClose(FHandle);
  {$endif}
  {$ifdef windows}
  if FHandle <> INVALID_HANDLE_VALUE then CloseHandle(FHandle);
  {$endif}
  inherited Destroy;
end;

procedure TFerretFile.ReadAt(Offset: int64; var Data; Count: integer);
var
  Available, Part, Done: integer;
begin
  if (Offset < 0) or (Count < 0) or (Offset > Size - Count) then DamagedIndex;
  FlushWrites;
  Done := 0;
  while Done < Count do
  begin
    if (Offset < FCacheStart) or (Offset >= FCacheStart + FCacheCount) then
    begin
      if Length(FBlockOffsets) > 0 then ReadPackedBlock(Offset div 65536)
      else
      begin
        FStream.Position := Offset;
        FCacheStart := Offset;
        FCacheCount := FStream.Read(FCache, SizeOf(FCache));
      end;
      if FCacheCount < 0 then raise EFerret.Create('Cannot read the index. Check the disk and folder permissions, or restore a backup.');
      if FCacheCount = 0 then DamagedIndex;
    end;
    Available := FCacheCount - integer(Offset - FCacheStart);
    Part := Count - Done;
    if Part > Available then Part := Available;
    Move(FCache[Offset - FCacheStart], (pbyte(@Data) + Done)^, Part);
    Inc(Done, Part);
    Inc(Offset, Part);
  end;
end;

function TFerretFile.ReadBytes(Offset: int64; Count: integer): rawbytestring;
begin
  Result := '';
  SetLength(Result, Count);
  if Count > 0 then ReadAt(Offset, Result[1], Count);
end;

procedure TFerretFile.FlushWrites;
begin
  if FWriteCount = 0 then Exit;
  FStream.Position := FWriteStart;
  FStream.WriteBuffer(FWriteBuffer, FWriteCount);
  FWriteCount := 0;
  if FHandle <> THandle(-1) then Step(fwWrite);
end;

procedure TFerretFile.Write(const Data; Count: integer);
var
  Done, Part: integer;
begin
  if not FWritable then raise EFerret.Create('The index file is read-only. Open it for writing before changing it.');
  FCacheStart := -1;
  try
    Done := 0;
    while Done < Count do
    begin
      if FWriteCount = 0 then FWriteStart := FPosition;
      Part := SizeOf(FWriteBuffer) - FWriteCount;
      if Part > Count - Done then Part := Count - Done;
      Move((pbyte(@Data) + Done)^, FWriteBuffer[FWriteCount], Part);
      Inc(FWriteCount, Part);
      Inc(FPosition, Part);
      Inc(Done, Part);
      if FPosition > FSize then FSize := FPosition;
      if FWriteCount = SizeOf(FWriteBuffer) then FlushWrites;
    end;
  except
    on E: EFerret do raise;
    on E: Exception do raise EFerret.Create('Cannot write the index. Check free space and folder permissions. ' + E.Message);
  end;
end;

procedure TFerretFile.WriteBytes(const Data: rawbytestring);
begin
  if Data <> '' then Write(Data[1], Length(Data));
end;

procedure TFerretFile.Seek(Offset: int64);
begin
  FlushWrites;
  FPosition := Offset;
end;

function TFerretFile.Position: int64;
begin
  Result := FPosition;
end;

function TFerretFile.Size: int64;
begin
  Result := FSize;
end;

function TFerretFile.RetainsBlocks: boolean;
begin
  Result := (FPageCache <> nil) and (FPageCache.Limit >= 65536 + 256);
end;

procedure TFerretFile.Sync;
begin
  FlushWrites;
  if FHandle = THandle(-1) then Exit;
  if not FileFlush(FHandle) then
    raise EFerret.Create('Cannot finish saving the index. Check the disk and its free space.');
  Step(fwSync);
end;

procedure PutFixed(var Data: rawbytestring; Offset: integer; Value: QWord; Width: integer);
var
  I: integer;
begin
  for I := 0 to Width - 1 do
  begin
    Data[Offset + I] := Chr(Value and 255);
    Value := Value shr 8;
  end;
end;

function GetFixed(const Data: rawbytestring; Offset, Width: integer): QWord;
var
  I: integer;
begin
  if (Offset < 1) or (Offset > Length(Data) - Width + 1) then DamagedIndex;
  Result := 0;
  for I := 0 to Width - 1 do Result := Result or (QWord(Ord(Data[Offset + I])) shl (8 * I));
end;

procedure TFerretFile.LoadPacked;
var
  Header, Table: rawbytestring;
  TableOffset, LogicalSize, PhysicalSize: int64;
  N, I: integer;
  Sum: cardinal;
begin
  if FSize < 8 then Exit;
  FStream.Position := 0;
  SetLength(Header, 8);
  FStream.ReadBuffer(Header[1], 8);
  if Header <> 'FERPAK02' then Exit;
  if FSize < 40 then DamagedIndex;
  PhysicalSize := FSize;
  SetLength(Header, 40);
  FStream.ReadBuffer(Header[9], 32);
  LogicalSize := GetFixed(Header, 9, 8);
  TableOffset := GetFixed(Header, 17, 8);
  N := GetFixed(Header, 29, 4);
  Sum := FerretCRC32(0, pbyte(PChar(Header)), 32);
  if (GetFixed(Header, 25, 4) <> 65536) or (LogicalSize < 80) or (N <> (LogicalSize + 65535) div 65536) or (TableOffset < 40) or
    (TableOffset > PhysicalSize - int64(N + 1) * 8 - 4) or (Sum <> GetFixed(Header, 33, 4)) then DamagedIndex;
  SetLength(Table, (N + 1) * 8 + 4);
  FStream.Position := TableOffset;
  FStream.ReadBuffer(Table[1], Length(Table));
  if FerretCRC32(0, pbyte(PChar(Table)), Length(Table) - 4) <> GetFixed(Table, Length(Table) - 3, 4) then DamagedIndex;
  SetLength(FBlockOffsets, N + 1);
  for I := 0 to N do
  begin
    FBlockOffsets[I] := GetFixed(Table, I * 8 + 1, 8);
    if (FBlockOffsets[I] < 40) or (FBlockOffsets[I] > TableOffset) then DamagedIndex;
    if (I > 0) and (FBlockOffsets[I] <= FBlockOffsets[I - 1]) then DamagedIndex;
  end;
  if FBlockOffsets[N] <> TableOffset then DamagedIndex;
  FSize := LogicalSize;
end;

procedure TFerretFile.ReadPackedBlock(Block: integer);
var
  Data, Key: rawbytestring;
  Count, Expected: integer;
  Sum: cardinal;
begin
  if (Block < 0) or (Block >= Length(FBlockOffsets) - 1) then DamagedIndex;
  Key := '';
  Data := '';
  if RetainsBlocks then
  begin
    Key := IntToStr(PtrUInt(Self)) + ':' + IntToStr(Block);
    Data := FPageCache.ReadBytes(Key);
  end;
  if Data <> '' then
  begin
    Move(Data[1], FCache, Length(Data));
    FCacheStart := int64(Block) * 65536;
    FCacheCount := Length(Data);
    Exit;
  end;
  if FBlockOffsets[Block + 1] - FBlockOffsets[Block] > 65541 then DamagedIndex;
  Count := FBlockOffsets[Block + 1] - FBlockOffsets[Block];
  if Count < 5 then DamagedIndex;
  FStream.Position := FBlockOffsets[Block];
  SetLength(Data, Count);
  FStream.ReadBuffer(Data[1], Count);
  Sum := GetFixed(Data, 1, 4);
  if Sum <> FerretCRC32(0, pbyte(@Data[5]), Count - 4) then DamagedIndex;
  Expected := 65536;
  if FSize - int64(Block) * 65536 < Expected then Expected := FSize - int64(Block) * 65536;
  Data := ExpandBlock(Copy(Data, 5, MaxInt), Expected);
  if Key <> '' then FPageCache.SaveBytes(Key, Data);
  Move(Data[1], FCache, Expected);
  FCacheStart := int64(Block) * 65536;
  FCacheCount := Expected;
end;

function TFerretFile.CompressFile(const Name: string; DenseFrom, DenseBefore: int64): TFerretFile;
var
  Dest: TFerretFile;
  Header, Data, Table, SumData: rawbytestring;
  Offsets: array of int64;
  I, N, Count: integer;
  TableOffset: int64;
begin
  FlushWrites;
  Dest := nil;
  if Name = '' then Dest := TFerretFile.Memory
  else
    Dest := TFerretFile.Create(Name + '.packed', True);
  try
    Header := StringOfChar(#0, 40);
    Dest.WriteBytes(Header);
    N := (FSize + 65535) div 65536;
    SetLength(Offsets, N + 1);
    for I := 0 to N - 1 do
    begin
      Count := 65536;
      if FSize - int64(I) * 65536 < Count then Count := FSize - int64(I) * 65536;
      Data := CompressBlock(ReadBytes(int64(I) * 65536, Count), (int64(I) * 65536 >= DenseFrom) and (int64(I) * 65536 < DenseBefore));
      Offsets[I] := Dest.Position;
      SumData := StringOfChar(#0, 4);
      PutFixed(SumData, 1, FerretCRC32(0, pbyte(PChar(Data)), Length(Data)), 4);
      Dest.WriteBytes(SumData);
      Dest.WriteBytes(Data);
    end;
    TableOffset := Dest.Position;
    Offsets[N] := TableOffset;
    Table := StringOfChar(#0, (N + 1) * 8 + 4);
    for I := 0 to N do PutFixed(Table, I * 8 + 1, Offsets[I], 8);
    PutFixed(Table, Length(Table) - 3, FerretCRC32(0, pbyte(PChar(Table)), Length(Table) - 4), 4);
    Dest.WriteBytes(Table);
    Move('FERPAK02'[1], Header[1], 8);
    PutFixed(Header, 9, FSize, 8);
    PutFixed(Header, 17, TableOffset, 8);
    PutFixed(Header, 25, 65536, 4);
    PutFixed(Header, 29, N, 4);
    PutFixed(Header, 33, FerretCRC32(0, pbyte(PChar(Header)), 32), 4);
    Dest.Seek(0);
    Dest.WriteBytes(Header);
    Dest.Sync;
    if Name <> '' then
    begin
      FreeAndNil(Dest);
      Replace(Name + '.packed', Name);
      Result := TFerretFile.Create(Name);
    end
    else
    begin
      Dest.LoadPacked;
      Result := Dest;
      Dest := nil;
    end;
  finally
    Dest.Free;
  end;
end;

class function TFerretFile.Lock(const Folder: string): TFerretFile;
var
  Handle: THandle;
begin
  Result := nil;
  {$ifdef unix}
  Handle := fpOpen(PChar(IncludeTrailingPathDelimiter(Folder) + 'writer.lock'), O_RDWR or O_CREAT, &600);
  if Handle < 0 then raise EFerret.Create('Cannot create the index lock. Check folder permissions.');
  if fpFcntl(Handle, F_SETFD, CloseOnExec) < 0 then
  begin
    FileClose(Handle);
    raise EFerret.Create('Cannot protect the index lock. Close and reopen the index.');
  end;
  if fpFlock(Handle, LOCK_EX or LOCK_NB) <> 0 then
  begin
    FileClose(Handle);
    raise EFerret.Create('Another program has the index open for writing. Close it there before making changes.');
  end;
  {$endif}
  {$ifdef windows}
  Handle := CreateFileW(PWideChar(UTF8Decode(IncludeTrailingPathDelimiter(Folder) + 'writer.lock')),
    GENERIC_READ or GENERIC_WRITE, FILE_SHARE_READ, nil, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if Handle = INVALID_HANDLE_VALUE then
    raise EFerret.Create('Another program has the index open for writing. Close it there before making changes.');
  {$endif}
  Result := TFerretFile.Memory;
  Result.FStream.Free;
  {$ifdef unix}
Result.FStream := THandleStream.Create(Handle);
  {$endif}
  {$ifdef windows}
Result.FStream := THandleStream.Create(Handle);
  {$endif}
  Result.FHandle := Handle;
end;

class procedure TFerretFile.Replace(const Source, Target: string);
begin
  {$ifdef windows}
  if not MoveFileExW(PWideChar(UTF8Decode(Source)), PWideChar(UTF8Decode(Target)), MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then
    raise EFerret.Create('Cannot replace the index manifest. Check folder permissions.');
  {$else}
  if not RenameFile(Source, Target) then
    raise EFerret.Create('Cannot replace the index manifest. Check folder permissions.');
  {$endif}
  Step(fwRename);
end;

class procedure TFerretFile.SyncFolder(const Folder: string);
{$ifdef unix}var Handle: cint;{$endif}
begin
  {$ifdef unix}
  Handle := fpOpen(PChar(Folder), O_RDONLY);
  if Handle < 0 then raise EFerret.Create('Cannot open the index folder. Check its permissions.');
  try
    if fpFsync(Handle) <> 0 then raise EFerret.Create('Cannot finish saving the index folder. Check the disk.');
  finally
    fpClose(Handle);
  end;
  {$endif}
  Step(fwDirectorySync);
end;

class function TFerretFile.Stamp(const Name: string): string;
var
  Info: TSearchRec;
  {$ifdef unix}
Status: Stat;
  {$endif}
  {$ifdef windows}
  Handle: THandle;
  Status: TByHandleFileInformation;
  {$endif}
begin
  Result := '';
  if FindFirst(Name, faAnyFile, Info) <> 0 then Exit;
  try
    Result := FormatDateTime('yyyymmddhhnnsszzz', Info.TimeStamp) + ':' + IntToStr(Info.Size);
    {$ifdef unix}
    // A rename changes the inode even when two commits share a clock tick.
    if fpStat(PChar(Name), Status) = 0 then
    begin
      Result := Result + ':' + IntToStr(Status.st_ino) + ':' + IntToStr(Status.st_mtime) + ':' + IntToStr(Status.st_ctime);
      {$ifdef linux}
      Result := Result + ':' + IntToStr(Status.st_mtime_nsec) + ':' + IntToStr(Status.st_ctime_nsec);
      {$endif}
      {$ifdef bsd}
      Result := Result + ':' + IntToStr(Status.st_mtimensec) + ':' + IntToStr(Status.st_ctimensec);
      {$endif}
    end;
    {$endif}
    {$ifdef windows}
    Handle := CreateFileW(PWideChar(UTF8Decode(Name)), GENERIC_READ,
      FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
    if Handle <> INVALID_HANDLE_VALUE then
    try
      if GetFileInformationByHandle(Handle, Status) then
        Result := Result + ':' + IntToStr(Status.nFileIndexHigh) + ':' + IntToStr(Status.nFileIndexLow) +
          ':' + IntToStr(Status.ftLastWriteTime.dwHighDateTime) + ':' + IntToStr(Status.ftLastWriteTime.dwLowDateTime);
    finally
      CloseHandle(Handle);
    end;
    {$endif}
  finally
    SysUtils.FindClose(Info);
  end;
end;

end.
