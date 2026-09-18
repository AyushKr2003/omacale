import QtQuick
import QtQuick.Layouts

// Caelestia dashboard "Weather" tab: city and date with sunrise/sunset, a
// big current-conditions pill, three detail cards, and a 7-day forecast.
Item {
  id: root
  property bool active: false
  onActiveChanged: if (active && Sys.forecast.length === 0) Sys.weatherProbe.running = true

  implicitWidth: Math.max(840, layout.implicitWidth)
  implicitHeight: layout.implicitHeight

  ColumnLayout {
    id: layout
    anchors.fill: parent
    spacing: Tk.spacing.medium

    RowLayout {
      Layout.leftMargin: Tk.padding.large
      Layout.rightMargin: Tk.padding.large
      Layout.fillWidth: true
      Column {
        spacing: Tk.spacing.extraSmall
        MText { text: Sys.city || "Loading..."; font.pointSize: 28; weight: Font.DemiBold }
        MText { text: new Date().toLocaleDateString(Qt.locale(), "dddd, MMMM d"); color: Colours.m3onSurfaceVariant }
      }
      Item { Layout.fillWidth: true }
      Row {
        spacing: Tk.spacing.largeIncreased
        Stat { icon: "wb_twilight"; label: "Sunrise"; value: Sys.sunrise }
        Stat { icon: "bedtime"; label: "Sunset"; value: Sys.sunset }
      }
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: big.implicitHeight + Tk.padding.small
      radius: Tk.rounding.extraLarge * 2
      color: Colours.m3surfaceContainer
      RowLayout {
        id: big
        anchors.centerIn: parent
        spacing: Tk.spacing.largeIncreased
        MIcon { Layout.alignment: Qt.AlignVCenter; text: Sys.weatherIcon; size: Tk.iconSize.extraLarge * 3; color: Colours.m3secondary; animate: true }
        ColumnLayout {
          Layout.alignment: Qt.AlignVCenter
          spacing: -Tk.spacing.small
          MText { text: Sys.temp; font.pointSize: 28 * 2; weight: Font.Medium; color: Colours.m3primary }
          MText { Layout.leftMargin: Tk.padding.extraSmall; text: Sys.weatherDesc; font.pointSize: Tk.body.medium; color: Colours.m3onSurfaceVariant }
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Tk.spacing.medium
      Detail { icon: "water_drop"; label: "Humidity"; value: Sys.humidity + "%"; colour: Colours.m3secondary }
      Detail { icon: "thermostat"; label: "Feels like"; value: Sys.feelsLike; colour: Colours.m3primary }
      Detail { icon: "air"; label: "Wind"; value: Sys.windSpeed ? Sys.windSpeed + (Sys.imperial ? " mph" : " km/h") : "--"; colour: Colours.m3tertiary }
    }

    MText {
      Layout.topMargin: Tk.spacing.medium
      Layout.leftMargin: Tk.padding.medium
      visible: Sys.forecast.length > 0
      text: "7-day forecast"
      font.pointSize: Tk.body.medium
      weight: Font.DemiBold
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Tk.spacing.medium
      Repeater {
        model: Sys.forecast
        Rectangle {
          id: day
          required property int index
          required property var modelData
          readonly property date d: new Date(modelData.date + "T12:00:00")
          Layout.fillWidth: true
          implicitHeight: dayCol.implicitHeight + Tk.padding.medium * 2
          radius: Tk.rounding.large
          color: Colours.m3surfaceContainer
          ColumnLayout {
            id: dayCol
            anchors.centerIn: parent
            spacing: Tk.spacing.small
            MText { Layout.alignment: Qt.AlignHCenter; text: day.index === 0 ? "Today" : day.d.toLocaleDateString(Qt.locale(), "ddd"); font.pointSize: Tk.body.medium; weight: Font.DemiBold; color: Colours.m3primary }
            MText { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: -Tk.spacing.extraSmall; text: day.d.toLocaleDateString(Qt.locale(), "MMM d"); opacity: 0.7; color: Colours.m3onSurfaceVariant }
            MIcon { Layout.alignment: Qt.AlignHCenter; text: Sys.weatherIconFor(day.modelData.code, 1); size: Tk.iconSize.extraLarge; color: Colours.m3secondary }
            MText { Layout.alignment: Qt.AlignHCenter; text: Math.round(day.modelData.min) + "° / " + Math.round(day.modelData.max) + "°"; weight: Font.DemiBold; color: Colours.m3tertiary }
          }
        }
      }
    }
  }

  component Detail: Rectangle {
    id: det
    property string icon
    property string label
    property string value
    property color colour
    Layout.fillWidth: true
    Layout.preferredHeight: 60
    radius: Tk.rounding.medium
    color: Colours.m3surfaceContainer
    Row {
      anchors.centerIn: parent
      spacing: Tk.spacing.medium
      MIcon { anchors.verticalCenter: parent.verticalCenter; text: det.icon; color: det.colour; size: Tk.iconSize.large }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        MText { text: det.label; opacity: 0.7 }
        MText { text: det.value; weight: Font.DemiBold }
      }
    }
  }

  component Stat: Row {
    id: st
    property string icon
    property string label
    property string value
    spacing: Tk.spacing.small
    MIcon { text: st.icon; size: Tk.iconSize.extraLarge; color: Colours.m3tertiary }
    Column {
      anchors.verticalCenter: parent.verticalCenter
      MText { text: st.label; color: Colours.m3onSurfaceVariant }
      MText { text: st.value; weight: Font.DemiBold }
    }
  }
}
