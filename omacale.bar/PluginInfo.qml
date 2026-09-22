import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Settings › Plugins › <plugin>. Laid out like AppInfo (Caelestia's nexus
// apps/AppInfo.qml): header, the switch, actions, details. Version, author
// and licence are read from the plugin's own manifest.json, which the
// catalog lists but `omarchy plugin list` doesn't carry.
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  readonly property var plugin: settings ? PluginService.byId(settings.selectedPlugin) : null
  property var manifest: ({})
  property bool confirmRemove: false

  FileView {
    path: root.plugin && root.plugin.manifestPath ? root.plugin.manifestPath : ""
    blockLoading: true
    onLoaded: { try { root.manifest = JSON.parse(text()) } catch (e) { root.manifest = {} } }
  }

  function author(m) {
    const a = m.author
    if (!a) return ""
    return typeof a === "string" ? a : (a.name || "")
  }

  spacing: Tk.spacing.extraSmall / 2

  RowLayout {
    Layout.fillWidth: true
    Layout.bottomMargin: Tk.spacing.large
    spacing: Tk.spacing.large
    MIcon {
      text: "extension"
      size: Tk.iconSize.extraLarge
      fill: root.plugin && root.plugin.enabled ? 1 : 0
      color: root.plugin && root.plugin.enabled ? Colours.m3primary : Colours.m3outline
    }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0
      MText {
        Layout.fillWidth: true
        text: root.plugin ? root.plugin.name : ""
        font.pointSize: Tk.title.large
        weight: Font.Medium
        elide: Text.ElideRight
      }
      MText {
        Layout.fillWidth: true
        visible: text !== ""
        text: root.plugin ? root.plugin.description : ""
        color: Colours.m3outline
        wrapMode: Text.WordWrap
      }
    }
  }

  RowToggle {
    Layout.fillWidth: true
    first: true
    last: true
    text: "Enabled"
    subtext: !root.plugin ? ""
      : root.plugin.managed ? "Managed by Omacale's " + (root.plugin.clonedFrom === "omarchy.lock" ? "lock screen" : "notification") + " handover"
      : root.plugin.isBar ? (root.plugin.active ? "This is the bar in use" : "A bar is picked with omarchy bar, not enabled")
      : !root.plugin.toggleable ? "Omarchy needs this plugin"
      : root.plugin.kinds.indexOf("bar-widget") >= 0 ? "Enabling places its widget in the bar"
      : "Load it in the shell"
    checked: !!root.plugin && root.plugin.enabled
    disabled: !root.plugin || !root.plugin.toggleable || PluginService.busyId !== ""
    onToggled: c => PluginService.setEnabled(root.plugin.id, c)
  }

  // Third-party only: update from git / remove (confirmed inline).
  SectionHeader { visible: !!root.plugin && !root.plugin.firstParty; row: ({ text: "Manage" }) }
  ConnectedRect {
    Layout.fillWidth: true
    visible: !!root.plugin && !root.plugin.firstParty
    first: true
    last: true
    implicitHeight: mr.implicitHeight + Tk.padding.medium * 2
    RowLayout {
      id: mr
      anchors.fill: parent
      anchors.margins: Tk.padding.medium
      anchors.leftMargin: Tk.padding.largeIncreased
      spacing: Tk.spacing.medium
      MText {
        Layout.fillWidth: true
        text: root.confirmRemove ? "Remove " + (root.plugin ? root.plugin.name : "") + "? Its folder is deleted."
          : "The shell reloads its plugins, so Settings closes and comes back here."
        color: root.confirmRemove ? Colours.m3error : Colours.m3outline
        font.pointSize: Tk.label.medium
        wrapMode: Text.WordWrap
      }
      IconTextButton {
        visible: !root.confirmRemove
        icon: "update"
        text: "Update"
        type: "tonal"
        horizontalPadding: Tk.padding.large
        verticalPadding: Tk.padding.small
        onClicked: PluginService.update(root.plugin.id)
      }
      IconTextButton {
        visible: root.confirmRemove
        icon: "close"
        text: "Cancel"
        type: "tonal"
        horizontalPadding: Tk.padding.large
        verticalPadding: Tk.padding.small
        onClicked: root.confirmRemove = false
      }
      IconTextButton {
        icon: "delete"
        text: root.confirmRemove ? "Remove" : "Remove…"
        type: root.confirmRemove ? "filled" : "tonal"
        disabled: !root.plugin || !root.plugin.removable
        horizontalPadding: Tk.padding.large
        verticalPadding: Tk.padding.small
        onClicked: {
          if (!root.confirmRemove) { root.confirmRemove = true; return }
          PluginService.remove(root.plugin.id)
          root.confirmRemove = false
        }
      }
    }
  }

  SectionHeader { row: ({ text: "Details" }) }
  Repeater {
    id: details
    model: root.plugin ? [
      ["ID", root.plugin.id],
      ["Source", root.plugin.firstParty ? "Built-in (Omarchy)" : "Third-party"],
      ["Kinds", root.plugin.kinds.join(", ")],
      ["Category", root.plugin.category],
      ["Version", root.manifest.version || ""],
      ["Author", root.author(root.manifest)],
      ["Licence", root.manifest.license || ""],
      ["Cloned from", root.plugin.clonedFrom],
      ["Folder", root.plugin.sourceDir]
    ].filter(d => d[1]) : []
    ConnectedRect {
      required property var modelData
      required property int index
      Layout.fillWidth: true
      first: index === 0
      last: index === details.count - 1
      implicitHeight: dr.implicitHeight + Tk.padding.medium * 2
      RowLayout {
        id: dr
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tk.padding.largeIncreased
        anchors.rightMargin: Tk.padding.largeIncreased
        spacing: Tk.spacing.large
        MText { text: modelData[0] }
        MText {
          Layout.fillWidth: true
          text: modelData[1]
          color: Colours.m3onSurfaceVariant
          horizontalAlignment: Text.AlignRight
          wrapMode: Text.WrapAnywhere
        }
      }
    }
  }
}
