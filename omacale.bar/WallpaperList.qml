import QtQuick

// Caelestia modules/launcher/WallpaperList.qml: the launcher's carousel. The
// current item sits in the middle at full size; scrolling previews it on the
// Omarchy background. Omacale also uses it for Omarchy themes, whose preview
// images take the place of wallpapers.
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

  readonly property int numItems: {
    // Screen width - 4x outer rounding - 2x bar (cause centered)
    const maxWidth = screenWidth - Tk.borderRounding * 4 - Tk.barWidth * 2
    if (maxWidth <= 0) return 0

    const maxItemsOnScreen = Math.floor(maxWidth / itemWidth)
    const visible = Math.min(maxItemsOnScreen, Config.o.launcher.maxWallpapers, values.length)

    if (visible === 2) return 1
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
  Component.onCompleted: { Wallpapers.reload(); recentre() }
  Component.onDestruction: Wallpapers.stopPreview()

  onThemesChanged: if (themes) Wallpapers.stopPreview()
  onCurrentItemChanged: if (currentItem && !themes) Wallpapers.preview(currentItem.modelData.key)

  implicitWidth: Math.min(numItems, count) * itemWidth
  pathItemCount: numItems
  cacheItemCount: 4

  snapMode: PathView.SnapToItem
  preferredHighlightBegin: 0.5
  preferredHighlightEnd: 0.5
  highlightRangeMode: PathView.StrictlyEnforceRange

  delegate: WallpaperItem {}

  path: Path {
    startY: root.height / 2

    PathAttribute { name: "z"; value: 0 }
    PathLine { x: root.width / 2; relativeY: 0 }
    PathAttribute { name: "z"; value: 1 }
    PathLine { x: root.width; relativeY: 0 }
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
