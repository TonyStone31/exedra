unit Notes;

{ Example module: short notes members leave for each other. Add this folder
  to the unit path and Notes to the program's uses clause to try it.
  docs/MODULES.md explains its registrations; the core needs no changes. }

{$mode objfpc}{$H+}

interface

implementation

uses
  Classes, SysUtils, httpdefs, httproute,
  SiteDb, SiteSql, SiteUsers, SiteRoles, SiteAdmin, SiteParts, SiteSearch, SiteWords, WebPages;

{ The module's link among the site's links, at the top of the left column. }
function NotesLink: string;
begin
  Result := '<a href="/notes">' + E(Say('Notes')) + '</a>';
end;

{ GET /notes  the newest notes, and the box to leave one. }
procedure ShowNotes(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Html, Side: string;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  Html := '<h1>' + E(Say('Notes')) + '</h1>';
  if Can(Me, 'notes-write') then
    Html := Html + '<form method="post" action="/notes"><input name="body" maxlength="500" required> <button>' + E(Say('Leave a note')) + '</button></form>';
  with Query('SELECT n.id, n.body, COALESCE(u.name, '''') FROM notes n LEFT JOIN users u ON u.id = n.user_id ORDER BY n.id DESC LIMIT :n', [SettingInt('notes_shown', 50)]) do
  try
    while not EOF do
    begin
      // whatever a member typed goes through E, which makes it safe to show
      Html := Html + '<p><b>' + E(Fields[2].AsString) + '</b>: ' + E(Fields[1].AsString);
      if Can(Me, 'notes-manage') then
        Html := Html + ' <form method="post" action="/notes/delete" style="display:inline"><input type="hidden" name="id" value="' +
          IntToStr(Fields[0].AsInteger) + '"><button>' + E(Say('Remove')) + '</button></form>';
      Html := Html + '</p>';
      Next;
    end;
  finally
    Free;
  end;
  Side := SideGroup(Say('Notes')) + SideLink('/notes', Say('All notes'));
  SendPage(AResponse, PartPage(ARequest, Me, Say('Notes'), Html, Side));
end;

{ POST /notes  body: a member leaves a note. }
procedure AddNote(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Body: string;
begin
  CheckConnection;
  // a form that another site's page sends in the member's name is refused
  if FromAnotherSite(ARequest) then
  begin
    SendText(AResponse, 403, Say('Send this form from this site.'));
    Exit;
  end;
  // NeedMember answers a visitor, a banned or an unconfirmed member itself
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  if not Can(Me, 'notes-write') then
  begin
    SendText(AResponse, 403, Say('You cannot leave notes.'));
    Exit;
  end;
  Body := Trim(ARequest.ContentFields.Values['body']);
  if (Body = '') or (Length(Body) > 500) then
  begin
    SendText(AResponse, 400, Say('A note is 1 to 500 characters.'));
    Exit;
  end;
  // values go in as :names, never pasted into the SQL
  Exec('INSERT INTO notes (user_id, body) VALUES (:u, :b)', [Me.Id, Body]);
  SeeOther(AResponse, '/notes');
end;

{ POST /notes/delete  id: whoever holds notes-manage takes a note away. }
procedure DeleteNote(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
begin
  // NeedPermission answers the refusal itself, and refuses a form from another site
  if not NeedPermission(ARequest, AResponse, 'notes-manage', Me) then
    Exit;
  Exec('DELETE FROM notes WHERE id = :i', [StrToIntDef(ARequest.ContentFields.Values['id'], 0)]);
  SeeOther(AResponse, '/notes');
end;

{ The notes in the site's search.  Every note may be read by anyone, so
  every one that holds the words is found; a module with private things
  gives back only those Me may open. }
function FindNotes(ARequest: TRequest; const Me: TMember; const Words: string; Offset, Limit: integer; out More: boolean): TSearchHits;
begin
  Result := nil;
  // one more than asked for tells whether there are more
  with Query('SELECT n.body, COALESCE(u.name, ''''), ' + IsoTime('n.created') + ' FROM notes n LEFT JOIN users u ON u.id = n.user_id' +
      ' WHERE n.body LIKE :w ORDER BY n.id DESC LIMIT :n OFFSET :o', ['%' + LikePrefix(Words), Limit + 1, Offset]) do
  try
    while not EOF and (Length(Result) < Limit) do
    begin
      // plain text: the search page escapes it and marks the words
      AddSearchHit(Result, Say('Note'), '/notes', Fields[0].AsString, Fields[2].AsString, Fields[1].AsString, 'note');
      Next;
    end;
    More := not EOF;
  finally
    Free;
  end;
end;

initialization
  // the switch: off on a new site, turned on under Community modules
  RegisterPart('notes', 'Notes: short notes members leave for each other', False);
  // the addresses that are this module's: they answer 404 while it is off
  RegisterPartPaths('notes', ['/notes']);
  RegisterPartLink('notes', @NotesLink);
  // where a site with only this module on opens
  RegisterPartHome('notes', '/notes');

  // written in MariaDB's words; the core puts it in the words of the database server in use
  RegisterTable('CREATE TABLE IF NOT EXISTS notes (id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL,' +
    ' body VARCHAR(500) NOT NULL, created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP) CHARACTER SET utf8mb4');

  // a permission, its words for the admin page, and the roles that hold it on a new site
  RegisterPermission('notes-write', 'Leave notes', 'member');
  RegisterPermission('notes-manage', 'Remove anyone''s notes', 'moderator,admin');
  // a role of the module's own, with the permissions it holds
  RegisterRole('notes-moderator', 'Keeps the notes tidy', 'notes-manage');

  // a setting: its name, its words, where it starts, its kind, and its heading on the admin page
  RegisterSetting('notes_shown', 'How many notes the page shows', '50', 'number', 'Notes');

  // the site's search asks FindNotes while the module is on
  RegisterSearch('notes', 'Notes', 50, @FindNotes);

  HTTPRouter.RegisterRoute('/notes', rmGet, @ShowNotes);
  HTTPRouter.RegisterRoute('/notes', rmPost, @AddNote);
  HTTPRouter.RegisterRoute('/notes/delete', rmPost, @DeleteNote);
end.
