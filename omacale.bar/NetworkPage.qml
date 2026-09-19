import QtQuick
import QtQuick.Layouts
import Quickshell

// Settings › Network. Port of Caelestia's nexus NetworkPage.qml and
// common/NetworkList.qml (+ EthernetSection), backed by NetService (the
// engine behind Omarchy's own network panel). VPN is omitted: Omarchy has no
// VPN provider backend for it.
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  readonly property int maxShown: 8
  property bool showAll: false
  readonly property bool live: !settings || settings.active === undefined || settings.active

  spacing: Tk.spacing.extraSmall / 2

  // Scan while the page is on screen, like Caelestia's rescan timer.
  property bool held: false
  function syncHold() { const want = visible && live; if (want !== held) { held = want; NetService.hold(want) } }
  onVisibleChanged: syncHold()
  onLiveChanged: syncHold()
  Component.onCompleted: syncHold()
  Component.onDestruction: if (held) NetService.hold(false)

  function openDetails(kind, ssid) {
    NetService.detailKind = kind
    NetService.detailSsid = ssid || ""
    root.settings.push("networkDetail")
  }

  // ---- Ethernet (Caelestia EthernetSection)
  RowButton {
    // Only with a cable in, like Caelestia's hasAvailableEthernet.
    visible: !!NetService.wiredDevice && (NetService.wiredDevice.connected || NetService.wiredDevice.hasLink)
    first: true
    last: true
    Layout.bottomMargin: Tk.spacing.large - root.spacing
    readonly property var dev: NetService.wiredDevice
    icon: dev && dev.connected ? "lan" : "cable"
    iconColour: dev && dev.connected ? Colours.m3primary : Colours.m3onSurfaceVariant
    text: "Ethernet"
    subtext: !dev ? "" : dev.connected ? "Connected" + (dev.linkSpeed > 0 ? " • " + dev.linkSpeed + " Mb/s" : "")
      : "Not connected"
    trailingIcon: dev && dev.connected ? "chevron_right" : ""
    disabled: !(dev && dev.connected)
    onClicked: root.openDetails("ethernet", "")
  }

  // ---- Wi-Fi
  RowToggle {
    Layout.fillWidth: true
    first: true
    text: "Wi-Fi"
    labelSize: Tk.body.medium
    subtext: !NetService.available ? "NetworkManager is not running"
      : !NetService.wifiHardwareEnabled ? "Blocked by the hardware switch" : ""
    disabled: !NetService.available || !NetService.wifiHardwareEnabled
    checked: NetService.wifiEnabled
    onToggled: c => NetService.setWifiEnabled(c)
  }

  ItemList {
    id: list
    showList: NetService.wifiEnabled
    scanning: NetService.wifiEnabled && NetService.scanning
    placeholderIcon: NetService.wifiEnabled ? "wifi_find" : "signal_wifi_off"
    placeholderText: NetService.wifiEnabled ? "No networks found" : "Wi-Fi disabled"

    model: ScriptModel { values: NetService.sorted(root.showAll ? 0 : root.maxShown) }

    delegate: Item {
      id: net
      required property var modelData
      readonly property string ssid: modelData ? modelData.name : ""
      readonly property bool active: !!(modelData && modelData.connected)
      readonly property bool loading: NetService.busy && NetService.actionSsid === ssid
      readonly property bool prompting: NetService.passwordSsid === ssid && !active
      readonly property bool enterprise: !!modelData && NetService.isEnterprise(modelData.security)
      readonly property bool failed: NetService.failureSsid === ssid && NetService.failureReason !== ""

      width: ListView.view ? ListView.view.width : 0
      implicitHeight: netRow.implicitHeight + Tk.padding.large * 2 + (prompting ? prompt.implicitHeight + Tk.padding.medium : 0)
      clip: true
      Behavior on implicitHeight { Anim {} }

      // Only the network row itself is clickable, not the prompt under it.
      StateLayer {
        anchors.fill: undefined
        width: parent.width
        height: netRow.implicitHeight + Tk.padding.large * 2
        radius: Tk.rounding.extraSmall
        disabled: net.loading || (NetService.busy && !net.active)
        onClicked: net.active ? root.openDetails("wifi", net.ssid) : NetService.activate(net.modelData)
      }

      RowLayout {
        id: netRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tk.padding.large
        anchors.leftMargin: Tk.padding.extraLarge
        anchors.rightMargin: Tk.padding.extraLarge
        spacing: Tk.spacing.medium
        opacity: net.loading ? 0.5 : 1
        Behavior on opacity { Anim { type: "effects" } }

        MIcon {
          text: Sys.networkIcon(NetService.strength(net.modelData))
          size: Tk.iconSize.medium
          color: net.active ? Colours.m3primary : Colours.m3onSurfaceVariant
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0
          MText { Layout.fillWidth: true; text: net.ssid; elide: Text.ElideRight }
          MText {
            Layout.fillWidth: true
            text: {
              if (net.failed) return NetService.failureReason
              if (net.loading) return NetService.actionKind === "connect" ? "Connecting…" : NetService.actionKind === "forget" ? "Forgetting…" : "Disconnecting…"
              const sec = "Security: " + NetService.securityLabel(net.modelData.security)
              return net.active ? sec + " • Connected" : net.modelData.known ? sec + " • Saved" : sec
            }
            color: net.failed ? Colours.m3error : Colours.m3outline
            font.pointSize: Tk.label.small
            elide: Text.ElideRight
            animate: true
          }
        }
        Item {
          implicitWidth: Tk.iconSize.medium * 1.3
          implicitHeight: implicitWidth
          LoadingIndicator { anchors.centerIn: parent; visible: net.loading }
          MIcon {
            anchors.centerIn: parent
            visible: !net.loading
            text: net.active ? "settings" : NetService.isOpen(net.modelData.security) ? "" : "lock"
            size: Tk.iconSize.medium
            color: net.active ? Colours.m3primary : Colours.m3onSurfaceVariant
          }
        }
      }

      // Inline credentials prompt (Caelestia opens a dialog; Omarchy's panel
      // expands the row, which fits a settings list better).
      ColumnLayout {
        id: prompt
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: netRow.bottom
        anchors.topMargin: Tk.padding.medium
        anchors.leftMargin: Tk.padding.extraLarge
        anchors.rightMargin: Tk.padding.extraLarge
        spacing: Tk.spacing.small
        visible: net.prompting
        opacity: net.prompting ? 1 : 0
        Behavior on opacity { Anim { type: "effects" } }
        onVisibleChanged: if (visible) (net.enterprise ? identity : password).focusInput()
        // Opened from the bar popout with the prompt already up.
        Component.onCompleted: if (net.prompting) Qt.callLater(() => (net.enterprise ? identity : password).focusInput())

        CredentialField { id: identity; visible: net.enterprise; Layout.fillWidth: true; placeholder: "Username"; onAccepted: password.focusInput() }
        CredentialField { id: password; Layout.fillWidth: true; placeholder: "Password"; secret: true; onAccepted: connectBtn.submit() }
        RowLayout {
          Layout.fillWidth: true
          Layout.bottomMargin: Tk.padding.small
          spacing: Tk.spacing.small
          Item { Layout.fillWidth: true }
          TextButton { text: "Cancel"; onClicked: { NetService.passwordSsid = ""; password.text = ""; identity.text = "" } }
          TextButton {
            id: connectBtn
            filled: true
            text: "Connect"
            disabled: password.text === "" || (net.enterprise && identity.text === "")
            function submit() {
              if (disabled) return
              if (net.enterprise) NetService.connectEnterprise(net.modelData, identity.text, password.text)
              else NetService.connectWithPsk(net.modelData, password.text)
              password.text = ""
            }
            onClicked: submit()
          }
        }
      }
    }
  }

  RowButton {
    readonly property int total: NetService.networks.length
    visible: NetService.wifiEnabled && total > root.maxShown
    icon: root.showAll ? "collapse_content" : "expand_content"
    text: root.showAll ? "Show fewer networks" : "Show all networks (" + total + ")"
    onClicked: root.showAll = !root.showAll
  }
  RowButton {
    last: true
    icon: "qr_code_2"
    text: "Share Wi-Fi"
    subtext: NetService.connectedNetwork ? "QR code for " + NetService.connectedNetwork.name : "Connect to a network to share it"
    disabled: !NetService.connectedNetwork
    onClicked: NetService.share()
  }

  // Password / username input, shaped like RowText's field.
  component CredentialField: Rectangle {
    id: field
    property string placeholder
    property bool secret: false
    property alias text: input.text
    property bool reveal: false
    signal accepted()
    function focusInput() { input.forceActiveFocus() }

    implicitHeight: 40
    radius: height / 2
    color: Colours.m3surfaceContainerHighest
    border.width: input.activeFocus ? 2 : 0
    border.color: Colours.m3primary

    MTextField {
      id: input
      anchors.left: parent.left
      anchors.right: eye.left
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Tk.padding.large
      anchors.rightMargin: Tk.spacing.small
      echoMode: field.secret && !field.reveal ? TextInput.Password : TextInput.Normal
      font.pointSize: Tk.body.small
      clip: true
      onAccepted: field.accepted()
      Keys.onEscapePressed: NetService.passwordSsid = ""
      MText { anchors.verticalCenter: parent.verticalCenter; visible: !input.text; text: field.placeholder; color: Colours.m3outline }
    }
    IconButton {
      id: eye
      anchors.right: parent.right
      anchors.rightMargin: Tk.padding.small
      anchors.verticalCenter: parent.verticalCenter
      visible: field.secret
      width: field.secret ? implicitWidth : 0
      type: "text"
      icon: field.reveal ? "visibility_off" : "visibility"
      onClicked: field.reveal = !field.reveal
    }
  }

  // Small pill text button (Caelestia TextButton).
  component TextButton: Rectangle {
    id: tb
    property string text
    property bool filled: false
    property bool disabled: false
    signal clicked()
    implicitWidth: tbLabel.implicitWidth + Tk.padding.large * 2
    implicitHeight: tbLabel.implicitHeight + Tk.padding.small * 2
    radius: height / 2
    color: disabled ? Qt.alpha(Colours.m3onSurface, filled ? 0.1 : 0) : filled ? Colours.m3primary : "transparent"
    Behavior on color { CAnim {} }
    StateLayer { disabled: tb.disabled; color: tb.filled ? Colours.m3onPrimary : Colours.m3primary; onClicked: tb.clicked() }
    MText {
      id: tbLabel
      anchors.centerIn: parent
      text: tb.text
      weight: Font.Medium
      color: tb.disabled ? Qt.alpha(Colours.m3onSurface, 0.38) : tb.filled ? Colours.m3onPrimary : Colours.m3primary
    }
  }
}
