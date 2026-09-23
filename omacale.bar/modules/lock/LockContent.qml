import QtQuick
import QtQuick.Layouts
import "../.."

// The inside of the lock card (Caelestia modules/lock/Content.qml): weather,
// fetch and media down the left, the clock and password in the middle, and
// resources over the notification dock on the right. Each side card can be
// turned off in Settings › Panels › Lock screen; a column with nothing left
// in it gives its width back to the middle.
RowLayout {
  id: root

  required property var lock

  readonly property var cfg: Config.o.lock
  readonly property bool hasLeft: cfg.weather || cfg.fetch || cfg.media
  readonly property bool hasRight: cfg.resources || cfg.notifs

  spacing: Tk.spacing.largeIncreased * 2

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.hasLeft
    spacing: Tk.spacing.medium

    LockWeather {
      Layout.fillWidth: true
      visible: root.cfg.weather
      rootHeight: root.height
    }

    LockFetch {
      Layout.fillWidth: true
      visible: root.cfg.fetch
      rootHeight: root.height
    }

    LockMedia {
      Layout.fillWidth: true
      Layout.fillHeight: true
      visible: root.cfg.media
    }

    // The card that fills the column's slack is the last one; without it the
    // rest would centre themselves instead of stacking from the top.
    Item {
      Layout.fillHeight: true
      visible: !root.cfg.media
    }
  }

  LockCenter {
    lock: root.lock
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.hasRight
    spacing: Tk.spacing.medium

    LockResources {
      Layout.fillWidth: true
      visible: root.cfg.resources
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      visible: root.cfg.notifs

      // Caelestia rounds the corner that meets the card's own corner harder.
      radius: Tk.rounding.medium
      bottomRightRadius: Tk.rounding.extraLarge
      color: Colours.m3surfaceContainer

      LockNotifs {
        anchors.fill: parent
        anchors.margins: Tk.padding.large
      }
    }

    Item {
      Layout.fillHeight: true
      visible: !root.cfg.notifs
    }
  }
}
