import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import "../.."

// Contents of the bar popouts (network, Wi-Fi password, bluetooth, battery,
// keyboard layouts, lock status, tray menus, active-window preview, and the
// window info panel it detaches into). Sized by the current page.
Item {
  id: root

  property var host
  property string name: ""
  property var trayItem: null
  property var screen: null
  // Whether the popout is showing (it keeps its last page loaded after).
  property bool open: false
  // The network the Wi-Fi password page asks for (ScreenScope keeps it).
  property string passwordSsid: ""
  signal closeRequested()
  // A page moving the popout on to another one (Caelestia sets
  // popouts.currentName): network -> wirelesspassword -> network.
  signal switchRequested(string name, string arg)

  readonly property Item current: loader.item
  implicitWidth: current ? current.implicitWidth : 0
  implicitHeight: current ? current.implicitHeight : 0

  Loader {
    id: loader
    anchors.fill: parent
    sourceComponent: ({
      network: network, wirelesspassword: wirelesspassword, bluetooth: bluetooth, battery: battery, audio: audio,
      kblayout: kblayout, lockstatus: lockstatus, update: update, traymenu: traymenu, activewindow: activewindow, winfo: winfo
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
  // Caelestia's popout footer: a full-width IconTextButton in primaryContainer
  // with extraSmall vertical padding.
  component WideButton: Rectangle {
    id: wb
    property string icon
    property string label
    signal clicked()
    Layout.fillWidth: true
    Layout.topMargin: Tk.spacing.medium
    implicitHeight: wbRow.implicitHeight + Tk.padding.extraSmall * 2
    radius: wbState.pressed ? Tk.rounding.small : height / 2
    color: Colours.m3primaryContainer
    Behavior on radius { Anim { type: "effects" } }
    StateLayer { id: wbState; color: Colours.m3onPrimaryContainer; onClicked: wb.clicked() }
    RowLayout {
      id: wbRow
      anchors.centerIn: parent
      spacing: Tk.spacing.small
      MIcon { text: wb.icon; size: Math.round(Tk.body.small * 1.2); color: Colours.m3onPrimaryContainer }
      MText { Layout.topMargin: 1; text: wb.label; color: Colours.m3onPrimaryContainer }
    }
  }

  // ------------------------------------------------------------ network
  Component {
    id: network
    ColumnLayout {
      id: netCol
      implicitWidth: Tk.sizes.networkWidth
      spacing: Tk.spacing.small
      // No NetService.hold(): this list is NetworkManager's last scan, which
      // is what the `nmcli ... --rescan no` behind it always showed. Starting
      // a scan (and the link-detail poll that comes with a hold) belongs to
      // the Network settings page, not to a hover popout.
      // Caelestia Network.qml: a network that needs a password turns the
      // popout into the password page. 802.1X also needs an identity, which
      // only Settings › Network has a field for.
      function askPassword(net) {
        if (!net || NetService.passwordSsid !== net.name) return
        if (NetService.isEnterprise(net.security)) { root.host.toggle("settings", "network"); root.closeRequested() }
        else root.switchRequested("wirelesspassword", net.name)
      }
      // Set by a click on a secured network, and by a saved network whose
      // key NetworkManager rejects.
      Connections {
        target: NetService
        function onPasswordSsidChanged() { netCol.askPassword(NetService.networkFor(NetService.passwordSsid)) }
      }
      Heading { text: Sys.ethernet && !Sys.wifi ? "Ethernet" : "Wireless" }
      Toggle {
        label: "Enabled"
        checked: NetService.wifiEnabled
        onToggled: c => NetService.setWifiEnabled(c)
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
              // password asks for it: activate() sets passwordSsid, which
              // netCol's Connections turns into the password page.
              NetService.activate(net)
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

  // --------------------------------------------------- wireless password
  // Caelestia bar/popouts/WirelessPassword.qml: a card asking for the key of
  // the network picked in the network popout. The field is Caelestia's own
  // FocusScope that draws one rounded dot per character (the password never
  // lives in a TextInput). The popout is held while this shows (ScreenScope
  // popoutHeld), so it has the keyboard and survives the pointer leaving.
  Component {
    id: wirelesspassword
    ColumnLayout {
      id: wp
      readonly property var net: NetService.networkFor(root.passwordSsid)
      readonly property bool connecting: NetService.actionKind === "connect" && NetService.actionSsid === root.passwordSsid
      // Set once Connect is pressed, so a failure or success from before the
      // page opened isn't taken for this attempt's.
      property bool submitted: false
      property bool hasError: false
      property string buffer: ""
      property bool shown: false

      function close() {
        buffer = ""
        submitted = false
        // Clear the pending prompt, so clicking the network again asks again.
        if (NetService.passwordSsid === root.passwordSsid) NetService.passwordSsid = ""
        root.switchRequested("network", "")
      }
      function connect() {
        if (!net || connecting || buffer.length === 0) return
        hasError = false
        submitted = true
        NetService.connectWithPsk(net, buffer)
      }

      spacing: Tk.spacing.medium
      implicitWidth: 400
      implicitHeight: card.implicitHeight + Tk.padding.extraLargeIncreased
      Component.onCompleted: { shown = true; focusTimer.start() }
      // Caelestia's focusTimer: the surface only takes the keyboard once the
      // layer has been given OnDemand focus, a frame or two after opening.
      Timer { id: focusTimer; interval: 150; onTriggered: field.forceActiveFocus() }

      Connections {
        target: NetService
        function onFailureReasonChanged() {
          if (!wp.submitted || NetService.failureSsid !== root.passwordSsid || !NetService.failureReason) return
          wp.submitted = false
          wp.hasError = true
          wp.buffer = ""
        }
      }
      readonly property bool connected: !!net && net.connected
      onConnectedChanged: if (connected && submitted) successTimer.start()
      // Caelestia connectionSuccessTimer: give the list a moment to update.
      Timer { id: successTimer; interval: 500; onTriggered: if (wp.connected) wp.close() }

      Rectangle {
        id: card
        Layout.fillWidth: true
        Layout.preferredWidth: 400
        implicitHeight: content.implicitHeight + Tk.padding.extraLargeIncreased
        radius: Tk.rounding.large
        color: Colours.m3surfaceContainer
        opacity: wp.shown ? 1 : 0
        scale: wp.shown ? 1 : 0.7
        Behavior on opacity { Anim { type: "effects" } }
        Behavior on scale { Anim {} }

        ColumnLayout {
          id: content
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.margins: Tk.padding.large
          spacing: Tk.spacing.medium

          MIcon {
            Layout.alignment: Qt.AlignHCenter
            text: "lock"
            size: Tk.iconSize.extraLarge * 2
          }
          MText {
            Layout.alignment: Qt.AlignHCenter
            text: "Enter password"
            font.pointSize: Tk.body.large
            weight: Font.Medium
          }
          MText {
            Layout.alignment: Qt.AlignHCenter
            text: root.passwordSsid ? "Network: " + root.passwordSsid : "Unknown network"
            color: Colours.m3outline
            font.pointSize: Tk.body.small
          }
          MText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tk.spacing.small
            Layout.maximumWidth: parent.width - Tk.padding.extraLargeIncreased
            visible: wp.connecting || wp.hasError
            text: wp.hasError ? "Connection failed. Please check your password and try again." : wp.connecting ? "Connecting..." : ""
            color: wp.hasError ? Colours.m3error : Colours.m3onSurfaceVariant
            font.pointSize: Tk.body.small
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
          }

          FocusScope {
            id: field
            Layout.topMargin: Tk.spacing.largeIncreased
            Layout.fillWidth: true
            implicitHeight: Math.max(48, dots.implicitHeight + Tk.padding.medium * 2)
            focus: true
            activeFocusOnTab: true

            Keys.onPressed: e => {
              if (e.key === Qt.Key_Escape) { wp.close(); e.accepted = true; return }
              if (wp.hasError && e.text && e.text.length > 0) wp.hasError = false
              if (e.key === Qt.Key_Enter || e.key === Qt.Key_Return) { wp.connect(); e.accepted = true }
              else if (e.key === Qt.Key_Backspace) {
                wp.buffer = (e.modifiers & Qt.ControlModifier) ? "" : wp.buffer.slice(0, -1)
                e.accepted = true
              }
              else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) e.accepted = false
              else if (e.text && e.text.length > 0 && e.text.charCodeAt(0) >= 32) { wp.buffer += e.text; e.accepted = true }
            }

            Rectangle {
              anchors.fill: parent
              radius: Tk.rounding.large
              color: field.activeFocus ? Qt.lighter(Colours.m3surfaceContainer, 1.05) : Colours.m3surfaceContainer
              border.width: field.activeFocus || wp.hasError ? 4 : 1
              border.color: wp.hasError ? Colours.m3error : field.activeFocus ? Colours.m3primary : Colours.m3outline
              Behavior on border.color { CAnim {} }
              Behavior on border.width { Anim { type: "effects" } }
              Behavior on color { CAnim {} }
            }
            StateLayer {
              showHoverBackground: false
              cursorShape: Qt.IBeamCursor
              radius: Tk.rounding.large
              onClicked: field.forceActiveFocus()
            }
            MText {
              anchors.centerIn: parent
              text: "Password"
              color: Colours.m3outline
              font.family: Tk.mono
              font.pointSize: Tk.body.medium
              opacity: wp.buffer ? 0 : 1
              Behavior on opacity { Anim { type: "effects" } }
            }
            ListView {
              id: dots
              anchors.centerIn: parent
              implicitWidth: count * (implicitHeight + spacing) - spacing
              implicitHeight: Tk.body.medium
              orientation: Qt.Horizontal
              spacing: Tk.spacing.extraSmall
              interactive: false
              Behavior on implicitWidth { Anim {} }
              model: ScriptModel { values: wp.buffer.split("") }
              delegate: Rectangle {
                id: ch
                implicitWidth: implicitHeight
                implicitHeight: dots.implicitHeight
                color: Colours.m3onSurface
                radius: Tk.rounding.medium / 2
                opacity: 0
                scale: 0
                Component.onCompleted: { opacity = 1; scale = 1 }
                Behavior on opacity { Anim { type: "effects" } }
                Behavior on scale { Anim { type: "fastSpatial" } }
                ListView.onRemove: removeAnim.start()
                SequentialAnimation {
                  id: removeAnim
                  PropertyAction { target: ch; property: "ListView.delayRemove"; value: true }
                  ParallelAnimation {
                    Anim { type: "effects"; target: ch; property: "opacity"; to: 0 }
                    Anim { target: ch; property: "scale"; to: 0.5 }
                  }
                  PropertyAction { target: ch; property: "ListView.delayRemove"; value: false }
                }
              }
            }
          }

          RowLayout {
            Layout.topMargin: Tk.spacing.medium
            Layout.fillWidth: true
            spacing: Tk.spacing.medium
            IconTextButton {
              Layout.fillWidth: true
              Layout.minimumHeight: Tk.body.medium + Tk.padding.medium * 2
              type: "tonal"
              text: "Cancel"
              onClicked: wp.close()
            }
            IconTextButton {
              Layout.fillWidth: true
              Layout.minimumHeight: Tk.body.medium + Tk.padding.medium * 2
              type: "filled"
              text: wp.connecting ? "Connecting..." : "Connect"
              disabled: wp.buffer.length === 0 || wp.connecting
              onClicked: wp.connect()
            }
          }
        }
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
      WideButton { Layout.bottomMargin: Tk.padding.small; icon: "settings"; label: "Open settings"; onClicked: { root.host.toggle("settings", "audio"); root.closeRequested() } }
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
      // Caelestia popouts/Battery.qml: three icon-sized profile targets with
      // a pill that slides to fill the current one.
      Rectangle {
        id: profiles
        readonly property var icons: ["energy_savings_leaf", "balance", "rocket_launch"]
        readonly property var values: [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
        readonly property int current: PowerProfiles.profile === PowerProfile.PowerSaver ? 0 : PowerProfiles.profile === PowerProfile.Performance ? 2 : 1
        readonly property real cell: pRep.count ? pRep.itemAt(0).implicitWidth : 0
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: Tk.padding.small
        implicitWidth: cell * 3 - Tk.padding.small * 3 + Tk.padding.medium * 2 + Tk.spacing.largeIncreased * 2
        implicitHeight: cell
        radius: height / 2
        color: Colours.m3surfaceContainer
        Rectangle {
          readonly property var cur: pRep.count > profiles.current ? pRep.itemAt(profiles.current) : null
          x: cur ? cur.x : 0
          width: profiles.cell
          height: profiles.cell
          radius: height / 2
          color: Colours.m3primary
          Behavior on x { Anim {} }
        }
        Repeater {
          id: pRep
          model: profiles.icons
          Item {
            required property string modelData
            required property int index
            readonly property bool on: index === profiles.current
            implicitWidth: pIcon.implicitHeight + Tk.padding.small
            implicitHeight: implicitWidth
            anchors.verticalCenter: parent.verticalCenter
            x: index === 0 ? Tk.padding.extraSmall
              : index === 2 ? profiles.width - width - Tk.padding.extraSmall
              : (profiles.width - width) / 2
            property real radius: width / 2
            StateLayer { color: parent.on ? Colours.m3onPrimary : Colours.m3onSurface; onClicked: PowerProfiles.profile = profiles.values[parent.index] }
            MIcon {
              id: pIcon
              anchors.centerIn: parent
              text: parent.modelData
              size: Tk.iconSize.large
              fill: parent.on ? 1 : 0
              color: parent.on ? Colours.m3onPrimary : Colours.m3onSurfaceVariant
              Behavior on fill { Anim { type: "effects" } }
            }
          }
        }
      }
    }
  }

  // ---------------------------------------------------- keyboard layout
  // Caelestia bar/popouts/kblayout/KbLayout.qml: the other configured
  // layouts (click to switch; XKB only takes the first 4), a divider, then
  // the active one, which pops in again on every change. The list and row
  // animations are Caelestia's own NumberAnimations, ported as written.
  Component {
    id: kblayout
    ColumnLayout {
      id: kb
      implicitWidth: Tk.sizes.kbLayoutWidth
      spacing: Tk.spacing.small
      Component.onCompleted: KbService.refresh()

      Heading { Layout.rightMargin: Tk.padding.extraSmall; text: "Keyboard layouts" }

      ListView {
        id: kbList
        Layout.fillWidth: true
        Layout.rightMargin: Tk.padding.extraSmall
        Layout.topMargin: Tk.spacing.small
        clip: true
        interactive: true
        implicitHeight: Math.min(contentHeight, 320)
        visible: count > 0
        spacing: Tk.spacing.small
        // Keyed by token, so a re-read of the same layouts keeps the rows.
        model: ScriptModel {
          objectProp: "token"
          values: KbService.layouts.filter(l => l.index !== KbService.activeIndex)
        }

        add: Transition {
          NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: 140 }
          NumberAnimation { properties: "y"; duration: 180; easing.type: Easing.OutCubic }
        }
        remove: Transition { NumberAnimation { properties: "opacity"; to: 0; duration: 100 } }
        move: Transition { NumberAnimation { properties: "y"; duration: 180; easing.type: Easing.OutCubic } }
        displaced: Transition { NumberAnimation { properties: "y"; duration: 180; easing.type: Easing.OutCubic } }

        delegate: Item {
          id: kbRow
          required property var modelData
          readonly property bool isDisabled: modelData.index > 3
          width: kbList.width
          height: Math.max(36, kbRowText.implicitHeight + Tk.padding.small)
          ToolTip.visible: isDisabled && kbHover.hovered
          ToolTip.text: "XKB limitation: maximum 4 layouts allowed"
          HoverHandler { id: kbHover }

          Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height - 4
            property real radius: Tk.rounding.full
            StateLayer {
              disabled: kbRow.isDisabled
              onClicked: if (!kbRow.isDisabled) KbService.switchTo(kbRow.modelData.index)
            }
          }
          MText {
            id: kbRowText
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Tk.padding.extraSmall
            anchors.rightMargin: Tk.padding.extraSmall
            text: kbRow.modelData.label
            elide: Text.ElideRight
            opacity: kbRow.isDisabled ? 0.4 : 1
          }
        }
      }

      Rectangle {
        visible: KbService.activeLabel.length > 0
        Layout.fillWidth: true
        Layout.rightMargin: Tk.padding.extraSmall
        Layout.topMargin: Tk.spacing.small
        implicitHeight: 1
        color: Colours.m3onSurfaceVariant
        opacity: 0.35
      }

      RowLayout {
        id: activeRow
        visible: KbService.activeLabel.length > 0
        Layout.fillWidth: true
        Layout.rightMargin: Tk.padding.extraSmall
        Layout.topMargin: Tk.spacing.small
        Layout.bottomMargin: Tk.padding.small
        spacing: Tk.spacing.small

        MIcon { text: "keyboard"; color: Colours.m3primary }
        MText {
          Layout.fillWidth: true
          text: KbService.activeLabel
          elide: Text.ElideRight
          font.pointSize: Tk.body.medium
          weight: Font.Medium
          color: Colours.m3primary
        }

        Connections {
          target: KbService
          function onActiveLabelChanged() { if (activeRow.visible) popIn.restart() }
        }
        SequentialAnimation {
          id: popIn
          ParallelAnimation {
            NumberAnimation { target: activeRow; property: "opacity"; to: 0; duration: 70 }
            NumberAnimation { target: activeRow; property: "scale"; to: 0.92; duration: 70 }
          }
          ParallelAnimation {
            NumberAnimation { target: activeRow; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: activeRow; property: "scale"; to: 1; duration: 220; easing.type: Easing.OutBack }
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

  // ------------------------------------------------------ system update
  // No Caelestia original: the stock bar's "Pending Omarchy Updates" tooltip,
  // with the lines omarchy-update-available printed and a button to run it.
  Component {
    id: update
    ColumnLayout {
      spacing: Tk.spacing.small
      MText { text: "Pending Omarchy updates"; weight: Font.Medium }
      Repeater {
        model: UpdateService.lines
        Sub { required property string modelData; text: modelData }
      }
      WideButton {
        icon: UpdateService.running ? "downloading" : "system_update_alt"
        label: UpdateService.running ? "Updating..." : "Update"
        onClicked: if (!UpdateService.running) UpdateService.update()
      }
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
  // Caelestia bar/popouts/ActiveWindow.qml: the app icon, title and class
  // over a live preview. The chevron detaches the popout into the window
  // info panel (Wrapper.qml detach("winfo")).
  Component {
    id: activewindow
    Item {
      id: aw
      readonly property var tl: Sys.activeToplevel
      readonly property var ipc: tl ? tl.lastIpcObject : null
      implicitWidth: tl ? awCol.implicitWidth : -Tk.padding.extraLargeIncreased
      implicitHeight: awCol.implicitHeight

      Column {
        id: awCol
        anchors.centerIn: parent
        spacing: Tk.spacing.medium

        RowLayout {
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: Tk.spacing.medium

          IconImage {
            asynchronous: true
            Layout.alignment: Qt.AlignVCenter
            implicitSize: awDetails.implicitHeight
            source: WindowIcons.source({
              class: aw.ipc ? aw.ipc.class : "",
              initialClass: aw.ipc ? aw.ipc.initialClass : "",
              title: aw.tl ? aw.tl.title : "",
              initialTitle: aw.ipc ? aw.ipc.initialTitle : ""
            })
          }
          ColumnLayout {
            id: awDetails
            Layout.fillWidth: true
            spacing: 0
            MText {
              Layout.fillWidth: true
              text: aw.tl ? aw.tl.title : ""
              font.pointSize: Tk.body.medium
              elide: Text.ElideRight
            }
            MText {
              Layout.fillWidth: true
              text: aw.ipc ? (aw.ipc.class || "") : ""
              color: Colours.m3onSurfaceVariant
              elide: Text.ElideRight
            }
          }
          Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: expandIcon.implicitHeight + Tk.padding.small
            implicitHeight: expandIcon.implicitHeight + Tk.padding.small
            StateLayer {
              radius: Tk.rounding.large
              onClicked: root.switchRequested("winfo", "")
            }
            MIcon {
              id: expandIcon
              anchors.centerIn: parent
              anchors.horizontalCenterOffset: size * 0.05
              text: "chevron_right"
              size: Tk.iconSize.large
            }
          }
        }

        ClippingWrapperRectangle {
          color: "transparent"
          radius: Tk.rounding.medium
          ScreencopyView {
            captureSource: aw.tl ? aw.tl.wayland : null
            live: visible
            constraintSize.width: Tk.sizes.windowPreviewSize
            constraintSize.height: Tk.sizes.windowPreviewSize
          }
        }
      }
    }
  }

  // --------------------------------------------------------- window info
  // The detached window info panel (Caelestia modules/windowinfo), shown as
  // a held popout: it has the keyboard, and Escape or a click outside closes it.
  Component {
    id: winfo
    WindowInfo {
      open: root.open && root.name === "winfo"
      screen: root.screen
      client: Sys.activeToplevel
      onCloseRequested: root.closeRequested()
    }
  }
}
