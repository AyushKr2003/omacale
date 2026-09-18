import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Bluetooth

// The Caelestia bar: logo, workspaces, active window, tray, clock, status
// icons, power — in Caelestia's default order and metrics.
Item {
  id: root

  required property var screen
  required property var host
  required property var scope

  readonly property int vPadding: Tk.padding.large

  // Popout lookup for a y coordinate on the bar (Caelestia Bar.checkPopout).
  function popoutAt(y) {
    const p = mapToItem(statusCol, 0, y)
    if (p.y >= -statusPill.anchorsPad && p.y <= statusCol.height + statusPill.anchorsPad) {
      for (let i = 0; i < statusCol.children.length; i++) {
        const c = statusCol.children[i]
        if (!c.visible || !c.popout) continue
        if (p.y >= c.y - 3 && p.y <= c.y + c.height + 3)
          return { name: c.popout, center: c.mapToItem(root, 0, c.height / 2).y }
      }
    }
    const t = mapToItem(trayCol, 0, y)
    if (trayCol.visible && t.y >= 0 && t.y <= trayCol.height) {
      for (let i = 0; i < trayRep.count; i++) {
        const it = trayRep.itemAt(i)
        if (t.y >= it.y - 4 && t.y <= it.y + it.height + 4)
          return { name: "traymenu", index: i, item: it.modelData, center: it.mapToItem(root, 0, it.height / 2).y }
      }
    }
    const w = mapToItem(activeWin, 0, y)
    if (activeWin.visible && w.y >= 0 && w.y <= activeWin.height && Hyprland.activeToplevel)
      return { name: "activewindow", center: activeWin.mapToItem(root, 0, activeWin.height / 2).y }
    return null
  }

  function handleWheel(y, dy) {
    const ws = mapToItem(workspaces, 0, y)
    if (ws.y >= 0 && ws.y <= workspaces.height) { Sys.workspace(dy > 0 ? "r-1" : "r+1"); return }
    if (y < height / 2) Sys.run(dy > 0 ? "swayosd-client --output-volume raise || wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
                                       : "swayosd-client --output-volume lower || wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")
    else Sys.run(dy > 0 ? "swayosd-client --brightness raise || brightnessctl set 5%+" : "swayosd-client --brightness lower || brightnessctl set 5%-")
  }

  SystemClock { id: clock; precision: SystemClock.Minutes }

  ColumnLayout {
    id: col
    anchors.fill: parent
    anchors.topMargin: root.vPadding
    anchors.bottomMargin: root.vPadding
    spacing: Tk.spacing.medium

    // ---------------------------------------------------------- logo
    Item {
      Layout.alignment: Qt.AlignHCenter
      implicitWidth: Math.round(Tk.body.large * 1.2)
      implicitHeight: implicitWidth
      ColouredIcon {
        anchors.centerIn: parent
        implicitSize: parent.width
        source: "file://" + root.host.omarchyPath + "/icon.png"
        colour: Colours.m3tertiary
      }
      MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: root.host.toggle("launcher")
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
        readonly property var tl: Hyprland.activeToplevel
        readonly property string title: tl && tl.title ? tl.title : "Desktop"
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
    Column {
      id: trayCol
      Layout.alignment: Qt.AlignHCenter
      visible: trayRep.count > 0
      topPadding: Tk.padding.extraSmall
      bottomPadding: Tk.padding.extraSmall
      spacing: Tk.spacing.small
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
          Image {
            anchors.fill: parent
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

    // --------------------------------------------------------- clock
    Column {
      Layout.alignment: Qt.AlignHCenter
      topPadding: Tk.padding.extraSmall
      bottomPadding: Tk.padding.extraSmall
      spacing: 0
      MIcon {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "calendar_month"
        color: Colours.m3tertiary
        bottomPadding: Tk.spacing.extraSmall
      }
      MText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatTime(clock.date, "HH")
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
    }

    // --------------------------------------------------- status icons
    Rectangle {
      id: statusPill
      readonly property int anchorsPad: Tk.padding.medium
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

        // caps/num lock
        MIcon {
          readonly property string popout: "lockstatus"
          anchors.horizontalCenter: parent.horizontalCenter
          visible: root.host.capsLock || root.host.numLock
          text: root.host.capsLock ? "keyboard_capslock_badge" : "looks_one"
          color: Colours.m3secondary
        }
        MIcon {
          readonly property string popout: "network"
          anchors.horizontalCenter: parent.horizontalCenter
          animate: true
          text: Sys.ethernet ? "cable" : Sys.wifi ? Sys.networkIcon(Sys.strength) : "wifi_off"
          color: Colours.m3secondary
        }
        Column {
          readonly property string popout: "bluetooth"
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
