# Roadmap

Where Exedra stands and what comes next. Dates are not promised.

## Done

- The shared core: members, sign-in, roles, the guard, the admin page
  and backups. It builds and runs with no module at all.
- The chat, with private conversations, the IRC side and Web Push.
- The wiki.
- The forum: boards, topics and posts with moderation, search, read
  marks, files in posts, and following a topic with mail about replies.
- The catalog: entries with ratings, Interesting, reports and its own
  tab on the admin page.
- A moderator and an admin role for the chat, the wiki and the forum, and
  an admin role for the catalog.
- Benches: a channel for a page, with the corner chat on this site's
  pages and, by one line of HTML, on the pages of other web sites.
- A guide to writing a module of your own ([docs/MODULES.md](docs/MODULES.md)).
- The switch: each module turned on or off from the config file or the
  admin page.
- MariaDB, MySQL, PostgreSQL and SQLite.
- The source in this repository, and [INSTALL.md](INSTALL.md).
- Releases for Linux on x86_64 and on 64-bit ARM (a Raspberry Pi) and
  for FreeBSD on x86_64 that need no compiler, and `install.sh`, which
  installs the right one and brings it up to date from the GitHub
  releases.
- Running under a path of a domain (`example.com/community`) as well as
  on a domain of its own.
- One admin page for the whole site: an overview with a switch for each
  community module, and each module's pages and settings in its own group.

## Next

- A Docker compose file.
- HTTPS without the work, if people ask for it (the README says how):
  the installer setting up a proxy that gets its own certificate, or
  Exedra serving HTTPS itself with a Let's Encrypt certificate from the
  admin page. A proxy in front stays the advice for a busy site.
- Release builds of Exedra Desktop for Linux, Windows and macOS.
- Forum: a solved mark on a topic, mentions.
- Private messages for a site without channels: a setting that runs the
  chat as a private messenger only, so a forum's members can write to
  each other from a profile or a post. The admin page says so where the
  forum is switched on. Tested with the CGI build too, where it should
  suit shared hosting far better than the full chat does.
- Emoji and reactions drawn by Exedra itself, one set in the core, so
  they look the same in the chat, the wiki and the forum and on every
  device.
- Catalog: members suggesting an entry.
- Benches: a list of them to browse, and a way for the owner of a web
  site to look after the benches of its pages.
- Color schemes for the whole site, chosen on the admin page.
- Feeds (Atom) for a board, a topic, the wiki's changes and new catalog
  entries, so a reader or another program can follow the site.
- The end to end encryption of private conversations: much more testing
  by people on real devices, and more work on it, before it is something
  to rely on. SECURITY.md says where it stands.
- Two-step sign-in with a code from an authenticator app. Off on a new
  site. Any member may turn it on for their own account, and the site's
  admin decides who must: nobody, the staff, or every member.

## Later

- Importers as tools of their own, apart from Exedra: one that brings the
  pages of a MediaWiki site into the wiki, and one for Simple Machines
  Forum.
- Packages for the ways people like to install: a YunoHost app, and a
  Docker image for the app catalogs built on Docker.
- More use of the CGI build on shared hosting; it runs, the chat poorly
  (INSTALL.md, step 13).
