import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import "../../.."

// Settings › Taskbar › Tray: every tray item currently running, with a switch
// that keeps it out of the bar (Caelestia's bar.tray.hiddenIcons).
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  readonly property var items: SystemTray.items.values.filter(i => i.status !== Status.Passive)
  readonly property var hidden: Config.o.bar.tray.hiddenIcons
  // An id that is hidden but whose app isn't running now: still listed, so a
  // tray icon hidden by mistake can be brought back without relaunching it.
  readonly property var offline: hidden.filter(id => !items.some(i => i.id === id))

  function setHidden(id, on) {
    const l = Array.from(hidden).filter(i => i !== id)
    Config.set("bar.tray.hiddenIcons", on ? l.concat([id]) : l)
  }

  spacing: Tk.spacing.extraSmall / 2

  MText {
    Layout.fillWidth: true
    Layout.bottomMargin: Tk.spacing.small
    visible: root.items.length === 0 && root.offline.length === 0
    text: "Nothing is in the tray right now."
    color: Colours.m3outline
    wrapMode: Text.WordWrap
  }

  Repeater {
    id: rep
    model: root.items

    ConnectedRect {
      id: trayRow
      required property var modelData
      required property int index
      readonly property bool isHidden: root.hidden.indexOf(modelData.id) >= 0
      Layout.fillWidth: true
      first: index === 0
      last: index === rep.count - 1 && root.offline.length === 0
      implicitHeight: tr.implicitHeight + Tk.padding.medium * 2

      StateLayer { onClicked: root.setHidden(trayRow.modelData.id, !trayRow.isHidden) }
      RowLayout {
        id: tr
        anchors.fill: parent
        anchors.margins: Tk.padding.medium
        anchors.leftMargin: Tk.padding.largeIncreased
        anchors.rightMargin: Tk.padding.largeIncreased
        spacing: Tk.spacing.medium
        Image {
          Layout.preferredWidth: Tk.iconSize.medium
          Layout.preferredHeight: Tk.iconSize.medium
          opacity: trayRow.isHidden ? 0.4 : 1
          source: {
            let icon = trayRow.modelData.icon
            if (icon.indexOf("?path=") >= 0) {
              const [name, path] = icon.split("?path=")
              icon = "file://" + path + "/" + name.slice(name.lastIndexOf("/") + 1)
            }
            return icon
          }
          sourceSize.width: width * 2
          sourceSize.height: height * 2
          smooth: true
          mipmap: true
        }
        RowLabel {
          Layout.fillWidth: true
          text: trayRow.modelData.tooltipTitle || trayRow.modelData.title || trayRow.modelData.id
          subtext: trayRow.modelData.id
        }
        MSwitch {
          checked: !trayRow.isHidden
          onToggled: c => root.setHidden(trayRow.modelData.id, !c)
        }
      }
    }
  }

  // Hidden ids whose app isn't running: shown so they can be brought back.
  Repeater {
    id: offRep
    model: root.offline

    ConnectedRect {
      required property string modelData
      required property int index
      Layout.fillWidth: true
      first: index === 0 && rep.count === 0
      last: index === offRep.count - 1
      implicitHeight: or.implicitHeight + Tk.padding.medium * 2

      StateLayer { onClicked: root.setHidden(modelData, false) }
      RowLayout {
        id: or
        anchors.fill: parent
        anchors.margins: Tk.padding.medium
        anchors.leftMargin: Tk.padding.largeIncreased
        anchors.rightMargin: Tk.padding.largeIncreased
        spacing: Tk.spacing.medium
        MIcon { text: "visibility_off"; size: Tk.iconSize.medium; color: Colours.m3outline }
        RowLabel { Layout.fillWidth: true; text: modelData; subtext: "Hidden · not running" }
        MSwitch { checked: false; onToggled: root.setHidden(modelData, false) }
      }
    }
  }
}
