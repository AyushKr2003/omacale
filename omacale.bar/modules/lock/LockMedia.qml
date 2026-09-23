import QtQuick
import QtQuick.Layouts
import "../.."

// The media card at the bottom left of the lock (Caelestia lock/Media.qml):
// the cover art washed out behind the surface colour, the track and artist
// centred on it, and previous / play / next under them.
Rectangle {
  id: root

  readonly property var player: Sys.player

  implicitHeight: layout.implicitHeight + Tk.padding.extraLarge * 2
  radius: Tk.rounding.extraLarge
  color: Colours.m3surfaceContainer
  clip: true

  Image {
    id: art

    anchors.fill: parent
    source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""

    asynchronous: true
    fillMode: Image.PreserveAspectCrop
    sourceSize.width: width
    sourceSize.height: height

    opacity: status === Image.Ready ? 1 : 0

    Behavior on opacity {
      Anim {
        type: "standardExtraLarge"
      }
    }

    Rectangle {
      anchors.fill: parent
      color: Colours.palette.m3surface
      opacity: 0.7
    }
  }

  ColumnLayout {
    id: layout

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.margins: Tk.padding.extraLarge

    spacing: Tk.spacing.extraSmall

    MText {
      Layout.fillWidth: true
      animate: true
      text: (root.player?.trackTitle ?? "Nothing playing") || "Unknown track"
      color: Colours.m3primary
      horizontalAlignment: Text.AlignHCenter
      font.pointSize: Tk.title.medium
      weight: Font.Medium
      elide: Text.ElideRight
    }

    MText {
      Layout.fillWidth: true
      animate: true
      text: (root.player?.trackArtist ?? "Try playing some music!") || "Unknown artist"
      color: Colours.m3onSurfaceVariant
      horizontalAlignment: Text.AlignHCenter
      font.pointSize: Tk.body.small
      elide: Text.ElideRight
    }

    ButtonRow {
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: Tk.spacing.medium

      spacing: Tk.spacing.extraSmall

      IconButton {
        type: "tonal"
        icon: "skip_previous"
        shapeMorph: true
        disabled: !root.player?.canGoPrevious
        onClicked: root.player?.previous()
      }

      IconButton {
        icon: root.player?.isPlaying ? "pause" : "play_arrow"
        shapeMorph: true
        checked: root.player?.isPlaying ?? false
        disabled: !root.player?.canTogglePlaying
        onClicked: root.player?.togglePlaying()
        implicitWidth: implicitHeight + Tk.padding.largeIncreased * 2
      }

      IconButton {
        type: "tonal"
        icon: "skip_next"
        shapeMorph: true
        disabled: !root.player?.canGoNext
        onClicked: root.player?.next()
      }
    }
  }
}
