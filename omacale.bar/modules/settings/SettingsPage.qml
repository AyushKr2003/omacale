import QtQuick
import QtQuick.Layouts
import "../.."

// Caelestia PageBase: title (with a back button on sub-pages) above a
// scrolling column of rows capped at 800px and centred, fading at the edges.
ColumnLayout {
  id: root
  property var page
  property var settings
  property bool isSub: false
  readonly property var rows: page ? page.rows : []
  spacing: Tk.spacing.extraLargeIncreased

  function groupable(r) { return r.type !== "section" && (r.type !== "custom" || r.comp === "seeds" || r.comp === "logoPicker") }
  function isFirst(i) { return i === 0 || !groupable(rows[i - 1]) }
  function isLast(i) { return i === rows.length - 1 || !groupable(rows[i + 1]) }
  readonly property var files: ({
    toggle: "rows/RowToggle.qml", stepper: "rows/RowStepper.qml", slider: "rows/RowSlider.qml", select: "rows/RowSelect.qml",
    text: "rows/RowText.qml", nav: "rows/RowNav.qml", section: "../../components/SectionHeader.qml",
    preview: "cards/StylePreview.qml", seeds: "cards/SeedPicker.qml", logoPicker: "cards/LogoPicker.qml", keybinds: "cards/KeybindsCard.qml", lock: "cards/LockCard.qml", notifs: "cards/NotifCard.qml", looknfeel: "cards/LookNFeelCard.qml", about: "cards/AboutCard.qml",
    network: "pages/NetworkPage.qml", networkDetail: "pages/NetworkDetail.qml",
    bluetooth: "pages/BluetoothPage.qml", btPair: "pages/BtPairing.qml", btDevice: "pages/BtDevice.qml",
    audio: "pages/AudioPage.qml", appVolumes: "pages/AppVolumes.qml",
    wallpapers: "pages/WallpaperGrid.qml", apps: "pages/AppsPage.qml", allApps: "pages/AllApps.qml", appInfo: "pages/AppInfo.qml",
    plugins: "pages/PluginsPage.qml", pluginInfo: "pages/PluginInfo.qml",
    trayIcons: "pages/TrayIcons.qml", barPlugins: "pages/PinnedPlugins.qml"
  })

  RowLayout {
    Layout.fillWidth: true
    spacing: Tk.spacing.largeIncreased
    IconButton {
      visible: root.isSub
      type: "tonal"
      icon: "arrow_back"
      inactiveColour: Colours.m3surfaceContainerHigh
      inactiveOnColour: Colours.m3onSurfaceVariant
      onClicked: root.settings.back()
    }
    MText {
      Layout.fillWidth: true
      text: root.page ? (root.page.title || root.page.label) : ""
      font.pointSize: Tk.title.large
      weight: Font.Medium
      elide: Text.ElideRight
    }
  }

  FadeFlickable {
    id: flick
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.topMargin: -topMargin
    topMargin: Tk.padding.large
    bottomMargin: Tk.padding.extraLarge
    contentHeight: col.implicitHeight

    ColumnLayout {
      id: col
      x: (flick.width - width) / 2
      width: Math.min(800, flick.width)
      spacing: Tk.spacing.extraSmall / 2

      Repeater {
        model: root.rows
        Loader {
          required property var modelData
          required property int index
          readonly property bool live: !modelData.when || Config.get(modelData.when.key) === modelData.when.value
          Layout.fillWidth: true
          enabled: live
          opacity: live ? 1 : 0.38
          Behavior on opacity { Anim { type: "effects" } }
          Component.onCompleted: {
            const f = root.files[modelData.type === "custom" ? modelData.comp : modelData.type]
            if (f) setSource(Qt.resolvedUrl(f), { row: modelData, settings: root.settings, first: root.isFirst(index), last: root.isLast(index) })
          }
        }
      }

      // Empty search state
      ColumnLayout {
        visible: root.page && root.page.id === "__search" && root.rows.length === 0
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Tk.spacing.extraLargeIncreased
        spacing: Tk.spacing.small
        MIcon { Layout.alignment: Qt.AlignHCenter; text: "manage_search"; size: Tk.iconSize.extraLarge * 1.3; color: Colours.m3onSurfaceVariant }
        MText { Layout.alignment: Qt.AlignHCenter; text: "No matching settings"; font.pointSize: Tk.body.large; weight: Font.Medium; color: Colours.m3onSurfaceVariant }
        MText { Layout.alignment: Qt.AlignHCenter; text: "Try another word, like “blur” or “clock”"; color: Colours.m3outline }
      }
    }
  }
}
