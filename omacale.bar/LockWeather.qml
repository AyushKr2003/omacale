import QtQuick
import QtQuick.Layouts

// The weather card at the top left of the lock (Caelestia lock/WeatherInfo.qml
// with its weather/BriefInfo.qml and weather/Forecast.qml). Conditions, the
// temperature and the icon always; feels-like and today's high/low on a taller
// screen; the daily forecast only on a very tall one, as Caelestia does.
//
// Omacale's forecast is Open-Meteo's daily one (Sys.forecast), not Caelestia's
// hourly, so the row reads as days.
Rectangle {
  id: root

  required property real rootHeight

  readonly property bool showDetails: rootHeight > Tk.sizes.lockWeatherDetailsHeight
  readonly property bool showForecast: rootHeight >= Tk.sizes.lockForecastHeight

  implicitHeight: {
    const base = brief.implicitHeight + Tk.padding.extraLarge
    if (showForecast)
      return base + Tk.spacing.largeIncreased + forecast.implicitHeight + Tk.padding.large * 2
    return base + Tk.padding.extraLarge
  }
  radius: Tk.rounding.extraExtraLarge
  color: Colours.m3surfaceContainer

  // The lock is often the first thing on screen after a resume, so ask for a
  // refresh when it appears and keep Caelestia's 15 minute beat after that.
  Component.onCompleted: Sys.weatherProbe.running = true
  Timer {
    running: true
    repeat: true
    interval: 900000
    onTriggered: Sys.weatherProbe.running = true
  }

  ColumnLayout {
    id: brief

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: Tk.padding.extraLarge

    spacing: Tk.spacing.extraSmall

    MText {
      Layout.alignment: Qt.AlignHCenter
      animate: true
      text: Sys.weatherDesc
      color: Colours.m3onSurfaceVariant
      font.pointSize: Tk.body.large
    }

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: Tk.spacing.medium

      MText {
        animate: true
        text: Sys.temp
        color: Colours.m3primary
        font.pointSize: Tk.headline.large * 1.5
        weight: Font.DemiBold
        axes: ({ "ROND": 25, "wdth": 80 })
      }

      MIcon {
        animate: true
        text: Sys.weatherIcon
        color: Colours.m3secondary
        size: Tk.headline.large * 1.5
      }
    }

    MText {
      Layout.alignment: Qt.AlignHCenter
      visible: root.showDetails
      animate: true
      text: `Feels like ${Sys.feelsLike}`
      color: Colours.m3onSurfaceVariant
      font.pointSize: Tk.body.large
    }

    MText {
      Layout.alignment: Qt.AlignHCenter
      visible: root.showDetails
      animate: true
      text: {
        const today = Sys.forecast[0]
        if (!today)
          return " "
        return `High ${Sys.fmtTemp(today.max)} • Low ${Sys.fmtTemp(today.min)}`
      }
      color: Colours.m3onSurfaceVariant
      font.pointSize: Tk.body.medium
    }
  }

  Loader {
    id: forecast

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: Tk.padding.large

    active: root.showForecast
    asynchronous: true

    sourceComponent: Rectangle {
      color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
      radius: Tk.rounding.extraLargeIncreased
      implicitHeight: header.implicitHeight + Tk.spacing.medium + days.implicitHeight + Tk.padding.largeIncreased * 2

      RowLayout {
        id: header

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Tk.padding.largeIncreased

        spacing: Tk.spacing.small

        MIcon {
          text: "calendar_month"
          size: Tk.iconSize.medium
          weight: Font.Medium
        }

        MText {
          text: "Forecast"
          font.pointSize: Tk.title.medium
          weight: Font.Medium
        }
      }

      RowLayout {
        id: days

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tk.padding.largeIncreased
        anchors.margins: Tk.padding.large

        spacing: Tk.spacing.small

        Repeater {
          model: Math.max(0, Math.min(Math.floor((days.width + days.spacing) / (Tk.sizes.lockForecastItemWidth + days.spacing)), Sys.forecast.length))

          ColumnLayout {
            id: day

            required property int index
            readonly property var cond: Sys.forecast[index]

            Layout.fillWidth: true
            spacing: Tk.spacing.extraSmall

            MShape {
              Layout.alignment: Qt.AlignHCenter
              implicitSize: temp.implicitHeight + Tk.padding.medium * 2
              shape: "cookie4"
              color: Qt.alpha(Colours.m3primary, day.index === 0 ? 1 : 0)

              MText {
                id: temp

                anchors.centerIn: parent
                text: Sys.fmtTemp(day.cond.max).replace(/°[CF]$/, "°")
                color: day.index === 0 ? Colours.m3onPrimary : Colours.m3onSurface
                font.pointSize: Tk.title.medium
                weight: Font.Medium
              }
            }

            MIcon {
              Layout.alignment: Qt.AlignHCenter
              text: Sys.weatherIconFor(day.cond.code, 1)
              color: Colours.m3secondary
              size: Tk.iconSize.large
            }

            MText {
              Layout.topMargin: Tk.spacing.extraSmall
              Layout.alignment: Qt.AlignHCenter
              text: day.index === 0 ? "Today" : Qt.formatDateTime(new Date(day.cond.date + "T12:00:00"), "ddd")
              color: Colours.m3onSurfaceVariant
              font.pointSize: Tk.body.medium
            }
          }
        }
      }
    }
  }
}
