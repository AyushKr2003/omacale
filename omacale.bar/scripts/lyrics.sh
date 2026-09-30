#!/usr/bin/env bash
# Omacale lyrics helper — synced (LRC) lyrics from lrclib.net, the same
# primary source Caelestia uses. Prints the LRC text, or nothing.
# usage: lyrics.sh <artist> <title> [album] [duration-seconds]
set -uo pipefail
uri() { jq -rn --arg s "$1" '$s|@uri'; }
ua="omacale (Omarchy shell; https://github.com/caelestia-dots/shell design)"
artist="${1:-}"; title="${2:-}"; album="${3:-}"; dur="${4:-}"
[[ -n $title ]] || exit 0

q="artist_name=$(uri "$artist")&track_name=$(uri "$title")"
[[ -n $album ]] && q+="&album_name=$(uri "$album")"
[[ -n $dur && $dur -gt 0 ]] && q+="&duration=$dur"

# lrclib has junk uploads ("[00:00.00]probe"), so require a real song's worth
# of timed lines, and prefer the closest duration among search results.
good() { [[ $(grep -cE '^\[[0-9]+:[0-9]+' <<<"$1") -ge 6 ]]; }

# The record lrclib matched: its lyrics, and which track it is (shown in
# the dashboard's lyrics info, Caelestia's "Selected candidate").
rec=$(curl -fsS --max-time 8 -A "$ua" "https://lrclib.net/api/get?$q" 2>/dev/null)
s=$(jq -r '.syncedLyrics // empty' 2>/dev/null <<<"$rec")
if ! good "$s"; then
  rec=$(curl -fsS --max-time 8 -A "$ua" "https://lrclib.net/api/search?artist_name=$(uri "$artist")&track_name=$(uri "$title")" 2>/dev/null \
      | jq -c --argjson d "${dur:-0}" '
          map(select((.syncedLyrics // "") | test("\\[[0-9]+:[0-9]+.*\\n.*\\[[0-9]+:[0-9]+.*\\n.*\\[[0-9]+:[0-9]+.*\\n.*\\[[0-9]+:[0-9]+.*\\n.*\\[[0-9]+:[0-9]+.*\\n.*\\[[0-9]+:[0-9]+")))
          | sort_by(if $d > 0 then ((.duration // 0) - $d | fabs) else 0 end)
          | .[0] // empty' 2>/dev/null)
  s=$(jq -r '.syncedLyrics // empty' 2>/dev/null <<<"$rec")
fi
if good "$s"; then
  # One header line the LRC parser skips: "#match<TAB>title<TAB>artist<TAB>album".
  jq -r '"#match\t" + ([.trackName, .artistName, .albumName] | map(. // "" | gsub("[\t\n]"; " ")) | join("\t"))' 2>/dev/null <<<"$rec"
  printf '%s' "$s"
fi
