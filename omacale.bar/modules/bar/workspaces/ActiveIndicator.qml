import QtQuick
import QtQuick.Effects
import "../../.."

// Caelestia modules/bar/components/workspaces/ActiveIndicator.qml: a pill that
// slides between workspaces with a trailing edge. Its content is `list`
// recoloured, so the icons under it read as onPrimary (onTertiary for the
// special workspaces).
Rectangle {
  id: root

  required property Item list   // the workspace column (row, on a top or bottom bar); `target` is one of its children
  property bool vertical: true
  property Item target
  property bool trail: Config.o.bar.workspaces.activeTrail
  property alias contentColour: colouriser.colorizationColor
  property real start: 0
  property real end: 0

  function run() {
    if (!target) return
    const s = vertical ? target.y : target.x, e = s + (vertical ? target.height : target.width)
    const up = s < start
    const lead = Tk.durations.defaultSpatial, trailing = lead * (trail ? 1.5 : 1)
    sA.stop(); eA.stop()
    sA.to = s; eA.to = e
    sA.duration = up ? lead : trailing
    eA.duration = up ? trailing : lead
    sA.start(); eA.start()
  }
  onTargetChanged: run()
  Connections {
    target: root.target
    function onYChanged() { root.run() }
    function onHeightChanged() { root.run() }
    function onXChanged() { root.run() }
    function onWidthChanged() { root.run() }
  }
  Component.onCompleted: run()

  NumberAnimation { id: sA; target: root; property: "start"; easing.type: Easing.BezierSpline; easing.bezierCurve: Tk.curves.defaultSpatial }
  NumberAnimation { id: eA; target: root; property: "end"; easing.type: Easing.BezierSpline; easing.bezierCurve: Tk.curves.defaultSpatial }

  x: vertical ? list.x : list.x + start
  y: vertical ? list.y + start : list.y
  width: vertical ? list.width : Math.max(0, end - start)
  height: vertical ? Math.max(0, end - start) : list.height
  radius: (vertical ? list.width : list.height) / 2
  color: Colours.m3primary
  clip: true

  MultiEffect {
    id: colouriser
    x: root.vertical ? 0 : -root.start
    y: root.vertical ? -root.start : 0
    width: root.list.width
    height: root.list.height
    source: ShaderEffectSource { sourceItem: root.list; hideSource: false; live: true }
    colorization: 1
    colorizationColor: Colours.m3onPrimary
    brightness: 1 - Colours.m3onSurface.hslLightness
  }
}
