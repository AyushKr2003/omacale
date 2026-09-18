.pragma library

// Polar radius functions for the M3 shapes drawn by MShape.qml.

function poly(th, n, rot, round) {
  const seg = 2 * Math.PI / n
  let a = ((th - rot) % seg + seg) % seg - seg / 2
  const p = Math.cos(Math.PI / n) / Math.cos(a)
  return p * (1 - round) + Math.cos(Math.PI / n) * round * 1.08
}
function supe(th, rot, a, b, n) {
  const c = Math.abs(Math.cos(th - rot)) / a, s = Math.abs(Math.sin(th - rot)) / b
  return Math.pow(Math.pow(c, n) + Math.pow(s, n), -1 / n)
}
function radius(name, th) {
  const PI = Math.PI
  switch (name) {
  case "square": return supe(th, 0, 1, 1, 5)
  case "slanted": return supe(th, -0.2, 1, 0.92, 4.5)
  case "oval": return supe(th, -PI / 4, 1, 0.66, 2)
  case "pill": return supe(th, -PI / 4, 1, 0.58, 3.2)
  case "triangle": return poly(th, 3, -PI / 2, 0.3)
  case "arrow": return poly(th, 3, -PI / 2, 0.22) * (Math.sin(th) > 0 ? 1 - 0.25 * Math.pow(Math.sin(th), 6) : 1)
  case "diamond": return supe(th, PI / 4, 1, 0.82, 1.35)
  case "pentagon": return poly(th, 5, -PI / 2, 0.3)
  case "gem": return poly(th, 6, 0, 0.3) * (1 - 0.1 * Math.pow(Math.cos(th), 2))
  case "sunny": return 0.9 + 0.1 * Math.cos(8 * th)
  case "verySunny": return 0.8 + 0.2 * Math.cos(8 * th)
  case "cookie4": return 0.86 + 0.14 * Math.cos(4 * (th - PI / 4))
  case "cookie6": return 0.9 + 0.1 * Math.cos(6 * th)
  case "cookie7": return 0.9 + 0.1 * Math.cos(7 * (th + PI / 2))
  case "cookie9": return 0.92 + 0.08 * Math.cos(9 * (th + PI / 2))
  case "cookie12": return 0.93 + 0.07 * Math.cos(12 * th)
  case "clover4": return 0.62 + 0.38 * Math.pow(Math.abs(Math.cos(2 * th - PI / 2)), 0.8)
  case "softBurst": return 0.88 + 0.12 * Math.cos(10 * th)
  case "ghostish": return Math.sin(th) > 0.2 ? 0.9 + 0.1 * Math.cos(6 * th) : 1
  case "arch": return Math.sin(th) < 0 ? 1 : supe(th, 0, 1, 1, 6)
  case "fan": return (th > Math.PI && th < 1.5 * Math.PI) ? supe(th, 0, 1, 1, 8) : 1
  case "clamShell": return supe(th, 0, 1, 0.8, 3) * (0.97 + 0.03 * Math.cos(10 * th))
  default: return 1
  }
}
function radii(name, samples) {
  const out = []
  let maxX = 0, maxY = 0
  for (let i = 0; i < samples; i++) {
    const th = i / samples * 2 * Math.PI
    const r = radius(name, th)
    out.push(r)
    maxX = Math.max(maxX, Math.abs(r * Math.cos(th)))
    maxY = Math.max(maxY, Math.abs(r * Math.sin(th)))
  }
  const s = 1 / Math.max(maxX, maxY)
  return out.map(r => r * s)
}

