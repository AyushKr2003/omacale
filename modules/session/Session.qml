import QtQuick
import Quickshell.Io
import "../.."

// Caelestia session menu (modules/session/Content.qml): four big buttons
// around the kurukuru gif, with Caelestia's session.icons / session.commands.
// Empty settings mean Omarchy's own commands, as in its System menu
// (default/omarchy/omarchy-menu.jsonc "system.*"), so the drawer can stand in
// for that menu. Below them, Omarchy's Lock and Screensaver (no Caelestia
// original; Settings › Session › Lock & screensaver).
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
  onActiveChanged: if (active) { sleepProbe.running = true; Qt.callLater(() => logout.forceActiveFocus()) }

  SessionButton {
    id: logout
    icon: root.icon("logout", "logout")
    command: root.cmd("logout", "omarchy system logout")
    KeyNavigation.down: shutdown
  }
  SessionButton {
    id: shutdown
    icon: root.icon("shutdown", "power_settings_new")
    command: root.cmd("shutdown", "omarchy system shutdown")
    KeyNavigation.up: logout
    KeyNavigation.down: hibernate.shown ? hibernate : reboot
  }
  AnimatedImage {
    visible: root.cfg.gif
    width: Tk.sizes.sessionButton
    height: Tk.sizes.sessionButton
    // Caelestia paths.sessionGif: a picture of the user's own, else the bundled one.
    source: root.cfg.gifPath ? "file://" + root.cfg.gifPath : Qt.resolvedUrl("../../assets/kurukuru.gif")
    playing: root.active
    speed: root.cfg.gifSpeed > 0 ? root.cfg.gifSpeed : 0.7
    fillMode: AnimatedImage.PreserveAspectFit
  }
  SessionButton {
    id: hibernate
    // Folded away, not hidden, when neither sleep is available (Column skips
    // a zero-size item).
    readonly property bool shown: root.sleepKind !== ""
    height: shown ? Tk.sizes.sessionButton : 0
    opacity: shown ? 1 : 0
    enabled: shown
    icon: root.icon("hibernate", root.sleepKind === "suspend" ? "bedtime" : "downloading")
    command: root.sleepKind === "custom" ? root.cfg.commands.hibernate
      : root.sleepKind === "suspend" ? "systemctl suspend" : "systemctl hibernate"
    KeyNavigation.up: shutdown
    KeyNavigation.down: reboot
  }
  SessionButton {
    id: reboot
    icon: root.icon("reboot", "cached")
    command: root.cmd("reboot", "omarchy system reboot")
    KeyNavigation.up: hibernate.shown ? hibernate : shutdown
    KeyNavigation.down: root.cfg.extraButtons ? lock : null
  }

  // Omarchy's Lock and Screensaver, half-height side by side, so the drawer
  // offers everything Omarchy's System menu does.
  Row {
    visible: root.cfg.extraButtons
    spacing: Tk.spacing.large
    SessionButton {
      id: lock
      width: (Tk.sizes.sessionButton - Tk.spacing.large) / 2
      height: width
      iconSize: Tk.iconSize.large
      icon: "lock"
      command: root.cmd("lock", "omarchy-system-lock")
      KeyNavigation.up: reboot
      KeyNavigation.right: screensaver
      KeyNavigation.down: screensaver
    }
    SessionButton {
      id: screensaver
      width: lock.width
      height: width
      iconSize: Tk.iconSize.large
      icon: "slideshow"
      command: root.cmd("screensaver", "omarchy-launch-screensaver force")
      KeyNavigation.up: lock
      KeyNavigation.left: lock
    }
  }

  component SessionButton: Rectangle {
    id: b
    property string icon
    property string command
    property real iconSize: Tk.iconSize.large * 1.3
    function exec() { Sys.run(command); root.dismissed() }

    width: Tk.sizes.sessionButton
    height: Tk.sizes.sessionButton
    radius: state.pressed ? Tk.rounding.medium : activeFocus ? Tk.rounding.extraLarge : Tk.rounding.largeIncreased
    color: activeFocus ? Colours.m3secondaryContainer : Colours.m3surfaceContainer
    Behavior on radius { Anim { type: "effects" } }
    Behavior on color { CAnim {} }

    Keys.onReturnPressed: exec()
    Keys.onEnterPressed: exec()
    Keys.onEscapePressed: root.dismissed()
    Keys.onTabPressed: if (KeyNavigation.down) KeyNavigation.down.forceActiveFocus()
    Keys.onBacktabPressed: if (KeyNavigation.up) KeyNavigation.up.forceActiveFocus()
    Keys.onPressed: e => {
      if (!root.cfg.vimKeybinds || !(e.modifiers & Qt.ControlModifier)) return
      if ((e.key === Qt.Key_J || e.key === Qt.Key_N) && KeyNavigation.down) { KeyNavigation.down.forceActiveFocus(); e.accepted = true }
      else if ((e.key === Qt.Key_K || e.key === Qt.Key_P) && KeyNavigation.up) { KeyNavigation.up.forceActiveFocus(); e.accepted = true }
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
      size: b.iconSize
      fill: 1
      color: b.activeFocus ? Colours.m3onSecondaryContainer : Colours.m3onSurface
    }
  }
}
