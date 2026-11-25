# Writing on the wiki

Pages here are written in Markdown, the kind GitHub uses (GitHub Flavored
Markdown), plus four things from wikis: links to pages, pictures,
categories and redirects. What you type is kept exactly as you typed it.
Readers get a web page made from it.

The first part of this page says how to start and change pages. The
second part, [[#Formatting|Formatting]], is the full reference for what
you can write. Anyone writing a tool or a converter for this wiki can
work from it.

## Starting a page

You need to be signed in. Then any of these opens the editor for a new
page:

- **New page** in the bar at the top. Type the page's name and press
  *Start writing*.
- A red link. Red means nobody has written that page yet. Following it
  offers *Start this page*.
- A search that finds nothing offers *Write the page*.
- In the chat, `/wiki Page Name` finds a page or starts it.

Search first. The page you want may already be there under another name.

### Page names

- Spaces are fine. In the page's address they become underscores, so
  *Getting Started* lives at `/wiki/Getting_Started`.
- The first letter becomes a capital. Capitals do not make a different
  page: *Getting started* and *Getting Started* are the same page.
- Letters in any language, digits and these marks are kept:
  `_ - . ( ) , ! ' + / $ @ : ^ ; & * =`. Anything else is left out.
- A name has 180 characters at most.
- A page in another language adds the language's code after a slash:
  *Getting Started/de* is the German page. The language bar at the top
  of a page lists the pages it has in other languages.

## Changing a page

Press **Edit** among the page's links to change all of it, or the small
**Edit** beside a heading to change that section alone. The editor shows
your text on the left and the page as readers will see it on the right
(on a phone, under its own tab). Its toolbar writes the Markdown for you,
and you can paste or drop a picture into the text. The button at the
right end of the bar gives the editor the whole window.

- **What changed** is a few words for the page's history, such as
  *fixed the install steps for Windows*.
- **Preview** shows the page without saving it.
- If someone saved the page while you were writing, your save is
  refused and your text stays in the editor. Open the page again in
  another tab and put your change into the new text.
- A locked page can only be changed by a moderator.

### History

**History** lists every saved version of a page, who saved it and when.
You can open any version, compare it with the one before, and bring an
old version back. Bringing one back saves it as a new version, so
nothing in the history is ever lost.

### Moving a page

**Move** gives a page a new name. The old name stays as a redirect, so
links and bookmarks to it still work. The page keeps its history.

### Deleting a page

Moderators can **Delete** a page, with a reason. Its history is kept. At
the page's address a moderator sees *Bring it back*, which puts the page
back as it was.

### Finding what needs work

- **What links here**, at the foot of every page, lists the pages that
  link to it.
- [Wanted pages](/wiki-wanted) are pages other pages link to that nobody
  has written yet.
- [Pages nobody links to](/wiki-orphans) are found only by searching. A
  link from a page on the same subject helps readers find them.

## Formatting

Everything GitHub Flavored Markdown has works here, with the exceptions
listed under [[#What is different|What is different]]. The four wiki
additions come after it.

### Text

| You write | Readers see |
|---|---|
| `**bold**` | **bold** |
| `*italic*` | *italic* |
| `` `code` `` | `code` |
| `~~struck out~~` | ~~struck out~~ |
| `[words](https://example.com)` | [words](https://example.com) |
| `https://example.com` | https://example.com |

A line that ends with a backslash `\` breaks there. A blank line starts a
new paragraph.

### Headings

```markdown
## A section
### A part of a section
```

Do not use a single `#`: the page's name is its title already. Sections
get an address of their own: *A section* is `#A_section`, the words with
underscores for spaces.

### Lists

```markdown
- one thing
- another
  - a thing under it

1. first step
2. second step
```

### Code

Put code between lines of three backticks and name its language, and it
is colored:

````markdown
```pascal
procedure Hello;
begin
  WriteLn('Hello');
end;
```
````

```pascal
procedure Hello;
begin
  WriteLn('Hello');
end;
```

Languages that are colored: `pascal` (also `pas`, `pp`, `lpr`, `dpr`,
`fpc`, `lazarus`, `freepascal`, `delphi`), `lfm`, `ada`, `asm`, `barye`,
`bash` (also `sh`, `shell`, `console`), `basic`, `batch`, `c`, `cpp`,
`csharp`, `css`, `d`, `diff`, `dockerfile`, `fortran`, `go`, `html`,
`ini`, `java`, `javascript`, `json`, `kotlin`, `lua`, `makefile`,
`markdown` (also `md`),
`modula-2`, `oberon`, `perl`, `php`, `powershell`, `python`,
`rst` (also `restructuredtext`), `ruby`,
`rust`, `sql`, `swift`, `toml`, `typescript`, `xml` (also `lpi`, `lpk`),
`yaml` and `zig`. A block with no language is colored as Pascal. Any
other name shows the code plainly. Nothing inside code is read as
formatting: `[[brackets]]` in code stay as they are.

### Quotes, tables and lines

```markdown
> A quote.

| Name | What it is |
|------|------------|
| TButton | a push button |

---
```

> A quote.

| Name | What it is |
|------|------------|
| TButton | a push button |

A table cell can say how well a thing works with an emoji: the site
draws its own picture for the emoji below, so a table reads the same on
every computer.

```markdown
| Feature | Linux | Windows | macOS | Haiku |
|---|---|---|---|---|
| Stepping | :yes: Y | :yes: Y | :partly: since 2.2 | :unknown: ? |
| Attach | :yes: Y | :no: N | :no: N | :unknown: ? |
```

| Feature | Linux | Windows | macOS | Haiku |
|---|---|---|---|---|
| Stepping | ✅ Y | ✅ Y | 🟡 since 2.2 | ❔ ? |
| Attach | ✅ Y | ❌ N | ❌ N | ❔ ? |

### Emoji

Paste an emoji, choose one with the editor's emoji button, or type its
keyword between colons: `:yes:`. In the editor a list of matches opens
as you type `:ye`; Enter or Tab takes the first. When the page is saved
each keyword becomes its emoji, so the page's text is plain Markdown
that shows the same emoji anywhere. Keywords in code and in addresses
stay as written.

{{emoji-table}}

Other emoji work too. They show as the reader's computer draws them.

### Links to pages

| You write | It links to |
|---|---|
| `[[Getting Started]]` | the page, its name as the words |
| `[[Getting Started|the tutorial]]` | the page, with your words |
| `[[Getting Started#Installing]]` | a section of the page |
| `[[#Installing]]` | a section of this same page |

- The page's name follows the rules of [[#Page names|Page names]], so
  `[[getting started]]` and `[[Getting_Started]]` both work.
- The words after `|` may hold formatting: ``[[Pointer|`pointer`]]``.
- A link stays on one line. The page's name cannot hold `[` or `]`.
- A link to a page nobody has written is red: [[A page nobody wrote]].
- Inside a table, write the `|` of a link as it is. It does not split
  the cell.
- Markdown links work too: `[words](/wiki/Getting_Started)`.

Two more kinds work:

- `[[https://example.com some words]]` links to another site. Write
  `[some words](https://example.com)` for new links.
- `[[wikipedia:Unicode]]` links to that article on Wikipedia.

### Pictures

Upload a picture with the editor's picture button, or paste or drop it
into the text. Then:

```markdown
[[File:Main window.png]]
[[File:Main window.png|thumb|300px|The main window after its first start]]
```

The parts after the name, each after a `|`:

| Part | What it does |
|---|---|
| `thumb` or `thumbnail` | a framed picture beside the text, with its caption |
| `frame` | framed, at its own size |
| `frameless` | no frame |
| `left`, `right`, `center`, `none` | where it sits |
| `300px`, `x200px`, `300x200px` | its width, its height, or both |
| `alt=words` | what a reader who cannot see it is told |
| `link=Page or address` | where clicking it goes |
| anything else | the caption, as plain text |

`[[Image:...]]` is the same as `[[File:...]]`. `[[:File:Main window.png]]`,
with a colon first, links to the picture's own page instead of showing it.
All pictures are listed under [Images](/wiki-files). Pictures from other
sites are not shown: upload them here.

### Categories

Lines at the very end of a page that start with `Category:` put the page
in those categories:

```markdown
Category:Tutorials
Category:Screenshots
```

- Only the lines at the end count. The same line in the middle of a page
  is ordinary text.
- One category on each line. Blank lines between them are fine.
- A page has 50 categories at most, and a category's name 200 characters
  at most.
- The categories show at the foot of the page, and each lists its pages.

### Redirects

A page whose first line is

```markdown
#REDIRECT [[Other Page]]
```

sends its readers to *Other Page*. Capitals do not matter in `#REDIRECT`.
A section or words in the link are ignored. A page cannot redirect to
itself, and a redirect to another redirect stops at the second page
rather than going around in circles. To see the redirect page itself,
add `?redirect=no` to its address.

### Mentions

`@name` links to a member, and `#room` to a chat room, when they exist.

### What is different

- HTML in the text is shown as text, not used. Everything a page needs
  has a Markdown way to write it.
- Inside `~~struck out~~` text, formatting and links are not read: they
  show as written.
- Task lists (`- [ ]` and `- [x]`) show their brackets as typed, not as
  boxes.
- Pictures from other sites are not shown (see [[#Pictures|Pictures]]).
- A Markdown link goes to a web address (`https://`, `http://`), an
  email address (`mailto:`) or a page of this site (`/...`). For a
  section of the same page, write `[[#Section]]`.
- A page has a size limit: 500 KB of text, unless this site set another.

## For tools

The Markdown is the page. Anything that reads or writes it should keep it
as it is.

- `GET /api/wiki?slug=Page_Name` answers the page as JSON: `slug`,
  `title`, `body` (the Markdown), `html`, `rev` and more.
- `POST /api/wiki/save` with `slug`, `title`, `body`, `summary` and `base`
  saves a page as a signed-in member. `base` is the `rev` the change was
  made from (0 for a new page), so a save made from an older version is
  refused instead of overwriting someone's change.
- `GET /api/wiki/search?q=words` searches, and `GET /api/wiki/changes`
  lists recent changes.
