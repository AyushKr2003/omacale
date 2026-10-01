.pragma library

// Caelestia's per-corner radii for the blob shader: the CPU half of
// plugin/src/Caelestia/Blobs/blobshape.cpp (cornerRadii, applyCornerFill,
// accumulateNeighbourFill, accumulateInvertedFill, cornerFillFactor).
//
// A corner keeps its radius far from anything, and squares up (down to 2px)
// as it nears the frame's inner edge or another rect's edge, over one
// smoothing width. That is what lets a drawer grow out of the frame with a
// square corner, round off as it pulls away, and meet another drawer flat --
// all from where the rects are, frame by frame, with nothing declared.
//
// rects:    [[x, y, w, h], ...]; a rect w or h <= 0 is absent.
// base:     per rect, a radius or [tr, br, bl, tl] (a negative entry takes
//           the rect's radius, as BlobRect's per-corner overrides do).
// radius:   the default radius (BlobShape.radius).
// hole:     [x, y, w, h] of the frame's inner edge, or null for none.
// k:        the group's smoothing.
// excluded: [[i, j], ...] pairs that neither blend nor square each other.
// Returns [[tr, br, bl, tl], ...], one per rect.

const MIN_R = 2 // blobshape.cpp applyCornerFill k_minR

function smoothstep(e0, e1, x) {
  const t = Math.max(0, Math.min(1, (x - e0) / (e1 - e0)))
  return t * t * (3 - 2 * t)
}

// Distance from a point to a box's edge (negative inside).
function sdBox(px, py, x, y, w, h) {
  const dx = Math.abs(px - (x + w / 2)) - w / 2
  const dy = Math.abs(py - (y + h / 2)) - h / 2
  return Math.hypot(Math.max(dx, 0), Math.max(dy, 0)) + Math.min(Math.max(dx, dy), 0)
}

// Two-sided window: 0 on the neighbour's edge, 1 a smoothing width either
// side of it (outside, or buried deep inside, where squaring would only
// crease the interior).
function neighbourFactor(sd, k) {
  return Math.max(smoothstep(0, k, sd), smoothstep(0, -k, sd))
}

function present(r) { return !!r && r[2] > 0.5 && r[3] > 0.5 }

function isExcluded(excluded, i, j) {
  if (!excluded) return false
  for (let n = 0; n < excluded.length; n++) {
    const p = excluded[n]
    if ((p[0] === i && p[1] === j) || (p[0] === j && p[1] === i)) return true
  }
  return false
}

function radii(rects, base, radius, hole, k, excluded, cornerFill) {
  const fill = cornerFill !== false
  const out = []
  for (let i = 0; i < rects.length; i++) {
    const r = rects[i]
    if (!present(r)) { out.push([0, 0, 0, 0]); continue }
    const maxR = Math.min(r[2], r[3]) / 2
    const own = Math.min(radius, maxR)
    const b = base && base[i] !== undefined ? base[i] : -1
    const per = Array.isArray(b) ? b : [b, b, b, b]
    const rad = per.map(v => Math.min(v >= 0 ? v : own, maxR))

    // Corners in BlobRectData order: TR, BR, BL, TL.
    const cx = [r[0] + r[2], r[0] + r[2], r[0], r[0]]
    const cy = [r[1], r[1] + r[3], r[1] + r[3], r[1]]
    const f = [1, 1, 1, 1]
    if (fill) {
      for (let j = 0; j < rects.length; j++) {
        if (j === i || !present(rects[j]) || isExcluded(excluded, i, j)) continue
        const o = rects[j]
        for (let c = 0; c < 4; c++)
          f[c] = Math.min(f[c], neighbourFactor(sdBox(cx[c], cy[c], o[0], o[1], o[2], o[3]), k))
      }
      if (hole) {
        for (let c = 0; c < 4; c++)
          f[c] = Math.min(f[c], smoothstep(0, k, -sdBox(cx[c], cy[c], hole[0], hole[1], hole[2], hole[3])))
      }
    }
    out.push([0, 1, 2, 3].map(c => Math.max(rad[c] * f[c], MIN_R)))
  }
  return out
}
