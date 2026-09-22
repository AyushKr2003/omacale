import QtQuick
import QtQuick.Layouts

// Settings › Plugins. No Caelestia original (Caelestia has no plugins); the
// layout follows Shibumi's plugin catalog -- summary with add / update,
// filter and search, then third-party and built-in lists with an enable
// switch each -- drawn with Nexus rows. Data and actions: PluginService.
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  property string filter: "all"      // all | enabled | third | builtin
  property string query: ""
  property bool adding: false

  readonly property var all: PluginService.plugins
  readonly property var shown: all.filter(p => {
    if (filter === "enabled" && !p.enabled) return false
    if (filter === "third" && p.firstParty) return false
    if (filter === "builtin" && !p.firstParty) return false
    const q = query.trim().toLowerCase()
    if (!q) return true
    return (p.name + " " + p.id + " " + p.description + " " + p.category).toLowerCase().indexOf(q) >= 0
  })
  readonly property var thirdParty: shown.filter(p => !p.firstParty)
  readonly property var builtIn: shown.filter(p => p.firstParty)
  readonly property int enabledCount: all.filter(p => p.enabled).length
  readonly property int thirdCount: all.filter(p => !p.firstParty).length

  function kindIcon(p) {
    if (p.isBar) return "dock_to_bottom"
    if (p.kinds.indexOf("bar-widget") >= 0) return "widgets"
    if (p.kinds.indexOf("overlay") >= 0 || p.kinds.indexOf("panel") >= 0) return "web_asset"
    if (p.kinds.indexOf("service") >= 0) return "settings_suggest"
    return "extension"
  }
  function subtitle(p) {
    if (p.managed) return "Managed by Omacale · " + (p.clonedFrom === "omarchy.lock" ? "Panels › Lock screen" : "Services › Notifications")
    if (p.isBar) return p.active ? "The bar in use" : "Bar · pick it with omarchy bar"
    return p.description || p.id
  }

  spacing: Tk.spacing.extraSmall / 2
  Component.onCompleted: PluginService.refresh()

  // ------------------------------------------------------------- summary
  ConnectedRect {
    Layout.fillWidth: true
    first: true
    last: !root.adding
    implicitHeight: sr.implicitHeight + Tk.padding.large * 2
    RowLayout {
      id: sr
      anchors.fill: parent
      anchors.margins: Tk.padding.large
      anchors.leftMargin: Tk.padding.largeIncreased
      spacing: Tk.spacing.large
      MIcon { text: "extension"; size: Tk.iconSize.large; color: Colours.m3primary; fill: 1 }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        MText { text: "Omarchy plugins"; font.pointSize: Tk.body.large; weight: Font.Medium }
        MText {
          Layout.fillWidth: true
          text: PluginService.loaded
            ? root.all.length + " installed · " + root.enabledCount + " enabled · " + root.thirdCount + " third-party"
            : "Reading plugins…"
          color: Colours.m3outline
          font.pointSize: Tk.label.medium
          elide: Text.ElideRight
        }
      }
      IconButton {
        icon: "refresh"
        type: "text"
        disabled: PluginService.loading
        onClicked: PluginService.refresh()
      }
      IconTextButton {
        icon: "update"
        text: "Update"
        type: "tonal"
        horizontalPadding: Tk.padding.large
        verticalPadding: Tk.padding.small
        disabled: root.thirdCount === 0
        onClicked: PluginService.update("")
      }
      IconTextButton {
        icon: root.adding ? "close" : "add"
        text: root.adding ? "Cancel" : "Add"
        type: root.adding ? "tonal" : "filled"
        horizontalPadding: Tk.padding.large
        verticalPadding: Tk.padding.small
        onClicked: root.adding = !root.adding
      }
    }
  }

  // Add from git: `omarchy plugin add <url> --enable --yes`.
  ConnectedRect {
    Layout.fillWidth: true
    visible: root.adding
    last: true
    implicitHeight: ar.implicitHeight + Tk.padding.large * 2
    ColumnLayout {
      id: ar
      anchors.fill: parent
      anchors.margins: Tk.padding.large
      spacing: Tk.spacing.medium
      RowLayout {
        Layout.fillWidth: true
        spacing: Tk.spacing.medium
        OutlinedField {
          id: urlField
          Layout.fillWidth: true
          placeholderText: "Git URL, e.g. https://github.com/user/omarchy-plugin"
          onAccepted: if (text.trim()) { PluginService.add(text, enableNew.checked); root.adding = false }
        }
        IconTextButton {
          icon: "download"
          text: "Install"
          horizontalPadding: Tk.padding.large
          verticalPadding: Tk.padding.small
          disabled: urlField.text.trim() === ""
          onClicked: { PluginService.add(urlField.text, enableNew.checked); root.adding = false }
        }
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: Tk.spacing.medium
        MText {
          Layout.fillWidth: true
          text: "Enable after installing. The shell reloads its plugins, so Settings closes and comes back here."
          color: Colours.m3outline
          font.pointSize: Tk.label.medium
          wrapMode: Text.WordWrap
        }
        MSwitch { id: enableNew; checked: true; onToggled: c => checked = c }
      }
    }
  }

  // Last error from omarchy plugin, until the next action.
  ConnectedRect {
    Layout.fillWidth: true
    Layout.topMargin: Tk.spacing.small
    visible: PluginService.error !== ""
    first: true
    last: true
    color: Colours.m3errorContainer
    implicitHeight: er.implicitHeight + Tk.padding.medium * 2
    RowLayout {
      id: er
      anchors.fill: parent
      anchors.margins: Tk.padding.medium
      anchors.leftMargin: Tk.padding.largeIncreased
      spacing: Tk.spacing.medium
      MIcon { text: "error"; color: Colours.m3onErrorContainer }
      MText { Layout.fillWidth: true; text: PluginService.error; color: Colours.m3onErrorContainer; wrapMode: Text.WordWrap }
      IconButton { icon: "close"; type: "text"; inactiveOnColour: Colours.m3onErrorContainer; onClicked: PluginService.error = "" }
    }
  }

  // ------------------------------------------------------ filter + search
  RowLayout {
    Layout.fillWidth: true
    Layout.topMargin: Tk.spacing.large
    spacing: Tk.spacing.small
    Repeater {
      model: [
        { id: "all", label: "All", icon: "apps" },
        { id: "enabled", label: "Enabled", icon: "toggle_on" },
        { id: "third", label: "Third-party", icon: "extension" },
        { id: "builtin", label: "Built-in", icon: "inventory_2" }
      ]
      IconTextButton {
        required property var modelData
        icon: modelData.icon
        text: modelData.label
        type: root.filter === modelData.id ? "filled" : "tonal"
        fontSize: Tk.label.large
        horizontalPadding: Tk.padding.medium
        verticalPadding: Tk.padding.small
        onClicked: root.filter = modelData.id
      }
    }
    Item { Layout.fillWidth: true }
  }
  Rectangle {
    Layout.fillWidth: true
    Layout.topMargin: Tk.spacing.small
    implicitHeight: search.implicitHeight + Tk.padding.medium * 2
    radius: height / 2
    color: Colours.m3surfaceContainerLowest
    border.width: 1
    border.color: Colours.m3outlineVariant
    MIcon {
      id: sIcon
      anchors.left: parent.left
      anchors.leftMargin: Tk.padding.largeIncreased
      anchors.verticalCenter: parent.verticalCenter
      text: "search"
      color: Colours.m3onSurfaceVariant
    }
    MTextField {
      id: search
      anchors.left: sIcon.right
      anchors.leftMargin: Tk.spacing.medium
      anchors.right: parent.right
      anchors.rightMargin: Tk.padding.largeIncreased
      anchors.verticalCenter: parent.verticalCenter
      clip: true
      onTextChanged: root.query = text
      MText {
        anchors.verticalCenter: parent.verticalCenter
        visible: !search.text
        text: "Search plugins"
        color: Colours.m3onSurfaceVariant
      }
    }
  }

  // ---------------------------------------------------------------- lists
  component PluginRow: ConnectedRect {
    id: pr
    required property var modelData
    required property int index
    property int count
    Layout.fillWidth: true
    first: index === 0
    last: index === count - 1
    implicitHeight: rl.implicitHeight + Tk.padding.medium * 2

    StateLayer {
      onClicked: { root.settings.selectedPlugin = pr.modelData.id; root.settings.push("pluginInfo") }
    }
    RowLayout {
      id: rl
      anchors.fill: parent
      anchors.margins: Tk.padding.medium
      anchors.leftMargin: Tk.padding.largeIncreased
      anchors.rightMargin: Tk.padding.largeIncreased
      spacing: Tk.spacing.medium
      MIcon {
        text: root.kindIcon(pr.modelData)
        size: Tk.iconSize.medium
        color: pr.modelData.enabled ? Colours.m3primary : Colours.m3outline
        fill: pr.modelData.enabled ? 1 : 0
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        MText { Layout.fillWidth: true; text: pr.modelData.name; elide: Text.ElideRight }
        MText {
          Layout.fillWidth: true
          text: root.subtitle(pr.modelData)
          color: Colours.m3outline
          font.pointSize: Tk.label.small
          elide: Text.ElideRight
        }
      }
      LoadingIndicator {
        visible: PluginService.busyId === pr.modelData.id
        implicitSize: Tk.iconSize.medium
      }
      MSwitch {
        visible: !pr.modelData.isBar
        checked: pr.modelData.enabled
        disabled: !pr.modelData.toggleable || PluginService.busyId !== ""
        onToggled: c => PluginService.setEnabled(pr.modelData.id, c)
      }
      MIcon { text: "chevron_right"; size: Tk.iconSize.medium; color: Colours.m3onSurfaceVariant }
    }
  }

  SectionHeader {
    visible: root.thirdParty.length > 0
    row: ({ text: "Third-party · " + root.thirdParty.length })
  }
  Repeater {
    id: thirdRep
    model: root.thirdParty
    PluginRow { count: thirdRep.count }
  }

  SectionHeader {
    visible: root.builtIn.length > 0
    row: ({ text: "Built-in · " + root.builtIn.length })
  }
  Repeater {
    id: builtRep
    model: root.builtIn
    PluginRow { count: builtRep.count }
  }

  ColumnLayout {
    visible: PluginService.loaded && root.shown.length === 0
    Layout.alignment: Qt.AlignHCenter
    Layout.topMargin: Tk.spacing.extraLargeIncreased
    spacing: Tk.spacing.small
    MIcon { Layout.alignment: Qt.AlignHCenter; text: "extension_off"; size: Tk.iconSize.extraLarge; color: Colours.m3onSurfaceVariant }
    MText { Layout.alignment: Qt.AlignHCenter; text: "No matching plugins"; font.pointSize: Tk.body.large; weight: Font.Medium; color: Colours.m3onSurfaceVariant }
  }
}
