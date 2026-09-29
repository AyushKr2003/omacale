import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
  signal deleteRequested()
  signal clearRequested()

  readonly property bool isImage: !!row && row.previewImage !== ""
  readonly property string kind: !row ? "" : row.entryType === "image" ? "Image"
    : row.entryType === "file" ? "File" : "Text"
  readonly property string meta: {
    if (!row) return ""
    if (row.entryType === "image") return row.mime
    if (row.entryType === "file") return row.fullText.split("\n").length > 1 ? row.previewText : row.path
    const lines = row.fullText.split("\n").length
    const chars = row.fullText.length
    // displayRows caps the text it shows (displayTextLimit); pasting reads
    // the whole entry back from history, so only the count is approximate.
    return (lines > 1 ? lines + " lines · " : "") + (chars >= 8192 ? "8192+" : chars) + " characters"
  }

  onRowChanged: text.contentY = 0

  ColumnLayout {
    anchors.fill: parent
    spacing: Tk.spacing.small
    visible: !!root.row

    RowLayout {
      Layout.fillWidth: true
      spacing: Tk.spacing.small

      MIcon {
        text: root.row && root.row.entryType === "image" ? "image"
          : root.row && root.row.entryType === "file" ? "description" : "notes"
        size: Tk.iconSize.medium
        color: Colours.m3primary
      }
      MText {
        text: root.kind
        font.pointSize: Tk.label.large
        weight: Font.Medium
      }
      MText {
        Layout.fillWidth: true
        text: root.meta
        color: Colours.m3outline
        font.pointSize: Tk.label.medium
        elide: Text.ElideMiddle
      }
      IconButton {
        type: "text"
        icon: "delete"
        onClicked: root.deleteRequested()
      }
      IconButton {
        type: "text"
        icon: "delete_sweep"
        onClicked: root.clearRequested()
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: Tk.rounding.medium
      color: Colours.m3surfaceContainer
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

    MText {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      text: "Enter paste · Shift+Enter copy · Alt+Enter open · Del delete · Shift+Del clear"
      color: Colours.m3outline
      font.pointSize: Tk.label.small
      wrapMode: Text.WordWrap
    }
  }
}
