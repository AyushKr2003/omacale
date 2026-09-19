pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// System probes shared by the bar and drawers (network, resources, uptime,
// weather). Polling only runs while something visible asks for it.
QtObject {
  id: root

  function run(cmd) { Quickshell.execDetached(["bash", "-c", cmd]) }

  // ------------------------------------------------------------ time
  // The one clock-format switch (Settings › Language & region › 12-hour
  // clock). Every time Omacale shows goes through these.
  readonly property bool h12: !Config.o.general.clock24
  readonly property string timeFormat: h12 ? "h:mm AP" : "HH:mm"
  function time(d) { return d ? Qt.formatTime(d, timeFormat) : "" }
  // Hour on its own (the stacked bar/dashboard clocks). Qt only gives a
  // 12-hour "hh" when the same format string has an AP, so format both and
  // drop the AP.
  function hour(d) { return d ? (h12 ? Qt.formatTime(d, "hh AP").split(" ")[0] : Qt.formatTime(d, "HH")) : "" }
  function dateTime(d) { return d ? Qt.formatDateTime(d, "d MMM yyyy, " + timeFormat) : "" }
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
  // Mounted disks (deduplicated by device) and the one shown on the dashboard.
  property var disks: []            // [{ mount, used, total }]
  property string primaryMount: "/"
  readonly property var primaryDisk: disks.find(d => d.mount === primaryMount) || disks[0] || null
  property Process diskProbe: Process {
    command: ["bash", "-c",
      "df -B1 --output=source,target,used,size -x tmpfs -x devtmpfs -x efivarfs -x overlay -x squashfs 2>/dev/null | tail -n +2 | sort -u -k1,1; " +
      "for h in /sys/class/hwmon/hwmon*; do case $(cat $h/name 2>/dev/null) in coretemp|k10temp|zenpower) for l in $h/temp*_label; do " +
      "case $(cat $l) in 'Package id'*|Tdie|Tctl) echo temp:$(cat ${l%_label}_input); break 2;; esac; done;; esac; done"]
    property var acc: []
    onStarted: acc = []
    stdout: SplitParser {
      onRead: function(l) {
        if (l.indexOf("temp:") === 0) { root.cpuTemp = (parseInt(l.slice(5)) || 0) / 1000; return }
        const p = l.trim().split(/\s+/)
        if (p.length >= 4) root.diskProbe.acc.push({ mount: p[1], used: Number(p[2]), total: Number(p[3]) })
      }
    }
    onExited: {
      const d = acc.sort((a, b) => a.mount.length - b.mount.length)
      root.disks = d
      const pd = root.primaryDisk
      root.disk = pd && pd.total ? pd.used / pd.total : 0
      root.diskText = pd ? root.fmtBytes(pd.used) + " / " + root.fmtBytes(pd.total) : ""
    }
  }

  // CPU model
  property string cpuName: ""
  property FileView cpuInfo: FileView {
    path: "/proc/cpuinfo"
    printErrors: false
    onLoaded: {
      const m = String(text()).match(/model name\s*:\s*(.+)/)
      root.cpuName = m ? m[1].replace(/\(R\)|\(TM\)|CPU|@.*$/g, "").replace(/\s+/g, " ").trim() : ""
    }
  }

  // GPU (helper never wakes a suspended NVIDIA dGPU)
  property string gpuType: "none"
  property string gpuName: ""
  property real gpu: 0
  property real gpuTemp: 0
  property bool gpuSleeping: false
  property Process gpuProbe: Process {
    command: ["bash", Qt.resolvedUrl("scripts/gpu.sh").toString().replace("file://", "")]
    stdout: SplitParser {
      onRead: function(l) {
        const p = l.split("|")
        root.gpuType = p[0]; root.gpuName = p[1] || ""
        root.gpu = (parseFloat(p[2]) || 0) / 100; root.gpuTemp = parseFloat(p[3]) || 0
        root.gpuSleeping = p[4] === "1"
      }
    }
  }

  // Network throughput (bytes/s) with a rolling history for the sparkline.
  readonly property int netHistory: 30
  property var downHistory: []
  property var upHistory: []
  property real downSpeed: 0
  property real upSpeed: 0
  property real downTotal: 0
  property real upTotal: 0
  property var _lastNet: null
  property FileView netDev: FileView { path: "/proc/net/dev"; printErrors: false }
  function sampleNet() {
    netDev.reload()
    let rx = 0, tx = 0
    String(netDev.text()).split("\n").slice(2).forEach(l => {
      const m = l.trim().match(/^([^:]+):\s*(.*)$/)
      if (!m || m[1] === "lo" || /^(docker|veth|br-|virbr|tun|wg)/.test(m[1])) return
      const f = m[2].split(/\s+/).map(Number)
      rx += f[0]; tx += f[8]
    })
    const now = Date.now()
    if (_lastNet) {
      const dt = Math.max(0.2, (now - _lastNet.t) / 1000)
      downSpeed = Math.max(0, (rx - _lastNet.rx) / dt)
      upSpeed = Math.max(0, (tx - _lastNet.tx) / dt)
      downTotal += Math.max(0, rx - _lastNet.rx)
      upTotal += Math.max(0, tx - _lastNet.tx)
      downHistory = downHistory.concat([downSpeed]).slice(-netHistory)
      upHistory = upHistory.concat([upSpeed]).slice(-netHistory)
    }
    _lastNet = { rx: rx, tx: tx, t: now }
  }

  function fmtBytes(b, perSecond) {
    const u = ["B", "KiB", "MiB", "GiB", "TiB"]
    let i = 0
    b = Math.max(0, b || 0)
    while (b >= 1024 && i < u.length - 1) { b /= 1024; i++ }
    return (i === 0 ? Math.round(b) : b.toFixed(b >= 100 ? 0 : 1)) + " " + u[i] + (perSecond ? "/s" : "")
  }

  property Timer resTimer: Timer {
    interval: 1000; repeat: true; triggeredOnStart: true
    running: root.resourcesWanted > 0
    // A stale baseline would turn the whole time the dashboard was closed
    // into one giant first sample.
    onRunningChanged: if (!running) root._lastNet = null
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
      root.sampleNet()
      if (!root.gpuProbe.running) root.gpuProbe.running = true
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
  // Open-Meteo via scripts/weather.sh — Caelestia's source and WMO codes.
  property string weatherIcon: "cloud"
  property string temp: "--°"
  property string weatherDesc: "Weather"
  property string city: ""
  property string feelsLike: "--°"
  property int humidity: 0
  property real windSpeed: 0
  // Kept raw so a clock-format change reformats them without a refetch.
  property string sunriseIso: ""
  property string sunsetIso: ""
  readonly property string sunrise: fmtTime(sunriseIso)
  readonly property string sunset: fmtTime(sunsetIso)
  property var forecast: []
  readonly property string weatherLocation: Config.o.general.weatherLocation
  readonly property bool imperial: Config.o.general.units === "imperial"
  readonly property var wmoIcons: ({
    "0": "clear_day", "1": "clear_day", "2": "partly_cloudy_day", "3": "cloud", "45": "foggy", "48": "foggy",
    "51": "rainy", "53": "rainy", "55": "rainy", "56": "rainy", "57": "rainy", "61": "rainy", "63": "rainy",
    "65": "rainy", "66": "rainy", "67": "rainy", "71": "cloudy_snowing", "73": "cloudy_snowing", "75": "snowing_heavy",
    "77": "cloudy_snowing", "80": "rainy", "81": "rainy", "82": "rainy", "85": "cloudy_snowing", "86": "snowing_heavy",
    "95": "thunderstorm", "96": "thunderstorm", "99": "thunderstorm"
  })
  readonly property var wmoText: ({
    "0": "Clear", "1": "Clear", "2": "Partly cloudy", "3": "Overcast", "45": "Fog", "48": "Fog",
    "51": "Drizzle", "53": "Drizzle", "55": "Drizzle", "56": "Freezing drizzle", "57": "Freezing drizzle",
    "61": "Light rain", "63": "Rain", "65": "Heavy rain", "66": "Light rain", "67": "Heavy rain",
    "71": "Light snow", "73": "Snow", "75": "Heavy snow", "77": "Snow", "80": "Light rain", "81": "Rain",
    "82": "Heavy rain", "85": "Light snow showers", "86": "Heavy snow showers", "95": "Thunderstorm",
    "96": "Thunderstorm with hail", "99": "Thunderstorm with hail"
  })
  function weatherIconFor(code, day) {
    const i = wmoIcons[String(code)] || "air"
    if (day === 0 && i === "clear_day") return "clear_night"
    if (day === 0 && i === "partly_cloudy_day") return "partly_cloudy_night"
    return i
  }
  function fmtTemp(t) { return t === undefined || t === null ? "--°" : Math.round(t) + (imperial ? "°F" : "°C") }
  function fmtTime(iso) { return iso ? time(new Date(iso)) : "--:--" }
  onWeatherLocationChanged: weatherProbe.running = true
  onImperialChanged: weatherProbe.running = true
  property Process weatherProbe: Process {
    command: ["bash", Qt.resolvedUrl("scripts/weather.sh").toString().replace("file://", ""), root.weatherLocation, root.imperial ? "imperial" : "metric"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const j = JSON.parse(text)
          if (j.error) return
          const c = j.current
          root.city = j.city
          root.temp = root.fmtTemp(c.temperature_2m)
          root.feelsLike = root.fmtTemp(c.apparent_temperature)
          root.humidity = c.relative_humidity_2m
          root.windSpeed = Math.round(c.wind_speed_10m)
          root.weatherIcon = root.weatherIconFor(c.weather_code, c.is_day)
          root.weatherDesc = root.wmoText[String(c.weather_code)] || "Unknown"
          root.forecast = j.daily
          if (j.daily.length) { root.sunriseIso = j.daily[0].sunrise || ""; root.sunsetIso = j.daily[0].sunset || "" }
        } catch (e) {}
      }
    }
  }
  property Timer weatherTimer: Timer {
    interval: 1800000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: root.weatherProbe.running = true
  }

  // ------------------------------------------------------------- players
  property var manualPlayer: null
  readonly property var players: Mpris.players.values
  readonly property var player: {
    const ps = players
    if (manualPlayer && ps.indexOf(manualPlayer) >= 0) return manualPlayer
    return ps.find(p => p.isPlaying) || ps[0] || null
  }
  function playerName(p) { return p ? (p.identity || p.desktopEntry || "Player") : "" }

  // -------------------------------------------------------------- lyrics
  // Synced lyrics from lrclib.net (scripts/lyrics.sh), parsed from LRC.
  property var lyrics: []             // [{ time, text }]
  property string lyricsState: "none" // loading | ready | none
  property string _lyricsKey: ""
  readonly property string lyricsKey: player && Config.o.dashboard.lyrics ? (player.trackArtist + "\u0001" + player.trackTitle) : ""
  onLyricsKeyChanged: lyricsDebounce.restart()
  property Timer lyricsDebounce: Timer {
    interval: 400
    onTriggered: {
      if (root.lyricsKey === root._lyricsKey) return
      root._lyricsKey = root.lyricsKey
      root.lyrics = []
      if (!root.lyricsKey || !root.player.trackTitle) { root.lyricsState = "none"; return }
      root.lyricsState = "loading"
      root.lyricsProbe.running = false
      root.lyricsProbe.command = ["bash", Qt.resolvedUrl("scripts/lyrics.sh").toString().replace("file://", ""),
        root.player.trackArtist || "", root.player.trackTitle || "", root.player.trackAlbum || "",
        String(Math.round(root.player.length > 0 && root.player.length < 36000 ? root.player.length : 0))]
      root.lyricsProbe.running = true
    }
  }
  property Process lyricsProbe: Process {
    stdout: StdioCollector {
      onStreamFinished: {
        const out = []
        String(text).split("\n").forEach(l => {
          const m = l.match(/^\[(\d+):(\d+(?:\.\d+)?)\](.*)$/)
          if (m) out.push({ time: parseInt(m[1]) * 60 + parseFloat(m[2]), text: m[3].trim() })
        })
        root.lyrics = out
        root.lyricsState = out.length ? "ready" : "none"
      }
    }
  }
  function lyricIndexAt(pos) {
    let i = -1
    for (let k = 0; k < lyrics.length; k++) { if (lyrics[k].time <= pos + 0.15) i = k; else break }
    return i
  }

  // ---------------------------------------------------------- visualiser
  // cava via scripts/cava.sh, only while something shows it.
  readonly property int visBars: 60
  property int visualiserWanted: 0
  property var visValues: []
  property bool cavaMissing: false
  property Process cava: Process {
    running: root.visualiserWanted > 0 && !root.cavaMissing && Config.o.dashboard.visualiser
    command: ["bash", Qt.resolvedUrl("scripts/cava.sh").toString().replace("file://", ""), String(root.visBars)]
    stdout: SplitParser {
      onRead: function(l) {
        const v = l.split(";")
        if (v.length >= root.visBars) root.visValues = v.slice(0, root.visBars).map(x => (parseInt(x) || 0) / 1000)
      }
    }
    onExited: (code) => { if (code === 127) root.cavaMissing = true; root.visValues = [] }
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
