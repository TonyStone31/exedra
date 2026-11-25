unit DeskIcons;

{ Small square pictures for the room and member lists: a downloaded room
  icon or avatar made to fit, or a letter on a colored circle for those
  without one, as the web page shows them. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Graphics;

{ The picture in Bytes (PNG, JPEG, GIF...) at Size by Size; nil when it
  cannot be read.  The caller frees it. }
type
  TDeskIconEntry = class
  public
    Slot, Serial: integer;
    Users: byte;
    Used, RetryAt: QWord;
    Pending, Ready: boolean;
  end;

function IconFromBytes(const Bytes: TBytes; Size: integer): TBitmap;
{ Name's first letter on a circle of a color picked from the name. }
function LetterIcon(const Name: string; Size: integer): TBitmap;

implementation

uses
  Math, IntfGraphics, FPImage, FPCanvas, FPImgCanv, GraphType, DeskPictures;

function IconFromBytes(const Bytes: TBytes; Size: integer): TBitmap;
var
  Picture: TPicture;
  Data: TBytesStream;
  Source, Target: TLazIntfImage;
  Canvas: TFPImageCanvas;
begin
  Result := nil;
  if PictureCost(Bytes) = 0 then Exit;
  Picture := TPicture.Create;
  Data := TBytesStream.Create(Bytes);
  try
    try
      Picture.LoadFromStream(Data);
    except
      Exit;
    end;
    // Scaled with fcl-image so the picture's transparency comes along.
    Source := Picture.Bitmap.CreateIntfImage;
    Target := TLazIntfImage.Create(Size, Size, [riqfRGB, riqfAlpha]);
    Canvas := TFPImageCanvas.Create(Target);
    try
      Target.FillPixels(colTransparent);
      Canvas.Interpolation := TMitchellInterpolation.Create;
      Canvas.StretchDraw(0, 0, Size, Size, Source);
      Canvas.Interpolation.Free;
      Result := TBitmap.Create;
      Result.LoadFromIntfImage(Target);
    finally
      Canvas.Free;
      Target.Free;
      Source.Free;
    end;
  finally
    Data.Free;
    Picture.Free;
  end;
end;

function LetterIcon(const Name: string; Size: integer): TBitmap;
const
  Palette: array[0..7] of TColor = ($B5782C, $3D9B2E, $2F6FD6, $8F3FB6, $0A7DC2, $5B6577, $9D0F0F, $4A9E8F);
var
  Letter: string;
  Back: TColor;
  Glyph: TBitmap;
  Mask, Target: TLazIntfImage;
  X, Y: integer;
  Inside, Ink: double;
  C: TFPColor;
begin
  Letter := UpperCase(Copy(Name, 1, 1));
  Back := Palette[(Ord(Letter[1]) + Length(Name)) mod Length(Palette)];
  if Letter = '#' then
    Back := $8C8479;
  // The letter drawn white on black is the mask that lays it on the circle.
  Glyph := TBitmap.Create;
  Glyph.SetSize(Size, Size);
  Glyph.Canvas.Brush.Color := clBlack;
  Glyph.Canvas.FillRect(0, 0, Size, Size);
  Glyph.Canvas.Font.Color := clWhite;
  Glyph.Canvas.Font.Style := [fsBold];
  Glyph.Canvas.Font.Height := -(Size * 3 div 5);
  Glyph.Canvas.TextOut((Size - Glyph.Canvas.TextWidth(Letter)) div 2,
    (Size - Glyph.Canvas.TextHeight(Letter)) div 2, Letter);
  Mask := Glyph.CreateIntfImage;
  Target := TLazIntfImage.Create(Size, Size, [riqfRGB, riqfAlpha]);
  try
    for Y := 0 to Size - 1 do
      for X := 0 to Size - 1 do
      begin
        // How far inside the circle the pixel's middle is, for a soft edge.
        Inside := Size / 2 - Sqrt(Sqr(X + 0.5 - Size / 2) + Sqr(Y + 0.5 - Size / 2));
        C := TColorToFPColor(ColorToRGB(Back));
        Ink := Mask.Colors[X, Y].Red / $FFFF;
        C.Red := Round(C.Red + (High(word) - C.Red) * Ink);
        C.Green := Round(C.Green + (High(word) - C.Green) * Ink);
        C.Blue := Round(C.Blue + (High(word) - C.Blue) * Ink);
        C.Alpha := Round(EnsureRange(Inside + 0.5, 0, 1) * High(word));
        Target.Colors[X, Y] := C;
      end;
    Result := TBitmap.Create;
    Result.LoadFromIntfImage(Target);
  finally
    Target.Free;
    Mask.Free;
    Glyph.Free;
  end;
end;

end.
