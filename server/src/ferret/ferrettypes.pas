unit FerretTypes;

{$mode objfpc}{$H+}
// Copyright (c) 2026 Tony Stone. 0BSD; see LICENSE.

interface

uses SysUtils, Math;

const
  FerretPrefixLimit = 64;

type
  EFerret = class(Exception);
  TFerretFactKind = (ffString, ffInteger, ffDate);

  TFerretFact = record
    Name: string;
    Kind: TFerretFactKind;
    Text: string;
    Number: int64;
    Date: TDateTime;
  end;
  TFerretFacts = array of TFerretFact;

  TFerretField = record
    Name, Text: string;
    Weight: double;
    WordCount: integer;
  end;
  TFerretFields = array of TFerretField;

  TFerretDocument = class
  public
    Id, Language: string;
    Fields: TFerretFields;
    Facts: TFerretFacts;
    constructor Create(const AId: string);
    procedure AddField(const Name, Text: string; Weight: double = 1);
    procedure SetFact(const Name, Value: string); overload;
    procedure SetFact(const Name: string; Value: int64); overload;
    procedure SetDate(const Name: string; Value: TDateTime);
    function Clone: TFerretDocument;
  end;

  TFerretNextDocument = function: TFerretDocument of object;
  TFerretRebuildProgress = function(Done, Total: int64): boolean of object;

  TFerretAllow = function(const Id: string; const Facts: TFerretFacts): boolean of object;
  TFerretTextProvider = function(const Id, Field: string): string of object;

  TFerretFilter = record
    Name: string;
    Values: TFerretFacts;
  end;
  TFerretFilters = array of TFerretFilter;
  TFerretStrings = array of string;

  // A fact that raises the score: a larger number, or with Recent a newer date.
  TFerretPreference = record
    Name: string;
    Recent: boolean;
    Half, Gain: double;
    Reference: TDateTime;
  end;
  TFerretPreferences = array of TFerretPreference;

  TFerretQuery = class
  private
    FPreparedFilters: TFerretFilters;
    FFiltersPrepared: boolean;
    procedure Prefer(const Name: string; Recent: boolean; Half, Gain: double; Reference: TDateTime);
  public
    Text: string;
    Fields: TFerretStrings;
    Filters: TFerretFilters;
    Preferences: TFerretPreferences;
    Offset, Limit, SnippetLength: integer;
    PrefixLast, Snippets, Prune, CorrectSpelling: boolean;
    // SnippetHtml escapes & < > " in the shown text, not in the markers. MarkTitle fills Hit.MarkedTitle.
    SnippetHtml, MarkTitle: boolean;
    OpenMarker, CloseMarker: string;
    OnAllow: TFerretAllow;
    constructor Create(const AText: string);
    procedure RequireAny(const Name: string; const Values: array of string); overload;
    procedure RequireAny(const Name: string; const Values: array of int64); overload;
    procedure RequireFact(const Name, Value: string); overload;
    procedure RequireFact(const Name: string; Value: int64); overload;
    procedure RequireDate(const Name: string; Value: TDateTime);
    procedure PreferHigh(const Name: string; Half, Gain: double);
    procedure PreferRecent(const Name: string; HalfLifeDays, Gain: double; Today: TDateTime = 0);
    function Preference(const Document: TFerretDocument): double;
    function PreferenceLimit: double;
    procedure PrepareFilters;
    procedure ClearPreparedFilters;
    function Allows(const Document: TFerretDocument): boolean;
    function IncludesField(const Name: string): boolean;
  end;

  TFerretDocumentEntry = record
    Id: string;
    Facts: TFerretFacts;
  end;
  TFerretDocumentList = array of TFerretDocumentEntry;

  TFerretHit = record
    Id, Title, MarkedTitle, Snippet: string;
    Score: double;
  end;
  TFerretHits = array of TFerretHit;

  TFerretSearchInfo = record
    ShowingResultsFor, DidYouMean: string;
  end;

  // An offer while typing: a document title, or a query to run.
  TFerretOfferKind = (foTitle, foWords);

  TFerretOffer = record
    Text: string;
    Kind: TFerretOfferKind;
    // The document of a title, when exactly one readable document has that title.
    Id: string;
  end;
  TFerretOffers = array of TFerretOffer;

implementation

function FactSlot(var Facts: TFerretFacts; const Name: string): integer;
begin
  if Name = '' then raise EFerret.Create('A fact needs a name.');
  for Result := 0 to High(Facts) do
    if Facts[Result].Name = Name then Exit;
  Result := Length(Facts);
  SetLength(Facts, Result + 1);
  Facts[Result].Name := Name;
end;

constructor TFerretDocument.Create(const AId: string);
begin
  inherited Create;
  Id := AId;
end;

procedure TFerretDocument.AddField(const Name, Text: string; Weight: double);
var
  I: integer;
begin
  if Name = '' then raise EFerret.Create('A field needs a name.');
  if (Weight <= 0) or (Weight > 1000000) then raise EFerret.Create('A field weight must be positive and finite.');
  for I := 0 to High(Fields) do
    if Fields[I].Name = Name then raise EFerret.Create('Duplicate field: ' + Name);
  I := Length(Fields);
  SetLength(Fields, I + 1);
  Fields[I].Name := Name;
  Fields[I].Text := Text;
  Fields[I].Weight := Weight;
end;

procedure TFerretDocument.SetFact(const Name, Value: string);
var
  I: integer;
begin
  I := FactSlot(Facts, Name);
  Facts[I].Kind := ffString;
  Facts[I].Text := Value;
end;

procedure TFerretDocument.SetFact(const Name: string; Value: int64);
var
  I: integer;
begin
  I := FactSlot(Facts, Name);
  Facts[I].Kind := ffInteger;
  Facts[I].Number := Value;
end;

procedure TFerretDocument.SetDate(const Name: string; Value: TDateTime);
var
  I: integer;
begin
  I := FactSlot(Facts, Name);
  Facts[I].Kind := ffDate;
  Facts[I].Date := Value;
end;

function TFerretDocument.Clone: TFerretDocument;
begin
  Result := TFerretDocument.Create(Id);
  Result.Language := Language;
  Result.Fields := Copy(Fields);
  Result.Facts := Copy(Facts);
end;

constructor TFerretQuery.Create(const AText: string);
begin
  inherited Create;
  Text := AText;
  Limit := 20;
  SnippetLength := 160;
  PrefixLast := True;
  Prune := True;
  Snippets := True;
  OpenMarker := '[';
  CloseMarker := ']';
end;

procedure TFerretQuery.RequireAny(const Name: string; const Values: array of string);
var
  I, N: integer;
begin
  N := Length(Filters);
  SetLength(Filters, N + 1);
  Filters[N].Name := Name;
  SetLength(Filters[N].Values, Length(Values));
  for I := 0 to High(Values) do
  begin
    Filters[N].Values[I].Kind := ffString;
    Filters[N].Values[I].Text := Values[I];
  end;
end;

procedure TFerretQuery.RequireAny(const Name: string; const Values: array of int64);
var
  I, N: integer;
begin
  N := Length(Filters);
  SetLength(Filters, N + 1);
  Filters[N].Name := Name;
  SetLength(Filters[N].Values, Length(Values));
  for I := 0 to High(Values) do
  begin
    Filters[N].Values[I].Kind := ffInteger;
    Filters[N].Values[I].Number := Values[I];
  end;
end;

procedure TFerretQuery.RequireFact(const Name, Value: string);
begin
  RequireAny(Name, [Value]);
end;

procedure TFerretQuery.RequireFact(const Name: string; Value: int64);
begin
  RequireAny(Name, [Value]);
end;

procedure TFerretQuery.RequireDate(const Name: string; Value: TDateTime);
var
  N: integer;
begin
  N := Length(Filters);
  SetLength(Filters, N + 1);
  Filters[N].Name := Name;
  SetLength(Filters[N].Values, 1);
  Filters[N].Values[0].Kind := ffDate;
  Filters[N].Values[0].Date := Value;
end;

procedure CheckPreference(const Item: TFerretPreference);
begin
  if Item.Name = '' then raise EFerret.Create('A preference needs a fact name.');
  if IsNan(Item.Half) or IsInfinite(Item.Half) or (Item.Half <= 0) or IsNan(Item.Gain) or (Item.Gain <= 0) or (Item.Gain > 1000000) then
    raise EFerret.Create('A preference needs a positive and finite half and gain.');
  if IsNan(Item.Reference) or IsInfinite(Item.Reference) then raise EFerret.Create('A preference date must be finite.');
end;

procedure TFerretQuery.Prefer(const Name: string; Recent: boolean; Half, Gain: double; Reference: TDateTime);
var
  Item: TFerretPreference;
begin
  Item.Name := Name;
  Item.Recent := Recent;
  Item.Half := Half;
  Item.Gain := Gain;
  Item.Reference := Reference;
  CheckPreference(Item);
  SetLength(Preferences, Length(Preferences) + 1);
  Preferences[High(Preferences)] := Item;
end;

procedure TFerretQuery.PreferHigh(const Name: string; Half, Gain: double);
begin
  Prefer(Name, False, Half, Gain, 0);
end;

procedure TFerretQuery.PreferRecent(const Name: string; HalfLifeDays, Gain: double; Today: TDateTime);
begin
  // The date is taken here, so scoring never reads the clock.
  if not IsNan(Today) and (Today = 0) then Today := Now;
  Prefer(Name, True, HalfLifeDays, Gain, Today);
end;

// From 1 to PreferenceLimit: each preference adds its gain times a share from 0 to 1.
function TFerretQuery.Preference(const Document: TFerretDocument): double;
var
  I, J: integer;
  Share, Value: double;
begin
  Result := 1;
  for I := 0 to High(Preferences) do
  begin
    Share := 0;
    for J := 0 to High(Document.Facts) do
      if Document.Facts[J].Name = Preferences[I].Name then
      begin
        if Preferences[I].Recent and (Document.Facts[J].Kind = ffDate) then
        begin
          Value := Max(0, Preferences[I].Reference - Document.Facts[J].Date);
          Share := Preferences[I].Half / (Preferences[I].Half + Value);
        end
        else if not Preferences[I].Recent and (Document.Facts[J].Kind = ffInteger) and (Document.Facts[J].Number >= 1) then
        begin
          Value := Document.Facts[J].Number;
          Share := Value / (Value + Preferences[I].Half);
        end;
        Break;
      end;
    Result := Result + Preferences[I].Gain * Share;
  end;
end;

function TFerretQuery.PreferenceLimit: double;
var
  I: integer;
begin
  Result := 1;
  for I := 0 to High(Preferences) do Result := Result + Preferences[I].Gain;
end;

function CompareFact(const A, B: TFerretFact): integer;
begin
  Result := Ord(A.Kind) - Ord(B.Kind);
  if Result <> 0 then Exit;
  case A.Kind of
    ffString:
      if A.Text < B.Text then Result := -1
      else if A.Text > B.Text then Result := 1;
    ffInteger:
      if A.Number < B.Number then Result := -1
      else if A.Number > B.Number then Result := 1;
    ffDate:
      if A.Date < B.Date then Result := -1
      else if A.Date > B.Date then Result := 1;
  end;
end;

procedure SortFacts(var Values: TFerretFacts; L, H: integer);
var
  I, J: integer;
  Pivot, Swap: TFerretFact;
begin
  if L >= H then Exit;
  I := L;
  J := H;
  Pivot := Values[L + (H - L) div 2];
  repeat
    while CompareFact(Values[I], Pivot) < 0 do Inc(I);
    while CompareFact(Values[J], Pivot) > 0 do Dec(J);
    if I <= J then
    begin
      Swap := Values[I];
      Values[I] := Values[J];
      Values[J] := Swap;
      Inc(I);
      Dec(J);
    end;
  until I > J;
  if L < J then SortFacts(Values, L, J);
  if I < H then SortFacts(Values, I, H);
end;

procedure TFerretQuery.PrepareFilters;
var
  I, J: integer;
begin
  ClearPreparedFilters;
  // A record appended by hand is held to the rules of PreferHigh and PreferRecent.
  for I := 0 to High(Preferences) do CheckPreference(Preferences[I]);
  FPreparedFilters := Copy(Filters);
  for I := 0 to High(FPreparedFilters) do
  begin
    FPreparedFilters[I].Values := Copy(Filters[I].Values);
    for J := 0 to High(FPreparedFilters[I].Values) do
      if FPreparedFilters[I].Values[J].Kind = ffDate then
        if IsNan(FPreparedFilters[I].Values[J].Date) or IsInfinite(FPreparedFilters[I].Values[J].Date) then
          raise EFerret.Create('A filter date must be finite.');
    SortFacts(FPreparedFilters[I].Values, 0, High(FPreparedFilters[I].Values));
  end;
  FFiltersPrepared := True;
end;

procedure TFerretQuery.ClearPreparedFilters;
begin
  FFiltersPrepared := False;
  FPreparedFilters := nil;
end;

function TFerretQuery.Allows(const Document: TFerretDocument): boolean;
var
  I, J, K, L, H, M: integer;
  Found: boolean;
  Selected: TFerretFilters;
begin
  Result := False;
  if FFiltersPrepared then Selected := FPreparedFilters
  else
    Selected := Filters;
  for I := 0 to High(Selected) do
  begin
    Found := False;
    for J := 0 to High(Document.Facts) do
      if Document.Facts[J].Name = Selected[I].Name then
      begin
        if FFiltersPrepared then
        begin
          L := 0;
          H := Length(Selected[I].Values);
          while L < H do
          begin
            M := L + (H - L) div 2;
            if CompareFact(Selected[I].Values[M], Document.Facts[J]) < 0 then L := M + 1
            else
              H := M;
          end;
          Found := (L < Length(Selected[I].Values)) and (CompareFact(Selected[I].Values[L], Document.Facts[J]) = 0);
        end
        else
          for K := 0 to High(Selected[I].Values) do
            if CompareFact(Document.Facts[J], Selected[I].Values[K]) = 0 then
            begin
              Found := True;
              Break;
            end;
        Break;
      end;
    if not Found then Exit;
  end;
  if Assigned(OnAllow) then
    if not OnAllow(Document.Id, Document.Facts) then Exit;
  Result := True;
end;

function TFerretQuery.IncludesField(const Name: string): boolean;
var
  I: integer;
begin
  Result := Length(Fields) = 0;
  for I := 0 to High(Fields) do
    if Fields[I] = Name then Exit(True);
end;

end.
