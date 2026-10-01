import QtQuick
import QtQuick.Effects
import ".."

// An image's alpha filled with one tint (Caelestia ColouredIcon).
Item {
  id: root
  property alias source: img.source
  property color colour: Colours.m3tertiary
  property real implicitSize: Tk.px(20)

  implicitWidth: implicitSize
  implicitHeight: implicitSize

  Image {
    id: img
    anchors.fill: parent
    sourceSize.width: root.width * 2
    sourceSize.height: root.height * 2
    fillMode: Image.PreserveAspectFit
    smooth: true
    visible: false
    layer.enabled: true
  }
  Rectangle {
    anchors.fill: parent
    color: root.colour
    Behavior on color { CAnim {} }
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: img
      maskThresholdMin: 0.3
      maskSpreadAtMin: 0.4
    }
  }
}
