unit CatalogImport;

{ Bulk JSON imports, READMEs and logos for catalog-import holders. Fields
  are checked against registered fields and choices before storage; manual
  Add and Edit use the same checks. See docs/API.md for the requests. }

{$mode objfpc}{$H+}

interface

uses fpjson;

{ One row of an import, checked: Item holds what may be stored, named by
  column.  False, and no Item, when a value is not allowed or the row has
  no entry_key and name. }
function CatalogImportRow(Data: TJSONData; out Item: TJSONObject): boolean;
{ The text of an import as its array of rows; nil when it is too long, too
  deep, not JSON or not an array of up to 500. }
function CatalogImportJSON(const Text: string): TJSONArray;
{ Stores one checked import row: a new entry, or an existing one's new
  values.  True for a new entry.  The caller holds the transaction and the
  catalog_totals row, as an import does. }
function CatalogStoreImport(Item: TJSONObject): boolean;

implementation

uses
  Classes, SysUtils, StrUtils, Variants, jsonparser, httpdefs, httproute,
  SiteDb, SiteUsers, SiteRoles, SiteAdmin, SiteGuard, SiteMarkup, WebPages, SiteWords, SiteSql, Catalog;

const
  ReadmeBytes = 190000;
  ImportBytes = 2 * 1024 * 1024;

function CatalogDate(const Text: string; out Value: TDateTime): boolean;
var
  Y, M, D, I: integer;
begin
  Value := 0;
  Result := False;
  if Length(Text) <> 10 then
    Exit;
  for I := 1 to Length(Text) do
    if not (I in [5, 8]) and not (Text[I] in ['0'..'9']) then
      Exit;
  Result := (Length(Text) = 10) and (Text[5] = '-') and (Text[8] = '-') and TryStrToInt(Copy(Text, 1, 4), Y) and TryStrToInt(Copy(Text, 6, 2), M) and
    TryStrToInt(Copy(Text, 9, 2), D);
  if Result then
    Result := (Y >= 1000) and (Y <= 9999) and (M >= 1) and (M <= 12) and (D >= 1) and (D <= 31) and TryEncodeDate(Y, M, D, Value);
end;

function CatalogImportRow(Data: TJSONData; out Item: TJSONObject): boolean;
var
  Source: TJSONObject;
  Field: TJSONData;
  I: integer;
  NumberValue: int64;
  TextValue, FieldName: string;
  FieldSize: integer;
  FieldKind: TCatalogFieldKind;
  DateValue: TDateTime;
begin
  Result := False;
  Item := nil;
  if not (Data is TJSONObject) then
    Exit;
  Source := TJSONObject(Data);
  Item := TJSONObject.Create;
  try
    for I := 0 to 31 do
    begin
      CatalogFieldAt(I, FieldName, FieldSize, FieldKind);
      if FieldName = '' then
        Continue;
      Field := Source.Find(FieldName);
      if (Field = nil) or (Field.JSONType = jtNull) then
        Continue;
      if FieldSize > 0 then
      begin
        if Field.JSONType <> jtString then
          Exit;
        TextValue := Trim(Field.AsString);
        if TextValue = '' then
          Continue;
        if (Length(UTF8Decode(TextValue)) > FieldSize) or ((I = 3) and (Length(TextValue) > FieldSize)) then
          Exit;
        if Length(CatalogChoices(FieldName)) > 0 then
        begin
          TextValue := LowerCase(TextValue);
          if not AnsiMatchStr(TextValue, CatalogChoices(FieldName)) then
            Exit;
        end;
        case I of
          0: begin
            TextValue := CatalogEntryKey(TextValue);
            if TextValue = '' then
              Exit;
          end;
          4, 21: if not CatalogURL(TextValue) then
              Exit;
          8: TextValue := CatalogCategories(TextValue);
          31: TextValue := LowerCase(CatalogCategories(TextValue));
        end;
        if TextValue <> '' then
          Item.Add(FieldName, TextValue);
      end
      else if FieldKind = cfDate then
      begin
        if Field.JSONType <> jtString then
          Exit;
        TextValue := Trim(Field.AsString);
        if TextValue = '' then
          Continue;
        if not CatalogDate(TextValue, DateValue) then
          Exit;
        Item.Add(FieldName, TextValue);
      end
      else
      begin
        if (FieldKind = cfBoolean) and (Field.JSONType = jtBoolean) then
          NumberValue := Ord(Field.AsBoolean)
        else if (Field.JSONType <> jtNumber) or not TryStrToInt64(Field.AsJSON, NumberValue) then
          Exit;
        if (NumberValue < 0) or (NumberValue > High(integer)) or ((FieldKind = cfBoolean) and (NumberValue > 1)) then
          Exit;
        Item.Add(FieldName, NumberValue);
      end;
    end;
    Field := Source.Find('hidden_note');
    if Field <> nil then
      if Field.JSONType = jtNull then
        Item.Add('hidden_note', TJSONNull.Create)
      else if (Field.JSONType <> jtString) or (Length(UTF8Decode(Field.AsString)) > 1000) then
        Exit
      else if Trim(Field.AsString) = '' then
        Item.Add('hidden_note', TJSONNull.Create)
      else
        Item.Add('hidden_note', Trim(Field.AsString));
    Result := (Item.Get('entry_key', '') <> '') and (Item.Get('name', '') <> '');
  finally
    if not Result then
      FreeAndNil(Item);
  end;
end;

function CatalogImportJSON(const Text: string): TJSONArray;
var
  Data: TJSONData;
begin
  Result := nil;
  if (Length(Text) = 0) or (Length(Text) > ImportBytes) or not CatalogJSONDepthOK(Text) then
    Exit;
  try
    Data := GetJSON(Text);
  except
    Exit;
  end;
  if (Data is TJSONArray) and (Data.Count <= 500) then
    Result := TJSONArray(Data)
  else
    Data.Free;
end;

{ The host kind and address an entry is read from, spelled one way: case,
  a slash at the end or .git do not make it another address. }
function EntryPlace(Id: integer): string;
begin
  Result := '';
  with Query('SELECT forge, url, entry_key FROM catalog_entries WHERE id = :i', [Id]) do
  try
    if not EOF then
      if Fields[1].AsString = '' then
        Result := Fields[0].AsString + ' https://' + Fields[2].AsString
      else
        Result := Fields[0].AsString + ' ' + Fields[1].AsString;
  finally
    Free;
  end;
  Result := LowerCase(Result);
  while Result.EndsWith('/') do
    SetLength(Result, Length(Result) - 1);
  if Result.EndsWith('.git') then
    SetLength(Result, Length(Result) - 4);
end;

function CatalogStoreImport(Item: TJSONObject): boolean;
var
  J, ExistingId: integer;
  Columns, Params, Changes, ColumnName, OldPlace: string;
  BindValues: array of variant;
begin
  BindValues := nil;
  ExistingId := IntValue('SELECT id FROM catalog_entries WHERE entry_key = :k', [Item.Strings['entry_key']]);
  Result := ExistingId = 0;
  OldPlace := '';
  if (ExistingId > 0) and CatalogMovesHeard then
    OldPlace := EntryPlace(ExistingId);
  Columns := '';
  Params := '';
  Changes := '';
  SetLength(BindValues, Item.Count);
  for J := 0 to Item.Count - 1 do
  begin
    ColumnName := Item.Names[J];
    if J > 0 then
    begin
      Columns := Columns + ', ';
      Params := Params + ', ';
      Changes := Changes + ', ';
    end;
    Columns := Columns + ColumnName;
    Params := Params + ':v' + IntToStr(J);
    // what an admin or a maintainer set by hand stays
    if CatalogKeptWhen(ColumnName) <> '' then
      Changes := Changes + ColumnName + ' = ' + SqlIf(CatalogKeptWhen(ColumnName), ColumnName, SqlNew(ColumnName))
    else
      Changes := Changes + ColumnName + ' = ' + SqlNew(ColumnName);
    if Item.Items[J].JSONType = jtNull then
      BindValues[J] := Null
    else if Item.Items[J].JSONType = jtNumber then
      BindValues[J] := Item.Items[J].AsInt64
    else
      BindValues[J] := Item.Items[J].AsString;
  end;
  Exec('INSERT INTO catalog_entries (' + Columns + ', seen) VALUES (' + Params + ', ' + SqlUtcNow + ')' + SqlOnConflict('entry_key',
    Changes + ', seen = ' + SqlUtcNow), BindValues);
  if Result then
    Exec('UPDATE catalog_totals SET visible = visible + 1 WHERE id = 1', [])
  // what was read from the old address is not this project's any more
  else if CatalogMovesHeard and (EntryPlace(ExistingId) <> OldPlace) then
    CatalogEntryMoved(ExistingId);
end;

procedure ImportCatalog(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Batch: TJSONArray;
  Item: TJSONObject;
  I, Added, Updated, Refused: integer;
begin
  if not NeedPermission(ARequest, AResponse, 'catalog-import', Me) then
    Exit;
  Batch := CatalogImportJSON(ARequest.Content);
  if Batch = nil then
  begin
    SendText(AResponse, 400, Say('Send a JSON array of up to 500 entries, up to 2 MB.'));
    Exit;
  end;
  Added := 0;
  Updated := 0;
  Refused := 0;
  try
    Exec('START TRANSACTION', []);
    try
      // Serialize imports and visibility changes with the saved total.
      IntValue('SELECT visible FROM catalog_totals WHERE id = 1 FOR UPDATE', []);
      for I := 0 to Batch.Count - 1 do
      begin
        if not CatalogImportRow(Batch.Items[I], Item) then
        begin
          Inc(Refused);
          Continue;
        end;
        try
          if CatalogStoreImport(Item) then
            Inc(Added)
          else
            Inc(Updated);
        finally
          Item.Free;
        end;
      end;
      Exec('COMMIT', []);
    except
      Exec('ROLLBACK', []);
      raise;
    end;
    CatalogEntriesChanged;
    SendJSON(AResponse, TJSONObject.Create(['added', Added, 'updated', Updated, 'refused', Refused]));
  finally
    Batch.Free;
  end;
end;

{ POST /api/catalog/icons  a JSON array of (entry_key, icon) objects: a project's own logo.
  An address that is not on a code host clears it, back to the owner's picture. }
procedure ImportIcons(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Data: TJSONData;
  Row: TJSONObject;
  I, Saved: integer;
  Icon: string;
begin
  if not NeedPermission(ARequest, AResponse, 'catalog-import', Me) then
    Exit;
  Data := nil;
  try
    if CatalogJSONDepthOK(ARequest.Content) then
      Data := GetJSON(ARequest.Content);
  except
    on Exception do
      Data := nil;
  end;
  if not (Data is TJSONArray) then
  begin
    Data.Free;
    SendText(AResponse, 400, Say('Send a JSON array of up to 500 entries, up to 2 MB.'));
    Exit;
  end;
  Saved := 0;
  try
    for I := 0 to Data.Count - 1 do
      if Data.Items[I] is TJSONObject then
      begin
        Row := TJSONObject(Data.Items[I]);
        Icon := Row.Get('icon', '');
        if not CatalogImageAllowed(Icon) then
          Icon := '';
        Exec('UPDATE catalog_entries SET icon = :i WHERE entry_key = :k', [Icon, CatalogEntryKey(Row.Get('entry_key', ''))]);
        Inc(Saved);
      end;
    SendJSON(AResponse, TJSONObject.Create(['saved', Saved]));
  finally
    Data.Free;
  end;
end;

{ POST /api/catalog/readme  a JSON array of (entry_key, readme, readme_url, image) objects.
  Made into HTML here, once, with raw HTML escaped. }
procedure ImportReadmes(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Data: TJSONData;
  Row: TJSONObject;
  I, Id, Saved, Refused: integer;
  Body, Image: string;
begin
  if not NeedPermission(ARequest, AResponse, 'catalog-import', Me) then
    Exit;
  Data := nil;
  try
    if CatalogJSONDepthOK(ARequest.Content) then
      Data := GetJSON(ARequest.Content);
  except
    on Exception do
      Data := nil;
  end;
  if not (Data is TJSONArray) then
  begin
    Data.Free;
    SendText(AResponse, 400, Say('Send a JSON array of up to 500 entries, up to 2 MB.'));
    Exit;
  end;
  Saved := 0;
  Refused := 0;
  try
    for I := 0 to Data.Count - 1 do
    begin
      if not (Data.Items[I] is TJSONObject) then
      begin
        Inc(Refused);
        Continue;
      end;
      Row := TJSONObject(Data.Items[I]);
      Body := Row.Get('readme', '');
      Id := IntValue('SELECT id FROM catalog_entries WHERE entry_key = :k', [CatalogEntryKey(Row.Get('entry_key', ''))]);
      if (Id = 0) or (Body = '') or (Length(Body) > ReadmeBytes) then
      begin
        Inc(Refused);
        Continue;
      end;
      try
        Exec('START TRANSACTION', []);
        Id := IntValue('SELECT id FROM catalog_entries WHERE entry_key = :k FOR UPDATE', [CatalogEntryKey(Row.Get('entry_key', ''))]);
        if Id = 0 then
        begin
          Exec('ROLLBACK', []);
          Inc(Refused);
          Continue;
        end;
        Exec(SqlReplace('catalog_readmes', 'entry_id, body, html, url, fetched, rendered', ':e, :b, :h, :u, ' + SqlUtcNow + ', :r'),
          [Id, Body, CatalogReadmeHtml(Body), Copy(Row.Get('readme_url', ''), 1, 2000), ReadmeRenderVersion]);
        Image := Row.Get('image', '');
        if not CatalogImageAllowed(Image) then
          Image := '';
        Exec('UPDATE catalog_entries SET image = :i WHERE id = :e', [Image, Id]);
        Exec('COMMIT', []);
        Inc(Saved);
      except
        on E: Exception do
        begin
          Exec('ROLLBACK', []);
          Log('A README would not go in: ' + E.Message);
          Inc(Refused);
        end;
      end;
    end;
    SendJSON(AResponse, TJSONObject.Create(['saved', Saved, 'refused', Refused]));
  finally
    Data.Free;
  end;
end;

initialization
  RegisterPermission('catalog-import', 'Import entries into the catalog', 'admin');
  RegisterRequestLimit('catimport', 'Catalog imports', 30, 30, 1);
  RegisterAdminRoute('/api/catalog/import', 'catalog-import');
  RegisterAdminRoute('/api/catalog/readme', 'catalog-import');
  RegisterAdminRoute('/api/catalog/icons', 'catalog-import');
  RegisterBodyLimit('/api/catalog/import', ImportBytes);
  RegisterBodyLimit('/api/catalog/readme', ImportBytes);
  RegisterBodyLimit('/api/catalog/icons', ImportBytes);
  LimitRoute('catimport', '/api/catalog/import', 'POST');
  LimitRoute('catimport', '/api/catalog/readme', 'POST');
  LimitRoute('catimport', '/api/catalog/icons', 'POST');
  HTTPRouter.RegisterRoute('/api/catalog/import', rmPost, @ImportCatalog);
  HTTPRouter.RegisterRoute('/api/catalog/readme', rmPost, @ImportReadmes);
  HTTPRouter.RegisterRoute('/api/catalog/icons', rmPost, @ImportIcons);
end.
