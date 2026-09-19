import QtQuick
import "Logos.js" as Logos

// One bar-logo option (Logos.js) drawn at `size` x `size`, in `colour`.
//
// Every logo goes through the same path: its outline (already trimmed and
// centred by scripts/gen-logos.py) is written into an SVG with the colours
// filled in, and Image rasterises it at the exact pixel size, the way
// Caelestia's ColouredIcon, Lacuna and Shibumi draw small logos. So every
// logo is the same size, whatever font or file it came from, and none is a
// scaled-down texture or a glyph with its own padding and hinting.
Item {
  id: root
  property string value: "omarchy"
  property real size: Math.round(Tk.body.large * 1.2)
  property color colour: Colours.m3tertiary
  // Caelestia's logo keeps its own two tones (components/Logo.qml).
  property color topColour: Colours.m3primary
  property color bottomColour: Colours.m3onSurface

  readonly property var opt: Logos.byId(value)
  readonly property int px: Math.max(1, Math.round(size))
  // Same area for every logo, not the same longest side: a wide or tall
  // logo fitted into the square would look smaller than a square one. So it
  // grows by sqrt(aspect) along its long side and shrinks the same along the
  // short one (Caelestia likewise lets its wide logo spill past the slot).
  readonly property int drawPx: opt.kind === "path" ? Math.round(px * Math.sqrt(Math.max(opt.aspect, 1 / opt.aspect))) : px

  implicitWidth: size
  implicitHeight: size

  function rgb(c) {
    return 'rgb(' + Math.round(c.r * 255) + ',' + Math.round(c.g * 255) + ',' + Math.round(c.b * 255) + ')'
  }
  function fill(c) {
    return 'fill="' + rgb(c) + '" fill-opacity="' + c.a + '"'
  }
  // A stroke in the fill colour thickens a logo evenly on every edge (see
  // BOLD in scripts/gen-logos.py, which also leaves room for it in the box).
  function stroke(c, w) {
    return w ? ' stroke="' + rgb(c) + '" stroke-opacity="' + c.a + '" stroke-width="' + w + '" stroke-linejoin="round"' : ''
  }
  function roleColour(role) {
    return role === "top" ? topColour : role === "bottom" ? bottomColour : colour
  }

  // Omarchy's mark, rebuilt on the pixel grid. The glyph is all 70-unit
  // lines and gaps on a 1024 grid (bands at 0/70/140/210 from each edge) with
  // one-unit connectors and notches around the middle; scaled as-is, its
  // lines land between pixels at almost every size. Here each band is a whole
  // number of pixels, with the lines (T) weighted heavier than the gap
  // between the rings (G) so the mark doesn't read as a hairline at bar
  // size; connectors are T wide around the design's centre line, notches G,
  // and the interior takes the remainder.
  function gridPath(grid, S) {
    const u = 70 * S / 1024
    const T = Math.max(2, Math.round(u * 1.4))
    const G = Math.max(1, Math.round(u * 0.8))
    const c = Math.round(510 * S / 1024 - T / 2)
    const snap = {
      0: 0, 70: T, 140: T + G, 210: 2 * T + G,
      471: c, 473: c, 549: c + T, 551: c + T, 626: c + T + G,
      736: S - 3 * T - G, 814: S - 2 * T - G, 884: S - T - G, 954: S - T, 1024: S
    }
    const m = v => snap[v] !== undefined ? snap[v] : Math.round(v * S / 1024)
    let d = ""
    for (const contour of grid)
      d += "M" + contour.map(p => m(p[0]) + " " + (S - m(p[1]))).join("L") + "Z"
    return d
  }

  readonly property string svg: {
    const o = opt
    if (o.kind === "grid") {
      return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + px + ' ' + px + '">'
        + '<path ' + fill(colour) + ' d="' + gridPath(o.grid, px) + '"/></svg>'
    }
    let s = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + Logos.box + ' ' + Logos.box + '">'
    for (const p of o.paths)
      s += '<path ' + fill(roleColour(p[0])) + stroke(roleColour(p[0]), o.bold) + ' d="' + p[1] + '"/>'
    return s + '</svg>'
  }

  Image {
    // Whole-pixel size and position: a half-pixel offset is what makes small
    // icons look soft.
    x: Math.round((root.width - width) / 2)
    y: Math.round((root.height - height) / 2)
    width: root.drawPx
    height: root.drawPx
    sourceSize: Qt.size(root.drawPx, root.drawPx)
    smooth: true
    source: "data:image/svg+xml;utf8," + encodeURIComponent(root.svg)
  }
}
