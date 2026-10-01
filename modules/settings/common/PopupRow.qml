import QtQuick
import QtQuick.Layouts
import "../../.."

// Caelestia nexus/common/PopupRow.qml: a settings row whose button, at its
// right end, swells into a blob popup (BlobPopup) holding `content`. The
// whole row opens it; a press anywhere outside the popup closes it.
ConnectedRect {
  id: root

  property string icon
  property string label
  property string status
  property var settings
  readonly property alias popup: popup
  default property Item content

  Layout.fillWidth: true
  implicitHeight: navLayout.implicitHeight + Tk.padding.medium * 2
  z: popup.open || popup.animDriver > 0 ? 2 : 0

  StateLayer {
    id: stateLayer
    manualHoverOverride: popup.hovered && !popup.open
    onClicked: popup.open = true
  }

  RowLayout {
    id: navLayout
    anchors.fill: parent
    anchors.margins: Tk.padding.medium
    anchors.leftMargin: Tk.padding.largeIncreased
    anchors.rightMargin: Tk.padding.largeIncreased
    spacing: Tk.spacing.medium

    MIcon { text: root.icon; size: Tk.iconSize.medium; color: Colours.m3onSurfaceVariant }
    RowLabel { Layout.fillWidth: true; text: root.label; subtext: root.status }

    Item {
      implicitWidth: popup.implicitWidth
      implicitHeight: popup.implicitHeight
      BlobPopup {
        id: popup
        anchors.fill: parent
        icon: "view_apps"
        padding: Tk.padding.small
        pressOverride: stateLayer.pressed
        hoverOverride: stateLayer.containsMouse
        color: open || hovered || stateLayer.containsMouse ? Colours.m3secondaryContainer : Colours.m3surfaceContainerHighest
        content: root.content
      }
    }
  }

  // A press outside the popup closes it and goes no further; inside, it
  // passes through to the popup.
  MouseArea {
    parent: root.settings || root
    anchors.fill: parent
    z: 1000
    enabled: popup.open
    onPressed: e => {
      const p = mapToItem(popup, e.x, e.y)
      if (p.x >= popup.popX && p.x <= popup.popX + popup.popW && p.y >= popup.popY && p.y <= popup.popY + popup.popH) {
        e.accepted = false
        return
      }
      popup.open = false
    }
  }
}
