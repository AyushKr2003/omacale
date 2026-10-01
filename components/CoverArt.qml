import QtQuick
import QtQuick.Effects
import ".."

// Caelestia CoverArt: album art cut to a slowly spinning M3 shape (it only
// turns while music plays), with a faint outline glow.
Item {
  id: root
  property string source: ""
  property string shapeName: "cookie12"
  property bool playing: false
  readonly property alias shape: shape
  // Caelestia's fallbackColour: the layered container, drawn opaque under an
  // opacity of its alpha so the spinning shape isn't see-through at its seams.
  property color fallbackColour: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
  Behavior on fallbackColour { CAnim {} }

  layer.enabled: true
  layer.effect: MultiEffect { shadowEnabled: true; blurMax: 1; shadowColor: Colours.m3outline; shadowOpacity: 0.3 }

  MShape {
    id: shape
    anchors.fill: parent
    implicitSize: root.width
    shape: root.shapeName
    color: Qt.alpha(root.fallbackColour, 1)
    opacity: root.fallbackColour.a
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
    size: Math.max(1, root.width * 0.35)
    color: Colours.m3onSurfaceVariant
    animate: true
    opacity: img.status === Image.Null || img.status === Image.Error ? 1 : 0
    Behavior on opacity { Anim { type: "effects" } }
  }
  Loader {
    anchors.centerIn: parent
    asynchronous: true
    active: opacity > 0
    opacity: img.status === Image.Loading ? 1 : 0
    Behavior on opacity { Anim { type: "effects" } }
    sourceComponent: MorphIndicator {
      implicitSize: root.width * 0.3
      colour: Colours.m3primaryContainer
    }
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
      sourceSize.width: Tk.px(400); sourceSize.height: Tk.px(400)
      asynchronous: true
      opacity: status === Image.Ready ? 1 : 0
      Behavior on opacity { Anim { type: "slowEffects" } }
    }
  }
}
