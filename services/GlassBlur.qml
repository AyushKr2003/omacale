pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import ".."

// GlassBlur: Hyprland's blur, tuned for glass while Settings › Glass wants it
// (Glass.tuneBlur). The glass is only as clean as the blur under it, and that
// blur is the user's: a grainy `noise` (0.1 is ~8x Hyprland's default) or a
// strong `vibrancy` reads as dirt and neon through a clear body, and a size x
// passes made for opaque windows smears what is behind past recognising.
// Hyprland 0.56 has no per-layer blur size, noise or vibrancy (a layer rule
// takes `blur`, `ignore_alpha`, `xray`, `blur_popups` only), so this sets the
// global ones, at runtime, as HyprLook does the gaps:
//
//   - the user's own values are read once and kept in
//     $XDG_RUNTIME_DIR/omacale-glass-blur.orig, and put back, and the file
//     removed, when glass or the tuning goes off;
//   - `hyprctl reload` re-reads the user's config, so the kept values are
//     read again from it and the tuning re-applied;
//   - a shell restart finds the file and leaves it: Hyprland still runs ours.
QtObject {
  id: root

  readonly property bool want: Glass.enabled && Glass.tuneBlur
  readonly property int size: Glass.frost
  // Hyprland's blur grows with size x 2^passes: a second pass past a small
  // size, a third for heavy frost (as Vitreus's Glass page does).
  readonly property int passes: size <= 3 ? 1 : size <= 8 ? 2 : 3
  readonly property string args: (want ? "on" : "off") + " " + size + " " + passes

  function run(mode) {
    if (job.running) { pending = mode; return }
    job.command = ["bash", "-c", script, "glassblur", mode, String(size), String(passes)]
    job.running = true
  }
  property string pending: ""

  onArgsChanged: push.restart()
  Component.onCompleted: push.restart()
  property Timer push: Timer {
    interval: 300
    onTriggered: root.run(root.want ? "on" : "off")
  }
  property Connections reloads: Connections {
    target: Hyprland
    function onRawEvent(e) { if (e.name === "configreloaded") root.run(root.want ? "reload" : "off") }
  }

  property Process job: Process {
    onExited: if (root.pending !== "") { const m = root.pending; root.pending = ""; root.run(m) }
  }
  readonly property string script: `
    f="\${XDG_RUNTIME_DIR:?}/omacale-glass-blur.orig"
    get() { hyprctl getoption "decoration:blur:$1" 2>/dev/null | awk 'NR==1 { print $2 }'; }
    keep() {
      e=$(get enabled); s=$(get size); p=$(get passes); n=$(get noise); v=$(get vibrancy)
      case "$e" in true|false|0|1) ;; *) return 1 ;; esac
      [ "$e" = 1 ] && e=true; [ "$e" = 0 ] && e=false
      printf 'enabled = %s, size = %d, passes = %d, noise = %s, vibrancy = %s' "$e" "$s" "$p" "$n" "$v" > "$f.tmp" && mv "$f.tmp" "$f"
    }
    tune() { hyprctl eval "hl.config({ decoration = { blur = { enabled = true, size = $1, passes = $2, noise = 0.0117, vibrancy = 0.1696 } } })" >/dev/null; }
    case "$1" in
      on) [ -f "$f" ] || keep || exit 1; tune "$2" "$3" ;;
      reload) keep || exit 1; tune "$2" "$3" ;;
      off)
        [ -f "$f" ] || exit 0
        # Only numbers and booleans go back to Hyprland.
        grep -qE '^enabled = (true|false), size = [0-9]+, passes = [0-9]+, noise = [0-9.]+, vibrancy = [0-9.]+$' "$f" \\
          && hyprctl eval "hl.config({ decoration = { blur = { $(cat "$f") } } })" >/dev/null
        rm -f "$f" ;;
    esac
  `
}
