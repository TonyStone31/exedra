#!/bin/sh
# install.sh: puts a release of Exedra on this machine, or brings the one
# that is here up to date.  For Linux on x86_64 or 64-bit ARM, with systemd,
# and for FreeBSD on x86_64 (there as root, without sudo).
#
#   sudo sh install.sh              install the newest release into /opt/exedra
#                                   (on FreeBSD into /usr/local/exedra)
#   sudo sh install.sh update       the newest release over the one installed
#   sh install.sh check             says which release is here and which is newest
#
# Options, after the word:
#   --dir /some/folder    install there instead
#   --from file.tar.gz    use this release file instead of downloading one
#   --no-service          only the files: no user, no service, no start
#
# An update replaces the program and the page files (static, templates,
# lang).  exedra.ini and data/ are never touched, and the program it
# replaces is kept beside it as exedra.previous.  Make a backup first:
# the admin page, Backup, or `exedra --backup`.
set -eu

say() { echo "exedra: $*"; }
die() { echo "exedra: $*" >&2; exit 1; }

REPO=TonyStone31/exedra
case "$(uname -s)" in
  Linux) OS=linux; DIR=/opt/exedra ;;
  FreeBSD) OS=freebsd; DIR=/usr/local/exedra ;;
  *) die "the releases are for Linux and FreeBSD; on another system build from the source (INSTALL.md)" ;;
esac
case "$OS-$(uname -m)" in
  *-x86_64|*-amd64) CPU=x86_64 ;;
  linux-aarch64|linux-arm64) CPU=aarch64 ;;
  linux-*) die "the releases are for x86_64 and 64-bit ARM; on $(uname -m) build from the source (INSTALL.md)" ;;
  *) die "the FreeBSD release is for x86_64; on $(uname -m) build from the source (INSTALL.md)" ;;
esac
FROM=
SERVICE=1
WHAT=install

case "${1:-}" in
  install|update|check) WHAT=$1; shift ;;
esac
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR=$2; shift 2 ;;
    --from) FROM=$2; shift 2 ;;
    --no-service) SERVICE=0; shift ;;
    -h|--help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "install.sh: unknown option $1" >&2; exit 2 ;;
  esac
done

download() { # download <address> <file>
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then wget -q "$1" -O "$2"
  elif command -v fetch >/dev/null 2>&1; then fetch -q -o "$2" "$1"
  else die "curl or wget is needed to download a release"; fi
}
# the key the releases are signed with; its private half never leaves the maintainer
KEY='-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEvIghl8CKp04NwDUaYA0lLMvbNp8t
twEyFNcqpGj7NFQvgusyrCeQLxcoIje7M1fqrDtZouAi986pFzPZN8/JIg==
-----END PUBLIC KEY-----'
signed() { # signed <file> <signature>: whether the maintainer's key signed the file
  command -v openssl >/dev/null 2>&1 || die "openssl is needed to check the release's signature; install it and run this again"
  echo "$KEY" > "$TMP/release.pub"
  openssl dgst -sha256 -verify "$TMP/release.pub" -signature "$2" "$1" >/dev/null 2>&1
}
checksum() { # the SHA-256 of a file
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else sha256 -q "$1"; fi
}
# the service, by this system's own tool
service_runs() {
  if [ "$OS" = freebsd ]; then service exedra onestatus >/dev/null 2>&1
  else command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet exedra 2>/dev/null; fi
}
service_do() { # start or stop; on FreeBSD also one started by hand, not switched on in rc.conf
  if [ "$OS" = freebsd ]; then service exedra "one$1" >/dev/null; else systemctl "$1" exedra; fi
}
[ "$OS" = freebsd ] && START="service exedra start" || START="systemctl start exedra"

here=
[ -x "$DIR/exedra" ] && here=$("$DIR/exedra" --version 2>/dev/null | sed 's/^Exedra //') || true

newest() { # the newest release's name without its v, from GitHub
  download "https://api.github.com/repos/$REPO/releases/latest" "$TMP/latest.json" 2>/dev/null || return 0
  sed -n 's/.*"tag_name"[^"]*"v\{0,1\}\([^"]*\)".*/\1/p' "$TMP/latest.json" | head -n 1
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [ "$WHAT" = check ]; then
  say "installed in $DIR: ${here:-nothing}"
  version=$(newest)
  say "newest release: ${version:-none found (GitHub has no release, or cannot be reached)}"
  exit 0
fi

if [ "$WHAT" = update ] && [ -z "$here" ]; then
  die "nothing is installed in $DIR; run install.sh without a word to install"
fi
if [ "$WHAT" = install ] && [ -n "$here" ]; then
  die "Exedra $here is in $DIR already; run: install.sh update"
fi
if [ "$SERVICE" = 1 ] && [ "$(id -u)" != 0 ]; then
  die "run it as root (sudo sh install.sh), or add --no-service and --dir for files only"
fi

# the release file: named, or the newest from GitHub with its checksum
if [ -n "$FROM" ]; then
  [ -f "$FROM" ] || die "$FROM is not a file"
  cp "$FROM" "$TMP/release.tar.gz"
  # its checksum file beside it is checked when it is there
  if [ -f "$FROM.sha256" ]; then
    want=$(cut -d' ' -f1 "$FROM.sha256")
    have=$(checksum "$TMP/release.tar.gz")
    [ "$want" = "$have" ] || die "$FROM does not match $FROM.sha256; nothing was changed"
  fi
  # and its signature, the same way
  if [ -f "$FROM.sig" ]; then
    signed "$TMP/release.tar.gz" "$FROM.sig" || die "$FROM is not signed by Exedra's release key; nothing was changed"
  fi
else
  version=$(newest)
  [ -n "$version" ] || die "no release found: GitHub has none, or cannot be reached"
  if [ "$WHAT" = update ] && [ "$version" = "$here" ]; then
    say "$here is the newest release; nothing to do"
    exit 0
  fi
  name="exedra-$version-$OS-$CPU.tar.gz"
  say "downloading $name"
  download "https://github.com/$REPO/releases/download/v$version/$name" "$TMP/release.tar.gz"
  download "https://github.com/$REPO/releases/download/v$version/$name.sha256" "$TMP/release.sha256"
  want=$(cut -d' ' -f1 "$TMP/release.sha256")
  have=$(checksum "$TMP/release.tar.gz")
  [ "$want" = "$have" ] || die "the download does not match its checksum; nothing was changed"
  # the checksum comes from the same place as the file; the signature does not
  download "https://github.com/$REPO/releases/download/v$version/$name.sig" "$TMP/release.sig" || die "the release has no signature; nothing was changed"
  signed "$TMP/release.tar.gz" "$TMP/release.sig" || die "the download is not signed by Exedra's release key; nothing was changed"
fi

mkdir "$TMP/new"
tar -xzf "$TMP/release.tar.gz" -C "$TMP/new" --strip-components=1
[ -x "$TMP/new/exedra" ] && [ -d "$TMP/new/site/static" ] || die "that file is not an Exedra release"
# the version, read from its file: nothing downloaded runs before it is installed
new=$(cat "$TMP/new/VERSION" 2>/dev/null) || true
[ -n "$new" ] || new="the new version"

running=0
if [ "$SERVICE" = 1 ] && service_runs; then
  running=1
  say "stopping the service"
  service_do stop
fi

mkdir -p "$DIR"
[ -f "$DIR/exedra" ] && cp -p "$DIR/exedra" "$DIR/exedra.previous"
cp "$TMP/new/exedra" "$DIR/exedra.new" && mv "$DIR/exedra.new" "$DIR/exedra"
for part in static templates lang; do
  mkdir -p "$DIR/$part"
  cp -r "$TMP/new/site/$part/." "$DIR/$part/"
done
cp "$TMP/new/install.sh" "$DIR/install.sh" 2>/dev/null || true
[ -f "$TMP/new/exedra.ini.example" ] && cp "$TMP/new/exedra.ini.example" "$DIR/exedra.ini.example"
first=0
if [ ! -f "$DIR/exedra.ini" ]; then
  first=1
  # the example names /opt/exedra; a site somewhere else gets its own folder in it
  sed "s#/opt/exedra#$DIR#g" "$TMP/new/exedra.ini.example" > "$DIR/exedra.ini"
  chmod 600 "$DIR/exedra.ini"
fi

if [ "$SERVICE" = 1 ]; then
  if id exedra >/dev/null 2>&1; then :
  elif [ "$OS" = freebsd ]; then pw useradd exedra -d "$DIR" -s /usr/sbin/nologin -c Exedra
  else useradd --system --home "$DIR" --shell /usr/sbin/nologin exedra; fi
  # root owns the program and its pages; the service's user owns only what
  # it writes, and reads the config file through its group
  mkdir -p "$DIR/data" "$DIR/wiki-images"
  chown -R 0:0 "$DIR"
  chown -R exedra:exedra "$DIR/data" "$DIR/wiki-images"
  chown 0:exedra "$DIR/exedra.ini"
  chmod 640 "$DIR/exedra.ini"
  if [ "$OS" = freebsd ]; then
    # the rc.d script, switched on in rc.conf
    if [ ! -f /usr/local/etc/rc.d/exedra ]; then
      sed "s#/usr/local/exedra#$DIR#g" "$TMP/new/exedra.rc" > /usr/local/etc/rc.d/exedra
      chmod 555 /usr/local/etc/rc.d/exedra
      sysrc exedra_enable=YES >/dev/null
    fi
  elif command -v systemctl >/dev/null 2>&1; then
    if [ ! -f /etc/systemd/system/exedra.service ]; then
      sed "s#/opt/exedra#$DIR#g" "$TMP/new/exedra.service" > /etc/systemd/system/exedra.service
      systemctl daemon-reload
      systemctl enable exedra >/dev/null 2>&1 || true
    fi
  fi
  if [ "$running" = 1 ]; then
    service_do start
    say "the service is running again"
  fi
fi

# the database it starts with is SQLite, whose library is not on every machine
if ! grep -q '^server=sqlite' "$DIR/exedra.ini" 2>/dev/null; then :
elif [ "$OS" = freebsd ]; then
  [ -e /usr/local/lib/libsqlite3.so.0 ] || say "the SQLite library is missing; install it before starting: pkg install sqlite3"
elif command -v ldconfig >/dev/null 2>&1 && ! ldconfig -p 2>/dev/null | grep -q 'libsqlite3\.so\.0'; then
  say "the SQLite library is missing; install it before starting:"
  say "  Debian, Ubuntu: apt install libsqlite3-0     Fedora, RHEL: dnf install sqlite-libs"
fi

if [ "$first" = 1 ]; then
  say "Exedra $new is in $DIR."
  say "Next: read $DIR/exedra.ini (the site's name, its address, the port), then"
  if [ "$SERVICE" = 1 ]; then say "  $START"; else say "  $DIR/exedra $DIR/exedra.ini"; fi
  say "Open the site, sign up, and make yourself the admin:"
  say "  $DIR/exedra $DIR/exedra.ini --admin YourName"
  say "INSTALL.md has the rest (a proxy for TLS, mail, backups):"
  say "  https://github.com/TonyStone31/exedra/blob/main/INSTALL.md"
else
  say "updated ${here:-the files} to $new in $DIR (the program before is exedra.previous)"
fi
