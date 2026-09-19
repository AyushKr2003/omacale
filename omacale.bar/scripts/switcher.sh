#!/usr/bin/env bash
# Omacale wallpaper/theme switcher helper.
#
# Omarchy's pickers (omarchy-theme-bg-switcher, omarchy-theme-switcher) only
# hand their lists to their own image menu, and Omarchy has no command that
# prints them. This script lists the same sources so Omacale's launcher
# carousel can show them.
#
# usage:
#   switcher.sh walls       current:<path>, then <image>\t<thumbnail> per background
#   switcher.sh themes      current:<name>, then <name>\t<label>\t<preview> per theme
#   switcher.sh menu off    remove the menu-route block older Omacale versions
#                           wrote to Omarchy's omarchy-menu.jsonc
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

# ------------------------------------------------------ old menu-route block
# Omacale no longer writes Omarchy's menu extension. Older versions added a
# block (between these markers) overriding the "background" and "theme"
# routes; this removes it, and the file too if Omacale had created it.
ext="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
begin="// >>> omacale switcher"
end="// <<< omacale switcher"

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

case "${1:-}" in
  walls) walls ;;
  themes) themes ;;
  menu) [[ ${2:-} == off ]] && menu_off || exit 2 ;;
  *) sed -n '9,13p' "$0"; exit 2 ;;
esac
