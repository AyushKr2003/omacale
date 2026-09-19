import QtQuick
import Quickshell
import Quickshell.Io

// Caelestia Colours' ImageAnalyser (plugin/src/Caelestia/Images/imageanalyser.cpp):
// the wallpaper's mean luminance, from a copy scaled to fit 128px, feeds
// Colours.wallLuminance. Quickshell has no image analyser, so the image is
// drawn into this invisible Canvas and read back. It needs a window to paint
// in, so ScreenScope hosts one. Only sampled while transparency is on, the
// only time Colours.layer uses it.
Canvas {
  id: root

  readonly property int rescaleSize: 128
  readonly property string link: Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
  property string path: ""
  readonly property string url: path ? Wallpapers.url(path) : ""

  width: rescaleSize
  height: rescaleSize
  opacity: 0
  enabled: false
  renderTarget: Canvas.Image
  renderStrategy: Canvas.Immediate

  // Omarchy swaps the `current/background` symlink; resolve it on a slow
  // timer and whenever Omacale's own switcher sets a background.
  Process {
    id: resolve
    command: ["readlink", "-f", root.link]
    stdout: SplitParser {
      onRead: line => {
        const p = String(line).trim()
        // Videos have no still to analyse; keep the last value.
        if (p && !Wallpapers.isVideo(p)) root.path = p
      }
    }
  }
  Timer {
    interval: 5000
    running: Colours.transparent
    repeat: true
    triggeredOnStart: true
    onTriggered: resolve.running = true
  }
  Connections {
    target: Wallpapers
    function onCurrentWallChanged() { if (Colours.transparent) resolve.running = true }
  }

  // The Canvas draws from its own copy of the image (loadImage); this one,
  // decoded at the analyser's size, only gives the scaled dimensions (both
  // sourceSize dimensions set keeps the aspect ratio).
  Image {
    id: img
    visible: false
    asynchronous: true
    cache: false
    source: root.url
    sourceSize.width: root.rescaleSize
    sourceSize.height: root.rescaleSize
    onStatusChanged: if (status === Image.Ready) root.requestPaint()
  }
  property string loaded: ""
  onUrlChanged: {
    if (loaded) unloadImage(loaded)
    loaded = url
    if (url) loadImage(url)
  }
  onImageLoaded: requestPaint()

  // Drawn in onPaint, read back once the frame has been flushed. `painted`
  // also fires for frames that drew nothing new, hence the pending flag.
  property int drawnW: 0
  property int drawnH: 0
  property bool pending: false
  onPaint: {
    const ctx = getContext("2d")
    ctx.clearRect(0, 0, width, height)
    const w = Math.min(width, img.implicitWidth), h = Math.min(height, img.implicitHeight)
    drawnW = drawnH = 0
    if (img.status !== Image.Ready || !isImageLoaded(url) || w < 1 || h < 1) return
    ctx.drawImage(url, 0, 0, w, h)
    drawnW = w
    drawnH = h
    pending = true
  }
  onPainted: {
    if (!pending) return
    pending = false
    const data = getContext("2d").getImageData(0, 0, drawnW, drawnH).data
    let total = 0, count = 0
    for (let i = 0; i < data.length; i += 4) {
      if (data[i + 3] === 0) continue
      const r = data[i] / 255, g = data[i + 1] / 255, b = data[i + 2] / 255
      total += Math.sqrt(0.299 * r * r + 0.587 * g * g + 0.114 * b * b)
      count++
    }
    Colours.wallLuminance = count ? total / count : 0
  }
}
