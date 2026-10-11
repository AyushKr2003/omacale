.pragma library

// Omarchy's light/dark rule for a theme (bin/omarchy-theme-color,
// resolve_theme_mode), so Omacale agrees with GTK, the templates and the
// shell: the `mode` key, the legacy `theme_type` key, a light.mode file
// beside colors.toml, the background's brightness (r + g + b > 382), dark.
// Plain JS, so tests/test-theme-mode.js runs it under node.

// colors.toml as flat key -> value (the subset Omarchy themes use).
function parse(text) {
  var out = {}
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var l = lines[i].replace(/\s+#.*$/, "").trim()
    if (!l || l.charAt(0) === "#" || l.charAt(0) === "[") continue
    var eq = l.indexOf("=")
    if (eq < 0) continue
    var key = l.slice(0, eq).replace(/["'\s]/g, "")
    var value = l.slice(eq + 1).trim().replace(/^["']|["']$/g, "")
    if (key) out[key] = value
  }
  return out
}

function resolveMode(text, hasLightFile) {
  var c = parse(text)
  var mode = c.mode || c.theme_type
  if (mode) return mode === "light" ? "light" : "dark"
  if (hasLightFile) return "light"
  var m = /^#([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})$/.exec(c.background || "")
  if (m && parseInt(m[1], 16) + parseInt(m[2], 16) + parseInt(m[3], 16) > 382) return "light"
  return "dark"
}
