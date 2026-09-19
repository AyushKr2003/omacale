import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

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
    toggle: "RowToggle.qml", stepper: "RowStepper.qml", slider: "RowSlider.qml", select: "RowSelect.qml",
    text: "RowText.qml", nav: "RowNav.qml", section: "SectionHeader.qml",
    preview: "StylePreview.qml", seeds: "SeedPicker.qml", logoPicker: "LogoPicker.qml", keybinds: "KeybindsCard.qml", looknfeel: "LookNFeelCard.qml", about: "AboutCard.qml",
    network: "NetworkPage.qml", networkDetail: "NetworkDetail.qml",
    bluetooth: "BluetoothPage.qml", btPair: "BtPairing.qml", btDevice: "BtDevice.qml"
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

  Item {
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.topMargin: -Tk.padding.large

    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: fadeMask
      maskThresholdMin: 0
      maskSpreadAtMin: 0
    }
    Item {
      id: fadeMask
      anchors.fill: parent
      visible: false
      layer.enabled: true
      Rectangle {
        anchors.fill: parent
        gradient: Gradient {
          GradientStop { position: 0; color: flick.atYBeginning ? "white" : "transparent" }
          GradientStop { position: Math.min(0.5, 24 / Math.max(1, fadeMask.height)); color: "white" }
          GradientStop { position: 1 - Math.min(0.5, 32 / Math.max(1, fadeMask.height)); color: "white" }
          GradientStop { position: 1; color: flick.atYEnd ? "white" : "transparent" }
        }
      }
    }

    Flickable {
      id: flick
      anchors.fill: parent
      topMargin: Tk.padding.large
      bottomMargin: Tk.padding.extraLarge
      contentHeight: col.implicitHeight
      boundsBehavior: Flickable.StopAtBounds
      clip: true

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
}
