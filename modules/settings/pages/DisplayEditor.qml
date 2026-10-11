import QtQuick
import QtQuick.Layouts
import "../../.."
import "../../../services/DisplayModel.js" as Model

// Settings › Display: the selected display's settings, when hyprmoncfg's
// editor is there. Each change is an edit_profile on DisplayService's draft
// (nothing reaches the screen until Apply). Options are hyprmoncfg's own:
// the modes the display reports, its sharp scales, and the values its Omarchy
// panel offers for VRR, bit depth and colour (crmne.hyprmoncfg/Panel.qml).
ColumnLayout {
  id: root
  property var sel
  property var monitors: []
  property var settings
  property bool last: true
  spacing: Tk.spacing.extraSmall / 2

  readonly property string key: sel ? sel.key : ""
  readonly property var groups: sel ? Model.modeGroups(sel.modes) : []
  readonly property var curMode: sel ? (/^(\d+x\d+)@/.exec(sel.mode) || [])[1] || (sel.width + "x" + sel.height) : ""
  readonly property real recommended: sel ? Model.recommendedScale(sel) : 1
  function set(fields) { DisplayService.edit(root.key, fields) }

  ConnectedRect {
    Layout.fillWidth: true
    first: true
    implicitHeight: ml.implicitHeight + Tk.padding.medium * 2
    RowLayout {
      id: ml
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.largeIncreased
      MText { Layout.fillWidth: true; text: "Model" }
      MText { Layout.maximumWidth: parent.width * 0.6; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; text: root.sel ? root.sel.label : ""; color: Colours.m3onSurfaceVariant }
    }
  }
  // ---- details (collapsed): what the display is, from hyprmoncfg and Hyprland
  property bool details: false
  readonly property var info: sel ? (DisplayService.hyprInfo[sel.name] || {}) : ({})
  readonly property real wmm: sel ? (sel.physicalWidth || info.physicalWidth || 0) : 0
  readonly property real hmm: info.physicalHeight || 0
  ConnectedRect {
    Layout.fillWidth: true
    implicitHeight: dl.implicitHeight + Tk.padding.medium * 2
    RowLayout {
      id: dl
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.medium
      MText { Layout.fillWidth: true; text: "Details" }
      MIcon { text: root.details ? "expand_less" : "expand_more"; color: Colours.m3onSurfaceVariant }
    }
    StateLayer { onClicked: root.details = !root.details }
  }
  Repeater {
    model: root.details && root.sel ? [
      { label: "Connector", value: root.sel.name + (root.sel.internal ? " (built in)" : "") },
      { label: "Serial", value: root.info.serial || "–" },
      { label: "Size", value: root.wmm && root.hmm ? Model.diagonalInches(root.wmm, root.hmm) + "″ · " + root.wmm + " × " + root.hmm + " mm" : "–" },
      { label: "Pixel density", value: root.wmm ? Model.ppi(root.sel.width, root.wmm) + " ppi" : "–" },
      { label: "Colour format", value: root.info.format || "–" },
      { label: "Workspace", value: root.info.workspace || "–" },
      { label: "Mirrored by", value: root.monitors.filter(m => m.mirrorOf === root.key || m.mirrorOf === root.sel.name).map(m => m.name).join(", ") || "–" }
    ] : []
    ConnectedRect {
      required property var modelData
      Layout.fillWidth: true
      implicitHeight: dr.implicitHeight + Tk.padding.small * 2
      RowLayout {
        id: dr
        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tk.padding.largeIncreased * 2; anchors.rightMargin: Tk.padding.largeIncreased
        MText { Layout.fillWidth: true; text: modelData.label; color: Colours.m3onSurfaceVariant; font.pointSize: Tk.body.small }
        MText { text: modelData.value; font.pointSize: Tk.body.small; color: Colours.m3onSurfaceVariant }
      }
    }
  }
  RowToggle {
    Layout.fillWidth: true
    text: "Use this screen"
    subtext: root.sel && !Model.canDisable(root.monitors, root.key) ? "The only screen in use can't be turned off" : ""
    checked: !!root.sel && root.sel.enabled
    disabled: !!root.sel && root.sel.enabled && !Model.canDisable(root.monitors, root.key)
    onToggled: c => root.set({ enabled: c })
  }
  RowSelect {
    Layout.fillWidth: true
    visible: !!root.sel && root.sel.enabled && root.groups.length > 0
    settings: root.settings
    row: ({ label: "Resolution", icon: "aspect_ratio", options: root.groups.map(g => ({ value: g.res, label: g.w + " × " + g.h })) })
    value: root.curMode
    onPicked: v => root.set({ mode: Model.modeFor(root.sel.modes, v, root.sel.refresh) })
  }
  RowSelect {
    Layout.fillWidth: true
    readonly property var group: root.groups.find(g => g.res === root.curMode)
    visible: !!root.sel && root.sel.enabled && !!group
    settings: root.settings
    row: ({ label: "Refresh rate", icon: "speed", options: group ? group.rates.map(r => ({ value: r.mode, label: Model.refreshLabel(r.hz) })) : [] })
    value: root.sel ? root.sel.mode || "" : ""
    onPicked: v => root.set({ mode: v })
  }
  RowSelect {
    Layout.fillWidth: true
    visible: !!root.sel && root.sel.enabled
    settings: root.settings
    // Every sharp scale, plus the current one if it isn't (Model.js's
    // scaleOptions in hyprmoncfg's plugin does the same).
    readonly property var values: {
      if (!root.sel) return []
      const v = (root.sel.scaleOptions || []).slice()
      if (!v.some(x => Math.abs(x - root.sel.scale) < 1e-4)) v.push(root.sel.scale)
      return v.sort((a, b) => a - b)
    }
    row: ({
      label: "Scale", icon: "zoom_in",
      subtext: root.sel ? root.sel.lw + " × " + root.sel.lh + " logical · recommended " + Model.scaleLabel(root.recommended) : "",
      options: values.map(x => ({ value: String(x), label: Model.scaleLabel(x) + (Math.abs(x - root.recommended) < 1e-4 ? " · recommended" : "") }))
    })
    value: root.sel ? String(values.find(x => Math.abs(x - root.sel.scale) < 1e-4) ?? root.sel.scale) : ""
    onPicked: v => root.set({ scale: Number(v) })
  }
  RowSelect {
    Layout.fillWidth: true
    visible: !!root.sel && root.sel.enabled
    settings: root.settings
    row: ({ label: "Rotation", icon: "screen_rotation", options: [
      { value: "0", label: "Normal" }, { value: "1", label: "90°" }, { value: "2", label: "180°" }, { value: "3", label: "270°" }
    ] })
    value: root.sel ? String(Model.rotationOf(root.sel.transform)) : "0"
    onPicked: v => root.set({ transform: Model.transformOf(Number(v), Model.flippedOf(root.sel.transform)) })
  }
  RowToggle {
    Layout.fillWidth: true
    visible: !!root.sel && root.sel.enabled
    text: "Flipped"
    subtext: "Mirror the picture left to right"
    checked: !!root.sel && Model.flippedOf(root.sel.transform)
    onToggled: c => root.set({ transform: Model.transformOf(Model.rotationOf(root.sel.transform), c) })
  }
  RowSelect {
    Layout.fillWidth: true
    visible: !!root.sel && root.sel.enabled && root.monitors.length > 1
    settings: root.settings
    row: ({ label: "Mirror", icon: "screen_share", subtext: "Show another screen's picture here", options: [{ value: "", label: "Off" }].concat(
      root.monitors.filter(m => m.key !== root.key && m.enabled).map(m => ({ value: m.key, label: m.name }))) })
    value: root.sel ? root.sel.mirrorOf : ""
    onPicked: v => root.set(v ? { mirror_of: v } : Object.assign({ mirror_of: "" }, Model.unmirrorAt(root.monitors, root.key) || {}))
  }
  // ---- advanced (collapsed): variable refresh, colour, bit depth
  property bool advanced: false
  ConnectedRect {
    Layout.fillWidth: true
    visible: !!root.sel && root.sel.enabled
    last: root.last && !root.advanced
    implicitHeight: al.implicitHeight + Tk.padding.medium * 2
    RowLayout {
      id: al
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.largeIncreased; anchors.rightMargin: Tk.padding.medium
      MText { Layout.fillWidth: true; text: "Advanced" }
      MText { text: root.sel ? ["VRR " + (["off", "on", "fullscreen"][root.sel.vrr] || "off"), root.sel.cm || "srgb", root.sel.bitdepth + "-bit"].join(" · ") : ""; color: Colours.m3onSurfaceVariant; font.pointSize: Tk.body.small }
      MIcon { text: root.advanced ? "expand_less" : "expand_more"; color: Colours.m3onSurfaceVariant }
    }
    StateLayer { onClicked: root.advanced = !root.advanced }
  }
  RowSelect {
    Layout.fillWidth: true
    visible: !!root.sel && root.sel.enabled && root.advanced
    settings: root.settings
    row: ({ label: "Variable refresh rate", icon: "sync", options: [
      { value: "0", label: "Off" }, { value: "1", label: "On" }, { value: "2", label: "Fullscreen" }
    ] })
    value: root.sel ? String(root.sel.vrr) : "0"
    onPicked: v => root.set({ vrr: Number(v) })
  }
  RowSelect {
    Layout.fillWidth: true
    visible: !!root.sel && root.sel.enabled && root.advanced
    settings: root.settings
    row: ({ label: "Colour", icon: "palette", options: [
      { value: "srgb", label: "sRGB (SDR)" }, { value: "auto", label: "Automatic" }, { value: "wide", label: "BT.2020 (SDR)" },
      { value: "hdr", label: "HDR (BT.2020 + PQ)" }, { value: "hdredid", label: "HDR (EDID primaries)" }, { value: "dcip3", label: "DCI-P3" },
      { value: "dp3", label: "Display P3" }, { value: "adobe", label: "Adobe RGB" }, { value: "edid", label: "EDID primaries (SDR)" }
    ] })
    value: root.sel ? (root.sel.cm || "srgb") : "srgb"
    onPicked: v => root.set({ cm: v })
  }
  RowSelect {
    Layout.fillWidth: true
    visible: !!root.sel && root.sel.enabled && root.advanced
    last: root.last
    settings: root.settings
    row: ({ label: "Bit depth", icon: "gradient", options: [{ value: "8", label: "8-bit" }, { value: "10", label: "10-bit" }] })
    value: root.sel ? String(root.sel.bitdepth) : "8"
    onPicked: v => root.set({ bitdepth: Number(v) })
  }
}
