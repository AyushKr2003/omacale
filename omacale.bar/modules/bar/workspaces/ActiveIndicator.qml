import QtQuick
import QtQuick.Effects
import "../../.."

// Caelestia modules/bar/components/workspaces/ActiveIndicator.qml: a pill that
// slides between workspaces with a trailing edge. Its content is `list`
// recoloured, so the icons under it read as onPrimary (onTertiary for the
// special workspaces).
Rectangle {
  id: root

  required property Item list   // the workspace column; `target` is one of its children
  property Item target
  property bool trail: Config.o.bar.workspaces.activeTrail
  property alias contentColour: colouriser.colorizationColor
  property real start: 0
  property real end: 0

  function run() {
    if (!target) return
    const s = target.y, e = target.y + target.height
    const up = s < start
    const lead = Tk.durations.defaultSpatial, trailing = lead * (trail ? 1.5 : 1)
    sA.stop(); eA.stop()
    sA.to = s; eA.to = e
    sA.duration = up ? lead : trailing
    eA.duration = up ? trailing : lead
    sA.start(); eA.start()
  }
  onTargetChanged: run()
  Connections { target: root.target; function onYChanged() { root.run() } function onHeightChanged() { root.run() } }
  Component.onCompleted: run()

  NumberAnimation { id: sA; target: root; property: "start"; easing.type: Easing.BezierSpline; easing.bezierCurve: Tk.curves.defaultSpatial }
  NumberAnimation { id: eA; target: root; property: "end"; easing.type: Easing.BezierSpline; easing.bezierCurve: Tk.curves.defaultSpatial }

  x: list.x
  y: list.y + start
  width: list.width
  height: Math.max(0, end - start)
  radius: width / 2
  color: Colours.m3primary
  clip: true

  MultiEffect {
    id: colouriser
    x: 0
    y: -root.start
    width: root.list.width
    height: root.list.height
    source: ShaderEffectSource { sourceItem: root.list; hideSource: false; live: true }
    colorization: 1
    colorizationColor: Colours.m3onPrimary
    brightness: 1 - Colours.m3onSurface.hslLightness
  }
}
