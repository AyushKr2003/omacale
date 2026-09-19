import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// Settings › Apps › All apps › <app>. Port of Caelestia's nexus
// pages/apps/AppInfo.qml: header, launcher favourite / hidden, details.
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  readonly property var app: settings ? settings.selectedApp : null
  function inList(key) { return !!app && Config.get(key).indexOf(app.id) >= 0 }
  function setIn(key, on) {
    const l = Array.from(Config.get(key)).filter(a => a !== app.id)
    Config.set(key, on ? l.concat([app.id]) : l)
  }

  spacing: Tk.spacing.extraSmall / 2

  RowLayout {
    Layout.fillWidth: true
    Layout.bottomMargin: Tk.spacing.large
    spacing: Tk.spacing.large
    IconImage {
      asynchronous: true
      implicitSize: Math.round(Tk.iconSize.extraLarge * 2)
      source: root.app ? Quickshell.iconPath(root.app.icon, "image-missing") : ""
    }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0
      MText { Layout.fillWidth: true; text: root.app ? root.app.name : ""; font.pointSize: Tk.title.large; weight: Font.Medium; elide: Text.ElideRight }
      MText {
        Layout.fillWidth: true
        visible: text !== ""
        text: root.app ? (root.app.comment || root.app.genericName || "") : ""
        color: Colours.m3outline
        wrapMode: Text.WordWrap
      }
    }
    IconTextButton {
      icon: "open_in_new"
      text: "Open"
      type: "tonal"
      horizontalPadding: Tk.padding.large
      verticalPadding: Tk.padding.small
      onClicked: if (root.app) root.app.execute()
    }
  }

  SectionHeader { first: true; row: ({ text: "Launcher" }) }
  RowToggle {
    Layout.fillWidth: true
    first: true
    text: "Favourite"
    subtext: "Pin to the top of the launcher"
    checked: root.inList("launcher.favouriteApps")
    onToggled: c => root.setIn("launcher.favouriteApps", c)
  }
  RowToggle {
    Layout.fillWidth: true
    last: true
    text: "Hidden"
    subtext: "Hide from the launcher"
    checked: root.inList("launcher.hiddenApps")
    onToggled: c => root.setIn("launcher.hiddenApps", c)
  }

  SectionHeader { row: ({ text: "Details" }) }
  Repeater {
    id: details
    model: root.app ? [
      ["ID", root.app.id],
      ["Command", (root.app.command || []).join(" ")],
      ["Categories", (root.app.categories || []).join(", ")],
      ["Runs in terminal", root.app.runInTerminal ? "Yes" : "No"],
      ["Working directory", root.app.workingDirectory || ""]
    ].filter(d => d[1] !== "") : []
    ConnectedRect {
      required property var modelData
      required property int index
      Layout.fillWidth: true
      first: index === 0
      last: index === details.count - 1
      implicitHeight: dr.implicitHeight + Tk.padding.medium * 2
      RowLayout {
        id: dr
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tk.padding.largeIncreased
        anchors.rightMargin: Tk.padding.largeIncreased
        spacing: Tk.spacing.large
        MText { text: modelData[0] }
        MText {
          Layout.fillWidth: true
          text: modelData[1]
          color: Colours.m3onSurfaceVariant
          horizontalAlignment: Text.AlignRight
          wrapMode: Text.WrapAnywhere
        }
      }
    }
  }
}
