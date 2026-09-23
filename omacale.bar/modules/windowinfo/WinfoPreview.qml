import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Widgets
import "../.."

// Caelestia modules/windowinfo/Preview.qml: the live window at its own aspect
// ratio (capped at the screen's), with where it sits written underneath, or
// an empty state when nothing is focused.
Item {
  id: root

  required property var screen
  required property var client
  readonly property var ipc: client ? client.lastIpcObject : null

  Layout.preferredWidth: preview.implicitWidth + Tk.padding.extraLargeIncreased
  Layout.fillHeight: true

  ClippingRectangle {
    id: preview
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.bottom: label.top
    anchors.topMargin: Tk.padding.large
    anchors.bottomMargin: Tk.spacing.medium
    implicitWidth: view.implicitWidth
    color: Colours.m3surfaceContainer
    radius: Tk.rounding.medium

    Loader {
      asynchronous: true
      anchors.centerIn: parent
      active: !root.client
      sourceComponent: ColumnLayout {
        spacing: 0
        MIcon {
          Layout.alignment: Qt.AlignHCenter
          text: "web_asset_off"
          color: Colours.m3outline
          size: Tk.iconSize.extraLarge * 3
        }
        MText {
          Layout.alignment: Qt.AlignHCenter
          text: "No active client"
          color: Colours.m3outline
          font.pointSize: 28
          weight: Font.Medium
        }
        MText {
          Layout.alignment: Qt.AlignHCenter
          text: "Try switching to a window"
          color: Colours.m3outline
          font.pointSize: Tk.body.large
        }
      }
    }

    ScreencopyView {
      id: view
      anchors.centerIn: parent
      captureSource: root.client ? root.client.wayland : null
      live: true
      constraintSize.width: root.client && root.ipc && root.ipc.size && root.screen
        ? parent.height * Math.min(root.screen.width / root.screen.height, root.ipc.size[0] / root.ipc.size[1])
        : parent.height
      constraintSize.height: parent.height
    }
  }

  MText {
    id: label
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Tk.padding.large
    animate: true
    text: {
      const c = root.client
      if (!c) return "No active client"
      const mon = c.monitor
      const at = root.ipc && root.ipc.at ? root.ipc.at : [0, 0]
      return c.title + " on monitor " + (mon ? mon.name : "?") + " at " + at[0] + ", " + at[1]
    }
  }
}
