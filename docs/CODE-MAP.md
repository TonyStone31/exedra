# Finding your way around the code

This is a map of the server's source for someone who wants to read it,
fix something or add to it. The server is in `server/`; the desktop
client in `desktop/` has its own [README](../desktop/README.md).

Every unit starts with a comment that says what it holds. This page says
which unit to open. To add a module of your own, see [MODULES.md](MODULES.md).

## The layout

```
server/
  exedra.lpr          the program: one line of units, nothing else
  src/core/           what every site has: members, the admin page, the guard
  src/chat/           the chat module
  src/wiki/           the wiki module
  src/forum/          the forum module
  src/catalog/        the catalog module
  site/templates/     the HTML pages, with {{places}} the server fills
  site/static/        the scripts and stylesheets a browser loads
  site/lang/          the site's words in other languages
```

`exedra.lpr` names `SiteServer` (the core) and one unit for each module:
`ChatPart`, `Wiki`, `Forum`, `Catalog` (and `WikiChat`, what the wiki and
the chat share). Leave a module's unit out and the program is
built without it. The core uses no module's units, and a module uses the
core's and its own.

## How a request is answered

1. **It arrives.** `core/siteserver.pas` starts the built-in web server
   (`core/sitehttpguard.pas`) or, built with `-dCGI`, answers one request
   and ends (`core/sitecgiguard.pas`).
2. **The guard looks at it** before any page does: `core/siteguard.pas`,
   with the rules in `core/siteguardrules.pas`. A blocked address, a path
   only a probing machine asks for, too many requests, or an admin
   address asked for by someone who may not: refused here.
3. **A module that is off answers nothing.** `core/siteparts.pas` knows
   which addresses belong to which module.
4. **The router finds the handler.** Each unit registers its own
   addresses with `HTTPRouter.RegisterRoute`, **at the foot of the unit**,
   in its `initialization` section. To find what answers `/api/something`,
   search the source for that address in quotes.
5. **The handler asks who is there**, does its work and answers.

### Who is asking

| Call | What it gives |
|---|---|
| `CurrentMember(Request)` | the member signed in, or an empty one for a visitor |
| `NeedMember(...)` | the same, and refuses a visitor or an unverified member |
| `NeedPermission(..., 'name', Me)` | refuses unless the member holds that permission; also refuses a form sent from another site |
| `Can(Me, 'name')` | whether the member holds a permission, to decide what to show |

The first two are in `core/siteusers.pas`, `NeedPermission` in
`core/siteadmin.pas`, `Can` in `core/siteroles.pas`.

### Answering

| Call | What it sends |
|---|---|
| `SendJSON(Response, Data)` | JSON, and frees `Data` |
| `SendText(Response, Code, 'words')` | a plain answer, usually a refusal |
| `SendPage(Response, FillTemplate('name', [...]))` | a page from `site/templates/name.html` |

### One request, followed through

A member presses **Post reply** in the forum:

1. `site/static/forum.js` sends the form to `POST /api/forum/reply`.
2. That address is registered at the foot of `forum/forum.pas`
   (`AddRoute('reply', rmPost)`); every forum address goes to `Handle`.
3. `Handle` finds the member, refuses a form from another site, starts a
   transaction and calls the function named for the address: `Reply`.
4. `Reply` checks the member may post and the topic is open, inserts the
   post, gives it its files (`ForumFiles.KeepPostFiles`) and calls
   `NotePost`, which adds the post to the stored counts of its topic,
   its board and its author.
5. `Handle` commits and sends back `{topic_id, post_id, page}`. Had
   `Reply` called `Refuse(403, '...')` instead, `Handle` would have rolled
   the transaction back and sent those words.
6. `forum.js` opens the page the new post is on.

The chat and the wiki each have their own habit here. A chat handler
answers a refusal itself and exits. A wiki operation returns a problem as
text and the page shows it. The forum raises and `Handle` answers. Each
unit's header says which it uses.

## Where things are defined

| Looking for | Search for | Notes |
|---|---|---|
| What answers an address | the address in quotes | registered at the foot of the unit that answers it |
| A setting | `RegisterSetting('name'` | that is where the admin page learns of it. It is read with `Setting('name', default)`: a value saved on the admin page wins, then `[site]` in the config file, then the default given |
| A table | `RegisterTable(` and `RegisterUpgrade(` | a table is made by the first; columns added later are in upgrades, so read both. They run in `core/sitedb.pas` at start |
| A permission | `RegisterPermission('name'` | with the roles that hold it on a new site |
| A role a module brings | `RegisterRole('name'` | `forum-moderator`, `wiki-admin`... |
| What a module adds to the site's search | `RegisterSearch(` | the function named there finds the module's hits and decides who may see them |
| A word shown to people | `Say('...')` in Pascal, `t('...')` in scripts | translated from `site/lang/` |
| Who may fetch a file | `RegisterFileGuard(` | a module that guards its files; without one the file's address alone opens it |
| Something done every so often | `RegisterChore(` | with how many minutes apart |

SQL is written once, in MariaDB's words. `core/sitesql.pas` holds the few
forms that differ between servers (`SqlInsertIgnore`, `SqlOnConflict`...),
and `core/sitesqlpg.pas` and `core/sitesqllite.pas` put a statement into
PostgreSQL's and SQLite's words as it is run. Values are given in the
order their `:names` first appear in the statement.

## The units

### core

| Unit | What it holds |
|---|---|
| `siteserver` | starting the server, the command line (`--admin`, `--password-link`, `--backup` with `--pictures` and `--logs`, `--restore`, `--version`) |
| `sitedb` | the database connection, the settings, making tables and running upgrades |
| `sitesql`, `sitesqlread`, `sitesqlpg`, `sitesqllite` | the SQL that differs between database servers |
| `siteusers` | members: signing up and in, sessions, passwords, profiles, tokens for bots |
| `sitelogins` | signing in with GitHub, GitLab, Codeberg, Google or Microsoft |
| `siteroles` | roles and permissions |
| `siteadmin` | the admin page's data: settings, members, roles |
| `siteparts` | the modules a site owner turns on or off |
| `sitesearch` | the search box on every page, `/search` and `/api/site-search`: each module registers its own search (`RegisterSearch`) |
| `webpages` | the pages every site has (home, sign-in, profile, admin shell), templates, dates |
| `sitebase` | a site under a path of its domain (`https://example.com/community`) |
| `sitewords` | the site's words in other languages |
| `sitemarkup` | members' text to HTML: Markdown, mentions, code blocks |
| `sitefiles` | files members send, and fetching them |
| `sitereactions` | the reactions every module offers: the two lists an admin keeps, the table a module stores them in, and reading it (the reactions on a page of things, who gave one) |
| `sitescan` | virus scanning of what members send |
| `sitefetch` | fetching an address a stranger gave, safely |
| `sitemail`, `sitenotices` | mail from the site; notices to a member |
| `sitebell`, `sitelive` | telling open pages something changed, over a WebSocket at `/api/live` (the same address asked with a plain GET is the corner chat's, in `chat/chatbenches.pas`) |
| `siteguard`, `siteguardrules`, `sitehttpguard`, `sitecgiguard` | keeping probing machines out, limits, blocks |
| `sitecrawlers`, `siteabuse` | telling search engines' crawlers from pretenders; reporting abuse |
| `sitesecurity`, `sitetls` | the security headers on every answer; the program's own TLS (TlsLib4Pascal), with certificates checked on every connection it makes |
| `sitestats`, `sitevisitors` | visitor counts, the access log, storage; the Visitors reports |
| `sitebackup` | backups made, downloaded and restored from the admin page |
| `sitebugs` | "Report a problem" |
| `sitestatic` | files sent as they are from a folder |
| `sitepoll` | waiting on sockets |
| `siteversion` | the release number |
| `syntaxtable`, `syntaxlangs`, `syntaxlfm`, `syntaxmarkdown`, `syntaxrst`, `syntaxbarye` | coloring code blocks, on FPC's fcl-syntax |

### chat

| Unit | What it holds |
|---|---|
| `chatpart` | the chat as a module: its pages, its admin entries, where a site opens |
| `chatrooms` | rooms (channels): who is in them, topics, following |
| `chatmessages` | messages: posting, editing, reactions, pins, search, what a page asks for as it stays open |
| `chatprivate` | private conversations between two members, encrypted in the browser |
| `chatcommands` | the `/commands` typed in a message box |
| `chatirc` | an IRC server on the same rooms and members |
| `chatpush`, `chatmissed` | notifications to a closed page; mail about what a member missed |
| `chatpreviews` | a line about the first link in a message |
| `chatbenches` | benches: a channel for a page, the corner chat on this site's pages and on other sites' |
| `chatoversight` | who talks in private, for the people running the site |

### wiki

| Unit | What it holds |
|---|---|
| `wiki` | pages: reading, editing, history, moving, deleting, search, languages |
| `wikirender` | wiki text to HTML |
| `wikifiles` | pictures and other files |
| `wikiemoji`, `wikiemojisite` | the wiki's own emoji set |
| `wikichat` | where the wiki and the chat meet, for a site with both: `/wiki`, `#channel` links, a bench for each page |

### forum

| Unit | What it holds |
|---|---|
| `forum` | the tables, every `/api/forum/...` address, reading and posting, moderation, unread posts |
| `forumpages` | the pages a browser reads |
| `forumrules` | decisions that need no database: who may change a post, addresses, paging |
| `forumrequest` | reading a request's fields, and refusing it |
| `forumfiles` | files in posts |
| `forumboards` | arranging categories and boards |
| `forumstaff` | reports, and stopping a member posting |
| `forumreactions` | reactions on posts |
| `forumfollow` | following a topic: who follows, the notice and the mail about a reply |
| `forumswitch` | whether the forum is turned on |

### catalog

| Unit | What it holds |
|---|---|
| `catalog` | entries: the list with its search and filters, an entry's page, ratings, Interesting, and the hooks a site's own unit adds fields and page parts through |
| `catalogimport` | entries brought in as JSON: a row checked and stored, READMEs and logos |
| `catalogreports` | members telling the admins an entry does not belong |
| `catalogadmin` | the catalog on the admin page: entries added and changed by hand, an entry's picture |

## In the browser

There is no build step: a page loads the files below as they are.

| File | What it does |
|---|---|
| `base.js` | first on every page: lets the site sit under a path of its domain |
| `theme.js` | light or dark before the page draws |
| `words.js` | `t('...')`: the site's words in the reader's language |
| `keys.js` | accounts and everything encrypted |
| `side.js` | the left column every module shares, and small helpers (`Side.el`, `Side.icon`) |
| `app.js` | the site's page: account, profiles, the admin page's frame. It exports its helpers as `window.Chat`, a name kept from when the chat was all there was; the admin scripts use it with the chat off too |
| `chat.js` | the chat, which adds itself to `app.js` |
| `reactions.js` | reactions as the chat and the forum both show them: the chips, who gave one, the emoji to pick from |
| `emoji-names.js` | emoji typed by name (`:thu` offers 👍), for the chat's message boxes and the editor alike: it finds the name being typed and the emoji that fit, from the list in `emoji-names.txt` |
| `live.js`, `embed.js` | the corner chat on a page (it loads its own `live.css`); the one line that puts it on another site's pages (with `live-embed.css` for its colors there) |
| `admin.js` | the admin page, loaded when it is opened |
| `editor.js` | the editor the wiki and the forum share |
| `wiki.js`, `wiki-edit.js`, `wiki-files.js`, `wiki-admin.js` | the wiki's pages, its side of the editor, its files, its Emoji tab |
| `forum.js`, `forum-admin.js` | the forum's forms; its boards tab on the admin page |
| `catalog.js`, `interest.js` | the catalog's list without reloading; the Interesting button |
| `home.js` | the home and sign-in pages |
| `sw.js` | the service worker: installing the site as an app, notifications |

Stylesheets: `site.css` is shared (colors, the left column, the chat, the
admin page, code blocks), `wiki.css`, `forum.css`, `catalog.css` and
`editor.css` are each part's own.

## Details shared by several units

### Visitor reports and logs

`sitestats` writes a daily tab-separated access log: UTC time, address,
method, path, referer, browser, signed-in name (empty for a visitor),
status code and elapsed milliseconds. Secrets in paths are masked.
`sitevisitors` seeks into these ordered logs for a time window and caches
reports for a minute. A person is one address and browser; signed-in
members count as people. Named bots, robots.txt requests and apparent
browsers that fetch only bare pages count as bots. Background polls are
counted separately from requests and pace. Reports include pages,
referrers, searches, members, timelines and concerns about each address.
Published crawlers and registered bots with `AnyPace` are exempt from
pace concerns; allowed and private addresses are exempt from assessment.

`sitecrawlers` caches published ranges in `crawler-ranges.json`. Extra
sources go in `crawler-sources.txt`, one tab-separated line per source:
company, crawler, JSON URL, lowercase browser-string marker. Lines
starting with `#` are comments. Each source uses `prefixes` containing
`ipv4Prefix` or `ipv6Prefix` CIDR values. An address in a company's ranges
identifies its crawler; a browser name alone does not verify it. Samples
are also checked against DNS for the visitor reports.

### Mail and IRC

`sitemail` reads `host`, `port` (465), `user`, `password`, `from` and
`name` from `[mail]`. With `file` in place of `host`, outgoing mail is
appended there for local inspection. With neither, sending fails.

`chatirc` reads `[irc] port` for plain connections (or a TLS proxy),
`tls_port` with PEM `cert` and `key` for direct TLS, and `name` for the
server name. Channels map to rooms: `#lobby` is `/p/lobby`. Clients poll
for messages each second; thread replies and long code blocks carry
links. Commands use the same checks as web messages.

### Forum delivery

`forumfollow` automatically follows topics a member starts or replies to
when their preference allows it. Explicitly stopping a follow persists
until they press Follow again. Replies queue work in the posting
transaction; delivery starts after commit, with chores retrying later.
CGI uses chores alone. Delivery excludes the author's own posts, hidden
posts or topics, unreadable boards, ignored authors and banned followers.
A forum posting restriction still allows reading and notifications.
Each topic gets its newest notice and one mail until the follower reads
it. Mail links use a random key specific to that follow, independent of
the account password.

### Browser helpers

`Editor.attach(textarea, options)` returns an editor. Its preview callback
`preview(text, signal)` returns HTML from the module's own renderer;
`afterPreview(view)` runs afterward. `heads` selects preview headings and
`viewClass` supplies preview classes. `storeKey` and `mode` select and
remember a view; `compact` makes a reply box and `language` names the
language of new code blocks (empty uses the site setting). `hint`,
`emptyWords`, `cheats` (`[mark, explanation]` rows) and `helpLink`
(`{href, words}`) provide help. `sendRow` holds form controls kept visible
in full screen; `linkTools(editor)` adds tools after Link.

`emoji()` asynchronously returns `{emoji, name, group, src, keywords}`
items; load `emoji-names.js` first for typed suggestions. `pictures`
supplies `accept`, `types` and `send(file, name)`, which returns
`{put, words}` or throws. Optional `refuses(file)` returns an error for
other file types; `label` names their link. The returned editor exposes
`box`, `form`, `shell`, `view`, editing helpers `replace`, `wrap`, `lines`,
`prefix`, popup helpers `pop`, `closePop`, and `say`, `tool`, `gap`,
`upload`, `choose`, `el`, `svg`. Call `notSaved()` after a refused save.

`Site.listView(options)` in `admin.js` makes a searchable, sortable list
with keyboard selection and a detail panel. `columns` contains
`{key, title, value(row), cell(row), num, wide, nosort, cls}`: `value`
supplies sorting, searching and export; `cell` supplies text or a node.
Numeric columns sort highest first; `wide` columns hide on phones.
Give `rows`, or `remote(state)` returning `{rows, total}` for state
`{q, filters, sort, page}`. Missing rows show loading until `set()`;
`failed(words)` displays a failure.

`search` sets placeholder words (false hides it), `enter(q)` handles Enter,
and `filters` holds `{key, title, all, options, test(row, value), value}`.
Options are `[value, caption]` pairs or a function of the rows. `sort`
names a column, prefixed by `-` to reverse it; `id` remembers sorting and
`key(row)` identifies a row. `detail(row, holder, view)` fills the detail
panel; `rowClass(row)` supplies row classes. `noun(count)` supplies the
count text, `empty` the no-rows text, and `csv` an export filename.

## Names kept on purpose

A few names from before the project was called Exedra stay because
changing them would lock people out:

- `beginend:` in the password salt and `beginend private message` in the
  key for private conversations (`core/siteusers.pas`,
  `site/static/keys.js`, `desktop/deskkeys.pas`). A different text gives
  different keys.
- `beginend`, the name of the browser's own store for a member's keys
  (`site/static/keys.js`). Another name would leave those keys behind.
- `bt_time_add`, a function the SQLite side registers for itself
  (`core/sitesqllite.pas`).
