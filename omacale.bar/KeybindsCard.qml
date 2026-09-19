import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Omacale keybinds, read from keybinds.lua (the same file `omacale binds`
// prints). Copy one line, copy everything, or try them for this session
// only: runtime binds via `hyprctl eval`, gone on the next Hyprland reload,
// and nothing is written to ~/.config/hypr.
ColumnLayout {
  id: root
  property var settings
  property var row
  property bool first
  property bool last
  spacing: Tk.spacing.extraSmall / 2

  readonly property string file: String(Qt.resolvedUrl("keybinds.lua")).replace("file://", "")
  property string source: ""
  property var binds: []        // { keys, desc, cmd, line, optional, note }
  property var active: ({})     // description -> true when bound in Hyprland
  property var tried: []        // keys bound by "Try" in this session
  property real keysWidth: 230  // widest key combo, so every label lines up
  property string toast: ""

  FileView {
    path: root.file
    printErrors: false
    onLoaded: {
      root.source = text()
      const out = []
      String(text()).split("\n").forEach(l => {
        const m = l.match(/^\s*(--\s*)?o\.(re)?bind\("([^"]+)",\s*"([^"]+)",\s*"([^"]+)"\)\s*(--\s*(.*))?$/)
        if (m) out.push({ optional: !!m[1], rebind: !!m[2], keys: m[3], desc: m[4], cmd: m[5], note: m[7] || "", line: l.replace(/^\s*--\s*/, "").replace(/\s+--.*$/, "") })
      })
      root.binds = out
    }
  }

  Process {
    id: bindProbe
    command: ["hyprctl", "binds", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const a = {}
          JSON.parse(text).forEach(b => { if (b.description) a[b.description] = true })
          root.active = a
        } catch (e) {}
      }
    }
  }
  Component.onCompleted: bindProbe.running = true
  Timer { id: reprobe; interval: 400; onTriggered: bindProbe.running = true }
  Timer { id: toastTimer; interval: 2200; onTriggered: root.toast = "" }

  function copy(text, what) {
    // "--" ends wl-copy's options: the Lua we copy starts with "--" comments,
    // which it would otherwise reject as an unknown option and copy nothing.
    Quickshell.execDetached(["wl-copy", "--", text])
    toast = what + " copied to the clipboard"
    toastTimer.restart()
  }
  function tryAll() {
    const todo = binds.filter(b => !b.optional && !active[b.desc])
    if (!todo.length) { toast = "All Omacale binds are already active"; toastTimer.restart(); return }
    Quickshell.execDetached(["hyprctl", "eval", todo.map(b => b.line).join("\n")])
    tried = tried.concat(todo.map(b => b.keys))
    toast = todo.length + " binds active until Hyprland reloads"
    toastTimer.restart()
    reprobe.restart()
  }
  function undoTry() {
    if (!tried.length) return
    Quickshell.execDetached(["hyprctl", "eval", tried.map(k => 'hl.unbind("' + k + '")').join("\n")])
    tried = []
    toast = "Session binds removed"
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
          MIcon { anchors.centerIn: parent; text: "keyboard"; size: Tk.iconSize.large; fill: 1; color: Colours.m3onPrimaryContainer }
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          MText { text: "Omarchy-style keybindings"; font.pointSize: Tk.title.small; weight: Font.Medium }
          MText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Colours.m3onSurfaceVariant
            text: "Paste them into ~/.config/hypr/bindings.lua. They use Omarchy's o.bind() helper and only call the shell over IPC, so they are safe to keep after uninstalling."
          }
        }
      }
      Flow {
        Layout.fillWidth: true
        spacing: Tk.spacing.small
        Pill { icon: "content_copy"; label: "Copy all"; filled: true; onClicked: root.copy(root.source, "Keybindings") }
        Pill { icon: "play_arrow"; label: "Try this session"; onClicked: root.tryAll() }
        Pill { icon: "undo"; label: "Undo trial"; visible: root.tried.length > 0; onClicked: root.undoTry() }
        Pill { icon: "edit"; label: "Open bindings.lua"; onClicked: Quickshell.execDetached(["omarchy-launch-editor", Quickshell.env("HOME") + "/.config/hypr/bindings.lua"]) }
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

  // ---- binds
  Repeater {
    model: root.binds.filter(b => !b.optional)
    BindRow { required property var modelData; required property int index; bind: modelData; last: false }
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
      text: "SUPER + SHIFT + SPACE (Omarchy's “Toggle top bar”) already hides and shows the Omacale frame."
    }
  }

  MText {
    Layout.fillWidth: true
    Layout.topMargin: Tk.spacing.largeIncreased
    Layout.bottomMargin: Tk.spacing.extraSmall
    Layout.leftMargin: Tk.padding.small
    text: "Optional — replaces Omarchy defaults"
    color: Colours.m3onSurfaceVariant
    font.pointSize: Tk.label.medium
  }
  // A picker bind is followed by its choice of picker, in the same group.
  readonly property var pickers: ({
    "omarchy-shell omacale wallpapers": { key: "launcher.wallpaperPicker", what: "wallpaper", menu: "Background switcher" },
    "omarchy-shell omacale themes": { key: "launcher.themePicker", what: "theme", menu: "Theme menu" }
  })
  readonly property var optionalRows: {
    const out = []
    binds.filter(b => b.optional).forEach(b => {
      out.push({ bind: b })
      const p = pickers[b.cmd]
      if (p) out.push({
        type: "select", key: p.key, label: "Picker",
        subtext: "Omacale's " + p.what + " carousel, or Omarchy's " + p.menu,
        options: [
          { value: "omacale", label: "Omacale launcher", icon: "view_carousel" },
          { value: "omarchy", label: "Omarchy default", icon: "menu" }
        ]
      })
    })
    return out
  }
  Repeater {
    model: root.optionalRows
    Loader {
      required property var modelData
      required property int index
      readonly property bool isFirst: index === 0
      readonly property bool isLast: index === root.optionalRows.length - 1
      Layout.fillWidth: true
      sourceComponent: modelData.bind ? bindRow : pickerRow
      Component {
        id: bindRow
        BindRow { bind: modelData.bind; first: isFirst; last: isLast }
      }
      Component {
        id: pickerRow
        RowSelect { row: modelData; settings: root.settings; first: isFirst; last: isLast }
      }
    }
  }

  MText {
    Layout.fillWidth: true
    Layout.topMargin: Tk.spacing.largeIncreased
    Layout.bottomMargin: Tk.spacing.extraSmall
    Layout.leftMargin: Tk.padding.small
    text: "Snippet"
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
      readOnly: true
      selectByMouse: true
      wrapMode: TextEdit.NoWrap
      text: root.source
      color: Colours.m3onSurfaceVariant
      selectionColor: Colours.m3secondary
      selectedTextColor: Colours.m3onSecondary
      font.family: Tk.mono
      font.pointSize: Tk.label.medium
      clip: true
    }
    IconButton {
      anchors.top: parent.top; anchors.right: parent.right
      anchors.margins: Tk.padding.small
      type: "tonal"; icon: "content_copy"; iconSize: Tk.iconSize.small
      onClicked: root.copy(root.source, "Snippet")
    }
  }

  component BindRow: ConnectedRect {
    id: br
    property var bind
    readonly property bool isActive: !!root.active[bind.desc]
    Layout.fillWidth: true
    implicitHeight: brl.implicitHeight + Tk.padding.medium * 2
    RowLayout {
      id: brl
      anchors.left: parent.left; anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased
      anchors.rightMargin: Tk.padding.medium
      spacing: Tk.spacing.medium
      Row {
        Layout.preferredWidth: root.keysWidth
        spacing: Tk.spacing.extraSmall
        onImplicitWidthChanged: root.keysWidth = Math.max(root.keysWidth, implicitWidth + Tk.spacing.large)
        Repeater {
          model: br.bind.keys.split("+").map(k => k.trim())
          Rectangle {
            required property string modelData
            width: Math.max(28, kt.implicitWidth + Tk.padding.small * 2)
            height: 28
            radius: Tk.rounding.small
            color: Colours.m3surfaceContainerHighest
            border.width: 1
            border.color: Colours.m3outlineVariant
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 3; radius: parent.radius; color: Colours.m3outlineVariant }
            MText { id: kt; anchors.centerIn: parent; anchors.verticalCenterOffset: -1; text: parent.modelData === "ESCAPE" ? "Esc" : parent.modelData.charAt(0) + parent.modelData.slice(1).toLowerCase(); font.family: Tk.mono; font.pointSize: Tk.label.medium; weight: Font.Medium }
          }
        }
      }
      RowLabel {
        Layout.fillWidth: true
        text: br.bind.desc
        subtext: br.bind.note ? br.bind.note.replace(/^was:/, "Replaces:") : br.bind.cmd.replace("omarchy-shell ", "")
      }
      Rectangle {
        visible: !br.bind.optional
        implicitWidth: st.implicitWidth + Tk.padding.medium * 2
        implicitHeight: st.implicitHeight + Tk.padding.extraSmall * 2
        radius: height / 2
        color: br.isActive ? Colours.m3tertiaryContainer : "transparent"
        border.width: br.isActive ? 0 : 1
        border.color: Colours.m3outlineVariant
        MText { id: st; anchors.centerIn: parent; text: br.isActive ? "Active" : "Not bound"; font.pointSize: Tk.label.small; weight: Font.Medium; color: br.isActive ? Colours.m3onTertiaryContainer : Colours.m3outline }
      }
      IconButton { type: "text"; icon: "content_copy"; iconSize: Tk.iconSize.small; onClicked: root.copy(br.bind.line, br.bind.keys) }
    }
  }
}
