.pragma library

// Omacale settings, laid out like Caelestia's Nexus: top-level pages grouped
// by category in the navigation pane, sub-pages opened from "nav" rows.
//
// Row types:
//   section  { text }
//   toggle   { key, label, subtext }
//   stepper  { key, label, subtext, from, to, step }
//   slider   { key, label, icon, from, to, step, unit: "%" | "x" | "px" }
//   select   { key, label, subtext, options: [{ value, label, icon }] }
//   text     { key, label, subtext, placeholder }
//   nav      { icon, label, subtext, page, status? }
//   custom   { comp }  — rendered by a dedicated component
// Any row can carry `when: { key, value }`; it is dimmed and inert unless
// that setting has that value.

var pages = [
  {
    id: "style", label: "Style", icon: "palette", category: "appearance",
    description: "Colours, scheme, transparency",
    rows: [
      { type: "custom", comp: "preview" },
      { type: "section", text: "Colours" },
      { type: "select", key: "appearance.palette", label: "Palette", subtext: "Material colours generated from a seed, or the Omarchy theme's own colours", options: [
        { value: "material", label: "Material", icon: "palette" },
        { value: "omarchy", label: "Omarchy", icon: "format_paint" }
      ] },
      { type: "custom", comp: "seeds", when: { key: "appearance.palette", value: "material" } },
      { type: "select", key: "appearance.variant", when: { key: "appearance.palette", value: "material" }, label: "Scheme", subtext: "How the palette is built from the seed colour", options: [
        { value: "tonalspot", label: "Tonal spot", icon: "palette" },
        { value: "vibrant", label: "Vibrant", icon: "colors" },
        { value: "expressive", label: "Expressive", icon: "gradient" },
        { value: "fidelity", label: "Fidelity", icon: "filter_vintage" },
        { value: "content", label: "Content", icon: "image" },
        { value: "fruitsalad", label: "Fruit salad", icon: "nutrition" },
        { value: "rainbow", label: "Rainbow", icon: "looks" },
        { value: "neutral", label: "Neutral", icon: "contrast" },
        { value: "monochrome", label: "Monochrome", icon: "tonality" }
      ] },
      { type: "select", key: "appearance.mode", when: { key: "appearance.palette", value: "material" }, label: "Mode", subtext: "Light or dark surfaces", options: [
        { value: "auto", label: "Follow theme", icon: "brightness_auto" },
        { value: "dark", label: "Dark", icon: "dark_mode" },
        { value: "light", label: "Light", icon: "light_mode" }
      ] },
      { type: "section", text: "Transparency" },
      { type: "toggle", key: "appearance.transparency.enabled", label: "Transparency", subtext: "Translucent frame and drawers with background blur" },
      { type: "slider", key: "appearance.transparency.base", label: "Surface opacity", icon: "opacity", from: 0.3, to: 1, step: 0.01, unit: "%" },
      { type: "slider", key: "appearance.transparency.layers", label: "Card opacity", icon: "layers", from: 0.1, to: 1, step: 0.01, unit: "%" }
    ]
  },
  {
    id: "frame", label: "Frame & motion", icon: "rounded_corner", category: "appearance",
    description: "Border, rounding, shadow, animation speed",
    rows: [
      { type: "section", text: "Frame" },
      { type: "slider", key: "border.thickness", label: "Border thickness", icon: "border_outer", from: 0, to: 30, step: 1, unit: "px" },
      { type: "slider", key: "border.rounding", label: "Corner rounding", icon: "rounded_corner", from: 0, to: 48, step: 1, unit: "px" },
      { type: "slider", key: "border.smoothing", label: "Drawer blending", icon: "join", from: 2, to: 40, step: 1, unit: "px" },
      { type: "toggle", key: "appearance.shadow", label: "Shadow", subtext: "Soft shadow under the frame and drawers" },
      { type: "section", text: "Motion" },
      { type: "slider", key: "appearance.animScale", label: "Animation duration", icon: "animation", from: 0.25, to: 2, step: 0.05, unit: "x" }
    ]
  },
  {
    id: "network", label: "Network", icon: "wifi", category: "connectivity",
    description: "Wi-Fi, ethernet",
    rows: [ { type: "custom", comp: "network" } ]
  },
  {
    id: "bluetooth", label: "Connected devices", icon: "devices_other", category: "connectivity",
    description: "Bluetooth, pairing",
    rows: [ { type: "custom", comp: "bluetooth" } ]
  },
  {
    id: "panels", label: "Panels", icon: "dock_to_bottom", category: "shell",
    description: "Taskbar, dashboard, launcher, session, sidebar, utilities",
    rows: [
      { type: "nav", icon: "dock_to_right", label: "Taskbar", page: "taskbar", status: "bar" },
      { type: "nav", icon: "dashboard", label: "Dashboard", page: "dashboard", status: "dashboard.enabled" },
      { type: "nav", icon: "apps", label: "Launcher", page: "launcher", status: "launcher.enabled" },
      { type: "nav", icon: "power_settings_new", label: "Session", page: "session", status: "session.enabled" },
      { type: "nav", icon: "notifications", label: "Sidebar", page: "sidebar", status: "sidebar.enabled" },
      { type: "nav", icon: "tune", label: "Utilities", page: "utilities", status: "utilities.enabled" }
    ]
  },
  {
    id: "region", label: "Language & region", icon: "globe", category: "shell",
    description: "Clock format, weather location, units",
    rows: [
      { type: "section", text: "Clock" },
      { type: "toggle", key: "general.clock24", invert: true, label: "12-hour clock", subtext: "AM/PM everywhere: bar, dashboard, weather, notifications, keep awake, recordings" },
      { type: "section", text: "Weather" },
      { type: "text", key: "general.weatherLocation", label: "Location", subtext: "City name; empty detects it from your IP", placeholder: "Auto" },
      { type: "select", key: "general.units", label: "Units", subtext: "Temperature units", options: [
        { value: "metric", label: "Celsius", icon: "thermometer" },
        { value: "imperial", label: "Fahrenheit", icon: "thermostat" }
      ] }
    ]
  },
  {
    id: "keybinds", label: "Keybinds", icon: "keyboard", category: "system",
    description: "Omarchy-style bindings to copy",
    rows: [ { type: "custom", comp: "keybinds" } ]
  },
  {
    id: "looknfeel", label: "Look'n'feel", icon: "auto_awesome", category: "system",
    description: "Caelestia's Hyprland styling to load",
    rows: [ { type: "custom", comp: "looknfeel" } ]
  },
  {
    id: "about", label: "About", icon: "info", category: "about",
    description: "Omacale, system, reset",
    rows: [ { type: "custom", comp: "about" } ]
  }
]

var subpages = {
  networkDetail: { title: "Network details", rows: [ { type: "custom", comp: "networkDetail" } ] },
  btPair: { title: "Pair new device", rows: [ { type: "custom", comp: "btPair" } ] },
  btDevice: { title: "Device", rows: [ { type: "custom", comp: "btDevice" } ] },
  taskbar: {
    title: "Taskbar",
    rows: [
      { type: "section", text: "Behaviour" },
      { type: "toggle", key: "bar.persistent", label: "Persistent", subtext: "Keep the bar visible at all times" },
      { type: "toggle", key: "bar.showOnHover", label: "Show on hover", subtext: "Reveal the bar when the cursor reaches the left edge" },
      { type: "section", text: "Components" },
      { type: "nav", icon: "workspaces", label: "Workspaces", subtext: "Indicators, window icons", page: "workspaces" },
      { type: "nav", icon: "web_asset", label: "Active window", subtext: "Title display, popout", page: "activeWindow" },
      { type: "nav", icon: "widgets", label: "Tray", subtext: "System tray icons", page: "tray" },
      { type: "nav", icon: "signal_cellular_alt", label: "Status icons", subtext: "Visible indicators", page: "status" },
      { type: "nav", icon: "schedule", label: "Clock", subtext: "Date, icon, background", page: "clock" },
      { type: "toggle", key: "bar.logo", label: "Logo", subtext: "Icon at the top; click opens the launcher" },
      { type: "custom", comp: "logoPicker" },
      { type: "toggle", key: "bar.power", label: "Power button", subtext: "Opens the session menu" },
      { type: "section", text: "Scroll actions" },
      { type: "toggle", key: "bar.scroll.workspaces", label: "Workspaces", subtext: "Scroll over the workspace indicator to switch workspaces" },
      { type: "toggle", key: "bar.scroll.volume", label: "Volume", subtext: "Scroll on the top half of the bar to adjust volume" },
      { type: "toggle", key: "bar.scroll.brightness", label: "Brightness", subtext: "Scroll on the bottom half of the bar to adjust brightness" }
    ]
  },
  workspaces: {
    title: "Workspaces",
    rows: [
      { type: "stepper", key: "bar.workspaces.shown", label: "Shown", subtext: "Number of workspaces displayed", from: 1, to: 10, step: 1 },
      { type: "select", key: "bar.workspaces.display", label: "Display", subtext: "How each workspace is drawn", options: [
        { value: "shapes", label: "Shapes", icon: "category" },
        { value: "numbers", label: "Numbers", icon: "pin" }
      ] },
      { type: "toggle", key: "bar.workspaces.activeIndicator", label: "Active indicator" },
      { type: "toggle", key: "bar.workspaces.activeTrail", label: "Active trail", subtext: "The indicator's trailing edge lags behind" },
      { type: "toggle", key: "bar.workspaces.occupiedBg", label: "Occupied background", subtext: "Highlight runs of occupied workspaces" },
      { type: "toggle", key: "bar.workspaces.showWindows", label: "Show windows", subtext: "Show icons of open windows on each workspace" },
      { type: "stepper", key: "bar.workspaces.maxWindowIcons", label: "Max window icons", from: 0, to: 10, step: 1 },
      { type: "section", text: "Special workspaces" },
      { type: "select", key: "bar.workspaces.specialDisplay", label: "Display", subtext: "How the scratchpad and other special workspaces are drawn while one is open", options: [
        { value: "icons", label: "Icons", icon: "star" },
        { value: "star", label: "Star only", icon: "grade" },
        { value: "letters", label: "Letters", icon: "text_fields" },
        { value: "shapes", label: "Shapes", icon: "category" }
      ] },
      { type: "toggle", key: "bar.workspaces.specialShowWindows", label: "Show windows", subtext: "Show icons of open windows on each special workspace" }
    ]
  },
  activeWindow: {
    title: "Active window",
    rows: [
      { type: "toggle", key: "bar.activeWindow.enabled", label: "Show title", subtext: "Rotated window title in the middle of the bar" },
      { type: "toggle", key: "bar.activeWindow.compact", label: "Compact", subtext: "Show only the last part of titles like 'Page — Browser'" },
      { type: "toggle", key: "bar.popouts.activeWindow", label: "Popout on hover", subtext: "Show a live window preview when hovering" }
    ]
  },
  tray: {
    title: "Tray",
    rows: [
      { type: "toggle", key: "bar.tray.enabled", label: "Show tray" },
      { type: "toggle", key: "bar.tray.background", label: "Background", subtext: "Draw a pill behind the tray" },
      { type: "toggle", key: "bar.tray.recolour", label: "Recolour icons", subtext: "Tint tray icons with the scheme" },
      { type: "toggle", key: "bar.popouts.tray", label: "Popout on hover", subtext: "Show the tray menu when hovering an icon" }
    ]
  },
  status: {
    title: "Status icons",
    rows: [
      { type: "section", text: "Visible icons" },
      { type: "toggle", key: "bar.status.lockStatus", label: "Caps / num lock", subtext: "Only shown while a lock key is on" },
      { type: "toggle", key: "bar.status.audio", label: "Audio" },
      { type: "toggle", key: "bar.status.microphone", label: "Microphone" },
      { type: "toggle", key: "bar.status.network", label: "Network" },
      { type: "toggle", key: "bar.status.bluetooth", label: "Bluetooth" },
      { type: "toggle", key: "bar.status.battery", label: "Battery / power profile" },
      { type: "toggle", key: "bar.status.keepAwake", label: "Keep awake", subtext: "Coffee icon while keep awake is on" },
      { type: "toggle", key: "bar.status.notifications", label: "Notifications", subtext: "Unread count and do-not-disturb state; click opens the sidebar" },
      { type: "section", text: "Behaviour" },
      { type: "toggle", key: "bar.popouts.statusIcons", label: "Popout on hover", subtext: "Show a details popout when hovering the status icons" }
    ]
  },
  clock: {
    title: "Clock",
    rows: [
      { type: "toggle", key: "bar.clock.background", label: "Background" },
      { type: "toggle", key: "bar.clock.showDate", label: "Show date" },
      { type: "toggle", key: "bar.clock.showIcon", label: "Show icon" },
      { type: "toggle", key: "bar.clock.showSeconds", label: "Show seconds" }
    ]
  },
  dashboard: {
    title: "Dashboard",
    rows: [
      { type: "section", text: "General" },
      { type: "toggle", key: "dashboard.enabled", label: "Enabled" },
      { type: "toggle", key: "dashboard.showOnHover", label: "Show on hover", subtext: "Reveal when the cursor reaches the top edge" },
      { type: "toggle", key: "dashboard.clockSeconds", label: "Show clock seconds", subtext: "Display seconds for the clock in the main panel" },
      { type: "toggle", key: "dashboard.mediaGif", label: "Bongo cat", subtext: "Dance along while media plays" },
      { type: "section", text: "Media" },
      { type: "toggle", key: "dashboard.lyrics", label: "Lyrics", subtext: "Synced lyrics from lrclib.net" },
      { type: "toggle", key: "dashboard.visualiser", label: "Visualiser", subtext: "Audio bars around the cover art (needs cava)" },
      { type: "section", text: "Tabs" },
      { type: "toggle", key: "dashboard.tabs.dashboard", label: "Dashboard" },
      { type: "toggle", key: "dashboard.tabs.media", label: "Media" },
      { type: "toggle", key: "dashboard.tabs.performance", label: "Performance" },
      { type: "toggle", key: "dashboard.tabs.weather", label: "Weather" },
      { type: "section", text: "Performance widgets" },
      { type: "toggle", key: "dashboard.performance.showBattery", label: "Battery" },
      { type: "toggle", key: "dashboard.performance.showGpu", label: "GPU" },
      { type: "toggle", key: "dashboard.performance.showCpu", label: "CPU" },
      { type: "toggle", key: "dashboard.performance.showMemory", label: "Memory" },
      { type: "toggle", key: "dashboard.performance.showStorage", label: "Storage" },
      { type: "toggle", key: "dashboard.performance.showNetwork", label: "Network" }
    ]
  },
  launcher: {
    title: "Launcher",
    rows: [
      { type: "section", text: "General" },
      { type: "toggle", key: "launcher.enabled", label: "Enabled" },
      { type: "text", key: "launcher.actionPrefix", label: "Action prefix", subtext: "Prefix used to run actions in the launcher", placeholder: ">" },
      { type: "section", text: "Display" },
      { type: "stepper", key: "launcher.maxShown", label: "Max items shown", from: 3, to: 12, step: 1 },
      { type: "stepper", key: "launcher.maxWallpapers", label: "Max wallpapers shown", subtext: "Carousel size for \">wallpaper\" and \">theme\"", from: 1, to: 15, step: 2 },
      { type: "stepper", key: "launcher.dragThreshold", label: "Drag threshold", subtext: "Pixels dragged up from the bottom edge before it opens", from: 10, to: 200, step: 5 },
      { type: "section", text: "Behaviour" },
      { type: "toggle", key: "launcher.vimKeybinds", label: "Vim keybinds", subtext: "Navigate results with Ctrl+J / Ctrl+K" },
      { type: "toggle", key: "launcher.dangerousActions", label: "Enable dangerous actions", subtext: "Allow actions that shut down or log out" }
    ]
  },
  session: {
    title: "Session",
    rows: [
      { type: "toggle", key: "session.enabled", label: "Enabled" },
      { type: "toggle", key: "session.gif", label: "Animation", subtext: "Show the spinning character between the buttons" },
      { type: "toggle", key: "session.vimKeybinds", label: "Vim keybinds", subtext: "Move between buttons with Ctrl+J / Ctrl+K" },
      { type: "stepper", key: "session.dragThreshold", label: "Drag threshold", subtext: "Pixels dragged in from the right edge before it opens", from: 10, to: 200, step: 5 },
      { type: "select", key: "session.sleepAction", label: "Third button", subtext: "What the download-arrow button does", options: [
        { value: "hibernate", label: "Hibernate", icon: "downloading" },
        { value: "suspend", label: "Suspend", icon: "bedtime" }
      ] }
    ]
  },
  sidebar: {
    title: "Sidebar",
    rows: [
      { type: "section", text: "General" },
      { type: "toggle", key: "sidebar.enabled", label: "Enabled", subtext: "Enable notification sidebar drawer" },
      { type: "slider", key: "sidebar.width", label: "Sidebar width", icon: "dock_to_right", from: 320, to: 600, step: 10, unit: "px" }
    ]
  },
  utilities: {
    title: "Utilities",
    rows: [
      { type: "section", text: "General" },
      { type: "toggle", key: "utilities.enabled", label: "Enabled", subtext: "Enable quick toggles and utilities drawer" },
      { type: "slider", key: "utilities.width", label: "Utilities width", icon: "tune", from: 320, to: 600, step: 10, unit: "px" },
      { type: "section", text: "Quick toggles" },
      { type: "toggle", key: "utilities.toggles.wifi", label: "Wi-Fi" },
      { type: "toggle", key: "utilities.toggles.bluetooth", label: "Bluetooth" },
      { type: "toggle", key: "utilities.toggles.mic", label: "Microphone" },
      { type: "toggle", key: "utilities.toggles.settings", label: "Settings", subtext: "Opens Omacale settings" },
      { type: "toggle", key: "utilities.toggles.gameMode", label: "Game mode" },
      { type: "toggle", key: "utilities.toggles.dnd", label: "Do not disturb" },
      { type: "toggle", key: "utilities.toggles.nightlight", label: "Night light", subtext: "Omarchy's night light; more than six toggles wrap onto a second row" }
    ]
  }
}

function pageById(id) {
  for (var i = 0; i < pages.length; i++) if (pages[i].id === id) return pages[i]
  return subpages[id] ? { id: id, label: subpages[id].title, rows: subpages[id].rows, isSub: true } : null
}

// Every searchable row, tagged with where it lives.
function searchRows(query) {
  var q = String(query || "").trim().toLowerCase()
  if (!q) return []
  var out = []
  var add = function(where, rows) {
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i]
      if (r.type === "section" || r.type === "custom" || r.type === "nav") continue
      var hay = (r.label + " " + (r.subtext || "") + " " + where).toLowerCase()
      if (hay.indexOf(q) >= 0) out.push(Object.assign({ where: where }, r))
    }
  }
  for (var p = 0; p < pages.length; p++) add(pages[p].label, pages[p].rows)
  for (var id in subpages) add(subpages[id].title, subpages[id].rows)
  return out
}
