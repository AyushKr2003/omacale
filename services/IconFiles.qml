pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// App icons by file, for when Qt's icon theme lookup finds nothing at all.
//
// Qt resolves `image://icon/<name>` through the icon theme the GTK settings
// name (QT_QPA_PLATFORMTHEME=gtk3). If that theme isn't installed, Qt does
// not fall back to hicolor: every app icon comes up empty. Omarchy's
// vantablack theme names "Yaru-gray", which yaru-icon-theme no longer ships,
// so the launcher, Settings › Apps and the dock lost their icons. Omarchy has
// no icon lookup of its own to use instead, so this indexes the fallback
// locations once (hicolor and pixmaps, system and user) and hands out a file
// URL for a name the theme can't resolve.
QtObject {
  id: root

  // name -> path of its best file: scalable over the biggest size.
  property var files: ({})
  // Bumped when the index lands, so bindings that went through source()
  // before it did run again.
  property int revision: 0

  function rank(path) {
    if (path.indexOf("/scalable/") >= 0) return 100000
    const m = path.match(/\/(\d+)x\d+(@\d)?\//)
    return m ? Number(m[1]) : 1
  }

  property Process scan: Process {
    running: true
    command: ["bash", "-c", "find -L /usr/share/icons/hicolor \"$HOME/.local/share/icons\" /usr/share/pixmaps -maxdepth 4 -type f \\( -name '*.png' -o -name '*.svg' -o -name '*.xpm' \\) 2>/dev/null"]
    stdout: StdioCollector {
      onStreamFinished: {
        const best = {}, score = {}
        for (const p of String(text).split("\n")) {
          if (!p) continue
          const name = p.split("/").pop().replace(/\.(png|svg|xpm)$/, "")
          const r = root.rank(p)
          if (score[name] === undefined || r > score[name]) { best[name] = p; score[name] = r }
        }
        root.files = best
        root.revision++
      }
    }
  }

  // Whether an icon of this name can be drawn, by the theme or by file.
  function exists(name) {
    void(revision)
    const n = String(name || "").trim()
    return n !== "" && (Quickshell.iconPath(n, true) !== "" || !!files[n])
  }

  // An image source for an icon name (or path): the theme's, else its file,
  // else the fallback's (theme or file), else "".
  function source(name, fallback) {
    void(revision)
    const n = String(name || "").trim()
    if (n.startsWith("/")) return "file://" + n
    if (n.startsWith("file://") || n.startsWith("image://") || n.startsWith("qrc:/")) return n
    for (const c of [n, String(fallback || "")]) {
      if (!c) continue
      const p = Quickshell.iconPath(c, true)
      if (p !== "") return p
      if (files[c]) return "file://" + files[c]
    }
    return ""
  }
}
