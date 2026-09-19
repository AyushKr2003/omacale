#!/usr/bin/env bash
# Omacale wallpaper/theme switcher helper.
#
# Omarchy's pickers (omarchy-theme-bg-switcher, omarchy-theme-switcher) only
# hand their lists to their own image menu, and Omarchy has no command that
# prints them. This script lists the same sources so Omacale's launcher
# carousel can show them, and switches Omarchy's menu routes between the two
# pickers.
#
# usage:
#   switcher.sh walls       current:<path>, then <image>\t<thumbnail> per background
#   switcher.sh themes      current:<name>, then <name>\t<label>\t<preview> per theme
#   switcher.sh menu on|off add/remove Omacale's override of the "background"
#                           and "theme" menu routes (SUPER+CTRL+SPACE, ...)
set -uo pipefail

state="$HOME/.local/state/omarchy/current"
omarchy="${OMARCHY_PATH:-/usr/share/omarchy}"
media='.*\.(jpe?g|png|gif|bmp|webp|mp4|m4v|mov|webm|mkv|avi)$'

walls() {
  local theme dirs cache rows
  theme=$(cat "$state/theme.name" 2>/dev/null)
  dirs=("$state/theme/backgrounds" "$HOME/.config/omarchy/backgrounds/$theme")
  echo "current:$(readlink -f "$state/background" 2>/dev/null)"

  # Omarchy's own thumbnail cache (the one its background picker uses).
  omarchy-theme-bg-cache >/dev/null 2>&1
  cache="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy/image-selector"
  rows="$cache/$(printf '%s\n%s' "${dirs[@]}" | md5sum | cut -d' ' -f1).rows"
  if [[ -s $rows ]]; then
    cat "$rows"; echo
    return
  fi
  # No cache (e.g. the format changed): the images stand in for thumbnails.
  find -L "${dirs[@]}" -maxdepth 1 -type f -regextype posix-extended -iregex "$media" 2>/dev/null \
    | sort | while IFS= read -r f; do printf '%s\t%s\n' "$f" "$f"; done
}

# Mirrors omarchy-theme-switcher's find_preview.
preview_for() {
  local dir=$1 name
  for name in preview.png preview.jpg preview.jpeg preview.webp; do
    [[ -f $dir/$name ]] && { echo "$dir/$name"; return; }
  done
  find -L "$dir/backgrounds" -maxdepth 1 -type f -regextype posix-extended \
    -iregex '.*\.(jpe?g|png|gif|bmp|webp)$' 2>/dev/null | sort | head -n1
}

themes() {
  local dir name preview seen=" "
  echo "current:$(cat "$state/theme.name" 2>/dev/null)"
  for dir in "$HOME/.config/omarchy/themes"/* "$omarchy/themes"/*; do
    [[ -d $dir ]] || continue
    name=${dir##*/}
    [[ $seen == *" $name "* ]] && continue
    seen+="$name "
    preview=$(preview_for "$dir")
    [[ -n $preview ]] || preview=$(preview_for "$omarchy/themes/$name")
    printf '%s\t%s\t%s\n' "$name" "$(sed -E 's/(^|-)([a-z])/\1\u\2/g; s/-/ /g' <<<"$name")" "$preview"
  done
}

# ---------------------------------------------------------------- menu routes
# The block reuses the default ids, so Omarchy keeps the label/icon/aliases and
# only the action changes. If Omacale is not running, or its switcher setting
# is off, the action falls through to Omarchy's own picker.
ext="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
begin="// >>> omacale switcher"
end="// <<< omacale switcher"

default_action() {
  grep -m1 "^ *\"$1\":" "$omarchy/default/omarchy/omarchy-menu.jsonc" \
    | sed -E "s/^ *\"$1\": *//; s/, *$//" | jq -r '.action // empty'
}

menu_off() {
  [[ -f $ext ]] && grep -qF "$begin" "$ext" || return 0
  local created=0 dir=0
  grep -qF "$begin (created" "$ext" && created=1
  grep -qF "$begin (created, dir)" "$ext" && dir=1
  sed -i "\|$begin|,\|$end|d" "$ext"
  # Created by Omacale and now empty again: put things back as they were.
  if (( created )) && [[ -z $(tr -d '{} \n\t' <"$ext") ]]; then
    rm -f "$ext"
    (( dir )) && rmdir "${ext%/*}" 2>/dev/null
  fi
  return 0
}

menu_block() { # menu_block <tag>
  local bg theme
  bg=$(default_action style.background)
  theme=$(default_action style.theme)
  [[ -n $bg && -n $theme ]] || { echo "switcher: Omarchy's default menu actions not found" >&2; exit 1; }
  jq -rn --arg bg "$bg" --arg theme "$theme" --arg begin "$begin$1" --arg end "$end" '
    def route(kind; fallback):
      { action: "[[ $(omarchy-shell omacale switcher \(kind) 2>/dev/null) == ok ]] || { \(fallback); }" } | tojson;
    "  \($begin) — managed by Omacale (Settings › Style › Switcher)",
    "  \"style.background\": \(route("wallpaper"; $bg)),",
    "  \"style.theme\": \(route("theme"; $theme)),",
    "  \($end)"'
}

menu_on() {
  local block tag=""
  # Runs on every shell start: leave the file alone when it is already current.
  if [[ -f $ext ]] && grep -qF "$begin" "$ext"; then
    tag=$(grep -oF -e "$begin (created, dir)" -e "$begin (created)" "$ext" | head -n1)
    tag=${tag#"$begin"}
    block=$(menu_block "$tag") || exit 1
    [[ $(sed -n "\|$begin|,\|$end|p" "$ext") == "$block" ]] && return 0
  fi
  menu_off
  tag=""
  if [[ ! -f $ext ]]; then
    tag=" (created)"
    [[ -d ${ext%/*} ]] || { mkdir -p "${ext%/*}"; tag=" (created, dir)"; }
    printf '{\n}\n' >"$ext"
  fi
  block=$(menu_block "$tag") || exit 1
  # Insert right after the opening brace.
  # (ENVIRON, not -v: awk -v would unescape the JSON's \" quotes.)
  BLOCK=$block awk '!done && /^[[:space:]]*\{/ { print; print ENVIRON["BLOCK"]; done = 1; next } { print }' "$ext" >"$ext.tmp" \
    && mv -f "$ext.tmp" "$ext"
}

case "${1:-}" in
  walls) walls ;;
  themes) themes ;;
  menu) case "${2:-}" in on) menu_on ;; off) menu_off ;; *) exit 2 ;; esac ;;
  *) sed -n '10,15p' "$0"; exit 2 ;;
esac
