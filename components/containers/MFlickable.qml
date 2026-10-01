import QtQuick
import "../.."

// Caelestia components/containers/StyledFlickable.qml: overshoots and springs
// back with the standard curve; the fake flick afterwards resets Qt's
// velocity so the next wheel scroll doesn't stall.
Flickable {
  id: root
  property bool doneFakeFlick

  maximumFlickVelocity: 3000
  rebound: Transition {
    onRunningChanged: {
      if (!running && !root.doneFakeFlick) {
        root.doneFakeFlick = true
        root.flick(1, 1)
        root.flick(-1, -1)
        Qt.callLater(() => root.cancelFlick())
      }
    }
    Anim { properties: "x,y" }
  }
  Timer { running: root.doneFakeFlick; interval: 10; onTriggered: root.doneFakeFlick = false }
}
