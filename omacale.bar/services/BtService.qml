pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import ".."

// Bluetooth state and actions for the settings Connected devices page. Same
// engine as Omarchy's own bluetooth panel (plugins/panels/bluetooth):
// Quickshell.Bluetooth for state, `omarchy-bluetooth-power` to switch the
// radio (an rfkill block that survives reboots, unlike BlueZ's Powered) and
// `omarchy-bluetooth-device` to pair / connect / disconnect / forget.
QtObject {
  id: root

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool enabled: !!(adapter && adapter.enabled)
  readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []

  function remembered(d) { return !!(d && (d.paired || d.bonded || d.trusted)) }
  // Omarchy's panel hides devices that only advertise a UUID or MAC as name.
  function hasName(d) {
    const n = String(d && (d.deviceName || d.name) || "").trim()
    return n !== "" && !/^([0-9a-f]{2}[:-]){5}[0-9a-f]{2}$/i.test(n) && !/^[0-9a-f-]{32,36}$/i.test(n)
  }
  function label(d) { return String(d && (d.deviceName || d.name) || "Unknown device").trim() }

  readonly property var saved: devices.filter(d => remembered(d))
    .sort((a, b) => (b.connected - a.connected) || label(a).localeCompare(label(b)))
  readonly property var discovered: devices.filter(d => d && !remembered(d) && hasName(d))
    .sort((a, b) => label(a).localeCompare(label(b)))

  function setEnabled(on) { Quickshell.execDetached(["omarchy-bluetooth-power", on ? "on" : "off"]) }

  // address -> "connecting" | "disconnecting" | "forgetting"
  property var pending: ({})
  function pendingOf(d) { return d ? (pending[d.address] || "") : "" }
  function setPending(address, action) {
    const next = Object.assign({}, pending)
    if (action) next[address] = action; else delete next[address]
    pending = next
    if (action) pendingTimeout.restart()
  }
  function run(d, action, state) {
    if (!d || !d.address || pendingOf(d)) return
    setPending(d.address, state)
    Quickshell.execDetached(["omarchy-bluetooth-device", action, d.address])
  }
  function connect(d) { if (d && !d.connected) run(d, remembered(d) ? "connect" : "pair", "connecting") }
  function disconnect(d) { if (d && d.connected) run(d, "disconnect", "disconnecting") }
  function forget(d) { run(d, "forget", "forgetting") }
  function toggle(d) { if (d) d.connected ? disconnect(d) : connect(d) }

  // Clear finished actions as BlueZ reports them.
  function sync() {
    let changed = false
    const next = Object.assign({}, pending)
    for (const address in next) {
      const d = devices.find(x => x && x.address === address)
      const a = next[address]
      if ((a === "connecting" && d && d.connected) || (a === "disconnecting" && d && !d.connected)
          || (a === "forgetting" && (!d || !remembered(d)))) {
        delete next[address]
        changed = true
      }
    }
    if (changed) pending = next
  }
  property Timer syncTimer: Timer {
    running: Object.keys(root.pending).length > 0
    repeat: true
    interval: 500
    onTriggered: root.sync()
  }
  property Timer pendingTimeout: Timer { interval: 30000; onTriggered: root.pending = ({}) }

  // Discovery while the pairing page is open; Omarchy's panel does the same
  // and only stops a scan it started.
  property int scanners: 0
  property bool ownsDiscovery: false
  function holdDiscovery(on) {
    scanners = Math.max(0, scanners + (on ? 1 : -1))
    syncDiscovery()
  }
  function syncDiscovery() {
    if (!adapter) return
    if (scanners > 0 && enabled && !adapter.discovering) { ownsDiscovery = true; adapter.discovering = true }
    else if (scanners === 0 && ownsDiscovery) { ownsDiscovery = false; if (adapter.discovering) adapter.discovering = false }
  }
  onEnabledChanged: syncDiscovery()
  // BlueZ ends discovery on its own after a while; keep it going.
  property Timer discoveryRetry: Timer {
    running: root.scanners > 0 && root.enabled && !!root.adapter && !root.adapter.discovering
    interval: 1500
    onTriggered: root.syncDiscovery()
  }

  // Device the info sub-page shows.
  property string selectedAddress: ""
  readonly property var selected: devices.find(d => d && d.address === selectedAddress) || null
}
