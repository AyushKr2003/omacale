import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../.."

// Caelestia modules/windowinfo/WindowInfo.qml: the active window's live
// preview beside a details card and an actions card. It is the bar popout
// "detached" (bar/popouts/Wrapper.qml detach("winfo")): Omacale shows it as the
// held `winfo` popout, so the popout frame supplies the padding.large inset
// Caelestia puts on its RowLayout, and the height here leaves room for it.
Item {
  id: root

  required property var screen
  required property var client
  // Whether the popout is showing. The page stays loaded after it closes (the
  // popout keeps its last page for the outro), so a reopen starts it afresh.
  property bool open: true
  signal closeRequested()

  implicitWidth: child.implicitWidth
  implicitHeight: Math.round((screen ? screen.height : 1080) * Tk.sizes.winfoHeightMult) - Tk.padding.large * 2

  focus: true
  Keys.onEscapePressed: closeRequested()
  // The held popout gets OnDemand keyboard focus a frame after it opens.
  Timer { id: focusTimer; interval: 150; onTriggered: root.forceActiveFocus() }

  function opened() {
    buttons.moveToWsExpanded = false
    Hyprland.refreshToplevels()
    focusTimer.restart()
  }
  Component.onCompleted: if (open) opened()
  onOpenChanged: if (open) opened()

  // lastIpcObject (position, size, floating, pinned, ...) is a snapshot;
  // Caelestia's Hypr service refreshes it on Hyprland's events. Here only
  // while this panel is up, and for the events its details and buttons show.
  Connections {
    target: Hyprland
    enabled: root.open
    function onRawEvent(e) {
      if (["changefloatingmode", "pin", "movewindowv2", "windowtitlev2", "fullscreen", "activewindowv2", "movewindow"].indexOf(e.name) >= 0)
        Hyprland.refreshToplevels()
    }
  }

  RowLayout {
    id: child
    anchors.fill: parent
    spacing: Tk.spacing.medium

    WinfoPreview {
      screen: root.screen
      client: root.client
    }

    ColumnLayout {
      spacing: Tk.spacing.medium
      Layout.preferredWidth: Tk.sizes.winfoDetailsWidth
      Layout.fillHeight: true

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Colours.m3surfaceContainer
        radius: Tk.rounding.large
        clip: true
        WinfoDetails { client: root.client }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: buttons.implicitHeight
        color: Colours.m3surfaceContainer
        radius: Tk.rounding.large
        WinfoButtons {
          id: buttons
          client: root.client
          onKilled: root.closeRequested()
        }
      }
    }
  }
}
