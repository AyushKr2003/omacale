import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

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
    RowSelect {
      required property var modelData
      required property int index
      Layout.fillWidth: true
      first: index === 0
      last: index === root.kinds.length - 1
      settings: root.settings
      row: ({ icon: modelData.icon, label: modelData.label, options: root.options(modelData) })
      value: root.current[modelData.kind] || ""
      onPicked: v => root.set(modelData.kind, v)
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
