#!/usr/bin/env bash
# bash tests/test-limine-style.sh -- scripts/limine-style on a scratch ESP only
# (LIMINE_STYLE_ROOT), never /boot. Covers the safety rules in its header.
set -u
export PYTHONDONTWRITEBYTECODE=1
here=$(cd "$(dirname "$0")/.." && pwd)
tool="$here/scripts/limine-style"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fails=0
ok() { echo "  PASS $1"; }
bad() { echo "  FAIL $1"; fails=$((fails + 1)); }

root="$tmp/root"; esp="$root/boot"; conf="$esp/limine.conf"
export LIMINE_STYLE_ROOT="$root"
export LIMINE_STYLE_TEMPLATE="$tmp/template.conf"
export LIMINE_STYLE_ENROLL="$tmp/enroll"
mkdir -p "$esp" "$root/etc/default"
echo 'ESP_PATH="/boot"' > "$root/etc/default/limine"
# Omarchy's template (the real one when present) and a stub enroll that logs.
if [ -f /usr/share/omarchy/default/limine/limine.conf ]; then cp /usr/share/omarchy/default/limine/limine.conf "$LIMINE_STYLE_TEMPLATE"
else printf '#timeout: 3\ndefault_entry: 2\ninterface_branding: Omarchy Bootloader\ninterface_branding_color: 9ece6a\nhash_mismatch_panic: no\n\nterm_background: 1a1b26\nterm_foreground: c0caf5\n' > "$LIMINE_STYLE_TEMPLATE"; fi
cat > "$LIMINE_STYLE_ENROLL" <<EOF
#!/bin/sh
echo enrolled >> "$tmp/enroll.log"
[ -e "$tmp/enroll.fail" ] && exit 1
exit 0
EOF
chmod +x "$LIMINE_STYLE_ENROLL"

entries=$'/+Omarchy\ncomment: Omarchy\n  //linux-omarchy\n  protocol: efi\n  path: boot():/EFI/Linux/omarchy_linux-omarchy.efi#abc123\n  //Snapshots\n  ///2026-10-10 12:00\n  protocol: efi\n  path: boot():/limine_history/x.efi\n'
fresh() { { cat "$LIMINE_STYLE_TEMPLATE"; printf '\n%s' "$entries"; } > "$conf"; rm -rf "$esp/omacale" "$tmp/enroll.log" "$tmp/enroll.fail"; }
entries_of() { python3 -I -c 'import sys; t=open(sys.argv[1],newline="").read(); i=[n for n,l in enumerate(t.splitlines(True)) if l.lstrip().startswith("/")][0]; sys.stdout.write("".join(t.splitlines(True)[i:]))' "$1"; }
run() { "$tool" "$@" >"$tmp/out" 2>"$tmp/err"; echo $?; }
png="$tmp/wall.png"; printf '\x89PNG\r\n\x1a\nfakeimagedata' > "$png"

# ---- apply
fresh; cp "$conf" "$tmp/before"
rc=$(run apply '{"branding":"My Laptop","brandingColor":"FF8800","foreground":"eeeeee","background":"101010","backgroundAlpha":128,"timeout":5,"rememberLast":true,"hideHelp":true}')
[ "$rc" = 0 ] && ok "apply succeeds" || bad "apply rc=$rc $(cat "$tmp/err")"
grep -qx 'interface_branding: My Laptop' "$conf" && grep -qx 'interface_branding_color: ff8800' "$conf" && ok "branding and its colour set" || bad "branding"
grep -qx 'term_background: 80101010' "$conf" && ok "background with transparency is TTRRGGBB" || bad "term_background"
grep -qx 'timeout: 5' "$conf" && grep -qx '#timeout: 3' "$conf" && ok "timeout set, the commented one kept" || bad "timeout"
grep -qx 'remember_last_entry: yes' "$conf" && grep -qx 'interface_help_hidden: yes' "$conf" && ok "toggles set" || bad "toggles"
grep -qx 'default_entry: 2' "$conf" && grep -qx 'hash_mismatch_panic: no' "$conf" && ok "other header keys untouched" || bad "other keys"
[ "$(entries_of "$conf")" = "$(entries_of "$tmp/before")" ] && ok "entries byte for byte the same" || bad "entries changed"
[ "$(grep -c enrolled "$tmp/enroll.log")" = 1 ] && ok "enrolled once" || bad "enroll"
[ "$(ls "$esp/omacale/backups" | wc -l)" = 1 ] && cmp -s "$esp/omacale/backups/"* "$tmp/before" && ok "backup is the old file" || bad "backup"
[ "$(grep -c '^interface_branding:' "$conf")" = 1 ] && ok "no duplicate keys" || bad "duplicates"

# ---- margin, soft edge, text size
fresh
rc=$(run apply '{"margin":120,"marginGradient":16,"fontScale":"2x2"}')
[ "$rc" = 0 ] && grep -qx 'term_margin: 120' "$conf" && grep -qx 'term_margin_gradient: 16' "$conf" && grep -qx 'term_font_scale: 2x2' "$conf" && ok "margin, soft edge and text size set" || bad "margin/scale rc=$rc $(cat "$tmp/err")"
rc=$(run apply '{"margin":null,"marginGradient":null,"fontScale":null}')
[ "$rc" = 0 ] && ! grep -q '^term_margin\|^term_font_scale' "$conf" && ok "null gives them back to Limine" || bad "margin/scale removal"
rc=$(run apply '{"margin":80,"fontScale":"3x3"}'); rc=$(run restore-default)
[ "$rc" = 0 ] && ! grep -q '^term_margin\|^term_font_scale' "$conf" && ok "restore-default drops them" || bad "restore-default margin/scale"

# ---- dry run
fresh; cp "$conf" "$tmp/before"
rc=$(run apply '{"branding":"X"}' --dry-run)
[ "$rc" = 0 ] && cmp -s "$conf" "$tmp/before" && [ ! -e "$tmp/enroll.log" ] && grep -q '^+interface_branding: X' "$tmp/out" && ok "dry run shows a diff, writes nothing" || bad "dry run"

# ---- refusals leave the file alone
fresh; cp "$conf" "$tmp/before"; mkfifo "$tmp/fifo"; ln -s /etc/passwd "$tmp/passwd-link"
head -c 17000000 /dev/zero | { printf '\x89PNG\r\n\x1a\n'; cat; } > "$tmp/huge.png"; cp "$png" "$esp/inside.png"
for bad_json in \
  '{"branding":"two\nlines"}' '{"branding":""}' '{"branding":"'"$(printf 'x%.0s' {1..70})"'"}' \
  '{"brandingColor":"12345"}' '{"brandingColor":"zzzzzz"}' '{"foreground":"#ffffff"}' \
  '{"timeout":0}' '{"timeout":31}' '{"timeout":"5"}' '{"timeout":true}' '{"rememberLast":"yes"}' \
  '{"backgroundAlpha":10}' '{"background":"000000","backgroundAlpha":300}' '{"wallpaperStyle":"fit"}' \
  '{"margin":-1}' '{"margin":241}' '{"margin":"64"}' '{"margin":true}' '{"marginGradient":65}' \
  '{"fontScale":"5x5"}' '{"fontScale":"2x1"}' '{"fontScale":2}' '{"default_entry":"1"}' '{"wallpaper":"relative.png"}' '{"wallpaper":"/etc/passwd"}' \
  '{"wallpaper":"'"$tmp"'/passwd-link"}' '{"wallpaper":"'"$tmp"'/huge.png"}' '{"wallpaper":"'"$tmp"'/fifo"}' \
  '{"wallpaper":"'"$esp"'/inside.png"}' '{"wallpaper":"'"$tmp"'/missing.png"}' '[1]' 'not json'; do
  rc=$(run apply "$bad_json")
  if [ "$rc" = 4 ] && cmp -s "$conf" "$tmp/before"; then :; else bad "refused: $bad_json (rc=$rc)"; fi
done
[ ! -e "$tmp/enroll.log" ] && ok "every bad input refused, file untouched, nothing enrolled" || bad "refusals enrolled"

# ---- wallpaper
fresh; cp "$conf" "$tmp/before"
rc=$(run apply '{"wallpaper":"'"$png"'","wallpaperStyle":"centered","backdrop":"000000"}')
[ "$rc" = 0 ] && grep -qx 'wallpaper: boot():/omacale/wallpaper.png' "$conf" && cmp -s "$png" "$esp/omacale/wallpaper.png" && ok "wallpaper copied onto the ESP and named" || bad "wallpaper rc=$rc $(cat "$tmp/err")"
grep -qx 'wallpaper_style: centered' "$conf" && grep -qx 'backdrop: 000000' "$conf" && ok "wallpaper style and backdrop" || bad "style/backdrop"
jpg="$tmp/w.jpg"; printf '\xff\xd8\xff\xe0jpegdata' > "$jpg"
rc=$(run apply '{"wallpaper":"'"$jpg"'"}')
[ -e "$esp/omacale/wallpaper.jpg" ] && [ ! -e "$esp/omacale/wallpaper.png" ] && grep -qx 'wallpaper: boot():/omacale/wallpaper.jpg' "$conf" && ok "a new wallpaper replaces the old file" || bad "wallpaper replace"
rc=$(run apply '{"wallpaper":""}')
! grep -q '^wallpaper' "$conf" && ok "an empty wallpaper removes its lines" || bad "wallpaper removal"
[ "$(entries_of "$conf")" = "$(entries_of "$tmp/before")" ] && ok "entries unchanged through wallpaper changes" || bad "entries (wallpaper)"

# ---- enroll failure rolls back
fresh; cp "$conf" "$tmp/before"; touch "$tmp/enroll.fail"
rc=$(run apply '{"branding":"Broken"}')
[ "$rc" = 5 ] && cmp -s "$conf" "$tmp/before" && [ "$(grep -c enrolled "$tmp/enroll.log")" = 2 ] && ok "enroll failure: old file back and enrolled again" || bad "rollback rc=$rc"

# ---- undo and restore-default
fresh; cp "$conf" "$tmp/v0"
run apply '{"branding":"One"}' >/dev/null; cp "$conf" "$tmp/v1"
run apply '{"branding":"Two"}' >/dev/null
rc=$(run undo); [ "$rc" = 0 ] && cmp -s "$conf" "$tmp/v1" && ok "undo goes back one step" || bad "undo 1 rc=$rc $(cat "$tmp/err")"
rc=$(run undo); [ "$rc" = 0 ] && cmp -s "$conf" "$tmp/v0" && ok "undo again goes back to the start" || bad "undo 2"
rc=$(run undo); [ "$rc" = 4 ] && cmp -s "$conf" "$tmp/v0" && ok "nothing left to undo is refused" || bad "undo 3 rc=$rc"
fresh; cp "$conf" "$tmp/v0"
run apply '{"branding":"Mine","timeout":9,"hideHelp":true,"wallpaper":"'"$png"'"}' >/dev/null
rc=$(run restore-default)
[ "$rc" = 0 ] && cmp -s "$conf" "$tmp/v0" && [ ! -e "$esp/omacale/wallpaper.png" ] && ok "restore-default gives Omarchy's file back, wallpaper removed" || bad "restore-default rc=$rc"
fresh; run apply '{"wallpaper":"'"$png"'"}' >/dev/null; run apply '{"branding":"B"}' >/dev/null; rm "$esp/omacale/wallpaper.png"
run undo >/dev/null; ! grep -q '^wallpaper:' "$conf" && ok "undo drops a wallpaper whose file is gone" || bad "undo missing wallpaper"

# ---- backups rotate
fresh; for i in 1 2 3 4 5 6 7; do run apply '{"branding":"N'$i'"}' >/dev/null; done
[ "$(ls "$esp/omacale/backups" | wc -l)" = 5 ] && ok "at most five backups" || bad "rotation"

# ---- shapes of the file
fresh; sed -i 's/$/\r/' "$conf"; cp "$conf" "$tmp/before"
run apply '{"branding":"CRLF"}' >/dev/null
grep -q $'^interface_branding: CRLF\r$' "$conf" && [ "$(entries_of "$conf")" = "$(entries_of "$tmp/before")" ] && ok "CRLF kept" || bad "CRLF"
printf 'timeout: 3\ninterface_branding: A\n' > "$conf"; cp "$conf" "$tmp/before"
rc=$(run apply '{"branding":"B"}'); [ "$rc" = 4 ] && cmp -s "$conf" "$tmp/before" && ok "a file without entries is refused" || bad "no entries rc=$rc"
{ printf 'interface_branding: A\ninterface_branding: B\ninterface_branding_colour: 111111\n'; printf '%s' "$entries"; } > "$conf"
run apply '{"branding":"C","brandingColor":"222222"}' >/dev/null
[ "$(grep -c '^interface_branding:' "$conf")" = 1 ] && ! grep -q 'colour' "$conf" && grep -qx 'interface_branding_color: 222222' "$conf" && ok "duplicates and the colour alias collapse" || bad "duplicates/alias"

# ---- status, and the root guard
fresh; run apply '{"branding":"S"}' >/dev/null
rc=$(run status); [ "$rc" = 0 ] && python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["interface_branding"]=="S" and d["backups"]==1' "$tmp/out" && ok "status reports the look" || bad "status"
rc=$(env -u LIMINE_STYLE_ROOT "$tool" status 2>/dev/null; echo $?)
[ "${rc##*$'\n'}" = 2 ] && ok "without root (and outside the tests) it refuses" || bad "root guard rc=$rc"
[ ! -e "$here/scripts/__pycache__" ] && ok "no bytecode written into the plugin" || bad "__pycache__ written"

echo
[ "$fails" = 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
