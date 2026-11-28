# Writing a module

Exedra's chat, wiki, forum and catalog are modules: units that tell the
core what they have. A module of your own is made the same way, and the
core is never changed to add one.

[example-module/notes.pas](example-module/notes.pas) is a whole module in
one file, about 160 lines: short notes that members leave for each other.
This page walks through it. Read [CODE-MAP.md](CODE-MAP.md) first for how
a request is answered.

## Adding it to the program

Two changes, both outside the module:

1. Put the module's folder on the unit path: in `server/exedra.lpi`, add
   it to `OtherUnitFiles` (both places), for example `src/notes;`.
2. Name its unit in `server/exedra.lpr`, on the `uses` line before
   `SiteServer`:

   ```pascal
   Forum,
   Catalog,
   Notes,
   SiteServer;
   ```

Build as usual. Leave the unit out again and the program builds without
it: nothing else refers to it.

## What a module tells the core

All of it happens in the unit's `initialization` section, at its foot.
Nothing here runs a query: the database is not open yet.

### The switch

```pascal
RegisterPart('notes', 'Notes: short notes members leave for each other', False);
RegisterPartPaths('notes', ['/notes']);
RegisterPartLink('notes', @NotesLink);
RegisterPartHome('notes', '/notes');
```

`RegisterPart` gives the module a name, the words shown beside its switch
under **Community modules** on the admin page, and whether it is on from
the start. New modules start off. While it is off, every address under
the paths you named answers 404, its link is gone, and its tables are
left alone.

`RegisterPartLink` gives the link shown with the site's links, and
`RegisterPartHome` says where a site with only this module on should
open.

### A table

```pascal
RegisterTable('CREATE TABLE IF NOT EXISTS notes (id INT AUTO_INCREMENT PRIMARY KEY, ...');
```

Write it in MariaDB's words. The core puts it into the words of the
database server in use (MariaDB, MySQL, PostgreSQL, SQLite), so a module
works on all four. To change a table later, leave the `CREATE` as it is
and add `RegisterUpgrade('a-name-for-it', 'ALTER TABLE ...')`: each
upgrade runs once on every site.

### Permissions and roles

```pascal
RegisterPermission('notes-write', 'Leave notes', 'member');
RegisterPermission('notes-manage', 'Remove anyone''s notes', 'moderator,admin');
RegisterRole('notes-moderator', 'Keeps the notes tidy', 'notes-manage');
```

A permission is one thing someone may do. Its third argument is the roles
that hold it on a new site; an admin can change that afterward on the
Permissions tab. `member` is everyone signed in, `guest` everyone else.

A role of the module's own lets a site owner put someone in charge of
this module and nothing else. Start every name with the module's name.

In a handler, `Can(Me, 'notes-write')` asks whether this person holds the
permission. Admins always do.

### A setting

```pascal
RegisterSetting('notes_shown', 'How many notes the page shows', '50', 'number', 'Notes');
```

Name, words, starting value, kind (`text`, `longtext` for a line too long
for a small box such as a list, `number`, `yesno`, `choice:a|b`, `secret`)
and the heading it goes under on the admin page.
Read it with `Setting('notes_shown', '50')` or `SettingInt`.

To let the module's own admin role change its settings without being the
site's admin, name the permission that keeps them:
`RegisterSettingsKeeper('Notes', 'notes-settings')`.

### Addresses

```pascal
HTTPRouter.RegisterRoute('/notes', rmGet, @ShowNotes);
HTTPRouter.RegisterRoute('/notes', rmPost, @AddNote);
```

Each address goes to one procedure. Keep them at the foot of the unit,
so the list of what the module answers is in one place.

## Answering a request

```pascal
procedure ShowNotes(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  ...
  SendPage(AResponse, PartPage(ARequest, Me, Say('Notes'), Html, Side));
end;
```

- `CheckConnection` first, in every handler: it makes sure this request
  has its database connection.
- `CurrentMember` says who is asking. `Me.Id` is 0 for a visitor.
- `Query(sql, [values])` reads rows, `Exec(sql, [values])` changes them,
  `IntValue` and `Value` read one value. **Values go in as `:names`**,
  in the order the names first appear; never paste them into the SQL.
- `Say('...')` gives a word in the reader's language (English when there
  is no translation).
- **Everything a person typed goes through `E(...)`** before it is put in
  a page. That is what keeps a note saying `<script>` from running.

### The page

`PartPage` puts your HTML in the frame every module can share: the left
column with the site's links and the account at its foot, and your
content beside it. You write no template.

```pascal
Side := SideGroup(Say('Notes')) + SideLink('/notes', Say('All notes'));
SendPage(AResponse, PartPage(ARequest, Me, Say('Notes'), Html, Side));
```

`Side` is the module's own links in the left column. Three more
arguments, all optional, name a stylesheet and a script of the module's
under `site/static` and classes to style by:

```pascal
PartPage(ARequest, Me, Title, Html, Side, 'notes.css', 'notes.js', 'notes-body', 'notes-main')
```

A module's script can be plain JavaScript in `site/static`. Exedra's own
scripts are written in Pascal and compiled with pas2js (`src/pages`,
see CODE-MAP.md), and a module's may be too: a unit there, named in
`scripts.list`, is built with the rest. Either way it reaches the
site's names through `window` (`t`, `Site`, `Side` and the rest) the
same way.

A module that wants a page of a different shape brings its own template
in `site/templates` and fills it with `FillTemplate('name', [...])`, as
the forum and the wiki do.

### Changing something

```pascal
procedure AddNote(ARequest: TRequest; AResponse: TResponse);
begin
  CheckConnection;
  if FromAnotherSite(ARequest) then ... refuse
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  if not Can(Me, 'notes-write') then ... refuse
  ...
  Exec('INSERT INTO notes (user_id, body) VALUES (:u, :b)', [Me.Id, Body]);
  SeeOther(AResponse, '/notes');
end;
```

Three checks, in this order, on anything that changes the site:

1. `FromAnotherSite`: refuse a form that another site's page sent in the
   member's name.
2. `NeedMember`: refuses a visitor, a banned member and one who has not
   confirmed their email, and answers them itself.
3. `Can`: the permission for this action.

For something only staff do, `NeedPermission(ARequest, AResponse,
'notes-manage', Me)` does all three in one call.

Answer a form with `SeeOther` to the page the reader should see next, an
API call with `SendJSON`, a refusal with `SendText(AResponse, 403,
'words')`.

### Being found by the site's search

```pascal
RegisterSearch('notes', 'Notes', 50, @FindNotes);
```

Every page carries one search box. It looks in the module whose page the
reader is on, or in another, or in all of them; `/search` shows what was
found, a group for each module, and `/api/site-search` gives the same as
JSON. A module joins by registering one function: the module's name (the
one given to `RegisterPart`), its name for the reader, a number that
places its group among the others (the chat is 10, the wiki 20, the forum
30, the catalog 40), and the function.

```pascal
function FindNotes(ARequest: TRequest; const Me: TMember; const Words: string;
  Offset, Limit: integer; out More: boolean): TSearchHits;
```

It answers the hits for `Words`, best first, `Limit` at most after
leaving out the first `Offset`, and sets `More` when there are others
after these (ask for one more row than `Limit` to know). Each hit is added
with `AddSearchHit(Result, Title, Address, Excerpt, Time, Author, Kind)`: plain text
all of it, never HTML. The search page escapes it and marks the words.
`Excerpt`, `Time` (ISO, UTC) and `Author` may be `''`; `Kind` is one word
of your own for what was found (`note`).

**The function decides what this reader may find.** The search page
shows whatever it gives back, to whoever asked. So check here exactly
what the module's own pages check: give back only what `Me` may open
(`Me.Id` is 0 for a visitor). Nothing else in the site looks at a
module's hits before they are shown.

A site can answer its search from an index it keeps itself (the setting
`search_engine`). A module that has not joined that index is asked
through this function under every setting.

Two more arguments are optional. A permission
(`RegisterSearch(..., @FindNotes, 'notes-read')`) keeps the module out of
the box and the results for a reader who does not hold it. An address
(`'/notes?q='`) names a search page of the module's own with more
choices; the words are added to it and the results link there.

## More, when the module needs it

| For | Call | Where to see it used |
|---|---|---|
| A tab on the admin page | `RegisterAdminSection('notes', 'Notes', 'notes-manage')` for its place in the list, and `RegisterPartAdminScript('notes', '/static/notes-admin.js', 'notes-manage')` for the script that draws it | `catalog/catalogadmin.pas`, `site/static/catalog-admin.js` |
| An address under `/api/admin/` | `RegisterAdminRoute('/api/admin/notes', 'notes-manage')`: the guard then refuses everyone else before the handler runs | `catalog/catalogadmin.pas` |
| Work every so often | `RegisterChore(@Tidy, 60)`: every 60 minutes | `core/sitefiles.pas` |
| Work at start, once the database is open | `RegisterStartup(@Fill)` | `core/siteroles.pas` |
| A member's account being closed | `RegisterCloseMemberHook(@Forget)`, a `procedure Forget(UserId: integer)`: wipe what the module keeps about the member for the member alone (settings, what they follow, addresses to notify). What they contributed stays, and shows their name still; in a query, `users.closed = 1` marks a former member | `forum/forum.pas`, `chat/chatpush.pas` |
| Something its pages need to know about the member signed in | `RegisterMeHook(@Add)`, a `procedure Add(const Me: TMember; Answer: TJSONObject)`: puts it on what `/api/me` answers | `chat/chatprivate.pas` |
| A yes or no of the member's own, on their profile | `RegisterMemberPref('notes_mail', 'Email me about new notes', True)`: the name, the words beside its checkbox, and what it is until the member chooses; a fourth argument is a function that says whether the line shows now. Read it with `MemberPref(UserId, 'notes_mail')` | `forum/forumfollow.pas` |
| A member being renamed | `RegisterRenameMemberHook(@Follow)`, for a module that keeps something under the member's name instead of their number | `chat/chatrooms.pas` |
| Limits on how often an address may be asked | `RegisterRequestLimit('notes', 'Notes', 60, 20, 10)` then `LimitRoute('notes', '/notes', 'POST')`; the name is ten characters at most | `forum/forum.pas` |
| Files members send | `SiteFiles`, and `RegisterFileGuard` to say who may fetch them | `forum/forumfiles.pas` |
| The module's storage on the Storage tab | `RegisterStorageTables('notes', 'Notes', 'notes')` | `catalog/catalogadmin.pas` |
| Its pages counted on the Visitors tab | `RegisterVisitorPart('notes', '/notes')` | `forum/forumpages.pas` |
| A card on the home page | `RegisterHomePart('notes_home', @NotesCard)`, the card made with `HomeCard` and `HomeRow`, and `{{notes_home}}` put where it should show in `site/templates/home.html`. It is the same for every reader and kept for half a minute, so show only what a visitor may see | `forum/forumpages.pas` |
| A bench for each of your pages, on a site with the chat | `RegisterPageKind('notes', @NotePage)` in a small unit of its own that uses `ChatBenches` (as `wiki/wikichat.pas` does, so the module still builds without the chat), and `LiveStrip(ARequest, 'notes', Key)` for the page's `{{live}}`; that needs a template of the module's own, since `PartPage` fills `{{live}}` with the corner chat for no page in particular | `wiki/wikichat.pas` |
| Reactions on what members write | `SiteReactions`: `RegisterTable(ReactionTable('note_reactions', 'note_id'))` for the table, `IsReaction(R)` before one is put on (taking one's own back needs no check), `AttachReactions` for the reactions on a page of things and `WhoReacted` for the names behind one. On the page, `reactions.js` draws them (`Reactions.chips`, `Reactions.choose`) from the lists `/api/me` gives as `reactions` | `forum/forumreactions.pas`, `site/static/forum.js` |
| A check of your settings before they are saved | `RegisterSettingsCheck(@Check)`, a `function Check(Sent: TStrings): string` that answers why not, or `''` | `core/sitereactions.pas` |
| Letting other units add to your pages | a `Register...` procedure of your own that keeps a list of callbacks | the top of `catalog/catalog.pas` |

In a script on the admin page, the site's shell is `window.Site`: its
helpers (`Site.el`, `Site.get`, `Site.post`, `Site.listView`...) and
`Site.extras.adminTabs`, which the script pushes its tab into. Older
scripts call the same object `window.Chat`.

## Checking a module

The example is checked by building the server with it added, starting it
on a new database and using it as a visitor, a member and an admin: off
by default, turned on, a note left and shown escaped, a forged form
refused, removal only by who may, the module's own role doing its one
job, and off again. A script that does the same for your module, with
`curl`, is the quickest proof that its switch, permissions and pages hold
together.

## Habits worth keeping

- One unit, one job, and a comment at its top that says what it holds.
- Start every permission, role, setting, table and address with the
  module's name.
- Addresses and registrations at the foot of the unit.
- No query in `initialization`.
- A module uses the core's units and its own, never another module's,
  unless it is built on that module and cannot run without it.
