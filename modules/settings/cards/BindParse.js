.pragma library

// One keybinds.lua line -> { optional, rebind, keys, desc, cmd, opts, note,
// line }, or null. `line` is the call itself (comment marker and trailing
// note removed, options kept), ready to copy or to `hyprctl eval`. Also reads
// Omarchy's own default/hypr/bindings/*.lua lines (stockLine). Plain JS, so
// tests/test-binds.js runs it under node.
var RE = /^\s*(--\s*)?o\.(re)?bind\("([^"]+)",\s*"([^"]+)",\s*"([^"]+)"(?:,\s*(\{[^}]*\}))?\)\s*(--\s*(.*))?$/

function parseBind(l) {
  var m = String(l).match(RE)
  if (!m) return null
  return {
    optional: !!m[1], rebind: !!m[2], keys: m[3], desc: m[4], cmd: m[5], opts: m[6] || "", note: m[8] || "",
    line: String(l).replace(/^\s*--\s*/, "").replace(/\)\s+--.*$/, ")").trim()
  }
}

// The bind for `keys` in a file of Omarchy's binds, as written there; "" if none.
function stockLine(text, keys) {
  var lines = String(text).split("\n")
  for (var i = 0; i < lines.length; i++) {
    var b = parseBind(lines[i])
    if (b && !b.optional && b.keys === keys) return b.line
  }
  return ""
}
