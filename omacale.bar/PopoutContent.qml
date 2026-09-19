import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire

// Contents of the bar popouts (network, bluetooth, battery, lock status,
// tray menus, active-window preview). Sized by the current page.
Item {
  id: root

  property var host
  property string name: ""
  property var trayItem: null
  signal closeRequested()

  readonly property Item current: loader.item
  implicitWidth: current ? current.implicitWidth : 0
  implicitHeight: current ? current.implicitHeight : 0

  Loader {
    id: loader
    anchors.fill: parent
    sourceComponent: ({
      network: network, bluetooth: bluetooth, battery: battery, audio: audio,
      lockstatus: lockstatus, traymenu: traymenu, activewindow: activewindow
    })[root.name] || null
  }

  component Heading: MText {
    Layout.topMargin: Tk.padding.medium
    font.pointSize: Tk.body.medium
    weight: Font.Medium
  }
  component Sub: MText {
    Layout.topMargin: Tk.spacing.small
    color: Colours.m3onSurfaceVariant
  }
  component RoundAction: Rectangle {
    id: ra
    property string icon
    property bool active
    property bool busy
    signal clicked()
    implicitWidth: implicitHeight
    implicitHeight: raIcon.implicitHeight + Tk.padding.extraSmall
    radius: height / 2
    color: Qt.alpha(Colours.m3primary, active ? 1 : 0)
    StateLayer { color: ra.active ? Colours.m3onPrimary : Colours.m3onSurface; disabled: ra.busy; onClicked: ra.clicked() }
    MIcon { id: raIcon; anchors.centerIn: parent; animate: true; text: ra.icon; color: ra.active ? Colours.m3onPrimary : Colours.m3onSurface }
  }
  component WideButton: Rectangle {
    id: wb
    property string icon
    property string label
    signal clicked()
    Layout.fillWidth: true
    Layout.topMargin: Tk.spacing.small
    implicitHeight: wbRow.implicitHeight + Tk.padding.small
    radius: height / 2
    color: Colours.m3primaryContainer
    StateLayer { color: Colours.m3onPrimaryContainer; onClicked: wb.clicked() }
    RowLayout {
      id: wbRow
      anchors.centerIn: parent
      spacing: Tk.spacing.small
      MIcon { text: wb.icon; color: Colours.m3onPrimaryContainer }
      MText { text: wb.label; color: Colours.m3onPrimaryContainer }
    }
  }

  // ------------------------------------------------------------ network
  Component {
    id: network
    ColumnLayout {
      implicitWidth: Tk.sizes.networkWidth
      spacing: Tk.spacing.small
      Heading { text: Sys.ethernet && !Sys.wifi ? "Ethernet" : "Wireless" }
      Toggle {
        label: "Enabled"
        checked: Sys.wifi || Sys.networks.length > 0
        onToggled: c => Sys.run("nmcli radio wifi " + (c ? "on" : "off"))
      }
      Sub { text: Sys.networks.length + (Sys.networks.length === 1 ? " network available" : " networks available") }
      Repeater {
        model: Sys.networks.slice(0, 8)
        RowLayout {
          id: ap
          required property var modelData
          Layout.fillWidth: true
          Layout.rightMargin: Tk.padding.extraSmall
          spacing: Tk.spacing.small
          opacity: 0; scale: 0.7
          Component.onCompleted: { opacity = 1; scale = 1 }
          Behavior on opacity { Anim { type: "effects" } }
          Behavior on scale { Anim {} }
          MIcon { text: Sys.networkIcon(ap.modelData.strength); color: ap.modelData.active ? Colours.m3primary : Colours.m3onSurfaceVariant }
          MIcon { visible: ap.modelData.secure; text: "lock"; size: Tk.iconSize.small }
          MText {
            Layout.leftMargin: Tk.spacing.extraSmall
            Layout.rightMargin: Tk.spacing.extraSmall
            Layout.fillWidth: true
            text: ap.modelData.ssid
            elide: Text.ElideRight
            font.pointSize: Tk.body.medium
            weight: ap.modelData.active ? Font.Medium : Font.Normal
            color: ap.modelData.active ? Colours.m3primary : Colours.m3onSurface
          }
          RoundAction {
            readonly property var net: NetService.networkFor(ap.modelData.ssid)
            icon: ap.modelData.active ? "link_off" : "link"
            active: ap.modelData.active
            busy: NetService.busy && NetService.actionSsid === ap.modelData.ssid
            onClicked: {
              if (!net) return
              if (ap.modelData.active) { NetService.disconnect(net); return }
              // Saved or open networks connect here; anything that needs a
              // password opens Settings › Network with its prompt already
              // expanded (Caelestia shows a password popout instead).
              NetService.activate(net)
              if (NetService.passwordSsid === net.name) { root.host.toggle("settings", "network"); root.closeRequested() }
            }
          }
        }
      }
      WideButton {
        Layout.bottomMargin: Tk.padding.small
        icon: "wifi_find"; label: "Rescan networks"
        onClicked: Sys.run("nmcli device wifi rescan")
      }
    }
  }

  // -------------------------------------------------------------- audio
  Component {
    id: audio
    ColumnLayout {
      implicitWidth: Tk.sizes.audioWidth
      spacing: Tk.spacing.medium
      readonly property var sink: Pipewire.defaultAudioSink
      readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio && !n.isStream)
      PwObjectTracker { objects: [sink] }
      component Radio: RowLayout {
        id: rb
        property string label
        property bool checked
        signal clicked()
        Layout.fillWidth: true
        spacing: Tk.spacing.medium
        Rectangle {
          width: 20; height: 20; radius: 10
          color: "transparent"
          border.width: 2
          border.color: rb.checked ? Colours.m3primary : Colours.m3onSurfaceVariant
          Behavior on border.color { CAnim {} }
          Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: Colours.m3primary; opacity: rb.checked ? 1 : 0; Behavior on opacity { Anim { type: "effects" } } }
          Item { anchors.fill: parent; anchors.margins: -Tk.padding.small; property real radius: width / 2
            StateLayer { color: rb.checked ? Colours.m3onSurface : Colours.m3primary; onClicked: rb.clicked() } }
        }
        MText { Layout.fillWidth: true; text: rb.label; elide: Text.ElideRight }
      }
      Heading { text: "Output device" }
      Repeater {
        model: parent.nodes.filter(n => n.isSink)
        Radio { required property var modelData; label: modelData.description || modelData.name; checked: Pipewire.defaultAudioSink === modelData; onClicked: Pipewire.preferredDefaultAudioSink = modelData }
      }
      Heading { text: "Input device" }
      Repeater {
        model: parent.nodes.filter(n => !n.isSink)
        Radio { required property var modelData; label: modelData.description || modelData.name; checked: Pipewire.defaultAudioSource === modelData; onClicked: Pipewire.preferredDefaultAudioSource = modelData }
      }
      Heading { text: sink && sink.audio ? (sink.audio.muted ? "Volume (muted)" : "Volume (" + Math.round(sink.audio.volume * 100) + "%)") : "Volume" }
      MSlider {
        Layout.fillWidth: true
        implicitHeight: Tk.padding.medium * 3
        value: sink && sink.audio ? sink.audio.volume : 0
        onMoved: v => { if (sink && sink.audio) { sink.audio.muted = false; sink.audio.volume = v } }
      }
      WideButton { Layout.bottomMargin: Tk.padding.small; icon: "settings"; label: "Open mixer"; onClicked: { Sys.run("omarchy-launch-audio || wiremix || pavucontrol"); root.closeRequested() } }
    }
  }

  // ---------------------------------------------------------- bluetooth
  Component {
    id: bluetooth
    ColumnLayout {
      implicitWidth: Tk.sizes.bluetoothWidth
      spacing: Tk.spacing.small
      readonly property var adapter: Bluetooth.defaultAdapter
      Heading { text: "Bluetooth" }
      Toggle { label: "Enabled"; checked: adapter ? adapter.enabled : false; onToggled: c => { if (adapter) adapter.enabled = c } }
      Toggle { label: "Discovering"; checked: adapter ? adapter.discovering : false; onToggled: c => { if (adapter) adapter.discovering = c } }
      Sub {
        readonly property var devs: Bluetooth.devices.values
        readonly property int conn: devs.filter(d => d.connected).length
        text: devs.length + (devs.length === 1 ? " device" : " devices") + " available" + (conn ? " (" + conn + " connected)" : "")
      }
      Repeater {
        model: [...Bluetooth.devices.values].sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name)).slice(0, 5)
        RowLayout {
          id: dev
          required property var modelData
          readonly property bool loading: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
          Layout.fillWidth: true
          Layout.rightMargin: Tk.padding.extraSmall
          spacing: Tk.spacing.small
          opacity: 0; scale: 0.7
          Component.onCompleted: { opacity = 1; scale = 1 }
          Behavior on opacity { Anim { type: "effects" } }
          Behavior on scale { Anim {} }
          MIcon { text: Sys.bluetoothIcon(dev.modelData.icon) }
          MText { Layout.leftMargin: Tk.spacing.extraSmall; Layout.rightMargin: Tk.spacing.extraSmall; Layout.fillWidth: true; text: dev.modelData.name; elide: Text.ElideRight }
          MIcon {
            visible: dev.modelData.state === BluetoothDeviceState.Connected
            text: dev.modelData.batteryAvailable ? Sys.batteryIcon(dev.modelData.battery, false) : "battery_alert"
            color: dev.modelData.batteryAvailable && dev.modelData.battery < 0.2 ? Colours.m3error : Colours.m3onSurfaceVariant
          }
          RoundAction {
            icon: dev.modelData.connected ? "link_off" : "link"
            active: dev.modelData.state === BluetoothDeviceState.Connected
            busy: dev.loading
            onClicked: dev.modelData.connected = !dev.modelData.connected
          }
        }
      }
      WideButton {
        Layout.bottomMargin: Tk.padding.small
        icon: "settings"; label: "Open settings"
        onClicked: { root.host.toggle("settings", "bluetooth"); root.closeRequested() }
      }
    }
  }

  // ------------------------------------------------------------ battery
  Component {
    id: battery
    ColumnLayout {
      readonly property var dev: UPower.displayDevice
      function fmt(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s / 3600) % 24, m = Math.floor(s / 60) % 60
        const c = []
        if (d) c.push(d + (d === 1 ? " day" : " days"))
        if (h) c.push(h + (h === 1 ? " hour" : " hours"))
        if (m) c.push(m + (m === 1 ? " min" : " mins"))
        return c.join(", ")
      }
      implicitWidth: Tk.sizes.batteryWidth
      spacing: Tk.spacing.medium
      MText {
        Layout.topMargin: Tk.padding.small
        text: dev && dev.isLaptopBattery ? "Remaining: " + Math.round(dev.percentage * 100) + "%" : "No battery detected"
      }
      MText {
        text: {
          if (!dev || !dev.isLaptopBattery) return "Power profile: " + (["Power saver", "Balanced", "Performance"][PowerProfiles.profile] || "Unknown")
          if (UPower.onBattery) return dev.timeToEmpty > 0 ? "Time remaining: " + fmt(dev.timeToEmpty) : "Calculating remaining battery life..."
          if (dev.timeToFull > 0) return "Time until charged: " + fmt(dev.timeToFull)
          return Math.round(dev.percentage * 100) === 100 ? "Fully charged!" : "Calculating time until charged..."
        }
      }
      Rectangle {
        id: profiles
        readonly property var icons: ["energy_savings_leaf", "balance", "rocket_launch"]
        readonly property int current: PowerProfiles.profile === PowerProfile.PowerSaver ? 0 : PowerProfiles.profile === PowerProfile.Performance ? 2 : 1
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: Tk.padding.small
        implicitWidth: row.implicitWidth + Tk.padding.medium * 2
        implicitHeight: row.implicitHeight + Tk.padding.small
        radius: height / 2
        color: Colours.m3surfaceContainer
        Rectangle {
          readonly property var cur: pRep.count > profiles.current ? pRep.itemAt(profiles.current) : null
          x: cur ? row.x + cur.x - Tk.padding.small : 0
          y: cur ? row.y + cur.y - Tk.padding.small : 0
          width: cur ? cur.width + Tk.padding.small * 2 : 0
          height: cur ? cur.height + Tk.padding.small * 2 : 0
          radius: height / 2
          color: Colours.m3primary
          Behavior on x { Anim {} }
        }
        Row {
          id: row
          anchors.centerIn: parent
          spacing: Tk.spacing.largeIncreased
          Repeater {
            id: pRep
            model: profiles.icons
            MIcon {
              required property string modelData
              required property int index
              text: modelData
              size: Tk.iconSize.large
              fill: index === profiles.current ? 1 : 0
              color: index === profiles.current ? Colours.m3onPrimary : Colours.m3onSurface
              MouseArea {
                anchors.fill: parent; anchors.margins: -Tk.padding.small
                cursorShape: Qt.PointingHandCursor
                onClicked: PowerProfiles.profile = [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance][parent.index]
              }
            }
          }
        }
      }
    }
  }

  // -------------------------------------------------------- lock status
  Component {
    id: lockstatus
    ColumnLayout {
      spacing: Tk.spacing.small
      MText { text: "Capslock: " + (root.host.capsLock ? "Enabled" : "Disabled") }
      MText { text: "Numlock: " + (root.host.numLock ? "Enabled" : "Disabled") }
    }
  }

  // ---------------------------------------------------------- tray menu
  Component {
    id: traymenu
    Item {
     implicitWidth: stack.currentItem ? stack.currentItem.implicitWidth : 0
     implicitHeight: stack.currentItem ? stack.currentItem.implicitHeight : 0
     StackView {
      id: stack
      anchors.fill: parent
      initialItem: menuPage.createObject(null, { handle: root.trayItem ? root.trayItem.menu : null })
      pushEnter: null; pushExit: null; popEnter: null; popExit: null
      replaceEnter: null; replaceExit: null

      Component {
        id: menuPage
        Column {
          id: page
          property var handle
          property bool isSub: false
          width: Tk.sizes.trayMenuWidth
          spacing: Tk.spacing.small
          QsMenuOpener { id: opener; menu: page.handle }

          Rectangle {
            visible: page.isSub
            width: backRow.implicitWidth + Tk.padding.small * 2
            height: backRow.implicitHeight + Tk.padding.small
            radius: height / 2
            color: Colours.m3secondaryContainer
            StateLayer { color: Colours.m3onSecondaryContainer; onClicked: stack.pop() }
            Row {
              id: backRow
              anchors.centerIn: parent
              spacing: Tk.spacing.small
              MIcon { text: "chevron_left"; color: Colours.m3onSecondaryContainer }
              MText { anchors.verticalCenter: parent.verticalCenter; text: "Back"; color: Colours.m3onSecondaryContainer }
            }
          }
          Repeater {
            model: opener.children
            Item {
              id: entry
              required property var modelData
              width: page.width
              height: modelData.isSeparator ? 1 : Math.max(24, label.implicitHeight + Tk.padding.small)
              Rectangle {
                visible: entry.modelData.isSeparator
                anchors.fill: parent
                color: Colours.m3outlineVariant
              }
              Item {
                visible: !entry.modelData.isSeparator
                anchors.fill: parent
                property real radius: Tk.rounding.full
                StateLayer {
                  disabled: !entry.modelData.enabled
                  onClicked: {
                    if (entry.modelData.hasChildren) stack.push(menuPage.createObject(null, { handle: entry.modelData, isSub: true }))
                    else { entry.modelData.triggered(); root.closeRequested() }
                  }
                }
                Image {
                  id: eIcon
                  anchors.left: parent.left
                  anchors.leftMargin: Tk.padding.small
                  anchors.verticalCenter: parent.verticalCenter
                  width: entry.modelData.icon ? label.implicitHeight : 0
                  height: width
                  source: entry.modelData.icon
                  sourceSize.width: 48; sourceSize.height: 48
                }
                MText {
                  id: label
                  anchors.left: eIcon.right
                  anchors.leftMargin: eIcon.width ? Tk.spacing.small : Tk.padding.small
                  anchors.right: chev.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: entry.modelData.text
                  elide: Text.ElideRight
                  color: entry.modelData.enabled ? Colours.m3onSurface : Colours.m3outline
                }
                MIcon {
                  id: chev
                  anchors.right: parent.right
                  anchors.rightMargin: Tk.padding.small
                  anchors.verticalCenter: parent.verticalCenter
                  visible: entry.modelData.hasChildren || entry.modelData.checkState === Qt.Checked
                  text: entry.modelData.hasChildren ? "chevron_right" : "check"
                  color: Colours.m3onSurfaceVariant
                }
              }
            }
          }
        }
      }
    }
    }
  }

  // ------------------------------------------------------ active window
  Component {
    id: activewindow
    ColumnLayout {
      readonly property var tl: Sys.activeToplevel
      spacing: Tk.spacing.medium
      Rectangle {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: preview.implicitWidth
        implicitHeight: preview.implicitHeight
        radius: Tk.rounding.large
        color: Colours.m3surfaceContainer
        layer.enabled: true
        layer.effect: ShaderMaskEffect { maskItem: previewMask }
        Rectangle { id: previewMask; anchors.fill: parent; radius: parent.radius; visible: false; layer.enabled: true }
        ScreencopyView {
          id: preview
          readonly property real ratio: sourceSize.height > 0 ? sourceSize.width / sourceSize.height : 16 / 9
          anchors.fill: parent
          captureSource: tl ? tl.wayland : null
          live: true
          constraintSize.width: 400
          constraintSize.height: 400
        }
      }
      RowLayout {
        Layout.maximumWidth: 400
        spacing: Tk.spacing.medium
        MIcon { text: Sys.appIcon(tl && tl.wayland ? tl.wayland.appId : "", "desktop_windows"); color: Colours.m3primary; size: Tk.iconSize.large }
        ColumnLayout {
          spacing: 0
          MText { Layout.fillWidth: true; text: tl && tl.wayland ? tl.wayland.appId : ""; font.pointSize: Tk.body.medium; weight: Font.Medium; elide: Text.ElideRight }
          MText { Layout.fillWidth: true; text: tl ? tl.title : ""; color: Colours.m3onSurfaceVariant; elide: Text.ElideRight }
        }
      }
    }
  }
}
