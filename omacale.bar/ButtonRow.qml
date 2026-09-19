import QtQuick

// Caelestia ButtonRow: children that set fillWidth share the row equally, and
// a child that reports a shapeMorphExpansion (a pressed button) bulges while
// its neighbours yield: edge neighbours give the full amount, inner ones half.
Item {
  id: root
  property real spacing: 0
  property var _hooked: []
  property bool _dirty: false

  function invalidate() {
    if (_dirty) return
    _dirty = true
    Qt.callLater(root.relayout)
  }

  onWidthChanged: invalidate()
  onChildrenChanged: {
    for (const c of children) {
      if (_hooked.indexOf(c) !== -1) continue
      _hooked.push(c)
      c.implicitWidthChanged.connect(invalidate)
      c.implicitHeightChanged.connect(invalidate)
      c.visibleChanged.connect(invalidate)
      if (c.shapeMorphExpansion !== undefined) c.shapeMorphExpansionChanged.connect(invalidate)
    }
    invalidate()
  }

  function morph(item) { return item && item.shapeMorphExpansion ? item.shapeMorphExpansion : 0 }

  function relayout() {
    _dirty = false
    const items = []
    for (const c of children) if (c.visible && typeof c.itemAt !== "function") items.push(c)
    const n = items.length
    if (n === 0) return
    const totalSpacing = (n - 1) * spacing
    let reserved = 0, unreserved = 0, fillCount = 0, maxH = 0
    for (const c of items) {
      maxH = Math.max(maxH, c.implicitHeight)
      if (c.fillWidth === undefined) continue
      if (c.fillWidth) { fillCount++; unreserved += c.implicitWidth } else reserved += c.implicitWidth
    }
    if (fillCount === 0) fillCount = 1
    const per = (width - totalSpacing - reserved) / fillCount
    let x = 0
    for (let i = 0; i < n; i++) {
      const c = items[i]
      let prev = i > 0 ? morph(items[i - 1]) : 0
      let next = i < n - 1 ? morph(items[i + 1]) : 0
      if (i > 1) prev /= 2
      if (i < n - 2) next /= 2
      const base = c.fillWidth ? per : c.implicitWidth
      c.width = base + morph(c) - prev - next
      c.height = maxH
      c.x = x
      c.y = 0
      x += c.width + spacing
    }
    implicitWidth = reserved + unreserved + totalSpacing
    implicitHeight = maxH
  }
}
