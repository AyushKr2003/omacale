import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."

// Settings › Apps. Port of Caelestia's nexus pages/AppsPage.qml. Caelestia
// keeps its own default-app commands; Omarchy owns these, so each row reads
// and sets them with omarchy-default-{terminal,browser,editor} (picking one
// that isn't installed runs Omarchy's installer, as its menu does).
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  spacing: Tk.spacing.extraSmall / 2

  // Choices and the binary each needs, as listed in the Omarchy scripts.
  readonly property var kinds: [
    { kind: "terminal", icon: "terminal", label: "Terminal", choices: [
      ["alacritty", "Alacritty", "alacritty"], ["foot", "Foot", "foot"],
      ["ghostty", "Ghostty", "ghostty"], ["kitty", "Kitty", "kitty"]] },
    { kind: "browser", icon: "language", label: "Browser", choices: [
      ["chromium", "Chromium", "chromium"], ["chrome", "Chrome", "google-chrome-stable"],
      ["brave", "Brave", "brave"], ["brave-origin", "Brave Origin", "brave-origin"],
      ["edge", "Edge", "microsoft-edge-stable"], ["firefox", "Firefox", "firefox"], ["zen", "Zen", "zen-browser"]] },
    { kind: "editor", icon: "edit_note", label: "Editor", choices: [
      ["code", "VSCode", "code"], ["cursor", "Cursor", "cursor"], ["zed", "Zed", "zeditor"],
      ["sublime_text", "Sublime Text", "sublime_text"], ["helix", "Helix", "helix"],
      ["vim", "Vim", "vim"], ["emacs", "Emacs", "emacs"], ["nvim", "Neovim", "nvim"]] }
  ]
  property var current: ({})
  property var installed: ({})

  function options(k) {
    return k.choices.map(c => ({
      value: c[0],
      label: root.installed[c[2]] === false ? c[1] + " · install" : c[1],
      icon: root.installed[c[2]] === false ? "download" : k.icon
    }))
  }
  function set(kind, value) {
    current = Object.assign({}, current, { [kind]: value })
    Quickshell.execDetached(["omarchy-default-" + kind, value])
    reprobe.restart()
  }

  Process {
    id: probe
    running: true
    command: ["bash", "-c",
      "for k in terminal browser editor; do echo \"cur:$k:$(omarchy-default-$k 2>/dev/null)\"; done; " +
      "for b in \"$@\"; do command -v \"$b\" >/dev/null && echo \"bin:$b:1\" || echo \"bin:$b:0\"; done",
      "probe"].concat(root.kinds.reduce((l, k) => l.concat(k.choices.map(c => c[2])), []))
    stdout: StdioCollector {
      onStreamFinished: {
        const cur = {}, bin = {}
        for (const line of text.split("\n")) {
          const [t, k, v] = line.split(":")
          if (t === "cur") cur[k] = v
          else if (t === "bin") bin[k] = v === "1"
        }
        root.current = cur
        root.installed = bin
      }
    }
  }
  Timer { id: reprobe; interval: 1500; onTriggered: probe.running = true }

  SectionHeader { first: true; row: ({ text: "Default applications" }) }
  Repeater {
    model: root.kinds
    // Caelestia AppsPage DefaultRow: the current app under the label, and a
    // blob popup of the choices.
    PopupRow {
      id: defRow
      required property var modelData
      required property int index
      readonly property var opts: root.options(modelData)
      first: index === 0
      last: index === root.kinds.length - 1
      settings: root.settings
      icon: modelData.icon
      label: modelData.label
      status: (opts.find(o => o.value === root.current[modelData.kind]) || { label: root.current[modelData.kind] || "" }).label

      ColumnLayout {
        implicitWidth: Tk.px(300)
        spacing: 0
        Repeater {
          model: defRow.opts
          StateLayer {
            id: choice
            required property var modelData
            anchors.fill: undefined
            Layout.fillWidth: true
            implicitHeight: choiceRow.implicitHeight + Tk.padding.medium * 2
            radius: Tk.rounding.small
            disabled: !defRow.popup.open
            onClicked: {
              defRow.popup.open = false
              root.set(defRow.modelData.kind, modelData.value)
            }
            RowLayout {
              id: choiceRow
              anchors.fill: parent
              anchors.margins: Tk.padding.medium
              spacing: Tk.spacing.medium
              MIcon {
                text: choice.modelData.value === root.current[defRow.modelData.kind] ? "check" : choice.modelData.icon
                size: Tk.iconSize.medium
                color: choice.modelData.value === root.current[defRow.modelData.kind] ? Colours.m3primary : Colours.m3onSurfaceVariant
              }
              MText { Layout.fillWidth: true; text: choice.modelData.label; elide: Text.ElideRight }
            }
          }
        }
      }
    }
  }

  SectionHeader { row: ({ text: "Library" }) }
  RowNav {
    Layout.fillWidth: true
    first: true
    last: true
    settings: root.settings
    row: ({ icon: "apps", label: "All apps", subtext: "Browse installed apps, set favourites and hidden", page: "allApps" })
  }
}
