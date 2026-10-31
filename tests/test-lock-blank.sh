#!/usr/bin/env bash
# The screen-off delay patch on Omarchy's lock Service.qml (scripts/lock-screen
# patch_blank): applies to the installed service, is idempotent, and leaves a
# service it does not recognise untouched.
set -Eeuo pipefail
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
stock="${OMARCHY_PATH:-/usr/share/omarchy}/shell/plugins/lock/Service.qml"
pass=0 failn=0
check() { local n="$1"; shift; if "$@"; then printf '  \e[32mPASS\e[0m %s\n' "$n"; pass=$((pass+1)); else printf '  \e[31mFAIL\e[0m %s\n' "$n"; failn=$((failn+1)); fi; }
py() { python3 -I - "$@" <<PY
import importlib.machinery, importlib.util, sys
sys.dont_write_bytecode = True
loader = importlib.machinery.SourceFileLoader("ls", "$here/../scripts/lock-screen")
spec = importlib.util.spec_from_loader("ls", loader); m = importlib.util.module_from_spec(spec); loader.exec_module(m)
$PYBODY
PY
}
PYBODY='
s = open("'"$stock"'","rb").read()
p = m.patch_blank(s)
sys.exit(0 if p != s and b"omacaleBlankMs" in p and p.count(b"omacale:blank-after") == 2 else 1)'
check "patch applies to the installed Service.qml" py
PYBODY='
s = open("'"$stock"'","rb").read()
p = m.patch_blank(s)
sys.exit(0 if m.patch_blank(p) == p else 1)'
check "patching twice changes nothing more" py
PYBODY='
junk = b"Item { }"
sys.exit(0 if m.patch_blank(junk) == junk else 1)'
check "an unrecognised service is left untouched" py
printf '%d passed, %d failed\n' "$pass" "$failn"; (( failn == 0 ))
