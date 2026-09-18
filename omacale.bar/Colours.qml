pragma Singleton
import QtQuick
import qs.Commons

// Material 3 "tonal spot" scheme, the same scheme Caelestia generates from
// the wallpaper. Here the seed is the active Omarchy theme's accent, so the
// shell recolours itself on `omarchy theme set`.
//
// HCT tone == CIELAB L*, so tonal palettes are built in CIELAB LCh with the
// seed's hue, then chroma-reduced until the colour fits in sRGB.
QtObject {
  id: root

  // ------------------------------------------------------------- inputs
  readonly property color seed: Color.accent
  readonly property bool light: {
    const b = Color.background
    return (0.2126 * b.r + 0.7152 * b.g + 0.0722 * b.b) > 0.5
  }

  // ------------------------------------------------------- colour maths
  function lin(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4) }
  function gam(c) { return c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(c, 1 / 2.4) - 0.055 }
  function fLab(t) { return t > 216 / 24389 ? Math.cbrt(t) : (24389 / 27 * t + 16) / 116 }
  function fLabInv(t) { return t * t * t > 216 / 24389 ? t * t * t : (116 * t - 16) / (24389 / 27) }

  function toLch(c) {
    const r = lin(c.r), g = lin(c.g), b = lin(c.b)
    const x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047
    const y = (0.2126729 * r + 0.7151522 * g + 0.0721750 * b)
    const z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883
    const fx = fLab(x), fy = fLab(y), fz = fLab(z)
    const L = 116 * fy - 16, A = 500 * (fx - fy), B = 200 * (fy - fz)
    return { l: L, c: Math.sqrt(A * A + B * B), h: (Math.atan2(B, A) * 180 / Math.PI + 360) % 360 }
  }

  function lchToRgb(L, C, h) {
    const hr = h * Math.PI / 180
    const A = C * Math.cos(hr), B = C * Math.sin(hr)
    const fy = (L + 16) / 116, fx = fy + A / 500, fz = fy - B / 200
    const x = fLabInv(fx) * 0.95047, y = L > 8 ? fy * fy * fy : L / (24389 / 27), z = fLabInv(fz) * 1.08883
    return [
      3.2404542 * x - 1.5371385 * y - 0.4985314 * z,
      -0.9692660 * x + 1.8760108 * y + 0.0415560 * z,
      0.0556434 * x - 0.2040259 * y + 1.0572252 * z
    ]
  }

  function inGamut(v) { return v[0] >= -1e-4 && v[0] <= 1.0001 && v[1] >= -1e-4 && v[1] <= 1.0001 && v[2] >= -1e-4 && v[2] <= 1.0001 }

  // Colour at a given tone of a (hue, chroma) palette.
  function tone(pal, t) {
    if (t <= 0) return Qt.rgba(0, 0, 0, 1)
    if (t >= 100) return Qt.rgba(1, 1, 1, 1)
    let lo = 0, hi = pal.c, v = lchToRgb(t, hi, pal.h)
    if (!inGamut(v)) {
      for (let i = 0; i < 18; i++) {
        const mid = (lo + hi) / 2
        if (inGamut(lchToRgb(t, mid, pal.h))) lo = mid; else hi = mid
      }
      v = lchToRgb(t, lo, pal.h)
    }
    const cl = x => Math.max(0, Math.min(1, gam(Math.max(0, x))))
    return Qt.rgba(cl(v[0]), cl(v[1]), cl(v[2]), 1)
  }

  // ----------------------------------------------------------- palettes
  readonly property var seedLch: toLch(seed)
  // LCh chroma runs ~10% hotter than HCT chroma; scale the M3 targets down.
  readonly property real k: 0.9
  readonly property var pP: ({ h: seedLch.h, c: Math.max(36, seedLch.c) * k })
  readonly property var pS: ({ h: seedLch.h, c: 16 * k })
  readonly property var pT: ({ h: (seedLch.h + 60) % 360, c: 24 * k })
  readonly property var pN: ({ h: seedLch.h, c: 6 * k })
  readonly property var pNV: ({ h: seedLch.h, c: 8 * k })
  readonly property var pE: ({ h: 25, c: 84 * k })

  function t(pal, darkTone, lightTone) { return tone(pal, light ? lightTone : darkTone) }

  // --------------------------------------------------------------- roles
  readonly property color m3primary: t(pP, 80, 40)
  readonly property color m3onPrimary: t(pP, 20, 100)
  readonly property color m3primaryContainer: t(pP, 30, 90)
  readonly property color m3onPrimaryContainer: t(pP, 90, 10)
  readonly property color m3secondary: t(pS, 80, 40)
  readonly property color m3onSecondary: t(pS, 20, 100)
  readonly property color m3secondaryContainer: t(pS, 30, 90)
  readonly property color m3onSecondaryContainer: t(pS, 90, 10)
  readonly property color m3tertiary: t(pT, 80, 40)
  readonly property color m3onTertiary: t(pT, 20, 100)
  readonly property color m3tertiaryContainer: t(pT, 30, 90)
  readonly property color m3onTertiaryContainer: t(pT, 90, 10)
  readonly property color m3error: t(pE, 80, 40)
  readonly property color m3onError: t(pE, 20, 100)
  readonly property color m3errorContainer: t(pE, 30, 90)
  readonly property color m3onErrorContainer: t(pE, 90, 10)

  readonly property color m3surface: t(pN, 6, 98)
  readonly property color m3surfaceDim: t(pN, 6, 87)
  readonly property color m3surfaceBright: t(pN, 24, 98)
  readonly property color m3surfaceContainerLowest: t(pN, 4, 100)
  readonly property color m3surfaceContainerLow: t(pN, 10, 96)
  readonly property color m3surfaceContainer: t(pN, 12, 94)
  readonly property color m3surfaceContainerHigh: t(pN, 17, 92)
  readonly property color m3surfaceContainerHighest: t(pN, 22, 90)
  readonly property color m3onSurface: t(pN, 90, 10)
  readonly property color m3surfaceVariant: t(pNV, 30, 90)
  readonly property color m3onSurfaceVariant: t(pNV, 80, 30)
  readonly property color m3outline: t(pNV, 60, 50)
  readonly property color m3outlineVariant: t(pNV, 30, 80)
  readonly property color m3inverseSurface: t(pN, 90, 20)
  readonly property color m3inverseOnSurface: t(pN, 20, 95)
  readonly property color m3scrim: Qt.rgba(0, 0, 0, 1)
  readonly property color m3shadow: Qt.rgba(0, 0, 0, 1)
}
