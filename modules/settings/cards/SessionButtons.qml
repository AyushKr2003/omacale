import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../session/SessionItems.js" as Items

// Settings › Session › Buttons: the session drawer's items top to bottom,
// each with a switch that leaves it out and arrows that move it (issue #28).
// The animation's switch is session.gif. Lock and Screensaver also follow
// session.extraButtons, the single switch they had before; turning one back
// on turns that on and leaves the other as it was shown.
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  readonly property var cfg: Config.o.session
  readonly property var order: Items.order(cfg.order)
  readonly property var info: ({
    logout: { label: "Logout", icon: root.cfg.icons.logout || "logout" },
    shutdown: { label: "Shutdown", icon: root.cfg.icons.shutdown || "power_settings_new" },
    gif: { label: "Animation", icon: "animated_images", subtext: "The spinning character, or your own picture" },
    hibernate: { label: "Sleep", icon: root.cfg.icons.hibernate || (root.cfg.sleepAction === "suspend" ? "bedtime" : "downloading"), subtext: "Folds away when Omarchy says neither sleep is available" },
    reboot: { label: "Reboot", icon: root.cfg.icons.reboot || "cached" },
    lock: { label: "Lock", icon: root.cfg.icons.lock || "lock" },
    screensaver: { label: "Screensaver", icon: root.cfg.icons.screensaver || "slideshow" }
  })

  function setShown(id, on) {
    if (id === "gif") { Config.set("session.gif", on); return }
    let hidden = Array.from(cfg.hidden).filter(i => i !== id)
    if (on && Items.EXTRA.indexOf(id) >= 0 && !cfg.extraButtons) {
      // The old switch hid both: bring back only this one.
      Items.EXTRA.forEach(e => { if (e !== id && hidden.indexOf(e) < 0) hidden.push(e) })
      Config.set("session.extraButtons", true)
    }
    if (!on) hidden.push(id)
    Config.set("session.hidden", hidden)
  }
  function move(id, by) { Config.set("session.order", Items.moved(cfg.order, id, by)) }

  spacing: Tk.spacing.extraSmall / 2

  Repeater {
    id: rep
    model: root.order

    ConnectedRect {
      id: item
      required property string modelData
      required property int index
      readonly property var meta: root.info[modelData]
      readonly property bool on: Items.shown(modelData, root.cfg)
      Layout.fillWidth: true
      first: index === 0
      last: index === rep.count - 1
      implicitHeight: rl.implicitHeight + Tk.padding.medium * 2

      StateLayer { onClicked: root.setShown(item.modelData, !item.on) }
      RowLayout {
        id: rl
        anchors.fill: parent
        anchors.margins: Tk.padding.medium
        anchors.leftMargin: Tk.padding.largeIncreased
        anchors.rightMargin: Tk.padding.largeIncreased
        spacing: Tk.spacing.medium
        MIcon {
          text: item.meta.icon
          size: Tk.iconSize.medium
          fill: 1
          color: item.on ? Colours.m3onSurface : Colours.m3outline
        }
        RowLabel {
          Layout.fillWidth: true
          text: item.meta.label
          subtext: item.meta.subtext || ""
        }
        IconButton {
          type: "text"
          icon: "arrow_upward"
          iconSize: Tk.iconSize.small
          disabled: item.index === 0
          onClicked: root.move(item.modelData, -1)
        }
        IconButton {
          type: "text"
          icon: "arrow_downward"
          iconSize: Tk.iconSize.small
          disabled: item.index === rep.count - 1
          onClicked: root.move(item.modelData, 1)
        }
        MSwitch {
          checked: item.on
          onToggled: c => root.setShown(item.modelData, c)
        }
      }
    }
  }

  IconTextButton {
    Layout.alignment: Qt.AlignRight
    Layout.topMargin: Tk.spacing.small
    visible: Array.from(root.cfg.order).join() !== Items.IDS.join() || root.cfg.hidden.length > 0 || !root.cfg.gif || !root.cfg.extraButtons
    type: "text"
    icon: "restart_alt"
    text: "Reset"
    onClicked: {
      Config.set("session.order", Items.IDS)
      Config.set("session.hidden", [])
      Config.set("session.gif", true)
      Config.set("session.extraButtons", true)
    }
  }
}
