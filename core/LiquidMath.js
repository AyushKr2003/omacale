.pragma library
// Portions from Vitreus (MIT, Copyright (c) 2026 natepayn3); see THIRD_PARTY.md.

// Liquid motion's arithmetic: no Caelestia original. A port of Vitreus
// (shell/Vitreus/vitreus.plm, pages/bar_shapes.plm), where every drawer is a
// shape blended into the bar that moves on a spring: it overshoots and
// settles, is joined to the bar by a neck that is thickest halfway, is a
// little narrower on the way (a falling drop), starts round and squares up
// as it grows, bulges sideways when it overshoots, and sags and shakes once
// as it lands. Pure, so `node tests/test-liquid.js` runs it.

// The numbers a preset sets; the booleans (neck, rounding, detach.*) are
// always the user's. balanced is the reference's own (Vitreus): `spring drip = 170, 18`, the
// `max(0, p - 1) * 0.6` bulge, `(26 + 20 * bell) * u` necks (Omacale's
// base being its smoothing), `0.07 * bell` narrowing, `impulse sag 220`
// and `impulse wobble -260`.
var NUMBERS = ["stiffness", "damping", "bulge", "neckWidth", "narrow", "sag", "wobble"]
var PRESETS = {
  subtle: { stiffness: 220, damping: 26, bulge: 0.3, neckWidth: 10, narrow: 0.04, sag: 120, wobble: 120 },
  balanced: { stiffness: 170, damping: 18, bulge: 0.6, neckWidth: 20, narrow: 0.07, sag: 220, wobble: 260 },
  bouncy: { stiffness: 260, damping: 14, bulge: 0.9, neckWidth: 28, narrow: 0.1, sag: 300, wobble: 420 }
}

// Vitreus's other springs: `hang` (critically damped, one slow hump) carries
// the sag, `splash` (two bounces you can see) the wobble.
var HANG = { stiffness: 260, damping: 32 }
var SPLASH = { stiffness: 420, damping: 13 }

// The drop style's narrowest: Vitreus's calendar comes out 120 of 450 wide.
var DROP_MIN = 0.3

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
function clamp01(v) { return clamp(v, 0, 1) }
function mix(a, b, t) { return a + (b - a) * t }

// A preset's numbers, or (custom) the stored ones; anything missing or
// not a number falls back to balanced.
function resolve(preset, stored) {
  var src = PRESETS[preset] || stored || {}
  var out = {}
  for (var i = 0; i < NUMBERS.length; i++) {
    var k = NUMBERS[i]
    var v = Number(src[k])
    out[k] = isFinite(v) ? v : PRESETS.balanced[k]
  }
  out.stiffness = Math.max(1, out.stiffness)
  out.damping = Math.max(0, out.damping)
  return out
}

// A spring made `scale` times slower (Settings' animation duration): the
// period goes as 1 / sqrt(k), the damping ratio c / (2 sqrt(k)) is kept.
function slowed(stiffness, damping, scale) {
  var s = Math.max(0.05, scale)
  return [stiffness / (s * s), damping / s]
}

// One frame of a unit-mass spring (semi-implicit Euler in 1/240 s steps,
// stable for any stiffness the settings allow). Returns [x, v].
function step(x, v, target, stiffness, damping, dt) {
  var n = Math.max(1, Math.ceil(dt * 240))
  var h = dt / n
  for (var i = 0; i < n; i++) {
    v += (-stiffness * (x - target) - damping * v) * h
    x += v * h
  }
  return [x, v]
}

// How far a spring overshoots once (0..1), for the Settings readout.
function overshoot(stiffness, damping) {
  var zeta = damping / (2 * Math.sqrt(Math.max(1e-6, stiffness)))
  if (zeta >= 1) return 0
  return Math.exp(-Math.PI * zeta / Math.sqrt(1 - zeta * zeta))
}

// Vitreus `*.bell`: 0 shut, 1 halfway, 0 open.
function bell(p) {
  var c = clamp01(p)
  return 4 * c * (1 - c)
}

// The drawer's rect [x, y, w, h] as liquid draws it, at progress p (0 shut,
// 1 open, more while it overshoots). `edge` is the frame edge it comes out
// of (top, bottom, left, right, or none for a floating one). Across that
// edge it narrows halfway, bulges on the overshoot and wobbles; along it,
// it sags from the free end and grows by its overshoot (Vitreus's heights
// scale with the unclamped spring), so the edge it hangs from never moves:
// ScreenScope slides it by the clamped `off`.
// drop: it grows out of the edge instead of sliding (x/y are its open
// place), reaching `bury` px into the frame so it melts into it.
// How wide it is across its edge, over its own width.
function across(p, o, wobble, drop) {
  var f = 1 - o.narrow * bell(p) + Math.max(0, p - 1) * o.bulge + 0.003 * wobble
  if (drop) f *= DROP_MIN + (1 - DROP_MIN) * Math.min(1, Math.max(0, p) * 1.6)
  return Math.max(0, f)
}

function shape(r, edge, p, o, sag, wobble, drop, bury) {
  if (!r) return r
  var vert = edge === "top" || edge === "bottom"
  var across_ = vert ? r[2] : r[3]
  var along = vert ? r[3] : r[2]
  var pc = Math.max(0, p)
  var f = across(p, o, wobble, drop)
  var a2 = across_ * f
  var b = drop ? Math.min(1, pc * 4) * (bury || 0) : 0
  var grow = drop ? pc : 1 + Math.max(0, p - 1)
  var l2 = Math.max(0, (along * grow + b) * (1 - 0.002 * wobble) + sag)
  // Floating: it narrows and bulges on both axes about its centre, and
  // has no free end to sag from.
  if (edge === "none") {
    var w = r[2] * f
    var h = Math.max(0, r[3] * (f - 0.005 * wobble))
    return [r[0] + (r[2] - w) / 2, r[1] + (r[3] - h) / 2, w, h]
  }
  var c = vert ? r[0] + (r[2] - a2) / 2 : r[1] + (r[3] - a2) / 2
  if (edge === "top") return [c, drop ? r[1] - b : r[1], a2, l2]
  if (edge === "bottom") return [c, drop ? r[1] + r[3] + b - l2 : r[1] + r[3] - l2, a2, l2]
  if (edge === "left") return [drop ? r[0] - b : r[0], c, l2, a2]
  return [drop ? r[0] + r[2] + b - l2 : r[0] + r[2] - l2, c, l2, a2]
}

// The content's scale, so it stays inside its shape: as narrow as it is
// across (never wider than its own), and, dropping, as long as it has grown.
function contentScale(edge, p, o, wobble, drop) {
  var a = Math.min(1, across(p, o, wobble, drop))
  var l = drop ? Math.min(1, Math.max(0, p)) : 1
  var vert = edge === "top" || edge === "bottom"
  return vert ? [a, l] : [l, a]
}

// The content's opacity: it comes in once the drawer has room for it, as
// Vitreus's contents arrive after their drawer.
function contentOpacity(p, drop) {
  return drop ? clamp01((p - 0.3) / 0.7) : clamp01((p - 0.2) / 0.8)
}

// Vitreus `corner: mix(min(w, h) / 2, rc, clamp(p * 1.6 - 0.1, 0, 1))`:
// round as a drop at first, its own radius once grown. Vitreus's drawers
// are small while they are round; a big one sliding out at full size would
// be a disc, so the drop's radius stops at four of its own.
var DROP_ROUND = 4
function radius(r, base, p) {
  if (!r) return base
  return mix(Math.min(Math.min(r[2], r[3]) / 2, base * DROP_ROUND), base, clamp01(p * 1.6 - 0.1))
}

// The extra blend (px) that makes the neck, at progress p.
function neck(width, p) {
  return Math.max(0, width) * bell(p)
}

// Vitreus `dj.neck = 52 * u * 4 * out * (1 - out)`: the thread that joins a
// drawer leaving the bar to it, gone (broken) by the time it is free.
function thread(width, t) {
  return Math.max(0, width) * bell(t)
}

// The ripples and the stray drop left on the edge a drawer broke away
// from (Vitreus dj.ripx / dj.riph / dj.stray), at ripple progress `rip`
// (0 at the break, 1 spent) and stray `stray` (1 at the break, 0 gone).
// Returns [spread, height, strayRadius] in units of `u` px.
function ripples(rip, stray, u) {
  return [(12 + 90 * rip) * u, 20 * u * (1 - rip) * clamp01(rip * 6), 10 * u * stray]
}
