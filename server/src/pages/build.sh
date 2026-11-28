#!/usr/bin/env bash
# Compile the page units and compare their checked-in JavaScript with check.
# PAS2JS_SOURCE names the pinned checkout; PAS2JS_RTL names rtl.js.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
static="$here/../../site/static"
# scripts.list names each page script and the size of the file it replaced.
mapfile -t scripts < <(tr ' ' ':' < "$here/scripts.list")
mode=${1:-build}
case "$mode" in build|check) ;; *) echo 'usage: build.sh [build|check]' >&2; exit 2;; esac
: "${PAS2JS_SOURCE:?Set PAS2JS_SOURCE to the pas2js source checkout}"
: "${PAS2JS_RTL:?Set PAS2JS_RTL to rtl.js}"
compiler=${PAS2JS:-pas2js}
expected=${PAS2JS_COMMIT:-729049300a9286dde3a5a50dd4a44fdc670b4789}
actual=$(git -C "$PAS2JS_SOURCE" rev-parse HEAD)
[ "$actual" = "$expected" ] || { echo "pas2js source: expected $expected, found $actual" >&2; exit 1; }
[ -z "$(git -C "$PAS2JS_SOURCE" status --porcelain -- packages/rtl/src)" ] || { echo 'pas2js RTL source has local changes' >&2; exit 1; }
[ "$("$compiler" -iV)" = 3.3.1 ] || { echo 'pas2js 3.3.1 is required' >&2; exit 1; }
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
# Every page unit is compiled as one program, so what no page uses is left out (smart linking),
# and the result is cut into the shared runtime and one file per script.  The units are copied
# under their unit names: a program's "uses X in 'file'" with a hyphen in the file name stops pas2js.
mkdir "$out/src" "$out/units"
for source in "$here"/*.pas; do
  unit=$(grep -m1 -i -E '^unit +[A-Za-z_0-9]+ *;' "$source" | sed -E 's/^[Uu][Nn][Ii][Tt] +([A-Za-z_0-9]+).*/\1/')
  cp "$source" "$out/src/${unit,,}.pas"
done
uses=$(for entry in "${scripts[@]}"; do grep -m1 -i -E '^unit +[A-Za-z_0-9]+ *;' "$here/${entry%%:*}.pas" | sed -E 's/^[Uu][Nn][Ii][Tt] +([A-Za-z_0-9]+).*/\1/'; done | paste -sd,)
printf 'program allpages;\n{$mode objfpc}\nuses %s;\nbegin\nend.\n' "$uses" > "$out/allpages.pas"
"$compiler" -n -Tbrowser -vw -Jc -Ji"$PAS2JS_RTL" -Fu"$PAS2JS_SOURCE/packages/rtl/src" -Fi"$PAS2JS_SOURCE/packages/rtl/src" \
  -Fu"$out/src" -FU"$out/units" -o"$out/allpages.js" "$out/allpages.pas"
python3 - "$here" "$out" "$static" "$PAS2JS_RTL" "$mode" "${scripts[@]}" <<'PY'
import gzip
import re
import sys
from pathlib import Path
source, out, static, rtl = map(Path, sys.argv[1:5])
mode = sys.argv[5]
scripts = {}
sizes = {}
for entry in sys.argv[6:]:
    name, size = entry.split(':')
    sizes[name] = int(size)
    unit = source / (name + '.pas')
    match = re.search(r'(?im)^unit\s+(\w+)\s*;', unit.read_text())
    scripts[name] = match[1]
# The program's output is rtl.js, then one rtl.module(...) per unit in the order they start,
# then the program's own module, which is left out.
bundle = (out / 'allpages.js').read_bytes()
cuts = [m.start() for m in re.finditer(rb'(?m)^rtl\.module\("', bundle)]
head = bundle[:cuts[0]]
parts = {}
for at, end in zip(cuts, cuts[1:] + [len(bundle)]):
    text = bundle[at:end]
    parts[re.match(rb'rtl\.module\("(\w+)"', text)[1].decode()] = text.rstrip(b'\n') + b'\n'
parts.pop('program')
mains = {unit.lower(): name for name, unit in scripts.items()}
# A large script may be several units: <script>_<part>.pas goes into that script's file.
def owner(module):
    if module.lower() in mains:
        return mains[module.lower()]
    return next((name for name in scripts if module.lower().startswith(name.lower() + '_')), None)
outputs = {'pas-runtime.js': head + b''.join(text for module, text in parts.items() if not owner(module))}
for name, unit in scripts.items():
    data = b''.join(text for module, text in parts.items() if owner(module) == name and module.lower() != unit.lower())
    data += parts[unit]
    # These scripts already guard each form or tab against a second attachment.
    if name in ('search', 'forum-admin'):
        prefix = (f'if (pas.{unit} && pas.{unit}.$state === rtl.m_initialized) pas.{unit}.Start();\n'
                  f'if (!pas.{unit})\n')
        data = prefix.encode() + data
    data += ("\nrtl.run('" + unit + "');\n").encode()
    if name not in ('search', 'forum-admin'):
        # A script a page names twice is started once, with no word about the second.
        data = f'if (!pas.{unit}) {{\n'.encode() + data + b'}\n'
    if name == 'live':
        # Other sites' pages loaded this file alone before embed.js named the plain one.
        data = (b"// A page that loads this file alone, with no runtime, gets the plain script.\n"
                b"if (typeof rtl === 'undefined') (function () {\n"
                b"  var plain = document.createElement('script');\n"
                b"  plain.src = document.currentScript.src.replace(/live\\.js/, 'live-embed.js');\n"
                b"  document.body.appendChild(plain);\n"
                b"})(); else {\n" + data + b"}\n")
    outputs[name + '.js'] = data
problems = []
for name, data in outputs.items():
    packed = len(gzip.compress(data, mtime=0))
    print(f'{name}: {len(data)} bytes, {packed} gzip bytes')
    if name == 'pas-runtime.js':
        if len(data) > 300000 or packed > 75000:
            problems.append('runtime exceeds 300000 bytes or 75000 gzip bytes')
    else:
        before = sizes[name.removesuffix('.js')]
        if len(data) > 2 * before:
            problems.append(f'{name} exceeds twice its original {before} bytes')
    if mode == 'check' and (not (static / name).is_file() or (static / name).read_bytes() != data):
        problems.append(name + ' differs from a fresh build')
if problems:
    raise SystemExit('\n'.join(problems))
# Validate every output before replacing any file.
if mode == 'build':
    for name, data in outputs.items():
        (static / name).write_bytes(data)
PY
