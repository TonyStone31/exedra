unit ForumBoards;

{ Category and board administration for forum-boards holders. Boards have
  ordered positions, optional parents and a read permission. Forum.Handle
  checks access and serializes changes under a lock and transaction. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, httpdefs;

{ GET /api/forum/admin/categories }
function Categories: TJSONArray;
{ POST /api/forum/admin/category  id (0 for a new one), name, position }
function SaveCategory(R: TRequest): TJSONObject;
{ POST /api/forum/admin/category/remove  id: only an empty category goes }
function RemoveCategory(R: TRequest): TJSONObject;
{ POST /api/forum/admin/board  id (0 for a new one), name, slug, description,
  category_id, parent_id, position, read_permission }
function SaveBoard(R: TRequest): TJSONObject;
{ POST /api/forum/admin/remove  id: only an empty board goes }
function RemoveBoard(R: TRequest): TJSONObject;
{ POST /api/forum/admin/order  the boards' new places }
function OrderBoards(R: TRequest): TJSONObject;

implementation

uses
  Variants, sqldb, SiteDb, SiteRoles, SiteSql, ForumRules, ForumRequest, Forum;

procedure CheckPermissionName(const Name: string);
var
  C: char;
  List: TJSONArray;
  I: integer;
begin
  if (Name = '') or (Length(Name) > 40) then
    Refuse(400, 'Choose a read permission.');
  for C in Name do
    if not (C in ['a'..'z', '0'..'9', '-']) then
      Refuse(400, 'Choose a read permission.');
  List := PermissionsJSON;
  try
    for I := 0 to List.Count - 1 do
      if TJSONObject(List.Items[I]).Get('name', '') = Name then
        Exit;
  finally
    List.Free;
  end;
  Refuse(400, 'Choose a registered read permission.');
end;

function SaveBoard(R: TRequest): TJSONObject;
var
  Id, ParentId, Position, CategoryId: integer;
  Name, Slug, Description, Permission: string;
begin
  Id := OptionalNumber(R, 'id');
  ParentId := OptionalNumber(R, 'parent_id');
  if (Id < 0) or (ParentId < 0) then
    Refuse(400, 'Enter a valid number.');
  CategoryId := OptionalNumber(R, 'category_id');
  if (CategoryId < 0) or ((CategoryId > 0) and (IntValue('SELECT id FROM forum_categories WHERE id = :c', [CategoryId]) = 0)) then Refuse(400, 'Choose a category.');
  Position := OptionalNumber(R, 'position');
  Name := Trim(Field(R, 'name'));
  Description := Field(R, 'description');
  Permission := Field(R, 'read_permission');
  Slug := ForumSlug(Field(R, 'slug'));
  if (Slug = 'search') or (Slug = 't') or (Slug = 'recent') or (Slug = 'unread') or (Slug = 'signature') or (Slug = 'reports') or
    (Slug = 'follow') or (Slug = 'following') or (Slug = 'mail-off') then
    Refuse(400, 'That board slug is reserved.');
  if Slug = '' then
    Refuse(400, 'Enter a board slug using letters or numbers.');
  CheckText(Name, 100, True);
  if Description <> '' then
    CheckText(Description, 2000, False);
  CheckPermissionName(Permission);
  if Id > 0 then
    LockBoard(Id);
  if ParentId > 0 then
  begin
    if ParentId = Id then
      Refuse(400, 'A board cannot be its own parent.');
    with Query('SELECT parent_id FROM forum_boards WHERE id = :b', [ParentId]) do
    try
      if EOF or (Fields[0].AsInteger <> 0) then
        Refuse(400, 'Choose a top-level parent board.');
    finally
      Free;
    end;
    if IntValue('SELECT id FROM forum_boards WHERE parent_id = :b LIMIT 1', [Id]) > 0 then
      Refuse(400, 'A board with sub-boards must stay at the top level.');
  end;
  if IntValue('SELECT id FROM forum_boards WHERE slug = :s AND id <> :b LIMIT 1', [Slug, Id]) > 0 then
    Refuse(409, 'That board slug is already in use.');
  if Id = 0 then
  begin
    Exec('INSERT INTO forum_boards (name, slug, description, position, parent_id, read_permission, category_id)' + ' VALUES (:n, :s, :d, :p, NULLIF(:a, 0), :r, NULLIF(:c, 0))',
      [Name, Slug, Description, Position, ParentId, Permission, CategoryId]);
    Id := IntValue('SELECT LAST_INSERT_ID()', []);
  end
  else
    Exec('UPDATE forum_boards SET name = :n, slug = :s, description = :d, position = :p,' +
      ' parent_id = NULLIF(:a, 0), read_permission = :r, category_id = NULLIF(:c, 0) WHERE id = :b',
      [Name, Slug, Description, Position, ParentId, Permission, CategoryId, Id]);
  Result := TJSONObject.Create(['id', Id]);
end;

function RemoveBoard(R: TRequest): TJSONObject;
var
  Id: integer;
begin
  Id := Number(Field(R, 'id'));
  LockBoard(Id);
  if (IntValue('SELECT id FROM forum_boards WHERE parent_id = :b LIMIT 1', [Id]) > 0) or (IntValue('SELECT id FROM forum_topics WHERE board_id = :b LIMIT 1', [Id]) > 0) then
    Refuse(409, 'Move the topics and sub-boards before removing this board.');
  Exec('DELETE FROM forum_boards WHERE id = :b', [Id]);
  Exec('DELETE FROM forum_board_reads WHERE board_id = :b', [Id]);
  Result := TJSONObject.Create(['ok', True]);
end;

{ Ordering uses the same board update and accepts a position for each board. }
function OrderBoards(R: TRequest): TJSONObject;
var
  Entries: TStringArray;
  Entry: string;
  Id, I, J, Swap: integer;
  LockIds: array of integer;
  Seen: TStringList;
begin
  LockIds := nil;
  Entries := Field(R, 'ids').Split([',']);
  if (Length(Entries) = 0) or (Length(Entries) > 1000) then
    Refuse(400, 'Enter a list of board numbers.');
  Seen := TStringList.Create;
  try
    SetLength(LockIds, Length(Entries));
    for I := 0 to High(Entries) do
    begin
      Entry := Trim(Entries[I]);
      Id := Number(Entry);
      if Seen.IndexOf(IntToStr(Id)) >= 0 then
        Refuse(400, 'List each board once.');
      Seen.Add(IntToStr(Id));
      LockIds[I] := Id;
    end;
    for I := 1 to High(LockIds) do
    begin
      J := I;
      while (J > 0) and (LockIds[J] < LockIds[J - 1]) do
      begin
        Swap := LockIds[J];
        LockIds[J] := LockIds[J - 1];
        LockIds[J - 1] := Swap;
        Dec(J);
      end;
    end;
    for I := 0 to High(LockIds) do
      LockBoard(LockIds[I]);
    for I := 0 to Seen.Count - 1 do
      Exec('UPDATE forum_boards SET position = :p WHERE id = :b', [I, StrToInt(Seen[I])]);
  finally
    Seen.Free;
  end;
  Result := TJSONObject.Create(['ok', True]);
end;

function Categories: TJSONArray;
var
  Q: TSQLQuery;
begin
  Result := TJSONArray.Create;
  try
    Q := Query('SELECT id, name, position FROM forum_categories ORDER BY position, id', []);
    try
      while not Q.EOF do
      begin
        Result.Add(TJSONObject.Create(['id', Q.Fields[0].AsInteger, 'name', Q.Fields[1].AsString, 'position', Q.Fields[2].AsInteger]));
        Q.Next;
      end;
    finally
      Q.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function SaveCategory(R: TRequest): TJSONObject;
var
  CategoryId, CategoryPosition: integer;
  CategoryName: string;
begin
  CategoryId := OptionalNumber(R, 'id');
  CategoryPosition := OptionalNumber(R, 'position');
  CategoryName := Trim(Field(R, 'name'));
  CheckText(CategoryName, 100, True);
  if CategoryId < 0 then Refuse(400, 'Enter a valid number.');
  if CategoryId = 0 then
  begin
    Exec('INSERT INTO forum_categories (name, position) VALUES (:n, :p)', [CategoryName, CategoryPosition]);
    CategoryId := IntValue('SELECT LAST_INSERT_ID()', []);
  end
  else
  begin
    if IntValue('SELECT id FROM forum_categories WHERE id = :c', [CategoryId]) = 0 then Refuse(404, 'Nothing here.');
    Exec('UPDATE forum_categories SET name = :n, position = :p WHERE id = :c', [CategoryName, CategoryPosition, CategoryId]);
  end;
  Result := TJSONObject.Create(['id', CategoryId]);
end;

function RemoveCategory(R: TRequest): TJSONObject;
var
  CategoryId: integer;
begin
  CategoryId := Number(Field(R, 'id'));
  if IntValue('SELECT id FROM forum_categories WHERE id = :c', [CategoryId]) = 0 then Refuse(404, 'Nothing here.');
  if IntValue('SELECT id FROM forum_boards WHERE category_id = :c LIMIT 1', [CategoryId]) > 0 then Refuse(409, 'Move the boards before removing this category.');
  Exec('DELETE FROM forum_categories WHERE id = :c', [CategoryId]);
  Result := TJSONObject.Create(['ok', True]);
end;

end.
