unit CatalogAdmin;

{ Catalog administration: entries, pictures and recent reader activity.
  Permissions are view-catalog, edit-catalog and delete-catalog, held by
  catalog-admin. catalog-admin.js draws the tab; RegisterCatalogAdminList
  adds columns, filters and details. }

{$mode objfpc}{$H+}

interface

uses fpjson, httpdefs;

type
  { A unit's own filters and sorts for the admin's list of entries: it may
    add to Where (with AND), replace Order, and note its choice in Answer.
    Joined is put after the list's rows x, for a join on x.id that Where and
    Order may use; Sorted is such a join that only Order uses, left out of
    the count of matches. }
  TCatalogAdminChoice = procedure(ARequest: TRequest; var Where, Order, Joined, Sorted: string; Answer: TJSONObject);
  { More facts for the entries on one page of the list, each item found by its id. }
  TCatalogAdminFacts = procedure(ARequest: TRequest; Items: TJSONArray);

{ Columns are more columns of catalog_entries e for Choice to filter and
  sort by, written as they follow a SELECT list: ', e.one, (...) AS two'. }
procedure RegisterCatalogAdminList(const Columns: string; Choice: TCatalogAdminChoice; Facts: TCatalogAdminFacts);

implementation

uses
  Classes, SysUtils, Variants, StrUtils, DB, httproute,
  SiteDb, SiteUsers, SiteRoles, SiteAdmin, SiteGuard, SiteGuardRules, SiteMarkup, SiteStats, SiteVisitors, SiteFiles, SiteScan,
  Catalog, CatalogImport, SiteParts, SiteWords, SiteSql;

const
  // the purpose an entry's picture carries in the files table
  CATALOG_FILE = 'catalog';
  MB = 1024 * 1024;

var
  ListParts: array of record
    Columns: string;
    Choice: TCatalogAdminChoice;
    Facts: TCatalogAdminFacts;
    end;

procedure RegisterCatalogAdminList(const Columns: string; Choice: TCatalogAdminChoice; Facts: TCatalogAdminFacts);
begin
  SetLength(ListParts, Length(ListParts) + 1);
  ListParts[High(ListParts)].Columns := Columns;
  ListParts[High(ListParts)].Choice := Choice;
  ListParts[High(ListParts)].Facts := Facts;
end;

{ The registered choices of a name, as a JSON list. }
function ChoiceList(const Name: string): TJSONArray;
var
  Choice: string;
begin
  Result := TJSONArray.Create;
  for Choice in CatalogChoices(Name) do
    Result.Add(Choice);
end;

// The rows of a GROUP BY as [{name, count}].
function CountGroups(const SQL: string): TJSONArray;
begin
  Result := TJSONArray.Create;
  with Query(SQL, []) do
  try
    while not EOF do
    begin
      Result.Add(TJSONObject.Create(['name', Fields[0].AsString, 'count', Fields[1].AsLargeInt]));
      Next;
    end;
  finally
    Free;
  end;
end;

function CatalogSources: TJSONArray;
var
  Counts: TStringList;
  SourceText: string;
  SourceCount: int64;
  I: integer;
begin
  Result := TJSONArray.Create;
  Counts := TStringList.Create;
  try
    with Query('SELECT sources, COUNT(*) FROM catalog_entries GROUP BY sources', []) do
    try
      while not EOF do
      begin
        SourceCount := Fields[1].AsLargeInt;
        for SourceText in Fields[0].AsString.Split([','], TStringSplitOptions.ExcludeEmpty) do
          Counts.Values[SourceText] := IntToStr(StrToInt64Def(Counts.Values[SourceText], 0) + SourceCount);
        Next;
      end;
    finally
      Free;
    end;
    Counts.Sort;
    for I := 0 to Counts.Count - 1 do
      Result.Add(TJSONObject.Create(['name', Counts.Names[I], 'count', StrToInt64Def(Counts.ValueFromIndex[I], 0)]));
  finally
    Counts.Free;
  end;
end;

procedure ShowCatalogAdmin(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Answer: TJSONObject;
  Items: TJSONArray;
  Words: string;
  Page: integer;
  Show, Where, Order, Kind, Sort, Inner, More, Joined, Sorted: string;
  I: integer;
begin
  if not NeedPermission(ARequest, AResponse, 'view-catalog', Me) then
    Exit;
  Words := Trim(ARequest.QueryFields.Values['q']);
  if Length(Words) > SettingInt('search_query_bytes', 100) then
  begin
    SendText(AResponse, 400, Say('Search text is too long.'));
    Exit;
  end;
  Page := StrToIntDef(ARequest.QueryFields.Values['page'], 0);
  if Page < 0 then
    Page := 0;
  if Page > 1000000 then
    Page := 1000000;
  // which entries: hidden (the default), reported by members, flagged by the
  // classifiers, or all; all=1 is the older way to ask for all
  Show := ARequest.QueryFields.Values['show'];
  if (Show = '') and (ARequest.QueryFields.Values['all'] = '1') then
    Show := 'all';
  Order := 'name, id';
  case Show of
    'reported':
    begin
      Where := 'reports > 0';
      Order := 'reports DESC, name, id';
    end;
    'flagged': Where := 'hidden_note LIKE ''Flagged for review%''';
    'all': Where := '1 = 1';
    else
    begin
      Show := 'hidden';
      Where := 'hidden = 1';
    end;
  end;
  // one kind only, and a column to sort by ('-' before it for the other way), both from fixed lists
  Kind := ARequest.QueryFields.Values['kind'];
  if AnsiMatchStr(Kind, CatalogChoices('kind')) then
    Where := Where + ' AND kind = ''' + Kind + ''''
  else
    Kind := '';
  Sort := ARequest.QueryFields.Values['sort'];
  case Sort of
    'name': Order := 'name, id';
    '-name': Order := 'name DESC, id';
    'key': Order := 'entry_key, id';
    '-key': Order := 'entry_key DESC, id';
    'kind': Order := 'kind, name, id';
    '-kind': Order := 'kind DESC, name, id';
    'works': Order := 'works_with, name, id';
    '-works': Order := 'works_with DESC, name, id';
    'reports': Order := 'reports, name, id';
    '-reports': Order := 'reports DESC, name, id';
    'state': Order := 'hidden, name, id';
    '-state': Order := 'hidden DESC, name, id';
    'id': Order := 'id';
    '-id': Order := 'id DESC';
  end;
  More := '';
  for I := 0 to High(ListParts) do
    More := More + ListParts[I].Columns;
  Inner := 'SELECT e.id, e.name, e.title, e.entry_key, e.kind, e.works_with, e.categories, e.hidden, e.hidden_note, e.url, e.summary, e.license, e.picture,' +
    ' (SELECT COUNT(*) FROM catalog_reports r WHERE r.entry_id = e.id AND r.resolved = 0) AS reports,' + ' (SELECT ' +
    SqlGroupConcat(SqlConcat(['r.reason', SqlIf('r.note <> ''''', SqlConcat([''': ''', 'r.note']), '''''')]) + ' ORDER BY r.created', '\n') +
    ' FROM catalog_reports r WHERE r.entry_id = e.id AND r.resolved = 0) AS report_notes' + More + ' FROM catalog_entries e' +
    ' WHERE (:q = '''' OR e.name LIKE :n OR e.title LIKE :t OR e.entry_key LIKE :k)';
  Items := TJSONArray.Create;
  Answer := TJSONObject.Create(['items', Items, 'page', Page, 'show', Show, 'kind', Kind, 'can', SitePermissions(Me)]);
  // the choices a site's own unit registered, for the page's filters and its edit form
  Answer.Add('choices', TJSONObject.Create(['kind', ChoiceList('kind'), 'works_with', ChoiceList('works_with')]));
  Joined := '';
  Sorted := '';
  try
    // Where, Order and Joined stay fixed texts: a part picks them by the request, never from it
    for I := 0 to High(ListParts) do
      if Assigned(ListParts[I].Choice) then
        ListParts[I].Choice(ARequest, Where, Order, Joined, Sorted, Answer);
    // the whole catalog's numbers, unless the page has them already (counts=0, a list's next search)
    if ARequest.QueryFields.Values['counts'] <> '0' then
    begin
      Answer.Add('total', IntValue('SELECT COUNT(*) FROM catalog_entries', []));
      Answer.Add('hidden', IntValue('SELECT COUNT(*) FROM catalog_entries WHERE hidden = 1', []));
      Answer.Add('reported', IntValue('SELECT COUNT(DISTINCT entry_id) FROM catalog_reports WHERE resolved = 0', []));
      Answer.Add('flagged', IntValue('SELECT COUNT(*) FROM catalog_entries WHERE hidden_note LIKE ''Flagged for review%''', []));
      Answer.Add('kinds', CountGroups('SELECT kind, COUNT(*) FROM catalog_entries GROUP BY kind ORDER BY kind'));
      Answer.Add('sources', CatalogSources);
      Answer.Add('statuses', CountGroups('SELECT ' + CatalogStatusSQL + ' AS state_text, COUNT(*) FROM catalog_entries GROUP BY state_text ORDER BY state_text'));
    end;
    // how many match, for the list's count
    Answer.Add('matches', IntValue('SELECT COUNT(*) FROM (' + Inner + ') x' + Joined + ' WHERE ' + Where, [Words, '%' + LikePrefix(Words),
      '%' + LikePrefix(Words), '%' + LikePrefix(Words)]));
    // Where and Order are chosen above from fixed texts, never from the request
    with Query('SELECT x.* FROM (' + Inner + ') x' + Joined + Sorted + ' WHERE ' + Where + ' ORDER BY ' + Order + ' LIMIT 51 OFFSET :o',
        [Words, '%' + LikePrefix(Words), '%' + LikePrefix(Words), '%' + LikePrefix(Words), Page * 50]) do
    try
      while not EOF do
      begin
        Items.Add(TJSONObject.Create(['id', Fields[0].AsInteger, 'name', Fields[1].AsString, 'title', Fields[2].AsString, 'entry_key',
          Fields[3].AsString, 'kind', Fields[4].AsString, 'works_with', Fields[5].AsString, 'categories', Fields[6].AsString, 'hidden',
          Fields[7].AsInteger = 1, 'hidden_note', Fields[8].AsString, 'url', Fields[9].AsString, 'summary', Fields[10].AsString, 'license',
          Fields[11].AsString, 'picture', CatalogPictureUrl(Fields[12].AsString), 'reports', Fields[13].AsInteger, 'report_notes', Fields[14].AsString]));
        Next;
      end;
    finally
      Free;
    end;
    Answer.Add('more', Items.Count > 50);
    if Items.Count > 50 then
      Items.Delete(50);
    for I := 0 to High(ListParts) do
      if Assigned(ListParts[I].Facts) then
        ListParts[I].Facts(ARequest, Items);
  except
    Answer.Free;
    raise;
  end;
  SendJSON(AResponse, Answer);
end;

const
  // what an admin may change of an entry's own words
  WordFields: array[0..3] of string = ('title', 'url', 'summary', 'license');

{ The words sent for an entry, checked as an import's row is checked.  A
  field not sent is left out; one sent empty stays in Sent with nothing, and
  clears the column.  False when a value is not allowed, or the title is
  emptied. }
function SentWords(ARequest: TRequest; Sent: TStrings): boolean;
var
  Source, Item: TJSONObject;
  Field, Text: string;
begin
  Source := TJSONObject.Create(['entry_key', 'check.local/entry', 'name', 'entry']);
  try
    for Field in WordFields do
      if ARequest.ContentFields.IndexOfName(Field) >= 0 then
      begin
        Text := Trim(ARequest.ContentFields.Values[Field]);
        Sent.Add(Field + '=' + Text);
        Source.Add(Field, Text);
      end;
    Result := ((Sent.IndexOfName('title') < 0) or (Sent.Values['title'] <> '')) and CatalogImportRow(Source, Item);
    if Result then
      Item.Free;
  finally
    Source.Free;
  end;
end;

{ A kind as an import takes it: one of the kinds a unit registered, or,
  with none registered, any 20 characters. }
function KindAllowed(const Kind: string): boolean;
begin
  if Length(CatalogChoices('kind')) > 0 then
    Result := AnsiMatchStr(Kind, CatalogChoices('kind'))
  else
    Result := Length(UTF8Decode(Kind)) <= 20;
end;

{ POST /api/admin/catalog/save  id, and any of: kind, works_with, categories,
  title, url, summary, license.  What is sent is changed and the rest stays.
  The entry keeps its key, so its address may change without it becoming
  another entry. }
procedure SaveCatalogEntry(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Id, I: integer;
  KindText, WorksText, CategoriesText: string;
  Words: TStringList;
begin
  if not NeedPermission(ARequest, AResponse, 'edit-catalog', Me) then
    Exit;
  Id := StrToIntDef(ARequest.ContentFields.Values['id'], 0);
  // works_with is one of the choices a unit registered, and so is kind where
  // kinds are registered; one not sent stays as it is
  KindText := Trim(ARequest.ContentFields.Values['kind']);
  WorksText := ARequest.ContentFields.Values['works_with'];
  CategoriesText := CatalogCategories(ARequest.ContentFields.Values['categories']);
  Words := TStringList.Create;
  try
    if ((KindText <> '') and not KindAllowed(KindText)) or ((WorksText <> '') and not AnsiMatchStr(WorksText, CatalogChoices('works_with'))) or
      (Length(UTF8Decode(CategoriesText)) > 200) or not SentWords(ARequest, Words) then
    begin
      SendText(AResponse, 400, Say('Check what you entered: an entry needs a title, and its address starts with https:// or http://.'));
      Exit;
    end;
    if IntValue('SELECT COUNT(*) FROM catalog_entries WHERE id = :i', [Id]) = 0 then
    begin
      SendText(AResponse, 404, Say('No entry by that number.'));
      Exit;
    end;
    // marked, so the next import keeps the admin's classification
    if (KindText <> '') or (WorksText <> '') then
      Exec('UPDATE catalog_entries SET kind = CASE WHEN :k = '''' THEN kind ELSE :k2 END, works_with = CASE WHEN :w = '''' THEN works_with ELSE :w2 END,' +
        ' admin_set = 1 WHERE id = :i', [KindText, KindText, WorksText, WorksText, Id]);
    // the categories are marked only when they were changed
    if (ARequest.ContentFields.IndexOfName('categories') >= 0) and (CategoriesText <> VarToStr(Value('SELECT categories FROM catalog_entries WHERE id = :i', [Id]))) then
      Exec('UPDATE catalog_entries SET categories = :c, admin_set = 1 WHERE id = :i', [CategoriesText, Id]);
    // and the same for its words, when any were sent; the column names are WordFields' own
    for I := 0 to Words.Count - 1 do
      Exec('UPDATE catalog_entries SET ' + Words.Names[I] + ' = :v, words_set = 1 WHERE id = :i', [Words.ValueFromIndex[I], Id]);
    if Words.Count > 0 then
      Log(Me.Name + ' changed the words of catalog entry ' + IntToStr(Id));
    CatalogEntriesChanged;
    SendText(AResponse, 200, Say('Saved.'));
  finally
    Words.Free;
  end;
end;

{ An entry's key from where it lives: the address without its scheme, a
  leading www., what follows a # and a slash at its end.  An entry with no
  address is keyed by its name.  An address or a name the key's letters
  cannot spell (a ? in it, a name in another script) gets a key made from
  its checksum, so it is still told apart from every other. }
function KeyFor(const Address, Name: string): string;
var
  C: char;
  P: integer;
begin
  Result := LowerCase(Trim(Address));
  if Result <> '' then
  begin
    P := Pos('://', Result);
    if P > 0 then
      Delete(Result, 1, P + 2);
    if Result.StartsWith('www.') then
      Delete(Result, 1, 4);
    if Pos('#', Result) > 0 then
      Result := Copy(Result, 1, Pos('#', Result) - 1);
    while Result.EndsWith('/') do
      SetLength(Result, Length(Result) - 1);
    if CatalogEntryKey(Result) = '' then
      Result := 'entry.local/e-' + Copy(Sha256Hex(Result), 1, 20);
    Exit;
  end;
  // letters and digits of the name, the rest as hyphens
  for C in LowerCase(Trim(Name)) do
    if C in ['a'..'z', '0'..'9'] then
      Result := Result + C
    else if (Result <> '') and not Result.EndsWith('-') then
      Result := Result + '-';
  while Result.EndsWith('-') do
    SetLength(Result, Length(Result) - 1);
  if Result <> '' then
    Result := 'entry.local/' + Result
  else if Trim(Name) <> '' then
    Result := 'entry.local/e-' + Copy(Sha256Hex(LowerCase(Trim(Name))), 1, 20);
end;

{ POST /api/admin/catalog/add  title, url, summary, categories, kind, license:
  an admin puts one entry in by hand.  The title is needed; the address is
  where the thing lives, when it lives somewhere.  Answers the new entry's
  number. }
procedure AddCatalogEntry(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Source, Item: TJSONObject;
  Title, Address, KeyText, Field: string;
  Id: integer;
begin
  if not NeedPermission(ARequest, AResponse, 'edit-catalog', Me) then
    Exit;
  Title := Trim(ARequest.ContentFields.Values['title']);
  Address := Trim(ARequest.ContentFields.Values['url']);
  KeyText := CatalogEntryKey(KeyFor(Address, Title));
  if (Title = '') or (KeyText = '') or ((Address <> '') and not CatalogURL(Address)) then
  begin
    SendText(AResponse, 400, Say('An entry needs a title; its address, when it has one, starts with https:// or http://.'));
    Exit;
  end;
  if IntValue('SELECT COUNT(*) FROM catalog_entries WHERE entry_key = :k', [KeyText]) > 0 then
  begin
    SendText(AResponse, 409, Say('There is an entry for that address already.'));
    Exit;
  end;
  // the same checks and the same storing as an import's row
  // the name is the short form of the title: 200 characters of it
  Source := TJSONObject.Create(['entry_key', KeyText, 'name', UTF8Encode(Copy(UTF8Decode(Title), 1, 200)), 'title', Title]);
  try
    if Address <> '' then
      Source.Add('url', Address);
    for Field in ['summary', 'categories', 'kind', 'license'] do
      if Trim(ARequest.ContentFields.Values[Field]) <> '' then
        Source.Add(Field, Trim(ARequest.ContentFields.Values[Field]));
    if not CatalogImportRow(Source, Item) then
    begin
      SendText(AResponse, 400, Say('Check the summary, the kind, the categories and the license.'));
      Exit;
    end;
  finally
    Source.Free;
  end;
  try
    Exec('START TRANSACTION', []);
    try
      IntValue('SELECT visible FROM catalog_totals WHERE id = 1 FOR UPDATE', []);
      CatalogStoreImport(Item);
      Id := IntValue('SELECT id FROM catalog_entries WHERE entry_key = :k', [KeyText]);
      // marked as the admin's, so a later import leaves its classification alone
      Exec('UPDATE catalog_entries SET admin_set = 1 WHERE id = :i', [Id]);
      Exec('COMMIT', []);
    except
      Exec('ROLLBACK', []);
      raise;
    end;
  finally
    Item.Free;
  end;
  CatalogEntriesChanged;
  Log(Me.Name + ' added catalog entry ' + IntToStr(Id) + ' (' + KeyText + ')');
  SendJSON(AResponse, TJSONObject.Create(['id', Id]));
end;

{ POST /api/admin/catalog/picture  id and file: the entry's picture, in
  place of the one it had; id and remove=1: no picture.  A PNG, JPEG, GIF
  or WebP by its first bytes, as large as catalog_picture_mb allows, kept
  where members' files are and reached the same way, /f/token/name. }
procedure SaveCatalogPicture(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Id, Code, Largest: integer;
  Sent: TUploadedFile;
  Token, Refusal: string;
begin
  if not NeedPermission(ARequest, AResponse, 'edit-catalog', Me) then
    Exit;
  Id := StrToIntDef(ARequest.ContentFields.Values['id'], 0);
  if IntValue('SELECT COUNT(*) FROM catalog_entries WHERE id = :i', [Id]) = 0 then
  begin
    SendText(AResponse, 404, Say('No entry by that number.'));
    Exit;
  end;
  Sent := nil;
  if ARequest.ContentFields.Values['remove'] <> '1' then
  begin
    if ARequest.Files.Count <> 1 then
    begin
      SendText(AResponse, 400, Say('Send one picture.'));
      Exit;
    end;
    Sent := ARequest.Files[0];
    Largest := SettingInt('catalog_picture_mb', 2);
    if Sent.Size > int64(Largest) * MB then
    begin
      SendText(AResponse, 413, Format(Say('A picture can be %d MB at most.'), [Largest]));
      Exit;
    end;
    if ImageType(Sent.LocalFileName) = '' then
    begin
      SendText(AResponse, 415, Say('An entry''s picture is a PNG, JPEG, GIF or WebP file.'));
      Exit;
    end;
    // before the transaction: a scan may take a while, and a refusal's row stays
    if not UploadScanPasses(Me.Id, CATALOG_FILE, Sent.FileName, Sent.LocalFileName, Refusal, Code) then
    begin
      SendText(AResponse, Code, Refusal);
      Exit;
    end;
  end;
  Token := '';
  // the picture before leaves the disk once the new one is in for good
  HoldFileDeletes;
  Exec('START TRANSACTION', []);
  try
    DeleteFilesOf(Id, CATALOG_FILE);
    if Sent <> nil then
    begin
      // the site's file, no member's: it counts against nobody's space
      Token := StoreFile(0, CATALOG_FILE, Sent.FileName, Sent.LocalFileName, 0, 0);
      AttachFiles(Id, 0, 0, Token, CATALOG_FILE, CATALOG_FILE);
    end;
    Exec('UPDATE catalog_entries SET picture = :p WHERE id = :i', [Token, Id]);
    Exec('COMMIT', []);
  except
    Exec('ROLLBACK', []);
    EndFileDeletes(False);
    raise;
  end;
  EndFileDeletes(True);
  Log(Me.Name + IfThen(Sent = nil, ' removed', ' set') + ' the picture of catalog entry ' + IntToStr(Id));
  SendJSON(AResponse, TJSONObject.Create(['picture', CatalogPictureUrl(Token)]));
end;

procedure DeleteCatalogEntry(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Id, Visible: integer;
begin
  if not NeedPermission(ARequest, AResponse, 'delete-catalog', Me) then
    Exit;
  Id := StrToIntDef(ARequest.ContentFields.Values['id'], 0);
  // its picture leaves the disk once the entry is gone for good
  HoldFileDeletes;
  Exec('START TRANSACTION', []);
  try
    IntValue('SELECT visible FROM catalog_totals WHERE id = 1 FOR UPDATE', []);
    Visible := -1;
    with Query('SELECT 1 - hidden FROM catalog_entries WHERE id = :i FOR UPDATE', [Id]) do
    try
      if not EOF then
        Visible := Fields[0].AsInteger;
    finally
      Free;
    end;
    if Visible < 0 then
    begin
      Exec('ROLLBACK', []);
      EndFileDeletes(False);
      SendText(AResponse, 404, Say('No entry by that number.'));
      Exit;
    end;
    DeleteFilesOf(Id, CATALOG_FILE);
    Exec('DELETE FROM catalog_ratings WHERE entry_id = :i', [Id]);
    Exec('DELETE FROM catalog_readmes WHERE entry_id = :i', [Id]);
    // its reports and Interesting go with it, or the counts drift
    Exec('DELETE FROM catalog_reports WHERE entry_id = :i', [Id]);
    Exec('DELETE FROM catalog_interest WHERE entry_id = :i', [Id]);
    // rows other units keep for the entry
    CatalogEntryDeleted(Id);
    Exec('DELETE FROM catalog_entries WHERE id = :i', [Id]);
    Exec('UPDATE catalog_totals SET visible = visible - :v WHERE id = 1', [Visible]);
    Exec('COMMIT', []);
  except
    Exec('ROLLBACK', []);
    EndFileDeletes(False);
    raise;
  end;
  EndFileDeletes(True);
  CatalogEntriesChanged;
  Log(Me.Name + ' deleted catalog entry ' + IntToStr(Id));
  SendText(AResponse, 200, Say('Deleted.'));
end;

{ A query's rows as objects named by its columns; numbers stay numbers. }
function RowsOf(const SQL: string): TJSONArray;
var
  Row: TJSONObject;
  I: integer;
begin
  Result := TJSONArray.Create;
  try
    with Query(SQL, []) do
    try
      while not EOF do
      begin
        Row := TJSONObject.Create;
        Result.Add(Row);
        for I := 0 to Fields.Count - 1 do
          if Fields[I].DataType in [ftSmallint, ftInteger, ftWord, ftLargeint, ftBCD, ftFMTBcd, ftFloat] then
            Row.Add(Fields[I].FieldName, Fields[I].AsLargeInt)
          else
            Row.Add(Fields[I].FieldName, Fields[I].AsString);
        Next;
      end;
    finally
      Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

{ Random entry and Interesting activity by day, reader, entry and filter.
  People are non-crawler steps sent by scripts or presses. days=0 includes
  all kept activity; hide=1 omits the admin and private addresses. }
procedure ShowCatalogActivity(ARequest: TRequest; AResponse: TResponse);
const
  Person = '(a.bot = '''' AND (a.hand = 1 OR a.action IN (''yes'', ''press'', ''unpress'')))';
  Shown = 'a.action IN (''start'', ''skip'', ''yes'', ''narrow'')';
var
  Me, Guest: TMember;
  Answer: TJSONObject;
  Days: integer;
  Since, Hide, Base, OwnWho: string;

  function Step(const Action: string): string;
  begin
    Result := 'CAST(SUM(' + Person + ' AND a.action = ''' + Action + ''') AS SIGNED) AS ' + Action;
  end;

begin
  if not NeedPermission(ARequest, AResponse, 'view-catalog', Me) then
    Exit;
  Days := StrToIntDef(ARequest.QueryFields.Values['days'], 7);
  if (Days < 0) or (Days > 400) then
    Days := 7;
  if Days = 0 then
    Since := '''2000-01-01'''
  else
    Since := SqlMinus('UTC_DATE()', IntToStr(Days - 1), suDay);
  // the admin's own steps: as a member, and from this address when signed out
  Guest := Default(TMember);
  OwnWho := InterestWho(ARequest, Guest);
  Hide := '';
  if ARequest.QueryFields.Values['hide'] <> '0' then
    Hide := ' AND a.local_net = 0 AND a.member_id <> ' + IntToStr(Me.Id) + ' AND a.who <> ''' + OwnWho + '''';
  Base := ' FROM catalog_actions a WHERE a.created >= ' + Since + Hide;
  Answer := TJSONObject.Create(['days', Days]);
  try
    Answer.Add('since', VarToStr(Value('SELECT ' + IsoTime('MIN(created)') + ' FROM catalog_actions', [])));
    Answer.Add('totals', RowsOf('SELECT COUNT(DISTINCT CASE WHEN ' + Person + ' THEN a.who END) AS people,' + ' COUNT(DISTINCT CASE WHEN ' +
      Person + ' AND ' + Shown + ' THEN a.who END) AS discoverers,' + ' COUNT(DISTINCT CASE WHEN ' + Person + ' AND a.member_id > 0 THEN a.who END) AS members, ' +
      Step('start') + ', ' + Step('skip') + ', ' + Step('yes') + ', ' + Step('narrow') + ', ' + Step('press') + ', ' + Step('unpress') +
      ', CAST(COALESCE(SUM(NOT ' + Person + '), 0) AS SIGNED) AS crawler_steps' + Base));
    Answer.Add('by_day', RowsOf('SELECT ' + SqlDay('a.created') + ' AS day, COUNT(DISTINCT CASE WHEN ' + Person + ' THEN a.who END) AS people, ' +
      Step('start') + ', ' + Step('skip') + ', ' + Step('yes') + ', ' + Step('narrow') + ', ' + Step('press') + ', ' + Step('unpress') +
      ', CAST(SUM(NOT ' + Person + ') AS SIGNED) AS crawler_steps' + Base + ' GROUP BY day ORDER BY day DESC'));
    Answer.Add('people', RowsOf('SELECT a.who, COALESCE(MAX(u.name), '''') AS name, ' + IsoTime('MIN(a.created)') + ' AS first, ' +
      IsoTime('MAX(a.created)') + ' AS last, COUNT(DISTINCT ' + SqlDate('a.created') + ') AS days, ' + Step('start') + ', ' + Step('skip') +
      ', ' + Step('yes') + ', ' + Step('narrow') + ', ' + Step('press') + ', ' + Step('unpress') + ', COALESCE(' + SqlGroupConcat(
      'DISTINCT NULLIF(a.narrowing, '''')', ', ') + ', '''') AS narrowings' + ' FROM catalog_actions a LEFT JOIN users u ON u.id = a.member_id WHERE a.created >= ' +
      Since + Hide + ' AND ' + Person + ' GROUP BY a.who ORDER BY MAX(a.created) DESC LIMIT 500'));
    Answer.Add('projects', RowsOf('SELECT a.entry_id AS id, COALESCE(NULLIF(e.title, ''''), e.name) AS title, e.kind, ' + Step('yes') +
      ', ' + Step('skip') + ', ' + Step('press') + ', ' + Step('unpress') + ', COUNT(DISTINCT a.who) AS people, e.interest' +
      ' FROM catalog_actions a JOIN catalog_entries e ON e.id = a.entry_id WHERE a.created >= ' + Since + Hide + ' AND ' + Person +
      ' AND a.action IN (''yes'', ''skip'', ''press'', ''unpress'') GROUP BY a.entry_id, e.title, e.name, e.kind, e.interest' +
      ' ORDER BY SUM(a.action IN (''yes'', ''press'')) DESC, SUM(a.action = ''skip'') DESC LIMIT 500'));
    Answer.Add('narrowings', RowsOf('SELECT a.narrowing, COUNT(*) AS steps, COUNT(DISTINCT a.who) AS people' + Base + ' AND ' + Person +
      ' AND ' + Shown + ' GROUP BY a.narrowing ORDER BY steps DESC'));
    Answer.Add('crawlers', RowsOf('SELECT a.bot AS name, COUNT(*) AS steps, COUNT(DISTINCT a.who) AS addresses, ' +
      'CAST(SUM(a.action = ''start'') AS SIGNED) AS start, CAST(SUM(a.action = ''skip'') AS SIGNED) AS skip, ' +
      'CAST(SUM(a.action NOT IN (''start'', ''skip'')) AS SIGNED) AS other, ' + IsoTime('MAX(a.created)') + ' AS last' + Base + ' AND NOT ' +
      Person + ' GROUP BY a.bot ORDER BY steps DESC LIMIT 200'));
    // the catalog's own tables over the same days: what stays after take-backs
    Hide := '';
    if ARequest.QueryFields.Values['hide'] <> '0' then
      Hide := ' AND who <> ''m' + IntToStr(Me.Id) + ''' AND who <> ''' + OwnWho + '''';
    Answer.Add('kept', RowsOf('SELECT COUNT(*) AS interest, COUNT(DISTINCT who) AS interest_people,' +
      ' CAST(COALESCE(SUM(who LIKE ''m%''), 0) AS SIGNED) AS interest_members, (SELECT COUNT(*) FROM catalog_interest) AS interest_all,' +
      ' (SELECT COUNT(*) FROM catalog_ratings WHERE updated >= ' + Since + ' AND user_id <> ' + IntToStr(Me.Id) + ') AS ratings,' +
      ' (SELECT COUNT(*) FROM catalog_reports WHERE created >= ' + Since + ') AS reports' + ' FROM catalog_interest WHERE created >= ' + Since + Hide));
  except
    Answer.Free;
    raise;
  end;
  SendJSON(AResponse, Answer);
end;

initialization
  RegisterPartAdminScript('catalog', '/static/catalog-admin.js', 'view-catalog');
  RegisterAdminSection('catalog', 'Catalog', 'view-catalog');
  RegisterPermission('view-catalog', 'See catalog administration', 'admin');
  RegisterPermission('edit-catalog', 'Edit catalog classifications', 'admin');
  RegisterPermission('delete-catalog', 'Delete catalog entries', 'admin');
  RegisterPermission('catalog-settings', 'Change the catalog''s settings', 'admin');
  RegisterSettingsKeeper('Catalog', 'catalog-settings');
  RegisterSetting('catalog_picture_mb', 'Catalog: largest picture of an entry, in MB (never more than the largest file under Files)', '2', 'number', 'Catalog');
  RegisterRole('catalog-admin', 'Runs the catalog: its entries and imports', 'view-catalog,edit-catalog,delete-catalog,catalog-import,catalog-settings,view-admin');
  RegisterOldLink('/catalog/');
  RegisterFilePath('/catalog-images/');
  RegisterFilePath('/catalog-badge/');
  RegisterFilePath('/catalog-count');
  RegisterPictureFolder('/catalog-images/', True);
  RegisterSearchPlace('/catalog', 'catalog');
  RegisterVisitorPart('catalog', '/catalog');
  RegisterVisitorPart('catalog', '/catalog-');
  RegisterVisitorPart('static', '/catalog-images');
  RegisterStorageFolder('catalog-images', 'Catalog images', 'catalog-images');
  RegisterStorageTables('catalog', 'Catalog tables', 'catalog_entries,catalog_readmes,catalog_ratings,catalog_totals,catalog_interest,catalog_reports,catalog_actions');
  RegisterAdminRoute('/api/admin/catalog', 'view-catalog');
  RegisterAdminRoute('/api/admin/catalog/activity', 'view-catalog');
  RegisterAdminRoute('/api/admin/catalog/save', 'edit-catalog');
  RegisterAdminRoute('/api/admin/catalog/add', 'edit-catalog');
  RegisterAdminRoute('/api/admin/catalog/picture', 'edit-catalog');
  // the transport lets an admin address take what /api/upload takes, and no more
  RegisterBodyLimit('/api/admin/catalog/picture', 32 * MB);
  RegisterAdminRoute('/api/admin/catalog/delete', 'delete-catalog');
  RegisterRequestLimit('catadmin', 'Catalog administration', 120, 120, 1);
  LimitRoute('catadmin', '/api/admin/catalog', 'GET');
  LimitRoute('catadmin', '/api/admin/catalog/activity', 'GET');
  LimitRoute('catadmin', '/api/admin/catalog/*', 'POST');
  HTTPRouter.RegisterRoute('/api/admin/catalog', rmGet, @ShowCatalogAdmin);
  HTTPRouter.RegisterRoute('/api/admin/catalog/activity', rmGet, @ShowCatalogActivity);
  HTTPRouter.RegisterRoute('/api/admin/catalog/save', rmPost, @SaveCatalogEntry);
  HTTPRouter.RegisterRoute('/api/admin/catalog/add', rmPost, @AddCatalogEntry);
  HTTPRouter.RegisterRoute('/api/admin/catalog/picture', rmPost, @SaveCatalogPicture);
  HTTPRouter.RegisterRoute('/api/admin/catalog/delete', rmPost, @DeleteCatalogEntry);
end.
