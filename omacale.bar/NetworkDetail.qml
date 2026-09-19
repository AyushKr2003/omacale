import QtQuick
import QtQuick.Layouts

// Settings › Network › details. Port of Caelestia's nexus
// network/NetworkDetailPage.qml (and EthernetDetailPage): Forget / Disconnect
// buttons over the live connection info. Link details come from
// `omarchy-network-status --verbose` via NetService. Caelestia's IPv4 editor
// is omitted: Omarchy has no command for it.
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  readonly property bool wired: NetService.detailKind === "ethernet"
  readonly property var net: wired ? null : NetService.networkFor(NetService.detailSsid)
  readonly property var dev: wired ? NetService.wiredDevice : NetService.wifiDevice
  readonly property bool isActive: wired ? !!(dev && dev.connected) : !!(net && net.connected)
  // omarchy-network-status reports the default route; only use it when that
  // is the connection shown here.
  readonly property var info: {
    const i = NetService.info
    if (!isActive || !i.type) return ({})
    if (wired ? i.type !== "ethernet" : (i.type !== "wifi" || i.ssid !== NetService.detailSsid)) return ({})
    return i
  }
  readonly property bool live: !settings || settings.active === undefined || settings.active

  spacing: Tk.spacing.extraSmall / 2

  property bool held: false
  function syncHold() { const want = visible && live; if (want !== held) { held = want; NetService.hold(want) } }
  onVisibleChanged: syncHold()
  onLiveChanged: syncHold()
  Component.onCompleted: syncHold()
  Component.onDestruction: if (held) NetService.hold(false)

  // Title row: the page title is generic, so name the connection here.
  RowLayout {
    Layout.fillWidth: true
    Layout.bottomMargin: Tk.spacing.large
    spacing: Tk.spacing.medium
    Rectangle {
      implicitWidth: implicitHeight
      implicitHeight: headIcon.implicitHeight + Tk.padding.medium * 2
      radius: height / 2
      color: root.isActive ? Colours.m3primaryContainer : Colours.m3surfaceContainerHighest
      MIcon {
        id: headIcon
        anchors.centerIn: parent
        text: root.wired ? "lan" : Sys.networkIcon(NetService.strength(root.net))
        size: Tk.iconSize.large
        fill: 1
        color: root.isActive ? Colours.m3onPrimaryContainer : Colours.m3onSurfaceVariant
      }
    }
    RowLabel {
      Layout.fillWidth: true
      textSize: Tk.title.medium
      text: root.wired ? "Ethernet" : NetService.detailSsid
      subtext: root.isActive ? "Connected" : root.net && root.net.known ? "Saved, not connected" : "Not connected"
    }
  }

  // ---- Action buttons (Caelestia ButtonRow of Forget / Disconnect)
  RowLayout {
    Layout.fillWidth: true
    Layout.bottomMargin: Tk.spacing.large - root.spacing
    spacing: Tk.spacing.small
    BigButton {
      visible: !root.wired && !!root.net && root.net.known
      icon: "delete"
      text: "Forget"
      bg: Colours.m3errorContainer
      fg: Colours.m3onErrorContainer
      onClicked: { NetService.forget(root.net); root.settings.back() }
    }
    BigButton {
      visible: root.isActive
      icon: "link_off"
      text: "Disconnect"
      bg: Colours.m3primaryContainer
      fg: Colours.m3onPrimaryContainer
      onClicked: {
        if (root.wired) root.dev.disconnect()
        else NetService.disconnect(root.net)
        root.settings.back()
      }
    }
    BigButton {
      visible: !root.wired && !root.isActive && !!root.net
      icon: "link"
      text: "Connect"
      bg: Colours.m3primaryContainer
      fg: Colours.m3onPrimaryContainer
      onClicked: { NetService.activate(root.net); root.settings.back() }
    }
  }

  // ---- Connection info
  SectionHeader { Layout.fillWidth: true; first: true; row: ({ text: "Connection" }) }
  InfoRow {
    first: true
    visible: !root.wired
    icon: "signal_wifi_4_bar"
    label: "Signal"
    value: root.net ? NetService.strength(root.net) + "%" : "—"
  }
  InfoRow {
    first: root.wired
    visible: !root.wired
    icon: "lock"
    label: "Security"
    value: root.net ? NetService.securityLabel(root.net.security) : "—"
  }
  InfoRow {
    visible: !root.wired && !!root.info.freq
    icon: "graphic_eq"
    label: "Frequency"
    value: NetService.bandLabel(root.info.freq)
  }
  InfoRow {
    first: root.wired
    visible: !!(root.info.bitrate || (root.wired && root.dev && root.dev.linkSpeed > 0))
    icon: "speed"
    label: "Link speed"
    value: root.wired ? (root.dev ? root.dev.linkSpeed + " Mb/s" : "") : (root.info.bitrate || "")
  }
  InfoRow {
    icon: "lan"
    label: "IP address"
    value: root.info.ip ? root.info.ip + (root.info.prefix ? "/" + root.info.prefix : "") : "—"
  }
  InfoRow {
    icon: "router"
    label: "Gateway"
    value: root.info.gateway || "—"
  }
  InfoRow {
    icon: "settings_ethernet"
    label: "Interface"
    value: root.info.iface || (root.dev ? root.dev.name : "—")
  }
  InfoRow {
    last: true
    icon: "memory"
    label: "MAC address"
    value: root.dev && root.dev.address ? root.dev.address : "—"
  }

  RowButton {
    Layout.topMargin: Tk.spacing.large - root.spacing
    visible: !root.wired && root.isActive
    first: true
    last: true
    icon: "qr_code_2"
    text: "Share this network"
    subtext: "Show a QR code other devices can scan"
    onClicked: NetService.share()
  }
}
