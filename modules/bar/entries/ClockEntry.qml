import QtQuick
import QtQuick.Layouts
import "../../.."

// Caelestia bar/components/Clock.qml (and Caelestia KDE's row form). The
// SystemClock lives in BarContent (bar.sysClock), shared by every screen's entry.
Rectangle {
  id: entry
  required property var bar
  Component.onCompleted: bar.registerEntry(entry)
  Component.onDestruction: bar.unregisterEntry(entry)
  property string entryId: "clock"
  readonly property bool shown: bar.cfg.clock.enabled
  visible: shown
  // The calendar icon's length along the bar, worked out whether or not it
  // is shown, so hiding it can't bring it straight back (see BarContent's budget).
  readonly property real calendarLen: bar.cfg.clock.enabled && bar.cfg.clock.showIcon ? (bar.vertical ? calIcon.implicitHeight + clockCol.spacing : calIconH.implicitWidth + clockRow.spacing) : 0
  Layout.alignment: bar.crossAlign
  readonly property real pad: bar.cfg.clock.background ? Tk.padding.medium : Tk.padding.extraSmall
  implicitWidth: bar.vertical ? Tk.barInner : clockRow.implicitWidth + pad * 2
  implicitHeight: bar.vertical ? clockCol.implicitHeight + pad * 2 : Tk.barInner
  radius: (bar.vertical ? width : height) / 2
  color: bar.cfg.clock.background ? Colours.m3surfaceContainer : "transparent"
  readonly property bool h12: Sys.h12
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: e => {
      if (e.button === Qt.RightButton) bar.host.toggle("sidebar")
      else bar.host.toggle("dashboard")
    }
  }
  // Caelestia bar/components/Clock.qml: body.small x1.1 digits, squeezed
  // or stretched on the width axis so hours and minutes line up.
  // Caelestia KDE's horizontal clock (bar/components/Clock.qml): the icon,
  // the date, then hours:minutes on one line.
  RowLayout {
    id: clockRow
    anchors.centerIn: parent
    visible: !bar.vertical
    spacing: Tk.spacing.extraSmall
    MIcon {
      id: calIconH
      visible: bar.calIconShown
      Layout.alignment: Qt.AlignVCenter
      text: "calendar_month"
      color: Colours.m3tertiary
    }
    // Day and date, a faint tertiary divider, then hours, colon and
    // minutes as separate texts spacing.extraSmall apart, as KDE's are.
    MText { visible: bar.cfg.clock.showDate; Layout.alignment: Qt.AlignVCenter; text: Qt.formatDate(bar.sysClock.date, "ddd"); font.pointSize: Tk.body.small; color: Colours.m3tertiary }
    MText { visible: bar.cfg.clock.showDate; Layout.alignment: Qt.AlignVCenter; text: Qt.formatDate(bar.sysClock.date, "d"); font.pointSize: Tk.body.small; color: Colours.m3tertiary }
    Rectangle {
      visible: bar.cfg.clock.showDate
      Layout.alignment: Qt.AlignVCenter
      implicitWidth: 1
      implicitHeight: Tk.px(16)
      color: Colours.m3tertiary
      opacity: 0.2
    }
    MText { Layout.alignment: Qt.AlignVCenter; text: Sys.hour(bar.sysClock.date); font.pointSize: Tk.body.small * 1.1; axes: ({ "ROND": 25 }); color: Colours.m3tertiary }
    MText { Layout.alignment: Qt.AlignVCenter; text: ":"; font.pointSize: Tk.body.small * 1.1; axes: ({ "ROND": 25 }); color: Colours.m3tertiary }
    MText { Layout.alignment: Qt.AlignVCenter; text: Qt.formatTime(bar.sysClock.date, "mm"); font.pointSize: Tk.body.small * 1.1; axes: ({ "ROND": 25 }); color: Colours.m3tertiary }
    MText { visible: bar.cfg.clock.showSeconds; Layout.alignment: Qt.AlignVCenter; text: ":" + Qt.formatTime(bar.sysClock.date, "ss"); font.pointSize: Tk.body.small * 1.1; axes: ({ "ROND": 25 }); color: Colours.m3tertiary }
    MText {
      visible: entry.h12
      Layout.alignment: Qt.AlignVCenter
      text: Qt.formatTime(bar.sysClock.date, "AP").toLowerCase()
      font.pointSize: Tk.body.small * 0.9
      color: Colours.m3tertiary
    }
  }

  ColumnLayout {
    id: clockCol
    anchors.centerIn: parent
    visible: bar.vertical
    spacing: Tk.spacing.extraSmall
    readonly property real size: Tk.body.small * 1.1
    function fit(text, metricWidth) {
      return text === "11" ? 1.15 : Math.min(1.05, Math.max(hourMetrics.width, minMetrics.width) / Math.max(1, metricWidth))
    }
    TextMetrics { id: hourMetrics; font.family: Tk.sans; font.pointSize: clockCol.size; text: Sys.hour(bar.sysClock.date) }
    TextMetrics { id: minMetrics; font.family: Tk.sans; font.pointSize: clockCol.size; text: Qt.formatTime(bar.sysClock.date, "mm") }
    TextMetrics { id: secMetrics; font.family: Tk.sans; font.pointSize: clockCol.size; text: Qt.formatTime(bar.sysClock.date, "ss") }
    component Digits: MText {
      property real metricWidth
      readonly property real fitScale: clockCol.fit(text, metricWidth)
      Layout.alignment: Qt.AlignHCenter
      font.pointSize: clockCol.size
      font.letterSpacing: fitScale
      axes: ({ "ROND": 25, "wdth": fitScale * 100 })
      color: Colours.m3tertiary
    }
    MIcon {
      id: calIcon
      visible: bar.calIconShown
      Layout.alignment: Qt.AlignHCenter
      text: "calendar_month"
      color: Colours.m3tertiary
    }
    ColumnLayout {
      visible: bar.cfg.clock.showDate
      Layout.alignment: Qt.AlignHCenter
      spacing: clockCol.spacing - Tk.px(4)
      MText { Layout.alignment: Qt.AlignHCenter; text: Qt.formatDate(bar.sysClock.date, "ddd"); font.pointSize: Tk.body.small * 0.9; color: Colours.m3tertiary }
      MText { Layout.alignment: Qt.AlignHCenter; text: Qt.formatDate(bar.sysClock.date, "d"); font.pointSize: clockCol.size * 1.1; color: Colours.m3tertiary }
      Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: -Tk.padding.extraSmall
        Layout.rightMargin: -Tk.padding.extraSmall
        Layout.topMargin: Tk.px(4)
        Layout.bottomMargin: Tk.padding.extraSmall / 2
        implicitHeight: 1
        color: Colours.m3outlineVariant
      }
    }
    Digits { text: Sys.hour(bar.sysClock.date); metricWidth: hourMetrics.width }
    Digits { Layout.topMargin: -clockCol.spacing - 4; text: Qt.formatTime(bar.sysClock.date, "mm"); metricWidth: minMetrics.width }
    Digits { visible: bar.cfg.clock.showSeconds; Layout.topMargin: -clockCol.spacing - 4; text: Qt.formatTime(bar.sysClock.date, "ss"); metricWidth: secMetrics.width }
    MText {
      visible: parent.parent.h12
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: -clockCol.spacing - Tk.px(4)
      text: Qt.formatTime(bar.sysClock.date, "AP").toLowerCase()
      font.pointSize: Tk.body.small * 0.9
      color: Colours.m3tertiary
    }
  }

  function navStops() {
    return [{ item: entry, act: () => bar.leaveFor("dashboard") }]
  }
}
