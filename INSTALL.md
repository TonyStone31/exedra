# Installing Exedra

This goes from nothing to a working site. The short version: get one
program (a ready-built release, or build it), put it in a folder with its
page files and a config file, start it, sign up, and make yourself the
admin.

- [What Exedra is made of](#what-exedra-is-made-of)
- [The quick way: a release](#the-quick-way-a-release)
- [What you need](#what-you-need)
- [1. Build the program](#1-build-the-program)
- [2. Make the site folder](#2-make-the-site-folder)
- [3. Write the config file](#3-write-the-config-file)
- [4. Start it and become the admin](#4-start-it-and-become-the-admin)
- [5. Choose the modules](#5-choose-the-modules)
- [6. Put it on the internet](#6-put-it-on-the-internet)
- [7. Run it as a service](#7-run-it-as-a-service)
- [8. Mail](#8-mail)
- [9. Sign-in with GitHub and others](#9-sign-in-with-github-and-others)
- [10. IRC](#10-irc)
- [11. Backups, moving and upgrading](#11-backups-moving-and-upgrading)
- [12. Virus scanning](#12-virus-scanning)
- [13. As a CGI program on shared hosting](#13-as-a-cgi-program-on-shared-hosting)
- [When something is wrong](#when-something-is-wrong)

## What Exedra is made of

Exedra is one program with four modules on a shared core.

| | What it is | Where it lives on the site |
|---|---|---|
| **Core** | Members, sign-in, roles and permissions, the admin page, the guard, the visitors report, mail, backups. Always there. | `/signin`, `/admin`, `/u/<name>` |
| **Chat** | Channels, threads, private conversations, files, the IRC side. | `/p/<channel>`, `/dm` |
| **Wiki** | Pages in Markdown with revisions, categories and pictures. | `/wiki` |
| **Forum** | Boards, topics and posts. | `/forum` |
| **Catalog** | A list of what the community makes or recommends, with ratings. | `/catalog` |

Every module uses the same members and the same admin page. Each module can
be turned on or off, in the config file or on the admin page. A module that
is off has no pages, no admin tabs and no link under the site's name. Its
tables are left alone, so turning it back on brings everything back.

With one module on, the site's front page opens straight on that module. With
more than one, the front page is a home page that links to each.

## The quick way: a release

For Linux there are ready-built releases, so no compiler is needed: one
for x86_64, and one for 64-bit ARM, which is what a Raspberry Pi 4 or 5
with a 64-bit system is. The script picks the right one. Exedra wants
systemd, glibc 2.34 or newer (Debian 12, Ubuntu 22.04, Raspberry Pi OS
12, RHEL 9 and later) and, for the SQLite database it starts with, the
SQLite library (`libsqlite3-0` on Debian and Ubuntu, `sqlite-libs` on
Fedora and RHEL).

```sh
curl -fsSLO https://raw.githubusercontent.com/TonyStone31/exedra/main/install.sh
sudo sh install.sh
```

For FreeBSD on x86_64 there is a release too. It is built against
FreeBSD 14.4 and was tried on 14.4 and on 15.1. The same script installs
it. As root:

```sh
pkg install sqlite3
fetch https://raw.githubusercontent.com/TonyStone31/exedra/main/install.sh
sh install.sh
```

On FreeBSD the folder is `/usr/local/exedra`, not `/opt/exedra`. The
service is an rc.d script, `/usr/local/etc/rc.d/exedra`, which the
script switches on with `exedra_enable="YES"` in `/etc/rc.conf`. You
start it with `service exedra start`, and what the program prints goes
to syslog (`/var/log/messages`). Where this page says `/opt/exedra` and
`systemctl`, read `/usr/local/exedra` and `service`.

Read the script first if you like; it is short. It downloads the newest
release from GitHub, checks it against its checksum and against the
signature of Exedra's release key (it needs `openssl` for that), puts it in
`/opt/exedra`, makes the user `exedra` and the systemd service, and
writes a first `exedra.ini` from the example. The program and its page
files belong to root; the user `exedra` owns only `data/` and
`wiki-images/`. It does not start the
service: look at `/opt/exedra/exedra.ini` first (the site's name, its
address, the port), then

```sh
sudo systemctl start exedra
```

and carry on at [step 4](#4-start-it-and-become-the-admin). Steps 1 to 3
are for building from the source.

Later, to bring it up to date:

```sh
sudo sh /opt/exedra/install.sh update
```

That replaces the program and the page files, and starts the service
again when it was running. Your `exedra.ini` and `data/` are not touched, and the program it
replaced is kept as `/opt/exedra/exedra.previous`. `sh install.sh check`
says which release is installed and which is the newest. Make a backup
before an update (step 11).

Without root, or to keep it out of systemd, the same script puts only
the files in a folder of your choice, from a download or from a release
file you already have:

```sh
sh install.sh --dir ~/exedra --no-service
sh install.sh --dir ~/exedra --no-service --from exedra-0.2.0-linux-x86_64.tar.gz
~/exedra/exedra ~/exedra/exedra.ini
```

You start and stop the program yourself then, and after
`install.sh update --dir ~/exedra --no-service` you start it again
yourself. A release file given with `--from` needs its `.sig` file beside
it, and is checked against it and against its `.sha256` file when that is
there. `--unsigned` takes a file without a signature, which you should
only do with one you built yourself. An older release is not put over a
newer one unless you add `--older`.

The release files are named for their system:
`exedra-<version>-linux-x86_64.tar.gz`, `-linux-aarch64.tar.gz` and
`-freebsd-x86_64.tar.gz`.

## What you need

To build it yourself:

- **A Linux machine, x86_64 or 64-bit ARM.** A small VPS or a Raspberry
  Pi is enough.
- **A database.** One of:
  - **SQLite.** No database server. The whole site is one file. The
    easiest start, and fine for a small community.
  - **MariaDB** or **MySQL 8**.
  - **PostgreSQL**.
- **The one library the program loads at run time:** the client
  library of your database. On Debian or Ubuntu:

  ```sh
  sudo apt install libsqlite3-0      # SQLite
  sudo apt install libmariadb3       # MariaDB or MySQL
  sudo apt install libpq5            # PostgreSQL
  ```

  On FreeBSD the packages carry a version in their name. These were
  tried:

  ```sh
  pkg install sqlite3                # SQLite
  pkg install mariadb118-client      # MariaDB or MySQL
  pkg install postgresql17-client    # PostgreSQL
  ```

- **To build:** Free Pascal 3.3.1 (the main branch) and Lazarus built
  with it. [fpcupdeluxe](https://github.com/LongDirtyAnimAlf/fpcupdeluxe)
  installs both, choose "trunk" for each. The released Free Pascal 3.2
  is too old, because the Markdown, code coloring and WebSocket units
  Exedra uses are newer than it. Trunk changes every day, so a newer
  one than ours can hit a problem we have not seen.
- **Four Pascal libraries**, all MIT licensed:
  [HashLib4Pascal](https://github.com/Xor-el/HashLib4Pascal),
  [SimpleBaseLib4Pascal](https://github.com/Xor-el/SimpleBaseLib4Pascal),
  [CryptoLib4Pascal](https://github.com/Xor-el/CryptoLib4Pascal) and
  [TlsLib4Pascal](https://github.com/Xor-el/TlsLib4Pascal).
  They do the password hashing, sign the push notifications and make
  the TLS connections the program opens itself.
- **For a public site:** a domain name and a proxy in front that does
  TLS (HAProxy, Caddy or nginx). See step 6.

You build on any machine with Lazarus and copy the result to the
server. The server itself needs no compiler.

## 1. Build the program

Get the source and the four libraries:

```sh
git clone https://github.com/TonyStone31/exedra.git
git clone https://github.com/Xor-el/HashLib4Pascal.git
git clone https://github.com/Xor-el/SimpleBaseLib4Pascal.git
git clone https://github.com/Xor-el/CryptoLib4Pascal.git
git clone https://github.com/Xor-el/TlsLib4Pascal.git
```

Tell Lazarus where the libraries are. This is done once:

```sh
lazbuild --add-package-link HashLib4Pascal/HashLib/src/Packages/FPC/HashLib4PascalPackage.lpk
lazbuild --add-package-link SimpleBaseLib4Pascal/SimpleBaseLib/src/Packages/FPC/SimpleBaseLib4PascalPackage.lpk
lazbuild --add-package-link CryptoLib4Pascal/CryptoLib/src/Packages/FPC/CryptoLib4PascalPackage.lpk
lazbuild --add-package-link TlsLib4Pascal/TlsLib/src/Packages/FPC/TlsLib4PascalPackage.lpk
lazbuild --add-package-link TlsLib4Pascal/TlsLib.Net/Packages/FPC/TlsLib.Net.lpk
lazbuild --add-package-link TlsLib4Pascal/TlsLib.Trust.System/Packages/FPC/TlsLib.Trust.System.lpk
lazbuild --add-package-link TlsLib4Pascal/TlsLib.Adapters/FclNet/Packages/FPC/TlsLib.Adapter.FclNet.lpk
```

Build:

```sh
lazbuild exedra/server/exedra.lpi
```

The program is now at `exedra/server/bin/exedra`. The first build takes
about a minute because the crypto library is large.

## 2. Make the site folder

The site is a folder that holds the program, its page files and its
config file. The program writes its own data under `data/` in the same
folder.

```sh
sudo mkdir -p /opt/exedra
sudo cp exedra/server/bin/exedra /opt/exedra/
sudo cp -r exedra/server/site/. /opt/exedra/
sudo cp exedra/server/exedra.ini.example /opt/exedra/exedra.ini
```

The folder then looks like this:

```
/opt/exedra/
  exedra          the program
  exedra.ini      the config file
  static/         scripts, styles and pictures
  templates/      the pages
  lang/           the site's words in 31 languages
  data/           made by the program: files, backups, logs,
                  and the database when it is SQLite
```

Give it a user of its own, so the site does not run as root. That user
owns only the folders the program writes in. The program and its page
files stay root's, so a fault in the site cannot replace them:

```sh
sudo useradd --system --home /opt/exedra --shell /usr/sbin/nologin exedra
sudo mkdir -p /opt/exedra/data /opt/exedra/wiki-images
sudo chown -R root:root /opt/exedra
sudo chown -R exedra:exedra /opt/exedra/data /opt/exedra/wiki-images
sudo chown root:exedra /opt/exedra/exedra.ini
sudo chmod 640 /opt/exedra/exedra.ini
```

## 3. Write the config file

Edit `/opt/exedra/exedra.ini`. The sample has every setting with a
comment. A small site on SQLite needs only this:

```ini
[site]
name=My Community
url=http://127.0.0.1:8099
port=8099
address=127.0.0.1
files=/opt/exedra

[database]
server=sqlite
file=/opt/exedra/data/site.db
```

`address=127.0.0.1` means only this machine can reach it, which is right
when a proxy sits in front. Accounts need a secure page: a browser lets
the sign-in work on `http://127.0.0.1` and `http://localhost`, and
otherwise only over https. So to try it from another computer before the
proxy is set up, tunnel the port (`ssh -L 8099:127.0.0.1:8099 yourserver`,
then open `http://127.0.0.1:8099` there), not the machine's plain
address.

### MariaDB or MySQL instead

Make an empty database and a user for it:

```sql
CREATE DATABASE exedra CHARACTER SET utf8mb4;
CREATE USER 'exedra'@'localhost' IDENTIFIED BY 'a long password';
GRANT ALL ON exedra.* TO 'exedra'@'localhost';
```

```ini
[database]
host=127.0.0.1
port=3306
name=exedra
user=exedra
password=a long password
```

Take the two SQLite lines (`server=sqlite` and `file=`) out when you
put these in. The database server itself has to be installed and running
first; Exedra brings only the client side. For MySQL 8 add
`client=mysql80` and, when it is not found on its own, `library=` with
the path of `libmysqlclient.so`.

### PostgreSQL instead

```sh
sudo -u postgres createuser --pwprompt exedra
sudo -u postgres createdb --owner exedra --encoding UTF8 exedra
```

```ini
[database]
server=postgres
host=127.0.0.1
port=5432
name=exedra
user=exedra
password=a long password
```

Whichever you choose, the program makes its own tables at the first
start. There is no schema file to load. You can change your mind later:
a backup made on one database goes back on any other (step 11).

## 4. Start it and become the admin

```sh
cd /opt/exedra
sudo -u exedra ./exedra
```

It reads `exedra.ini` from its own folder. To use another file, name
it: `./exedra /etc/exedra.ini`.

(Installed from a release with the service started? Skip that command;
the service is the running program.)

Open `http://127.0.0.1:8099/signin` in a browser and **sign up**: one
form serves for joining and for signing in, so type a new name and a
password of eight characters or more and press Go. The first account is
an ordinary member like any other. Make it the admin from a
second terminal:

```sh
cd /opt/exedra
sudo -u exedra ./exedra --admin YourName
```

It answers `YourName is an admin now.` Reload the page and open
`/admin`. From here on, everything is set on the admin page: the site's
name and look, who may do what, new accounts open or closed, limits,
and the modules.

## 5. Choose the modules

A new site starts with the chat and the wiki on, and the forum and the
catalog off.

The admin page opens on **Overview**. Under **Community modules** each
module has a card with a **Turn on** or **Turn off** button. The change
takes effect at once, except the chat's IRC side, which follows the next
restart.

The same switches work in the config file, for a site that should start
a certain way before anyone has signed in:

```ini
[site]
chat=1
wiki=1
forum=1
catalog=1
```

A value saved on the admin page wins over the config file.

Some ways to set a site up:

| You want | Turn on | The front page |
|---|---|---|
| A wiki and nothing else | wiki | opens the wiki's main page |
| A forum and nothing else | forum | opens the forum |
| A chat for a team or a project | chat | the home page, or a channel when `start_room` is set |
| A list of things with ratings | catalog | opens the catalog |
| A whole community site | all four | the home page, with links to each |

Under the site's name, in the column on the left, are links to the
modules that are on. More links of your own go after them: admin page,
**Settings**, group **Site**, "More links under the site's name", written
as `Shop=https://shop.example.com, Rules=/wiki/Rules`.

A page about the site is yours to write: save it as `about.html` in the
`templates` folder and restart, and it answers at `/about` (without the
file that address answers 404). It is a whole page like the others in
that folder, and `{{site}}`, `{{brand}}` and `{{nav}}` work in it as they
do there. Nothing links to it until you add `About=/about` to the links
above.

Each module adds its own group to the admin page (Channels for the chat,
Forum boards for the forum, Catalog for the catalog) and its own settings
groups.

Each module also brings two roles of its own, a moderator and an admin
(`forum-moderator`, `forum-admin`, and the same for the others; the
catalog has `catalog-admin`). Give one to a member under **Members** and
they look after that module and nothing else.

### The corner chat and benches

With the chat on, every page of the site has a round button at the bottom
right: the corner chat. It shows the latest talk and lets a member say
something without leaving the page.

A **bench** is a channel that belongs to one page. On a wiki page the
corner chat offers to open the page's bench; once a member has, everyone
who reads that page finds the same talk. Benches are not in the list of
channels: a member sees the ones they follow under **Benches**. Who may
open one is the permission "Open a bench for a page", which members have
on a new site.

The same works on **another web site**. Its owner adds one line to their
pages, with your site's address in it:

```html
<script src="https://chat.example.com/embed.js" async></script>
```

A visitor there sees the corner chat and reads along. To talk, or to open
the bench for that page, they come to your site and sign in; the bench is
a channel on your site, opened when a member presses the button for it
there. A bench is only ever opened for a page that
carries the line: your site reads the page first and looks for it, so
nobody can open benches for pages whose owner did not ask for the chat.
Each page gets its own bench, by its address without what follows a `?`.

### Reactions

The emoji members can put on a message are yours to choose: **Settings**,
group **Reactions**. "Reactions shown at once" are the few a message's
menu shows right away (12 at most), "More reactions" the ones behind its
plus button (120 in all at most; leave it empty and there is no button).
Each is a line of emoji with spaces between them. A reaction you take
off the lists stays under the messages that have it, and members can
still take theirs back; nobody can add it anymore.

The forum offers the same emoji under its posts. To keep some of them
out of the forum, list them under **Settings**, group **Forum**,
"Reactions the forum leaves out"; the chat goes on offering them.

### Your own words

Every word the site shows can be replaced without touching the program.
Put a file `en.json` in the `lang` folder with the words as they are on
the left and yours on the right, and restart:

```json
{
  "%d entries in the catalog.": "%d recipes in the book.",
  "Random entry": "Surprise me"
}
```

A `%d` or `%s` on the left has to be on the right too. The same works for
another language in `de.json`, `fr.json` and so on; your file wins over
the one Exedra brings, and an update leaves it alone.

### The search index

Every page has one search box, and each module answers it from the
database. The site can also keep a search index of its own and answer
from that. It is off until you turn it on: **Settings**, group
**Search**.

- "The site search answers from": `database` is how it works without an
  index. `index` answers from the index. `compare` keeps the index and
  still answers everyone from the database, except those who may change
  the settings, so you can look at it before your visitors do.
- "Languages whose word forms a search matches": with `en`, a search for
  "index" also finds "indexes". Name the languages your site is written
  in, with commas between them, out of da, de, en, es, fi, fr, it, nl,
  no, pt and sv. Changing the list builds the index again.

A module is answered from the index only once it has joined it. Until
then it is searched in the database as before, whatever the setting says.

To compare the two, search while you are signed in as someone who may
change the settings. The results page then says which one answered and
how long it took, with a link to the same search answered by the other.
The **Search** settings also show how the index of each module stands.

The index is kept in `data/search`. The program makes it, keeps it in
step with what members write, and builds it again once a day and whenever
it no longer fits the database. Expect it to take about one and a half
times the room of the text it searches. It is in no backup, because the
program makes it again, and it is safe to delete while the server is
stopped.

If you load a database dump by other means than the program's own
restore, delete `data/search` before you start the server. The index
cannot tell that the database under it changed.

## 6. Put it on the internet

Exedra speaks plain HTTP. A proxy in front holds the certificate. The
proxy must pass WebSocket connections through, because the live updates
use one at `/api/live`.

Tell Exedra it is behind TLS and what its public address is:

```ini
[site]
url=https://community.example.com
https=1
address=127.0.0.1
proxies=127.0.0.1
```

`proxies` lists the addresses whose `X-Forwarded-For` header is
believed. Leave it at the proxy's own address. Without it every visitor
would seem to come from the proxy, and the guard would block the proxy.

**HAProxy**, with the certificate and its key in one PEM file:

```
frontend https
    bind :443 ssl crt /etc/haproxy/certs/community.example.com.pem
    mode http
    option forwardfor
    default_backend exedra

backend exedra
    mode http
    timeout server 1h
    timeout tunnel 1h
    server exedra 127.0.0.1:8099
```

`option forwardfor` adds the visitor's address for Exedra, and
`timeout tunnel` keeps the live connections open. HAProxy passes
WebSocket connections through on its own.

For nginx and HAProxy you need the proxy installed, the domain's DNS
pointing at the server, ports 80 and 443 open, and a certificate, for
example from [certbot](https://certbot.eff.org/). HAProxy wants the
certificate and its key joined in one file
(`cat fullchain.pem privkey.pem > community.example.com.pem`, again after
each renewal). Caddy needs none of that.

**Caddy** gets and renews the certificate by itself. The whole
`Caddyfile`:

```
community.example.com {
    reverse_proxy 127.0.0.1:8099
}
```

**nginx**, with a certificate from certbot:

```nginx
server {
    listen 443 ssl;
    server_name community.example.com;
    ssl_certificate     /etc/letsencrypt/live/community.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/community.example.com/privkey.pem;
    client_max_body_size 40m;

    location / {
        proxy_pass http://127.0.0.1:8099;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 1h;
    }
}
```

### Under a path of a domain

Exedra does not need a domain to itself. To have it at
`https://example.com/community`, put the path in its address:

```ini
[site]
url=https://example.com/community
https=1
```

and have the proxy send that path to it. The path may stay on the
request or be taken off; Exedra accepts both.

```
# HAProxy, in the frontend
use_backend exedra if { path_beg /community }

# Caddy
example.com {
    handle /community* {
        reverse_proxy 127.0.0.1:8099
    }
}

# nginx, inside the server block, with the same proxy_set_header lines as above
location /community {
    proxy_pass http://127.0.0.1:8099;
}
```

Every page, link and request then carries `/community`. Choose the path
before people sign up for push notifications or install the site as an
app, since both remember the address. The CGI build does not take a path
yet.

Restart Exedra after changing the config file.

## 7. Run it as a service

Copy the sample unit and start it:

```sh
sudo cp exedra/server/exedra.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now exedra
systemctl status exedra
```

The unit runs `/opt/exedra/exedra` as the user `exedra` and
starts it again if it stops. Edit the paths in it if yours differ.

On FreeBSD the service is an rc.d script. With the site in
`/usr/local/exedra` and a user `exedra` who owns it
(`pw useradd exedra -d /usr/local/exedra -s /usr/sbin/nologin`), as
root:

```sh
cp exedra/server/exedra.rc /usr/local/etc/rc.d/exedra
chmod 555 /usr/local/etc/rc.d/exedra
sysrc exedra_enable=YES
service exedra start
service exedra status
```

The script runs the program as the user `exedra` under `daemon(8)`,
which starts it again if it stops and sends what it prints to syslog.
When the site is in another folder, name it in `/etc/rc.conf`:
`exedra_dir="/some/folder"`.

## 8. Mail

Mail is optional. With it, new members confirm their address, a
forgotten password gets a link, and members hear about messages they
missed and about replies in the forum topics they follow. Exedra signs
in to a mailbox over TLS (port 465):

```ini
[mail]
host=mail.example.com
port=465
user=community@example.com
password=the mailbox password
from=community@example.com
name=My Community
reports_to=you@example.com
```

`reports_to` is where reports from members go. Without a `[mail]`
section nothing is sent and the site works all the same.

To try a site out before it has a mailbox, give `file=/a/path` under
`[mail]` in place of `host`: every mail is added to that file as it
would have gone out, and none is sent.

### Mail from the forum

A member follows a forum topic when they start it or reply in it, or
press **Follow** on its page. When someone else replies, each follower
gets a notice on the site and, to a confirmed address, one mail about
that topic; no second one comes until they have read the topic, so a
busy topic floods nobody. Mail goes only for a reply the follower may
read, and never to a banned member or a closed account.

A member stops it in three ways: the two links at the foot of every such
mail, which need no sign-in and ask before they act (stop following that
topic, or stop all the forum's mail); the button on the topic's page and
the list under **Topics you follow** in the forum; and their profile,
which has "Email me about replies in forum topics I follow" and "Follow
a topic when I post in it".

An admin sets it for the whole site under **Settings**, group **Forum**:
"Email members about replies in the topics they follow" turns the mail
off and leaves the notices, and "Mails about replies the forum sends in
an hour, at most" (200 at first) keeps a busy forum within what the
mailbox allows; past it, a reply is told by its notice alone.

Without mail, an admin can still help someone who forgot their
password: on the admin page, under **Members**, pick the member and press
**Password link**. It shows a one-time link to send them. The same from a
shell, for when the one locked out is the admin:

```sh
sudo -u exedra ./exedra --password-link TheirName
```

Members change their own password and email address on their profile,
under **Email and password**.

### Closing an account

A member who wants to leave closes their account in the same box, with
their password. An admin closes one under **Members**, with a reason.
Either way the account is closed, not deleted: nobody can sign in to it
any more, and its email address, password, picture, profile and personal
settings are wiped. What the member wrote stays, marked "Former member"
where their standing used to show, and their name stays taken. A name
quoted or mentioned inside other people's text stays as it was typed.

Under **Settings**, group **Members**, "The name a closed account shows"
decides whether a closed account keeps its member's name (`keep`, the
default) or is shown as "Former member" with a number (`anonymous`). A
member closing their own account can ask for the second whatever the
setting says.

An admin can open a closed account again from the same place. It comes
back with no email address and no password, so make a password link for
its member next; an account that was given a number for a name keeps it
until an admin renames it. A ban is something else: it can be lifted and
wipes nothing. The site's only admin cannot close their own account.

## 9. Sign-in with GitHub and others

Members can sign in with GitHub, GitLab, Codeberg, Google or Microsoft.
Each one needs an OAuth app that you register with that provider. Give
the provider this return address:

```
https://community.example.com/_oauth/github
```

with `gitlab`, `codeberg`, `google` or `microsoft` in place of `github`.
Then put the app's id and secret on the admin page, **Settings**, group
**Sign-in**. A provider shows on the sign-in page once it has both.

A self-hosted GitLab, Forgejo or Gitea works too: set its address in
the same group.

## 10. IRC

The chat can also be an IRC server on the same channels and members, so
people can join from HexChat, WeeChat or irssi.

```ini
[irc]
tls_port=6697
cert=/etc/letsencrypt/live/community.example.com/fullchain.pem
key=/etc/letsencrypt/live/community.example.com/privkey.pem
public_port=6697
```

The user `exedra` must be able to read the two files. Open the port
in the firewall. The site's `/irc` page then tells members how to set up
their client. Without an `[irc]` section there is no IRC side.

An IRC client sends the member's password to the server. Open only the
TLS port to the internet. The plain `port=` setting is for a proxy that
does the TLS itself, or for a private network.

## 11. Backups, moving and upgrading

**Backups.** On the admin page, **Backup** makes one zip with the whole
site: every table, the members' files and the config file. It can be
downloaded, checked and restored there. From the command line, for a
nightly cron job:

```sh
sudo -u exedra /opt/exedra/exedra --backup --pictures
sudo -u exedra /opt/exedra/exedra --backup --pictures --logs
```

Plain `--backup` holds the database, the config file and the files
members sent. `--pictures`
adds the wiki's pictures, which a site with a wiki wants every time;
`--logs` adds the access logs. A line for root's crontab
(`sudo crontab -e`), every night at 3:30:

```
30 3 * * * sudo -u exedra /opt/exedra/exedra --backup --pictures
```

The five newest backups are kept.

Backups are kept in `/opt/exedra/data/backups`. Copy them to another
machine. The zip holds the config file with the database password, so
keep it as safe as the site.

**Moving to another machine, or another database.** Install Exedra
on the new machine as above, with a config file that names an empty
database. Then, with the service stopped:

```sh
sudo -u exedra /opt/exedra/exedra --restore /path/to/site-backup.zip
sudo systemctl start exedra
```

A backup holds rows, not table definitions, so one made on MariaDB goes
back on PostgreSQL or SQLite and the other way around.

**Upgrading.** Make a backup. Installed from a release:
`sudo sh /opt/exedra/install.sh update` does all of it. Built from the
source: build the new version, stop the service,
replace the program and the `static`, `templates` and `lang` folders,
and start it again. The program upgrades its own tables at start.

```sh
sudo systemctl stop exedra
sudo cp exedra/server/bin/exedra /opt/exedra/
sudo cp -r exedra/server/site/. /opt/exedra/
sudo systemctl start exedra
```

Your `exedra.ini` and `data/` are not touched by this.

## 12. Virus scanning

Exedra can scan every file members upload with ClamAV before it is kept:
chat files, avatars, wiki pictures and forum attachments. A file the
scanner finds something in is refused and not stored. Scanning is off
until you switch it on, so a site without ClamAV works the same.

On Debian or Ubuntu, install the scanner, its signature updater and its
daemon:

```sh
sudo apt install clamav clamav-daemon clamdscan
sudo systemctl enable --now clamav-freshclam clamav-daemon
```

The daemon, clamd, keeps the signatures in memory, so a scan takes a
moment. Its first start waits for freshclam's first download.

Then on the admin page, **Settings**, group **File scanning**:

- switch scanning on,
- leave the command at `clamdscan --stream --no-summary`,
- choose what a file gets when the scanner cannot be started or fails:
  **allow** keeps it unscanned, **refuse** turns it away,
- press **Test the scanner**. It scans the EICAR test file, a harmless
  file every virus scanner reports, and says whether it was caught. It
  then scans an archive nested deeper than ClamAV reads and warns when
  the scanner does not report that limit.

The same group shows the scanner's version and its last error, and lists
the files it stopped or could not check: when, who, where, the name, the
size and the SHA-256.

**Why `--stream`.** clamd runs as its own user and cannot read files in
another service's private `/tmp` (the sample unit has `PrivateTmp=true`).
With `--stream`, clamdscan reads the file and sends it over clamd's socket.

**Limits for big files.** clamd stops reading at the limits in
`/etc/clamav/clamd.conf`. Check them against the largest upload you allow
(the largest is 32 MB):

```
StreamMaxLength 40M
MaxFileSize 40M
MaxScanSize 100M
AlertExceedsMax yes
```

`StreamMaxLength` is the most `--stream` may send, `MaxFileSize` the
largest file clamd reads, and `MaxScanSize` what it reads in all of an
archive's contents. Restart clamd after a change. A file over a limit is
not fully scanned. With `AlertExceedsMax yes` clamd says so, and the file
counts as a scanner error and gets what you chose for that case. Without
it clamd calls such a file clean, so set it.

**Without the daemon** the command can be `clamscan --no-summary`. It
loads the signatures for every file, which takes 10 to 30 seconds and
much memory, so raise the scan's time limit in the same group. Exedra
adds `--alert-exceeds-max` to a clamscan command itself.

A file counts as clean only when the scanner exits with 0 and prints
`<file>: OK`, and as found when it exits with 1 and prints
`<file>: <name> FOUND`. Anything else is a scanner error: another exit
code, a program ended by a signal or by the time limit, or a missing
answer. That is why `--infected` and `--quiet` are not taken: they hide
the OK line.

The command may only name clamscan or clamdscan, with no other options
than `--no-summary`, `--stream`, `--fdpass`, `--multiscan` and
`--alert-exceeds-max`, because it can be changed from the admin page.
The file is passed last, after `--`. Another scanner that answers as
ClamAV does (the exit codes and the lines above) can be named in the
config file, which only the server's operator can change:

```ini
[site]
scan_program=/usr/local/sbin/my-scanner
```

and then put first in the command.

## 13. As a CGI program on shared hosting

Exedra can be built as a CGI program, for a host where you cannot keep
a program of your own running. A release carries it as
`cgi/exedra.cgi`; from the source it is
`lazbuild --build-mode=CGI exedra/server/exedra.lpi`.

**Use it only when you have no other choice, and not for the chat.** A
CGI program is started again for every request, so each page costs a
program start and a new database connection, and nothing runs between
requests. That means:

- **The chat is poor.** No live connection: the page asks for news every
  few seconds, so messages arrive late. No IRC, no push notifications, no
  link previews, no mail about missed messages.
- **The wiki and the forum do fine** on a small site. They are pages and
  forms, and a visitor waits a little longer for each.
- Nothing is done in the background: no backups from the admin page
  (use the host's own), no storage figures, no visitors report.
- No search index: the search always asks the database.

To set it up: put `exedra.cgi` in the host's `cgi-bin` and the config
file, `exedra.ini`, **outside the web root**, with `files=` naming a
folder, also outside the web root, that holds `static`, `templates`,
`lang` and `data`, and SQLite as the database. The config file holds
passwords: in a folder the web serves, anyone could read it.

Have the web server name the config file and send every address to the
program. With Apache, in a `.htaccess` file in the web root:

```
SetEnv EXEDRA_CONFIG /home/you/exedra/exedra.ini
RewriteEngine On
RewriteCond %{REQUEST_URI} !^/cgi-bin/
RewriteRule ^(.*)$ /cgi-bin/exedra.cgi/$1 [L,QSA]
```

Without `EXEDRA_CONFIG` the program looks for `exedra.ini` beside itself;
if the host leaves no other way, keep it there and forbid it:

```
<Files "exedra.ini">
  Require all denied
</Files>
```

The program has to be executable (`chmod 755`), `url=` in the config is
the public address, and the web server's account must be able to write
in `data/`. Turn the chat off on the
admin page, under Community modules. This way of running it has had
far less use than the server; expect rough edges.

## When something is wrong

- **It does not start.** Run it by hand as in step 4 and read what it
  prints. A missing library is named there, and so is a database it
  cannot reach.
- **The page loads without styles.** `files=` in the config does not
  point at the folder that holds `static/`, `templates/` and `lang/`.
- **Signing in fails behind the proxy.** `https=1` and `url=` must match
  the address people type. Sign-in cookies are marked for TLS only when
  `https=1`.
- **Mail, push or sign-in with another site fails with "the server
  certificate chain was not trusted".** Exedra checks the certificate of
  every server it connects to against the system's trusted certificates:
  the file `/etc/ssl/certs/ca-certificates.crt` on Debian and Ubuntu,
  which the `ca-certificates` package keeps. It needs no TLS library of
  the system for this. To trust other certificates in their place (a
  mail server with a certificate of your own authority, say), name a
  file of PEM certificates, or a folder of them, in the config:

  ```ini
  [tls]
  certs=/etc/exedra/trusted.pem
  ```

- **Everyone is blocked at once.** `proxies=` does not list the proxy,
  so all visitors look like one address.
- **Messages only show after a reload.** The proxy does not pass
  WebSocket connections. The site still works by polling, only slower.
- **The log.** `journalctl -u exedra` when run as a service. The
  access logs are in `data/logs`, and the admin page's Visitors tab
  reads them.
