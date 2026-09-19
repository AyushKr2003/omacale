import QtQuick
import QtQuick.Layouts

// Recordings list (Caelestia utilities/cards/RecordingList.qml): a header with
// an unfold toggle, then the newest recordings with play / folder / delete.
ColumnLayout {
  id: root
  spacing: 0

  function label(name) {
    const m = name.match(/(\d{4})-(\d{2})-(\d{2})[_ T-](\d{2})[-:](\d{2})[-:](\d{2})/) || name.match(/(\d{4})(\d{2})(\d{2})_(\d{2})-(\d{2})-(\d{2})/)
    if (!m) return name.replace(/\.[^.]+$/, "")
    return "Recording at " + Sys.dateTime(new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]))
  }

  MouseArea {
    Layout.fillWidth: true
    implicitHeight: header.implicitHeight
    cursorShape: Qt.PointingHandCursor
    onClicked: RecordService.listExpanded = !RecordService.listExpanded

    RowLayout {
      id: header
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: Tk.spacing.medium

      MIcon { Layout.alignment: Qt.AlignVCenter; text: "list"; size: Tk.iconSize.large }
      MText { Layout.alignment: Qt.AlignVCenter; Layout.fillWidth: true; text: "Recordings"; font.pointSize: Tk.body.medium }
      IconButton {
        type: "text"
        icon: RecordService.listExpanded ? "unfold_less" : "unfold_more"
        onClicked: RecordService.listExpanded = !RecordService.listExpanded
      }
    }
  }

  ListView {
    id: list
    Layout.fillWidth: true
    Layout.rightMargin: -Tk.spacing.small
    implicitHeight: (Tk.body.large + Tk.padding.small) * (RecordService.listExpanded ? 10 : 3)
    Behavior on implicitHeight { Anim {} }
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    model: RecordService.recentRecordings

    delegate: RowLayout {
      id: rec
      required property var modelData
      readonly property bool confirming: RecordService.confirmDelete === modelData.path

      anchors.left: parent ? parent.left : undefined
      anchors.right: parent ? parent.right : undefined
      anchors.rightMargin: Tk.spacing.small
      spacing: Tk.spacing.extraSmall

      MText {
        Layout.fillWidth: true
        Layout.rightMargin: Tk.spacing.extraSmall
        text: rec.confirming ? "Delete this recording?" : root.label(rec.modelData.name)
        color: rec.confirming ? Colours.m3error : Colours.m3onSurfaceVariant
        elide: Text.ElideRight
      }
      IconButton {
        visible: !rec.confirming
        type: "text"
        icon: "play_arrow"
        onClicked: RecordService.play(rec.modelData.path)
      }
      IconButton {
        visible: !rec.confirming
        type: "text"
        icon: "folder"
        onClicked: RecordService.reveal(rec.modelData.path)
      }
      IconButton {
        type: "text"
        icon: rec.confirming ? "check" : "delete_forever"
        inactiveOnColour: Colours.m3error
        onClicked: {
          if (rec.confirming) { RecordService.remove(rec.modelData.path); RecordService.confirmDelete = "" }
          else RecordService.confirmDelete = rec.modelData.path
        }
      }
      IconButton {
        visible: rec.confirming
        type: "text"
        icon: "close"
        onClicked: RecordService.confirmDelete = ""
      }
    }

    // Empty state
    Loader {
      anchors.centerIn: parent
      opacity: list.count === 0 ? 1 : 0
      active: opacity > 0
      Behavior on opacity { Anim { type: "effects" } }

      sourceComponent: RowLayout {
        spacing: Tk.spacing.medium
        MIcon { text: "scan_delete"; color: Colours.m3outline }
        MText { text: "No recordings found"; color: Colours.m3outline }
      }
    }
  }
}
