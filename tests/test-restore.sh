#!/usr/bin/env bash
# Sandboxed proof that install → uninstall restores the exact prior state.
# Uses a throwaway HOME and OMACALE_OFFLINE=1, so it never touches the real
# desktop, shell, or config.
set -Eeuo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
omacale="$here/../scripts/omacale"
src_shell_json="${OMACALE_TEST_SHELL_JSON:-$HOME/.config/omarchy/shell.json}"
[[ -f $src_shell_json ]] || src_shell_json="${OMARCHY_PATH:-/usr/share/omarchy}/config/omarchy/shell.json"
# A realistic pre-install shell.json: the user's own, minus any Omacale state.
real_shell_json="$(mktemp)"
jq 'if (.bar.id // "") | startswith("omacale.") then del(.bar.id) else . end' "$src_shell_json" > "$real_shell_json"
pass=0 failn=0

homes=()
cleanup() { (( ${#homes[@]} )) && chmod -R u+rwx "${homes[@]}" 2>/dev/null; rm -rf -- "${homes[@]}" "$real_shell_json"; }
trap cleanup EXIT
new_home() {
  H="$(mktemp -d)"; homes+=("$H")
  mkdir -p "$H/.config/omarchy/plugins" "$H/.local/state"
}
run() { env -u XDG_CONFIG_HOME -u XDG_STATE_HOME HOME="$H" OMACALE_OFFLINE=1 "$omacale" "$@" --yes >/dev/null; }
check() { # check "name" cond-cmd...
  local name="$1"; shift
  if "$@"; then printf '  \e[32mPASS\e[0m %s\n' "$name"; pass=$((pass+1)); else printf '  \e[31mFAIL\e[0m %s\n' "$name"; failn=$((failn+1)); fi
}
snapshot_tree() { (cd "$H" && find . -type f -o -type l | sort | xargs -r sha256sum 2>/dev/null; find . -type d | sort) ; }
SJ() { echo "$H/.config/omarchy/shell.json"; }

echo "A. shell.json exists, no bar.id set — byte-exact restore"
new_home; cp "$real_shell_json" "$(SJ)"
before="$(snapshot_tree)"
run install
check "bar.id switched"            test "$(jq -r .bar.id "$(SJ)")" = omacale.bar
check "plugin dir installed"       test -f "$H/.config/omarchy/plugins/omacale.bar/manifest.json"
check "state recorded"             test -f "$H/.local/state/omacale/state.json"
run uninstall
check "shell.json byte-identical"  cmp -s "$real_shell_json" "$(SJ)"
check "plugin dir gone"            test ! -e "$H/.config/omarchy/plugins/omacale.bar"
check "state dir gone"             test ! -e "$H/.local/state/omacale"
check "whole tree identical"       test "$before" = "$(snapshot_tree)"

echo "B. user edits shell.json after install — their edit survives"
new_home; cp "$real_shell_json" "$(SJ)"
run install
jq '.idle.lock = 777' "$(SJ)" > "$(SJ).t" && mv "$(SJ).t" "$(SJ)"
run uninstall
check "idle.lock edit kept"        test "$(jq -r .idle.lock "$(SJ)")" = 777
check "bar.id reverted"            test "$(jq -r '.bar.id // "unset"' "$(SJ)")" = unset
check "no omacale entries left"    test "$(grep -c omacale "$(SJ)" || true)" = 0

echo "C. no shell.json before install — absent again after"
new_home; rm -f "$(SJ)"
run install
check "shell.json created"         test -f "$(SJ)"
run uninstall
check "shell.json absent again"    test ! -e "$(SJ)"

echo "D. a different bar was active — it is re-selected"
new_home; jq '.bar.id = "local.neon-bar"' "$real_shell_json" > "$(SJ)"; keep="$(cat "$(SJ)")"
run install
check "switched to omacale"        test "$(jq -r .bar.id "$(SJ)")" = omacale.bar
run uninstall
check "previous bar restored"      test "$(jq -r .bar.id "$(SJ)")" = local.neon-bar
check "file byte-identical"        test "$keep" = "$(cat "$(SJ)")"

echo "E. a pre-existing plugin directory is set aside and put back"
new_home; cp "$real_shell_json" "$(SJ)"
mkdir -p "$H/.config/omarchy/plugins/omacale.bar"; echo '{"id":"omacale.bar","mine":true}' > "$H/.config/omarchy/plugins/omacale.bar/manifest.json"
run install
check "ours replaced it"           test "$(jq -r .version "$H/.config/omarchy/plugins/omacale.bar/manifest.json")" = "$(jq -r .version "$here/../omacale.bar/manifest.json")"
run uninstall
check "theirs is back"             test "$(jq -r .mine "$H/.config/omarchy/plugins/omacale.bar/manifest.json")" = true

echo "F. dry-run changes nothing"
new_home; cp "$real_shell_json" "$(SJ)"; before="$(snapshot_tree)"
env -u XDG_CONFIG_HOME -u XDG_STATE_HOME HOME="$H" OMACALE_OFFLINE=1 "$omacale" install --dry-run >/dev/null
check "tree unchanged"             test "$before" = "$(snapshot_tree)"

echo "G. --dev symlink install and uninstall"
new_home; cp "$real_shell_json" "$(SJ)"; before="$(snapshot_tree)"
run install --dev
check "plugin is a symlink"        test -L "$H/.config/omarchy/plugins/omacale.bar"
run uninstall
check "symlink removed, source intact" bash -c "test ! -e '$H/.config/omarchy/plugins/omacale.bar' && test -f '$here/../omacale.bar/manifest.json'"
check "tree identical"             test "$before" = "$(snapshot_tree)"

echo "H. uninstall with nothing installed is a no-op"
new_home; cp "$real_shell_json" "$(SJ)"; before="$(snapshot_tree)"
run uninstall
check "tree unchanged"             test "$before" = "$(snapshot_tree)"

echo "I. failed install rolls back"
new_home; cp "$real_shell_json" "$(SJ)"; before="$(snapshot_tree)"
chmod 500 "$H/.config/omarchy/plugins"    # plugin copy will fail
env -u XDG_CONFIG_HOME -u XDG_STATE_HOME HOME="$H" OMACALE_OFFLINE=1 "$omacale" install --yes >/dev/null 2>&1 || true
chmod 700 "$H/.config/omarchy/plugins"
check "shell.json untouched"       cmp -s "$real_shell_json" "$(SJ)"
check "no plugin left behind"      test ! -e "$H/.config/omarchy/plugins/omacale.bar"
check "no state left behind"       test ! -e "$H/.local/state/omacale"

echo "J. settings created while installed are removed on uninstall"
new_home; cp "$real_shell_json" "$(SJ)"; before="$(snapshot_tree)"
run install
mkdir -p "$H/.config/omacale"; echo '{"bar":{"persistent":false}}' > "$H/.config/omacale/settings.json"
run uninstall
check "settings dir removed"       test ! -e "$H/.config/omacale"
check "tree identical"             test "$before" = "$(snapshot_tree)"

echo "K. settings that existed before install are restored exactly"
new_home; cp "$real_shell_json" "$(SJ)"
mkdir -p "$H/.config/omacale"; echo '{"appearance":{"variant":"vibrant"}}' > "$H/.config/omacale/settings.json"
before="$(snapshot_tree)"
run install
echo '{"appearance":{"variant":"monochrome"}}' > "$H/.config/omacale/settings.json"
run uninstall
check "pre-install settings back"  test "$(jq -r .appearance.variant "$H/.config/omacale/settings.json")" = vibrant
check "tree identical"             test "$before" = "$(snapshot_tree)"

echo "L. --keep-settings keeps the user's settings"
new_home; cp "$real_shell_json" "$(SJ)"
run install
mkdir -p "$H/.config/omacale"; echo '{"x":1}' > "$H/.config/omacale/settings.json"
env -u XDG_CONFIG_HOME -u XDG_STATE_HOME HOME="$H" OMACALE_OFFLINE=1 "$omacale" uninstall --keep-settings --yes >/dev/null
check "settings kept"              test -f "$H/.config/omacale/settings.json"
check "plugin still removed"       test ! -e "$H/.config/omarchy/plugins/omacale.bar"

echo "M. keybinds file is valid Omarchy Lua"
check "has o.bind lines"           bash -c "grep -cE '^o\\.bind\\(\"[A-Z +]+\", \"Omacale [^\"]+\", \"omarchy-shell omacale [a-zA-Z ]+\"\\)$' '$here/../omacale.bar/keybinds.lua' | grep -qx 8"

echo "N. the switcher's menu block is removed on uninstall"
switcher() { env -u XDG_CONFIG_HOME HOME="$H" bash "$H/.config/omarchy/plugins/omacale.bar/scripts/switcher.sh" menu "$1"; }
EXT() { echo "$H/.config/omarchy/extensions/omarchy-menu.jsonc"; }
new_home; cp "$real_shell_json" "$(SJ)"
mkdir -p "$(dirname "$(EXT)")"; printf '{\n  // mine\n  "about": {"label":"Me"},\n}\n' > "$(EXT)"
before="$(snapshot_tree)"
run install
switcher on
check "block added"                grep -qF '"style.background"' "$(EXT)"
run uninstall
check "user's extension restored"  test "$before" = "$(snapshot_tree)"
new_home; cp "$real_shell_json" "$(SJ)"
before="$(snapshot_tree)"
run install
switcher on
check "extension file created"     test -f "$(EXT)"
run uninstall
check "created file removed again" test "$before" = "$(snapshot_tree)"

echo "O. look'n'feel file is valid Lua"
check "omacale.lua parses"         luac -p "$here/../omacale.bar/omacale.lua"

echo; echo "passed: $pass  failed: $failn"
(( failn == 0 ))
