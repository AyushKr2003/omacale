import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../.."
import "../../../services/DisplayModel.js" as Model

// Settings › Display: the displays as they are arranged, the selected one's
// details and brightness, and the desktop-wide text size and laptop panel.
// No Caelestia original (its nexus has a "Display" TODO stub); drawn with
// Nexus rows. Data and actions are DisplayService's (hyprmoncfg's daemon when
// it manages the displays, hyprctl otherwise; Omarchy's commands for the rest).
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  Component.onCompleted: DisplayService.hold()
  Component.onDestruction: DisplayService.release()

  // The draft while hyprmoncfg's editor is there (what Apply would set), the
  // live state otherwise.
  readonly property var monitors: DisplayService.editable ? DisplayService.draftRows : DisplayService.monitors
  readonly property bool edit: DisplayService.editable && !DisplayService.previewBusy
  readonly property string selected: DisplayService.selected   // survives Settings closing for the confirm card
  readonly property var sel: monitors.find(m => m.name === selected) || monitors.find(m => m.focused) || monitors[0] || null

  spacing: Tk.spacing.extraSmall / 2

  // ---- who manages the displays
  ConnectedRect {
    Layout.fillWidth: true
    first: true
    last: true
    implicitHeight: bl.implicitHeight + Tk.padding.medium * 2
    RowLayout {
      id: bl
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.medium
      spacing: Tk.spacing.medium
      MIcon {
        text: DisplayService.backend === "hyprmoncfg" ? "verified" : "info"
        size: Tk.iconSize.medium
        color: DisplayService.backend === "hyprmoncfg" ? Colours.m3primary : Colours.m3onSurfaceVariant
      }
      RowLabel {
        Layout.fillWidth: true
        text: DisplayService.backend === "hyprmoncfg" ? "Managed by hyprmoncfg" + (DisplayService.activeProfile ? " · " + DisplayService.activeProfile : "")
          : DisplayService.backend === "unmanaged" ? "hyprmoncfg is installed but not managing the displays"
          : "Read from Hyprland"
        subtext: DisplayService.backend === "hyprmoncfg" ? "Layouts follow your displays on hotplug, lid and resume"
          : DisplayService.backend === "unmanaged" ? "Let it manage them to save layouts per set of displays"
          : "Arranging displays, modes and profiles need hyprmoncfg"
      }
      IconTextButton {
        visible: DisplayService.backend === "unmanaged"
        type: "tonal"
        isRound: true
        fontSize: Tk.body.small
        horizontalPadding: Tk.padding.medium
        verticalPadding: Tk.padding.extraSmall
        icon: "play_arrow"
        text: "Manage"
        onClicked: DisplayService.manage()
      }
    }
  }

  // ---- the arrangement
  SectionHeader { row: ({ text: "Arrangement" }) }
  ConnectedRect {
    id: canvasCard
    Layout.fillWidth: true
    first: true
    last: true
    implicitHeight: Tk.px(220)
    readonly property var fitted: Model.fit(root.monitors, width, height - Tk.px(40), Tk.padding.large)
    Repeater {
      model: Model.rects(root.monitors, canvasCard.fitted)
      Rectangle {
        required property var modelData
        readonly property bool isSel: root.sel && root.sel.name === modelData.name
        x: Math.round(modelData.x); y: Math.round(modelData.y)
        width: Math.round(modelData.w) - 4; height: Math.round(modelData.h) - 4
        radius: Tk.rounding.small
        color: isSel ? Colours.m3primaryContainer : Colours.m3surfaceContainerHighest
        border.width: isSel ? 2 : 1
        border.color: isSel ? Colours.m3primary : Colours.m3outlineVariant
        Behavior on color { CAnim {} }
        Column {
          anchors.centerIn: parent
          MText { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.name; weight: Font.Medium; color: isSel ? Colours.m3onPrimaryContainer : Colours.m3onSurface }
          MText {
            readonly property var m: root.monitors.find(x => x.name === modelData.name)
            anchors.horizontalCenter: parent.horizontalCenter
            text: m ? m.width + "×" + m.height + " · " + Model.scaleLabel(m.scale) : ""
            font.pointSize: Tk.label.small
            color: Colours.m3onSurfaceVariant
          }
        }
        // Displays mirroring this one are left off the canvas (they'd sit
        // under it); a chip each, to select them.
        Column {
          z: 2
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Tk.padding.small
          spacing: Tk.spacing.extraSmall
          Repeater {
            model: root.monitors.filter(m => m.mirrorOf && (m.mirrorOf === modelData.key || m.mirrorOf === modelData.name)).map(m => m.name)
            IconTextButton {
              required property string modelData
              type: root.selected === modelData || (root.sel && root.sel.name === modelData) ? "filled" : "tonal"
              isRound: true
              icon: "screen_share"
              text: modelData + " mirrors this"
              fontSize: Tk.label.small
              verticalPadding: Tk.padding.extraSmall
              onClicked: DisplayService.selected = modelData
            }
          }
        }
        // Click selects; with the editor, drag moves it (the daemon snaps it
        // to its neighbours on edit_profile).
        MouseArea {
          id: boxMouse
          anchors.fill: parent
          cursorShape: root.edit ? (drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.PointingHandCursor
          drag.target: root.edit ? parent : null
          drag.threshold: Tk.px(6)
          onPressed: DisplayService.selected = modelData.name
          onReleased: {
            if (!drag.active && Math.abs(parent.x - Math.round(modelData.x)) < 1 && Math.abs(parent.y - Math.round(modelData.y)) < 1) return
            const at = Model.toLayout(parent.x, parent.y, canvasCard.fitted)
            DisplayService.edit(modelData.key, { x: at.x, y: at.y, snap_distance: Math.round(Tk.px(16) / canvasCard.fitted.k) })
            parent.x = Qt.binding(() => Math.round(modelData.x)); parent.y = Qt.binding(() => Math.round(modelData.y))
          }
        }
      }
    }
    IconTextButton {
      anchors.right: parent.right; anchors.bottom: parent.bottom
      anchors.margins: Tk.padding.small
      type: "tonal"
      isRound: true
      fontSize: Tk.body.small
      horizontalPadding: Tk.padding.medium
      verticalPadding: Tk.padding.extraSmall
      icon: "badge"
      text: "Identify"
      onClicked: DisplayService.identify()
    }
  }

  // ---- changes waiting for Apply
  ConnectedRect {
    Layout.fillWidth: true
    Layout.topMargin: Tk.spacing.small
    first: true
    last: true
    visible: DisplayService.dirty || DisplayService.lastError !== "" || DisplayService.previewBusy
    implicitHeight: ab.implicitHeight + Tk.padding.medium * 2
    RowLayout {
      id: ab
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.medium
      spacing: Tk.spacing.medium
      MIcon {
        text: DisplayService.lastError ? "error" : "edit"
        size: Tk.iconSize.medium
        color: DisplayService.lastError ? Colours.m3error : Colours.m3primary
      }
      RowLabel {
        Layout.fillWidth: true
        text: DisplayService.lastError ? DisplayService.lastError
          : DisplayService.previewBusy ? "Waiting for you to keep or revert"
          : "Changes not applied yet"
        subtext: DisplayService.previewBusy ? "" : "Applied for 30 seconds first; kept in profile " + (DisplayService.sourceProfile || "Omacale") + " if you keep them"
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

  // ---- the selected display
  SectionHeader { visible: !!root.sel; row: ({ text: root.sel ? root.sel.name : "" }) }
  Repeater {
    id: infoRows
    model: root.sel && !DisplayService.editable ? [
      { label: "Model", value: root.sel.label },
      { label: "Resolution", value: root.sel.width + " × " + root.sel.height + " @ " + Math.round(root.sel.refresh) + " Hz" },
      { label: "Scale", value: Model.scaleLabel(root.sel.scale) + " · " + root.sel.lw + " × " + root.sel.lh + " logical" },
      { label: "Position", value: root.sel.x + ", " + root.sel.y + (root.sel.mirrorOf ? " · mirrors " + root.sel.mirrorOf : "") }
    ] : []
    ConnectedRect {
      required property var modelData
      required property int index
      Layout.fillWidth: true
      first: index === 0
      last: index === 3 && brightRow.visible === false
      implicitHeight: il.implicitHeight + Tk.padding.medium * 2
      RowLayout {
        id: il
        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.largeIncreased
        MText { Layout.fillWidth: true; text: modelData.label }
        MText { Layout.maximumWidth: parent.width / 2; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; text: modelData.value; color: Colours.m3onSurfaceVariant }
      }
    }
  }
  DisplayEditor {
    Layout.fillWidth: true
    visible: DisplayService.editable && !!root.sel
    sel: root.sel
    monitors: root.monitors
    settings: root.settings
    enabled: root.edit
    last: !brightRow.visible
  }
  ConnectedRect {
    id: brightRow
    readonly property var level: root.sel ? DisplayService.brightness[root.sel.name] : undefined
    visible: level !== undefined
    Layout.fillWidth: true
    first: !DisplayService.editable && !infoRows.count
    last: !offRow.visible
    implicitHeight: br.implicitHeight + Tk.padding.medium * 2
    RowLayout {
      id: br
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.largeIncreased
      spacing: Tk.spacing.medium
      MIcon { text: "brightness_6"; size: Tk.iconSize.medium; color: Colours.m3onSurfaceVariant }
      MText { text: "Brightness"; Layout.preferredWidth: Tk.px(90) }
      MSlider {
        Layout.fillWidth: true
        implicitHeight: Tk.px(30)
        value: (brightRow.level || 0) / 100
        onMoved: v => DisplayService.setBrightness(root.sel.name, Math.max(1, v * 100))
      }
      MText { Layout.preferredWidth: Tk.px(40); horizontalAlignment: Text.AlignRight; text: Math.round(brightRow.level || 0) + "%"; color: Colours.m3onSurfaceVariant }
    }
  }

  // ---- this screen dark for now (DPMS), until "Turn on", a lock or a resume
  ConnectedRect {
    id: offRow
    Layout.fillWidth: true
    first: !brightRow.visible
    last: true
    visible: !!root.sel && root.sel.enabled
    readonly property bool off: !!root.sel && DisplayService.blanked.indexOf(root.sel.name) >= 0
    implicitHeight: bo.implicitHeight + Tk.padding.medium * 2
    RowLayout {
      id: bo
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.medium
      spacing: Tk.spacing.medium
      MIcon { text: offRow.off ? "monitor" : "desktop_access_disabled"; size: Tk.iconSize.medium; color: Colours.m3onSurfaceVariant }
      RowLabel {
        Layout.fillWidth: true
        text: offRow.off ? (root.sel ? root.sel.name : "") + " is off" : "Turn off for now"
        subtext: offRow.off ? "It stays dark until you turn it on here, lock the screen or resume"
          : root.sel && !DisplayService.canBlank(root.sel.name) ? "Another screen has to stay on"
          : "The screen goes dark; your layout and windows stay as they are"
      }
      IconTextButton {
        type: offRow.off ? "filled" : "tonal"; isRound: true
        icon: "power_settings_new"
        text: offRow.off ? "Turn on" : "Turn off"
        fontSize: Tk.body.small
        disabled: !offRow.off && !(root.sel && DisplayService.canBlank(root.sel.name))
        onClicked: offRow.off ? DisplayService.wake(root.sel.name) : DisplayService.blank(root.sel.name)
      }
    }
  }

  // ---- without hyprmoncfg: Omarchy's own laptop-panel switches
  RowToggle {
    Layout.fillWidth: true
    Layout.topMargin: Tk.spacing.small
    visible: DisplayService.hasInternal && DisplayService.hasExternal && !DisplayService.editable
    first: true
    text: "Laptop screen"
    subtext: "Turn off to use only the external screens"
    checked: root.monitors.some(m => m.internal && m.enabled)
    onToggled: c => DisplayService.setInternal(c)
  }
  RowToggle {
    Layout.fillWidth: true
    visible: DisplayService.hasInternal && DisplayService.hasExternal && !DisplayService.editable
    last: true
    text: "Mirror the laptop screen"
    subtext: "Show the same picture on the external screen"
    checked: root.monitors.some(m => !!m.mirrorOf)
    onToggled: c => DisplayService.setMirror(c)
  }

  // ---- everything else, one sub-page each (SettingsModel.js display*)
  SectionHeader { row: ({ text: "More" }) }
  Repeater {
    model: [
      { icon: "bookmarks", label: "Profiles", page: "displayProfiles", status: "fn:profiles", managed: true },
      { icon: "space_dashboard", label: "Workspaces", page: "displayWorkspaces", status: "fn:workspaces", managed: true },
      { icon: "brightness_6", label: "Brightness", page: "displayBrightness", status: "fn:brightness" },
      { icon: "nightlight", label: "Night light", page: "displayNight", status: "fn:night" },
      { icon: "dock_to_bottom", label: "Shell on each screen", page: "displayShell", status: "fn:shell" },
      { icon: "format_size", label: "Text and cursor", page: "displayText", status: "fn:text" }
    ].filter(r => !r.managed || DisplayService.editable)
    RowNav {
      required property var modelData
      required property int index
      Layout.fillWidth: true
      row: modelData
      settings: root.settings
      first: index === 0
      last: index === (DisplayService.editable ? 5 : 3)
    }
  }
}
