# Exedra Desktop

A native chat client for Exedra servers, for Linux, Windows and macOS,
written in Free Pascal with Lazarus. It signs in to any Exedra site and
talks to it only through the API in [docs/API.md](../docs/API.md); it
shares no code with the server.

## Building

You need Lazarus and Free Pascal, trunk of both, as for the server
([INSTALL.md](../INSTALL.md), "What you need"), and these packages:

```sh
git clone https://github.com/TonyStone31/InfoBarToast.git
git clone https://github.com/TonyStone31/FileAss.git
git clone https://github.com/TonyStone31/CrossDragDrop.git
git clone https://github.com/TonyStone31/LazInk.git
git clone https://github.com/Xor-el/TlsLib4Pascal.git
git clone https://github.com/Xor-el/CryptoLib4Pascal.git
git clone https://github.com/Xor-el/HashLib4Pascal.git
git clone https://github.com/Xor-el/SimpleBaseLib4Pascal.git
```

Tell Lazarus where they are, once:

```sh
lazbuild --add-package-link InfoBarToast/infobartoast.lpk
lazbuild --add-package-link FileAss/component/fileass_runtime.lpk
lazbuild --add-package-link CrossDragDrop/crossdragdrop.lpk
lazbuild --add-package-link LazInk/lazink.lpk
lazbuild --add-package-link HashLib4Pascal/HashLib/src/Packages/FPC/HashLib4PascalPackage.lpk
lazbuild --add-package-link SimpleBaseLib4Pascal/SimpleBaseLib/src/Packages/FPC/SimpleBaseLib4PascalPackage.lpk
lazbuild --add-package-link CryptoLib4Pascal/CryptoLib/src/Packages/FPC/CryptoLib4PascalPackage.lpk
for p in $(find TlsLib4Pascal -name '*.lpk' | grep -v -E 'Indy|Synapse|mORMot'); do
  lazbuild --add-package-link "$p"
done
```

Build, from the folder this repository was cloned into:

```sh
lazbuild --ws=gtk3 desktop/exedradesktop.lpi
```

That is for Linux, where it is built on GTK3 and needs the GTK3 libraries
(`libgtk-3-0` on Debian and Ubuntu; a desktop has them). On Windows and
macOS leave `--ws=gtk3` out. The program is `desktop/exedra-desktop`.

## Using it

Start it and give it your site's address and your sign-in. It is a chat
client: a site's wiki and forum open in the browser, and a site with the
chat turned off has nothing for it to show. A site's
admin can also hand out a connection file: `/connect.exedra` on the site
makes one, and opening it starts the client on that site.
