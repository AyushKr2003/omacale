import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../.."

// Caelestia dashboard: a tab bar over Dashboard / Media / Performance /
// Weather pages, sliding horizontally between them.
Item {
  id: root

  property var host
  property bool active: false
  property int tab: 0
  readonly property var cfg: Config.o.dashboard
  readonly property var allTabs: [
    { id: "dashboard", icon: "dashboard", text: "Dashboard", page: dash },
    { id: "media", icon: "queue_music", text: "Media", page: media },
    { id: "performance", icon: "speed", text: "Performance", page: perf },
    { id: "weather", icon: "cloud", text: "Weather", page: weather }
  ]
  readonly property var tabs: {
    const t = allTabs.filter(x => cfg.tabs[x.id])
    return t.length ? t : [allTabs[0]]
  }
  onTabsChanged: tab = Math.min(tab, tabs.length - 1)
  function selectTab(id) {
    const i = tabs.findIndex(t => t.id === id)
    if (i >= 0) tab = i
  }

  readonly property Item page: tabs[Math.min(tab, tabs.length - 1)].page
  readonly property bool h12: Sys.h12
  readonly property real margins: Tk.padding.large

  implicitWidth: page.implicitWidth + margins * 2
  implicitHeight: tabBar.implicitHeight + tabBar.y + page.implicitHeight + margins * 2
  Behavior on implicitWidth { Anim {} }
  Behavior on implicitHeight { Anim {} }

  // Released on destruction too: a ScreenScope torn down while the dashboard
  // was open (monitor unplugged, plugins reloaded) would otherwise leak the
  // hold and leave Sys polling for the rest of the session.
  onActiveChanged: Sys.resourcesWanted += active ? 1 : -1
  Component.onDestruction: if (active) Sys.resourcesWanted -= 1

  readonly property var player: Sys.player
  SystemClock { id: clock; precision: SystemClock.Seconds }

  // --------------------------------------------------------------- tabs
  Item {
    id: tabBar
    x: root.margins
    y: Math.max(0, root.margins - Tk.border)
    width: root.width - root.margins * 2
    implicitHeight: Tk.sizes.tabIndicatorSpacing + tabRow.implicitHeight + 5 + Tk.sizes.tabIndicatorHeight + 1

    RowLayout {
      id: tabRow
      y: Tk.sizes.tabIndicatorSpacing
      width: parent.width
      spacing: 0
      Repeater {
        id: tabRep
        model: root.tabs
        Item {
          id: t
          required property var modelData
          required property int index
          readonly property bool current: root.tab === index
          readonly property real contentWidth: Math.max(tIcon.implicitWidth, tLabel.implicitWidth)
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          implicitHeight: tIcon.implicitHeight + tLabel.implicitHeight
          Item {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height + Tk.sizes.tabIndicatorSpacing * 2
            property real radius: Tk.rounding.medium
            StateLayer { color: t.current ? Colours.m3primary : Colours.m3onSurface; onClicked: root.tab = t.index }
          }
          MIcon {
            id: tIcon
            anchors.horizontalCenter: parent.horizontalCenter
            text: t.modelData.icon
            size: Tk.iconSize.medium
            fill: t.current ? 1 : 0
            color: t.current ? Colours.m3primary : Colours.m3onSurfaceVariant
            Behavior on fill { Anim { type: "effects" } }
          }
          MText {
            id: tLabel
            anchors.top: tIcon.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            text: t.modelData.text
            color: t.current ? Colours.m3primary : Colours.m3onSurfaceVariant
          }
        }
      }
    }
    WheelHandler {
      onWheel: e => root.tab = Math.max(0, Math.min(root.tabs.length - 1, root.tab + (e.angleDelta.y < 0 ? 1 : -1)))
    }
    Item {
      id: indicator
      readonly property real slot: tabBar.width / root.tabs.length
      readonly property Item cur: tabRep.count > root.tab ? tabRep.itemAt(root.tab) : null
      y: tabRow.y + tabRow.implicitHeight + 5
      height: Tk.sizes.tabIndicatorHeight
      width: cur ? cur.contentWidth : slot
      x: slot * root.tab + (slot - width) / 2
      clip: true
      Behavior on x { Anim {} }
      Behavior on width { Anim {} }
      Rectangle { width: parent.width; height: parent.height * 2; radius: height / 2; color: Colours.m3primary }
    }
    Rectangle {
      y: indicator.y + indicator.height
      width: parent.width; height: 1
      color: Colours.m3outlineVariant
    }
  }

  // -------------------------------------------------------------- pages
  // Caelestia dashboard/Content.qml: pages sit side by side in a rounded
  // clip and can be dragged sideways; past a tenth of a page it snaps on.
  ClippingRectangle {
    id: viewWrapper
    x: root.margins
    y: tabBar.y + tabBar.implicitHeight + root.margins
    width: root.width - root.margins * 2
    height: root.height - y - root.margins
    radius: Tk.rounding.large
    color: "transparent"

    Flickable {
      id: view
      anchors.fill: parent
      flickableDirection: Flickable.HorizontalFlick
      contentWidth: strip.implicitWidth
      contentHeight: strip.implicitHeight
      contentX: root.page.x
      Behavior on contentX { Anim {} }
      onContentXChanged: {
        if (!moving) return
        const dx = contentX - root.page.x
        if (dx > root.page.implicitWidth / 2) root.tab = Math.min(root.tab + 1, root.tabs.length - 1)
        else if (dx < -root.page.implicitWidth / 2) root.tab = Math.max(root.tab - 1, 0)
      }
      onDragEnded: {
        const dx = contentX - root.page.x
        if (dx > root.page.implicitWidth / 10) root.tab = Math.min(root.tab + 1, root.tabs.length - 1)
        else if (dx < -root.page.implicitWidth / 10) root.tab = Math.max(root.tab - 1, 0)
        else contentX = Qt.binding(() => root.page.x)
      }

      Row {
        id: strip
        spacing: 0
        Dash { id: dash; visible: root.cfg.tabs.dashboard || root.tabs[0].id === "dashboard" }
        MediaTab { id: media; visible: root.cfg.tabs.media; active: root.active && root.page === media }
        PerfTab { id: perf; visible: root.cfg.tabs.performance; active: root.active && root.page === perf }
        WeatherTab { id: weather; visible: root.cfg.tabs.weather; active: root.active && root.page === weather }
      }
    }
  }

  component Card: Rectangle { color: Colours.m3surfaceContainer; radius: Tk.rounding.extraLarge }

  // ============================================================ Dashboard
  component Dash: GridLayout {
    rowSpacing: Tk.spacing.medium
    columnSpacing: Tk.spacing.medium

    // Weather
    Card {
      Layout.row: 0; Layout.column: 0; Layout.columnSpan: 2
      Layout.preferredWidth: Tk.sizes.weatherWidth
      Layout.preferredHeight: wRow.implicitHeight + Tk.padding.largeIncreased * 2
      radius: Tk.rounding.extraLarge * 1.5
      Row {
        id: wRow
        anchors.centerIn: parent
        spacing: Tk.spacing.largeIncreased
        MIcon { anchors.verticalCenter: parent.verticalCenter; animate: true; text: Sys.weatherIcon; color: Colours.m3secondary; size: Tk.iconSize.extraLarge * 1.6 }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          spacing: Tk.spacing.extraSmall
          MText { anchors.horizontalCenter: parent.horizontalCenter; animate: true; text: Sys.temp; color: Colours.m3primary; font.pointSize: Tk.headline.medium; weight: Font.DemiBold; axes: ({ "ROND": 25, "wdth": 110 }) }
          MText { anchors.horizontalCenter: parent.horizontalCenter; animate: true; text: Sys.weatherDesc; width: Math.min(implicitWidth, Tk.sizes.weatherWidth - Tk.iconSize.extraLarge * 1.6 - Tk.spacing.largeIncreased - Tk.padding.extraLargeIncreased); elide: Text.ElideRight; wrapMode: Text.WordWrap; maximumLineCount: 2; horizontalAlignment: Text.AlignHCenter }
        }
      }
    }

    // User
    Card {
      Layout.row: 0; Layout.column: 2; Layout.columnSpan: 3
      Layout.preferredWidth: Tk.sizes.userWidth
      Layout.fillHeight: true
      UserCard { anchors.fill: parent; anchors.margins: Tk.padding.large }
    }

    // Media
    Card {
      Layout.row: 0; Layout.column: 5; Layout.rowSpan: 2
      Layout.preferredWidth: Tk.sizes.mediaWidth
      Layout.fillHeight: true
      radius: Tk.rounding.extraLarge * 2
      MediaCard { anchors.fill: parent }
    }

    // Date / time
    Card {
      Layout.row: 1; Layout.column: 0
      Layout.preferredWidth: Tk.sizes.dateTimeWidth
      Layout.fillHeight: true
      radius: Tk.rounding.large
      ColumnLayout {
        anchors.centerIn: parent
        spacing: 0
        MText { Layout.alignment: Qt.AlignHCenter; Layout.bottomMargin: -Tk.headline.medium * 0.4; text: Sys.hour(clock.date); color: Colours.m3secondary; font.family: Tk.clock; font.pointSize: 28; weight: Font.DemiBold }
        MText { Layout.alignment: Qt.AlignHCenter; text: "•••"; color: Colours.m3primary; font.family: Tk.clock; font.pointSize: 28 * 0.9 }
        MText { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: -Tk.headline.medium * 0.4; text: Qt.formatTime(clock.date, "mm"); color: Colours.m3secondary; font.family: Tk.clock; font.pointSize: 28; weight: Font.DemiBold }
        MText { visible: root.cfg.clockSeconds; Layout.alignment: Qt.AlignHCenter; Layout.topMargin: -Tk.headline.medium * 0.4; text: "•••"; color: Colours.m3primary; font.family: Tk.clock; font.pointSize: 28 * 0.9 }
        MText { visible: root.cfg.clockSeconds; Layout.alignment: Qt.AlignHCenter; Layout.topMargin: -Tk.headline.medium * 0.4; text: Qt.formatTime(clock.date, "ss"); color: Colours.m3secondary; font.family: Tk.clock; font.pointSize: 28; weight: Font.DemiBold }
        MText { visible: root.h12; Layout.alignment: Qt.AlignHCenter; text: Qt.formatTime(clock.date, "AP"); color: Colours.m3primary; font.family: Tk.clock; font.pointSize: 18; weight: Font.DemiBold }
      }
    }

    // Calendar
    Card {
      Layout.row: 1; Layout.column: 1; Layout.columnSpan: 3
      Layout.fillWidth: true
      Layout.preferredHeight: cal.implicitHeight + Tk.padding.large * 2
      Calendar { id: cal; anchors.fill: parent; anchors.margins: Tk.padding.large }
    }

    // Resources
    Card {
      Layout.row: 1; Layout.column: 4
      Layout.preferredWidth: resCol.implicitWidth + Tk.padding.large * 2
      Layout.fillHeight: true
      radius: Tk.rounding.large
      ColumnLayout {
        id: resCol
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top; anchors.bottom: parent.bottom
        anchors.margins: Tk.padding.large
        spacing: Tk.spacing.medium
        Resource { icon: "memory"; value: Sys.cpu }
        Resource { icon: "memory_alt"; value: Sys.mem; fgColour: Colours.m3tertiary }
        Resource { icon: "hard_disk"; value: Sys.disk; fgColour: Colours.m3secondary }
      }
    }
  }

  component Resource: CircularProgress {
    property string icon
    Layout.fillHeight: true
    implicitSize: height
    implicitWidth: height
    strokeWidth: Tk.sizes.resourceProgressThickness
    MIcon { anchors.centerIn: parent; text: parent.icon; size: Tk.iconSize.large; color: parent.fgColour }
  }

  // User card: logo gem, pill profile picture, uptime clamshell, WM bubble.
  component UserCard: Item {
    id: uc
    MShape {
      id: logoShape
      x: Tk.padding.extraSmall
      shape: "gem"
      implicitSize: Tk.sizes.logoSize + Tk.padding.small * 2
      color: Colours.m3primaryContainer
      ColouredIcon {
        anchors.centerIn: parent
        implicitSize: Tk.sizes.logoSize
        source: "file://" + root.host.omarchyPath + "/icon.png"
        colour: Colours.m3onPrimaryContainer
      }
    }
    Item {
      id: pfpBox
      anchors.top: parent.top; anchors.bottom: parent.bottom
      anchors.left: logoShape.right
      anchors.leftMargin: -(Tk.padding.largeIncreased + Tk.padding.extraLarge) / 2
      width: height
      MShape {
        id: pfpShape
        anchors.centerIn: parent
        implicitSize: parent.height
        shape: "pill"
        color: Colours.m3surfaceContainerHighest
      }
      Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: ShaderMaskEffect { maskItem: pfpShape }
        Image {
          id: pfp
          anchors.fill: parent
          source: "file://" + Quickshell.env("HOME") + "/.face"
          fillMode: Image.PreserveAspectCrop
          sourceSize.width: 256; sourceSize.height: 256
          cache: false
        }
        MIcon {
          anchors.centerIn: parent
          visible: pfp.status !== Image.Ready
          text: "person"
          size: Tk.iconSize.extraLarge
          fill: 1
          color: Colours.m3onSurfaceVariant
        }
      }
    }
    MShape {
      id: uptimeShape
      anchors.bottom: parent.bottom
      anchors.left: pfpBox.right
      anchors.bottomMargin: -Tk.padding.small
      anchors.leftMargin: -Tk.padding.extraLargeIncreased
      implicitSize: Tk.sizes.uptimeSize + Tk.padding.small * 2
      shape: "clamShell"
      color: Colours.m3tertiaryContainer
      MIcon { anchors.centerIn: parent; text: "clock_arrow_up"; size: Tk.iconSize.medium; color: Colours.m3onTertiaryContainer }
    }
    MText {
      anchors.left: uptimeShape.right
      anchors.leftMargin: Tk.spacing.small
      anchors.verticalCenter: uptimeShape.verticalCenter
      text: "up " + Sys.uptime
      width: uc.width - x - Tk.padding.small
      elide: Text.ElideRight
    }
    Rectangle {
      id: bubble1
      anchors.left: pfpBox.right; anchors.top: bubble2.bottom
      anchors.leftMargin: Tk.spacing.small; anchors.topMargin: -Tk.spacing.extraSmall
      width: 10; height: 10; radius: 5
      color: Colours.m3secondaryContainer
    }
    Rectangle {
      id: bubble2
      anchors.left: bubble1.right; anchors.verticalCenter: wm.bottom
      anchors.leftMargin: Tk.spacing.extraSmall
      width: 15; height: 15; radius: 7.5
      color: Colours.m3secondaryContainer
    }
    Rectangle {
      id: wm
      anchors.left: bubble2.left
      anchors.leftMargin: -Tk.padding.medium
      y: Tk.padding.extraSmall
      radius: Tk.rounding.largeIncreased
      color: Colours.m3secondaryContainer
      width: wmRow.implicitWidth + Tk.padding.medium * 2
      height: wmRow.implicitHeight + Tk.padding.small * 2
      Row {
        id: wmRow
        anchors.centerIn: parent
        spacing: Tk.spacing.extraSmall
        MIcon { anchors.verticalCenter: parent.verticalCenter; text: "select_window"; size: Tk.body.small; color: Colours.m3onSecondaryContainer }
        MText { anchors.verticalCenter: parent.verticalCenter; text: "Hyprland..."; color: Colours.m3onSecondaryContainer; axes: ({ "ROND": 25, "slnt": -4 }) }
      }
    }
  }

  // Calendar with a sunny "today" marker; wheel changes month.
  component Calendar: ColumnLayout {
    id: calRoot
    property date shown: new Date(clock.date.getFullYear(), clock.date.getMonth(), 1)
    readonly property int month: shown.getMonth()
    readonly property int year: shown.getFullYear()
    readonly property bool isCurrent: month === clock.date.getMonth() && year === clock.date.getFullYear()
    spacing: Tk.spacing.extraSmall
    // Caelestia dash/Calendar.qml: the month slides out one way and the new
    // one slides in from the other.
    property date target: shown
    readonly property int animDirection: target > shown ? -1 : 1
    property real animTranslate
    property real animOpacity: 1
    function step(n) { shown = new Date(target.getFullYear(), target.getMonth() + n, 1) }
    onShownChanged: target = shown
    Anim { id: trOutAnim; running: false; target: calRoot; property: "animTranslate"; to: Tk.padding.extraLarge * calRoot.animDirection; type: "fastSpatial" }
    Behavior on shown {
      SequentialAnimation {
        ParallelAnimation {
          ScriptAction { script: Qt.callLater(() => trOutAnim.start()) }
          Anim { target: calRoot; property: "animOpacity"; to: 0; type: "fastEffects" }
        }
        ScriptAction { script: { trOutAnim.complete(); calRoot.animTranslate = Tk.padding.extraLarge * -calRoot.animDirection } }
        PropertyAction {}
        ParallelAnimation {
          Anim { target: calRoot; property: "animTranslate"; to: 0; type: "spatial" }
          Anim { target: calRoot; property: "animOpacity"; to: 1; type: "effects" }
        }
      }
    }
    Connections { target: root; function onActiveChanged() { if (root.active) calRoot.shown = new Date(clock.date.getFullYear(), clock.date.getMonth(), 1) } }

    RowLayout {
      Layout.fillWidth: true
      spacing: Tk.spacing.extraSmall
      IconButton { type: "text"; icon: "chevron_left"; iconSize: Tk.iconSize.small; iconWeight: Font.Bold; padding: Tk.padding.small; onClicked: calRoot.step(-1) }
      Item {
        Layout.fillWidth: true
        implicitHeight: monthLabel.implicitHeight + Tk.padding.extraSmall * 2
        property real radius: height / 2
        StateLayer { color: Colours.m3primary; disabled: calRoot.isCurrent; onClicked: calRoot.shown = new Date(clock.date.getFullYear(), clock.date.getMonth(), 1) }
        MText {
          id: monthLabel
          opacity: calRoot.animOpacity
          transform: Translate { x: calRoot.animTranslate }
          anchors.centerIn: parent
          text: Qt.formatDate(calRoot.shown, "MMMM yyyy")
          color: Colours.m3primary
          font.pointSize: Tk.title.small
          weight: Font.Medium
        }
      }
      IconButton { type: "text"; icon: "chevron_right"; iconSize: Tk.iconSize.small; iconWeight: Font.Bold; padding: Tk.padding.small; onClicked: calRoot.step(1) }
    }
    Grid {
      id: grid
      Layout.fillWidth: true
      opacity: calRoot.animOpacity
      transform: Translate { x: calRoot.animTranslate }
      columns: 7
      columnSpacing: 3
      rowSpacing: 3
      readonly property real cellW: (width - columnSpacing * 6) / 7
      readonly property int offset: (calRoot.shown.getDay() + 6) % 7
      readonly property int days: new Date(calRoot.year, calRoot.month + 1, 0).getDate()
      readonly property int prevDays: new Date(calRoot.year, calRoot.month, 0).getDate()
      readonly property int rows: Math.ceil((offset + days) / 7)
      Repeater {
        model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        MText {
          required property string modelData
          required property int index
          width: grid.cellW
          horizontalAlignment: Text.AlignHCenter
          text: modelData
          weight: Font.Medium
          color: index >= 5 ? Colours.m3tertiary : Colours.m3onSurface
        }
      }
      Repeater {
        model: grid.rows * 7
        Item {
          required property int index
          readonly property int day: index - grid.offset + 1
          readonly property bool inMonth: day >= 1 && day <= grid.days
          readonly property int shownDay: inMonth ? day : day < 1 ? grid.prevDays + day : day - grid.days
          readonly property bool today: inMonth && calRoot.isCurrent && day === clock.date.getDate()
          readonly property bool weekend: index % 7 >= 5
          width: grid.cellW
          height: dayText.implicitHeight + Tk.padding.small
          MShape {
            visible: parent.today
            anchors.centerIn: parent
            implicitSize: Math.max(parent.height, dayText.implicitWidth) + Tk.padding.extraSmall * 2
            shape: "sunny"
            color: Colours.m3primary
          }
          MText {
            id: dayText
            anchors.centerIn: parent
            text: parent.shownDay
            color: parent.today ? Colours.m3onPrimary : parent.weekend ? Colours.m3tertiary : Colours.m3onSurfaceVariant
            opacity: parent.inMonth ? 1 : 0.4
          }
        }
      }
    }
    WheelHandler { onWheel: e => calRoot.step(e.angleDelta.y > 0 ? -1 : 1) }
  }

  // Media card: cover art inside a 180° progress arc, then titles, controls, bongo cat.
  component MediaCard: Item {
    id: mc
    property real progress: root.player && root.player.length > 0 ? (root.player.position % root.player.length) / root.player.length : 0
    Behavior on progress { Anim { type: "standardLarge" } }
    Timer { running: root.active && root.player && root.player.isPlaying; interval: Config.o.services.mediaUpdateInterval; repeat: true; triggeredOnStart: true; onTriggered: root.player.positionChanged() }

    CircularProgress {
      id: prog
      anchors.centerIn: cover
      implicitSize: cover.width + Tk.spacing.extraSmall + thickness * 2
      width: implicitSize; height: implicitSize
      strokeWidth: Tk.sizes.mediaProgressThickness
      sweepAngle: Tk.sizes.mediaProgressSweep
      startAngle: -90 - sweepAngle / 2
      value: mc.progress
      wavy: true
      waveFrequency: 8
      waveDuration: 2000
      wavePaused: !(root.player && root.player.isPlaying)
    }
    Rectangle {
      id: cover
      anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
      anchors.margins: Tk.padding.medium + Tk.spacing.extraSmall + prog.thickness
      height: width
      radius: width / 2
      color: Colours.m3surfaceContainerHigh
      clip: true
      MIcon { anchors.centerIn: parent; text: "art_track"; size: Tk.iconSize.extraLarge; color: Colours.m3onSurfaceVariant; visible: art.status !== Image.Ready }
      Image {
        id: art
        anchors.fill: parent
        source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 256; sourceSize.height: 256
        layer.enabled: true
        layer.effect: ShaderMaskEffect { maskItem: coverMask }
      }
      Rectangle { id: coverMask; anchors.fill: parent; radius: width / 2; visible: false }
    }
    Column {
      id: info
      anchors.top: cover.bottom
      anchors.topMargin: Tk.spacing.medium
      anchors.left: parent.left; anchors.right: parent.right
      spacing: Tk.spacing.small
      MText { width: parent.width - Tk.padding.extraLargeIncreased; anchors.horizontalCenter: parent.horizontalCenter; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; animate: true
        text: root.player ? (root.player.trackTitle || "Unknown title") : "No media"; color: Colours.m3primary; font.pointSize: Tk.title.small; weight: Font.Medium }
      MText { width: parent.width - Tk.padding.extraLargeIncreased; anchors.horizontalCenter: parent.horizontalCenter; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; animate: true
        text: root.player ? (root.player.trackAlbum || "Unknown album") : "No media"; color: Colours.m3outline }
      MText { width: parent.width - Tk.padding.extraLargeIncreased; anchors.horizontalCenter: parent.horizontalCenter; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; animate: true
        text: root.player ? (root.player.trackArtist || "Unknown artist") : "No media"; color: Colours.m3secondary }
      // Caelestia dash/Media.qml: a ButtonRow, so a pressed button bulges.
      Item { width: 1; height: Tk.spacing.medium - Tk.spacing.small }
      ButtonRow {
        width: parent.width - Tk.padding.large * 2
        implicitHeight: playBtn.implicitHeight
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Tk.spacing.extraSmall
        IconButton { type: "tonal"; icon: "skip_previous"; shapeMorph: true; disabled: !root.player || !root.player.canGoPrevious; onClicked: root.player.previous() }
        IconButton {
          id: playBtn
          fillWidth: true
          shapeMorph: true
          icon: root.player && root.player.isPlaying ? "pause" : "play_arrow"
          toggle: true; checked: root.player ? root.player.isPlaying : false
          disabled: !root.player || !root.player.canTogglePlaying
          onClicked: root.player.togglePlaying()
        }
        IconButton { type: "tonal"; icon: "skip_next"; shapeMorph: true; disabled: !root.player || !root.player.canGoNext; onClicked: root.player.next() }
      }
    }
    AnimatedImage {
      visible: root.cfg.mediaGif
      anchors.top: info.bottom
      anchors.bottom: parent.bottom
      anchors.left: parent.left; anchors.right: parent.right
      anchors.margins: Tk.padding.extraLargeIncreased
      anchors.topMargin: Tk.spacing.small
      anchors.bottomMargin: Tk.padding.large
      source: Qt.resolvedUrl("../../assets/bongocat.gif")
      playing: root.active && root.player && root.player.isPlaying
      fillMode: AnimatedImage.PreserveAspectFit
    }
  }
}
