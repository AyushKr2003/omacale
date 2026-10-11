import QtQuick
import Quickshell
import Quickshell.Wayland
import "../.."

// Settings › Display › Identify: each screen's name, big, in its middle for a
// moment, so the canvas's boxes can be matched to the real screens. Overlay,
// input-transparent, one window per screen (Bar.qml's Variants).
PanelWindow {
  id: root
  required property var modelData
  screen: modelData
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "omacale-identify"
  anchors { top: true; bottom: true; left: true; right: true }
  mask: Region {}

  Rectangle {
    anchors.centerIn: parent
    width: col.implicitWidth + Tk.padding.extraLarge * 2
    height: col.implicitHeight + Tk.padding.extraLarge * 2
    radius: Tk.rounding.extraLarge
    color: Colours.palette.m3surfaceContainer
    // Settings (same surface) is usually open behind it.
    border.width: Tk.px(2)
    border.color: Colours.m3outlineVariant
    Column {
      id: col
      anchors.centerIn: parent
      spacing: Tk.spacing.small
      MIcon { anchors.horizontalCenter: parent.horizontalCenter; text: "monitor"; size: Tk.iconSize.extraLarge * 1.5; color: Colours.m3primary }
      MText { anchors.horizontalCenter: parent.horizontalCenter; text: root.modelData.name; font.pointSize: Tk.font(32); weight: Font.Medium; color: Colours.m3onSurface }
      MText { anchors.horizontalCenter: parent.horizontalCenter; text: root.modelData.model || ""; color: Colours.m3onSurfaceVariant }
    }
  }
}
