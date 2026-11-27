# Security

If you find a security problem in Exedra, please report it privately so
it can be fixed before it is public.

## How to report

Use GitHub's private reporting: on this repository open the **Security**
tab and press **Report a vulnerability**. Only the maintainer sees the
report.

Please do not open a public issue or post about it on a forum or in a
chat until a fix is out.

A good report says:

- what the problem is and what someone could do with it,
- how to make it happen, step by step, on a site you run yourself,
- the version (the admin page shows it, or `exedra --version`) and the
  database you use.

Please test only on your own installation. Do not try things out on
pascal.chat or on anyone else's site.

## What to expect

Exedra is a small project with one maintainer. You should hear back
within a few days. A real problem gets fixed in a new release as soon as
a tested fix is ready, and the release notes say what was fixed and thank
whoever reported it, unless you would rather not be named.

## Which versions get fixes

The newest release. Update with `install.sh update` (INSTALL.md says
how).

## What Exedra does to stay safe

INSTALL.md and the README describe it: in the browser the password never
leaves the member's device, private conversations are encrypted end to
end, a guard
watches for scanners and password guessing, uploads can be scanned for
viruses, and every form is refused when it comes from another site. If
you run a site, put it behind a proxy with TLS and keep backups.

## What the encryption does and does not cover

A locked private conversation is encrypted in the two members' browsers,
and the server stores only what it cannot read. Two things are worth
knowing before you rely on it.

- The server hands out the members' public keys and the page's own
  scripts. Someone who controls the server could hand out a key or a
  script of their own. To catch a swapped key, each locked conversation
  shows a safety code. Both members see the same code, and can compare
  it some other way, by a call or in person. The code is made from the
  other member's key and your own, and your browser checks that the one
  given out as yours really is yours, so a key swapped on either side
  shows as a different code. The browser also remembers
  the key it saw for each member and warns when another one comes, which
  happens after a password reset. It writes nothing to the new key until
  you have seen that warning. Nothing can catch a changed script, so
  the people who run the site are trusted not to do that. This is true
  of every web page that encrypts in the browser.
- The password stays on the member's device in the browser and in the
  desktop program. An IRC client sends it to the server, because that is
  how IRC signs in. Offer IRC on its TLS port only, and keep the plain
  port for a proxy or a private network.

A member who renames their account keeps the first name inside their
password and key data, so the first name can still be found from the new
one. An account closed as "Former member" loses it.
