import QtQuick

// Caelestia session menu: four big buttons around the kurukuru gif.
Column {
  id: root

  property bool active: false
  signal dismissed()
  readonly property var cfg: Config.o.session

  padding: Tk.padding.large
  rightPadding: Math.max(0, padding - Tk.border)
  spacing: Tk.spacing.large

  onActiveChanged: if (active) logout.forceActiveFocus()

  SessionButton { id: logout; icon: "logout"; command: "omarchy system logout"; KeyNavigation.down: shutdown }
  SessionButton { id: shutdown; icon: "power_settings_new"; command: "omarchy system shutdown"; KeyNavigation.up: logout; KeyNavigation.down: hibernate }
  AnimatedImage {
    visible: root.cfg.gif
    width: Tk.sizes.sessionButton
    height: Tk.sizes.sessionButton
    source: Qt.resolvedUrl("assets/kurukuru.gif")
    playing: root.active
    speed: 0.7
    fillMode: AnimatedImage.PreserveAspectFit
  }
  SessionButton {
    id: hibernate
    icon: root.cfg.sleepAction === "suspend" ? "bedtime" : "downloading"
    command: root.cfg.sleepAction === "suspend" ? "systemctl suspend" : "systemctl hibernate || systemctl suspend"
    KeyNavigation.up: shutdown; KeyNavigation.down: reboot
  }
  SessionButton { id: reboot; icon: "cached"; command: "omarchy system reboot"; KeyNavigation.up: hibernate }

  component SessionButton: Rectangle {
    id: b
    property string icon
    property string command
    function exec() { Sys.run(command); root.dismissed() }

    width: Tk.sizes.sessionButton
    height: Tk.sizes.sessionButton
    radius: state.pressed ? Tk.rounding.medium : activeFocus ? Tk.rounding.extraLarge : Tk.rounding.largeIncreased
    color: activeFocus ? Colours.m3secondaryContainer : Colours.m3surfaceContainer
    Behavior on radius { Anim { type: "fastSpatial" } }
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
      size: Tk.iconSize.large * 1.3
      fill: 1
      color: b.activeFocus ? Colours.m3onSecondaryContainer : Colours.m3onSurface
    }
  }
}
