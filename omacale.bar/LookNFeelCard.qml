import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Omacale look'n'feel, read from omacale.lua (Caelestia's Hyprland styling).
// Copy the loader line for ~/.config/hypr/looknfeel.lua, copy one value as
// its own hl.config() line, or try the whole file for this session only:
// `hyprctl eval dofile(...)`, undone by `hyprctl reload`, and nothing is
// written to ~/.config/hypr.
ColumnLayout {
  id: root
  property var settings
  property var row
  property bool first
  property bool last
  spacing: Tk.spacing.extraSmall / 2

  readonly property string file: String(Qt.resolvedUrl("omacale.lua")).replace("file://", "")
  readonly property string userFile: Quickshell.env("HOME") + "/.config/hypr/looknfeel.lua"
  readonly property string loader: "-- Omacale look'n'feel (Caelestia styling). Keep your own tweaks below it.\n"
    + "pcall(dofile, os.getenv(\"HOME\") .. \"/.config/omarchy/plugins/omacale.bar/omacale.lua\")"

  property string source: ""
  property var groups: []       // { title, vars: [{ name, raw, opt, uses }] }
  property int animations: 0
  property var live: ({})       // hyprland option -> current value
  property bool loaded: false   // omacale.lua is dofile'd from looknfeel.lua
  property bool tried: false
  property string toast: ""

  readonly property var opts: groups.reduce((a, g) => a.concat(g.vars.filter(v => v.opt).map(v => v.opt)), [])
  readonly property int appliedCount: groups.reduce((n, g) => n + g.vars.filter(v => v.opt && applied(v)).length, 0)
  readonly property bool allApplied: opts.length > 0 && appliedCount === opts.length

  readonly property var labels: ({
    blurEnabled: "Blur", blurSpecialWs: "Blur special workspace", blurPopups: "Blur popups",
    blurInputMethods: "Blur input methods", blurSize: "Blur size", blurPasses: "Blur passes", blurXray: "Blur x-ray",
    shadowEnabled: "Shadow", shadowRange: "Shadow range", shadowRenderPower: "Shadow render power",
    workspaceGaps: "Gaps between workspaces", windowGapsIn: "Gaps between windows",
    windowGapsOut: "Gaps to the screen edge", singleWindowGapsOut: "Gaps around a lone window",
    windowOpacity: "Window opacity", windowRounding: "Window rounding", windowBorderSize: "Border size"
  })

  FileView {
    path: root.file
    printErrors: false
    onLoaded: root.parse(String(text()))
  }
  FileView {
    path: root.userFile
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.loaded = String(text()).split("\n").some(l => /omacale\.lua/.test(l) && !/^\s*--/.test(l))
    onLoadFailed: root.loaded = false
  }

  Process {
    id: optProbe
    command: ["hyprctl", "-j", "--batch", root.opts.map(o => "getoption " + o).join("; ")]
    stdout: StdioCollector {
      onStreamFinished: {
        const l = {}
        ;(text.match(/\{[^{}]*\}/g) || []).forEach(s => {
          try {
            const o = JSON.parse(s)
            if ("bool" in o) l[o.option] = o.bool
            else if ("int" in o) l[o.option] = o.int
            else if ("float" in o) l[o.option] = o.float
            else if ("css" in o) l[o.option] = parseFloat(String(o.css).split(" ")[0])
          } catch (e) {}
        })
        root.live = l
      }
    }
  }
  Timer { id: reprobe; interval: 600; onTriggered: if (root.opts.length) optProbe.running = true }
  Timer { id: toastTimer; interval: 2600; onTriggered: root.toast = "" }

  // vars table -> groups (by its "-- Heading" comments); hl.config() keys
  // assigned from vars.X -> the Hyprland option path for X; top-level
  // hl.*/o.* calls that use vars.X (rules) for the vars with no option.
  function parse(t) {
    source = t
    const lines = t.split("\n")
    const out = [], optOf = {}, raws = {}
    let inVars = false, inCfg = false, stack = []
    lines.forEach(l => {
      if (/^local vars = \{/.test(l)) { inVars = true; return }
      if (inVars) {
        if (/^\}/.test(l)) { inVars = false; return }
        const h = l.match(/^\s*--\s*(.+)$/)
        if (h) { out.push({ title: h[1].trim(), vars: [] }); return }
        const v = l.match(/^\s*(\w+)\s*=\s*([^,]+),/)
        if (v) {
          if (!out.length) out.push({ title: "", vars: [] })
          raws[v[1]] = v[2].trim()
          out[out.length - 1].vars.push({ name: v[1], raw: v[2].trim(), opt: "", uses: [] })
        }
        return
      }
      if (/^hl\.config\(\{/.test(l)) { inCfg = true; stack = []; return }
      if (inCfg) {
        if (/^\}\)/.test(l)) { inCfg = false; return }
        let m = l.match(/^\s*(\w+)\s*=\s*\{\s*$/)
        if (m) { stack.push(m[1]); return }
        if (/^\s*\},?\s*$/.test(l)) { stack.pop(); return }
        m = l.match(/^\s*(\w+)\s*=\s*vars\.(\w+)/)
        if (m) optOf[m[2]] = stack.concat(m[1]).join(":")
      }
    })
    const subst = s => s.replace(/vars\.(\w+)/g, (_, n) => raws[n] !== undefined ? raws[n] : "nil")
    out.forEach(g => g.vars.forEach(v => {
      v.opt = optOf[v.name] || ""
      v.uses = lines.filter(l => /^(hl|o)\.\w+\(/.test(l) && new RegExp("vars\\." + v.name + "\\b").test(l)).map(subst)
    }))
    groups = out.filter(g => g.vars.length)
    animations = lines.filter(l => /^hl\.animation\(/.test(l)).length
    reprobe.restart()
  }

  function value(v) { return v.raw === "true" ? true : v.raw === "false" ? false : parseFloat(v.raw) }
  function applied(v) {
    if (!(v.opt in live)) return false
    const a = value(v), b = live[v.opt]
    return typeof a === "boolean" ? a === b : Math.abs(a - b) < 0.001
  }
  function fmt(x, name) {
    if (typeof x === "boolean") return x ? "On" : "Off"
    return /Gaps|Size|Rounding|Range/.test(name) ? x + "px" : String(x)
  }
  // One value as a line of its own: a nested hl.config() for an option, or
  // the rule lines it feeds.
  function snippet(v) {
    if (!v.opt) return v.uses.join("\n")
    const keys = v.opt.split(":")
    return "hl.config({ " + keys.map(k => k + " = ").join("{ ").replace(/= $/, "= " + v.raw) + " }".repeat(keys.length - 1) + " })"
  }

  function copy(text, what) {
    Quickshell.execDetached(["wl-copy", text])
    toast = what + " copied to the clipboard"
    toastTimer.restart()
  }
  function tryIt() {
    if (loaded) { toast = "Already loaded from looknfeel.lua"; toastTimer.restart(); return }
    Quickshell.execDetached(["hyprctl", "eval", 'dofile("' + file + '")'])
    tried = true
    toast = "Omacale look'n'feel active until Hyprland reloads"
    toastTimer.restart()
    reprobe.restart()
  }
  function revert() {
    // Re-reading the user's config is the only way to drop runtime config,
    // rules and curves; it also drops "Try this session" keybinds.
    Quickshell.execDetached(["hyprctl", "reload"])
    tried = false
    toast = "Hyprland reloaded from your own config"
    toastTimer.restart()
    reprobe.restart()
  }

  // ---- intro card
  ConnectedRect {
    Layout.fillWidth: true
    first: true
    implicitHeight: intro.implicitHeight + Tk.padding.largeIncreased * 2
    ColumnLayout {
      id: intro
      anchors.fill: parent
      anchors.margins: Tk.padding.largeIncreased
      spacing: Tk.spacing.large
      RowLayout {
        spacing: Tk.spacing.large
        MShape {
          implicitSize: 56
          shape: "cookie9"
          color: Colours.m3primaryContainer
          MIcon { anchors.centerIn: parent; text: "auto_awesome"; size: Tk.iconSize.large; fill: 1; color: Colours.m3onPrimaryContainer }
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          RowLayout {
            spacing: Tk.spacing.medium
            MText { text: "Caelestia look'n'feel"; font.pointSize: Tk.title.small; weight: Font.Medium }
            StatusChip {
              active: root.loaded || root.allApplied
              text: root.loaded ? "Loaded" : root.allApplied ? "Active this session" : root.appliedCount + " / " + root.opts.length + " applied"
            }
          }
          MText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Colours.m3onSurfaceVariant
            text: "Load omacale.lua from ~/.config/hypr/looknfeel.lua, above your own tweaks so they still win. It is wrapped in pcall, so Hyprland keeps starting after uninstalling."
          }
        }
      }
      Flow {
        Layout.fillWidth: true
        spacing: Tk.spacing.small
        Pill { icon: "content_copy"; label: "Copy loader"; filled: true; onClicked: root.copy(root.loader, "Loader") }
        Pill { icon: "play_arrow"; label: "Try this session"; visible: !root.loaded; onClicked: root.tryIt() }
        Pill { icon: "undo"; label: "Revert"; visible: !root.loaded && (root.tried || root.allApplied); onClicked: root.revert() }
        Pill { icon: "description"; label: "Copy file"; onClicked: root.copy(root.source, "omacale.lua") }
        Pill { icon: "edit"; label: "Open looknfeel.lua"; onClicked: Quickshell.execDetached(["omarchy-launch-editor", root.userFile]) }
      }
      MText {
        Layout.fillWidth: true
        visible: root.toast !== ""
        text: root.toast
        color: Colours.m3primary
        weight: Font.Medium
      }
    }
  }
  ConnectedRect {
    Layout.fillWidth: true
    last: true
    implicitHeight: hint.implicitHeight + Tk.padding.medium * 2
    MText {
      id: hint
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.largeIncreased
      wrapMode: Text.WordWrap
      color: Colours.m3outline
      font.pointSize: Tk.label.small
      text: "Also sets Material 3 curves for " + root.animations + " animations (windows, layers, workspaces) and fade rules for Omacale's own layers. Border colours stay with your Omarchy theme."
    }
  }

  // ---- values, grouped as in omacale.lua's vars table
  Repeater {
    model: root.groups
    ColumnLayout {
      id: grp
      required property var modelData
      Layout.fillWidth: true
      spacing: Tk.spacing.extraSmall / 2
      MText {
        Layout.fillWidth: true
        Layout.topMargin: Tk.spacing.largeIncreased
        Layout.bottomMargin: Tk.spacing.extraSmall
        Layout.leftMargin: Tk.padding.small
        text: grp.modelData.title
        color: Colours.m3onSurfaceVariant
        font.pointSize: Tk.label.medium
      }
      Repeater {
        model: grp.modelData.vars
        VarRow { required property var modelData; required property int index; v: modelData; first: index === 0; last: index === grp.modelData.vars.length - 1 }
      }
    }
  }

  MText {
    Layout.fillWidth: true
    Layout.topMargin: Tk.spacing.largeIncreased
    Layout.bottomMargin: Tk.spacing.extraSmall
    Layout.leftMargin: Tk.padding.small
    text: "Snippet — add to ~/.config/hypr/looknfeel.lua"
    color: Colours.m3onSurfaceVariant
    font.pointSize: Tk.label.medium
  }
  ConnectedRect {
    Layout.fillWidth: true
    first: true; last: true
    color: Colours.m3surfaceContainerLowest
    implicitHeight: code.implicitHeight + Tk.padding.large * 2
    TextEdit {
      id: code
      anchors.fill: parent
      anchors.margins: Tk.padding.large
      anchors.rightMargin: Tk.padding.large + 40
      readOnly: true
      selectByMouse: true
      wrapMode: TextEdit.WrapAnywhere
      text: root.loader
      color: Colours.m3onSurfaceVariant
      selectionColor: Colours.m3secondary
      selectedTextColor: Colours.m3onSecondary
      font.family: Tk.mono
      font.pointSize: Tk.label.medium
    }
    IconButton {
      anchors.top: parent.top; anchors.right: parent.right
      anchors.margins: Tk.padding.small
      type: "tonal"; icon: "content_copy"; iconSize: Tk.iconSize.small
      onClicked: root.copy(root.loader, "Snippet")
    }
  }

  component StatusChip: Rectangle {
    id: sc
    property bool active
    property string text
    implicitWidth: sct.implicitWidth + Tk.padding.medium * 2
    implicitHeight: sct.implicitHeight + Tk.padding.extraSmall * 2
    radius: height / 2
    color: active ? Colours.m3tertiaryContainer : "transparent"
    border.width: active ? 0 : 1
    border.color: Colours.m3outlineVariant
    MText { id: sct; anchors.centerIn: parent; text: sc.text; font.pointSize: Tk.label.small; weight: Font.Medium; color: sc.active ? Colours.m3onTertiaryContainer : Colours.m3outline }
  }

  component VarRow: ConnectedRect {
    id: vr
    property var v
    readonly property bool known: !!v.opt && (v.opt in root.live)
    Layout.fillWidth: true
    implicitHeight: vrl.implicitHeight + Tk.padding.medium * 2
    RowLayout {
      id: vrl
      anchors.left: parent.left; anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased
      anchors.rightMargin: Tk.padding.medium
      spacing: Tk.spacing.medium
      RowLabel {
        Layout.fillWidth: true
        text: root.labels[vr.v.name] || vr.v.name
        subtext: vr.v.opt || (vr.v.uses.length ? vr.v.uses[0].split("(")[0] : "")
      }
      MText { text: root.fmt(root.value(vr.v), vr.v.name); font.family: Tk.mono; font.pointSize: Tk.label.medium; weight: Font.Medium }
      StatusChip {
        visible: vr.known
        active: root.applied(vr.v)
        text: active ? "Applied" : "Now " + root.fmt(root.live[vr.v.opt], vr.v.name)
      }
      IconButton { type: "text"; icon: "content_copy"; iconSize: Tk.iconSize.small; onClicked: root.copy(root.snippet(vr.v), root.labels[vr.v.name] || vr.v.name) }
    }
  }
}
