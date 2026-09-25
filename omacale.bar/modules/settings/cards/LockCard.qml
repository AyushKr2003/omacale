import QtQuick
import QtQuick.Layouts
import "../../.."

// Settings › Panels › Lock screen: what is drawing the lock screen, and the
// handover that changes it (LockService, scripts/lock-screen).
ColumnLayout {
  id: root

  property var settings
  property var row
  property bool first
  property bool last

  spacing: Tk.spacing.extraSmall / 2

  readonly property bool on: Config.o.lock.enabled
  readonly property bool installed: LockService.installed
  readonly property bool drawing: on && installed

  Component.onCompleted: LockService.refresh()

  ConnectedRect {
    Layout.fillWidth: true
    first: true
    last: !root.notice && !LockService.error
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
            text: root.drawing ? "lock" : "lock_open_right"
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
              text: "Lock screen"
              font.pointSize: Tk.title.small
              weight: Font.Medium
            }

            StatusChip {
              active: root.drawing
              text: {
                if (LockService.busy)
                  return "Working…"
                if (!LockService.ready)
                  return "Checking…"
                if (LockService.fellBack && !root.installed)
                  return "Handed back to Omarchy"
                if (root.drawing)
                  return "Drawn by Omacale"
                if (root.on)
                  return "Handover missing"
                return "Drawn by Omarchy"
              }
            }
          }

          MText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Colours.m3onSurfaceVariant
            text: "Omarchy's lock plugin keeps the session lock, PAM and the `lock` IPC that `omarchy system lock` and the sleep lock call. Turning this on clones that plugin and swaps only the view for Caelestia's; turning it off gives the drawing straight back."
          }
        }
      }

      Flow {
        Layout.fillWidth: true
        spacing: Tk.spacing.small

        Pill {
          icon: "visibility"
          label: "Preview"
          filled: true
          // The preview is an overlay surface over everything, so the
          // settings drawer goes away first or it is all the user sees.
          onClicked: {
            if (root.settings)
              root.settings.closeRequested()
            LockService.preview()
          }
        }
        Pill {
          icon: "download"
          label: LockService.fellBack ? "Install again" : "Install handover"
          visible: LockService.ready && !LockService.installed
          onClicked: LockService.install()
        }
        Pill {
          icon: "restart_alt"
          label: "Reinstall"
          visible: LockService.installed && LockService.stale
          onClicked: LockService.install()
        }
        Pill {
          icon: "undo"
          label: "Remove handover"
          visible: LockService.ready && LockService.clone !== ""
          onClicked: LockService.remove()
        }
      }
    }
  }

  // The clone is rebuilt from Omarchy's lock plugin whenever an `omarchy
  // update` changes it (services/Handover.qml); this says what happened.
  readonly property string notice: {
    if (LockService.fellBack && !root.installed)
      return "After an Omarchy update the lock service in the handover stopped working"
        + (LockService.lastReason ? " (" + LockService.lastReason + ")" : "")
        + ", so Omarchy's own lock screen was put back. Install the handover again once Omacale is updated."
    if (LockService.lastAction === "synced")
      return "Omarchy's lock plugin was updated, and the handover now carries the new one. It applies after the next shell restart."
    if (LockService.lastAction === "refused")
      return "Omarchy's lock service now drives its view with something Omacale's doesn't have, so the handover kept the previous service. Update Omacale."
    if (LockService.installed && LockService.stale)
      return "Omarchy's lock plugin has changed. The handover picks it up by itself while the screen is unlocked, or now with Reinstall."
    return ""
  }

  ConnectedRect {
    Layout.fillWidth: true
    last: !LockService.error
    visible: root.notice !== ""
    implicitHeight: staleText.implicitHeight + Tk.padding.medium * 2

    MText {
      id: staleText

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
    visible: LockService.error !== ""
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
      text: LockService.error
    }
  }

  component StatusChip: Rectangle {
    id: sc

    property bool active
    property string text

    implicitWidth: sct.implicitWidth + Tk.padding.medium * 2
    implicitHeight: sct.implicitHeight + Tk.padding.extraSmall * 2
    radius: height / 2
    color: active ? Colours.m3tertiaryContainer : "transparent"
    border.width: active ? 0 : 1
    border.color: Colours.m3outlineVariant

    MText {
      id: sct

      anchors.centerIn: parent
      text: sc.text
      font.pointSize: Tk.label.small
      weight: Font.Medium
      color: sc.active ? Colours.m3onTertiaryContainer : Colours.m3outline
    }
  }
}
