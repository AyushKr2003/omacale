pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
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
  readonly property string seedSetting: Config.o.appearance.seed
  readonly property color seed: /^#[0-9a-fA-F]{6}$/.test(seedSetting) ? seedSetting : Color.accent
  readonly property bool themeLight: {
    const b = Color.background
    return (0.2126 * b.r + 0.7152 * b.g + 0.0722 * b.b) > 0.5
  }
  readonly property string mode: Config.o.appearance.mode
  // Settings › Style › Palette: "omarchy" skips the generated scheme and
  // paints with the theme's own colours (see `om` below).
  readonly property bool omarchy: Config.o.appearance.palette === "omarchy"
  readonly property bool light: omarchy ? themeLight : mode === "light" || (mode !== "dark" && themeLight)
  readonly property string variant: Config.o.appearance.variant

  readonly property bool transparent: Config.o.appearance.transparency.enabled
  readonly property real baseAlpha: transparent ? Config.o.appearance.transparency.base : 1
  readonly property real layerAlpha: transparent ? Config.o.appearance.transparency.layers : 1

  // Colours of the active Omarchy theme, offered as seed swatches.
  property var themeSwatches: []
  // Every named colour in the theme's colors.toml (name -> "#rrggbb").
  property var themeRaw: ({})
  readonly property FileView themeColors: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    printErrors: false
    onLoaded: {
      const want = ["accent", "red", "orange", "yellow", "green", "cyan", "blue", "magenta", "color1", "color2", "color3", "color4", "color5", "color6"]
      const seen = {}, out = [], raw = {}
      seen[String(Color.accent).toLowerCase()] = true   // already offered as "Theme"
      String(text()).split("\n").forEach(l => {
        const m = l.match(/^\s*([A-Za-z0-9_]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
        if (m) raw[m[1]] = m[2]
        if (m && want.indexOf(m[1]) >= 0 && !seen[m[2].toLowerCase()]) { seen[m[2].toLowerCase()] = true; out.push({ name: m[1], color: m[2] }) }
      })
      root.themeRaw = raw
      root.themeSwatches = out.slice(0, 9)
    }
  }
  // Omarchy pushes theme switches over IPC; re-read colors.toml when the
  // theme's colours move (the seed alone misses it when a custom seed is set).
  readonly property string themeKey: String(Color.accent) + String(Color.background) + String(Color.foreground)
  onThemeKeyChanged: themeColors.reload()

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
  function hue(d) { return ((seedLch.h + d) % 360 + 360) % 360 }
  // [primary, secondary, tertiary, neutral, neutralVariant] as {h, c}, per
  // Material's dynamic scheme variants.
  readonly property var palettes: {
    const h = seedLch.h, c = seedLch.c
    const P = (dh, ch) => ({ h: hue(dh), c: ch * k })
    switch (variant) {
    case "vibrant": return [P(0, 200), P(15, 24), P(60, 32), P(0, 10), P(0, 12)]
    case "expressive": return [P(240, 40), P(15, 24), P(90, 32), P(15, 8), P(15, 12)]
    case "fidelity": return [P(0, Math.max(c, 36)), P(0, Math.max(c - 32, c * 0.5)), P(60, Math.max(c * 0.6, 24)), P(0, c / 8), P(0, c / 8 + 4)]
    case "content": return [P(0, c), P(0, Math.max(c - 32, c * 0.5)), P(60, Math.max(c * 0.6, 24)), P(0, c / 8), P(0, c / 8 + 4)]
    case "neutral": return [P(0, 12), P(0, 8), P(0, 16), P(0, 2), P(0, 2)]
    case "monochrome": return [P(0, 0), P(0, 0), P(0, 0), P(0, 0), P(0, 0)]
    case "rainbow": return [P(0, 48), P(0, 16), P(60, 24), P(0, 0), P(0, 0)]
    case "fruitsalad": return [P(-50, 48), P(-50, 36), P(0, 36), P(0, 10), P(0, 16)]
    default: return [P(0, Math.max(36, c)), P(0, 16), P(60, 24), P(0, 6), P(0, 8)]
    }
  }
  readonly property var pP: palettes[0]
  readonly property var pS: palettes[1]
  readonly property var pT: palettes[2]
  readonly property var pN: palettes[3]
  readonly property var pNV: palettes[4]
  readonly property var pE: ({ h: 25, c: 84 * k })

  function t(pal, darkTone, lightTone) { return tone(pal, light ? lightTone : darkTone) }

  // ------------------------------------------------------ Omarchy palette
  // The theme's colours on the M3 roles, the way Omarchy's own shell uses
  // them: accent for highlights, urgent for errors, surfaces stepped from
  // background towards foreground. Secondary is the accent softened towards
  // the text colour (M3's low-chroma secondary); tertiary is the theme's
  // magenta, else the accent softened further.
  function mix(a, b, f) { return Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, 1) }
  function lum(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }
  function hex(h) { return Qt.rgba(parseInt(h.slice(1, 3), 16) / 255, parseInt(h.slice(3, 5), 16) / 255, parseInt(h.slice(5, 7), 16) / 255, 1) }
  readonly property var om: {
    const bg = Color.background, fg = Color.foreground
    const raw = themeRaw
    const named = (keys, fallback) => { for (const k of keys) if (raw[k]) return hex(raw[k]); return fallback }
    // Text on a colour: whichever of background/foreground contrasts more.
    const on = c => Math.abs(lum(c) - lum(bg)) >= Math.abs(lum(c) - lum(fg)) ? bg : fg
    const s = f => mix(bg, fg, f)
    const o = {}
    const role = (name, c) => {
      o[name] = c
      o["on" + name[0].toUpperCase() + name.slice(1)] = on(c)
      o[name + "Container"] = mix(bg, c, 0.3)
      o["on" + name[0].toUpperCase() + name.slice(1) + "Container"] = mix(c, fg, 0.4)
    }
    role("primary", Color.accent)
    role("secondary", mix(Color.accent, fg, 0.45))
    role("tertiary", named(["magenta", "color5"], mix(Color.accent, fg, 0.7)))
    role("error", Color.urgent)
    o.surface = bg
    o.surfaceDim = mix(bg, Qt.rgba(0, 0, 0, 1), 0.15)
    o.surfaceBright = s(0.2)
    o.surfaceContainerLowest = mix(bg, light ? Qt.rgba(1, 1, 1, 1) : Qt.rgba(0, 0, 0, 1), 0.3)
    o.surfaceContainerLow = s(0.04)
    o.surfaceContainer = s(0.07)
    o.surfaceContainerHigh = s(0.11)
    o.surfaceContainerHighest = s(0.15)
    o.onSurface = fg
    o.surfaceVariant = s(0.2)
    o.onSurfaceVariant = s(0.78)
    o.outline = s(0.55)
    o.outlineVariant = s(0.25)
    o.inverseSurface = fg
    o.inverseOnSurface = bg
    return o
  }
  // A role's colour: the theme's in Omarchy mode, else the tone from the scheme.
  function role(name, pal, darkTone, lightTone) { return omarchy ? om[name] : t(pal, darkTone, lightTone) }

  // --------------------------------------------------------------- roles
  readonly property color m3primary: role("primary", pP, 80, 40)
  readonly property color m3onPrimary: role("onPrimary", pP, 20, 100)
  readonly property color m3primaryContainer: role("primaryContainer", pP, 30, 90)
  readonly property color m3onPrimaryContainer: role("onPrimaryContainer", pP, 90, 10)
  readonly property color m3secondary: role("secondary", pS, 80, 40)
  readonly property color m3onSecondary: role("onSecondary", pS, 20, 100)
  readonly property color m3secondaryContainer: role("secondaryContainer", pS, 30, 90)
  readonly property color m3onSecondaryContainer: role("onSecondaryContainer", pS, 90, 10)
  readonly property color m3tertiary: role("tertiary", pT, 80, 40)
  readonly property color m3onTertiary: role("onTertiary", pT, 20, 100)
  readonly property color m3tertiaryContainer: role("tertiaryContainer", pT, 30, 90)
  readonly property color m3onTertiaryContainer: role("onTertiaryContainer", pT, 90, 10)
  readonly property color m3error: role("error", pE, 80, 40)
  readonly property color m3onError: role("onError", pE, 20, 100)
  readonly property color m3errorContainer: role("errorContainer", pE, 30, 90)
  readonly property color m3onErrorContainer: role("onErrorContainer", pE, 90, 10)

  // Surfaces honour transparency (Caelestia's base/layer alphas).
  function layer(c) { return layerAlpha < 1 ? Qt.rgba(c.r, c.g, c.b, layerAlpha) : c }
  readonly property color m3surface: Qt.alpha(role("surface", pN, 6, 98), baseAlpha)
  readonly property color m3surfaceDim: role("surfaceDim", pN, 6, 87)
  readonly property color m3surfaceBright: role("surfaceBright", pN, 24, 98)
  readonly property color m3surfaceContainerLowest: layer(role("surfaceContainerLowest", pN, 4, 100))
  readonly property color m3surfaceContainerLow: layer(role("surfaceContainerLow", pN, 10, 96))
  readonly property color m3surfaceContainer: layer(role("surfaceContainer", pN, 12, 94))
  readonly property color m3surfaceContainerHigh: layer(role("surfaceContainerHigh", pN, 17, 92))
  readonly property color m3surfaceContainerHighest: layer(role("surfaceContainerHighest", pN, 22, 90))
  readonly property color m3onSurface: role("onSurface", pN, 90, 10)
  readonly property color m3surfaceVariant: role("surfaceVariant", pNV, 30, 90)
  readonly property color m3onSurfaceVariant: role("onSurfaceVariant", pNV, 80, 30)
  readonly property color m3outline: role("outline", pNV, 60, 50)
  readonly property color m3outlineVariant: role("outlineVariant", pNV, 30, 80)
  readonly property color m3inverseSurface: role("inverseSurface", pN, 90, 20)
  readonly property color m3inverseOnSurface: role("inverseOnSurface", pN, 20, 95)
  readonly property color m3scrim: Qt.rgba(0, 0, 0, 1)
  readonly property color m3shadow: Qt.rgba(0, 0, 0, 1)
}
