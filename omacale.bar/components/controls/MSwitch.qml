import QtQuick
import QtQuick.Shapes
import "../.."

// Caelestia components/controls/StyledSwitch.qml: an M3 switch whose mark is
// two strokes morphing between a cross (off), a tick (on) and a dash (held).
// A row can pass its own press / hover in, since in Caelestia the whole
// ToggleRow is the switch.
Item {
  id: root
  property bool checked
  property bool disabled: false
  property bool pressOverride: false
  property bool hoverOverride: false
  readonly property bool pressed: mouse.pressed || pressOverride
  readonly property bool hovered: mouse.containsMouse || hoverOverride
  // KeyNav cursor (see StateLayer.focused).
  property bool focused: false
  readonly property bool navTarget: !disabled
  function navActivate() { toggled(!checked) }
  signal toggled(bool checked)

  // Caelestia sizes these from the point size used as pixels.
  implicitHeight: Tk.body.medium + Tk.padding.small * 2
  implicitWidth: implicitHeight * 1.7

  Rectangle {
    id: track
    anchors.fill: parent
    radius: height / 2
    color: root.disabled ? (root.checked ? Qt.alpha(Colours.m3onSurface, 0.12) : Qt.alpha(Colours.m3surfaceContainerHighest, 0.38))
      : root.checked ? Colours.m3primary : Colours.m3surfaceContainerHighest
    Behavior on color { CAnim {} }

    // Keyboard focus: M3's switch state layer, a circle around the handle
    // (40dp on a 32dp track), which the handle's own veil is too small to show.
    Rectangle {
      width: root.height * 1.25
      height: width
      radius: width / 2
      anchors.centerIn: handle
      color: root.checked ? Colours.m3primary : Colours.m3onSurface
      opacity: root.focused ? 0.12 : 0
      Behavior on opacity { Anim { type: "effects" } }
    }

    Rectangle {
      id: handle
      readonly property real nonAnimWidth: root.pressed ? height * 1.2 : height
      width: nonAnimWidth
      height: parent.height - Tk.padding.extraSmall
      radius: height / 2
      anchors.verticalCenter: parent.verticalCenter
      x: root.checked ? parent.width - nonAnimWidth - Tk.padding.extraSmall / 2 : Tk.padding.extraSmall / 2
      color: root.disabled ? (root.checked ? Colours.m3surface : Qt.alpha(Colours.m3onSurface, 0.12))
        : root.checked ? Colours.m3onPrimary : Colours.m3outline
      Behavior on x { Anim { type: "fastSpatial" } }
      Behavior on width { Anim { type: "fastSpatial" } }
      Behavior on color { CAnim {} }

      Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: root.checked ? Colours.m3primary : Colours.m3onSurface
        opacity: root.pressed || root.focused ? 0.1 : root.hovered ? 0.08 : 0
        Behavior on opacity { Anim { type: "effects" } }
      }

      Shape {
        id: icon
        property point start1: root.pressed ? Qt.point(width * 0.2, height / 2)
          : root.checked ? Qt.point(width * 0.15, height / 2) : Qt.point(width * 0.15, height * 0.15)
        property point end1: root.pressed ? (root.checked ? Qt.point(width * 0.4, height / 2) : Qt.point(width * 0.8, height / 2))
          : root.checked ? Qt.point(width * 0.4, height * 0.7) : Qt.point(width * 0.85, height * 0.85)
        property point start2: root.pressed ? (root.checked ? Qt.point(width * 0.4, height / 2) : Qt.point(width * 0.2, height / 2))
          : root.checked ? Qt.point(width * 0.4, height * 0.7) : Qt.point(width * 0.15, height * 0.85)
        property point end2: root.pressed ? Qt.point(width * 0.8, height / 2)
          : root.checked ? Qt.point(width * 0.85, height * 0.2) : Qt.point(width * 0.85, height * 0.15)

        anchors.centerIn: parent
        width: height
        height: parent.height - Tk.padding.medium
        preferredRendererType: Shape.CurveRenderer
        asynchronous: true

        ShapePath {
          strokeWidth: Tk.body.large * 0.15
          strokeColor: root.disabled ? (root.checked ? Colours.m3outline : Colours.m3surfaceContainer)
            : root.checked ? Colours.m3primary : Colours.m3surfaceContainerHighest
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          startX: icon.start1.x
          startY: icon.start1.y
          PathLine { x: icon.end1.x; y: icon.end1.y }
          PathMove { x: icon.start2.x; y: icon.start2.y }
          PathLine { x: icon.end2.x; y: icon.end2.y }
          Behavior on strokeColor { CAnim {} }
        }

        Behavior on start1 { PropAnim {} }
        Behavior on end1 { PropAnim {} }
        Behavior on start2 { PropAnim {} }
        Behavior on end2 { PropAnim {} }
      }
    }
  }

  FocusRing { target: root; innerRadius: root.height / 2; shown: root.focused }

  MouseArea {
    id: mouse
    anchors.fill: parent
    enabled: !root.disabled
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled(!root.checked)
  }

  component PropAnim: PropertyAnimation {
    duration: Tk.durations.fastSpatial
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Tk.curves.fastSpatial
  }
}
