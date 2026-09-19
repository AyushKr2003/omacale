.pragma library

// Icons the bar logo can show (Settings › Panels › Taskbar › Logo icon), in
// the spirit of Shibumi-Shell's LogoSettingsPage but kept to simple marks:
// Omarchy's own logo, a few distro glyphs from the Nerd Font, and plain
// Material Symbols.
//   kind: "image"    -> Omarchy's icon.png, tinted
//         "nerd"     -> glyph in Tk.mono (JetBrainsMono Nerd Font)
//         "material" -> Material Symbols icon name
var options = [
  { id: "omarchy", label: "Omarchy", kind: "image" },
  { id: "arch", label: "Arch", kind: "nerd", glyph: "" },
  { id: "hyprland", label: "Hyprland", kind: "nerd", glyph: "" },
  { id: "tux", label: "Linux", kind: "nerd", glyph: "" },
  { id: "nixos", label: "NixOS", kind: "nerd", glyph: "" },
  { id: "apps", label: "Apps", kind: "material", glyph: "apps" },
  { id: "grid_view", label: "Grid", kind: "material", glyph: "grid_view" },
  { id: "blur_on", label: "Dots", kind: "material", glyph: "blur_on" },
  { id: "change_history", label: "Triangle", kind: "material", glyph: "change_history" },
  { id: "hexagon", label: "Hexagon", kind: "material", glyph: "hexagon" },
  { id: "circle", label: "Circle", kind: "material", glyph: "circle" },
  { id: "star", label: "Star", kind: "material", glyph: "star" },
  { id: "diamond", label: "Diamond", kind: "material", glyph: "diamond" },
  { id: "bolt", label: "Bolt", kind: "material", glyph: "bolt" },
  { id: "auto_awesome", label: "Sparkle", kind: "material", glyph: "auto_awesome" },
  { id: "rocket_launch", label: "Rocket", kind: "material", glyph: "rocket_launch" },
  { id: "terminal", label: "Terminal", kind: "material", glyph: "terminal" },
  { id: "spa", label: "Lotus", kind: "material", glyph: "spa" },
  { id: "eco", label: "Leaf", kind: "material", glyph: "eco" },
  { id: "pets", label: "Paw", kind: "material", glyph: "pets" },
  { id: "cruelty_free", label: "Bunny", kind: "material", glyph: "cruelty_free" },
  { id: "local_fire_department", label: "Flame", kind: "material", glyph: "local_fire_department" }
]

function byId(id) {
  for (var i = 0; i < options.length; i++) if (options[i].id === id) return options[i]
  return options[0]
}
