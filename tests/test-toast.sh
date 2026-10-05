#!/usr/bin/env bash
# Shows each kind of toast on the live desktop, a couple of seconds apart, for
# a preview: notification popups (normal, with actions, critical), Omacale's
# utilities toasts (info, success, warning, error) and Omarchy's OSD (sliders
# and messages; with Omacale's OSD handover on, these draw as Omacale's
# sliders and toasts).
#   tests/test-toast.sh            all of them
#   tests/test-toast.sh notifs     notification popups only
#   tests/test-toast.sh toasts     utilities toasts only
#   tests/test-toast.sh osd        OSD only
set -Eeuo pipefail

gap="${GAP:-2}"
which="${1:-all}"

notifs() {
  notify-send -a "Omacale" -i dialog-information \
    "Hello from Omacale" "A normal notification popup."
  sleep "$gap"
  # Waits in the background for a click, so the script carries on.
  notify-send -a "Messages" -i mail-message-new -A open=Open -A later=Later \
    "Alex" "Are we still on for tonight? This one has actions." &
  sleep "$gap"
  notify-send -a "System" -i dialog-warning -u critical \
    "Battery low" "A critical notification stays until dismissed."
  sleep "$gap"
}

toasts() {
  omarchy-shell omacale toast info "Info" "An info toast." info
  sleep "$gap"
  omarchy-shell omacale toast success "Saved" "A success toast." check_circle
  sleep "$gap"
  omarchy-shell omacale toast warning "Careful" "A warning toast." warning
  sleep "$gap"
  omarchy-shell omacale toast error "Failed" "An error toast." error
  sleep "$gap"
}

# Only shows the OSD: nothing here changes the volume or brightness.
osd() {
  omarchy-osd -i volume-medium -p 45
  sleep "$gap"
  omarchy-osd -i brightness -p 70
  sleep "$gap"
  omarchy-osd -i microphone-muted -m "Microphone muted"
  sleep "$gap"
  omarchy-osd -i keyboard -m "Keyboard backlight 2/3"
  sleep "$gap"
  omarchy-osd -i media-play -m "Now playing: Test track"
  sleep "$gap"
  omarchy-osd -i touchpad -m "Touchpad disabled"
  sleep "$gap"
  omarchy-osd -m "A plain OSD message"
}

case $which in
  all) notifs; toasts; osd ;;
  notifs) notifs ;;
  toasts) toasts ;;
  osd) osd ;;
  *) echo "usage: $0 [all|notifs|toasts|osd]" >&2; exit 2 ;;
esac
