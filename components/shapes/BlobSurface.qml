import QtQuick
import "BlobFill.js" as BlobFill
import "../.."

// One blob group, drawn by shaders/blob.frag: Caelestia's BlobGroup with a
// BlobInvertedRect (the frame, when `framed`) and up to nine BlobRects.
// Everything Caelestia's C++ works out per frame is done here: the rects'
// corner radii after corner fill (BlobFill.js), and each rect's deformation
// (a BlobDeform's `vec`, passed in `deforms`).
ShaderEffect {
  id: root

  // [[x, y, w, h], ...], up to nine; a missing or empty rect draws nothing.
  property var rects: []
  // Per rect: a radius, or [tr, br, bl, tl]; -1 (or missing) is `radius`.
  property var corners: []
  property real radius: Tk.rounding.extraLarge
  // BlobGroup.cornerFill.
  property bool cornerFill: true
  // Per rect, a vector4d (m00, m01, m11, 0); missing is no deformation.
  property var deforms: []
  // [[i, j], ...]: pairs that neither blend nor square each other's corners.
  // Only (5, 6) and (1, 8) are honoured by the shader.
  property var excluded: []

  // The frame: an inverted rect whose hole is `hole`, rounded by holeRadius.
  property bool framed: true
  property rect hole: Qt.rect(0, 0, width, height)
  property real smoothing: Tk.smoothing
  property real frameRadius: Tk.borderRounding
  property color color: Colours.m3surface

  readonly property var fill: BlobFill.radii(rects, corners, radius,
    framed ? [hole.x, hole.y, hole.width, hole.height] : null, smoothing, excluded, cornerFill)

  function rectAt(i) {
    const r = rects[i]
    return r && r[2] > 0.5 && r[3] > 0.5 ? Qt.rect(r[0], r[1], r[2], r[3]) : Qt.rect(0, 0, 0, 0)
  }
  function radiiAt(i) {
    const c = fill[i]
    return c ? Qt.vector4d(c[0], c[1], c[2], c[3]) : Qt.vector4d(0, 0, 0, 0)
  }
  function deformAt(i) { return deforms[i] || Qt.vector4d(1, 0, 1, 0) }
  function excludes(i, j) { return excluded.some(p => (p[0] === i && p[1] === j) || (p[0] === j && p[1] === i)) }

  fragmentShader: Qt.resolvedUrl("../../shaders/blob.frag.qsb")

  property size res: Qt.size(width, height)
  property real holeRadius: framed ? frameRadius : -1
  property rect r0: rectAt(0)
  property rect r1: rectAt(1)
  property rect r2: rectAt(2)
  property rect r3: rectAt(3)
  property rect r4: rectAt(4)
  property rect r5: rectAt(5)
  property rect r6: rectAt(6)
  property rect r7: rectAt(7)
  property rect r8: rectAt(8)
  property vector4d c0: radiiAt(0)
  property vector4d c1: radiiAt(1)
  property vector4d c2: radiiAt(2)
  property vector4d c3: radiiAt(3)
  property vector4d c4: radiiAt(4)
  property vector4d c5: radiiAt(5)
  property vector4d c6: radiiAt(6)
  property vector4d c7: radiiAt(7)
  property vector4d c8: radiiAt(8)
  property vector4d d0: deformAt(0)
  property vector4d d1: deformAt(1)
  property vector4d d2: deformAt(2)
  property vector4d d3: deformAt(3)
  property vector4d d4: deformAt(4)
  property vector4d d5: deformAt(5)
  property vector4d d6: deformAt(6)
  property vector4d d7: deformAt(7)
  property vector4d d8: deformAt(8)
  property real excl56: excludes(5, 6) ? 1 : 0
  property real excl18: excludes(1, 8) ? 1 : 0
}
