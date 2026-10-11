import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../.."

// Settings › Display › Apply: "Keep these display settings?" on every screen
// (one of them may be the one that went dark or wrong), counting down to the
// daemon's deadline. hyprmoncfg reverts by itself when it runs out, even if
// the shell is gone. Owned by Bar.qml, not Settings, so closing Settings or
// restarting the shell mid-countdown still leaves a way to answer. Enter
// keeps, Escape reverts, on the focused screen.
PanelWindow {
  id: root
  required property var modelData
  screen: modelData
  readonly property bool keys: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name === modelData.name : false
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "omacale-display-confirm"
  WlrLayershell.keyboardFocus: keys ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  anchors { top: true; bottom: true; left: true; right: true }

  Rectangle {
    anchors.fill: parent
    color: Qt.alpha(Colours.m3scrim, 0.4)
  }

  Rectangle {
    id: card
    anchors.centerIn: parent
    width: Tk.px(400)
    height: col.implicitHeight + Tk.padding.extraLarge * 2
    radius: Tk.rounding.extraLarge
    color: Colours.palette.m3surfaceContainer
    border.width: Tk.px(2)
    border.color: Colours.m3outlineVariant

    focus: true
    Keys.onReturnPressed: DisplayService.keep()
    Keys.onEnterPressed: DisplayService.keep()
    Keys.onEscapePressed: DisplayService.revert()

    ColumnLayout {
      id: col
      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
      anchors.margins: Tk.padding.extraLarge
      spacing: Tk.spacing.medium
      MIcon { Layout.alignment: Qt.AlignHCenter; text: "monitor"; size: Tk.iconSize.extraLarge; color: Colours.m3primary }
      MText {
        Layout.alignment: Qt.AlignHCenter
        text: "Keep these display settings?"
        font.pointSize: Tk.title.medium
        weight: Font.Medium
      }
      MText {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: Colours.m3onSurfaceVariant
        text: "The previous settings come back in " + DisplayService.seconds + (DisplayService.seconds === 1 ? " second" : " seconds") + " unless you keep these."
      }
      // The daemon's deadline as a fraction of the 30 seconds asked for.
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: Tk.px(4)
        radius: height / 2
        color: Colours.m3surfaceContainerHighest
        Rectangle {
          width: parent.width * Math.min(1, DisplayService.seconds / 30)
          height: parent.height
          radius: parent.radius
          color: Colours.m3primary
          Behavior on width { NumberAnimation { duration: 250 } }
        }
      }
      RowLayout {
        Layout.alignment: Qt.AlignRight
        spacing: Tk.spacing.small
        IconTextButton {
          type: "tonal"; isRound: true; icon: "undo"; text: "Revert"
          horizontalPadding: Tk.padding.large
          disabled: DisplayService.actionPending
          onClicked: DisplayService.revert()
        }
        IconTextButton {
          type: "filled"; isRound: true; icon: "check"; text: "Keep"
          horizontalPadding: Tk.padding.large
          disabled: DisplayService.actionPending
          onClicked: DisplayService.keep()
        }
      }
    }
  }
}
