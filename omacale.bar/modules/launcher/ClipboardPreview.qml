import QtQuick
import QtQuick.Controls
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

  onRowChanged: text.contentY = 0

  // Just the entry: its whole text, or its image, straight on the panel's
  // own surface. Its kind and the keys are left out; the rows say the first.
  Item {
    anchors.fill: parent
    visible: !!root.row
    clip: true

    Image {
      visible: root.isImage
      anchors.fill: parent
      anchors.margins: Tk.padding.small
      source: root.isImage ? "file://" + root.row.previewImage : ""
      fillMode: Image.PreserveAspectFit
      asynchronous: true
      smooth: true
      mipmap: true
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
