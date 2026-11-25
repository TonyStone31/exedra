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

INSTALL.md and the README describe it: the password never leaves the
member's device, private conversations are encrypted end to end, a guard
watches for scanners and password guessing, uploads can be scanned for
viruses, and every form is refused when it comes from another site. If
you run a site, put it behind a proxy with TLS and keep backups.
