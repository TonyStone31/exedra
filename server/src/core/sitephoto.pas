unit SitePhoto;

{ Takes what a camera or an editor wrote beside the picture out of an
  uploaded JPEG, PNG or WebP file: where and when it was taken, the device,
  comments.  The picture itself is not touched, and a JPEG keeps the one
  value that says which way up it is. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

{ The picture in Data without its camera data, in Clean.  False when Data
  is no picture of these kinds or holds nothing to take out. }
function WithoutCameraData(const Data: TBytes; out Clean: TBytes): boolean;
{ The same for a file, written back in place.  True when it was changed. }
function StripCameraData(const FileName: string): boolean;

implementation

uses
  Classes;

procedure Put(var Into: TBytes; const From: TBytes; At, Count: integer);
var
  Old: integer;
begin
  if Count <= 0 then
    Exit;
  Old := Length(Into);
  SetLength(Into, Old + Count);
  Move(From[At], Into[Old], Count);
end;

{ The turn of the picture from an Exif part that starts at At: 1 to 8, or 0. }
function Orientation(const Data: TBytes; At, Count: integer): integer;
var
  Little: boolean;
  Base, Dir, Entries, I, E: integer;

  function Word16(P: integer): integer;
  begin
    if P + 1 >= At + Count then
      Exit(0);
    if Little then
      Result := Data[P] or (Data[P + 1] shl 8)
    else
      Result := (Data[P] shl 8) or Data[P + 1];
  end;

  function Long32(P: integer): int64;
  begin
    if Little then
      Result := Word16(P) or (int64(Word16(P + 2)) shl 16)
    else
      Result := (int64(Word16(P)) shl 16) or Word16(P + 2);
  end;

begin
  Result := 0;
  Base := At + 6;
  if (Count < 20) or (Data[At] <> Ord('E')) or (Data[At + 1] <> Ord('x')) or (Data[At + 2] <> Ord('i')) or (Data[At + 3] <> Ord('f')) then
    Exit;
  Little := Data[Base] = Ord('I');
  if Word16(Base + 2) <> 42 then
    Exit;
  Dir := Long32(Base + 4);
  if (Dir < 8) or (Dir > Count) then
    Exit;
  Entries := Word16(Base + Dir);
  for I := 0 to Entries - 1 do
  begin
    E := Base + Dir + 2 + 12 * I;
    if E + 12 > At + Count then
      Exit;
    if Word16(E) = $0112 then
    begin
      Result := Word16(E + 8);
      if (Result < 1) or (Result > 8) then
        Result := 0;
      Exit;
    end;
  end;
end;

{ An Exif part that says nothing but which way up the picture is. }
function TurnOnly(Turn: integer): TBytes;
const
  Part: array[0..35] of byte = ($FF, $E1, $00, $22, $45, $78, $69, $66, $00, $00, $4D, $4D, $00, $2A, $00, $00, $00, $08, $00, $01,
    $01, $12, $00, $03, $00, $00, $00, $01, $00, $00, $00, $00, $00, $00, $00, $00);
begin
  Result := nil;
  SetLength(Result, Length(Part));
  Move(Part[0], Result[0], Length(Part));
  Result[29] := Turn;
end;

function CleanJpeg(const Data: TBytes; out Clean: TBytes): boolean;
var
  P, Size, Turn: integer;
  Marker: byte;
  Keep: boolean;
  Body: TBytes;
begin
  Result := False;
  Clean := nil;
  Body := nil;
  Turn := 0;
  P := 2;
  while P + 4 <= Length(Data) do
  begin
    if Data[P] <> $FF then
      Exit(False);
    Marker := Data[P + 1];
    // the picture's own data runs from here to the end
    if Marker = $DA then
      Break;
    Size := (Data[P + 2] shl 8) or Data[P + 3];
    if (Size < 2) or (P + 2 + Size > Length(Data)) then
      Exit(False);
    // kept: the JFIF header, a color profile, Adobe's color note, and every part the picture is made of
    Keep := (Marker < $E0) or (Marker > $EF) and (Marker <> $FE) or (Marker = $E0) or (Marker = $EE) or ((Marker = $E2) and (Size > 13) and
      (Data[P + 4] = Ord('I')) and (Data[P + 5] = Ord('C')) and (Data[P + 6] = Ord('C')));
    if Keep then
      Put(Body, Data, P, Size + 2)
    else
    begin
      Result := True;
      if (Marker = $E1) and (Turn = 0) then
        Turn := Orientation(Data, P + 4, Size - 2);
    end;
    P := P + 2 + Size;
  end;
  if not Result or (P + 4 > Length(Data)) then
    Exit(False);
  Put(Clean, Data, 0, 2);
  if Turn > 1 then
    Put(Clean, TurnOnly(Turn), 0, 36);
  Put(Clean, Body, 0, Length(Body));
  Put(Clean, Data, P, Length(Data) - P);
end;

function CleanPng(const Data: TBytes; out Clean: TBytes): boolean;
var
  P, Size: integer;
  Kind: string;
begin
  Result := False;
  Clean := nil;
  Put(Clean, Data, 0, 8);
  P := 8;
  while P + 12 <= Length(Data) do
  begin
    Size := (Data[P] shl 24) or (Data[P + 1] shl 16) or (Data[P + 2] shl 8) or Data[P + 3];
    if (Size < 0) or (P + 12 + Size > Length(Data)) then
      Exit(False);
    SetString(Kind, pansichar(@Data[P + 4]), 4);
    if (Kind = 'eXIf') or (Kind = 'tEXt') or (Kind = 'zTXt') or (Kind = 'iTXt') or (Kind = 'tIME') then
      Result := True
    else
      Put(Clean, Data, P, Size + 12);
    P := P + 12 + Size;
  end;
  // anything after the last whole chunk is not a picture's
  Result := Result and (P = Length(Data));
end;

function CleanWebp(const Data: TBytes; out Clean: TBytes): boolean;
var
  P, Size, Whole, Total: integer;
  Kind: string;
begin
  Result := False;
  Clean := nil;
  Put(Clean, Data, 0, 12);
  P := 12;
  while P + 8 <= Length(Data) do
  begin
    Size := Data[P + 4] or (Data[P + 5] shl 8) or (Data[P + 6] shl 16) or (Data[P + 7] shl 24);
    Whole := 8 + Size + (Size and 1);
    if (Size < 0) or (P + 8 + Size > Length(Data)) then
      Exit(False);
    if P + Whole > Length(Data) then
      Whole := Length(Data) - P;
    SetString(Kind, pansichar(@Data[P]), 4);
    if (Kind = 'EXIF') or (Kind = 'XMP ') then
      Result := True
    else
    begin
      Put(Clean, Data, P, Whole);
      // the header's own notes that such parts follow
      if (Kind = 'VP8X') and (Size >= 1) then
        Clean[Length(Clean) - Whole + 8] := Clean[Length(Clean) - Whole + 8] and not $0C;
    end;
    P := P + Whole;
  end;
  if not Result then
    Exit;
  Total := Length(Clean) - 8;
  Clean[4] := Total and $FF;
  Clean[5] := (Total shr 8) and $FF;
  Clean[6] := (Total shr 16) and $FF;
  Clean[7] := (Total shr 24) and $FF;
end;

function WithoutCameraData(const Data: TBytes; out Clean: TBytes): boolean;
begin
  Clean := nil;
  Result := False;
  if Length(Data) < 16 then
    Exit;
  if (Data[0] = $FF) and (Data[1] = $D8) then
    Result := CleanJpeg(Data, Clean)
  else if (Data[0] = $89) and (Data[1] = Ord('P')) and (Data[2] = Ord('N')) and (Data[3] = Ord('G')) then
    Result := CleanPng(Data, Clean)
  else if (Data[0] = Ord('R')) and (Data[1] = Ord('I')) and (Data[2] = Ord('F')) and (Data[3] = Ord('F')) and (Data[8] = Ord('W')) and
    (Data[9] = Ord('E')) and (Data[10] = Ord('B')) and (Data[11] = Ord('P')) then
    Result := CleanWebp(Data, Clean);
end;

function StripCameraData(const FileName: string): boolean;
var
  F: TFileStream;
  Data, Clean: TBytes;
begin
  Result := False;
  Data := nil;
  try
    F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      // nothing a camera makes is larger, and the whole file is held twice
      if (F.Size < 16) or (F.Size > 64 * 1024 * 1024) then
        Exit;
      SetLength(Data, F.Size);
      F.ReadBuffer(Data[0], Length(Data));
    finally
      F.Free;
    end;
    if not WithoutCameraData(Data, Clean) then
      Exit;
    F := TFileStream.Create(FileName, fmCreate);
    try
      F.WriteBuffer(Clean[0], Length(Clean));
    finally
      F.Free;
    end;
    Result := True;
  except
    // a file that cannot be read or written stays as it is
    on E: EStreamError do
      Result := False;
  end;
end;

end.
