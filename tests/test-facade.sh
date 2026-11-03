#!/usr/bin/env bash
# tests/test-facade.sh -- every public member of Omarchy's bar widget API
# (shell/Ui/PluginBarApi.qml: what a hosted widget may read or call on `bar`)
# exists on Omacale's PluginBarFacade. A member a later Omarchy adds shows up
# here, so the widgets that use it can be checked before they break.
# OMARCHY_PATH picks another Omarchy tree (default /usr/share/omarchy).
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
api=${OMARCHY_PATH:-/usr/share/omarchy}/shell/Ui/PluginBarApi.qml
facade=$here/modules/bar/PluginBarFacade.qml
[[ -f $api ]] || { echo "SKIP: no $api"; exit 0; }

members() {
  sed -nE 's/^\s*(required\s+|readonly\s+)*property\s+\S+\s+([A-Za-z][A-Za-z0-9]*).*/\2/p; s/^\s*function\s+([A-Za-z][A-Za-z0-9]*)\s*\(.*/\1/p' "$1" | sort -u
}
missing=$(comm -23 <(members "$api") <(members "$facade"))
if [[ -n $missing ]]; then
  echo "FAIL: PluginBarFacade lacks members of $api:"
  sed 's/^/    /' <<<"$missing"
  exit 1
fi
echo "all passed ($(members "$api" | wc -l) members)"
