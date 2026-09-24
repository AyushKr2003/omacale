import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import "../.."

// The Caelestia bar: logo, workspaces, active window, tray, clock, status
// icons, power — in Caelestia's default order and metrics.
Item {
  id: root

  required property var screen
  required property var host
  required property var scope

  readonly property int vPadding: Tk.padding.large
  readonly property var cfg: Config.o.bar

  // ------------------------------------------------------ space budget
  // The active window title is the bar's flexible space. The tray and the
  // plugins pill share what's left above its minimum, instead of each taking
  // a fixed share: title + tray + plugins is the same whatever they collapse
  // to, so the budget doesn't move when they do. When the tray's full list
  // and the plugins' pinned widgets don't fit, the tray goes compact first;
  // the plugins pill then scrolls. Status icons and the clock never shrink.
  readonly property real titleMin: cfg.activeWindow.enabled ? Tk.barInner * 3 : Tk.barInner
  readonly property real budget: Math.max(0, titleArea.height
    + (pluginPlace.visible ? pluginPlace.height : 0)
    + (trayPill.visible ? trayPill.height : 0) - titleMin)
  readonly property bool trayOverBudget: trayPill.visible && trayPill.fullHeight + pluginPill.collapsedHeight > budget
  readonly property real trayReserve: !trayPill.visible ? 0 : trayPill.compact ? trayPill.collapsedHeight : trayPill.fullHeight

  // Popout lookup for a y coordinate on the bar (Caelestia Bar.checkPopout).
  function popoutAt(y) {
    const p = mapToItem(statusCol, 0, y)
    if (cfg.popouts.statusIcons && p.y >= -statusPill.anchorsPad && p.y <= statusCol.height + statusPill.anchorsPad) {
      for (let i = 0; i < statusCol.children.length; i++) {
        const c = statusCol.children[i]
        if (!c.visible || !c.popout) continue
        if (p.y >= c.y - 3 && p.y <= c.y + c.height + 3)
          return { name: c.popout, center: c.mapToItem(root, 0, c.height / 2).y }
      }
    }
    const t = mapToItem(trayCol, 0, y)
    if (cfg.popouts.tray && trayPill.visible && (!trayPill.compact || trayPill.expanded) && t.y >= 0 && t.y <= trayCol.height) {
      for (let i = 0; i < trayRep.count; i++) {
        const it = trayRep.itemAt(i)
        if (t.y >= it.y - 4 && t.y <= it.y + it.height + 4)
          return { name: "traymenu", index: i, item: it.modelData, center: it.mapToItem(root, 0, it.height / 2).y }
      }
    }
    const w = mapToItem(activeWin, 0, y)
    if (cfg.popouts.activeWindow && activeWin.visible && w.y >= 0 && w.y <= activeWin.height && Sys.activeToplevel)
      return { name: "activewindow", center: activeWin.mapToItem(root, 0, activeWin.height / 2).y }
    return null
  }

  // Which collapsible group the pointer is over, from ScreenScope (Caelestia
  // drives its compact tray the same way, in Bar.checkPopout). A hover
  // handler inside the bar is no good: leaving the layer surface altogether
  // never reaches it, and the group would stay open.
  // Open while the pointer is on the group; ScreenScope drives this.
  readonly property bool groupsExpanded: trayPill.expanded || pluginPill.expanded

  function hoverAt(y, onBar) {
    const t = mapToItem(trayPill, 0, y)
    if (onBar && trayPill.visible && t.y >= 0 && t.y <= trayPill.height) {
      collapseTrayTimer.stop()
      if (trayPill.compact) trayPill.expanded = true
    } else if (trayPill.expanded && !collapseTrayTimer.running) collapseTrayTimer.start()

    const p = mapToItem(pluginPill, 0, y)
    if (onBar && pluginPill.visible && p.y >= 0 && p.y <= pluginPill.height) {
      collapsePluginsTimer.stop()
      if (pluginPill.overflowCount > 0) pluginPill.expanded = true
    } else if (pluginPill.expanded && !collapsePluginsTimer.running) collapsePluginsTimer.start()
  }

  function handleWheel(y, dy) {
    const ws = mapToItem(workspaces, 0, y)
    if (ws.y >= 0 && ws.y <= workspaces.height) { workspaces.scroll(dy); return }
    // Omarchy's volume/brightness keys: they resolve the real sink behind a
    // speaker tuning and show Omarchy's OSD.
    const svc = Config.o.services
    if (y < height / 2) { if (cfg.scroll.volume) Quickshell.execDetached(["omarchy-audio-output-volume", (dy > 0 ? "+" : "-") + svc.volumeStep]) }
    else if (cfg.scroll.brightness) Quickshell.execDetached(["omarchy-brightness-display", dy > 0 ? "+" + svc.brightnessStep + "%" : svc.brightnessStep + "%-"])
  }

  SystemClock { id: clock; precision: root.cfg.clock.showSeconds ? SystemClock.Seconds : SystemClock.Minutes }
  PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

  ColumnLayout {
    id: col
    anchors.fill: parent
    anchors.topMargin: root.vPadding
    anchors.bottomMargin: root.vPadding
    spacing: Tk.spacing.medium

    // ---------------------------------------------------------- logo
    // Full-width row so the icon is centred with a rounded x: the bar is an
    // even width and the slot odd, so AlignHCenter would put it on a half
    // pixel and blur it.
    Item {
      visible: root.cfg.logo
      Layout.fillWidth: true
      implicitHeight: logo.height
      LogoIcon {
        id: logo
        x: Math.round((parent.width - width) / 2)
        width: Math.round(Tk.body.large * 1.2)
        height: width
        value: root.cfg.logoIcon
        size: width
        colour: Colours.m3tertiary
      }
      MouseArea {
        anchors.fill: logo
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => root.host.toggle(e.button === Qt.RightButton ? "settings" : "launcher")
      }
    }

    // ---------------------------------------------------- workspaces
    Workspaces {
      id: workspaces
      Layout.alignment: Qt.AlignHCenter
      screen: root.screen
    }

    // ------------------------------------------ active window (centred)
    Item {
      id: titleArea
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true

      Item {
        id: activeWin
        visible: root.cfg.activeWindow.enabled
        readonly property var tl: Sys.activeToplevel
        readonly property string title: {
          const t = tl && tl.title ? tl.title : "Desktop"
          if (!root.cfg.activeWindow.compact) return t
          const parts = t.split(/\s+[\-\u2013\u2014]\s+/)
          return parts.length > 1 ? parts[parts.length - 1].trim() : t
        }
        readonly property real maxLen: parent.height - winIcon.height - Tk.spacing.small

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(winIcon.implicitWidth, metrics.height)
        height: winIcon.implicitHeight + Tk.spacing.small + Math.min(metrics.width, maxLen)
        Behavior on height { Anim {} }

        MIcon {
          id: winIcon
          anchors.horizontalCenter: parent.horizontalCenter
          animate: true
          text: Sys.appIcon(activeWin.tl && activeWin.tl.wayland ? activeWin.tl.wayland.appId : "", "desktop_windows")
          color: Colours.m3primary
        }
        // Caelestia ActiveWindow: two titles cross-fade when the text changes.
        property Item current: title1
        TextMetrics {
          id: metrics
          text: activeWin.title
          font.family: Tk.sans
          font.pointSize: Tk.body.small
          font.letterSpacing: 1.4
          elide: Qt.ElideRight
          elideWidth: Math.max(0, activeWin.maxLen)
          onElidedTextChanged: {
            if (!title1 || !title2) return
            const next = activeWin.current === title1 ? title2 : title1
            next.text = elidedText
            activeWin.current = next
          }
        }
        component Title: MText {
          id: t
          anchors.top: winIcon.bottom
          anchors.topMargin: Tk.spacing.small
          anchors.horizontalCenter: winIcon.horizontalCenter
          width: implicitHeight
          height: implicitWidth
          font.letterSpacing: 1.4
          color: Colours.m3primary
          opacity: activeWin.current === t ? 1 : 0
          Behavior on opacity { Anim { type: "effects" } }
          transform: Rotation { angle: 90; origin.x: t.implicitHeight / 2; origin.y: t.implicitHeight / 2 }
        }
        Title { id: title1; Component.onCompleted: text = metrics.elidedText }
        Title { id: title2 }
      }
    }

    // --------------------------------------------------- plugins pill
    // Holds the plugins pill's place in the column; the pill is drawn outside
    // the layout (see pluginPill below). Hiding a parent of a widget makes the
    // widget itself report visible=false, so a pill hidden because every
    // widget had hidden itself could never come back. Hiding this empty
    // placeholder instead also lets the layout drop its spacing.
    Item {
      id: pluginPlace
      Layout.alignment: Qt.AlignHCenter
      implicitWidth: Tk.barInner
      implicitHeight: pluginPill.implicitHeight
      visible: pluginPill.visible && pluginPill.anyShown
    }

    // ---------------------------------------------------------- tray
    // Caelestia bar/components/Tray.qml: compact collapses the tray behind a
    // chevron that hovering expands (Caelestia's Bar.checkPopout), and
    // hiddenIcons drops items for good. Compact is also switched on by the
    // shared space budget (see "space budget" below) when the tray doesn't fit.
    Rectangle {
      id: trayPill
      Layout.alignment: Qt.AlignHCenter
      readonly property var trayItems: SystemTray.items.values.filter(i => i.status !== Status.Passive
        && root.cfg.tray.hiddenIcons.indexOf(i.id) < 0)
      readonly property bool bg: root.cfg.tray.background
      readonly property int padding: bg ? Tk.padding.medium : Tk.padding.extraSmall
      readonly property int spacingN: bg ? Tk.spacing.medium : Tk.spacing.extraSmall
      visible: root.cfg.tray.enabled && trayItems.length > 0
      implicitWidth: Tk.barInner

      readonly property bool compact: root.cfg.tray.compact || root.trayOverBudget
      property bool expanded: false
      onCompactChanged: if (!compact) expanded = false

      // Caelestia's nonAnimHeight, with the expanded list capped to the budget.
      readonly property real fullHeight: trayCol.implicitHeight + padding * 2
      readonly property real collapsedHeight: Math.max(bg ? width : 0, expandTrayIcon.implicitHeight + (bg ? Tk.padding.extraSmall : 0) + padding)
      implicitHeight: {
        if (!visible) return 0
        if (!compact) return fullHeight
        if (!expanded) return collapsedHeight
        return Math.max(collapsedHeight, Math.min(expandTrayIcon.implicitHeight + trayCol.implicitHeight + spacingN + (bg ? Tk.padding.extraSmall : 0) + padding,
          root.budget - pluginPill.implicitHeight))
      }
      radius: Tk.rounding.full
      color: bg ? Colours.m3surfaceContainer : "transparent"
      clip: true
      Behavior on implicitHeight { Anim {} }

      // The tray menu keeps it open; closing the menu lets it fold again.
      Connections {
        target: root.scope
        function onPopoutChanged() { if (root.scope.popout === "") collapseTrayTimer.restart() }
      }
      Timer {
        id: collapseTrayTimer
        interval: 400
        onTriggered: if (root.scope.popout !== "traymenu") trayPill.expanded = false
      }

      // Scrolls when an expanded tray is capped by the budget.
      MFlickable {
        id: trayFlick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: trayPill.padding
        height: Math.max(0, parent.height - trayPill.padding - (trayPill.compact ? expandTrayIcon.implicitHeight + trayPill.spacingN : trayPill.padding))
        contentHeight: trayCol.implicitHeight
        interactive: contentHeight > height + 0.5
        clip: true

        Column {
          id: trayCol
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Tk.spacing.small
          opacity: !trayPill.compact || trayPill.expanded ? 1 : 0
          Behavior on opacity { Anim { type: "effects" } }

          Repeater {
            id: trayRep
            model: trayPill.trayItems
            MouseArea {
              required property var modelData
              implicitWidth: Tk.body.small * 2
              implicitHeight: Tk.body.small * 2
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              cursorShape: Qt.PointingHandCursor
              onClicked: function(e) { if (e.button === Qt.LeftButton) modelData.activate(); else modelData.secondaryActivate() }
              ColouredIcon {
                anchors.fill: parent
                visible: root.cfg.tray.recolour
                colour: Colours.m3secondary
                source: trayImg.source
              }
              Image {
                id: trayImg
                anchors.fill: parent
                visible: !root.cfg.tray.recolour
                source: {
                  let icon = parent.modelData.icon
                  if (icon.indexOf("?path=") >= 0) {
                    const [name, path] = icon.split("?path=")
                    icon = "file://" + path + "/" + name.slice(name.lastIndexOf("/") + 1)
                  }
                  return icon
                }
                sourceSize.width: width * 2
                sourceSize.height: height * 2
                smooth: true
                mipmap: true
              }
              scale: 0
              Component.onCompleted: scale = 1
              Behavior on scale { Anim { easing.bezierCurve: Tk.curves.standardDecel } }
            }
          }
        }
      }

      // Caelestia's expandIcon: one glyph, turned 180° when expanded.
      MIcon {
        id: expandTrayIcon
        visible: trayPill.compact
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: trayPill.bg ? Tk.padding.extraSmall : 0
        text: "expand_less"
        size: Tk.iconSize.medium
        color: Colours.m3onSurfaceVariant
        rotation: trayPill.expanded ? 180 : 0
        Behavior on rotation { Anim {} }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: { collapseTrayTimer.stop(); trayPill.expanded = !trayPill.expanded }
        }
      }
    }

    // --------------------------------------------------------- clock
    Rectangle {
      Layout.alignment: Qt.AlignHCenter
      implicitWidth: Tk.barInner
      implicitHeight: clockCol.implicitHeight + (root.cfg.clock.background ? Tk.padding.medium : Tk.padding.extraSmall) * 2
      radius: width / 2
      color: root.cfg.clock.background ? Colours.m3surfaceContainer : "transparent"
      readonly property bool h12: Sys.h12
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => {
          if (e.button === Qt.RightButton) root.host.toggle("sidebar")
          else root.host.toggle("dashboard")
        }
      }
      // Caelestia bar/components/Clock.qml: body.small x1.1 digits, squeezed
      // or stretched on the width axis so hours and minutes line up.
      ColumnLayout {
        id: clockCol
        anchors.centerIn: parent
        spacing: Tk.spacing.extraSmall
        readonly property real size: Tk.body.small * 1.1
        function fit(text, metricWidth) {
          return text === "11" ? 1.15 : Math.min(1.05, Math.max(hourMetrics.width, minMetrics.width) / Math.max(1, metricWidth))
        }
        TextMetrics { id: hourMetrics; font.family: Tk.sans; font.pointSize: clockCol.size; text: Sys.hour(clock.date) }
        TextMetrics { id: minMetrics; font.family: Tk.sans; font.pointSize: clockCol.size; text: Qt.formatTime(clock.date, "mm") }
        TextMetrics { id: secMetrics; font.family: Tk.sans; font.pointSize: clockCol.size; text: Qt.formatTime(clock.date, "ss") }
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
          visible: root.cfg.clock.showIcon
          Layout.alignment: Qt.AlignHCenter
          text: "calendar_month"
          color: Colours.m3tertiary
        }
        ColumnLayout {
          visible: root.cfg.clock.showDate
          Layout.alignment: Qt.AlignHCenter
          spacing: clockCol.spacing - 4
          MText { Layout.alignment: Qt.AlignHCenter; text: Qt.formatDate(clock.date, "ddd"); font.pointSize: Tk.body.small * 0.9; color: Colours.m3tertiary }
          MText { Layout.alignment: Qt.AlignHCenter; text: Qt.formatDate(clock.date, "d"); font.pointSize: clockCol.size * 1.1; color: Colours.m3tertiary }
          Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: -Tk.padding.extraSmall
            Layout.rightMargin: -Tk.padding.extraSmall
            Layout.topMargin: 4
            Layout.bottomMargin: Tk.padding.extraSmall / 2
            implicitHeight: 1
            color: Colours.m3outlineVariant
          }
        }
        Digits { text: Sys.hour(clock.date); metricWidth: hourMetrics.width }
        Digits { Layout.topMargin: -clockCol.spacing - 4; text: Qt.formatTime(clock.date, "mm"); metricWidth: minMetrics.width }
        Digits { visible: root.cfg.clock.showSeconds; Layout.topMargin: -clockCol.spacing - 4; text: Qt.formatTime(clock.date, "ss"); metricWidth: secMetrics.width }
        MText {
          visible: parent.parent.h12
          Layout.alignment: Qt.AlignHCenter
          Layout.topMargin: -clockCol.spacing - 4
          text: Qt.formatTime(clock.date, "AP").toLowerCase()
          font.pointSize: Tk.body.small * 0.9
          color: Colours.m3tertiary
        }
      }
    }

    // --------------------------------------------------- status icons
    Rectangle {
      id: statusPill
      readonly property int anchorsPad: Tk.padding.medium
      // Not `statusCol.visibleChildren`: while the bar is hidden (fullscreen)
      // every child reads invisible, the pill hides, and its children then
      // stay invisible for good, so the pill never came back.
      readonly property var st: root.cfg.status
      visible: (st.keepAwake && IdleService.enabled) || (st.update && UpdateService.available)
        || RecordService.running || st.notifications
        || (st.lockStatus && (root.host.capsLock || root.host.numLock || lockStatus.visible))
        || st.audio || st.microphone || st.kbLayout || st.network || st.bluetooth || st.battery
      Layout.alignment: Qt.AlignHCenter
      implicitWidth: Tk.barInner
      implicitHeight: statusCol.implicitHeight + Tk.padding.medium * 2
      radius: width / 2
      color: Colours.m3surfaceContainer
      clip: true
      Behavior on implicitHeight { Anim {} }

      Column {
        id: statusCol
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tk.padding.medium
        spacing: Tk.spacing.medium / 2

        // Keep awake indicator
        MIcon {
          visible: root.cfg.status.keepAwake && IdleService.enabled
          anchors.horizontalCenter: parent.horizontalCenter
          text: "coffee"
          color: Colours.m3secondary
          fill: 1
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.host.toggle("utilities")
          }
        }

        // Pending Omarchy update (stock omarchy.system-update): click runs it.
        MIcon {
          readonly property string popout: "update"
          visible: root.cfg.status.update && UpdateService.available
          anchors.horizontalCenter: parent.horizontalCenter
          animate: true
          text: UpdateService.running ? "downloading" : "system_update_alt"
          color: Colours.m3primary
          fill: 1
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: UpdateService.update()
          }
        }

        // Screen recording active indicator
        MIcon {
          visible: RecordService.running
          anchors.horizontalCenter: parent.horizontalCenter
          text: "fiber_manual_record"
          color: Colours.m3error
          fill: 1
          SequentialAnimation on opacity {
            running: RecordService.running
            loops: Animation.Infinite
            NumberAnimation { from: 1; to: 0.2; duration: 600 }
            NumberAnimation { from: 0.2; to: 1; duration: 600 }
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.host.toggle("utilities")
          }
        }

        // Notifications indicator: always there (when enabled) so the sidebar
        // has a target; filled with unread notifications, outlined when empty.
        MIcon {
          visible: root.cfg.status.notifications
          anchors.horizontalCenter: parent.horizontalCenter
          animate: true
          text: NotifService.dnd ? "notifications_off" : NotifService.count > 0 ? "notifications_unread" : "notifications"
          color: NotifService.dnd ? Colours.m3error : Colours.m3secondary
          fill: NotifService.count > 0 || NotifService.dnd ? 1 : 0
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.host.toggle("sidebar")
          }
        }

        // caps/num lock (Caelestia status/LockStatus.qml): each grows in
        // and fades/scales its own icon.
        Column {
          id: lockStatus
          readonly property string popout: "lockstatus"
          readonly property bool caps: root.host.capsLock
          readonly property bool num: root.host.numLock
          property real gap: caps && num ? statusCol.spacing : 0
          property real capsHeight: caps ? capsIcon.implicitHeight : 0
          property real numHeight: num ? numIcon.implicitHeight : 0
          anchors.horizontalCenter: parent.horizontalCenter
          visible: root.cfg.status.lockStatus && (capsHeight > 0.5 || numHeight > 0.5)
          spacing: Math.round(gap)
          Behavior on gap { Anim { type: "slowEffects" } }
          Behavior on capsHeight { Anim { type: "slowEffects" } }
          Behavior on numHeight { Anim { type: "slowEffects" } }
          Item {
            implicitWidth: capsIcon.implicitWidth
            implicitHeight: Math.round(lockStatus.capsHeight)
            MIcon {
              id: capsIcon
              anchors.centerIn: parent
              scale: lockStatus.caps ? 1 : 0.5
              opacity: lockStatus.caps ? 1 : 0
              text: "keyboard_capslock_badge"
              color: Colours.m3secondary
              fill: 1
              grade: 25
              Behavior on opacity { Anim { type: "effects" } }
              Behavior on scale { Anim {} }
            }
          }
          Item {
            implicitWidth: numIcon.implicitWidth
            implicitHeight: Math.round(lockStatus.numHeight)
            MIcon {
              id: numIcon
              anchors.centerIn: parent
              scale: lockStatus.num ? 1 : 0.5
              opacity: lockStatus.num ? 1 : 0
              text: "looks_one"
              color: Colours.m3secondary
              fill: 1
              grade: 25
              Behavior on opacity { Anim { type: "effects" } }
              Behavior on scale { Anim {} }
            }
          }
        }
        MIcon {
          readonly property string popout: "audio"
          readonly property var sink: Pipewire.defaultAudioSink
          readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
          readonly property bool muted: !sink || !sink.audio || sink.audio.muted
          visible: root.cfg.status.audio
          anchors.horizontalCenter: parent.horizontalCenter
          animate: true
          text: muted ? "no_sound" : vol >= 0.5 ? "volume_up" : vol > 0 ? "volume_down" : "volume_mute"
          color: Colours.m3secondary
          size: Tk.iconSize.medium
          fill: 1
        }
        MIcon {
          readonly property string popout: "audio"
          readonly property var src: Pipewire.defaultAudioSource
          readonly property bool muted: !src || !src.audio || src.audio.muted
          // "Only while recording" keeps it out of the way until an app
          // actually opens the microphone.
          visible: root.cfg.status.microphone && (!root.cfg.status.microphoneInUseOnly || AudioService.capturing)
          anchors.horizontalCenter: parent.horizontalCenter
          animate: true
          text: muted ? "mic_off" : "mic"
          color: Colours.m3secondary
          size: Tk.iconSize.medium
          fill: 1
        }
        // Caelestia StatusIcons "kbLayout": the active layout's code in mono.
        // KbService is only touched while the icon is on, so it costs nothing
        // when off (its default, as in Caelestia's barconfig).
        MText {
          readonly property string popout: "kblayout"
          visible: root.cfg.status.kbLayout
          anchors.horizontalCenter: parent.horizontalCenter
          animate: true
          text: root.cfg.status.kbLayout ? KbService.code : ""
          color: Colours.m3secondary
          font.family: Tk.mono
          font.pointSize: Tk.body.medium
        }
        MIcon {
          readonly property string popout: "network"
          visible: root.cfg.status.network
          anchors.horizontalCenter: parent.horizontalCenter
          animate: true
          text: Sys.ethernet ? "cable" : Sys.wifi ? Sys.networkIcon(Sys.strength) : "wifi_off"
          color: Colours.m3secondary
        }
        Column {
          readonly property string popout: "bluetooth"
          // "Only when connected" hides the idle bluetooth glyph.
          visible: root.cfg.status.bluetooth && (!root.cfg.status.bluetoothConnectedOnly
            || Bluetooth.devices.values.some(d => d.connected))
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Tk.spacing.medium / 2
          MIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            animate: true
            readonly property var adapter: Bluetooth.defaultAdapter
            text: !adapter || !adapter.enabled ? "bluetooth_disabled"
              : Bluetooth.devices.values.some(d => d.connected) ? "bluetooth_connected" : "bluetooth"
            color: Colours.m3secondary
          }
          Repeater {
            model: Bluetooth.devices.values.filter(d => d.state !== BluetoothDeviceState.Disconnected)
            MIcon {
              required property var modelData
              anchors.horizontalCenter: parent.horizontalCenter
              text: Sys.bluetoothIcon(modelData.icon)
              color: Colours.m3secondary
              fill: 1
              SequentialAnimation on opacity {
                running: modelData.state !== BluetoothDeviceState.Connected
                alwaysRunToEnd: true
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0; duration: Tk.durations.large; easing.type: Easing.BezierSpline; easing.bezierCurve: Tk.curves.standardAccel }
                NumberAnimation { from: 0; to: 1; duration: Tk.durations.large; easing.type: Easing.BezierSpline; easing.bezierCurve: Tk.curves.standardDecel }
              }
            }
          }
        }
        MIcon {
          readonly property string popout: "battery"
          visible: root.cfg.status.battery
          readonly property var dev: UPower.displayDevice
          readonly property bool laptop: dev && dev.isLaptopBattery
          readonly property bool charging: dev && [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].indexOf(dev.state) >= 0
          anchors.horizontalCenter: parent.horizontalCenter
          animate: true
          text: !laptop ? (PowerProfiles.profile === PowerProfile.PowerSaver ? "energy_savings_leaf"
                         : PowerProfiles.profile === PowerProfile.Performance ? "rocket_launch" : "balance")
                        : Sys.batteryIcon(dev.percentage, charging)
          color: !UPower.onBattery || !dev || dev.percentage > 0.2 ? Colours.m3secondary : Colours.m3error
          fill: 1
        }
      }
    }

    // --------------------------------------------------------- power
    Item {
      visible: root.cfg.power
      Layout.alignment: Qt.AlignHCenter
      implicitWidth: powerIcon.implicitHeight + Tk.padding.small
      implicitHeight: powerIcon.implicitHeight
      Item {
        anchors.centerIn: parent
        width: powerIcon.implicitHeight + Tk.padding.small
        height: width
        property real radius: width / 2
        StateLayer { onClicked: root.host.toggle("session") }
      }
      MIcon {
        id: powerIcon
        anchors.centerIn: parent
        text: "power_settings_new"
        color: Colours.m3error
        weight: 700
      }
    }
  }

  // Dedicated Caelestia pill for 3rd-party bar widgets (installed in
  // ~/.config/omarchy/plugins/), laid out like the status pill: same padding,
  // same spacing, one status-icon cell per widget (BarWidgetSlot scales each
  // widget's mark to the status icons' size). Sits on pluginPlace.
  //
  // Pinned widgets (Settings › Taskbar › Plugins) always show; the others
  // wait behind a chevron that hovering expands, like the compact tray.
  Rectangle {
    id: pluginPill
    readonly property var pluginsList: root.host.thirdPartyPlugins || []
    readonly property var unpinned: root.cfg.plugins.unpinned
    readonly property bool anyShown: pluginCol.implicitHeight - pluginCol.topPadding - pluginCol.bottomPadding > 0.5
    property bool expanded: false
    onOverflowCountChanged: if (overflowCount === 0) expanded = false

    // Counted by hand: Repeater.itemAt is not a binding dependency, so every
    // slot asks for a recount when its size, content or pin changes.
    property int overflowCount: 0
    property real pinnedHeight: 0
    function recount() { countTimer.restart() }
    Timer {
      id: countTimer
      interval: 0
      onTriggered: {
        let n = 0, h = 0
        for (let i = 0; i < pluginRep.count; i++) {
          const slot = pluginRep.itemAt(i)
          if (!slot || !slot.shown) continue
          if (slot.pinned) h += Math.round(slot.visualHeight) + pluginCol.spacing
          else n++
        }
        pluginPill.overflowCount = n
        pluginPill.pinnedHeight = h
      }
    }
    // The pill's height with the overflow closed: what the budget plans for.
    readonly property real collapsedHeight: overflowCount === 0 && pinnedHeight === 0 ? 0
      : pluginCol.topPadding + pluginCol.bottomPadding + pinnedHeight
        + (overflowCount > 0 ? overflowIcon.implicitHeight : -pluginCol.spacing)

    visible: root.cfg.plugins.enabled !== false && pluginsList.length > 0
    opacity: anyShown ? 1 : 0
    x: col.x + pluginPlace.x
    y: col.y + pluginPlace.y
    width: Tk.barInner
    // Capped by the space budget, leaving the tray its (collapsed) share.
    implicitHeight: anyShown ? Math.min(Math.max(collapsedHeight, root.budget - root.trayReserve), pluginCol.implicitHeight) : 0
    height: implicitHeight
    radius: width / 2
    color: Colours.m3surfaceContainer
    clip: true

    Behavior on implicitHeight { Anim {} }

    Timer {
      id: collapsePluginsTimer
      interval: 400
      onTriggered: pluginPill.expanded = false
    }

    // A status icon's height, so a plugin cell matches the status pill's.
    MIcon { id: cellRef; visible: false; text: "extension" }

    // More widgets than fit scroll rather than being cut off.
    MFlickable {
      anchors.fill: parent
      contentWidth: width
      contentHeight: pluginCol.implicitHeight
      interactive: contentHeight > height + 0.5

      Column {
        id: pluginCol
        width: parent.width
        topPadding: Tk.padding.medium
        bottomPadding: Tk.padding.medium
        spacing: Tk.spacing.medium / 2

        Repeater {
          id: pluginRep
          model: pluginPill.pluginsList

          BarWidgetSlot {
            required property var modelData
            pinned: pluginPill.unpinned.indexOf(moduleName) < 0
            entry: modelData
            host: root.host
            cellHeight: cellRef.implicitHeight
            collapsed: !pinned && !pluginPill.expanded
            onShownChanged: pluginPill.recount()
            onPinnedChanged: pluginPill.recount()
            onVisualHeightChanged: pluginPill.recount()
            Component.onCompleted: pluginPill.recount()
            Component.onDestruction: pluginPill.recount()
          }
        }

        // Caelestia's tray chevron, for the widgets that aren't pinned.
        Item {
          width: parent.width
          height: pluginPill.overflowCount > 0 ? overflowIcon.implicitHeight : 0
          MIcon {
            id: overflowIcon
            anchors.centerIn: parent
            visible: pluginPill.overflowCount > 0
            text: "expand_less"
            size: Tk.iconSize.medium
            color: Colours.m3onSurfaceVariant
            rotation: pluginPill.expanded ? 180 : 0
            Behavior on rotation { Anim {} }
          }
          MouseArea {
            anchors.fill: parent
            enabled: pluginPill.overflowCount > 0
            cursorShape: Qt.PointingHandCursor
            onClicked: { collapsePluginsTimer.stop(); pluginPill.expanded = !pluginPill.expanded }
          }
        }
      }
    }
  }
}
