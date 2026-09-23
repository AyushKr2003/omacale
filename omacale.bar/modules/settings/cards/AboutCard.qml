import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../.."

ColumnLayout {
  id: root
  property var settings
  property var row
  property bool first
  property bool last
  spacing: Tk.spacing.extraSmall / 2
  property var info: ({})
  property bool confirmReset: false

  Process {
    running: true
    command: ["bash", "-c",
      "echo host=$(hostname); echo kernel=$(uname -r); echo omarchy=$(omarchy-version 2>/dev/null); " +
      "echo hypr=$(hyprctl version -j 2>/dev/null | jq -r .tag); echo qs=$(quickshell --version 2>/dev/null | awk '{print $2}'); " +
      "echo model=$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null)"]
    stdout: SplitParser {
      onRead: l => { const i = l.indexOf("="); const o = Object.assign({}, root.info); o[l.slice(0, i)] = l.slice(i + 1); root.info = o }
    }
  }
  Timer { id: confirmTimer; interval: 3000; onTriggered: root.confirmReset = false }

  ConnectedRect {
    Layout.fillWidth: true
    first: true; last: true
    implicitHeight: hero.implicitHeight + Tk.padding.extraLarge * 2
    ColumnLayout {
      id: hero
      anchors.centerIn: parent
      spacing: Tk.spacing.small
      Item {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 96; implicitHeight: 96
        MShape {
          id: logoShape
          anchors.fill: parent
          implicitSize: 96
          color: Colours.m3primaryContainer
          property int i: 0
          readonly property var cycle: ["cookie12", "softBurst", "gem", "clover4", "cookie7", "sunny"]
          shape: cycle[i]
          Timer { interval: 2600; running: root.visible; repeat: true; onTriggered: logoShape.i = (logoShape.i + 1) % logoShape.cycle.length }
          RotationAnimation on rotation { from: 0; to: 360; duration: 24000; loops: Animation.Infinite; running: root.visible }
        }
        ColouredIcon {
          anchors.centerIn: parent
          implicitSize: 44
          source: "file://" + Quickshell.env("OMARCHY_PATH") + "/icon.png"
          colour: Colours.m3onPrimaryContainer
        }
      }
      MText { Layout.alignment: Qt.AlignHCenter; text: "Omacale"; font.pointSize: Tk.headline.small; weight: Font.Medium; color: Colours.m3primary }
      MText { Layout.alignment: Qt.AlignHCenter; text: "Caelestia's look, Omarchy's engine · v" + (root.settings ? root.settings.version : ""); color: Colours.m3onSurfaceVariant }
    }
  }

  Header { text: "System" }
  Info { first: true; label: "Hostname"; value: root.info.host || "" }
  Info { label: "Device"; value: root.info.model || "" }
  Info { label: "Omarchy"; value: root.info.omarchy || "" }
  Info { label: "Kernel"; value: root.info.kernel || "" }
  Info { label: "Hyprland"; value: root.info.hypr || "" }
  Info { last: true; label: "Quickshell"; value: root.info.qs || "" }

  Header { text: "Settings" }
  Action {
    first: true
    icon: "description"; label: "Open settings file"; sub: Config.path.replace(Quickshell.env("HOME"), "~")
    onClicked: Quickshell.execDetached(["bash", "-c", "mkdir -p '" + Config.dir + "'; [ -f '" + Config.path + "' ] || echo '{}' > '" + Config.path + "'; omarchy-launch-editor '" + Config.path + "'"])
  }
  Action {
    last: true
    danger: true
    icon: root.confirmReset ? "warning" : "restart_alt"
    label: root.confirmReset ? "Click again to reset everything" : "Reset all settings"
    sub: "Restore every Omacale option to its default"
    onClicked: {
      if (root.confirmReset) { Config.resetAll(); root.confirmReset = false }
      else { root.confirmReset = true; confirmTimer.restart() }
    }
  }

  Header { text: "Credits" }
  Action { first: true; icon: "code"; label: "Made by AyushKr2003"; sub: "github.com/AyushKr2003"; onClicked: Qt.openUrlExternally("https://github.com/AyushKr2003") }
  Action { last: true; icon: "favorite"; label: "Design by Caelestia"; sub: "github.com/caelestia-dots/shell · GPL-3.0"; onClicked: Qt.openUrlExternally("https://github.com/caelestia-dots/shell") }

  component Header: MText {
    Layout.fillWidth: true
    Layout.topMargin: Tk.spacing.largeIncreased
    Layout.bottomMargin: Tk.spacing.extraSmall
    Layout.leftMargin: Tk.padding.small
    color: Colours.m3onSurfaceVariant
    font.pointSize: Tk.label.medium
  }
  component Info: ConnectedRect {
    property string label
    property string value
    Layout.fillWidth: true
    implicitHeight: il.implicitHeight + Tk.padding.medium * 2
    RowLayout {
      id: il
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.largeIncreased
      MText { Layout.fillWidth: true; text: parent.parent.label }
      MText { text: parent.parent.value; color: Colours.m3outline; animate: true }
    }
  }
  component Action: ConnectedRect {
    id: act
    property string icon
    property string label
    property string sub
    property bool danger
    signal clicked()
    Layout.fillWidth: true
    color: danger && root.confirmReset ? Colours.m3errorContainer : Colours.m3surfaceContainer
    implicitHeight: al.implicitHeight + Tk.padding.medium * 2
    StateLayer { color: act.danger ? Colours.m3error : Colours.m3onSurface; onClicked: act.clicked() }
    RowLayout {
      id: al
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.largeIncreased
      spacing: Tk.spacing.medium
      MIcon { text: act.icon; size: Tk.iconSize.medium; fill: 1; color: act.danger ? Colours.m3error : Colours.m3onSurfaceVariant }
      RowLabel { Layout.fillWidth: true; text: act.label; subtext: act.sub }
      MIcon { text: "chevron_right"; size: Tk.iconSize.medium; color: Colours.m3onSurfaceVariant }
    }
  }
}
