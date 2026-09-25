import QtQuick
import "../.."

// Caelestia modules/launcher/WallpaperList.qml: the launcher's carousel. The
// current item sits in the middle at full size; scrolling previews it on the
// Omarchy background. Omacale also uses it for Omarchy themes, whose preview
// images take the place of wallpapers.
//
// One deliberate difference: with exactly two entries Caelestia shows only the
// current one, since a wrapping path can't hold the other on a fixed side of a
// centred item. Omacale shows both side by side (`pair`): the path stops
// following the selection, so moving it only changes which one is current.
PathView {
  id: root

  required property string kind         // "wallpapers" | "themes"
  required property string search       // launcher text after the prefix
  property real screenWidth: 0
  signal picked()

  readonly property int itemWidth: Tk.sizes.launcherWallpaperWidth * 0.8 + Tk.padding.medium * 2
  readonly property bool themes: kind === "themes"
  readonly property string current: themes ? Wallpapers.currentTheme : Wallpapers.currentWall

  readonly property var values: {
    const all = themes ? Wallpapers.themes : Wallpapers.walls
    const q = search.trim().toLowerCase()
    return q ? all.filter(w => w.label.toLowerCase().indexOf(q) >= 0 || w.key.split("/").pop().toLowerCase().indexOf(q) >= 0) : all
  }

  readonly property bool pair: numItems === 2
  readonly property int numItems: {
    // Screen width - 4x outer rounding - 2x bar (cause centered)
    const maxWidth = screenWidth - Tk.borderRounding * 4 - Tk.barWidth * 2
    if (maxWidth <= 0) return 0

    const maxItemsOnScreen = Math.floor(maxWidth / itemWidth)
    const visible = Math.min(maxItemsOnScreen, Config.o.launcher.maxWallpapers, values.length)

    // Only a model of exactly two is a pair; two that fit out of more stay 1,
    // as a still path can't scroll through the rest.
    if (visible === 2) return values.length === 2 ? 2 : 1
    if (visible > 1 && visible % 2 === 0) return visible - 1
    return visible
  }

  function recentre() {
    const i = values.findIndex(w => w.key === current)
    currentIndex = search.trim() || i < 0 ? 0 : i
  }

  function activate(entry) {
    if (!entry) return
    if (themes) Wallpapers.setTheme(entry.key)
    else Wallpapers.setWallpaper(entry.key)
    picked()
  }

  // A plain array resets currentIndex when it is assigned, so re-centre after
  // the model changes (Caelestia's ScriptModel does it on valuesChanged).
  model: values
  onModelChanged: recentre()
  // A pair sits at offset 0 whatever is current; leaving one, put the current
  // item back in the middle, since the range mode alone doesn't move the path.
  onPairChanged: Qt.callLater(() => {
    if (pair) offset = 0
    else positionViewAtIndex(currentIndex, PathView.Center)
  })
  Component.onCompleted: { Wallpapers.reload(); recentre() }
  Component.onDestruction: Wallpapers.stopPreview()

  onThemesChanged: if (themes) Wallpapers.stopPreview()
  onCurrentItemChanged: if (currentItem && !themes) Wallpapers.preview(currentItem.modelData.key)

  implicitWidth: Math.min(numItems, count) * itemWidth
  pathItemCount: numItems
  cacheItemCount: 4

  snapMode: PathView.SnapToItem
  // PathView adds the highlight start to every position whenever it snaps,
  // range or no range, so a pair has none: item 0 is left, item 1 right.
  preferredHighlightBegin: pair ? 0 : 0.5
  preferredHighlightEnd: pair ? 0 : 0.5
  highlightRangeMode: pair ? PathView.NoHighlightRange : PathView.StrictlyEnforceRange
  interactive: !pair

  delegate: WallpaperItem {}

  // A pair's path runs from the first slot's centre to half a slot past the
  // second, so its two items (at 0 and 0.5 of it) sit on the slot centres.
  path: Path {
    startX: root.pair ? root.itemWidth / 2 : 0
    startY: root.height / 2

    PathAttribute { name: "z"; value: 0 }
    PathLine { x: root.pair ? root.itemWidth * 1.5 : root.width / 2; relativeY: 0 }
    PathAttribute { name: "z"; value: 1 }
    PathLine { x: root.pair ? root.itemWidth * 2.5 : root.width; relativeY: 0 }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    onWheel: function(event) {
      if (event.angleDelta.y > 0) root.decrementCurrentIndex()
      else if (event.angleDelta.y < 0) root.incrementCurrentIndex()
    }
  }
}
