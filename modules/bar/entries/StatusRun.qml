import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import "../../.."

// A pill of status icons (Caelestia bar/components/StatusIcons.qml). The
// default layout has one run with every icon; moving icons apart in
// Settings › Taskbar › Layout gives each group of neighbours its own run.
Rectangle {
  id: run
  required property var bar
  // The status icons in this pill, in order (BarLayout.STATUS ids). Icons
  // next to each other in a bar section share one pill.
  property var ids: []
  property string entryId: "status:" + ids.join(",")
  readonly property int anchorsPad: Tk.padding.medium
  // Not `statusCol.visibleChildren`: while the bar is hidden (fullscreen)
  // every child reads invisible, the pill hides, and its children then
  // stay invisible for good, so the pill never came back.
  readonly property var st: bar.cfg.status
  // Set by the lock icon while it is still folding away.
  property bool lockShown: false
  function on(id) {
    switch (id) {
    case "keepAwake": return st.keepAwake && IdleService.enabled
    case "update": return st.update && UpdateService.available
    case "recording": return RecordService.running
    case "lockStatus": return st.lockStatus && (bar.host.capsLock || bar.host.numLock || lockShown)
    default: return !!st[id]
    }
  }
  readonly property bool shown: ids.some(id => on(id))
  visible: shown
  Layout.alignment: bar.crossAlign
  implicitWidth: bar.vertical ? Tk.barInner : statusCol.implicitWidth + Tk.padding.medium * 2
  implicitHeight: bar.vertical ? statusCol.implicitHeight + Tk.padding.medium * 2 : Tk.barInner
  radius: (bar.vertical ? width : height) / 2
  color: Colours.m3surfaceContainer
  clip: true
  Behavior on implicitHeight { enabled: bar.vertical; Anim {} }
  Behavior on implicitWidth { enabled: !bar.vertical; Anim {} }

  // Every icon sits in its own cell, centred across the bar. Filled from
  // the pill's far end, so a new one grows in from the inner side.
  GridLayout {
    id: statusCol
    readonly property real gapPx: Tk.spacing.medium / 2
    x: bar.vertical ? Math.round((parent.width - width) / 2) : parent.width - width - Tk.padding.medium
    y: bar.vertical ? parent.height - height - Tk.padding.medium : Math.round((parent.height - height) / 2)
    columns: bar.vertical ? 1 : -1
    rows: bar.vertical ? -1 : 1
    flow: bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    rowSpacing: gapPx
    columnSpacing: gapPx

    // One cell per id. The cell's visibility mirrors the icon's own `want`,
    // never its effective `visible`, so a hidden pill can't latch it hidden.
    Repeater {
      id: rep
      model: run.ids
      Loader {
        required property string modelData
        Layout.alignment: Qt.AlignCenter
        sourceComponent: run["c_" + modelData] || null
        visible: !!item && item.want
      }
    }
  }

  // The icons, as they are drawn in the pill (Caelestia bar/components/StatusIcons.qml).
    // Keep awake indicator
  property Component c_keepAwake: Component {
      MIcon {
        readonly property bool want: bar.cfg.status.keepAwake && IdleService.enabled
        visible: want
        Layout.alignment: Qt.AlignCenter
        text: "coffee"
        color: Colours.m3secondary
        fill: 1
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: bar.host.toggle("utilities")
        }
      }
  }

    // Pending Omarchy update (stock omarchy.system-update): click runs it.
  property Component c_update: Component {
      MIcon {
        readonly property string popout: "update"
        readonly property bool want: bar.cfg.status.update && UpdateService.available
        visible: want
        Layout.alignment: Qt.AlignCenter
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
  }

    // Screen recording active indicator
  property Component c_recording: Component {
      MIcon {
        readonly property bool want: RecordService.running
        visible: want
        Layout.alignment: Qt.AlignCenter
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
          onClicked: bar.host.toggle("utilities")
        }
      }
  }

    // Notifications indicator: always there (when enabled) so the sidebar
    // has a target; filled with unread notifications, outlined when empty.
  property Component c_notifications: Component {
      MIcon {
        readonly property bool want: bar.cfg.status.notifications
        visible: want
        Layout.alignment: Qt.AlignCenter
        animate: true
        text: NotifService.dnd ? "notifications_off" : NotifService.count > 0 ? "notifications_unread" : "notifications"
        color: NotifService.dnd ? Colours.m3error : Colours.m3secondary
        fill: NotifService.count > 0 || NotifService.dnd ? 1 : 0
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: bar.host.toggle("sidebar")
        }
      }
  }

    // caps/num lock (Caelestia status/LockStatus.qml): each grows in
    // and fades/scales its own icon.
  property Component c_lockStatus: Component {
      GridLayout {
        id: lockStatus
        readonly property string popout: "lockstatus"
        readonly property bool caps: bar.host.capsLock
        readonly property bool num: bar.host.numLock
        property real gap: caps && num ? statusCol.gapPx : 0
        // How much of the bar each icon takes, along it.
        property real capsLen: caps ? (bar.vertical ? capsIcon.implicitHeight : capsIcon.implicitWidth) : 0
        property real numLen: num ? (bar.vertical ? numIcon.implicitHeight : numIcon.implicitWidth) : 0
        Layout.alignment: Qt.AlignCenter
        readonly property bool want: bar.cfg.status.lockStatus && (capsLen > 0.5 || numLen > 0.5)
        onWantChanged: run.lockShown = want
        Component.onCompleted: run.lockShown = want
        visible: want
        columns: bar.vertical ? 1 : -1
        rows: bar.vertical ? -1 : 1
        flow: bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: Math.round(gap)
        columnSpacing: Math.round(gap)
        Behavior on gap { Anim { type: "slowEffects" } }
        Behavior on capsLen { Anim { type: "slowEffects" } }
        Behavior on numLen { Anim { type: "slowEffects" } }
        Item {
          implicitWidth: bar.vertical ? capsIcon.implicitWidth : Math.round(lockStatus.capsLen)
          implicitHeight: bar.vertical ? Math.round(lockStatus.capsLen) : capsIcon.implicitHeight
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
          implicitWidth: bar.vertical ? numIcon.implicitWidth : Math.round(lockStatus.numLen)
          implicitHeight: bar.vertical ? Math.round(lockStatus.numLen) : numIcon.implicitHeight
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
  }

  property Component c_audio: Component {
      MIcon {
        readonly property string popout: "audio"
        readonly property var sink: Pipewire.defaultAudioSink
        readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
        readonly property bool muted: !sink || !sink.audio || sink.audio.muted
        readonly property bool want: bar.cfg.status.audio
        visible: want
        Layout.alignment: Qt.AlignCenter
        animate: true
        text: muted ? "no_sound" : vol >= 0.5 ? "volume_up" : vol > 0 ? "volume_down" : "volume_mute"
        color: Colours.m3secondary
        size: Tk.iconSize.medium
        fill: 1
      }
  }

  property Component c_microphone: Component {
      MIcon {
        readonly property string popout: "audio"
        readonly property var src: Pipewire.defaultAudioSource
        readonly property bool muted: !src || !src.audio || src.audio.muted
        // "Only while recording" keeps it out of the way until an app
        // actually opens the microphone.
        readonly property bool want: bar.cfg.status.microphone && (!bar.cfg.status.microphoneInUseOnly || AudioService.capturing)
        visible: want
        Layout.alignment: Qt.AlignCenter
        animate: true
        text: muted ? "mic_off" : "mic"
        color: Colours.m3secondary
        size: Tk.iconSize.medium
        fill: 1
      }
  }

    // Caelestia StatusIcons "kbLayout": the active layout's code in mono.
    // KbService is only touched while the icon is on, so it costs nothing
    // when off (its default, as in Caelestia's barconfig).
  property Component c_kbLayout: Component {
      MText {
        readonly property string popout: "kblayout"
        readonly property bool want: bar.cfg.status.kbLayout
        visible: want
        Layout.alignment: Qt.AlignCenter
        animate: true
        text: bar.cfg.status.kbLayout ? KbService.code : ""
        color: Colours.m3secondary
        font.family: Tk.mono
        font.pointSize: Tk.body.medium
      }
  }

  property Component c_network: Component {
      MIcon {
        readonly property string popout: "network"
        readonly property bool want: bar.cfg.status.network
        visible: want
        Layout.alignment: Qt.AlignCenter
        animate: true
        text: Sys.ethernet ? "cable" : Sys.wifi ? Sys.networkIcon(Sys.strength) : "wifi_off"
        color: Colours.m3secondary
      }
  }

  property Component c_bluetooth: Component {
      GridLayout {
        readonly property string popout: "bluetooth"
        // "Only when connected" hides the idle bluetooth glyph.
        readonly property bool want: bar.cfg.status.bluetooth && (!bar.cfg.status.bluetoothConnectedOnly || Bluetooth.devices.values.some(d => d.connected))
        visible: want
        Layout.alignment: Qt.AlignCenter
        columns: bar.vertical ? 1 : -1
        rows: bar.vertical ? -1 : 1
        flow: bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: statusCol.gapPx
        columnSpacing: statusCol.gapPx
        MIcon {
          Layout.alignment: Qt.AlignCenter
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
            Layout.alignment: Qt.AlignCenter
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
  }

  property Component c_battery: Component {
      MIcon {
        readonly property string popout: "battery"
        readonly property bool want: bar.cfg.status.battery
        visible: want
        readonly property var dev: UPower.displayDevice
        readonly property bool laptop: dev && dev.isLaptopBattery
        readonly property bool charging: dev && [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].indexOf(dev.state) >= 0
        Layout.alignment: Qt.AlignCenter
        animate: true
        text: !laptop ? (PowerProfiles.profile === PowerProfile.PowerSaver ? "energy_savings_leaf"
                       : PowerProfiles.profile === PowerProfile.Performance ? "rocket_launch" : "balance")
                      : Sys.batteryIcon(dev.percentage, charging)
        color: !UPower.onBattery || !dev || dev.percentage > 0.2 ? Colours.m3secondary : Colours.m3error
        fill: 1
      }
  }

  // The cells on show, in bar order: { cell (the Loader), icon (its item) }.
  function cells() {
    const out = []
    for (let i = 0; i < rep.count; i++) {
      const l = rep.itemAt(i)
      if (l && l.visible && l.item) out.push({ cell: l, icon: l.item })
    }
    return out
  }
  function navStops() {
    const out = []
    for (const c of cells()) {
      const it = c.icon
      if (it.popout && it.popout !== "update") out.push({ item: it, act: () => bar.scope.openPopoutKeys(it.popout) })
      else {
        const area = [...it.children].find(k => k instanceof MouseArea)
        if (area) out.push({ item: it, act: () => { bar.scope.barFocus = false; area.clicked(null) } })
      }
    }
    return out
  }
  function popoutAt(a) {
    const p = bar.pointAlong(bar.pointOn(statusCol, a))
    if (!bar.cfg.popouts.statusIcons || !visible || p < -anchorsPad || p > bar.alen(statusCol) + anchorsPad) return null
    for (const c of cells()) {
      if (!c.icon.popout) continue
      if (p >= bar.apos(c.cell) - 3 && p <= bar.apos(c.cell) + bar.alen(c.cell) + 3)
        return { name: c.icon.popout, center: bar.centreOf(c.cell) }
    }
    return null
  }
  function popoutCenterFor(name) {
    for (const c of cells())
      if (c.icon.popout === name) return bar.centreOf(c.cell)
    return undefined
  }
  function statusPopouts() {
    const out = []
    for (const c of cells())
      if (c.icon.popout && out.indexOf(c.icon.popout) < 0) out.push(c.icon.popout)
    return out
  }
}
