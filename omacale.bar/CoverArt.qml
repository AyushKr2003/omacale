import QtQuick
import QtQuick.Effects

// Caelestia CoverArt: album art cut to a slowly spinning M3 shape (it only
// turns while music plays), with a faint outline glow.
Item {
  id: root
  property string source: ""
  property string shapeName: "cookie12"
  property bool playing: false
  readonly property alias shape: shape

  layer.enabled: true
  layer.effect: MultiEffect { shadowEnabled: true; blurMax: 1; shadowColor: Colours.m3outline; shadowOpacity: 0.3 }

  MShape {
    id: shape
    anchors.fill: parent
    implicitSize: root.width
    shape: root.shapeName
    color: Colours.m3surfaceContainerHighest
    RotationAnimation on rotation {
      running: true
      paused: !root.playing
      from: 360; to: 0
      duration: 23500
      loops: Animation.Infinite
    }
  }
  MIcon {
    anchors.centerIn: parent
    grade: 200
    text: img.status === Image.Error ? "broken_image" : "art_track"
    size: Math.max(1, root.width * 0.35 * 0.75)
    color: Colours.m3onSurfaceVariant
    opacity: img.status === Image.Ready ? 0 : 1
    Behavior on opacity { Anim { type: "effects" } }
  }
  Item {
    anchors.fill: parent
    layer.enabled: true
    layer.effect: ShaderMaskEffect { maskItem: shape }
    Image {
      id: img
      anchors.fill: parent
      source: root.source
      fillMode: Image.PreserveAspectCrop
      sourceSize.width: 400; sourceSize.height: 400
      asynchronous: true
      opacity: status === Image.Ready ? 1 : 0
      Behavior on opacity { Anim { type: "slowEffects" } }
    }
  }
}
