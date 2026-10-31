import QtQuick
import QtQuick.Layouts
import "../../.."

// Settings › Boot menu: Apply (asks your password; BootMenu runs
// scripts/limine-style as root), Undo, and Omarchy's look back, with what
// happened last. Nothing on the page reaches the boot partition before Apply.
ConnectedRect {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  implicitHeight: col.implicitHeight + Tk.padding.large * 2

  ColumnLayout {
    id: col
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Tk.padding.largeIncreased
    anchors.rightMargin: Tk.padding.largeIncreased
    spacing: Tk.spacing.medium

    RowLabel {
      Layout.fillWidth: true
      text: BootMenu.busy ? "Working..." : BootMenu.message ? BootMenu.message
        : !BootMenu.valid ? "A colour isn't a full RRGGBB value yet"
        : !BootMenu.applied ? "Omacale hasn't changed your boot menu yet"
        : BootMenu.dirty ? "Changes not applied yet" : "Applied"
      subtext: "Only the look of the menu changes; your boot entries and snapshots are left alone. A backup is kept on the boot partition (omacale/backups, the last five)."
    }
    Flow {
      Layout.fillWidth: true
      spacing: Tk.spacing.small
      IconTextButton {
        type: "filled"
        isRound: true
        icon: "check"
        text: "Apply"
        fontSize: Tk.body.medium
        horizontalPadding: Tk.padding.large
        verticalPadding: Tk.padding.small
        disabled: !BootMenu.valid || BootMenu.busy || !BootMenu.dirty
        onClicked: BootMenu.apply()
      }
      IconTextButton {
        type: "tonal"
        isRound: true
        icon: "palette"
        text: "Theme colours"
        fontSize: Tk.body.medium
        horizontalPadding: Tk.padding.large
        verticalPadding: Tk.padding.small
        disabled: BootMenu.busy
        onClicked: BootMenu.fromTheme()
      }
      IconTextButton {
        type: "tonal"
        isRound: true
        icon: "undo"
        text: "Undo last change"
        fontSize: Tk.body.medium
        horizontalPadding: Tk.padding.large
        verticalPadding: Tk.padding.small
        disabled: BootMenu.busy
        onClicked: BootMenu.undo()
      }
      IconTextButton {
        type: "tonal"
        isRound: true
        icon: "restart_alt"
        text: "Omarchy's look"
        fontSize: Tk.body.medium
        horizontalPadding: Tk.padding.large
        verticalPadding: Tk.padding.small
        disabled: BootMenu.busy
        onClicked: BootMenu.restoreDefault()
      }
    }
  }
}
