pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Wi-Fi / ethernet state and actions for the settings Network page. Runs on
// the same engine as Omarchy's own network panel (plugins/panels/network):
// Quickshell.Networking over NetworkManager for devices, networks and
// connect / disconnect / forget, and `omarchy-network-status --verbose` for
// the live link details (IP, gateway, band, bitrate).
QtObject {
  id: root

  readonly property bool available: Networking.backend === NetworkBackendType.NetworkManager
  readonly property var devices: Networking.devices ? Networking.devices.values : []
  readonly property var wifiDevice: findDevice(DeviceType.Wifi)
  readonly property var wiredDevice: findDevice(DeviceType.Wired)
  readonly property var networks: wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : []
  readonly property var connectedNetwork: networks.find(n => n && n.connected) || null
  readonly property bool wifiEnabled: Networking.wifiEnabled
  readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
  readonly property bool scanning: !!(wifiDevice && wifiDevice.scannerEnabled)

  function findDevice(type) {
    let fallback = null
    for (const d of devices) {
      if (!d || d.type !== type) continue
      if (d.connected) return d
      if (!fallback) fallback = d
    }
    return fallback
  }
  function networkFor(ssid) { return networks.find(n => n && n.name === ssid) || null }

  function setWifiEnabled(on) { Networking.wifiEnabled = on }

  // Which connection the details sub-page shows ("wifi" + SSID, or "ethernet").
  property string detailKind: "wifi"
  property string detailSsid: ""

  // Pages that want scanning / live details hold the service while visible.
  // The scanner lives on the shared WifiDevice, so it is only released once
  // the last holder lets go.
  property int holders: 0
  function hold(on) {
    holders = Math.max(0, holders + (on ? 1 : -1))
    syncScanner()
    if (holders > 0) details.running = true
  }
  function syncScanner() { if (wifiDevice) wifiDevice.scannerEnabled = holders > 0 && wifiEnabled }
  onWifiDeviceChanged: syncScanner()
  onWifiEnabledChanged: syncScanner()

  // ------------------------------------------------------------ display
  function securityLabel(sec) {
    switch (sec) {
      case WifiSecurityType.Open: return "Open"
      case WifiSecurityType.Owe: return "Enhanced open"
      case WifiSecurityType.WpaPsk: return "WPA"
      case WifiSecurityType.Wpa2Psk: return "WPA2"
      case WifiSecurityType.Sae: return "WPA3"
      case WifiSecurityType.WpaEap:
      case WifiSecurityType.Wpa2Eap: return "Enterprise"
      case WifiSecurityType.Wpa3SuiteB192: return "WPA3 Enterprise"
      case WifiSecurityType.StaticWep:
      case WifiSecurityType.DynamicWep: return "WEP"
      case WifiSecurityType.Leap: return "LEAP"
      default: return "Unknown"
    }
  }
  function isOpen(sec) { return sec === WifiSecurityType.Open || sec === WifiSecurityType.Owe }
  function isEnterprise(sec) {
    return sec === WifiSecurityType.WpaEap || sec === WifiSecurityType.Wpa2Eap || sec === WifiSecurityType.Wpa3SuiteB192
  }
  function strength(net) { return Math.round((net && net.signalStrength || 0) * 100) }
  function bandLabel(mhz) {
    const v = parseFloat(mhz)
    if (!v) return ""
    if (v < 2500) return "2.4 GHz"
    if (v < 5925) return "5 GHz"
    if (v < 7125) return "6 GHz"
    return (v / 1000).toFixed(1) + " GHz"
  }

  // Connecting first, then saved, then signal (Caelestia NetworkList rank).
  function sorted(limit) {
    const rank = n => n.connected ? 0 : (n.name === actionSsid && actionKind === "connect") || n.name === passwordSsid ? 1 : n.known ? 2 : 3
    const list = networks.filter(n => n && n.name).sort((a, b) => rank(a) - rank(b) || b.signalStrength - a.signalStrength)
    return limit > 0 ? list.slice(0, limit) : list
  }

  // ------------------------------------------------------------ actions
  // One action at a time, like Omarchy's panel: the row shows a spinner
  // until NetworkManager settles or the safety timeout fires.
  property string actionSsid: ""
  property string actionKind: ""   // connect | disconnect | forget
  property string failureSsid: ""
  property string failureReason: ""
  property string passwordSsid: ""
  readonly property bool busy: actionKind !== ""

  function run(kind, net, fn) {
    if (busy || !net) return
    actionSsid = net.name || ""
    actionKind = kind
    failureSsid = ""
    failureReason = ""
    fn(net)
    actionTimeout.restart()
  }
  function finish() {
    actionTimeout.stop()
    if (actionKind === "connect") passwordSsid = ""
    actionSsid = ""
    actionKind = ""
  }
  function check(net) {
    if (!net || !busy || actionSsid !== net.name) return
    if (actionKind === "connect" && net.connected) finish()
    else if (actionKind === "disconnect" && !net.connected && !net.stateChanging) finish()
    else if (actionKind === "forget" && !net.known && !net.stateChanging) finish()
  }
  function fail(net, reason) {
    if (!net) return
    const ours = actionKind === "connect" && actionSsid === net.name
    const needsKey = !isOpen(net.security)
    failureSsid = net.name
    failureReason = reason === ConnectionFailReason.NoSecrets && needsKey ? "Password required"
      : reason === ConnectionFailReason.WifiAuthTimeout && needsKey ? "Wrong password"
      : reason === ConnectionFailReason.WifiNetworkLost ? "Network lost"
      : "Couldn't connect"
    if (ours) {
      actionTimeout.stop()
      actionSsid = ""
      actionKind = ""
      if (needsKey && (reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout)) passwordSsid = net.name
    }
  }

  // Row click: known or open networks connect straight away, others ask for
  // a password (and, for 802.1X, an identity) inline.
  function activate(net) {
    if (!net || busy) return
    if (net.known || isOpen(net.security)) { passwordSsid = ""; run("connect", net, n => n.connect()); return }
    failureSsid = ""
    passwordSsid = passwordSsid === net.name ? "" : net.name
  }
  function connectWithPsk(net, psk) { if (psk) run("connect", net, n => n.connectWithPsk(psk)) }
  function connectEnterprise(net, identity, password) {
    if (!identity || !password) return
    run("connect", net, n => {
      enterprise.secret = password
      enterprise.command = ["bash", "-c", enterpriseScript, "nmcli-eap", n.name, identity]
      enterprise.running = true
    })
  }

  // Omarchy's 802.1X profile script (plugins/panels/network/Model.js,
  // enterpriseConnectScript): PEAP/MSCHAPv2 with the password written over
  // stdin into `nmcli connection edit`, never onto a command line.
  readonly property string enterpriseScript:
    "u=$(uuidgen); IFS= read -r pw;" +
    " nmcli connection add type wifi con-name \"$1\" ssid \"$1\" connection.uuid \"$u\"" +
    " wifi-sec.key-mgmt wpa-eap 802-1x.eap peap 802-1x.phase2-auth mschapv2" +
    " 802-1x.identity \"$2\" 802-1x.auth-timeout 8 >/dev/null" +
    " && printf 'set 802-1x.password %s\\nsave\\nquit\\n' \"$pw\" | nmcli connection edit uuid \"$u\" >/dev/null" +
    " && nmcli connection up uuid \"$u\"" +
    " || { nmcli connection delete uuid \"$u\" >/dev/null 2>&1; false; }"
  property Process enterprise: Process {
    property string secret: ""
    stdinEnabled: true
    onStarted: { write(secret + "\n"); secret = "" }
    onExited: code => { if (code !== 0 && root.actionKind === "connect") { root.failureSsid = root.actionSsid; root.failureReason = "Couldn't connect"; root.finish() } }
  }
  function disconnect(net) { run("disconnect", net, n => n.disconnect()) }
  function forget(net) { run("forget", net, n => n.forget()) }
  // Omarchy's share card (plugins/panels/wifiqr).
  function share() {
    Quickshell.execDetached(["omarchy-shell", "shell", "summon", "omarchy.wifiqr",
      JSON.stringify({ iface: info.iface || "", ssid: connectedNetwork ? connectedNetwork.name : "" })])
  }

  property Timer actionTimeout: Timer {
    interval: 25000
    onTriggered: {
      if (root.actionKind !== "") { root.failureSsid = root.actionSsid; root.failureReason = "Timed out" }
      root.actionSsid = ""
      root.actionKind = ""
    }
  }

  property Instantiator watchers: Instantiator {
    model: root.networks
    delegate: Connections {
      required property var modelData
      target: modelData
      function onConnectionFailed(reason) { root.fail(modelData, reason) }
      function onConnectedChanged() { root.check(modelData) }
      function onKnownChanged() { root.check(modelData) }
      function onStateChangingChanged() { root.check(modelData) }
    }
  }

  // ------------------------------------------------------------ details
  // Active route's link details, polled only while a page holds the service.
  property var info: ({})
  property Process details: Process {
    command: ["omarchy-network-status", "--verbose"]
    stdout: StdioCollector {
      onStreamFinished: {
        const next = {}
        for (const line of text.split("\n")) {
          const i = line.indexOf("\t")
          if (i > 0) next[line.slice(0, i)] = line.slice(i + 1).trim()
        }
        root.info = next
      }
    }
  }
  property Timer detailsPoll: Timer {
    running: root.holders > 0
    repeat: true
    interval: 3000
    onTriggered: root.details.running = true
  }
}
