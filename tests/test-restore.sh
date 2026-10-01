#!/usr/bin/env bash
# Sandboxed proof that install → uninstall restores the exact prior state.
# Uses a throwaway HOME and OMACALE_OFFLINE=1, so it never touches the real
# desktop, shell, or config.
set -Eeuo pipefail
# The scripts under test live in the plugin; bytecode written beside them
# would be synced into ~/.config/omarchy/plugins and reload every plugin.
export PYTHONDONTWRITEBYTECODE=1

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
check "ours replaced it"           test "$(jq -r .version "$H/.config/omarchy/plugins/omacale.bar/manifest.json")" = "$(jq -r .version "$here/../manifest.json")"
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
check "symlink removed, source intact" bash -c "test ! -e '$H/.config/omarchy/plugins/omacale.bar' && test -f '$here/../manifest.json'"
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
check "has o.bind lines"           bash -c "grep -cE '^o\\.bind\\(\"[A-Z +]+\", \"Omacale [^\"]+\", \"omarchy-shell omacale [a-zA-Z ]+\"\\)$' '$here/../keybinds.lua' | grep -qx 8"

echo "N. an old switcher menu block is removed on uninstall"
EXT() { echo "$H/.config/omarchy/extensions/omarchy-menu.jsonc"; }
# What Omacale <= 0.6 wrote to the menu extension (it no longer writes it).
old_block() { printf '  // >>> omacale switcher%s — managed by Omacale\n  "style.theme": {"action":"true"},\n  // <<< omacale switcher\n' "$1"; }
new_home; cp "$real_shell_json" "$(SJ)"
mkdir -p "$(dirname "$(EXT)")"; printf '{\n  // mine\n  "about": {"label":"Me"},\n}\n' > "$(EXT)"
before="$(snapshot_tree)"
run install
{ echo '{'; old_block ""; tail -n +2 "$(EXT)"; } > "$(EXT).new" && mv "$(EXT).new" "$(EXT)"
check "old block present"          grep -qF '"style.theme"' "$(EXT)"
run uninstall
check "user's extension restored"  test "$before" = "$(snapshot_tree)"
new_home; cp "$real_shell_json" "$(SJ)"
before="$(snapshot_tree)"
run install
mkdir -p "$(dirname "$(EXT)")"; { echo '{'; old_block " (created, dir)"; echo '}'; } > "$(EXT)"
run uninstall
check "created file removed again" test "$before" = "$(snapshot_tree)"

echo "O. look'n'feel file is valid Lua"
check "omacale.lua parses"         luac -p "$here/../omacale.lua"

echo "P. the notification daemon patch"
# scripts/notif-popups edits a clone of Omarchy's notification plugin. It must
# do exactly one thing to a file it recognises, nothing at all to one it does
# not, and nothing a second time.
stock="${OMARCHY_PATH:-/usr/share/omarchy}/shell/plugins/notifications/Service.qml"
patch_copy() { python3 -c "
from importlib.machinery import SourceFileLoader
SourceFileLoader('np', '$here/../scripts/notif-popups').load_module().patch_service('$1')"; }
if [[ -f $stock ]]; then
  work="$(mktemp -d)"; cp "$stock" "$work/Service.qml"
  patch_copy "$work/Service.qml" >/dev/null 2>&1
  # The toast window goes; `reloadableId: "omarchy-notifications"` stays --
  # that is the DND state's key, not the surface.
  check "popup window removed"     bash -c "! grep -qE 'PanelWindow|WlrLayershell|NotificationCard' '$work/Service.qml'"
  check "lifetime timer kept"      grep -q 'sweepPopupLifetimes' "$work/Service.qml"
  check "IPC added"                grep -q 'function invokeKey' "$work/Service.qml"
  check "daemon left intact"       grep -q 'NotificationServer' "$work/Service.qml"
  check "original backed up"       test -f "$work/Service.qml.omacale-orig"
  check "braces still balanced"    bash -c "test \$(tr -cd '{' < '$work/Service.qml' | wc -c) -eq \$(tr -cd '}' < '$work/Service.qml' | wc -c)"
  cp "$work/Service.qml" "$work/again.qml"
  patch_copy "$work/again.qml" >/dev/null 2>&1
  check "patching twice is a no-op" cmp -s "$work/Service.qml" "$work/again.qml"
  # An Omarchy update that reshapes the popup UI must stop the patch dead
  # rather than leave a half-edited notification daemon behind.
  sed 's/omarchy-notifications/something-else/' "$stock" > "$work/changed.qml"
  check "refuses an unfamiliar file" bash -c "! patch_copy '$work/changed.qml' 2>/dev/null"
  rm -rf "$work"
else
  echo "  - skipped (no Omarchy notification plugin on this machine)"
fi

echo "Q. the lock screen handover"
# scripts/lock-screen swaps the view of a clone of Omarchy's lock
# plugin and leaves its service alone. The contract it checks before writing
# anything is what keeps an Omarchy update from leaving the machine with a
# lock screen that cannot load, so that check is what is tested here.
lock_stock="${OMARCHY_PATH:-/usr/share/omarchy}/shell/plugins/lock/Service.qml"
wrapper="$here/../assets/lock/LockView.qml"
if [[ -f $lock_stock ]]; then
  # missing: what the service drives its view with that the wrapper lacks.
  # added: the same after pretending an Omarchy update grew a property.
  # none: what a service with no LockView block at all yields.
  read -r -d '' lock_probe <<PY || true
from importlib.machinery import SourceFileLoader
m = SourceFileLoader('lk', '$here/../scripts/lock-screen').load_module()
svc = open('$lock_stock').read()
tpl = open('$wrapper').read()
grown = svc.replace('inputEnabled: root.lockRequested', 'inputEnabled: root.lockRequested\n        brandNew: 1')
gone = svc.replace('LockView {', 'SomethingElse {')
print('missing=' + ','.join(sorted(m.view_usage(svc) - m.view_provides(tpl))))
print('added=' + ','.join(sorted(m.view_usage(grown) - m.view_provides(tpl))))
print('none=' + ','.join(sorted(m.view_usage(gone))))
view = open('$lock_stock'.replace('Service.qml', 'LockView.qml')).read()
# A v4.0.x view: none of what Omarchy's view gained since.
old = '\n'.join(l for l in view.splitlines() if not any(n in l for n in ('displaysBlank', 'powerSaverActive', 'videoPosterPath')))
print('onstock=' + ','.join(sorted(m.view_usage(tpl, 'StockLockView') - m.view_provides(view))))
print('onold=' + ','.join(sorted(m.view_usage(tpl, 'StockLockView') - m.view_provides(old))))
print('onbad=' + ','.join(sorted(m.view_usage(tpl.replace('passwordText: root.passwordText', 'passwordText: root.passwordText\n      brandNew: 1'), 'StockLockView') - m.view_provides(view))))
PY
  lock_out="$(python3 -c "$lock_probe" 2>/dev/null)"
  check "the contract probe ran"               test -n "$lock_out"
  check "wrapper meets the service's contract" grep -qx 'missing=' <<<"$lock_out"
  check "a new upstream property is caught"    grep -qx 'added=brandNew' <<<"$lock_out"
  check "a service with no LockView is caught" grep -qx 'none=' <<<"$lock_out"
  check "wrapper only sets what Omarchy's view has" grep -qx 'onstock=' <<<"$lock_out"
  check "wrapper loads on a v4.0.x view"       grep -qx 'onold=' <<<"$lock_out"
  check "a wrapper setting a missing property is caught" grep -qx 'onbad=brandNew' <<<"$lock_out"
  check "wrapper keeps Omarchy's view as the fallback" grep -q 'StockLockView' "$wrapper"
  # A relative directory import of omacale.bar would make a removed or broken
  # Omacale a lock screen that cannot load; the wrapper loads it by URL.
  check "wrapper imports nothing from Omacale" bash -c "! grep -q '^import \"' '$wrapper'"
  check "wrapper carries its version marker"   grep -q 'omacale:lock-view v' "$wrapper"
else
  echo "  - skipped (no Omarchy lock plugin on this machine)"
fi

echo "R. handovers follow Omarchy updates"
# Both clones are rebuilt from the installed Omarchy on every sync, and the
# watchdog hands a broken one back. Run against a scratch OMARCHY_PATH and
# HOME, with omarchy-shell / omarchy faked on PATH, so nothing real is touched.
real_omarchy="${OMARCHY_PATH:-/usr/share/omarchy}"
scripts="$here/../scripts"
if [[ -d $real_omarchy/shell/plugins/notifications && -d $real_omarchy/shell/plugins/lock ]]; then
  new_home
  fake="$H/omarchy"; mkdir -p "$fake/shell/plugins" "$H/bin"
  cp -r "$real_omarchy/shell/plugins/notifications" "$real_omarchy/shell/plugins/lock" "$fake/shell/plugins/"
  plugins="$H/.config/omarchy/plugins"
  # The fake shell answers from files, so a case can make a plugin "broken".
  cat > "$H/bin/omarchy-shell" <<'SH'
#!/bin/bash
case "$1 $2" in
  "shell ping") echo ok ;;
  "shell listPlugins") echo '[]' ;;
  "notifications ping") [[ -f $HOME/notif-broken ]] && exit 1; echo ok ;;
  "notifications popupsHidden") [[ -f $HOME/notif-broken ]] && exit 1; echo yes ;;
  "lock isLocked") echo false ;;
  "lock status") [[ -f $HOME/lock-dead ]] && exit 1; [[ -f $HOME/lock-broken ]] && { echo '{"locked":false,"passwordPam":false}'; exit 0; }; echo '{"locked":false,"passwordPam":true}' ;;
  *) exit 1 ;;
esac
SH
  cat > "$H/bin/omarchy" <<'SH'
#!/bin/bash
[[ "$1 $2" == "plugin remove" ]] && rm -rf "$HOME/.config/omarchy/plugins/$3"
SH
  printf '#!/bin/bash\nrm -rf "$HOME/.config/omarchy/plugins/$1"\n' > "$H/bin/omarchy-plugin-remove"
  printf '#!/bin/bash\nexit 0\n' > "$H/bin/omarchy-plugin-enable"
  printf '#!/bin/bash\ntouch "$HOME/restarted"\n' > "$H/bin/omarchy-restart-shell"
  chmod +x "$H/bin/"*
  hv() { env HOME="$H" USER=tester OMARCHY_PATH="$fake" PATH="$H/bin:$PATH" OMACALE_HEALTH_TRIES=0 OMACALE_HEAL_DELAY=0 "$@"; }
  # Clones as `omarchy plugin clone` leaves them: stock files + an identity.
  nclone="$plugins/tester.notifications"; lclone="$plugins/tester.lock"
  cp -r "$fake/shell/plugins/notifications" "$nclone"
  jq '.id = "tester.notifications" | .omarchy.clonedFrom = "omarchy.notifications"' "$fake/shell/plugins/notifications/manifest.json" > "$nclone/manifest.json"
  cp -r "$fake/shell/plugins/lock" "$lclone"
  jq '.id = "tester.lock" | .omarchy.clonedFrom = "omarchy.lock"' "$fake/shell/plugins/lock/manifest.json" > "$lclone/manifest.json"
  hv python3 "$scripts/notif-popups" sync >/dev/null
  hv python3 -c "
import sys; sys.argv=['lock-screen']
from importlib.machinery import SourceFileLoader
m = SourceFileLoader('lk', '$scripts/lock-screen').load_module()
m.plan('$lclone', open(m.TEMPLATE).read()).apply()"
  nstatus() { hv python3 "$scripts/notif-popups" status --offline; }
  lstale() { hv python3 -c "
from importlib.machinery import SourceFileLoader
m = SourceFileLoader('lk', '$scripts/lock-screen').load_module()
print(','.join(m.stale_files('$lclone')))"; }
  check "fresh notification clone is not stale"  grep -qx 'stale:     no' <<<"$(nstatus)"
  check "fresh lock clone is not stale"          test -z "$(lstale)"

  # A newer Omarchy: the daemon changes but the patch still applies.
  sed -i 's|function ping(): string { return "ok" }|function ping(): string { return "ok" }\n    function newer(): string { return "yes" }|' "$fake/shell/plugins/notifications/Service.qml"
  echo "// newer" >> "$fake/shell/plugins/notifications/NotificationLogic.js"
  check "a newer daemon makes the clone stale"   grep -qx 'stale:     yes' <<<"$(nstatus)"
  check "and is not the verified one"            grep -qx 'verified:  no' <<<"$(nstatus)"
  hv python3 "$scripts/notif-popups" sync >/dev/null
  check "sync rebuilds from the newer stock"     grep -q 'function newer' "$nclone/Service.qml"
  check "the patch is re-applied"                grep -q 'omacale:headless-popups' "$nclone/Service.qml"
  check "the patch is applied once"              test "$(grep -c 'function popupsHidden' "$nclone/Service.qml")" = 1
  check "other files follow stock"               cmp -s "$fake/shell/plugins/notifications/NotificationLogic.js" "$nclone/NotificationLogic.js"
  check "the pristine copy is the new stock"     cmp -s "$fake/shell/plugins/notifications/Service.qml" "$nclone/Service.qml.omacale-orig"
  check "clean after the sync"                   grep -qx 'stale:     no' <<<"$(nstatus)"

  # Stock reshaped so the patch no longer applies: the old clone stays.
  before_clone="$(sha256sum "$nclone/Service.qml")"
  sed -i 's|// -------------------------------------------------------------- popup UI|// popups, redone|' "$fake/shell/plugins/notifications/Service.qml"
  check "a reshaped daemon is refused"           grep -qx 'patch:     refused' <<<"$(nstatus)"
  check "and reported stale"                     grep -qx 'stale:     yes' <<<"$(nstatus)"
  sync_refused() { ! hv python3 "$scripts/notif-popups" sync >/dev/null 2>&1; }
  check "sync refuses"                           sync_refused
  check "the old clone is kept"                  test "$(sha256sum "$nclone/Service.qml")" = "$before_clone"
  wd="$(hv python3 "$scripts/notif-popups" watchdog)"
  check "watchdog keeps a refused but healthy clone" grep -qx 'action:    refused' <<<"$wd"
  check "  (still there)"                        test -d "$nclone"
  touch "$H/notif-broken"
  wd="$(hv python3 "$scripts/notif-popups" watchdog)"
  check "watchdog hands a broken daemon back"    grep -qx 'action:    fellback' <<<"$wd"
  check "  (clone removed)"                      test ! -e "$nclone"

  # The lock: a new file upstream reaches the clone, a removed one leaves it,
  # and a manifest capability change is carried over.
  echo "// new" > "$fake/shell/plugins/lock/NewThing.qml"
  rm "$fake/shell/plugins/lock/poster.sh"
  jq '.omarchy.capabilities += ["newcap"]' "$fake/shell/plugins/lock/manifest.json" > "$H/m" && mv "$H/m" "$fake/shell/plugins/lock/manifest.json"
  stale="$(lstale)"
  check "lock: new upstream file is stale"       grep -q 'NewThing.qml' <<<"$stale"
  check "lock: removed upstream file is stale"   grep -q 'poster.sh (removed upstream)' <<<"$stale"
  check "lock: manifest change is stale"         grep -q 'manifest.json' <<<"$stale"
  wd="$(hv python3 "$scripts/lock-screen" watchdog 2>/dev/null)"
  check "lock watchdog syncs"                    grep -qx 'action:    synced' <<<"$wd"
  check "a new file upstream reaches the clone"  test -f "$lclone/NewThing.qml"
  check "a file removed upstream leaves it"      test ! -e "$lclone/poster.sh"
  check "our wrapper is kept"                    grep -q 'omacale:lock-view' "$lclone/LockView.qml"
  check "stock view kept as StockLockView"       cmp -s "$fake/shell/plugins/lock/LockView.qml" "$lclone/StockLockView.qml"
  check "capabilities follow stock"              jq -e '.omarchy.capabilities | index("newcap")' "$lclone/manifest.json" >/dev/null
  check "identity stays the clone's"             jq -e '.id == "tester.lock" and .omarchy.clonedFrom == "omarchy.lock"' "$lclone/manifest.json" >/dev/null
  # A clone whose wrapper didn't fit this Omarchy: its service never loaded,
  # and only a shell restart loads the repaired one (--heal).
  healed() { for _ in 1 2 3 4 5 6 7 8 9 10; do [[ -f $H/restarted ]] && return 0; sleep 0.1; done; return 1; }
  unhealed() { sleep 0.5; test ! -f "$H/restarted"; }
  old_wrapper() { sed -i 's/omacale:lock-view v[0-9]*/omacale:lock-view v1/' "$lclone/LockView.qml"; rm -f "$H/restarted"; }
  touch "$H/lock-dead"; old_wrapper
  hv python3 "$scripts/lock-screen" install >/dev/null 2>&1
  check "a repair without --heal doesn't restart" unhealed
  old_wrapper
  hv python3 "$scripts/lock-screen" install --heal >/dev/null 2>&1
  check "a repair under a dead lock service restarts the shell" healed
  rm -f "$H/restarted"
  hv python3 "$scripts/lock-screen" install --heal >/dev/null 2>&1
  check "nothing to repair, no restart"          unhealed
  rm "$H/lock-dead"; old_wrapper
  hv python3 "$scripts/lock-screen" install --heal >/dev/null 2>&1
  check "a running lock service is never restarted under" unhealed
  touch "$H/lock-dead"; old_wrapper
  wd="$(hv python3 "$scripts/lock-screen" watchdog 2>/dev/null)"
  check "the watchdog heals a dead clone rather than dropping it" grep -qx 'action:    healing' <<<"$wd"
  check "  (and restarts the shell)"             healed
  check "  (clone kept)"                         test -d "$lclone"
  rm "$H/lock-dead"

  touch "$H/lock-broken"
  wd="$(hv python3 "$scripts/lock-screen" watchdog 2>/dev/null)"
  check "a lock without PAM is handed back"      grep -qx 'action:    fellback' <<<"$wd"
  check "  (lock clone removed)"                 test ! -e "$lclone"
else
  echo "  - skipped (no Omarchy notification/lock plugins on this machine)"
fi

echo "S. upstream-check names what moved"
# Dev-only drift report: record a scratch Omarchy, change it, and it must
# point at the Omacale area to re-test.
if [[ -d $real_omarchy/shell/plugins/lock ]]; then
  new_home
  fake="$H/omarchy"; mkdir -p "$fake/shell/Ui" "$fake/shell/plugins" "$fake/default/omarchy"
  cp -r "$real_omarchy/shell/plugins/lock" "$real_omarchy/shell/plugins/notifications" "$fake/shell/plugins/"
  cp "$real_omarchy/shell/shell.qml" "$fake/shell/"
  cp "$real_omarchy"/shell/Ui/*.qml "$fake/shell/Ui/"
  uc() { OMARCHY_PATH="$fake" python3 "$here/../scripts/upstream-check" --lock "$H/upstream.lock" "$@"; }
  uc --record >/dev/null
  uc_ok() { uc >/dev/null; }
  check "unchanged Omarchy passes"               uc_ok
  echo "// x" >> "$fake/shell/plugins/lock/Service.qml"
  echo "x" > "$fake/shell/plugins/notifications/New.qml"
  echo 'function f() { shell.bar.brandNewCall() }' >> "$fake/shell/shell.qml"
  out="$(uc || true)"
  check "a changed file is reported"             grep -q 'changed: shell/plugins/lock/Service.qml' <<<"$out"
  check "with the area to re-test"               grep -q 're-test lock handover' <<<"$out"
  check "an added file is reported"              grep -q 'added: shell/plugins/notifications/New.qml' <<<"$out"
  check "a new bar-contract call is reported"    grep -q 'newly called: bar.brandNewCall' <<<"$out"
  uc_fails() { ! uc >/dev/null; }
  check "and the check fails"                    uc_fails
  check "the committed lock is readable"         python3 -c "import json; json.load(open('$here/upstream.lock'))"
else
  echo "  - skipped (no Omarchy lock plugin on this machine)"
fi

echo "T. notifs.py survives a changed record format"
new_home
nd="$H/.local/state/omarchy/notifications"; mkdir -p "$nd/history"
echo '{"id": 1, "app": "a", "summary": "ok", "timestamp": 100}' > "$nd/history/100-1.json"
echo '{"id": 2, "app": "b", "summary": "late", "timestamp": "not a number", "shiny": true}' > "$nd/history/200-2.json"
echo '{"id": 3, "app": "c", "headline": "no summary", "timestamp": 300}' > "$nd/history/300-3.json"
echo '[1, 2, 3]' > "$nd/history/400-4.json"
echo '{broken' > "$nd/history/500-5.json"
out="$(HOME="$H" python3 "$here/../scripts/notifs.py" 2>"$H/err")"
check "good records survive bad neighbours"    test "$(jq length <<<"$out")" = 3
check "newest first"                           test "$(jq -r '.[0].app' <<<"$out")" = c
check "a bad timestamp becomes 0"              test "$(jq -r '.[] | select(.app == "b") | .timestamp' <<<"$out")" = 0
check "unknown fields pass through"            test "$(jq -r '.[] | select(.app == "b") | .shiny' <<<"$out")" = true
check "a missing summary is filled"            test "$(jq -r '.[] | select(.app == "c") | .summary' <<<"$out")" = ""
check "the format change is logged once"       test "$(grep -c 'notifs.py:' "$H/err")" = 1

echo "U. the OSD handover"
# scripts/osd-handover puts its clone in place already patched: the host keeps
# the first compilation of a plugin file for the whole session, so a clone that
# is enabled unpatched for a moment stays the running OSD until a restart.
# Faked shell and omarchy on PATH, scratch HOME and OMARCHY_PATH, as in R.
if [[ -d $real_omarchy/shell/plugins/osd ]]; then
  new_home
  fake="$H/omarchy"; mkdir -p "$fake/shell/plugins" "$H/bin"
  cp -r "$real_omarchy/shell/plugins/osd" "$fake/shell/plugins/"
  plugins="$H/.config/omarchy/plugins"; oclone="$plugins/tester.osd"
  # Every clone dir is listed; it is enabled once `omarchy plugin enable` ran.
  # The OSD answers as patched when the clone on disk is, unless it is told
  # to be the stale compilation (osd-stale) or dead (osd-broken).
  cat > "$H/bin/omarchy-shell" <<'SH'
#!/bin/bash
p="$HOME/.config/omarchy/plugins"
case "$1 $2" in
  "shell ping") echo ok ;;
  "shell rescanPlugins") echo ok ;;
  "shell listPlugins")
    for d in "$p"/*/; do [[ -d $d ]] || continue; id=$(basename "$d")
      jq -cn --arg id "$id" --argjson on "$([[ -f $HOME/enabled-$id ]] && echo true || echo false)" '{id:$id,enabled:$on}'
    done | jq -cs . ;;
  "osd ping") [[ -f $HOME/osd-broken ]] && exit 1; echo ok ;;
  "osd omacaleOsd") [[ -f $HOME/osd-broken || -f $HOME/osd-stale ]] && exit 1
    [[ -f $HOME/osd-outdated ]] && { echo yes; exit 0; }
    grep -om1 'omacale:osd-handover v[0-9]*' "$p/tester.osd/Osd.qml" || exit 1 ;;
  *) exit 1 ;;
esac
SH
  cat > "$H/bin/omarchy" <<'SH'
#!/bin/bash
case "$1 $2" in
  "plugin enable") touch "$HOME/enabled-$3" ;;
  "plugin remove") rm -rf "$HOME/.config/omarchy/plugins/$3" "$HOME/enabled-$3" ;;
  "plugin clone") echo "osd-handover must not use omarchy plugin clone" >&2; exit 1 ;;
esac
SH
  chmod +x "$H/bin/"*
  hv() { env HOME="$H" USER=tester OMARCHY_PATH="$fake" PATH="$H/bin:$PATH" OMACALE_HEALTH_TRIES=0 "$@"; }
  ostatus() { hv python3 "$scripts/osd-handover" status "$@"; }

  # Stock reshaped: nothing is cloned at all.
  cp "$fake/shell/plugins/osd/Osd.qml" "$H/Osd.qml.stock"
  sed -i 's|function show(iconName|function showRenamed(iconName|' "$fake/shell/plugins/osd/Osd.qml"
  install_refused() { ! hv python3 "$scripts/osd-handover" install >/dev/null 2>&1; }
  check "a reshaped OSD is refused"              install_refused
  check "  (and nothing is cloned)"              test ! -e "$oclone"
  cp "$H/Osd.qml.stock" "$fake/shell/plugins/osd/Osd.qml"

  # A clone of the OSD someone edited by hand is theirs: never overwritten,
  # never "handed back" (removed) by the watchdog.
  cp -r "$fake/shell/plugins/osd" "$oclone"
  jq '.id = "tester.osd" | .omarchy.clonedFrom = "omarchy.osd"' "$fake/shell/plugins/osd/manifest.json" > "$oclone/manifest.json"
  echo "// my own OSD" >> "$oclone/Osd.qml"
  before_clone="$(sha256sum "$oclone/Osd.qml")"
  check "an edited clone is not taken over"      install_refused
  check "  (left exactly as it was)"             test "$(sha256sum "$oclone/Osd.qml")" = "$before_clone"
  wd="$(hv python3 "$scripts/osd-handover" watchdog)"
  check "  (and the watchdog leaves it alone)"   grep -qx 'action:    none' <<<"$wd"
  check "  (still there)"                        test -d "$oclone"
  # An untouched `omarchy plugin clone` is adopted.
  cp "$fake/shell/plugins/osd/Osd.qml" "$oclone/Osd.qml"
  hv python3 "$scripts/osd-handover" install >/dev/null 2>&1
  check "a plain clone is adopted and patched"   grep -q 'omacale:osd-handover' "$oclone/Osd.qml"
  rm -rf "$oclone" "$H/enabled-tester.osd"

  # $USER becomes the clone's id: never a path.
  bad_user() { ! env HOME="$H" USER="../evil" OMARCHY_PATH="$fake" PATH="$H/bin:$PATH" OMACALE_HEALTH_TRIES=0 python3 "$scripts/osd-handover" install >/dev/null 2>&1; }
  check "a clone id that is a path is refused"   bad_user
  check "  (nothing written outside)"            test ! -e "$H/.config/omarchy/evil.osd"

  out="$(hv python3 "$scripts/osd-handover" install 2>&1)"
  check "install places the clone"               test -f "$oclone/Osd.qml"
  check "  already patched"                      grep -q 'omacale:osd-handover' "$oclone/Osd.qml"
  check "  with no staging dir left behind"      test -z "$(find "$plugins" -maxdepth 1 -name '.clone.*')"
  check "  and enables it"                       test -f "$H/enabled-tester.osd"
  check "  and finds the patched OSD running"    grep -qx 'running:   patched' <<<"$out"
  check "the gate is patched in once"            test "$(grep -c 'if (root.omacaleTakes(next)) return' "$oclone/Osd.qml")" = 1
  check "the Hyprland import is added once"      test "$(grep -c '^import Quickshell.Hyprland$' "$oclone/Osd.qml")" = 1
  check "close() is passed on"                   grep -q 'function close() { opened = false; root.omacaleSend({ kind: "close" }) }' "$oclone/Osd.qml"
  check "other OSDs become toasts"               grep -q 'osd.toasts' "$oclone/Osd.qml"
  check "the pristine copy is stock"             cmp -s "$fake/shell/plugins/osd/Osd.qml" "$oclone/Osd.qml.omacale-orig"
  check "identity is the clone's"                jq -e '.id == "tester.osd" and .name == "My On-screen display" and .omarchy.clonedFrom == "omarchy.osd"' "$oclone/manifest.json" >/dev/null
  check "a fresh clone is not stale"             grep -qx 'stale:     no' <<<"$(ostatus --offline)"
  check "sync has nothing to do"                 grep -q 'already matches' <<<"$(hv python3 "$scripts/osd-handover" sync)"
  wd="$(hv python3 "$scripts/osd-handover" watchdog)"
  check "a healthy clone is left alone"          grep -qx 'action:    none' <<<"$wd"

  # The shell compiled the clone before it was patched: Omarchy's OSD still
  # draws everything, which is not broken -- a restart finishes the handover.
  touch "$H/osd-stale"
  check "status says the stale OSD is running"   grep -qx 'running:   stock' <<<"$(ostatus)"
  wd="$(hv python3 "$scripts/osd-handover" watchdog)"
  check "watchdog waits for a restart"           grep -qx 'action:    restart-pending' <<<"$wd"
  check "  (clone kept)"                         test -d "$oclone"
  rm "$H/osd-stale"

  # An older patch (v1/v2 answered "yes") still running after a re-sync: it
  # works, so it is left alone, and status says a restart brings the new one.
  touch "$H/osd-outdated"
  check "an older running patch is reported"     grep -qx 'running:   outdated' <<<"$(ostatus)"
  wd="$(hv python3 "$scripts/osd-handover" watchdog)"
  check "  and is healthy"                       grep -qx 'action:    none' <<<"$wd"
  rm "$H/osd-outdated"

  # A newer Omarchy that the patch still fits.
  echo "// newer" >> "$fake/shell/plugins/osd/OsdModel.js"
  check "a newer OSD makes the clone stale"      grep -qx 'stale:     yes' <<<"$(ostatus --offline)"
  wd="$(hv python3 "$scripts/osd-handover" watchdog)"
  check "watchdog syncs it"                      grep -qx 'action:    synced' <<<"$wd"
  check "  (the new file reached the clone)"     cmp -s "$fake/shell/plugins/osd/OsdModel.js" "$oclone/OsdModel.js"

  touch "$H/osd-broken"
  wd="$(hv python3 "$scripts/osd-handover" watchdog)"
  check "a dead OSD is handed back"              grep -qx 'action:    fellback' <<<"$wd"
  check "  (clone removed)"                      test ! -e "$oclone"
  rm "$H/osd-broken"
else
  echo "  - skipped (no Omarchy OSD plugin on this machine)"
fi

echo; echo "passed: $pass  failed: $failn"
(( failn == 0 ))
