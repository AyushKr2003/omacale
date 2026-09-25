import QtQuick
import QtQuick.Layouts
import "../../.."

// Settings › Notifications: who draws the toasts, and the handover that
// changes it (NotifHandover, scripts/notif-popups). Drawn like LockCard.
ColumnLayout {
  id: root

  property var settings
  property var row
  property bool first
  property bool last

  spacing: Tk.spacing.extraSmall / 2

  readonly property bool drawing: NotifService.popupsSupported

  Component.onCompleted: NotifHandover.refresh()

  // The clone is rebuilt from Omarchy's daemon whenever an `omarchy update`
  // changes it (services/Handover.qml); this says what happened.
  readonly property string notice: {
    if (NotifHandover.fellBack && !NotifHandover.installed)
      return "After an Omarchy update the notification daemon in the handover stopped working"
        + (NotifHandover.lastReason ? " (" + NotifHandover.lastReason + ")" : "")
        + ", so Omarchy's own daemon and toasts were put back. Install the handover again once Omacale is updated."
    if (NotifHandover.refused)
      return "Omarchy's notification daemon has changed shape and Omacale's patch no longer applies, so the handover keeps running the previous daemon. Update Omacale."
    if (NotifHandover.lastAction === "synced")
      return "Omarchy's notification daemon was updated, and the handover now carries the new one. It applies after the next shell restart."
    if (NotifHandover.unverified)
      return "Omarchy's notification daemon differs from the one this Omacale was tested with. The patch still applies; report anything odd with the toasts."
    return ""
  }

  ConnectedRect {
    Layout.fillWidth: true
    first: true
    last: !root.notice && !NotifHandover.error
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
            text: root.drawing ? "notifications_active" : "notifications_off"
            size: Tk.iconSize.large
            fill: 1
            color: root.drawing ? Colours.m3onPrimaryContainer : Colours.m3onSurfaceVariant
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          RowLayout {
            spacing: Tk.spacing.medium

            MText {
              text: "Notification popups"
              font.pointSize: Tk.title.small
              weight: Font.Medium
            }

            LockCard.StatusChip {
              active: root.drawing
              text: {
                if (NotifHandover.busy)
                  return "Working…"
                if (!NotifHandover.ready)
                  return "Checking…"
                if (NotifHandover.fellBack && !NotifHandover.installed)
                  return "Handed back to Omarchy"
                if (root.drawing)
                  return "Drawn by Omacale"
                if (NotifHandover.installed)
                  return "Handover not running"
                return "Drawn by Omarchy"
              }
            }
          }

          MText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Colours.m3onSurfaceVariant
            text: "Omarchy's notification daemon keeps the D-Bus server, do not disturb and history. The handover clones it and takes out only its toast window, so Omacale can draw the toasts; removing it gives Omarchy's own toasts back."
          }
        }
      }

      Flow {
        Layout.fillWidth: true
        spacing: Tk.spacing.small

        Pill {
          icon: "download"
          label: NotifHandover.fellBack ? "Install again" : "Install handover"
          filled: true
          visible: NotifHandover.ready && !NotifHandover.installed
          onClicked: NotifHandover.install()
        }
        Pill {
          icon: "restart_alt"
          label: "Resync"
          visible: NotifHandover.installed && NotifHandover.stale && !NotifHandover.refused
          onClicked: NotifHandover.install()
        }
        Pill {
          icon: "undo"
          label: "Remove handover"
          visible: NotifHandover.ready && NotifHandover.clone !== ""
          onClicked: NotifHandover.remove()
        }
      }
    }
  }

  ConnectedRect {
    Layout.fillWidth: true
    last: !NotifHandover.error
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
    visible: NotifHandover.error !== ""
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
      text: NotifHandover.error
    }
  }
}
