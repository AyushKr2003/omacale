import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../services/DisplayModel.js" as Model

// Settings › Display › Workspaces: which workspaces live on which screen,
// kept in the profile by hyprmoncfg (`workspaces`: strategy, max, group
// size, rules). Edits go to the draft (DisplayService.editProfile) and take
// effect with Apply, behind the keep-or-revert card, like any other layout
// change. Rules other than plain numbers (f[1]s[false], …) are kept as they
// are. hyprmoncfg's own panel has a fuller planner; this is the everyday part.
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last
  spacing: Tk.spacing.extraSmall / 2
  Component.onCompleted: DisplayService.hold()
  Component.onDestruction: DisplayService.release()

  readonly property var ws: DisplayService.draft ? (DisplayService.draft.workspaces || {}) : ({})
  readonly property string strategy: Model.wsStrategy(ws)
  readonly property var outputs: DisplayService.draftRows.filter(r => r.enabled && !r.mirrorOf).map(r => ({ key: r.key, name: r.name }))
  readonly property var assigned: Model.wsAssigned(ws)
  readonly property int count: Math.max(ws.max_workspaces || 9, ...Object.keys(assigned).map(Number))
  function edit(next) { DisplayService.editProfile({ workspaces: next }) }
  // A screen's chip colour: the first screen primary, the second tertiary, …
  function tone(key) {
    const i = outputs.findIndex(o => o.key === key)
    return i < 0 ? null : [Colours.m3primaryContainer, Colours.m3tertiaryContainer, Colours.m3secondaryContainer][i % 3]
  }
  function onTone(key) {
    const i = outputs.findIndex(o => o.key === key)
    return i < 0 ? Colours.m3onSurfaceVariant : [Colours.m3onPrimaryContainer, Colours.m3onTertiaryContainer, Colours.m3onSecondaryContainer][i % 3]
  }


  RowSelect {
    Layout.fillWidth: true
    first: true
    settings: root.settings
    row: ({ label: "Placement", icon: "space_dashboard",
      subtext: root.strategy === "off" ? "hyprmoncfg leaves workspaces where Hyprland puts them"
        : root.strategy === "manual" ? "Click a workspace to move it to the next screen"
        : root.strategy === "sequential" ? "In order: a group on the first screen, the next group on the next"
        : "Taking turns: one group at a time per screen",
      options: [{ value: "off", label: "Off" }, { value: "manual", label: "Manual" }, { value: "sequential", label: "Sequential" }, { value: "interleave", label: "Interleaved" }] })
    value: root.strategy
    onPicked: v => root.edit(Model.wsStrategyEdit(root.ws, v, DisplayService.workspacePlan))
  }

  // Sequential / interleaved: how many, in groups of how many.
  Repeater {
    model: root.strategy === "sequential" || root.strategy === "interleave" ? [
      { key: "max_workspaces", label: "Workspaces", min: 1, max: 30, fallback: 9 },
      { key: "group_size", label: "Group size", min: 1, max: 10, fallback: 3 }
    ] : []
    ConnectedRect {
      required property var modelData
      readonly property int val: root.ws[modelData.key] || modelData.fallback
      Layout.fillWidth: true
      implicitHeight: sr.implicitHeight + Tk.padding.medium * 2
      RowLayout {
        id: sr
        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.medium
        spacing: Tk.spacing.medium
        MText { Layout.fillWidth: true; text: modelData.label }
        IconButton { type: "text"; icon: "remove"; disabled: parent.parent.val <= modelData.min; onClicked: { const n = JSON.parse(JSON.stringify(root.ws)); n[modelData.key] = parent.parent.val - 1; root.edit(n) } }
        MText { Layout.preferredWidth: Tk.px(32); horizontalAlignment: Text.AlignHCenter; text: parent.parent.val }
        IconButton { type: "text"; icon: "add"; disabled: parent.parent.val >= modelData.max; onClicked: { const n = JSON.parse(JSON.stringify(root.ws)); n[modelData.key] = parent.parent.val + 1; root.edit(n) } }
      }
    }
  }

  // Manual: one chip per workspace, coloured by its screen.
  ConnectedRect {
    Layout.fillWidth: true
    visible: root.strategy === "manual"
    implicitHeight: grid.implicitHeight + Tk.padding.medium * 2
    Flow {
      id: grid
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.largeIncreased
      spacing: Tk.spacing.small
      Repeater {
        model: root.count
        Rectangle {
          id: chip
          required property int index
          readonly property string num: String(index + 1)
          readonly property string key: root.assigned[num] || ""
          readonly property var scr: root.outputs.find(o => o.key === key)
          width: Tk.px(78); height: Tk.px(48)
          radius: Tk.rounding.medium
          color: root.tone(key) || Colours.m3surfaceContainerHighest
          Column {
            anchors.centerIn: parent
            MText { anchors.horizontalCenter: parent.horizontalCenter; text: chip.num; weight: Font.Medium; color: root.onTone(chip.key) }
            MText { anchors.horizontalCenter: parent.horizontalCenter; text: chip.scr ? chip.scr.name : "Any"; font.pointSize: Tk.label.small; color: root.onTone(chip.key) }
          }
          StateLayer { onClicked: root.edit(Model.wsCycle(root.ws, chip.num, root.outputs)) }
        }
      }
    }
  }

  // What hyprmoncfg works out from it, per screen.
  ConnectedRect {
    Layout.fillWidth: true
    visible: root.strategy !== "off"
    implicitHeight: pl.implicitHeight + Tk.padding.medium * 2
    RowLayout {
      id: pl
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.largeIncreased
      MIcon { text: "view_column"; size: Tk.iconSize.medium; color: Colours.m3onSurfaceVariant }
      MText { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: Model.wsPlanText(DisplayService.workspacePlan); color: Colours.m3onSurfaceVariant; font.pointSize: Tk.body.small }
    }
  }

  // The page's Apply bar is far up; the same here.
  ConnectedRect {
    Layout.fillWidth: true
    last: true
    implicitHeight: ap.implicitHeight + Tk.padding.medium * 2
    RowLayout {
      id: ap
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.medium
      spacing: Tk.spacing.medium
      MText {
        Layout.fillWidth: true
        text: DisplayService.lastError ? "hyprmoncfg: " + DisplayService.lastError
          : DisplayService.dirty ? "Changes not applied yet" : "Kept in profile " + (DisplayService.sourceProfile || "–")
        color: DisplayService.lastError ? Colours.m3error : Colours.m3onSurfaceVariant
        font.pointSize: Tk.body.small
        wrapMode: Text.WordWrap
      }
      IconTextButton {
        visible: DisplayService.dirty && !DisplayService.previewBusy
        type: "text"; isRound: true; icon: "undo"; text: "Reset"
        fontSize: Tk.body.small
        onClicked: DisplayService.reset()
      }
      IconTextButton {
        visible: DisplayService.dirty && !DisplayService.previewBusy
        type: "filled"; isRound: true; icon: "check"; text: "Apply"
        fontSize: Tk.body.small
        disabled: DisplayService.editPending
        onClicked: DisplayService.apply()
      }
    }
  }
}
