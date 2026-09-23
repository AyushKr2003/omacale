import QtQuick
import QtQuick.Layouts
import "../.."

// The notification dock on the lock (Caelestia lock/NotifDock.qml): the count
// over a list of the same grouped cards the sidebar shows. Settings › Panels
// › Lock screen can hide the contents ("Unlock for notifications") for a lock
// screen that gives nothing away while it is showing.
ColumnLayout {
  id: root

  readonly property bool hidden: Config.o.lock.hideNotifs
  readonly property var groups: NotifService.groups

  spacing: Tk.spacing.medium

  MText {
    Layout.fillWidth: true
    text: !root.hidden && root.groups.length > 0 ? (NotifService.count === 1 ? "1 notification" : `${NotifService.count} notifications`) : "Notifications"
    color: Colours.m3outline
    font.family: Tk.mono
    font.pointSize: Tk.body.small
    weight: Font.Medium
    elide: Text.ElideRight
  }

  Item {
    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true

    // Caelestia's empty state, with Omacale's own wording from the sidebar.
    ColumnLayout {
      anchors.centerIn: parent
      width: parent.width

      opacity: root.hidden || root.groups.length === 0 ? 1 : 0
      visible: opacity > 0
      spacing: Tk.spacing.largeIncreased

      Behavior on opacity {
        Anim {
          type: "standardExtraLarge"
        }
      }

      MIcon {
        Layout.alignment: Qt.AlignHCenter
        text: root.hidden ? "lock" : "notifications_off"
        color: Colours.m3outlineVariant
        size: Tk.iconSize.extraLarge * 2
      }

      MText {
        Layout.alignment: Qt.AlignHCenter
        text: root.hidden ? "Unlock for notifications" : "All up to date!"
        color: Colours.m3outlineVariant
        font.family: Tk.mono
        font.pointSize: Tk.body.large
        weight: Font.Medium
      }
    }

    MListView {
      id: list

      anchors.fill: parent
      visible: !root.hidden
      spacing: Tk.spacing.small
      clip: true

      model: root.groups

      delegate: NotifGroup {
        required property var modelData

        width: list.width
        groupData: modelData
      }

      add: Transition {
        Anim {
          property: "opacity"
          from: 0
          to: 1
          type: "effects"
        }
        Anim {
          property: "scale"
          from: 0
          to: 1
        }
      }

      remove: Transition {
        Anim {
          property: "opacity"
          to: 0
          type: "effects"
        }
        Anim {
          property: "scale"
          to: 0.6
        }
      }

      displaced: Transition {
        Anim {
          properties: "opacity,scale"
          to: 1
          type: "effects"
        }
        Anim {
          property: "y"
        }
      }
    }
  }
}
