import QtQuick
import QtQuick.Controls
import Quickshell.Widgets
import "../.."

// The clipboard preview panel: its own drawer beside the launcher while it
// shows ">clipboard " rows, as Caelestia PR #1298's ClipboardPreview (its
// background is ScreenScope's r8; this draws only the content). Unlike the
// PR it shows every entry, not only images: the whole text of the selected
// entry as Omarchy's clipboard panel does, or its image. `row` is a
// ClipboardHistory.js displayRows() row.
Item {
  id: root

  property var row: null

  readonly property bool isImage: !!row && row.previewImage !== ""

  // An image sizes the panel to its own aspect ratio, as the PR's
  // targetHeight does (there the height only, 200-600px): fitted inside
  // maxW x maxH, and small ones raised to minSide on their longer side.
  // ScreenScope reads `fit` (0x0 for text, which keeps the default size);
  // while the next image loads the last fit stays, so the panel doesn't jump.
  property real maxW: 0
  property real maxH: 0
  readonly property real minSide: Tk.px(240)
  readonly property bool imageReady: isImage && image.status === Image.Ready && image.sourceSize.width > 0
  property size fit: Qt.size(0, 0)
  function refit() {
    if (!isImage) { fit = Qt.size(0, 0); return }
    if (!imageReady || maxW <= 0 || maxH <= 0) return
    const iw = image.sourceSize.width, ih = image.sourceSize.height
    const s = Math.min(maxW / iw, maxH / ih, Math.max(1, minSide / Math.max(iw, ih)))
    fit = Qt.size(Math.round(iw * s), Math.round(ih * s))
  }
  onImageReadyChanged: refit()
  onIsImageChanged: refit()
  onMaxWChanged: refit()
  onMaxHChanged: refit()

  onRowChanged: text.contentY = 0

  // Just the entry: its whole text, or its image, straight on the panel's
  // own surface. Its kind and the keys are left out; the rows say the first.
  Item {
    anchors.fill: parent
    visible: !!root.row
    clip: true

    ClippingRectangle {
      visible: root.isImage
      anchors.fill: parent
      radius: Tk.rounding.medium
      color: "transparent"

      Image {
        id: image
        anchors.fill: parent
        source: root.isImage ? "file://" + root.row.previewImage : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
      }
    }

    FadeFlickable {
      id: text
      visible: !root.isImage
      anchors.fill: parent
      anchors.margins: Tk.padding.medium
      fadeSize: Tk.px(20)
      contentWidth: width
      contentHeight: body.implicitHeight
      clip: true
      ScrollBar.vertical: MScrollBar { flickable: text }

      MText {
        id: body
        width: text.width
        text: root.row && !root.isImage ? root.row.fullText : ""
        textFormat: Text.PlainText
        wrapMode: Text.WrapAnywhere
        font.family: Tk.mono
        font.pointSize: Tk.body.small
        color: Colours.m3onSurface
      }
    }
  }
}
