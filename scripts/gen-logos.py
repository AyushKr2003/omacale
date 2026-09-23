#!/usr/bin/env python3
"""Generate omacale.bar/components/Logos.js: the bar logo options as vector outlines.

Every logo (Omarchy's font glyph, Caelestia's paths, Nerd Font distro glyphs,
Material Symbols) is pulled out of its source, trimmed to its real bounds and
centred in a 1000x1000 box with the longest side filling it, and its aspect
ratio recorded. LogoIcon then rasterises them all the same way at the same
area, with no built-in padding, whatever font they came from.

Dev-only: needs fontTools (`pip install fonttools`) and the fonts below.
The output is committed, so installs don't need either.

  python3 scripts/gen-logos.py            # rewrite omacale.bar/components/Logos.js
"""
import os
import re
import sys

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.svgLib.path import parse_path
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "omacale.bar", "components", "Logos.js")
CAELESTIA_LOGO = os.path.join(HERE, "..", "..", "caelestia_shell", "components", "Logo.qml")

OMARCHY_FONT = "/usr/share/fonts/omarchy/omarchy.ttf"
NERD_FONT = "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf"
MATERIAL_FONT = "/usr/share/fonts/TTF/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"

BOX = 1000

# (id, label, source, key)
OPTIONS = [
    ("omarchy", "Omarchy", "omarchy", 0xE900),
    ("caelestia", "Caelestia", "caelestia", None),
    ("arch", "Arch", "nerd", 0xF303),
    ("hyprland", "Hyprland", "nerd", 0xF359),
    ("tux", "Linux", "nerd", 0xF31A),
    ("nixos", "NixOS", "nerd", 0xF313),
    ("apps", "Apps", "material", "apps"),
    ("grid_view", "Grid", "material", "grid_view"),
    ("blur_on", "Dots", "material", "blur_on"),
    ("change_history", "Triangle", "material", "change_history"),
    ("hexagon", "Hexagon", "material", "hexagon"),
    ("circle", "Circle", "material", "circle"),
    ("star", "Star", "material", "star"),
    ("diamond", "Diamond", "material", "diamond"),
    ("bolt", "Bolt", "material", "bolt"),
    ("auto_awesome", "Sparkle", "material", "auto_awesome"),
    ("rocket_launch", "Rocket", "material", "rocket_launch"),
    ("terminal", "Terminal", "material", "terminal"),
    ("spa", "Lotus", "material", "spa"),
    ("eco", "Leaf", "material", "eco"),
    ("pets", "Paw", "material", "pets"),
    ("cruelty_free", "Bunny", "material", "cruelty_free"),
    ("local_fire_department", "Flame", "material", "local_fire_department"),
]

# Extra weight for logos that read as hairlines at bar size: a stroke of the
# fill colour, this wide in BOX units (so ~1px per 45 at the bar's ~22px),
# added on both sides of every edge. Picked per logo from renders at bar
# size: outline glyphs need the most, solid ones only firming up, and each
# stops before small holes (Tux's eyes, Caelestia's stars) close up.
BOLD = {
    "caelestia": 35,  # thin crescent arc and stars
    "hyprland": 50,   # hairline droplet outline
    "tux": 45,        # outline penguin; more closes the eyes
    "arch": 25,       # solid already; firms up the thin spikes
}


def font_glyph(font, key):
    """RecordingPen of a glyph by codepoint or glyph name (font units, y up)."""
    gs = font.getGlyphSet()
    name = font.getBestCmap()[key] if isinstance(key, int) else key
    pen = RecordingPen()
    gs[name].draw(pen)
    return pen


def material_font():
    # MIcon draws with FILL 1 at the default weight/grade/optical size.
    font = TTFont(MATERIAL_FONT)
    return instancer.instantiateVariableFont(font, {"FILL": 1, "wght": 400, "GRAD": 0, "opsz": 24})


def caelestia_paths():
    """Logo.qml's paths in order, with their colour role (SVG units, y down)."""
    src = open(CAELESTIA_LOGO).read()
    out = []
    for colour, d in re.findall(r'fillColor: root\.(\w+)[\s\S]*?path: "([^"]+)"', src):
        pen = RecordingPen()
        parse_path(d, pen)
        out.append(("top" if colour == "topColour" else "bottom", pen))
    return out


def bounds(pens):
    b = BoundsPen(None)
    for _, pen in pens:
        pen.replay(b)
    return b.bounds


def normalise(pens, y_up, bold=0):
    """Fit the combined outline into BOX x BOX (longest side), centred, y down,
    leaving bold/2 on every side for LogoIcon's stroke."""
    x0, y0, x1, y1 = bounds(pens)
    w, h = x1 - x0, y1 - y0
    s = (BOX - bold) / max(w, h)
    dx = (BOX - w * s) / 2
    dy = (BOX - h * s) / 2
    if y_up:
        # flip: screen y = (y1 - y) * s + dy
        t = (s, 0, 0, -s, dx - x0 * s, dy + y1 * s)
    else:
        t = (s, 0, 0, s, dx - x0 * s, dy - y0 * s)
    out = []
    for role, pen in pens:
        svg = SVGPathPen(None, ntos=lambda v: ("%.1f" % v).rstrip("0").rstrip("."))
        pen.replay(TransformPen(svg, t))
        out.append((role, svg.getCommands()))
    return out, w / h


def omarchy_grid(font):
    """The Omarchy glyph as raw contours on its 1024 grid (y up), for LogoIcon
    to snap to whole pixels itself: every edge is axis-aligned."""
    pen = font_glyph(font, 0xE900)
    contours, cur = [], []
    for op, args in pen.value:
        if op in ("moveTo", "lineTo"):
            cur.append(args[0])
        elif op == "closePath":
            contours.append(cur)
            cur = []
        else:
            sys.exit("omarchy glyph is no longer rectilinear (%s); update LogoIcon's snapping" % op)
    return contours


def js_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    omarchy = TTFont(OMARCHY_FONT)
    nerd = TTFont(NERD_FONT)
    material = material_font()
    mat_names = set(material.getGlyphOrder())

    entries = []
    for oid, label, source, key in OPTIONS:
        if source == "omarchy":
            grid = omarchy_grid(omarchy)
            pts = ", ".join("[" + ", ".join("[%d, %d]" % p for p in c) + "]" for c in grid)
            entries.append('  { id: "%s", label: "%s", kind: "grid", grid: [%s] }' % (oid, label, pts))
            continue
        bold = BOLD.get(oid, 0)
        if source == "caelestia":
            paths, aspect = normalise(caelestia_paths(), y_up=False, bold=bold)
        elif source == "nerd":
            paths, aspect = normalise([("fg", font_glyph(nerd, key))], y_up=True, bold=bold)
        else:
            name = key + ".fill" if key + ".fill" in mat_names else key
            paths, aspect = normalise([("fg", font_glyph(material, name))], y_up=True, bold=bold)
        ps = ", ".join("[%s, %s]" % (js_str(r), js_str(d)) for r, d in paths)
        extra = ", bold: %d" % bold if bold else ""
        entries.append('  { id: "%s", label: "%s", kind: "path", aspect: %.3f%s, paths: [%s] }' % (oid, label, aspect, extra, ps))

    with open(OUT, "w") as f:
        f.write(""".pragma library

// GENERATED by scripts/gen-logos.py; edit that script, not this file.
//
// Icons the bar logo can show (Settings › Panels › Taskbar › Logo icon), in
// the spirit of Shibumi-Shell's LogoSettingsPage: Omarchy's and Caelestia's
// own logos, a few Nerd Font distro glyphs and Material Symbols (filled).
// Each is an outline trimmed to its real bounds and centred in a %d x %d box,
// longest side filling it; LogoIcon then sizes it by `aspect` so every logo
// covers the same area.
//   kind: "path" -> paths: [[role, d]], role "fg" (tinted) or Caelestia's
//                   "top" / "bottom" colours; bold: optional stroke width
//                   (box units) to thicken a logo that reads as a hairline
//         "grid" -> Omarchy's rectilinear glyph on its 1024 grid (y up),
//                   snapped to whole pixels by LogoIcon
var box = %d
var options = [
%s
]

function byId(id) {
  for (var i = 0; i < options.length; i++) if (options[i].id === id) return options[i]
  return options[0]
}
""" % (BOX, BOX, BOX, ",\n".join(entries)))
    print("wrote", os.path.relpath(OUT), "(%d logos)" % len(entries))


if __name__ == "__main__":
    main()
