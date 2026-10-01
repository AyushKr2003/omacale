import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../.."

// Settings › Audio › App volumes. Port of Caelestia's nexus
// pages/audio/AppVolumes.qml.
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  spacing: Tk.spacing.extraSmall / 2
  Component.onCompleted: AudioService.users++
  Component.onDestruction: AudioService.users--

  MText {
    Layout.fillWidth: true
    Layout.leftMargin: Tk.padding.small
    Layout.bottomMargin: Tk.spacing.medium
    text: "Adjust the volume of individual apps currently playing audio."
    color: Colours.m3outline
    wrapMode: Text.WordWrap
  }

  ItemList {
    id: streamList
    first: true
    last: true
    showList: true
    placeholderIcon: "music_off"
    placeholderText: "No apps playing audio"
    color: list.count === 0 ? Colours.m3surfaceContainer : "transparent"
    list.spacing: Tk.spacing.extraSmall / 2
    model: ScriptModel { values: AudioService.streams }

    delegate: AudioSlider {
      id: stream
      required property var modelData
      required property int index
      width: ListView.view ? ListView.view.width : 0
      first: index === 0
      last: index === streamList.list.count - 1
      icon: AudioService.volumeIcon(value, muted)
      label: AudioService.streamName(modelData)
      value: modelData && modelData.audio ? modelData.audio.volume : 0
      muted: !!(modelData && modelData.audio && modelData.audio.muted)
      onMoved: v => AudioService.setStreamVolume(stream.modelData, v)
    }
  }
}
