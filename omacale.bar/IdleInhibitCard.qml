import QtQuick
import QtQuick.Layouts

// Keep awake card (Caelestia utilities/cards/IdleInhibit.qml).
Rectangle {
  id: root

  readonly property real nonAnimHeight: layout.implicitHeight + (IdleService.enabled ? chip.implicitHeight + chip.anchors.topMargin : 0) + Tk.padding.extraLargeIncreased

  implicitHeight: nonAnimHeight
  radius: Tk.rounding.large
  color: Colours.m3surfaceContainer
  clip: true

  RowLayout {
    id: layout
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: Tk.padding.large
    spacing: Tk.spacing.medium

    Rectangle {
      implicitWidth: implicitHeight
      implicitHeight: icon.implicitHeight + Tk.padding.large
      radius: Tk.rounding.full
      color: IdleService.enabled ? Colours.m3secondary : Colours.m3secondaryContainer
      Behavior on color { CAnim {} }

      MIcon {
        id: icon
        anchors.centerIn: parent
        text: "coffee"
        size: Tk.iconSize.large
        color: IdleService.enabled ? Colours.m3onSecondary : Colours.m3onSecondaryContainer
        Behavior on color { CAnim {} }
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0

      MText {
        Layout.fillWidth: true
        text: "Keep awake"
        font.pointSize: Tk.body.medium
        elide: Text.ElideRight
      }
      MText {
        Layout.fillWidth: true
        text: IdleService.enabled ? "Preventing sleep mode" : "Normal power management"
        color: Colours.m3onSurfaceVariant
        font.pointSize: Tk.body.small
        elide: Text.ElideRight
      }
    }

    MSwitch {
      checked: IdleService.enabled
      onToggled: IdleService.toggle()
    }
  }

  Loader {
    id: chip
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.topMargin: Tk.spacing.large
    anchors.bottomMargin: IdleService.enabled ? Tk.padding.large : -implicitHeight
    anchors.leftMargin: Tk.padding.large

    opacity: IdleService.enabled ? 1 : 0
    scale: IdleService.enabled ? 1 : 0.5
    active: opacity > 0

    sourceComponent: Rectangle {
      implicitWidth: activeText.implicitWidth + Tk.padding.medium * 2
      implicitHeight: activeText.implicitHeight + Tk.padding.small
      radius: Tk.rounding.full
      color: Colours.m3primary

      MText {
        id: activeText
        anchors.centerIn: parent
        text: "Active since " + (IdleService.enabledSince ? Qt.formatTime(IdleService.enabledSince, Config.o.general.clock24 ? "hh:mm" : "hh:mm a") : "just now")
        color: Colours.m3onPrimary
        font.pointSize: Math.round(Tk.body.small * 0.9)
      }
    }

    Behavior on anchors.bottomMargin { Anim {} }
    Behavior on opacity { Anim { type: "standardSmall" } }
    Behavior on scale { Anim {} }
  }

  Behavior on implicitHeight { Anim {} }
}
