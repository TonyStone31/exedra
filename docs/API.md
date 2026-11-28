# The Exedra API

Everything the web page does goes through this API, so an app, a desktop
client or a bot can do the same. Answers are JSON unless they say
otherwise; refusals are plain text with a 4xx code, in words a person can
read.

## Signing in

The password never leaves the device. From the name and password a client
derives two keys:

1. `PBKDF2-SHA256(password, salt = "beginend:" + lowercase(name), 600000 rounds)` gives 32 bytes. (beginend was the program's first name; the salt keeps it so passwords made then still work.)
2. HKDF-SHA256 over those bytes (salt 32 zero bytes, info `sign in`) gives the login secret, sent as 64 hex digits (`auth`).
3. HKDF-SHA256 the same way with info `wrap` gives the AES-GCM key that wraps the member's private key.

`static/keys.js` is the reference: a client has to derive exactly what it
derives, or the member's private messages cannot be opened.

Before signing in or opening a wrapped key, get `/api/auth-name?name=` and
use its `name` in the password salt. The account's current name still goes
in the sign-in request. Signup and a new password use the current name as
the salt. A rename keeps the previous salt so the password keeps working.

| Request | Fields | Answer |
|---|---|---|
| `POST /api/signup` | name, auth, pub (the public ECDH P-256 key), wrapped (the private key, wrapped), app | name, token when app was sent |
| `POST /api/signin` | name, auth, app | name, wrapped, token when app was sent |
| `GET /api/auth-name?name=` | | name to use in the password salt, unchanged by a member rename (so the first name can be found from the new one; an account closed without a name loses it) |
| `POST /api/signout` | | ok |
| `GET /api/me` | | name, key_name (the stable identity for locked messages), roles, banned, can (site permissions), avatar, away |

A web page gets a cookie. An app sends `app=<a name for the device>` and
gets a token instead, good for a year. Send it on every request:

    Authorization: Bearer <token>

Signing in with GitHub, GitLab and the others from an app: `GET
/api/providers` lists what the site offers (`name`, `title`). The app
listens on a port of 127.0.0.1, makes up a random `state` (16 to 64
letters and digits) and opens
`/signin-with/<name>?app=<its name>&port=<port>&state=<state>` in the
browser. When the provider has answered, a page of the site names the
app and the account and asks the member to allow it or cancel; the answer
is a form the site takes only from its own page. Allowed, the browser is
sent to `http://127.0.0.1:<port>/?grant=<code>&state=<state>`; otherwise
to `?failed=1` (the member said no, or the sign-in did not go through) or
`?failed=closed` (new accounts are closed), each with the state.
The app takes only an answer that carries its own state. `POST
/api/grant` with that `code` and the `state`, within two minutes and
once, answers the app token. A
member already signed in on the web links the login to their account
and the app gets that account.

Members can also make tokens for bots on their profile page (`GET/POST
/api/tokens`). A bot is an ordinary account; an admin can give it the
`bot` role so it shows a badge.

## Staying current

1. Connect a WebSocket to `/api/live` (send the cookie or the
   Authorization header). The first message is `{"t":"hello","id":"..."}`.
2. Send that id as `live` with every `GET /api/sync`. The server then
   knows which channel this client shows.
3. Send any text every 25 seconds, or the server closes the connection
   after 90.
4. When a ring arrives, ask `/api/sync`. A ring says what changed, not
   what it says; the one exception is a new message, which rides along as
   `m` on its `room` ring to the pages of members who may read it:

| Ring | Meaning |
|---|---|
| `{"t":"room","room":"lobby"}` | something changed in that channel |
| `{"t":"typing","room":"lobby","name":"x"}` | x is typing in the channel this client shows |
| `{"t":"me"}` | something for this member: a mention, an invite |
| `{"t":"dm","from":"x"}` | a private message from x (or one this member sent from another device); with `"deleted": id` that message was taken back, with `"gone": true` the whole conversation |
| `{"t":"dmseen","from":"x","seen":id}` | x has read the private conversation up to that message; sent only where read receipts apply to the two |
| `{"t":"names"}` | a member was renamed; refresh member and room lists and cached private-message identities |

Without a live connection (a site run as CGI has none), ask `/api/sync`
every few seconds instead.

`GET /api/sync?room=&since=&thread=&read=&rooms=1&live=` answers with
`rev`, then what changed since `since`: `messages` in the channel, `thread`
(the open thread), `typing`, `here`, and with `rooms=1` the sidebar
(`rooms` with unread and mention counts, `owner`, whether this member
opened the channel, and `notify`; `dms`). Keep the highest `rev`
seen minus three seconds as the next `since`, and replace messages by `id`
when a newer `rev` arrives. `read` marks the channel read up to a message id.

## Channels and messages

| Request | Notes |
|---|---|
| `GET /api/rooms` | the member's followed channels (public channels for guests) |
| `GET /api/room?slug=` | one channel: kind, topic, owner, private, following, policy (`all`, `readonly`: some start messages and anyone replies, `closed`: only they write at all, or `owner`), can_start, can_reply, why_not, as_sent (true where nobody changes or deletes a message once it is sent), can (what this member may do there), and whatever units added on top put there; opening a channel makes it the one `/` brings the member back to |
| `GET /api/room/members?room=` | a private channel's members, or who holds a role in a public one: name, avatar, roles, owner, `away`, and `online` (seen on some page in the last two minutes) |
| `POST /api/room/create` | slug, topic, private (1 or 0) |
| `POST /api/follow` | room, on (1 or 0); off is leaving the channel |
| `POST /api/follow/notify` | room, mode: `all`, `mentions` or `none`. How much a followed channel may bother the member. Silenced (`none`) means no push and no mail about mentions there, and the page shows no badge; `mentions` shows the mention badge alone. The sidebar carries each room's `notify`. |
| `POST /api/room/delete` | slug: a private channel, by a member in it who holds the room permission `delete-channel` (its owner does); everything in it goes and its members get the ring `gone`. A public channel is refused. |
| `POST /api/admin/channel/delete` | slug: a public channel, by someone with `manage-channels`; everything in it goes and its members get the ring `gone`. A private channel is refused here. |
| `POST /api/topic` | room, topic |
| `POST /api/typing` | room |
| `GET /api/messages?room=&before=` | 50 messages, newest first, before an id |
| `GET /api/thread?id=` | a message and its replies |
| `GET /api/pins?room=` | |
| `GET /api/search?q=&room=` | words of three letters or more, anywhere the member may read |
| `POST /api/post` | room, parent (a thread), body, files, re (the id of a message this one answers). Answers id, info (text for this member only), go (a page to open, after /join) |
| `POST /api/edit` | id, body |
| `POST /api/delete` | id |
| `POST /api/react` | id, r (an emoji): puts the member's reaction on the message, or takes it off |
| `GET /api/reacted?id=&r=` | who put the emoji r on the message, for whoever may read its channel: `names`, the first 20 by the alphabet, and `more`, how many members beyond them |
| `POST /api/pin` | id |
| `GET /api/commands` | the slash commands, for suggestions: name, usage (how it is typed, ` - `, a sentence) and anywhere (it needs no channel, so it also works in a private conversation) |

A message may answer another: `re` of `POST /api/post` names a message
still there, of the same channel for a message in the channel, of the same
thread (its first message or a reply) for a reply; anything else is
refused with 404. Wherever messages are given, one that answers another
carries `re`: `id`, `gone` (the answered message was deleted since), and
unless it is gone `from` (its author) and `text` (how it starts, at most
140 bytes of plain text; a file's name when it has no words), as they are
when the messages are read. A private message's `re` has the same `id`,
`from` and `text`, written by its sender (see below).

An answer counts as a mention of the answered message's author, and a
reply in a thread as a mention of the member who started the thread, as
if the message named them with `@`: the room's `mentions` count, the
message's `mentions_me`, the push, the mail about missed messages. The
same things turn it off: the channel's `notify`, ignoring the sender.
Nobody is told of their own message, a bot is not, and neither is a member
who can no longer read the channel. A thread's other repliers are not
told: only its starter, and whoever the reply answers or names.

A reaction is an emoji, sent and answered as its text (it used to be a
number, 0 to 5). The site offers two lists of them, which its admin
changes under **Settings**, group **Reactions**, and which `GET /api/me`
gives a member as `reactions`: `shown`, the few a client shows at once,
and `more`, the rest. Putting one on takes an emoji from those lists, or
the answer is 400; taking one's own back works for any emoji, so one the
site has stopped offering still shows under its message and still comes
off. A message's `reactions` is a list of `r` (the emoji), `n` (how many
members) and `mine`. The names are not sent with it: a client asks
`/api/reacted` when someone wants to see them.

A message has `id, room, parent, uid, name, avatar, badge, at, edited,
deleted, pinned, replies, last_reply, rev, mentions_me, ignored, body,
html, reactions, files`, and `preview` when the first web link in it has
been looked at: `url, title, description, image, site` (the last three may
be empty). The server fetches the page after the message is posted or
edited and then gives the message a new `rev`, so it comes through the
usual refresh a moment later; a page is kept by address for a week. Show
it folded to one line and load the picture only when a reader opens it.
The admin setting `link_previews` turns the fetching off. `html` is made on the server with members' own
HTML escaped; `body` is what they typed (Markdown).

Slash commands are posted like messages: `/join`, `/part`, `/away`,
`/back`, `/whois`, `/names`, `/invite`, `/kick`, `/op`, `/deop`, `/mute`,
`/unmute`, `/ban`, `/unban`, `/ignore`, `/unignore`, `/topic`, `/me`,
`/help`, plus any that units added on top register. `/msg` is the
client's job: it picks plain or locked for the conversation. `/help name`
answers with that one command's line. A line whose first word is no
command (`/usr/local/bin`, `/shrug`) is an ordinary message, posted as it
is. A command's answer comes in the language of the request.

In a private conversation the client decides, since the words may be
sealed. Words that begin with `/me ` are sent as the message they are and
shown as an action, the sender's name and then the words, by whoever
shows them (the `html` of an unlocked one already reads so, and IRC gets
an ACTION). Another line whose first word is a command of
`GET /api/commands` goes to `POST /api/post` with no `room`, and `info`
answers the member alone: a command marked `anywhere` runs, any other is
said to be for channels. Nothing is posted without a room. A line that
names no command is an ordinary message, sent as any other. A summary of
a message (a notification, a quote of it) gives an action as it is shown:
`Ann waves`, never the `/me`.

## Files

`POST /api/upload` (multipart: file, expire = hour, day, week, once or
empty, sealed = 1 for an encrypted private file, avatar = 1). Answers a
token to send in `files` with the message. Files download from
`/f/<token>/<name>`. A file in a message goes to whoever may read that
message: anyone for a public channel or a bench, the members of a private
channel, the two members of a private conversation. Until it is in a
message it goes to its sender only. Send the token or the cookie with the
download; anyone else gets 404. Avatars and channel icons are open to all.

With the admin setting `scan_files` on, every upload is scanned with
ClamAV before it is kept, the wiki's and the forum's too. A sealed file
is scanned as well, though the scanner sees only its encrypted bytes: the
server cannot tell a real one from a plain file marked sealed. A sealed
file can only be sent with a locked private message, and downloads only
as `application/octet-stream`. A
finding answers `422` with the words to show. A scanner that cannot run
answers `503` when `scan_unavailable=refuse`, and the file is kept when
it is `allow`.

## Private messages

Encrypted on the device. Each member has an ECDH P-256 key pair; the
public half is on the server (`GET /api/key?name=`), the private half
only wrapped. The key between two members is HKDF-SHA256 over their ECDH
secret (salt 32 zero bytes, info `beginend private message`), used with
AES-GCM; the additional data is `from>to`, both stable key names in lowercase.
Use `key_name` from `/api/me` and `/api/key?name=` for those identities, and
`from_key_name` from each message when opening it. These names stay fixed
when an account is renamed, so old locked messages remain readable. On a
server without these fields, use the displayed names.

| Request | Notes |
|---|---|
| `GET /api/dm?with=&after=&before=` | the newest 100 at first, then newer than `after` or older than `before` |
| `POST /api/dm` | to, iv, data, files (sealed uploads) |
| `POST /api/dm/delete` | `with`: this member's copy of the whole conversation goes, the other keeps theirs. `id`: one message this member sent goes from both sides, with its files; both members get the ring `{"t":"dm","from":name,"deleted":id}`. |
| `POST /api/dm/edit` | id, data, and iv when the conversation is locked: one of the member's own messages, written again; both members get the ring `{"t":"dm","from":name,"edited":id}` |
| `POST /api/dm/react` | id, r (an emoji, as for `/api/react`): puts the member's reaction on the message, or takes it off; either side may, locked or not; both get the `edited` ring |
| `GET /api/dm/reacted?id=&r=` | who put the emoji r on the message, `names` and `more` as `/api/reacted` gives them; for the two members of the conversation |
| `GET /api/dm/search?with=&q=` | the unlocked messages of the conversation that hold the words, the newest 100; locked messages are never searched |
| `POST /api/beam`, `GET /api/beam`, `POST /api/beam/answer`, `GET /api/ice` | a file sent browser to browser over WebRTC |

Each message of `GET /api/dm` carries `reactions` (a list of `r`, `n` and
`mine`, as on a channel message). An unlocked message (`iv` empty) also
carries `html`, its `text` shaped by the server exactly as a channel
message is (Markdown, colored code, names and channels linked), and
`preview` when its first link has one. A locked message has neither: the
server cannot read it, so a client shapes its text itself.

Reading: `GET /api/dm` marks what it returns as read, unless it is asked
with `peek=1` (a page nobody is looking at); `read=id` says the member has
now seen everything up to that message.

Read receipts: where they apply, each conversation in `dms` of `/api/sync`
carries `seen`, the id up to which the other member has read, so the
newest of one's own messages at or below it is the last one they read. The
ring `dmseen` brings a new value live. `dms` holds the 40 newest
conversations; `GET /api/key?name=` carries the same `seen` for the
conversation with that member, however old, under the same rule. The site's setting "Private
conversations: read receipts" says who has them: `off` nobody, `always`
everybody, or each member as they choose (`members choose (on)`,
the default, and `members choose (off)`). Where members choose,
`/api/me` carries `read_receipts` (true or false, this member's choice or
the site's start) and `POST /api/dm/receipts` (on: 1 or 0) sets it. The
rule goes both ways: a member with receipts off does not show their
reading and does not see anyone else's, so `seen` is there only between two
members who both have them on. It is never given to a member the reader
ignores, and where it does not apply the field and the ring do not exist.
Locked conversations have them too: the server knows which message was
read, not what it says.

A message's JSON (`data`, sealed or not) may hold `re`, the message it
answers: `id`, `from` and `text` (its first 140 characters). The sender
wrote it, so show it as text and trust none of it.

## Wiki pages and files

`GET /wiki/<name>` reads a page. Options are `edit=1`, `history=1`
(200 revisions at a time, `from=N` continues downward), `rev=N` and
`diff=N` against the preceding revision. `POST` saves `body`, `summary`
and `base`, reverts with `rev`, changes `locked`, or previews with
`preview=1`. Saving requires `wiki-edit`; locked pages need `wiki-lock`.
`GET /wiki-pages?from=name` lists up to 500 pages; `/wiki-category/<name>`,
`/wiki-changes` and `/wiki-search?q=` browse categories, changes and search.
JSON equivalents are `GET /api/wiki?slug=`, `/api/wiki/changes`,
`/api/wiki/search?q=`, `/api/wiki/pages?from=` and `/api/wiki/categories`.
`POST /api/wiki/save` takes `slug`, `title`, `body`, `summary` and `base`.

`GET /api/wiki/emoji` gives the set's emoji, names, groups, keywords and
pictures. `GET /wiki-emoji/<file>` serves a picture. Saving needs
`wiki-emoji`: `POST /api/wiki/emoji/save` takes `chars`, `name`, `keywords`,
`drawn`, `svg`, `plain` (restore the default picture) and `add=1` for a
new entry. SVG pictures are checked for executable or external content.

## The reply that solved a topic, and names in forum posts

`POST /api/forum/solved` takes `post` and `on` (1 or 0). Who started the
topic, or a forum moderator, marks the reply that solved it. A topic has
one such reply: marking another moves the mark, `on=0` takes it off. The
first post cannot be marked. `GET /api/forum/topic?id=` gives the topic's
`solved_post` (0 for none) and `may_solve` for the member asking, and the
topic lists carry `solved_post` too. Hiding or deleting the marked reply
takes the mark off.

`@name` in a post links to that member, and the member gets a notice
(`GET /api/notices`, kind `forum-mention`, with a link to the post) when
they may read the post. One notice stands for a topic, the newest, and
reading the topic marks it seen. A post tells ten members at most, and a
changed post tells only who it names anew. `#name` links to the chat's
public channel of that name on a site with the chat on.

## Reactions on forum posts

| | |
|---|---|
| `POST /api/forum/react` | post, r (an emoji): puts the member's reaction on the post, or takes it off. Answers `id` and the post's `reactions` as they are then |
| `GET /api/forum/reacted?post=&r=` | who put the emoji r on the post: `names` and `more`, as `/api/reacted` gives them |

Each post of `GET /api/forum/topic?id=` carries `reactions`, a list of
`r`, `n` and `mine` as on a chat message.

Whoever may post in the forum may react to any post they can read, their
own too. The emoji are the site's two lists less the ones the forum
leaves out (**Settings**, group **Forum**); another is answered 400.
One's own comes off whatever it is. On a locked topic only a moderator
puts one on, and nobody does on a hidden post or topic (403); a member
stopped from posting does neither. The names are for whoever may read the
post, a visitor too where the board is open to visitors. A reaction is
not a post: the topic's last post, its place on the board and what
members have not read stay as they were. Posts deleted for good take
their reactions with them.

## Following a forum topic

| | |
|---|---|
| `POST /api/forum/follow` | topic_id, value (1 follows, 0 stops): answers `following`. With `all=1` in their place, stops following every topic |
| `GET /api/forum/following?page=` | the topics the member follows, last posted in first: `topics` as a board lists them, and `has_more` |

For a member signed in, the `topic` of `GET /api/forum/topic?id=` carries
`following`, true or false.

A member follows a topic from the moment they start it or reply in it
(their preference `forum_follow_posts`, on at first), or when they ask
to. Stopping is remembered for that topic: writing in it again does not
follow it again, asking does. Only a topic the member may read can be
followed (404 otherwise).

When someone else replies, each follower who may read the reply gets a
notice, one for a topic, the newest reply's (`GET /api/notices`, kind
`forum`, with a link to the post); reading the topic marks it seen. On a
site with mail, a follower with a confirmed address also gets a mail,
unless they turned it off (preference `forum_reply_mail`): one for a
topic, and no more about it until they have read it. Nothing is told
about a hidden post or topic, a board the follower may not read, a reply
from a member they ignore, or to a banned member.

The same form sent to `POST /forum/follow` answers with a redirect to
the topic's page (with `page`), or to `/forum/following` (with `list=1`
or `all=1`): it is what the Follow button sends from a browser without
scripts.

Each mail carries two links that need no sign-in:
`/forum/mail-off/<key>` stops following the topic and
`/forum/mail-off/<key>/all` turns the forum's mail off for the member. A
GET shows a page that asks; only a POST to the same address does it, as
a mail program's one-click unsubscribe sends (the mail names the first
in `List-Unsubscribe`).

## Members

`GET /api/users?q=` (names starting with q), `GET /api/user?name=`,
`POST /api/profile` (bio, links), `POST /api/ignore` (name, on).

Also for a member's own account: `POST /api/keys` (the keys of an account
that has none yet, as one made by signing in with a provider),
`POST /api/prefs` (mail_notes, auto_away, and any preference `GET
/api/me` lists in `prefs`, by its `name`, as 1 or 0), `POST /api/verify` (asks for
the confirming mail again; with `email`, to another address while the
first is unconfirmed), `GET /api/notes` (the latest unread mentions and
private messages, each with its words on one line, Markdown left out; 401
with nobody signed in, at which the service worker ends the device's pushes) and
`POST /api/bug` (text, page, info: "Report a problem").

A new password, from the member who knows the old one: `POST
/api/password` with `current` (the login secret of the old password),
`auth` (the new one's) and `wrapped` (the same private key, wrapped with
the new password's key), and `pub` from an account that had no keys.
Every sign-in of the account ends, apps and bots too; the answer signs
this one in again (a cookie, or `token` when `app` was sent). An account
with no password yet sets its first with `POST /api/keys`.

Another email address: `POST /api/email` with `email` and, when the
account has a password, `current` as above. On a site with mail, a link
goes to the new address and the account keeps the old one until it is
opened; without mail the address is saved as given. An address another
account uses is refused.

Closing the account: `POST /api/close` with `current` as above, or, from
an account with no password, `name` (the account's own name, typed out);
`anonymous=1` leaves the name behind too. An account is closed, never
deleted: nobody signs in to it again, its address, password, keys,
picture and profile are wiped, and what the member wrote stays. `GET
/api/user` then answers `closed: true` with no `joined`, `seen` or
`posts`, and a forum post's author carries `former: true`; `GET
/api/users` leaves closed accounts out. The name stays taken. Left
without a name, the account is called `Former member` and its number.
The site's only admin cannot close their account.

A name a member had before a rename stays theirs: nobody else can take
it, and `/u/<old name>` leads to the present profile, unless the account
was closed without a name.

A locked conversation: `POST /api/dm/lock` (with, on) turns the lock on or
off for both; `POST /api/dm/typing` (to) tells the other side. The rings
`dmtyping` and `gone` go with them.

Notifications to a closed page (Web Push): `GET /api/push/key` is the
server's public key, `POST /api/push` (endpoint, p256dh, auth; `off=1` to
stop) keeps the browser's subscription.

## Benches and the corner chat

A bench is a channel of kind `bench` that belongs to one page.

| | |
|---|---|
| `GET /api/live` | plain JSON, no sign-in needed: the latest public messages on the site, `here` (how many are present) and `talk` (the open channel). With `room=slug`, the latest in one public channel or bench. Readable from any site. (The same address asked as a WebSocket is the live connection above.) |
| `POST /page-bench` | kind, key: opens the bench for a page of this site (`wiki` and a page's name, or a kind a module registered). Answers `room` and `url`. Needs the permission `add-bench`. |
| `GET /api/embed/page?url=` | which bench a page of another site has: `room` (empty for none), `title`, `talk`. Readable from any site. |
| `GET /embed/bench?url=` | in a browser: goes to the bench that page has. When it has none, sends a visitor to sign in and shows a member a button that opens it. |
| `POST /embed/bench` | url: opens the bench for that page, after the site has read the page and found the script line on it, and goes to it. Needs the permission `add-bench`. |
| `GET /embed.js` | the script another site puts on its pages. |

## The catalog

| | |
|---|---|
| `GET /api/catalog?q=&category=&sort=&page=` | the list as JSON, with the filters the catalog's page has. An entry's `picture` is the address of the picture an admin gave it, or empty. |
| `GET /api/catalog/<id>/readme` | an entry's README as it was read |
| `POST /api/catalog/import` | a JSON array of up to 500 entries, 2 MB at most; needs the permission `catalog-import`. Each has `entry_key` (where it lives, without `https://`) and `name`, and may have `title`, `summary`, `url`, `forge`, `owner`, `kind`, `categories`, `license`, `stars`, `forks`, `created`, `pushed`, `archived`, `release_name`, `released`, `topics`, `download_url`, `version`, `authors`, `sources`. An entry with a key already there is brought up to date; what an admin changed by hand stays. |
| `POST /api/catalog/readme` | a JSON array of `entry_key`, `readme`, `readme_url`, `image`; same permission |
| `POST /api/catalog/icons` | a JSON array of `entry_key`, `icon`; same permission |
| `POST /api/admin/catalog/add` | `title`, and any of `url`, `summary`, `kind`, `categories`, `license`: one entry put in by hand. Answers its `id`. Needs the permission `edit-catalog`. |
| `POST /api/admin/catalog/save` | `id`, and what changes of `title`, `url`, `summary`, `kind`, `categories`, `license`; same permission. A `kind` is one of the kinds a site's own unit registered, or, where none are registered, any word up to 20 characters. |
| `POST /api/admin/catalog/picture` | `id` and `file` (a form with a file: PNG, JPEG, GIF or WebP, as large as the setting `catalog_picture_mb` allows): the entry's picture, in place of the one it had. `id` and `remove=1` takes it away. Answers `picture`, its address. Same permission. An import carries no picture: one is sent for each entry here. |

## Searching the whole site

`GET /api/site-search?q=&in=&page=` asks every module that is on, as the
search page `/search` does. It needs no sign-in; signed in, a member also
finds what only they may read (a private channel they are in, a board for
members). Private conversations are not searched here.

- `q`: the words, two characters to `search_query_bytes` bytes, or the
  answer is 400.
- `in`: a module by name (`chat`, `wiki`, `forum`, `catalog`, or one a
  site's own unit registered) to search that one alone. Left out, or a
  module that is off or that the asker may not search: every module.
- `page`: with `in`, the page of that module's hits, 20 to a page, from 1.
  Without `in` each module gives its first 5.
- `engine`: `database` or `index`, to pick what answers this one request.
  It counts only for someone who holds `manage-settings`, on a site whose
  setting `search_engine` is `compare` or `index`. For everyone else it
  is ignored.

```json
{
  "q": "generics", "in": "", "page": 1,
  "groups": [
    {"module": "wiki", "caption": "Wiki", "more": true,
     "hits": [
       {"title": "Generic collections", "url": "/wiki/Generic_collections",
        "excerpt": "Using generics in Pascal...", "time": "",
        "author": "", "kind": "page"}
     ]}
  ]
}
```

A group is one module, in the order the page shows them, with its hits in
the order that module ranks them. `more` says the module has further
hits: ask again with `in` and the next `page`. In a hit, `url` is a path
on this site, `excerpt` is plain text (empty when the module has none),
`time` is ISO and UTC or empty, `author` a name or empty, and `kind` the
module's word for what was found (`message`, `page`, `topic`, `entry`).
A chat message's `title` is its channel, `#name`.

A site can answer from a search index it keeps itself (the setting
`search_engine`). A group answered that way may carry one of two more fields.
`showing_for` holds the words that were searched for when the index took
a word as misspelled, and `did_you_mean` holds words to offer in place of
the ones sent. For someone who holds `manage-settings` every group also
says what answered it, in `engine`: `index` or `database`. When the index
answers, `q` may hold a phrase in quotes, `OR` between words and a minus
in front of a word to leave it out.

Each module also keeps its own search, with choices this one does not
have: `/api/search` (one channel), `/api/wiki/search`, `/api/forum/search`
and `/api/catalog` (filters and sorts).

`GET /api/site-suggest?q=&in=` gives what the search box offers while
someone types, where the site's own index answers: `{"q": "tstr",
"offers": [{"text": "TStringList", "url": "/wiki/TStringList", "caption":
"Wiki"}, {"text": "tstringlist loadfromfile"}]}`. An offer with `url` is
a page to open, one without is words to search for. Eight at most, none
for fewer than two characters, and only from modules everyone may read.

## The desktop client

`GET /connect.exedra` answers a small text file (`[exedra]` with
`server=` and `name=`, and a client may add `channel=`) that the desktop
client opens: it adds the server to its list and signs in there.  Pass the
file on, or link to it.

## Running the site

`GET /api/admin` and the `POST /api/admin/...` requests behind the admin
page: settings, member, permission, role, channel. Each needs its own
permission; `GET /api/me` says which the member has.

`POST /api/admin/member` takes `name` and any of `roles`, `banned` (1 or
0), `rename` (a new name, by the rules a new account's name meets) and
`password_link=1`, which answers a link that sets a new password, good
once and for a week; `close=1` with `reason` closes the account (as
`POST /api/close` does, the name kept or not as the setting
`closed_names` says) and `reopen=1` opens it again, with no address and
no password, so a password link comes next. The ban needs `ban`, the
others `manage-members`; any of them but roles and the ban, for someone
on the staff, needs an admin. A closed account takes only `rename` and
`reopen`. After a rename the ring `names` goes to every open page. `GET
/api/admin/members?state=closed` lists the closed accounts, each with
`closed` (when), `closed_by` (the account's own name when its member
left) and `closed_reason`.

`GET /api/admin/scans` answers the virus scanner's state (`on`, `ready`,
`version`, `problem`, `last_error`) and the last 200 uploads it stopped or
could not check. `POST /api/admin/scans/test` scans the EICAR test file and
answers `caught`, `error` and the scanner's `words`. Both need
manage-settings.

`GET /api/admin/search` answers how the site's search index stands:
`engine` (the setting), `cgi` (true for the CGI program, which keeps no
index) and `parts`, one for each module that joined the index, with
`part`, `state` (`off`, `waiting`, `building`, `ready` or `failed`),
`documents`, `built` (when it was last built, ISO and UTC), `step` (how
far a build is), `queued` (changes waiting to go in), `refused` (hits the
index offered and the module did not show) and `problem` (why it failed).
It needs manage-settings.

Safety settings show their stored names on the admin page. The defaults
are `missing_tries=6` per minute (scanner paths count three),
`admin_probe_tries=3` per minute and `password_tries=10` in 15 minutes.
A wrong or expired token is held by its own limit (`token_tries`) and is
not a password try. A request the browser made on its own, a picture, a
link followed from a page or anything another site set off, counts for
nothing. The browser says which those are, so a program that says the same
is not counted either: the guard slows scanners down, it does not prove
there are none. Refused admin routes and unknown admin paths
both answer `404 Nothing here.`. From the third block on (`block_strikes=3`)
a block lasts `block_days`; `block_cache_max=10000` drops the oldest cached addresses
(hard cap 100,000). This machine's own address and `allowed_ips` are never
blocked. Every other address is, the house network's too. A proxy in front
has to be named under `proxies`, or every visitor looks like that one
address: the admin page says so when it sees one that is not named.
IPv6 spellings and mapped IPv4 addresses share counters.

`signuptry_address=10` caps signup attempts per minute across web, IRC and
external sign-in; `signups_per_address=10` caps completed accounts per day.
`signin_tries=10` caps web and IRC password checks together per minute.
`token_tries=30` caps token-link attempts per minute. `tokens_address=30`
and `tokens_member=10` cap token changes per minute. Server mode also has
`live_tries=30` live connection attempts per address per minute.

Transport defaults are `request_body_kb=64`, `request_headers=64`, an 8 KB
header line and `request_read_ms=30000` per socket read (at most 60,000).
Restart after changing transport limits. Uploads and artwork use
`upload_max_mb=5`, plus 64 KB of form overhead, within a 32 MB transport
cap. Layers register larger forms and address/member limits with SiteGuard.
Oversized bodies answer 413; unsupported methods answer 405.
`search_query_bytes=100` caps registered searches, which need two characters.
`search_address=30` and `search_member=30` cap the site's search per minute.
CGI checks announced sizes before reading; its host controls read deadlines
and the original header count. Rate limits also apply to exempt addresses.

### Visitor reports

`GET /api/admin/visitors/report?from=&to=&hide=me` reports a window of
whole days (`yyyy-mm-dd`) or UTC moments (`yyyy-mm-ddThh:mm:ssZ`).
`hide=me` omits the requesting address, private networks and addresses
where the admin signed in during the window. `GET
/api/admin/visitors/address?ip=&from=&to=` gives one address's requests,
browsers, members, pages, statuses, timeline and guard facts.

`GET /api/admin/catalog/activity?days=7&hide=1` groups Random entry and
Interesting activity by day, reader, entry and filter, with crawler
activity separate. `days=0` includes all retained steps; `hide=1` omits
the admin's steps and private addresses.

### Backups

Backups are ZIP files in `data/backups`; files placed there also appear
in the admin list. Each contains `database.sql` (the program's own SQL
dump), `manifest.json` (site, time, contents and table row counts),
`config/<ini>` (including credentials), `data/`, and optional registered
`pictures/<name>/` folders and `data/logs`. Keep backups as private as
the site's configuration.

| Request | Fields or result |
|---|---|
| `GET /api/admin/backup` | Kept backups and the running job |
| `POST /api/admin/backup/make` | `pictures=1`, `logs=1` include optional content |
| `POST /api/admin/backup/check` | `name`: starts an integrity check |
| `POST /api/admin/backup/restore` | `name`, `confirm=RESTORE`: starts restoring |
| `POST /api/admin/backup/delete` | `name` |
| `GET /api/admin/backup/file/<name>` | The backup file |
| `POST /api/admin/backup/chunk?name=&offset=&size=` | Raw upload piece, up to 8 MB; `size` marks the final piece |

Uploads append in order to `name.part`; the response's `have` allows a
retry to resume. The final length and ZIP format are checked before the
file is renamed. One background job runs at a time. Restore replaces
the included tables and data but preserves sessions and transient
counts; other requests are asked to return in a minute. Tables absent
from this build and their upgrade marks stay. A restored config is left
beside the backups for the admin, never installed automatically.

With the service stopped, run as its user:
`exedra site.ini --restore /path/to/site-backup.zip`, against an empty
database when moving a site. `--backup [--pictures] [--logs]` uses the
same jobs for scheduled backups. An external backup-copy script may
write `backup-status.json` beside the program for the admin page.

### Private channels and conversations

Both need the permission `manage-private` (admins only, unless a site
grants it). The list says who, when and how much, never what.

`GET /api/admin/private` answers:

```json
{
  "channels": [
    {"slug": "bitbroom", "title": "bitbroom", "owner": "name",
     "members": ["name", "name"], "messages": 12, "archived": false,
     "created": "2026-10-27T12:00:00Z", "last": "2026-11-01T09:30:00Z"}
  ],
  "conversations": [
    {"a": "name", "b": "name", "messages": 40, "locked": true,
     "last": "2026-11-02T21:15:00Z"}
  ]
}
```

`owner` may be empty and `last` may be null or empty for a channel nobody
has spoken in. A conversation both members have deleted is not listed. The
newest thousand conversations are listed.

`POST /api/admin/private/delete` deletes for good and answers a line to
show the person:

| Fields | What goes |
|---|---|
| `kind=channel`, `slug` | the private channel with its messages, threads, files and members. A public channel is refused. |
| `kind=conversation`, `a`, `b` | every message and file between the two, on both sides. A locked conversation stays locked if they talk again. |

After a channel is deleted its members get the ring `{"t": "gone", "room":
slug}`, and `GET /api/room` for it answers 404. After a
conversation is deleted both members get the ring `{"t": "dm", "from": name,
"gone": true}`.
