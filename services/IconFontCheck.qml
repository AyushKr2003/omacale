import QtQuick
import Quickshell
import Quickshell.Io

// Every icon in Omacale is a Material Symbols Rounded glyph (Tk.icon). Without
// that family Qt draws the ligature names ("coffee", "terminal") as text. The
// installer adds the font package, but a marketplace install (`omarchy plugin
// add`) never runs the installer, and a failed `omarchy pkg add` there was only
// a warning (issue #38). The older "Material Icons" family is a different font
// and does not help. So the shell checks once at startup and says what to do:
// install the package, or restart if it was installed after the shell started
// (a running Qt process doesn't see fonts added later). A notification, not a
// toast: a toast's icon is a Material Symbols glyph too.
QtObject {
  id: root

  readonly property string family: "Material Symbols Rounded"
  readonly property string pkg: "ttf-material-symbols-variable"

  property Timer startup: Timer {
    running: true
    interval: 4000
    onTriggered: if (Qt.fontFamilies().indexOf(root.family) < 0) root.onDisk.running = true
  }

  // fontconfig, not pacman: the AUR -git build provides the same family.
  property Process onDisk: Process {
    command: ["fc-list", "-q", root.family]
    onExited: code => {
      const installed = code === 0
      root.notify.command = ["notify-send", "-a", "Omacale", "-u", "critical", "--wait",
        "-A", installed ? "restart=Restart the shell" : "install=Install the icon font",
        "Omacale's icon font is missing",
        installed
          ? root.family + " was installed after the shell started. Restart the shell to load it."
          : "Icons show as words until " + root.pkg + " is installed (\"Material Icons\" is a different font)."]
      root.notify.running = true
    }
  }

  property Process notify: Process {
    stdout: StdioCollector {
      onStreamFinished: {
        const action = text.trim()
        if (action === "install")
          Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation",
            "omarchy pkg add " + root.pkg + " && omarchy-restart-shell"])
        else if (action === "restart")
          Quickshell.execDetached(["omarchy-restart-shell"])
      }
    }
  }
}
