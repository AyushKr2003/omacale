import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// Settings › Apps › All apps. Port of Caelestia's nexus pages/apps/AllApps.qml.
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  spacing: Tk.spacing.extraSmall / 2

  Repeater {
    id: list
    model: AppService.entries.slice().sort((a, b) => a.name.localeCompare(b.name))

    ConnectedRect {
      id: app
      required property var modelData
      required property int index
      Layout.fillWidth: true
      first: index === 0
      last: index === list.count - 1
      implicitHeight: ar.implicitHeight + Tk.padding.medium * 2

      StateLayer {
        onClicked: { root.settings.selectedApp = app.modelData; root.settings.push("appInfo") }
      }
      RowLayout {
        id: ar
        anchors.fill: parent
        anchors.margins: Tk.padding.medium
        anchors.leftMargin: Tk.padding.largeIncreased
        anchors.rightMargin: Tk.padding.largeIncreased
        spacing: Tk.spacing.medium

        IconImage {
          asynchronous: true
          implicitSize: Math.round(Tk.iconSize.large * 1.8)
          source: Quickshell.iconPath(app.modelData.icon, "image-missing")
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0
          MText { Layout.fillWidth: true; text: app.modelData.name; elide: Text.ElideRight }
          MText {
            Layout.fillWidth: true
            visible: text !== ""
            text: app.modelData.comment || app.modelData.genericName || ""
            color: Colours.m3outline
            font.pointSize: Tk.label.small
            elide: Text.ElideRight
          }
        }
        MIcon {
          visible: Config.o.launcher.hiddenApps.indexOf(app.modelData.id) >= 0
          text: "visibility_off"
          color: Colours.m3outline
        }
        MIcon {
          visible: Config.o.launcher.favouriteApps.indexOf(app.modelData.id) >= 0
          text: "favorite"
          fill: 1
          color: Colours.m3primary
        }
        MIcon { text: "chevron_right"; size: Tk.iconSize.medium; color: Colours.m3onSurfaceVariant }
      }
    }
  }
}
