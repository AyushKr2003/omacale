import QtQuick
import QtQuick.Templates as T
import "../.."

// Caelestia components/controls/FilledSlider.qml: the OSD's vertical slider.
// A full-round track filled from the bottom in secondary, and a round
// inverse-surface handle carrying the icon, which turns into the percentage
// while the value moves.
T.Slider {
  id: root

  required property string icon
  property real oldValue
  property bool initialized

  orientation: Qt.Vertical

  background: Rectangle {
    color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
    radius: Tk.rounding.full

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right

      y: root.handle.y
      implicitHeight: parent.height - y

      color: Colours.m3secondary
      radius: parent.radius
    }
  }

  handle: Item {
    id: handle

    property alias moving: icon.moving

    y: root.visualPosition * (root.availableHeight - height)
    implicitWidth: root.width
    implicitHeight: root.width

    Elevation {
      anchors.fill: parent
      radius: rect.radius
      level: handleInteraction.containsMouse ? 2 : 1
    }

    Rectangle {
      id: rect

      anchors.fill: parent

      color: Colours.m3inverseSurface
      radius: Tk.rounding.full

      MouseArea {
        id: handleInteraction

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.NoButton
      }

      MIcon {
        id: icon

        property bool moving

        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1
        text: moving ? Math.round(root.value * 100) : root.icon
        color: Colours.m3inverseOnSurface
        // The percentage in body.small, the icon at its medium size.
        font.family: moving ? Tk.sans : Tk.icon
        size: moving ? Tk.body.small : Tk.iconSize.medium

        Behavior on moving {
          SequentialAnimation {
            Anim {
              target: icon
              property: "scale"
              to: 0.3
              duration: Tk.durations.small / 2
              easing.bezierCurve: Tk.curves.standardAccel
            }
            PropertyAction {}
            Anim {
              target: icon
              property: "scale"
              to: 1
              duration: Tk.durations.normal / 2
              easing.bezierCurve: Tk.curves.standardDecel
            }
          }
        }
      }
    }
  }

  onPressedChanged: handle.moving = pressed

  onValueChanged: {
    if (!initialized) {
      initialized = true
      return
    }
    if (Math.abs(value - oldValue) < 0.01)
      return
    oldValue = value
    handle.moving = true
    stateChangeDelay.restart()
  }

  Timer {
    id: stateChangeDelay

    interval: 500
    onTriggered: {
      if (!root.pressed)
        handle.moving = false
    }
  }

  Behavior on value {
    Anim {
      type: "standardLarge"
    }
  }
}
