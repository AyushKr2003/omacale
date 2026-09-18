pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// System probes shared by the bar and drawers (network, resources, uptime,
// weather). Polling only runs while something visible asks for it.
QtObject {
  id: root

  function run(cmd) { Quickshell.execDetached(["bash", "-c", cmd]) }
  function hypr(dispatcher) { Quickshell.execDetached(["hyprctl", "dispatch", dispatcher]) }
  function workspace(id) { hypr('hl.dsp.focus({ workspace = "' + id + '" })') }

  // ------------------------------------------------------------ network
  property bool ethernet: false
  property bool wifi: false
  property string ssid: ""
  property int strength: 0
  property var networks: []   // [{ssid, strength, secure, active}]
  property bool _seen: false

  property Process netProbe: Process {
    command: ["bash", "-c",
      "nmcli -t -f TYPE,STATE device 2>/dev/null | awk -F: '$2==\"connected\"{print \"dev:\"$1}'; " +
      "nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID dev wifi list --rescan no 2>/dev/null | head -12 | sed 's/^/ap:/'"]
    property var acc: ({ eth: false, wifi: false, aps: [] })
    onStarted: acc = { eth: false, wifi: false, aps: [] }
    stdout: SplitParser {
      onRead: function(line) {
        const a = root.netProbe.acc
        if (line === "dev:ethernet") a.eth = true
        else if (line === "dev:wifi") a.wifi = true
        else if (line.indexOf("ap:") === 0) {
          const p = line.slice(3).split(":")
          if (p.length >= 4 && p.slice(3).join(":")) {
            const ssid = p.slice(3).join(":").replace(/\\:/g, ":")
            if (!a.aps.some(x => x.ssid === ssid))
              a.aps.push({ active: p[0] === "*", strength: parseInt(p[1]) || 0, secure: p[2] !== "" && p[2] !== "--", ssid: ssid })
          }
        }
      }
    }
    onExited: {
      const a = acc
      root.ethernet = a.eth
      root.wifi = a.wifi
      const act = a.aps.find(x => x.active)
      root.ssid = act ? act.ssid : ""
      root.strength = act ? act.strength : 0
      root.networks = a.aps.sort((x, y) => (y.active - x.active) || (y.strength - x.strength))
    }
  }
  property Timer netTimer: Timer {
    interval: 5000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: root.netProbe.running = true
  }

  // ---------------------------------------------------------- resources
  property int resourcesWanted: 0
  property real cpu: 0
  property real mem: 0
  property real memUsedGb: 0
  property real memTotalGb: 0
  property real disk: 0
  property string diskText: ""
  property real cpuTemp: 0
  property var _lastCpu: null

  property FileView statFile: FileView { path: "/proc/stat"; printErrors: false }
  property FileView memFile: FileView { path: "/proc/meminfo"; printErrors: false }
  property Process diskProbe: Process {
    command: ["bash", "-c", "df -B1 --output=used,size / | tail -1; for z in /sys/class/thermal/thermal_zone*; do [[ $(cat $z/type) == x86_pkg_temp || $(cat $z/type) == acpitz ]] && { cat $z/temp; break; }; done"]
    property int n: 0
    onStarted: n = 0
    stdout: SplitParser {
      onRead: function(l) {
        if (root.diskProbe.n++ === 0) {
          const p = l.trim().split(/\s+/).map(Number)
          root.disk = p[1] ? p[0] / p[1] : 0
          root.diskText = (p[0] / 1e9).toFixed(0) + " / " + (p[1] / 1e9).toFixed(0) + " GB"
        } else root.cpuTemp = (parseInt(l) || 0) / 1000
      }
    }
  }
  property Timer resTimer: Timer {
    interval: 2000; repeat: true; triggeredOnStart: true
    running: root.resourcesWanted > 0
    onTriggered: {
      root.statFile.reload()
      const m = String(root.statFile.text()).split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
      const idle = m[3] + (m[4] || 0)
      const total = m.reduce((a, b) => a + b, 0)
      if (root._lastCpu) {
        const dt = total - root._lastCpu.total, di = idle - root._lastCpu.idle
        root.cpu = dt > 0 ? Math.max(0, Math.min(1, 1 - di / dt)) : 0
      }
      root._lastCpu = { total: total, idle: idle }
      root.memFile.reload()
      const t = String(root.memFile.text())
      const tot = parseInt((t.match(/MemTotal:\s+(\d+)/) || [])[1]) || 1
      const av = parseInt((t.match(/MemAvailable:\s+(\d+)/) || [])[1]) || 0
      root.mem = 1 - av / tot
      root.memUsedGb = (tot - av) / 1048576
      root.memTotalGb = tot / 1048576
      root.diskProbe.running = true
    }
  }

  // ------------------------------------------------------------- uptime
  property string uptime: ""
  property FileView uptimeFile: FileView { path: "/proc/uptime"; printErrors: false }
  property Timer uptimeTimer: Timer {
    interval: 60000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: {
      root.uptimeFile.reload()
      const s = parseFloat(String(root.uptimeFile.text()).split(" ")[0]) || 0
      const d = Math.floor(s / 86400), h = Math.floor(s / 3600) % 24, m = Math.floor(s / 60) % 60
      const parts = []
      if (d) parts.push(d + (d === 1 ? " day" : " days"))
      if (h) parts.push(h + (h === 1 ? " hour" : " hours"))
      if (!d && m) parts.push(m + (m === 1 ? " minute" : " minutes"))
      root.uptime = parts.join(", ") || "just now"
    }
  }

  // ------------------------------------------------------------ weather
  property string weatherIcon: "cloud"
  property string temp: "--°C"
  property string weatherDesc: "Weather"
  property string city: ""
  readonly property var _codes: ({
    "113": "clear_day", "116": "partly_cloudy_day", "119": "cloud", "122": "cloud", "143": "foggy",
    "176": "rainy", "179": "weather_snowy", "182": "rainy_snow", "185": "rainy_snow", "200": "thunderstorm",
    "227": "weather_snowy", "230": "severe_cold", "248": "foggy", "260": "foggy", "263": "rainy", "266": "rainy",
    "281": "rainy", "284": "rainy", "293": "rainy", "296": "rainy", "299": "rainy", "302": "rainy", "305": "rainy",
    "308": "rainy", "311": "rainy", "314": "rainy", "317": "rainy_snow", "320": "weather_snowy", "323": "weather_snowy",
    "326": "weather_snowy", "329": "weather_snowy", "332": "weather_snowy", "335": "weather_snowy", "338": "weather_snowy",
    "350": "weather_hail", "353": "rainy", "356": "rainy", "359": "rainy", "362": "rainy_snow", "365": "rainy_snow",
    "368": "weather_snowy", "371": "weather_snowy", "374": "weather_hail", "377": "weather_hail", "386": "thunderstorm",
    "389": "thunderstorm", "392": "thunderstorm", "395": "weather_snowy"
  })
  readonly property string weatherLocation: Config.o.general.weatherLocation
  readonly property bool imperial: Config.o.general.units === "imperial"
  onWeatherLocationChanged: weatherProbe.running = true
  onImperialChanged: weatherProbe.running = true
  property Process weatherProbe: Process {
    command: ["curl", "-s", "--max-time", "8", "https://wttr.in/" + encodeURIComponent(root.weatherLocation) + "?format=j1"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const j = JSON.parse(text)
          const c = j.current_condition[0]
          root.temp = root.imperial ? c.temp_F + "°F" : c.temp_C + "°C"
          root.weatherDesc = c.weatherDesc[0].value
          root.weatherIcon = root._codes[c.weatherCode] || "air"
          root.city = j.nearest_area ? j.nearest_area[0].areaName[0].value : ""
        } catch (e) {}
      }
    }
  }
  property Timer weatherTimer: Timer {
    interval: 1800000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: root.weatherProbe.running = true
  }

  // --------------------------------------------------------------- icons
  readonly property var categoryIcons: ({
    WebBrowser: "web", Printing: "print", Security: "security", Network: "chat", Archiving: "archive",
    Compression: "archive", Development: "code", IDE: "code", TextEditor: "edit_note", Audio: "music_note",
    Music: "music_note", Player: "music_note", Recorder: "mic", Game: "sports_esports", FileTools: "files",
    FileManager: "files", Filesystem: "files", FileTransfer: "files", Settings: "settings",
    DesktopSettings: "settings", HardwareSettings: "settings", TerminalEmulator: "terminal",
    ConsoleOnly: "terminal", Utility: "build", Monitor: "monitor_heart", Midi: "graphic_eq", Mixer: "graphic_eq",
    AudioVideoEditing: "video_settings", AudioVideo: "music_video", Video: "videocam", Building: "construction",
    Graphics: "photo_library", "2DGraphics": "photo_library", RasterGraphics: "photo_library", TV: "tv",
    System: "host", Office: "content_paste"
  })
  function appIcon(cls, fallback) {
    if (!cls) return fallback
    const e = DesktopEntries.heuristicLookup(cls)
    const cats = e ? e.categories : null
    if (cats) for (const k in categoryIcons) if (cats.indexOf(k) !== -1) return categoryIcons[k]
    return fallback
  }
  function networkIcon(s) {
    return ["signal_wifi_0_bar", "network_wifi_1_bar", "network_wifi_2_bar", "network_wifi_3_bar", "network_wifi"][Math.max(0, Math.min(4, Math.floor(s / 20)))]
  }
  function batteryIcon(p, charging) {
    if (p >= 0.995) return charging ? "battery_charging_full" : "battery_full"
    let level = Math.floor(p * 7)
    if (charging && (level === 4 || level === 1)) level--
    return charging ? "battery_charging_" + ((level + 3) * 10) : "battery_" + level + "_bar"
  }
  function bluetoothIcon(icon) {
    const i = String(icon || "")
    if (i.indexOf("headset") >= 0 || i.indexOf("headphones") >= 0) return "headphones"
    if (i.indexOf("audio") >= 0) return "speaker"
    if (i.indexOf("phone") >= 0) return "smartphone"
    if (i.indexOf("mouse") >= 0) return "mouse"
    if (i.indexOf("keyboard") >= 0) return "keyboard"
    return "bluetooth"
  }
}
