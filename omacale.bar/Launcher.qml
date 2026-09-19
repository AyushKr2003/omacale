import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// Caelestia launcher: results list above a pill search bar, keyboard driven.
// Typing ">" lists Omarchy actions instead of apps; ">wallpaper " and
// ">theme " swap the list for the wallpaper carousel (Caelestia ContentList).
Item {
  id: root

  property bool active: false
  property real maxHeight: 800
  signal dismissed()
  signal openSettings()
  readonly property var cfg: Config.o.launcher
  readonly property string prefix: cfg.actionPrefix || ">"

  readonly property int padding: Tk.padding.large
  readonly property int itemH: Tk.sizes.launcherItemHeight
  readonly property string wallPrefix: prefix + "wallpaper "
  readonly property string themePrefix: prefix + "theme "
  readonly property string mode: search.text.startsWith(wallPrefix) ? "wallpapers"
                               : search.text.startsWith(themePrefix) ? "themes" : "apps"
  readonly property bool actionMode: mode === "apps" && search.text.startsWith(prefix)
  // Sizes lag `mode` behind a fade, as Caelestia's animState.
  property string animState: mode
  property real screenWidth: 0
  readonly property string query: search.text.split(" ").slice(1).join(" ")
  property string pendingText: ""

  // Open straight into a carousel ("wallpaper" / "theme"), e.g. from IPC.
  function openMode(kind) {
    const text = prefix + kind + " "
    if (active) { search.text = text; search.forceActiveFocus() }
    else pendingText = text
  }

  readonly property var actions: [
    { name: "Settings", comment: "Open Omacale settings", icon: "settings", settings: true },
    { name: "Lock", comment: "Lock the screen", icon: "lock", cmd: "omarchy system lock", dangerous: true },
    { name: "Logout", comment: "End this session", icon: "logout", cmd: "omarchy system logout", dangerous: true },
    { name: "Shutdown", comment: "Power off", icon: "power_settings_new", cmd: "omarchy system shutdown", dangerous: true },
    { name: "Reboot", comment: "Restart the computer", icon: "cached", cmd: "omarchy system reboot", dangerous: true },
    // These autocomplete into the carousel, as Caelestia's Wallpaper/Scheme
    // actions; `cmd` (Omarchy's own pickers) is kept for reference only.
    { name: "Theme", comment: "Change the Omarchy theme", icon: "palette", autocomplete: "theme", cmd: 'theme=$(omarchy-theme-switcher); [[ -n $theme ]] && omarchy-theme-set "$theme"' },
    { name: "Background", comment: "Change the wallpaper", icon: "wallpaper", autocomplete: "wallpaper", cmd: 'background=$(omarchy-theme-bg-switcher); [[ -n $background ]] && omarchy-theme-bg-set "$background"' },
    { name: "Wallpaper", comment: "Next background", icon: "wallpaper", cmd: "omarchy theme bg next" },
    { name: "Nightlight", comment: "Toggle night light", icon: "nightlight", cmd: "omarchy toggle nightlight" },
    { name: "Screenshot", comment: "Capture a region", icon: "screenshot_region", cmd: "omarchy capture screenshot" },
    { name: "Menu", comment: "Open the Omarchy menu", icon: "menu", cmd: "omarchy-menu" },
    { name: "Update", comment: "Update the system", icon: "system_update_alt", cmd: "omarchy launch floating-terminal-with-presentation omarchy update" }
  ]

  readonly property var results: {
    const q = (actionMode ? search.text.slice(prefix.length) : search.text).trim().toLowerCase()
    if (actionMode) return actions.filter(a => (cfg.dangerousActions || !a.dangerous) && (!q || a.name.toLowerCase().indexOf(q) >= 0)).map(a => ({ action: a }))
    const apps = DesktopEntries.applications.values.filter(e => !e.noDisplay)
    if (!q) return apps.slice().sort((a, b) => a.name.localeCompare(b.name)).map(e => ({ app: e }))
    const scored = []
    for (let i = 0; i < apps.length; i++) {
      const e = apps[i], n = e.name.toLowerCase()
      let s = -1
      if (n === q) s = 0
      else if (n.startsWith(q)) s = 1
      else if (n.split(/\s+/).some(w => w.startsWith(q))) s = 2
      else if (n.indexOf(q) >= 0) s = 3
      else if ((e.genericName || "").toLowerCase().indexOf(q) >= 0) s = 4
      else if ((e.keywords || []).join(" ").toLowerCase().indexOf(q) >= 0) s = 5
      if (s >= 0) scored.push({ e: e, s: s })
    }
    scored.sort((a, b) => a.s - b.s || a.e.name.localeCompare(b.e.name))
    return scored.map(x => ({ app: x.e }))
  }

  function activate(r) {
    if (!r) return
    if (r.action && r.action.settings) { root.openSettings(); return }
    if (r.action && r.action.autocomplete) { search.text = prefix + r.action.autocomplete + " "; return }
    if (r.app) r.app.execute(); else Sys.run(r.action.cmd)
    root.dismissed()
  }

  onActiveChanged: {
    if (active) { search.text = pendingText; pendingText = ""; list.currentIndex = 0; search.forceActiveFocus() }
    else Wallpapers.stopPreview()
  }

  readonly property var carouselView: carousel.item
  function currentList() { return animState === "apps" ? list : carouselView }

  readonly property int shownRows: Math.max(0, Math.min(cfg.maxShown, results.length,
                                    Math.floor((maxHeight - searchBox.height - padding * 3 + Tk.spacing.small) / (itemH + Tk.spacing.small))))
  readonly property real listH: results.length ? (itemH + Tk.spacing.small) * shownRows - Tk.spacing.small : emptyState.implicitHeight

  readonly property real contentW: animState === "apps" ? Tk.sizes.launcherItemWidth
    : Math.max(Tk.sizes.launcherItemWidth * 1.2, carouselView ? carouselView.implicitWidth : 0)
  readonly property real contentH: animState === "apps" ? listH : Tk.sizes.launcherWallpaperHeight

  implicitWidth: contentW + padding * 2
  implicitHeight: contentH + padding + padding + searchBox.height + Math.max(0, padding - Tk.border)
  Behavior on implicitWidth { enabled: root.active; Anim {} }
  Behavior on implicitHeight { enabled: root.active; Anim {} }

  Behavior on animState {
    SequentialAnimation {
      Anim { target: body; property: "opacity"; from: 1; to: 0; type: "effects" }
      PropertyAction {}
      Anim { target: body; property: "opacity"; from: 0; to: 1; type: "effects" }
    }
  }

  Item {
    id: body
    x: root.padding
    y: root.padding
    width: root.contentW
    height: root.contentH
    clip: true

    ListView {
      id: list
      visible: root.animState === "apps"
      width: Tk.sizes.launcherItemWidth
      height: root.listH
      clip: true
      model: root.results
      spacing: Tk.spacing.small
      currentIndex: 0
      boundsBehavior: Flickable.StopAtBounds
      highlightFollowsCurrentItem: false
      preferredHighlightBegin: 0
      preferredHighlightEnd: height
      highlightRangeMode: ListView.ApplyRange
      highlight: Rectangle {
        radius: Tk.rounding.large
        color: Colours.m3onSurface
        opacity: 0.08
        y: list.currentItem ? list.currentItem.y : 0
        width: list.width
        height: list.currentItem ? list.currentItem.height : 0
        Behavior on y { Anim {} }
      }

      delegate: Item {
        id: item
        required property var modelData
        required property int index
        readonly property var app: modelData.app || null
        readonly property var action: modelData.action || null
        width: list.width
        height: root.itemH

        Item {
          anchors.fill: parent
          property real radius: Tk.rounding.large
          StateLayer { onClicked: root.activate(item.modelData) }
        }
        Item {
          anchors.fill: parent
          anchors.leftMargin: Tk.padding.medium
          anchors.rightMargin: Tk.padding.medium
          anchors.topMargin: Tk.padding.small
          anchors.bottomMargin: Tk.padding.small

          IconImage {
            id: icon
            visible: item.app !== null
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: parent.height * 0.8
            asynchronous: true
            source: item.app ? Quickshell.iconPath(item.app.icon, "image-missing") : ""
          }
          MIcon {
            visible: item.action !== null
            anchors.centerIn: icon
            text: item.action ? item.action.icon : ""
            size: Tk.iconSize.large
            color: Colours.m3onSurfaceVariant
          }
          Column {
            anchors.left: icon.right
            anchors.leftMargin: Tk.spacing.medium
            anchors.right: parent.right
            anchors.verticalCenter: icon.verticalCenter
            MText {
              text: item.app ? item.app.name : item.action ? item.action.name : ""
              font.pointSize: Tk.body.medium
            }
            MText {
              width: parent.width
              text: item.app ? (item.app.comment || item.app.genericName || item.app.name) : item.action ? item.action.comment : ""
              color: Colours.m3outline
              elide: Text.ElideRight
            }
          }
        }
      }
    }

    Loader {
      id: carousel
      active: root.animState !== "apps"
      asynchronous: true
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      sourceComponent: WallpaperList {
        kind: root.animState
        search: root.query
        screenWidth: root.screenWidth
        onPicked: root.dismissed()
      }
    }

    Row {
      id: emptyState
      readonly property bool carouselMode: root.animState !== "apps"
      readonly property bool empty: carouselMode ? !!root.carouselView && root.carouselView.count === 0 : root.results.length === 0
      anchors.horizontalCenter: parent.horizontalCenter
      y: (parent.height - implicitHeight) / 2
      opacity: empty ? 1 : 0
      scale: empty ? 1 : 0.5
      padding: Tk.padding.large
      spacing: Tk.spacing.medium
      Behavior on opacity { Anim { type: "effects" } }
      Behavior on scale { Anim {} }
      MIcon { anchors.verticalCenter: parent.verticalCenter; text: emptyState.carouselMode ? "wallpaper_slideshow" : "manage_search"; size: Tk.iconSize.extraLarge; color: Colours.m3onSurfaceVariant }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        MText {
          text: root.animState === "wallpapers" ? "No wallpapers found" : root.animState === "themes" ? "No themes found" : "No results"
          color: Colours.m3onSurfaceVariant; font.pointSize: Tk.body.large; weight: Font.Medium
        }
        MText {
          text: root.animState === "wallpapers" && Wallpapers.walls.length === 0
            ? "Try putting some wallpapers in ~/.config/omarchy/backgrounds/" + Wallpapers.currentTheme
            : "Try searching for something else"
          color: Colours.m3onSurfaceVariant; font.pointSize: Tk.body.medium
        }
      }
    }
  }

  // Search bar
  Rectangle {
    id: searchBox
    x: root.padding
    width: parent.width - root.padding * 2
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Math.max(0, root.padding - Tk.border)
    readonly property int vpad: Math.round((Tk.padding.medium + Tk.padding.large) / 2)
    height: search.implicitHeight + vpad * 2
    radius: height / 2
    color: Colours.m3surfaceContainer

    MIcon {
      id: searchIcon
      anchors.left: parent.left
      anchors.leftMargin: Tk.padding.large
      anchors.verticalCenter: parent.verticalCenter
      text: "search"
      size: Tk.iconSize.medium * 0.9
      color: Colours.m3onSurfaceVariant
    }
    TextInput {
      id: search
      anchors.left: searchIcon.right
      anchors.leftMargin: Tk.spacing.medium
      anchors.right: clearBtn.left
      anchors.rightMargin: Tk.spacing.medium
      anchors.verticalCenter: parent.verticalCenter
      color: Colours.m3onSurface
      selectionColor: Colours.m3secondary
      selectedTextColor: Colours.m3onSecondary
      font.family: Tk.sans
      font.pointSize: Tk.body.medium
      font.variableAxes: ({ "ROND": 25, "wght": 400 })
      clip: true
      cursorDelegate: Rectangle {
        width: 2; radius: 1
        color: Colours.m3primary
        visible: search.activeFocus
        SequentialAnimation on opacity { loops: Animation.Infinite; running: search.activeFocus
          NumberAnimation { to: 0; duration: 500 } NumberAnimation { to: 1; duration: 500 } }
      }
      onTextChanged: list.currentIndex = 0
      Keys.onPressed: function(e) {
        if (e.key === Qt.Key_Escape) { root.dismissed(); e.accepted = true }
        else if (e.key === Qt.Key_Down || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier))
                 || (root.cfg.vimKeybinds && (e.modifiers & Qt.ControlModifier) && (e.key === Qt.Key_J || e.key === Qt.Key_N))) { const l = root.currentList(); if (l) l.incrementCurrentIndex(); e.accepted = true }
        else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab
                 || (root.cfg.vimKeybinds && (e.modifiers & Qt.ControlModifier) && (e.key === Qt.Key_K || e.key === Qt.Key_P))) { const l = root.currentList(); if (l) l.decrementCurrentIndex(); e.accepted = true }
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
          if (root.animState === "apps") root.activate(root.results[list.currentIndex])
          else if (root.carouselView && root.carouselView.currentItem) root.carouselView.activate(root.carouselView.currentItem.modelData)
          e.accepted = true
        }
      }
      MText {
        anchors.verticalCenter: parent.verticalCenter
        text: 'Type "' + root.prefix + '" for commands'
        color: Colours.m3onSurfaceVariant
        font.pointSize: Tk.body.medium
        opacity: search.text ? 0 : 1
        Behavior on opacity { Anim { type: "effects" } }
      }
    }
    IconButton {
      id: clearBtn
      anchors.right: parent.right
      anchors.rightMargin: Tk.padding.medium
      anchors.verticalCenter: parent.verticalCenter
      type: "text"
      icon: "clear"
      opacity: search.text ? 1 : 0
      enabled: search.text !== ""
      Behavior on opacity { Anim { type: "effects" } }
      onClicked: { search.text = ""; search.forceActiveFocus() }
    }
  }
}
