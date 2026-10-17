import QtQuick
import Quickshell.Io
import "../.."
import "SessionItems.js" as Items

// Caelestia session menu (modules/session/Content.qml): four big buttons
// around the kurukuru gif, with Caelestia's session.icons / session.commands.
// Empty settings mean Omarchy's own commands, as in its System menu
// (default/omarchy/omarchy-menu.jsonc "system.*"), so the drawer can stand in
// for that menu. Below them, Omarchy's Lock and Screensaver (no Caelestia
// original). Settings › Session › Buttons picks which items show, their
// order, and whether Lock and Screensaver are a compact pair (issue #28).
Column {
  id: root

  property bool active: false
  // On the left of the screen, with a right-hand bar: the frame's border is
  // then on its left.
  property bool mirror: false
  signal dismissed()
  readonly property var cfg: Config.o.session

  function cmd(key, fallback) { return root.cfg.commands[key] || fallback }
  function icon(key, fallback) { return root.cfg.icons[key] || fallback }

  // Omarchy's guards on its Suspend and Hibernate entries ("when"), asked
  // each time the drawer opens. Until they answer, both count as available,
  // which is what the button did before it asked.
  property bool canSuspend: true
  property bool canHibernate: true
  Process {
    id: sleepProbe
    command: ["bash", "-c", "omarchy-hibernation-available >/dev/null 2>&1 && echo h; omarchy-toggle-enabled suspend-off >/dev/null 2>&1 || echo s"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.canHibernate = text.indexOf("h") >= 0
        root.canSuspend = text.indexOf("s") >= 0
      }
    }
  }
  // The third button: the chosen sleep, else the other one, else none at all.
  // A command of the user's own is run as it is.
  readonly property string sleepKind: {
    if (cfg.commands.hibernate) return "custom"
    const wantHibernate = cfg.sleepAction !== "suspend"
    if (wantHibernate && canHibernate) return "hibernate"
    if (canSuspend) return "suspend"
    if (canHibernate) return "hibernate"
    return ""
  }

  padding: Tk.padding.large
  leftPadding: mirror ? Math.max(0, padding - Tk.border) : padding
  rightPadding: mirror ? padding : Math.max(0, padding - Tk.border)
  spacing: Tk.spacing.large

  // Deferred: built on demand, it is still being created (not yet in the
  // window) when `active` first turns true.
  onActiveChanged: if (active) { sleepProbe.running = true; Qt.callLater(() => { const b = root.flat()[0]; if (b) b.forceActiveFocus() }) }

  // Settings › Session › Buttons: which items, in what order, and whether
  // Lock and Screensaver are the compact pair or full-size buttons.
  readonly property var rows: Items.rows(cfg)

  // The buttons by id, for the keys (registered by each button).
  property var buttons: ({})
  function btn(id) { const b = buttons[id]; return b && b.shown ? b : null }
  // The buttons that take focus, row by row.
  function grid() { return rows.map(r => r.map(btn).filter(b => b)).filter(r => r.length) }
  function flat() { return [].concat.apply([], grid()) }
  // Up and down go to the row above or below (the same column, or the
  // nearest one), else to the previous or next button; left and right stay
  // in the row.
  function step(b, key) {
    const g = grid()
    const r = g.findIndex(row => row.indexOf(b) >= 0)
    if (r < 0) return null
    const c = g[r].indexOf(b)
    if (key === "left") return g[r][c - 1] || null
    if (key === "right") return g[r][c + 1] || null
    const f = flat(), i = f.indexOf(b)
    if (key === "next") return f[i + 1] || null
    if (key === "prev") return f[i - 1] || null
    const to = g[r + (key === "down" ? 1 : -1)]
    if (to) return to[Math.min(c, to.length - 1)]
    return key === "down" && c < g[r].length - 1 ? g[r][g[r].length - 1] : null
  }
  function go(b, key) { const t = step(b, key); if (t) t.forceActiveFocus(); return !!t }

  Repeater {
    model: root.rows
    // One row, as wide as a button so a lone small one sits in the middle.
    Item {
      required property var modelData
      width: Tk.sizes.sessionButton
      height: line.height
      Row {
        id: line
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Tk.spacing.large
        Repeater {
          model: modelData
          Loader {
            required property string modelData
            readonly property string itemId: modelData
            sourceComponent: modelData === "gif" ? gifItem : button
          }
        }
      }
    }
  }

  Component {
    id: gifItem
    AnimatedImage {
      width: Tk.sizes.sessionButton
      height: Tk.sizes.sessionButton
      // Caelestia paths.sessionGif: a picture of the user's own, else the bundled one.
      source: root.cfg.gifPath ? "file://" + root.cfg.gifPath : Qt.resolvedUrl("../../assets/kurukuru.gif")
      playing: root.active
      speed: root.cfg.gifSpeed > 0 ? root.cfg.gifSpeed : 0.7
      fillMode: AnimatedImage.PreserveAspectFit
    }
  }

  Component {
    id: button
    SessionButton {
      id: sb
      readonly property string itemId: parent ? parent.itemId : ""
      // The sleep button is folded away, not hidden, when neither sleep is
      // available (Column skips a zero-size row).
      shown: itemId !== "hibernate" || root.sleepKind !== ""
      small: Items.small(itemId, root.cfg)
      icon: itemId === "logout" ? root.icon("logout", "logout")
        : itemId === "shutdown" ? root.icon("shutdown", "power_settings_new")
        : itemId === "hibernate" ? root.icon("hibernate", root.sleepKind === "suspend" ? "bedtime" : "downloading")
        : itemId === "reboot" ? root.icon("reboot", "cached")
        : itemId === "lock" ? root.icon("lock", "lock")
        : root.icon("screensaver", "slideshow")
      command: itemId === "logout" ? root.cmd("logout", "omarchy system logout")
        : itemId === "shutdown" ? root.cmd("shutdown", "omarchy system shutdown")
        : itemId === "hibernate" ? (root.sleepKind === "custom" ? root.cfg.commands.hibernate
          : root.sleepKind === "suspend" ? "systemctl suspend" : "systemctl hibernate")
        : itemId === "reboot" ? root.cmd("reboot", "omarchy system reboot")
        : itemId === "lock" ? root.cmd("lock", "omarchy-system-lock")
        : root.cmd("screensaver", "omarchy-launch-screensaver force")
      Component.onCompleted: root.buttons[itemId] = sb
      Component.onDestruction: if (root.buttons[itemId] === sb) delete root.buttons[itemId]
    }
  }

  component SessionButton: Rectangle {
    id: b
    property string icon
    property string command
    property bool shown: true
    // Half-size, two to a row: Lock and Screensaver in the compact style.
    property bool small: false
    function exec() { Sys.run(command); root.dismissed() }

    width: small ? (Tk.sizes.sessionButton - Tk.spacing.large) / 2 : Tk.sizes.sessionButton
    height: shown ? width : 0
    opacity: shown ? 1 : 0
    enabled: shown
    radius: state.pressed ? Tk.rounding.medium : activeFocus ? Tk.rounding.extraLarge : Tk.rounding.largeIncreased
    color: activeFocus ? Colours.m3secondaryContainer : Colours.m3surfaceContainer
    Behavior on radius { Anim { type: "effects" } }
    Behavior on color { CAnim {} }

    Keys.onReturnPressed: exec()
    Keys.onEnterPressed: exec()
    Keys.onEscapePressed: root.dismissed()
    Keys.onTabPressed: root.go(b, "next")
    Keys.onBacktabPressed: root.go(b, "prev")
    Keys.onUpPressed: root.go(b, "up")
    Keys.onDownPressed: root.go(b, "down")
    Keys.onLeftPressed: root.go(b, "left")
    Keys.onRightPressed: root.go(b, "right")
    Keys.onPressed: e => {
      if (!root.cfg.vimKeybinds || !(e.modifiers & Qt.ControlModifier)) return
      if (e.key === Qt.Key_J || e.key === Qt.Key_N) { root.go(b, "down"); e.accepted = true }
      else if (e.key === Qt.Key_K || e.key === Qt.Key_P) { root.go(b, "up"); e.accepted = true }
    }

    StateLayer {
      id: state
      color: b.activeFocus ? Colours.m3onSecondaryContainer : Colours.m3onSurface
      onClicked: b.exec()
    }
    MIcon {
      anchors.centerIn: parent
      anchors.verticalCenterOffset: 1
      text: b.icon
      size: b.small ? Tk.iconSize.large : Tk.iconSize.large * 1.3
      fill: 1
      color: b.activeFocus ? Colours.m3onSecondaryContainer : Colours.m3onSurface
    }
  }
}
