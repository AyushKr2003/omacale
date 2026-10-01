import QtQuick
import QtQuick.Layouts
import "../../.."

// Settings › Panels › OSD: who draws the volume and brightness OSD, and the
// handover that changes it (OsdHandover, scripts/osd-handover). Drawn like
// NotifCard.
ColumnLayout {
  id: root

  property var settings
  property var row
  property bool first
  property bool last

  spacing: Tk.spacing.extraSmall / 2

  readonly property bool drawing: OsdHandover.installed && Config.o.osd.enabled

  Component.onCompleted: OsdHandover.refresh()

  // The clone is rebuilt from Omarchy's daemon whenever an `omarchy update`
  // changes it (services/Handover.qml); this says what happened.
  readonly property string notice: {
    if (OsdHandover.fellBack && !OsdHandover.installed)
      return "After an Omarchy update the OSD in the handover stopped working"
        + (OsdHandover.lastReason ? " (" + OsdHandover.lastReason + ")" : "")
        + ", so Omarchy's own OSD was put back. Install the handover again once Omacale is updated."
    if (OsdHandover.refused)
      return "Omarchy's OSD has changed shape and Omacale's patch no longer applies, so the handover keeps running the previous one. Update Omacale."
    if (OsdHandover.lastAction === "synced")
      return "Omarchy's OSD was updated, and the handover now carries the new one."
    if (OsdHandover.unverified)
      return "Omarchy's OSD differs from the one this Omacale was tested with. The patch still applies; report anything odd with the volume or brightness keys."
    return ""
  }

  ConnectedRect {
    Layout.fillWidth: true
    first: true
    last: !root.notice && !OsdHandover.error
    implicitHeight: intro.implicitHeight + Tk.padding.largeIncreased * 2

    ColumnLayout {
      id: intro

      anchors.fill: parent
      anchors.margins: Tk.padding.largeIncreased
      spacing: Tk.spacing.large

      RowLayout {
        spacing: Tk.spacing.large

        MShape {
          implicitSize: Tk.px(56)
          shape: root.drawing ? "cookie9" : "circle"
          color: root.drawing ? Colours.m3primaryContainer : Colours.m3surfaceContainerHighest

          MIcon {
            anchors.centerIn: parent
            text: root.drawing ? "volume_up" : "volume_off"
            size: Tk.iconSize.large
            fill: 1
            color: root.drawing ? Colours.m3onPrimaryContainer : Colours.m3onSurfaceVariant
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          RowLayout {
            spacing: Tk.spacing.medium

            MText {
              text: "Volume and brightness"
              font.pointSize: Tk.title.small
              weight: Font.Medium
            }

            LockCard.StatusChip {
              active: root.drawing
              text: {
                if (OsdHandover.busy)
                  return "Working…"
                if (!OsdHandover.ready)
                  return "Checking…"
                if (OsdHandover.fellBack && !OsdHandover.installed)
                  return "Handed back to Omarchy"
                if (root.drawing)
                  return "Drawn by Omacale"
                if (OsdHandover.installed)
                  return "Off in Omacale"
                return "Drawn by Omarchy"
              }
            }
          }

          MText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Colours.m3onSurfaceVariant
            text: "Omarchy's OSD keeps drawing media, keyboard backlight and the other messages. The handover clones it so that the volume and display brightness keys open Caelestia's sliders instead; removing it gives Omarchy's own bars back. Without it the sliders still open when you hover the middle of the screen's edge."
          }
        }
      }

      Flow {
        Layout.fillWidth: true
        spacing: Tk.spacing.small

        Pill {
          icon: "download"
          label: OsdHandover.fellBack ? "Install again" : "Install handover"
          filled: true
          visible: OsdHandover.ready && !OsdHandover.installed
          onClicked: OsdHandover.install()
        }
        Pill {
          icon: "restart_alt"
          label: "Resync"
          visible: OsdHandover.installed && OsdHandover.stale && !OsdHandover.refused
          onClicked: OsdHandover.install()
        }
        Pill {
          icon: "undo"
          label: "Remove handover"
          visible: OsdHandover.ready && OsdHandover.clone !== ""
          onClicked: OsdHandover.remove()
        }
      }
    }
  }

  ConnectedRect {
    Layout.fillWidth: true
    last: !OsdHandover.error
    visible: root.notice !== ""
    implicitHeight: noticeText.implicitHeight + Tk.padding.medium * 2

    MText {
      id: noticeText

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased
      anchors.rightMargin: Tk.padding.largeIncreased

      wrapMode: Text.WordWrap
      color: Colours.m3onSurfaceVariant
      font.pointSize: Tk.label.small
      text: root.notice
    }
  }

  ConnectedRect {
    Layout.fillWidth: true
    last: true
    visible: OsdHandover.error !== ""
    color: Colours.m3errorContainer
    implicitHeight: errorText.implicitHeight + Tk.padding.medium * 2

    MText {
      id: errorText

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased
      anchors.rightMargin: Tk.padding.largeIncreased

      wrapMode: Text.WordWrap
      color: Colours.m3onErrorContainer
      font.pointSize: Tk.label.small
      text: OsdHandover.error
    }
  }
}
