pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Settings › Wallpaper & style › "Colour Omarchy's menus too": with the
// Material palette, Omarchy's own menus, popups, notifications, launcher,
// polkit prompt and image picker are drawn in Omacale's colours too. Omacale
// keeps one marked block in Omarchy's user shell.toml (scripts/shell-toml),
// which Omarchy watches live and lets win over the theme (Color.qml
// mergeShell). Off, or with the Omarchy palette (the theme's own colours
// already), the block is taken out again; uninstall removes it as well.
// Limit: Omarchy's Ui kit reads the base accent/foreground from the theme's
// colors.toml, which shell.toml can't change.
QtObject {
  id: root

  readonly property string script: String(Qt.resolvedUrl("../scripts/shell-toml")).replace("file://", "")
  readonly property bool on: Config.loaded && Config.o.appearance.omarchySurfaces && !Colours.omarchy

  function hex(c) {
    return "#" + [c.r, c.g, c.b].map(v => ("0" + Math.round(v * 255).toString(16)).slice(-2)).join("")
  }
  // section.key=value lines, Omarchy's shell.toml names; alpha keys stay the
  // theme's. Laid out as Omarchy's own template is (selection as a light
  // veil of the text colour with primary text), in Omacale's roles.
  readonly property string spec: {
    if (!on) return ""
    // Surfaces from the opaque palette (the m3surface* roles carry Omacale's
    // transparency); the rest are opaque roles already.
    const p = Colours.palette
    const S = hex(p.m3surfaceContainer), B = hex(p.m3surface)
    const T = hex(Colours.m3onSurface), O = hex(Colours.m3outlineVariant)
    const P = hex(Colours.m3primary), E = hex(Colours.m3error)
    const lines = []
    const put = (section, pairs) => { for (const k in pairs) lines.push(section + "." + k + "=" + pairs[k]) }
    const panel = { background: S, text: T, border: O }
    put("popups", panel)
    put("tooltip", panel)
    put("notifications", Object.assign({ countdown: P }, panel))
    const list = Object.assign({ scrim: B, "selected-background": T, "selected-text": P, "selected-border": O }, panel)
    put("launcher", list)
    put("menu", list)
    put("polkit", Object.assign({ "text-error": E, "border-error": E }, panel))
    put("image-picker", { scrim: B, text: T, "selected-border": P, "unselected-border": O })
    put("controls", { "normal-color": T, "normal-border": O, "hover-cursor-color": T, "hover-cursor-border": O,
      "focus-color": T, "focus-border": P, "selected-color": P, "selected-border": P })
    return lines.join("\n")
  }

  // Written a moment after the palette settles (a seed drag changes it many
  // times), and only when it changed.
  property string written: ""
  onSpecChanged: if (Config.loaded) debounce.restart()
  onOnChanged: debounce.restart()
  property Timer debounce: Timer {
    interval: 800
    onTriggered: {
      if (root.spec === root.written) return
      writer.command = root.spec ? ["python3", root.script, "set", root.spec] : ["python3", root.script, "remove"]
      writer.running = true
      root.written = root.spec
    }
  }
  property Process writer: Process {
    environment: ({ PYTHONDONTWRITEBYTECODE: "1" })
  }
  // Off at start: make sure no block is left from before (a no-op when none is).
  Component.onCompleted: { written = "-"; debounce.restart() }
}
