import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire

// The Caelestia bar: logo, workspaces, active window, tray, clock, status
// icons, power — in Caelestia's default order and metrics.
Item {
  id: root

  required property var screen
  required property var host
  required property var scope

  readonly property int vPadding: Tk.padding.large
  readonly property var cfg: Config.o.bar

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
    if (cfg.popouts.tray && trayCol.visible && t.y >= 0 && t.y <= trayCol.height) {
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
    // Dedicated Caelestia pill for 3rd-party bar widgets (installed in
    // ~/.config/omarchy/plugins/).  Renders each widget's icon directly,
    // with Caelestia's standard m3surfaceContainer rounded pill styling.
    Rectangle {
      id: pluginPill
      Layout.alignment: Qt.AlignHCenter
      readonly property var pluginsList: root.host.thirdPartyPlugins
      visible: (root.cfg.plugins ? root.cfg.plugins.enabled !== false : true) && pluginsList && pluginsList.length > 0

      implicitWidth: Tk.barInner
      implicitHeight: Math.min(maxHeight, pluginCol.implicitHeight + Tk.padding.extraSmall * 2)
      radius: width / 2
      color: Colours.m3surfaceContainer
      clip: true

      Behavior on implicitHeight { Anim {} }

      readonly property real maxHeight: Math.max(120, col.height * 0.35)

      Column {
        id: pluginCol
        anchors.horizontalCenter: parent.horizontalCenter
        topPadding: Tk.padding.extraSmall
        bottomPadding: topPadding
        spacing: Tk.spacing.small

        Repeater {
          id: pluginRep
          model: pluginPill.pluginsList

          BarWidgetSlot {
            required property var modelData
            entry: modelData
            host: root.host
            bar: root.host.pluginBarFacadeFor(root.host.entryId(modelData))
          }
        }
      }
    }

    // ---------------------------------------------------------- tray
    Rectangle {
      id: trayPill
      Layout.alignment: Qt.AlignHCenter
      readonly property var trayItems: SystemTray.items.values.filter(i => i.status !== Status.Passive)
      visible: root.cfg.tray.enabled && trayItems.length > 0
      implicitWidth: Tk.barInner

      property bool compact: (root.cfg.tray && root.cfg.tray.compact) || trayItems.length > 4
      property bool expanded: false

      implicitHeight: {
        if (!visible) return 0
        if (!compact) return Math.min(maxHeight, trayCol.implicitHeight + (root.cfg.tray.background ? Tk.padding.medium : Tk.padding.extraSmall) * 2)
        if (expanded) return Math.min(maxHeight, trayCol.implicitHeight + expandTrayBtn.implicitHeight + Tk.padding.medium * 2 + Tk.spacing.small)
        return width
      }
      radius: width / 2
      color: root.cfg.tray.background ? Colours.m3surfaceContainer : "transparent"
      clip: true
      Behavior on implicitHeight { Anim {} }

      readonly property real maxHeight: Math.max(120, col.height * 0.35)

      HoverHandler {
        id: trayHover
        onHoveredChanged: {
          if (hovered) {
            collapseTrayTimer.stop()
            if (trayPill.compact) trayPill.expanded = true
          } else {
            if (trayPill.compact) collapseTrayTimer.restart()
          }
        }
      }
      Timer {
        id: collapseTrayTimer
        interval: 400
        repeat: false
        onTriggered: {
          if (!trayHover.hovered) trayPill.expanded = false
        }
      }

      Flickable {
        id: trayFlick
        anchors.fill: parent
        anchors.topMargin: root.cfg.tray.background ? Tk.padding.medium : Tk.padding.extraSmall
        anchors.bottomMargin: trayPill.compact ? (expandTrayBtn.implicitHeight + Tk.padding.small) : (root.cfg.tray.background ? Tk.padding.medium : Tk.padding.extraSmall)
        contentHeight: trayCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: trayCol
          anchors.horizontalCenter: parent.horizontalCenter
          topPadding: root.cfg.tray.background ? Tk.padding.medium : Tk.padding.extraSmall
          bottomPadding: topPadding
          spacing: root.cfg.tray.background ? Tk.spacing.medium : Tk.spacing.small
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

      // Compact trigger icon / chevron
      Item {
        id: expandTrayBtn
        visible: trayPill.compact
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: Tk.barInner
        height: trayPill.expanded ? (expandTrayIcon.implicitHeight + Tk.padding.small) : parent.height

        MIcon {
          id: expandTrayIcon
          anchors.centerIn: parent
          text: trayPill.expanded ? "expand_less" : "expand_more"
          color: Colours.m3onSurfaceVariant
          rotation: trayPill.expanded ? 180 : 0
          Behavior on rotation { Anim {} }
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            collapseTrayTimer.stop()
            trayPill.expanded = !trayPill.expanded
          }
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
      visible: (st.keepAwake && IdleService.enabled) || RecordService.running || st.notifications
        || (st.lockStatus && (root.host.capsLock || root.host.numLock || lockStatus.visible))
        || st.audio || st.microphone || st.network || st.bluetooth || st.battery
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
          visible: root.cfg.status.microphone
          anchors.horizontalCenter: parent.horizontalCenter
          animate: true
          text: muted ? "mic_off" : "mic"
          color: Colours.m3secondary
          size: Tk.iconSize.medium
          fill: 1
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
          visible: root.cfg.status.bluetooth
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
}
