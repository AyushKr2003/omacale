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
    if (cfg.popouts.activeWindow && activeWin.visible && w.y >= 0 && w.y <= activeWin.height && Hyprland.activeToplevel)
      return { name: "activewindow", center: activeWin.mapToItem(root, 0, activeWin.height / 2).y }
    return null
  }

  function handleWheel(y, dy) {
    const ws = mapToItem(workspaces, 0, y)
    if (ws.y >= 0 && ws.y <= workspaces.height) { if (cfg.scroll.workspaces) Sys.workspace(dy > 0 ? "r-1" : "r+1"); return }
    if (y < height / 2) { if (cfg.scroll.volume) Sys.run(dy > 0 ? "swayosd-client --output-volume raise || wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
                                       : "swayosd-client --output-volume lower || wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-") }
    else if (cfg.scroll.brightness) Sys.run(dy > 0 ? "swayosd-client --brightness raise || brightnessctl set 5%+" : "swayosd-client --brightness lower || brightnessctl set 5%-")
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
    Item {
      visible: root.cfg.logo
      Layout.alignment: Qt.AlignHCenter
      implicitWidth: Math.round(Tk.body.large * 1.2)
      implicitHeight: implicitWidth
      LogoIcon {
        anchors.centerIn: parent
        value: root.cfg.logoIcon
        size: parent.width
        omarchyPath: root.host.omarchyPath
        colour: Colours.m3tertiary
      }
      MouseArea {
        anchors.fill: parent
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
        readonly property var tl: Hyprland.activeToplevel
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
        TextMetrics {
          id: metrics
          text: activeWin.title
          font.family: Tk.sans
          font.pointSize: Tk.body.small
          font.letterSpacing: 1.4
          elide: Qt.ElideRight
          elideWidth: Math.max(0, activeWin.maxLen)
        }
        MText {
          id: titleText
          animate: true
          anchors.top: winIcon.bottom
          anchors.topMargin: Tk.spacing.small
          anchors.horizontalCenter: winIcon.horizontalCenter
          width: implicitHeight
          height: implicitWidth
          text: metrics.elidedText
          font.letterSpacing: 1.4
          color: Colours.m3primary
          transform: Rotation { angle: 90; origin.x: titleText.implicitHeight / 2; origin.y: titleText.implicitHeight / 2 }
        }
      }
    }

    // ---------------------------------------------------------- tray
    Rectangle {
      Layout.alignment: Qt.AlignHCenter
      visible: root.cfg.tray.enabled && trayRep.count > 0
      implicitWidth: Tk.barInner
      implicitHeight: trayCol.implicitHeight
      radius: width / 2
      color: root.cfg.tray.background ? Colours.m3surfaceContainer : "transparent"
    Column {
      id: trayCol
      anchors.horizontalCenter: parent.horizontalCenter
      topPadding: root.cfg.tray.background ? Tk.padding.medium : Tk.padding.extraSmall
      bottomPadding: topPadding
      spacing: root.cfg.tray.background ? Tk.spacing.medium : Tk.spacing.small
      Repeater {
        id: trayRep
        model: SystemTray.items.values.filter(i => i.status !== Status.Passive)
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
      Column {
        id: clockCol
        anchors.centerIn: parent
        spacing: 0
        MIcon {
          visible: root.cfg.clock.showIcon
          anchors.horizontalCenter: parent.horizontalCenter
          text: "calendar_month"
          color: Colours.m3tertiary
          bottomPadding: Tk.spacing.extraSmall
        }
        Column {
          visible: root.cfg.clock.showDate
          anchors.horizontalCenter: parent.horizontalCenter
          bottomPadding: Tk.spacing.extraSmall
          MText { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(clock.date, "ddd"); font.pointSize: Tk.body.small * 0.9; color: Colours.m3tertiary }
          MText { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(clock.date, "d"); font.pointSize: Tk.body.small * 1.2; color: Colours.m3tertiary }
          Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 22; height: 1; color: Colours.m3outlineVariant }
        }
        MText {
          anchors.horizontalCenter: parent.horizontalCenter
          text: Sys.hour(clock.date)
          font.pointSize: Tk.body.small * 1.1
          color: Colours.m3tertiary
        }
        MText {
          anchors.horizontalCenter: parent.horizontalCenter
          topPadding: -4
          text: Qt.formatTime(clock.date, "mm")
          font.pointSize: Tk.body.small * 1.1
          color: Colours.m3tertiary
        }
        MText {
          visible: root.cfg.clock.showSeconds
          anchors.horizontalCenter: parent.horizontalCenter
          topPadding: -4
          text: Qt.formatTime(clock.date, "ss")
          font.pointSize: Tk.body.small * 1.1
          color: Colours.m3tertiary
        }
        MText {
          visible: parent.parent.h12
          anchors.horizontalCenter: parent.horizontalCenter
          topPadding: -4
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
      visible: statusCol.visibleChildren.length > 0
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

        // caps/num lock
        MIcon {
          readonly property string popout: "lockstatus"
          anchors.horizontalCenter: parent.horizontalCenter
          visible: root.cfg.status.lockStatus && (root.host.capsLock || root.host.numLock)
          text: root.host.capsLock ? "keyboard_capslock_badge" : "looks_one"
          color: Colours.m3secondary
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
