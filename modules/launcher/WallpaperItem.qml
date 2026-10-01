import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../.."

// Caelestia modules/launcher/items/WallpaperItem.qml: a 16:9 thumbnail with
// its name below; the centred one is full size and lifted, neighbours shrink.
Item {
  id: root

  required property var modelData
  required property int index

  scale: 0.5
  opacity: 0
  // The path's z puts the centre on top; a pair doesn't move, so there it is
  // whichever one is current.
  z: PathView.view && PathView.view.pair ? (PathView.isCurrentItem ? 1 : 0) : PathView.z ?? 0

  Component.onCompleted: {
    scale = Qt.binding(() => PathView.isCurrentItem ? 1 : PathView.onPath ? 0.8 : 0)
    opacity = Qt.binding(() => PathView.onPath ? 1 : 0)
  }

  implicitWidth: image.width + Tk.padding.medium * 2
  implicitHeight: image.height + label.height + Tk.spacing.extraSmall + Tk.padding.large + Tk.padding.medium

  StateLayer {
    radius: Tk.rounding.large
    onClicked: root.PathView.view.activate(root.modelData)
  }

  // Caelestia Elevation, level 4.
  RectangularShadow {
    readonly property real dp: 8
    anchors.fill: image
    radius: image.radius
    color: Qt.alpha(Colours.m3shadow, 0.7)
    blur: Math.pow(dp * 5, 0.7)
    spread: -dp * 0.3 + Math.pow(dp * 0.1, 2)
    offset.y: dp / 2
    opacity: root.PathView.isCurrentItem ? 1 : 0
    Behavior on opacity { Anim { type: "effects" } }
  }

  ClippingRectangle {
    id: image

    anchors.horizontalCenter: parent.horizontalCenter
    y: Tk.padding.large
    width: Tk.sizes.launcherWallpaperWidth
    height: width / 16 * 9
    color: Colours.m3surfaceContainer
    radius: Tk.rounding.large

    MIcon {
      anchors.centerIn: parent
      text: "image"
      color: Colours.m3outline
      size: Tk.iconSize.extraLarge * 2
      weight: Font.DemiBold
    }

    Image {
      anchors.fill: parent
      source: root.modelData.thumb ? "file://" + root.modelData.thumb.split("/").map(encodeURIComponent).join("/") : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      smooth: !root.PathView.view.moving
      sourceSize.width: image.width * (QsWindow.window ? QsWindow.window.devicePixelRatio : 1)
      sourceSize.height: image.height * (QsWindow.window ? QsWindow.window.devicePixelRatio : 1)
      opacity: status === Image.Ready ? 1 : 0
      Behavior on opacity { Anim { type: "effects" } }
    }
  }

  MText {
    id: label

    anchors.top: image.bottom
    anchors.topMargin: Tk.spacing.extraSmall
    anchors.horizontalCenter: parent.horizontalCenter

    width: image.width - Tk.padding.medium * 2
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
    // As Caelestia: outline rendering stays crisp when the item is scaled to
    // 0.8, where MText's native glyphs would be resampled and blur.
    renderType: Text.QtRendering
    text: root.modelData.label
    font.pointSize: Tk.label.medium
    weight: Font.Medium
  }

  Behavior on scale { Anim {} }
  Behavior on opacity { Anim { type: "effects" } }
}
