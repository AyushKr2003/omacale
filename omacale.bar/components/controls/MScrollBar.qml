import QtQuick
import QtQuick.Controls
import "../.."

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
    opacity: root.size >= 1 ? 0 : root.pressed || fullMouse.pressed ? 1 : mouse.containsMouse ? 0.8
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

  // Caelestia's fullMouse: press anywhere on the track to centre the thumb
  // there, drag to scrub, and the wheel over the bar steps a tenth.
  function scrollTo(pos) {
    if (!flickable) return
    const maxY = flickable.contentHeight - flickable.height
    if (maxY <= 0) return
    const maxPos = 1 - size
    const p = Math.max(0, Math.min(maxPos, pos))
    flickable.contentY = maxPos > 0 ? p / maxPos * maxY : 0
  }
  function posAt(y) { return y / height - size / 2 }
  MouseArea {
    id: fullMouse
    anchors.fill: parent
    preventStealing: true
    onPressed: e => root.scrollTo(root.posAt(e.y))
    onPositionChanged: e => { if (pressed) root.scrollTo(root.posAt(e.y)) }
    onWheel: e => {
      const maxY = root.flickable.contentHeight - root.flickable.height
      if (maxY <= 0) return
      const cur = root.flickable.contentY / maxY * (1 - root.size)
      root.scrollTo(cur + (e.angleDelta.y > 0 ? -0.1 : e.angleDelta.y < 0 ? 0.1 : 0))
    }
  }
  // The thumb glides (spatial) rather than jumping, except under the finger.
  Behavior on position { enabled: !fullMouse.pressed; Anim {} }
}
