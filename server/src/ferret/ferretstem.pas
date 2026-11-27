unit FerretStem;

{$mode objfpc}{$H+}
// Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.

interface

uses Classes, SysUtils, FerretTypes, FerretText;

type
  TFerretStemmer = class abstract
  public
    function Stem(const word: string): string; virtual; abstract;
  end;

  TFerretStemmers = class
  private
    FItems: TStringList;
    function GetLanguages: string;
  public
    constructor Create(const Languages: string);
    property Languages: string read GetLanguages;
    destructor Destroy; override;
    function Terms(const word, Language: string): TFerretStrings;
    procedure AddTokens(var Tokens: TFerretTokens; const Language: string);
  end;

function CreateStemmer(const Language: string): TFerretStemmer;
function StemLanguages: string;

implementation

uses
  SnowballProgram,
  englishStemmer,
  danishStemmer,
  dutchStemmer,
  finnishStemmer,
  frenchStemmer,
  germanStemmer,
  italianStemmer,
  norwegianStemmer,
  portugueseStemmer,
  spanishStemmer,
  swedishStemmer;

type
  TSnowballStemmer = class(TFerretStemmer)
  private
    FProgram: TSnowballProgram;
  public
    constructor Create(Program_: TSnowballProgram);
    destructor Destroy; override;
    function Stem(const word: string): string; override;
  end;

function StemLanguages: string;
begin
  Result := 'da,de,en,es,fi,fr,it,nl,no,pt,sv';
end;

function CreateStemmer(const Language: string): TFerretStemmer;
var
  P: TSnowballProgram;
begin
  case LowerCase(Language) of
    'da': P := TDanishStemmer.Create;
    'de': P := TGermanStemmer.Create;
    'en': P := TEnglishStemmer.Create;
    'es': P := TSpanishStemmer.Create;
    'fi': P := TFinnishStemmer.Create;
    'fr': P := TFrenchStemmer.Create;
    'it': P := TItalianStemmer.Create;
    'nl': P := TDutchStemmer.Create;
    'no': P := TNorwegianStemmer.Create;
    'pt': P := TPortugueseStemmer.Create;
    'sv': P := TSwedishStemmer.Create;
    else
      raise EFerret.Create('Unsupported stemming language: ' + Language);
  end;
  Result := TSnowballStemmer.Create(P);
end;

constructor TSnowballStemmer.Create(Program_: TSnowballProgram);
begin
  inherited Create;
  FProgram := Program_;
end;

destructor TSnowballStemmer.Destroy;
begin
  FProgram.Free;
  inherited Destroy;
end;

function TSnowballStemmer.Stem(const word: string): string;
var
  Offset, I, N: integer;
  Code: cardinal;
  Latin: ansistring;
begin
  SetLength(Latin, Length(word));
  Offset := 1;
  N := 0;
  while Offset <= Length(word) do
  begin
    Code := NextUTF8(word, Offset);
    if Code > 255 then Exit(word);
    if (Code in [65..90, 192..214, 216..222]) then Inc(Code, 32);
    Inc(N);
    Latin[N] := Chr(Code);
  end;
  SetLength(Latin, N);
  FProgram.Current := Latin;
  FProgram.Stem;
  Latin := FProgram.Current;
  Result := '';
  for I := 1 to Length(Latin) do
  begin
    Code := Ord(Latin[I]);
    if Code < 128 then Result := Result + Chr(Code)
    else
      Result := Result + Chr($C0 or (Code shr 6)) + Chr($80 or (Code and $3F));
  end;
end;

constructor TFerretStemmers.Create(const Languages: string);
var
  Codes: TStringList;
  I: integer;
  Code: string;
begin
  inherited Create;
  FItems := TStringList.Create;
  FItems.OwnsObjects := True;
  FItems.Sorted := True;
  Codes := TStringList.Create;
  try
    Codes.CommaText := Languages;
    for I := 0 to Codes.Count - 1 do
    begin
      Code := LowerCase(Trim(Codes[I]));
      if FItems.IndexOf(Code) < 0 then FItems.AddObject(Code, CreateStemmer(Code));
    end;
  finally
    Codes.Free;
  end;
end;

function TFerretStemmers.GetLanguages: string;
begin
  Result := FItems.CommaText;
end;

destructor TFerretStemmers.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

function TFerretStemmers.Terms(const word, Language: string): TFerretStrings;
var
  I, N, Offset: integer;
begin
  Result := nil;
  // Snowball's Pascal algorithms accept Latin-1 only.
  Offset := 1;
  while Offset <= Length(word) do
    if NextUTF8(word, Offset) > 255 then Exit;
  for I := 0 to FItems.Count - 1 do
    if (Language = '') or (LowerCase(Language) = FItems[I]) then
    begin
      N := Length(Result);
      SetLength(Result, N + 1);
      Result[N] := #1 + 's:' + FItems[I] + ':' + FoldText(TFerretStemmer(FItems.Objects[I]).Stem(word));
    end;
end;

procedure TFerretStemmers.AddTokens(var Tokens: TFerretTokens; const Language: string);
var
  I, J, N, Count: integer;
  Stems: TFerretStrings;
begin
  Count := Length(Tokens);
  N := Count;
  for I := 0 to Count - 1 do
    if Tokens[I].StemAllowed then
    begin
      Stems := Terms(Tokens[I].Original, Language);
      if N + Length(Stems) > Length(Tokens) then SetLength(Tokens, (N + Length(Stems)) * 2);
      for J := 0 to High(Stems) do
      begin
        Tokens[N] := Tokens[I];
        Tokens[N].Term := Stems[J];
        Tokens[N].Primary := False;
        Inc(N);
      end;
    end;
  SetLength(Tokens, N);
end;

end.
