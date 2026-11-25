<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/exedra-wordmark-dark.svg">
    <img src="docs/images/exedra-wordmark-light.svg" alt="Exedra" width="380">
  </picture>
</p>

> **Version 0.1.0 is on its way.** This page describes it. The source,
> the ready-built releases and the install script arrive here very soon.
> Until then this repository holds only this page, so its links to other
> files lead nowhere yet.

**A community site in one program: chat, a forum, a wiki and a catalog.**
They share the same members, sign-in, roles, search and admin page. Each
one is a module you switch on or off, so a site can run just the chat,
just the forum, or all four.

Exedra is written in Free Pascal and runs as a single native program. It
keeps its data in MariaDB, MySQL, PostgreSQL or SQLite, your choice.
There are ready-built releases for Linux (x86_64 and 64-bit ARM, so a
Raspberry Pi works) and FreeBSD.

It runs [pascal.chat](https://pascal.chat), a community for Free Pascal,
Lazarus and Delphi developers, with a wiki of nearly 7,000 pages and a
catalog of nearly 30,000 projects.

| | |
|---|---|
| ![The chat: a channel with reactions and an answered message](docs/images/screenshot-chat.png) | ![A message's menu: reactions on top, then what you can do with it](docs/images/screenshot-menu.png) |
| The chat | Every message has a menu |
| ![The forum: boards grouped by category](docs/images/screenshot-forum.png) | ![A forum topic with reactions on its posts](docs/images/screenshot-topic.png) |
| The forum | A topic, with reactions |
| ![The wiki: a page with its contents and tools](docs/images/screenshot-wiki.png) | ![The catalog: entries with pictures, ratings and categories](docs/images/screenshot-catalog.png) |
| The wiki | The catalog |
| ![One search over the chat, the wiki, the forum and the catalog](docs/images/screenshot-search.png) | ![The admin page: a switch for each module](docs/images/screenshot-admin.png) |
| One search for all of it | The admin page |

<p align="center">
  <img src="docs/images/phone-chat.png" alt="The chat on a phone, dark" width="250">
  <img src="docs/images/phone-topic.png" alt="A forum topic on a phone" width="250">
  <img src="docs/images/phone-wiki.png" alt="A wiki page on a phone" width="250">
</p>

Every page works on a phone, in light and dark. The pictures show a
made-up community.

## Why one program

Normally a community that wants a chat, a forum and a wiki installs
three different applications. Something like Rocket.Chat, Mattermost or
Zulip for the chat. Discourse or phpBB for the forum. MediaWiki for the
wiki. Each has its own accounts, its own admin pages and its own backups,
and members sign up three times.

Each of those also brings its own stack. Between them you end up
installing things like Node.js, MongoDB, PostgreSQL, Redis, RabbitMQ,
memcached, PHP, Ruby on Rails and Docker, and keeping all of it updated.
Their own documentation gives an idea of the weight:

| | What its docs ask for |
|---|---|
| Rocket.Chat | Node.js and a MongoDB server |
| Mattermost | PostgreSQL, and 2 GB of memory to start |
| Zulip | a machine to itself and at least 2 GB of memory |
| Discourse | Docker, and 1 GB of memory with swap at the very least |
| **Exedra** | **one program. A small site sits at about 40 MB of memory** |

Those are good programs with far more people behind them than this one.
The point is only what it takes to run them. With Exedra it is one
program, one account per member, one admin page, one search across
everything and one backup file.

It is free under a license that asks nothing of you. No paid edition, no
member limit, nothing held back.

## What you get

- **Chat.** Channels, threads, reactions, answers, mentions, files and
  link previews. Private conversations are encrypted end to end, so the
  server cannot read them. Notifications on the phone. An IRC side for
  people who live in HexChat or irssi.
- **Forum.** Boards in categories, moderation, reactions, following a
  topic and mail about replies.
- **Wiki.** Markdown pages with revisions, categories, pictures and more
  than one language.
- **Catalog.** A list of what your community makes, uses or recommends,
  with ratings, filters and pictures. You can shape it to your subject
  with a few lines of plain Pascal that add your own fields and filters.
  The catalog of Pascal projects on pascal.chat is built that way.
- **One search** over all four, showing each reader only what they may
  see. Private conversations are never searched.
- **A chat on every page.** A button in the corner of any page opens the
  talk about that page. One line of HTML puts it on another web site's
  pages too.
- **No captchas.** Scrapers, floods, password guessers and spam bots are
  dealt with by measures built in and on from the first start. Real
  people are not bothered. The details stay out of this page on purpose.
- **31 languages.**
- **Modules of your own.** The four modules plug in through the same
  hooks a fifth can use. [docs/MODULES.md](docs/MODULES.md) has a small
  working example.

The full list is [further down](#what-it-does).

## Why Pascal

Free Pascal compiles to native code, and that is most of why Exedra is
small and quick.

- **No runtime.** There is no interpreter and no garbage collector. The
  program starts, serves, and that is it.
- **One file, only 29 MB.** Everything is linked into a single program:
  the web server, live connections, all four modules, mail, backups and
  the admin page. The whole download is 17 MB.
- **No OpenSSL, and that is where most of the size goes.** About two
  thirds of those 29 MB are the cryptography and TLS code, done in
  Pascal and built into the program. Without it Exedra would be around
  10 MB, but it would need the system's OpenSSL, and that differs from
  one system to the next and can be a problem on ARM boards and small
  installs. This way the same program runs the same everywhere, linked
  against the system's C library and nothing else. We think that is
  worth the megabytes.
- **Mostly what ships with Free Pascal.** The web server, the routing
  and the WebSockets are fcl-web. The databases go through fcl-db's
  SQLDB. JSON, Markdown and syntax coloring are FCL packages too. On top
  of that are four Pascal libraries by one author for cryptography and
  TLS, and nothing else.
- **Quick to build.** The server is about 47,000 lines of Pascal, and a
  full rebuild takes about five seconds.
- **Plain pages.** The browser gets HTML, CSS and JavaScript as written.
  No framework, no bundler, no npm.
- **Easy to read.** A module is a unit, a page is a procedure, a setting
  is one line.

### It is not an old CGI script

Exedra is a server program that stays running. It has its own HTTP
server and keeps a live connection to every open page, which is how
messages and reactions show up at once.

There is also a CGI build, for shared hosting where you cannot keep a
program running. The wiki, the forum and the catalog work fine that way.
The chat does not, because CGI cannot hold a live connection, so we do
not recommend it for the chat. If you have a real server or a VPS, use
the normal program.

## Tested at scale

The chat was load tested in October 2026 on an ordinary 6-core machine
with MariaDB, with 1,000,000 members, 2,100,000 messages and 7,000,000
channel follows in the database:

| Request | Median time |
|---|---|
| Checking for new messages | 4 ms |
| Opening a channel of 600,000 messages and scrolling back | 8 to 10 ms |
| Completing an @name out of a million | 1 ms |
| Searching for a rare word | 7 ms |

With 5,000 browser pages open in one channel and a message posted every
second, all 150,000 deliveries arrived, half of them within 215 ms. The
server held those 5,000 connections in 261 MB of memory.

That is one setup, not a promise for every site. Today Exedra runs as
one program on one machine. Running several copies behind a load
balancer is not built yet. The piece that is missing is passing live
updates between copies, and that is where the work would go when a site
needs it.

## Getting started

On Linux a ready-built release installs with one script, no compiler
needed:

```sh
curl -fsSLO https://raw.githubusercontent.com/TonyStone31/Exedra/main/install.sh
sudo sh install.sh
```

On FreeBSD the same script installs the FreeBSD release. Run it as root,
with `fetch` in place of `curl -fsSLO`.

It starts on SQLite, so there is no database server to set up. To use
MariaDB, MySQL or PostgreSQL, name it in the config file. A backup made
on one database restores on another, so you can start small and move
later.

[INSTALL.md](INSTALL.md) goes from nothing to a working site.

A few things worth knowing first:

- **Put a proxy in front** for HTTPS: HAProxy, nginx or Caddy. It has
  to pass WebSocket connections through.
  [INSTALL.md, step 6](INSTALL.md#6-put-it-on-the-internet) has a working
  config for each, and for running under a path such as
  `example.com/community`.
- **The first account is an ordinary member.** Sign up, then make
  yourself the admin from a shell:
  `exedra exedra.ini --admin YourName`.
- **Set up mail early.** Without it nobody can get a password link or
  confirm an address by themselves.
- **Back up every night.** `exedra --backup --pictures` from cron writes
  one zip with everything.
- **Update with the same script:** `sudo sh install.sh update`.

## What it does

### Shared by every module

- Members with their own accounts, or sign-in with GitHub, GitLab,
  Google, Microsoft or Codeberg.
- The password never leaves the member's device. The browser derives a
  login secret from it, and the server only stores a hash of that.
- A member changes their own password and email address, and can close
  their account. What they wrote stays, under their name or as "Former
  member".
- Roles and permissions set from a table of check boxes. The chat, the
  wiki and the forum each have a moderator and an admin role of their
  own.
- One admin page: members, permissions, settings, look, reports,
  backups, storage and a visitors report.
- One search box on every page.
- Backup and restore of the database and files as one zip.

### Chat

- Channels, threads, pins, mentions, files and link previews.
- A menu on every message, opened from its corner or by a right-click.
- Reactions with the names of who gave each. The admin edits the list of
  emoji.
- A message can answer another, which is quoted above it, and its author
  is told.
- Private conversations encrypted end to end (ECDH P-256, AES-GCM), with
  read receipts the admin or each member can turn off.
- Files in a private channel or conversation open only for those who may
  read the message.
- Beams: a file sent straight from one browser to another.
- Code blocks colored for Pascal and about 30 other languages.
- Slash commands, channel moderators, mute and ban.
- Benches: a channel for a page, opened from the corner button
  ([INSTALL.md, step 5](INSTALL.md#the-corner-chat-and-benches)).
- An IRC side, so HexChat, WeeChat or irssi can join the same channels.
- Web Push notifications, and mail about missed messages.
- An installable web app for phones.

### Wiki

- Pages in Markdown with an editor, a preview and section editing.
- Revisions, categories, a link index, moving and deleting pages.
- Pictures and file pages.
- Pages in more than one language.

### Forum

- Boards in categories, topics and posts in Markdown, with the wiki's
  editor.
- Moderation: pin, lock, move and hide. Members report a post.
- Reactions under a post, with the names of who gave each. A reaction
  never bumps a topic.
- Following a topic: a notice and one mail about replies until you have
  read it, and every mail has a link that stops it.
- Search, read marks, files in posts and a signature for each member.
- A view count that counts people, not reloads or crawlers.

### Catalog

- Entries with a page of their own, categories, search and filters.
- Members rate an entry, mark it Interesting, and report one that does
  not belong.
- Entries are added on the admin page, with a picture, or sent in bulk
  as JSON.
- A site's own unit adds fields and page parts to an entry.

The catalog is the newest module and is off on a new site.

## Exedra Desktop

A Lazarus program for Linux, Windows and macOS that talks to any Exedra
server. Its source is in `desktop/` and
[desktop/README.md](desktop/README.md) says how to build it. It is
younger than the server, so take it as a preview for now.

## For developers

- **The API.** Everything the chat's page does goes through a JSON API,
  so an app or a bot can do the same: [docs/API.md](docs/API.md).
- **The source.** The server's units are in `server/src`: `core` and a
  folder for each module. [docs/CODE-MAP.md](docs/CODE-MAP.md) is a map
  of it.
- **Your own module.** [docs/MODULES.md](docs/MODULES.md).

## Requirements

- **To run it:** Linux on x86_64 or 64-bit ARM, or FreeBSD on x86_64.
- **A database:** MariaDB, MySQL 8, PostgreSQL or SQLite.
- **A proxy in front for TLS:** HAProxy, nginx or Caddy.
- **To build it yourself:** Free Pascal 3.3.1 and Lazarus, with
  [CryptoLib4Pascal](https://github.com/Xor-el/CryptoLib4Pascal),
  [HashLib4Pascal](https://github.com/Xor-el/HashLib4Pascal),
  [SimpleBaseLib4Pascal](https://github.com/Xor-el/SimpleBaseLib4Pascal)
  and [TlsLib4Pascal](https://github.com/Xor-el/TlsLib4Pascal). All four
  are MIT licensed.

## The name

An exedra (say EK-seh-drah) was a part of Greek and Roman public
buildings: an open recess, often a half circle, with a bench running
along the wall. It was built for sitting down and talking. Teachers
held their classes in them and people met there to argue and trade
news. That is what this program is for.

The mark is that bench seen from above, with three people on it.

## License

[0BSD](LICENSE). Use it for anything.

## Security

Found a security problem? Please report it privately, as
[SECURITY.md](SECURITY.md) describes.
