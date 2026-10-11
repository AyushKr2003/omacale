import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../.."

// The display-switch menu (IPC `display menu`, the optional XF86Display /
// SUPER+P binds, or a display being connected): Extend, Mirror, Only laptop,
// Only external, as other desktops' Win+P. Picking one goes through
// DisplayService.quick, i.e. the same keep-or-revert card as Settings ›
// Display's Apply. On the focused screen only; keys 1-4, arrows, Enter, Esc.
PanelWindow {
  id: root
  required property var modelData
  screen: modelData
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "omacale-display-quick"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  anchors { top: true; bottom: true; left: true; right: true }

  readonly property var modes: [
    { id: "extend", icon: "dual_screen", label: "Extend", note: "One desktop across both" },
    { id: "mirror", icon: "screen_share", label: "Mirror", note: "The same picture on both" },
    { id: "laptop", icon: "laptop", label: "Only laptop", note: "External display off" },
    { id: "external", icon: "desktop_windows", label: "Only external", note: "Laptop display off" }
  ].filter(m => m.id !== "laptop" || DisplayService.editable)
  property int cursor: Math.max(0, modes.findIndex(m => m.id === DisplayService.quickCurrent))

  function pick(i) { if (i >= 0 && i < modes.length && DisplayService.quickReady) DisplayService.quick(modes[i].id) }

  Rectangle {
    anchors.fill: parent
    color: Qt.alpha(Colours.m3scrim, 0.4)
    MouseArea { anchors.fill: parent; onClicked: DisplayService.quickShow(false) }
  }

  Rectangle {
    id: card
    anchors.centerIn: parent
    width: row.implicitWidth + Tk.padding.extraLarge * 2
    height: col.implicitHeight + Tk.padding.extraLarge * 2
    radius: Tk.rounding.extraLarge
    color: Colours.palette.m3surfaceContainer
    border.width: Tk.px(2)
    border.color: Colours.m3outlineVariant
    MouseArea { anchors.fill: parent }   // clicks on the card don't close it

    focus: true
    Keys.onPressed: e => {
      if (e.key === Qt.Key_Escape) DisplayService.quickShow(false)
      else if (e.key === Qt.Key_Left || e.key === Qt.Key_H) root.cursor = (root.cursor + root.modes.length - 1) % root.modes.length
      else if (e.key === Qt.Key_Right || e.key === Qt.Key_L || e.key === Qt.Key_Tab) root.cursor = (root.cursor + 1) % root.modes.length
      else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) root.pick(root.cursor)
      else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_4) root.pick(e.key - Qt.Key_1)
      else return
      e.accepted = true
    }

    ColumnLayout {
      id: col
      anchors.centerIn: parent
      spacing: Tk.spacing.large
      MText {
        Layout.alignment: Qt.AlignHCenter
        text: DisplayService.quickReady ? "Displays" : "Reading your displays…"
        font.pointSize: Tk.title.medium
        weight: Font.Medium
      }
      RowLayout {
        id: row
        spacing: Tk.spacing.medium
        Repeater {
          model: root.modes
          Rectangle {
            id: tile
            required property var modelData
            required property int index
            readonly property bool current: modelData.id === DisplayService.quickCurrent
            readonly property bool sel: index === root.cursor
            implicitWidth: Tk.px(150)
            Layout.fillHeight: true               // even tiles when a caption wraps
            implicitHeight: tc.implicitHeight + Tk.padding.large * 2
            radius: Tk.rounding.large
            color: current ? Colours.m3primaryContainer : Colours.m3surfaceContainerHighest
            border.width: sel ? Tk.px(2) : 0
            border.color: Colours.m3primary
            opacity: DisplayService.quickReady ? 1 : 0.5
            ColumnLayout {
              id: tc
              anchors.centerIn: parent
              width: parent.width - Tk.padding.medium * 2
              spacing: Tk.spacing.small
              MIcon {
                Layout.alignment: Qt.AlignHCenter
                text: tile.modelData.icon
                size: Tk.iconSize.extraLarge
                fill: tile.current ? 1 : 0
                color: tile.current ? Colours.m3onPrimaryContainer : Colours.m3onSurfaceVariant
              }
              MText {
                Layout.alignment: Qt.AlignHCenter
                text: (tile.index + 1) + "  " + tile.modelData.label
                weight: Font.Medium
                color: tile.current ? Colours.m3onPrimaryContainer : Colours.m3onSurface
              }
              MText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: tile.modelData.note
                font.pointSize: Tk.label.medium
                color: tile.current ? Colours.m3onPrimaryContainer : Colours.m3onSurfaceVariant
              }
            }
            StateLayer { onClicked: root.pick(tile.index) }
          }
        }
      }
    }
  }
}
