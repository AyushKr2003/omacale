import QtQuick
import QtQuick.Controls

// Caelestia components/controls/StyledScrollBar.qml: a thin secondary pill
// that shows while the view moves (lingering 600ms), brightens on hover and
// while dragged, and hides when everything fits.
ScrollBar {
  id: root
  required property Flickable flickable
  property bool shouldBeActive

  implicitWidth: Tk.padding.extraSmall
  padding: 0
  onHoveredChanged: shouldBeActive = hovered || flickable.moving

  contentItem: Rectangle {
    implicitWidth: Tk.padding.extraSmall
    radius: width / 2
    color: Colours.m3secondary
    opacity: root.size >= 1 ? 0 : root.pressed ? 1 : mouse.containsMouse ? 0.8
      : (root.policy === ScrollBar.AlwaysOn || root.shouldBeActive) ? 0.6 : 0
    Behavior on opacity { Anim { type: "effects" } }
    MouseArea {
      id: mouse
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
    }
  }
  background: null

  Connections {
    target: root.flickable
    function onMovingChanged() {
      if (root.flickable.moving) root.shouldBeActive = true
      else hideDelay.restart()
    }
  }
  Timer { id: hideDelay; interval: 600; onTriggered: root.shouldBeActive = root.flickable.moving || root.hovered }
}
