unit FerretCodec;

{$mode objfpc}{$H+}{$modeswitch advancedrecords}
// Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.

interface

uses Classes, SysUtils, Math, FerretCRC, FerretTypes, FerretIO;

type
  TFerretBuffer = class
  private
    FData: rawbytestring;
    FCount: integer;
  public
    procedure Clear;
    procedure Bytes(const Value; Count: integer);
    procedure U(Value: QWord); inline;
    procedure Signed(Value: integer);
    procedure Fixed(Value: QWord; Count: integer);
    procedure Text(const Value: string);
    procedure Float(Value: double);
    function Data: rawbytestring;
    function Capacity: integer;
    function Slice(First, Count: integer): rawbytestring;
    procedure EndFrame(First: integer);
    function TakeData: rawbytestring;
    procedure WriteTo(FileData: TFerretFile);
    property Count: integer read FCount;
  end;

  TFerretDecoder = record
    Data: rawbytestring;
    Position: integer;
    procedure Start(const Value: rawbytestring);
    function U: QWord; inline;
    function Number: integer; inline;
    function Signed: integer;
    function Fixed(Count: integer): QWord;
    function Text: string;
    function Float: double;
    procedure Finish;
  end;

function Checksum(const Data: rawbytestring): cardinal;
function FrameBytes(const Data: rawbytestring; WithChecksum: boolean = True): rawbytestring;
procedure WriteFrame(FileData: TFerretFile; const Data: rawbytestring);
function ReadFrame(FileData: TFerretFile; Offset: int64; out After: int64; Buffer: TFerretReadBuffer = nil): rawbytestring;
function EncodeDocument(Doc: TFerretDocument): rawbytestring;
function DecodeDocument(const Data: rawbytestring; WithText: boolean = True): TFerretDocument;
function DecodeDocumentInfo(const Metadata: rawbytestring): TFerretDocument;
procedure DecodeDocumentText(Doc: TFerretDocument; const TextData: rawbytestring);
function NewDictionary: TStringList;

implementation

function NewDictionary: TStringList;
begin
  Result := TStringList.Create;
  Result.UseLocale := False;
  Result.CaseSensitive := True;
  Result.Sorted := True;
  Result.Duplicates := dupIgnore;
end;

procedure TFerretBuffer.Clear;
begin
  FCount := 0;
end;

procedure TFerretBuffer.Bytes(const Value; Count: integer);
begin
  if Count < 0 then DamagedIndex;
  if FCount > MaxInt - Count then raise EFerret.Create('This document is too large. Split it into smaller documents.');
  if Length(FData) < FCount + Count then SetLength(FData, (FCount + Count) + (FCount + Count) div 2 + 32);
  if Count > 0 then Move(Value, (pbyte(PChar(FData)) + FCount)^, Count);
  Inc(FCount, Count);
end;

procedure TFerretBuffer.U(Value: QWord);
var
  B: byte;
begin
  if (Value < 128) and (FCount < Length(FData)) then
  begin
    pbyte(PChar(FData))[FCount] := Value;
    Inc(FCount);
    Exit;
  end;
  if FCount > MaxInt - 10 then raise EFerret.Create('This document is too large. Split it into smaller documents.');
  if Length(FData) < FCount + 10 then SetLength(FData, FCount + FCount div 2 + 42);
  repeat
    B := Value and 127;
    Value := Value shr 7;
    if Value <> 0 then B := B or 128;
    Inc(FCount);
    pbyte(PChar(FData))[FCount - 1] := B;
  until Value = 0;
end;

procedure TFerretBuffer.Signed(Value: integer);
begin
  if Value < 0 then U(QWord(-int64(Value)) * 2 - 1)
  else
    U(QWord(Value) * 2);
end;

procedure TFerretBuffer.Fixed(Value: QWord; Count: integer);
var
  I: integer;
begin
  if (Count < 0) or (Count > 8) then DamagedIndex;
  if FCount > MaxInt - Count then raise EFerret.Create('This document is too large. Split it into smaller documents.');
  if Length(FData) < FCount + Count then SetLength(FData, FCount + FCount div 2 + 40);
  for I := 1 to Count do
  begin
    Inc(FCount);
    pbyte(PChar(FData))[FCount - 1] := Value and 255;
    Value := Value shr 8;
  end;
end;

procedure TFerretBuffer.Text(const Value: string);
begin
  U(Length(Value));
  if Value <> '' then Bytes(Value[1], Length(Value));
end;

procedure TFerretBuffer.Float(Value: double);
var
  Bits: QWord;
begin
  Move(Value, Bits, 8);
  Fixed(Bits, 8);
end;

function TFerretBuffer.Data: rawbytestring;
begin
  Result := Copy(FData, 1, FCount);
end;

function TFerretBuffer.Slice(First, Count: integer): rawbytestring;
begin
  Result := Copy(FData, First + 1, Count);
end;

function TFerretBuffer.Capacity: integer;
begin
  Result := Length(FData);
end;

procedure TFerretBuffer.EndFrame(First: integer);
var
  I, FrameSize: integer;
begin
  FrameSize := FCount - First - 8;
  if (First < 0) or (FrameSize < 0) then DamagedIndex;
  for I := 0 to 3 do
  begin
    pbyte(PChar(FData))[First + I] := FrameSize and 255;
    FrameSize := FrameSize shr 8;
  end;
end;

function TFerretBuffer.TakeData: rawbytestring;
begin
  SetLength(FData, FCount);
  Result := FData;
  FData := '';
  FCount := 0;
end;

procedure TFerretBuffer.WriteTo(FileData: TFerretFile);
begin
  if FCount > 0 then FileData.Write(FData[1], FCount);
end;

procedure TFerretDecoder.Start(const Value: rawbytestring);
begin
  Data := Value;
  Position := 1;
end;

function TFerretDecoder.U: QWord;
var
  Shift: integer;
  B: byte;
begin
  if Position > Length(Data) then DamagedIndex;
  B := Ord(Data[Position]);
  Inc(Position);
  if B < 128 then Exit(B);
  Result := B and 127;
  Shift := 7;
  repeat
    if Position > Length(Data) then DamagedIndex;
    B := Ord(Data[Position]);
    Inc(Position);
    if (Shift = 63) and (B > 1) then DamagedIndex;
    Result := Result or (QWord(B and 127) shl Shift);
    Inc(Shift, 7);
  until B < 128;
end;

function TFerretDecoder.Number: integer;
var
  Value: QWord;
begin
  Value := U;
  if Value > MaxInt then DamagedIndex;
  Result := Value;
end;

function TFerretDecoder.Signed: integer;
var
  Value: QWord;
begin
  Value := U;
  if Value > QWord(MaxInt) * 2 + 1 then DamagedIndex;
  if Value and 1 <> 0 then Result := -int64(Value shr 1) - 1
  else
    Result := Value shr 1;
end;

function TFerretDecoder.Fixed(Count: integer): QWord;
var
  I: integer;
begin
  if (Count > 8) or (Count < 0) or (Position > Length(Data) - Count + 1) then DamagedIndex;
  Result := 0;
  for I := 0 to Count - 1 do Result := Result or (QWord(Ord(Data[Position + I])) shl (I * 8));
  Inc(Position, Count);
end;

function TFerretDecoder.Text: string;
var
  Count: integer;
begin
  Count := Number;
  if Count > Length(Data) - Position + 1 then DamagedIndex;
  Result := Copy(Data, Position, Count);
  Inc(Position, Count);
end;

function TFerretDecoder.Float: double;
var
  Bits: QWord;
begin
  Bits := Fixed(8);
  Move(Bits, Result, 8);
  if IsNan(Result) or IsInfinite(Result) then DamagedIndex;
end;

procedure TFerretDecoder.Finish;
begin
  if Position <> Length(Data) + 1 then DamagedIndex;
end;

function Checksum(const Data: rawbytestring): cardinal;
begin
  Result := FerretCRC32(0, pbyte(PChar(Data)), Length(Data));
end;

function FrameBytes(const Data: rawbytestring; WithChecksum: boolean): rawbytestring;
var
  B: TFerretBuffer;
begin
  B := TFerretBuffer.Create;
  try
    B.Fixed(Length(Data), 4);
    if WithChecksum then B.Fixed(Checksum(Data), 4)
    else
      B.Fixed(0, 4);
    Result := B.Data + Data;
  finally
    B.Free;
  end;
end;

procedure WriteFrame(FileData: TFerretFile; const Data: rawbytestring);
var
  Header: TFerretBuffer;
begin
  Header := TFerretBuffer.Create;
  try
    Header.Fixed(Length(Data), 4);
    if FileData.BlockProtected then Header.Fixed(0, 4)
    else
      Header.Fixed(Checksum(Data), 4);
    FileData.WriteBytes(Header.Data);
    FileData.WriteBytes(Data);
  finally
    Header.Free;
  end;
end;

function ReadFrame(FileData: TFerretFile; Offset: int64; out After: int64; Buffer: TFerretReadBuffer): rawbytestring;
var
  Header: TFerretDecoder;
  Count, Sum: cardinal;
begin
  if Buffer = nil then Header.Start(FileData.ReadBytes(Offset, 8))
  else
    Header.Start(Buffer.ReadBytes(Offset, 8));
  Count := Header.Fixed(4);
  Sum := Header.Fixed(4);
  if (Count > MaxInt) or (Offset > FileData.Size - 8 - Count) then DamagedIndex;
  After := Offset + 8 + Count;
  if Buffer = nil then Result := FileData.ReadBytes(Offset + 8, Count)
  else
    Result := Buffer.ReadBytes(Offset + 8, Count);
  if (Sum <> 0) and (Checksum(Result) <> Sum) then DamagedIndex;
end;

function EncodeDocument(Doc: TFerretDocument): rawbytestring;
var
  B: TFerretBuffer;
  I, TextStart: integer;
  Bits: QWord;
begin
  B := TFerretBuffer.Create;
  try
    B.Fixed(0, 8);
    B.Text(Doc.Id);
    B.Text(Doc.Language);
    B.U(Length(Doc.Fields));
    for I := 0 to High(Doc.Fields) do
    begin
      B.Text(Doc.Fields[I].Name);
      B.Float(Doc.Fields[I].Weight);
      B.U(Doc.Fields[I].WordCount);
      if Doc.Fields[I].Name = 'title' then B.Text(Doc.Fields[I].Text);
    end;
    B.U(Length(Doc.Facts));
    for I := 0 to High(Doc.Facts) do
    begin
      B.Text(Doc.Facts[I].Name);
      B.U(Ord(Doc.Facts[I].Kind));
      case Doc.Facts[I].Kind of
        ffString: B.Text(Doc.Facts[I].Text);
        ffInteger: begin
          Move(Doc.Facts[I].Number, Bits, 8);
          B.Fixed(Bits, 8);
        end;
        ffDate: B.Float(Doc.Facts[I].Date);
      end;
    end;
    B.EndFrame(0);
    TextStart := B.Count;
    B.Fixed(0, 8);
    for I := 0 to High(Doc.Fields) do B.Text(Doc.Fields[I].Text);
    B.EndFrame(TextStart);
    Result := B.TakeData;
  finally
    B.Free;
  end;
end;

function DecodeDocumentInfo(const Metadata: rawbytestring): TFerretDocument;
var
  D: TFerretDecoder;
  I, N, Kind: integer;
  Bits: QWord;
begin
  D.Start(Metadata);
  Result := TFerretDocument.Create(D.Text);
  try
    Result.Language := D.Text;
    N := D.Number;
    if N > Length(Metadata) div 10 then DamagedIndex;
    SetLength(Result.Fields, N);
    for I := 0 to N - 1 do
    begin
      Result.Fields[I].Name := D.Text;
      Result.Fields[I].Weight := D.Float;
      if Result.Fields[I].Weight <= 0 then DamagedIndex;
      Result.Fields[I].WordCount := D.Number;
      if Result.Fields[I].Name = 'title' then Result.Fields[I].Text := D.Text;
    end;
    N := D.Number;
    if N > Length(Metadata) div 3 then DamagedIndex;
    SetLength(Result.Facts, N);
    for I := 0 to N - 1 do
    begin
      Result.Facts[I].Name := D.Text;
      Kind := D.Number;
      if Kind > Ord(High(TFerretFactKind)) then DamagedIndex;
      Result.Facts[I].Kind := TFerretFactKind(Kind);
      case Result.Facts[I].Kind of
        ffString: Result.Facts[I].Text := D.Text;
        ffInteger: begin
          Bits := D.Fixed(8);
          Move(Bits, Result.Facts[I].Number, 8);
        end;
        ffDate: Result.Facts[I].Date := D.Float;
      end;
    end;
    D.Finish;
  except
    Result.Free;
    raise;
  end;
end;

procedure DecodeDocumentText(Doc: TFerretDocument; const TextData: rawbytestring);
var
  D: TFerretDecoder;
  I: integer;
begin
  D.Start(TextData);
  for I := 0 to High(Doc.Fields) do Doc.Fields[I].Text := D.Text;
  D.Finish;
end;

function DecodeDocument(const Data: rawbytestring; WithText: boolean): TFerretDocument;
var
  Offset: integer;

  function Part: rawbytestring;
  var
    D: TFerretDecoder;
    Count, Sum: cardinal;
  begin
    D.Start(Copy(Data, Offset, 8));
    Count := D.Fixed(4);
    Sum := D.Fixed(4);
    if (Count > MaxInt) or (Offset > Length(Data) - 7 - int64(Count)) then DamagedIndex;
    Result := Copy(Data, Offset + 8, Count);
    Inc(Offset, 8 + Count);
    if (Sum <> 0) and (Checksum(Result) <> Sum) then DamagedIndex;
  end;

begin
  Offset := 1;
  Result := DecodeDocumentInfo(Part);
  try
    if WithText then
    begin
      DecodeDocumentText(Result, Part);
      if Offset <> Length(Data) + 1 then DamagedIndex;
    end;
  except
    Result.Free;
    raise;
  end;
end;

end.
