#!/usr/bin/env bash
# bash tests/test-shell-toml.sh -- scripts/shell-toml on scratch files only.
set -u
export PYTHONDONTWRITEBYTECODE=1
here=$(cd "$(dirname "$0")/.." && pwd)
tool="$here/scripts/shell-toml"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export OMACALE_SHELL_TOML="$tmp/shell.toml"
fails=0
ok() { echo "  PASS $1"; }
bad() { echo "  FAIL $1"; fails=$((fails + 1)); }
spec=$'popups.background=#112233\npopups.text=#eeeeee\nmenu.background=#112233'

printf '[font]\nbase-size = 10\n' > "$OMACALE_SHELL_TOML"; cp "$OMACALE_SHELL_TOML" "$tmp/orig"
"$tool" set "$spec"
grep -q '^background = "#112233"' "$OMACALE_SHELL_TOML" && grep -q '^base-size = 10' "$OMACALE_SHELL_TOML" && ok "set adds the block, keeps the user's lines" || bad "set adds the block"
[ "$("$tool" status)" = present ] && ok "status: present" || bad "status present"
"$tool" set "$spec"; [ "$(grep -c 'omacale:surfaces v1' "$OMACALE_SHELL_TOML")" = 1 ] && ok "set twice keeps one block" || bad "one block"
"$tool" remove; cmp -s "$tmp/orig" "$OMACALE_SHELL_TOML" && ok "remove restores the file byte for byte" || bad "byte-for-byte restore"
[ "$("$tool" status)" = absent ] && ok "status: absent" || bad "status absent"

printf '[font]\nbase-size = 10' > "$OMACALE_SHELL_TOML"; cp "$OMACALE_SHELL_TOML" "$tmp/orig"
"$tool" set "$spec"; "$tool" remove
cmp -s "$tmp/orig" "$OMACALE_SHELL_TOML" && ok "no trailing newline: restored exactly" || bad "no trailing newline"

rm -f "$OMACALE_SHELL_TOML"
"$tool" set "$spec"; [ -f "$OMACALE_SHELL_TOML" ] && ok "set creates a missing file" || bad "create"
"$tool" remove; [ ! -e "$OMACALE_SHELL_TOML" ] && ok "remove deletes a file it created" || bad "delete created"

printf '[popups]\nbackground = "#ff0000"\n' > "$OMACALE_SHELL_TOML"
"$tool" set "$spec"
# popups.background stays the user's; only menu.background takes #112233.
[ "$(grep -c '#ff0000' "$OMACALE_SHELL_TOML")" = 1 ] && [ "$(grep -c '#112233' "$OMACALE_SHELL_TOML")" = 1 ] && grep -q '^text = "#eeeeee"' "$OMACALE_SHELL_TOML" \
  && ok "a key the user set is left to the user" || bad "user key wins"
"$tool" remove

printf '[font]\nbase-size = 10\n' > "$OMACALE_SHELL_TOML"; "$tool" set "$spec"
printf '\n[font]\nfamily = "x"\n' >> "$OMACALE_SHELL_TOML"   # a later edit after the block
"$tool" remove; grep -q 'family = "x"' "$OMACALE_SHELL_TOML" && ! grep -q omacale "$OMACALE_SHELL_TOML" && ok "remove keeps lines added after the block" || bad "lines after block"

[ $fails -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
