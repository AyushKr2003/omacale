import QtQuick
import "../.."

// Caelestia plugin/src/Caelestia/Components/visualiserbars.cpp, in QML: two
// mirrored banks of bars filling the outer 40% of each side, up to 40% of the
// height, eased towards the latest values with the same exponential step.
//
// Caelestia's C++ item repaints a QPainter texture the size of the screen on
// every frame. Here the bars are drawn by shaders/visualiser.frag on one quad
// that covers only their reach, so a frame is 30 uniforms and nothing else:
// no texture, no item per bar.
Item {
  id: root

  property var values: []
  property color primaryColor
  property color secondaryColor
  property real rounding: 0
  property real spacing: 0
  property int animationDuration: 200

  // The eased heights. A plain array, not a list property, so easing it
  // notifies nothing; the shader is handed the result.
  property var _shown: []

  onValuesChanged: {
    while (_shown.length < values.length) _shown.push(0)
    _shown.length = values.length
    bars.count = values.length
    anim.running = visible
  }
  onVisibleChanged: if (!visible) anim.running = false

  function advance(dt) {
    const alpha = 1 - Math.exp(-dt * 1000 / (animationDuration / 3))
    const d = _shown, v = values
    let all = true
    for (let i = 0; i < d.length; i++) {
      const diff = (v[i] || 0) - d[i]
      if (Math.abs(diff) > 0.001) { d[i] += diff * alpha; all = false }
      else d[i] = v[i] || 0
    }
    for (let k = 0, b = 0; k < 30 && b < d.length; k++, b += 4)
      bars["v" + k] = Qt.vector4d(d[b], d[b + 1] || 0, d[b + 2] || 0, d[b + 3] || 0)
    if (all) anim.running = false
  }

  FrameAnimation {
    id: anim
    onTriggered: root.advance(frameTime)
  }

  ShaderEffect {
    id: bars

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: parent.height * 0.4
    blending: true
    fragmentShader: Qt.resolvedUrl("../../shaders/visualiser.frag.qsb")

    property size res: Qt.size(width, height)
    property real count: 0
    property real spacing: root.spacing
    property real rounding: root.rounding
    property color primaryColor: root.primaryColor
    property color secondaryColor: root.secondaryColor
    property vector4d v0; property vector4d v1; property vector4d v2; property vector4d v3; property vector4d v4
    property vector4d v5; property vector4d v6; property vector4d v7; property vector4d v8; property vector4d v9
    property vector4d v10; property vector4d v11; property vector4d v12; property vector4d v13; property vector4d v14
    property vector4d v15; property vector4d v16; property vector4d v17; property vector4d v18; property vector4d v19
    property vector4d v20; property vector4d v21; property vector4d v22; property vector4d v23; property vector4d v24
    property vector4d v25; property vector4d v26; property vector4d v27; property vector4d v28; property vector4d v29
  }
}
