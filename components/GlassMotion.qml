// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ilyamiro and the Serpantinum contributors (https://github.com/ilyamiro/serpantinum).
// Ported from Serpantinum (GlassFill.qml). See THIRD_PARTY.md.
import QtQuick

// Serpantinum's glass motion (GlassFill.qml): a surface that moves gets
// thicker, bends and splits the light more, and settles as it stops. Each
// rect's movement since it was last seen (its centre, plus half its change
// in size) adds to its energy, 36 px to the full; the energy decays 9% a
// frame. A rect that appears is only primed, so opening a drawer counts its
// slide, not its first frame. Nothing ticks while everything is still.
Item {
  id: root

  // [[x, y, w, h] or null, ...]
  property var rects: []
  // 0..1 per rect; missing is still.
  property var values: []
  property var seen: []

  visible: false

  onRectsChanged: {
    if (!enabled) return
    const v = values.slice()
    let bumped = false
    for (let i = 0; i < rects.length; i++) {
      const r = rects[i]
      const s = seen[i]
      if (!r || r[2] <= 0.5 || r[3] <= 0.5) { seen[i] = null; continue }
      if (s) {
        const d = Math.abs(r[0] + r[2] / 2 - s[0] - s[2] / 2) + Math.abs(r[1] + r[3] / 2 - s[1] - s[3] / 2)
          + 0.5 * (Math.abs(r[2] - s[2]) + Math.abs(r[3] - s[3]))
        if (d >= 0.05) {
          v[i] = Math.min(1, (v[i] || 0) + Math.min(60, d) / 36)
          bumped = true
        }
      }
      seen[i] = [r[0], r[1], r[2], r[3]]
    }
    if (bumped) {
      values = v
      decay.running = true
    }
  }
  onEnabledChanged: if (!enabled) { values = []; seen = []; decay.running = false }

  FrameAnimation {
    id: decay
    onTriggered: {
      const k = Math.pow(0.91, frameTime / 0.016)
      let any = false
      root.values = root.values.map(x => {
        const y = (x || 0) * k
        if (y < 0.004) return 0
        any = true
        return y
      })
      if (!any) running = false
    }
  }
}
