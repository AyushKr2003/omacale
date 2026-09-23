import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// Caelestia launcher: results list above a pill search bar, keyboard driven.
// Typing ">" lists Omarchy actions instead of apps; ">wallpaper " and
// ">theme " swap the list for the wallpaper carousel (Caelestia ContentList).
// Typing ":" walks the Omarchy menu itself, drawn as launcher rows and backed
// by Omarchy's own menu engine (MenuService).
Item {
  id: root

  property bool active: false
  property real maxHeight: 800
  signal dismissed()
  signal openSettings()
  readonly property var cfg: Config.o.launcher
  readonly property string prefix: cfg.actionPrefix || ">"
  readonly property string menuPrefix: cfg.menuPrefix || ":"

  readonly property int padding: Tk.padding.large
  readonly property int itemH: Tk.sizes.launcherItemHeight
  readonly property string wallPrefix: prefix + "wallpaper "
  readonly property string themePrefix: prefix + "theme "
  readonly property string mode: search.text.startsWith(wallPrefix) ? "wallpapers"
                               : search.text.startsWith(themePrefix) ? "themes"
                               : search.text.startsWith(menuPrefix) ? "menu" : "apps"
  readonly property bool actionMode: mode === "apps" && search.text.startsWith(prefix)
  readonly property bool menuMode: mode === "menu"
  // The two modes that draw into the results list, as opposed to the carousel.
  readonly property bool listMode: animState === "apps" || animState === "menu"
  // Sizes lag `mode` behind a fade, as Caelestia's animState.
  property string animState: mode
  property real screenWidth: 0
  readonly property string query: search.text.split(" ").slice(1).join(" ")
  readonly property string menuQuery: menuMode ? search.text.slice(menuPrefix.length) : ""
  property string pendingText: ""

  // Open straight into a carousel ("wallpaper" / "theme") or the Omarchy menu
  // ("menu"), e.g. from IPC.
  function openMode(kind) {
    const text = kind === "menu" ? menuPrefix : prefix + kind + " "
    if (active) { search.text = text; search.forceActiveFocus() }
    else pendingText = text
  }

  // ---------------------------------------------------------- Omarchy menu
  // Where in the menu tree ":" is looking, and how it got there. Omarchy's
  // Menu.qml keeps the same pair (activeMenu / navStack): the stack is what
  // makes going back retrace the route taken rather than the tree.
  property string menuPath: "root"
  property var menuStack: []

  function menuGo(id, push) {
    if (push && id !== menuPath) menuStack = menuStack.concat([menuPath])
    menuPath = id
    // Drop the query, keep the mode: the prefix alone is the menu's "root".
    search.text = menuPrefix
    list.currentIndex = 0
    settleCursor()
    MenuService.open(id)
  }

  function menuBack() {
    if (menuStack.length > 0) {
      const previous = menuStack[menuStack.length - 1]
      menuStack = menuStack.slice(0, menuStack.length - 1)
      menuGo(previous, false)
    } else if (menuPath !== "root") menuGo(MenuService.parentOf(menuPath), false)
  }

  function menuReset() { menuStack = []; menuPath = "root" }

  // Omarchy's settleCursor(): a disabled row can't take the cursor, so park it
  // on the first row that can (a submenu of software you already have opens
  // with the highlight on the first thing still worth picking).
  function settleCursor() {
    if (!menuMode) return
    for (let i = Math.max(0, list.currentIndex); i < results.length; i++) {
      if (!results[i].disabled) { list.currentIndex = i; return }
    }
  }

  onModeChanged: {
    if (mode === "menu") { menuReset(); MenuService.open("root") }
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
    { name: "Wallpaper", comment: "Change the wallpaper", icon: "wallpaper", autocomplete: "wallpaper", cmd: 'background=$(omarchy-theme-bg-switcher); [[ -n $background ]] && omarchy-theme-bg-set "$background"' },
    { name: "Random", comment: "Next background", icon: "wallpaper", cmd: "omarchy theme bg next" },
    { name: "Nightlight", comment: "Toggle night light", icon: "nightlight", cmd: "omarchy toggle nightlight" },
    { name: "Screenshot", comment: "Capture a region", icon: "screenshot_region", cmd: "omarchy capture screenshot" },
    { name: "Menu", comment: "Open the Omarchy menu", icon: "menu", cmd: "omarchy-menu" },
    { name: "Update", comment: "Update the system", icon: "system_update_alt", cmd: "omarchy launch floating-terminal-with-presentation omarchy update" }
  ]

  readonly property var results: {
    if (menuMode) return MenuService.rows(menuPath, menuQuery)
    const q = (actionMode ? search.text.slice(prefix.length) : search.text).trim().toLowerCase()
    if (actionMode) return actions.filter(a => (cfg.dangerousActions || !a.dangerous) && (!q || a.name.toLowerCase().indexOf(q) >= 0))
    const favs = Config.o.launcher.favouriteApps
    const fav = e => favs.indexOf(e.id) >= 0 ? 0 : 1
    const apps = AppService.launchable
    if (!q) return apps.slice().sort((a, b) => fav(a) - fav(b) || a.name.localeCompare(b.name))
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
    scored.sort((a, b) => a.s - b.s || fav(a.e) - fav(b.e) || a.e.name.localeCompare(b.e.name))
    return scored.map(x => x.e)
  }

  // Results are DesktopEntry objects, entries of `actions`, or menu rows.
  function isApp(r) { return !!r && typeof r.execute === "function" }
  function isMenuRow(r) { return !!r && r.itemId !== undefined }
  function activate(r) {
    if (!r) return
    if (isMenuRow(r)) { activateMenuRow(r); return }
    if (!isApp(r) && r.settings) { root.openSettings(); return }
    if (!isApp(r) && r.autocomplete) { search.text = prefix + r.autocomplete + " "; return }
    if (isApp(r)) r.execute(); else Sys.run(r.cmd)
    root.dismissed()
  }

  // Omarchy's Menu.qml activateIndex(): a submenu or link is walked into, an
  // app row is launched, anything else runs its action.
  function activateMenuRow(row) {
    if (row.disabled) return
    if (row.kind === "menu" || row.kind === "link") { menuGo(row.target || row.itemId, true); return }
    if (row.kind === "app") {
      const entry = DesktopEntries.byId(row.appId)
      if (entry) entry.execute()
    } else MenuService.run(row.action)
    root.dismissed()
  }

  // A disabled row (software already installed) stays listed but the cursor
  // steps over it, as it does in Omarchy's menu.
  function stepList(delta) {
    const l = currentList()
    if (!l) return
    const step = () => delta > 0 ? l.incrementCurrentIndex() : l.decrementCurrentIndex()
    step()
    if (!menuMode) return
    for (let i = 0; i < results.length; i++) {
      const row = results[l.currentIndex]
      if (!row || !row.disabled) return
      step()
    }
  }

  onActiveChanged: {
    // Wallpapers.reload(): a reopened carousel keeps its old list otherwise,
    // since it is not recreated when the search text is unchanged.
    if (active) { menuReset(); search.text = pendingText; pendingText = ""; list.currentIndex = 0; search.forceActiveFocus(); Wallpapers.reload() }
    else Wallpapers.stopPreview()
    disarmPointer()
  }

  // One cursor for mouse and keys, as Omarchy's launcher/clipboard: hovering a
  // row moves currentIndex there, and the keys carry on from it. Only real
  // pointer motion counts (Omarchy's Ui/PointerMoveGate), so rows sliding
  // under a still pointer on keyboard scroll or a new search don't steal it.
  property bool pointerPrimed: false
  property point pointerLast
  function disarmPointer() { pointerPrimed = false }
  function hoverRow(index, area, e) {
    const p = area.mapToItem(null, e.x, e.y)
    const moved = pointerPrimed && (Math.abs(p.x - pointerLast.x) > 1 || Math.abs(p.y - pointerLast.y) > 1)
    if (!pointerPrimed || moved) pointerLast = p
    pointerPrimed = true
    if (moved && !(results[index] && results[index].disabled)) list.currentIndex = index
  }

  readonly property var carouselView: carousel.item
  function currentList() { return listMode ? list : carouselView }

  readonly property int shownRows: Math.max(0, Math.min(cfg.maxShown, results.length,
                                    Math.floor((maxHeight - searchBox.height - padding * 3 + Tk.spacing.small) / (itemH + Tk.spacing.small))))
  readonly property real listH: results.length ? (itemH + Tk.spacing.small) * shownRows - Tk.spacing.small : emptyState.implicitHeight

  readonly property real contentW: listMode ? Tk.sizes.launcherItemWidth
    : Math.max(Tk.sizes.launcherItemWidth * 1.2, carouselView ? carouselView.implicitWidth : 0)
  readonly property real contentH: listMode ? listH : Tk.sizes.launcherWallpaperHeight

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

    // Caelestia launcher/AppList.qml, with the edge fade of Caelestia's
    // VerticalFadeListView (as Settings' pages have) while it can scroll.
    FadeListView {
      id: list
      visible: root.listMode
      width: Tk.sizes.launcherItemWidth
      height: root.listH
      clip: true
      model: ScriptModel {
        values: root.results
        onValuesChanged: { list.currentIndex = 0; root.settleCursor(); root.disarmPointer() }
      }
      spacing: Tk.spacing.small
      currentIndex: 0
      ScrollBar.vertical: MScrollBar { flickable: list }
      add: Transition { Anim { type: "effects"; property: "opacity"; from: 0; to: 1 } }
      remove: Transition { Anim { type: "effects"; property: "opacity"; from: 1; to: 0 } }
      move: Transition {
        Anim { property: "y" }
        Anim { type: "effects"; property: "opacity"; to: 1 }
      }
      addDisplaced: Transition {
        Anim { property: "y"; type: "standardSmall" }
        Anim { type: "effects"; property: "opacity"; to: 1 }
      }
      displaced: Transition {
        Anim { property: "y" }
        Anim { type: "effects"; property: "opacity"; to: 1 }
      }
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
        readonly property var app: root.isApp(modelData) ? modelData : null
        readonly property var menuRow: root.isMenuRow(modelData) ? modelData : null
        readonly property var action: app || menuRow ? null : modelData
        width: list.width
        height: root.itemH

        Item {
          anchors.fill: parent
          property real radius: Tk.rounding.large
          // The list highlight is the hover veil, so there is one highlight.
          StateLayer {
            id: rowLayer
            showHoverBackground: false
            onPositionChanged: e => root.hoverRow(item.index, rowLayer, e)
            onClicked: root.activate(item.modelData)
          }
        }
        Item {
          anchors.fill: parent
          anchors.leftMargin: Tk.padding.medium
          anchors.rightMargin: Tk.padding.medium
          anchors.topMargin: Tk.padding.small
          anchors.bottomMargin: Tk.padding.small
          // A row whose `disabled:` evaluated true (software already on the
          // machine) reads as listed-but-spent, as it does in Omarchy's menu.
          opacity: item.menuRow && item.menuRow.disabled ? 0.45 : 1

          readonly property string appIcon: item.app ? item.app.icon
            : item.menuRow && item.menuRow.kind === "app" ? item.menuRow.appIcon : ""

          IconImage {
            id: icon
            visible: parent.appIcon !== ""
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: parent.height * 0.8
            asynchronous: true
            source: parent.appIcon ? Quickshell.iconPath(parent.appIcon, "image-missing") : ""
          }
          MIcon {
            visible: item.action !== null
            anchors.centerIn: icon
            text: item.action ? item.action.icon : ""
            size: Tk.iconSize.large * 1.3
            color: Colours.m3onSurfaceVariant
          }
          // Menu glyphs are Nerd Font (or whatever `iconFont:` names, e.g.
          // Omarchy's own "omarchy" family), not Material Symbols.
          MText {
            visible: !!item.menuRow && item.menuRow.icon !== "" && !icon.visible
            anchors.centerIn: icon
            text: item.menuRow ? item.menuRow.icon : ""
            font.family: item.menuRow && item.menuRow.iconFont ? item.menuRow.iconFont : Tk.mono
            font.pointSize: Tk.body.large
            color: Colours.m3onSurfaceVariant
          }
          // A submenu says so, as Omarchy's menu does with its own chevron.
          MIcon {
            id: chevron
            visible: !!item.menuRow && (item.menuRow.kind === "menu" || item.menuRow.kind === "link")
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "chevron_right"
            size: Tk.iconSize.medium
            color: Colours.m3outline
          }
          // Caelestia items/AppItem.qml: a heart for favourites.
          MIcon {
            id: favIcon
            visible: !!item.app && Config.o.launcher.favouriteApps.indexOf(item.app.id) >= 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "favorite"
            fill: 1
            color: Colours.m3primary
          }
          Column {
            anchors.left: icon.right
            anchors.leftMargin: Tk.spacing.medium
            anchors.right: favIcon.visible ? favIcon.left : chevron.visible ? chevron.left : parent.right
            anchors.verticalCenter: icon.verticalCenter
            MText {
              text: item.app ? item.app.name : item.menuRow ? item.menuRow.label : item.action ? item.action.name : ""
              font.pointSize: Tk.body.medium
            }
            MText {
              width: parent.width
              text: item.app ? (item.app.comment || item.app.genericName || item.app.name)
                : item.menuRow ? item.menuRow.detail : item.action ? item.action.comment : ""
              color: Colours.m3outline
              elide: Text.ElideRight
              visible: text !== ""
            }
          }
        }
      }
    }

    Loader {
      id: carousel
      active: !root.listMode
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
      readonly property bool carouselMode: !root.listMode
      readonly property bool empty: carouselMode ? !!root.carouselView && root.carouselView.count === 0 : root.results.length === 0
      anchors.horizontalCenter: parent.horizontalCenter
      y: (parent.height - implicitHeight) / 2
      opacity: empty ? 1 : 0
      scale: empty ? 1 : 0.5
      padding: Tk.padding.large
      spacing: Tk.spacing.medium
      Behavior on opacity { Anim { type: "effects" } }
      Behavior on scale { Anim {} }
      MIcon { anchors.verticalCenter: parent.verticalCenter; text: emptyState.carouselMode ? "wallpaper_slideshow" : root.menuMode && !MenuService.available ? "error" : "manage_search"; size: Tk.iconSize.extraLarge; color: Colours.m3onSurfaceVariant }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        MText {
          text: root.animState === "wallpapers" ? "No wallpapers found" : root.animState === "themes" ? "No themes found"
            : root.menuMode && !MenuService.available ? "Omarchy menu unavailable"
            : root.menuMode && !MenuService.ready ? "Reading the Omarchy menu…" : "No results"
          color: Colours.m3onSurfaceVariant; font.pointSize: Tk.body.large; weight: Font.Medium
        }
        MText {
          text: root.animState === "wallpapers" && Wallpapers.walls.length === 0
            ? "Try putting some wallpapers in ~/.config/omarchy/backgrounds/" + Wallpapers.currentTheme
            : root.menuMode && !MenuService.available ? "Omarchy's menu engine was not found in " + MenuService.omarchyPath
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
    // Where ":" is in the menu tree. Omarchy's menu puts the submenu's title
    // in its header; the launcher has no header, so the route rides in the
    // search bar, in front of what is being typed. Clicking it steps back out.
    Rectangle {
      id: crumb
      readonly property bool shown: root.menuMode && root.menuPath !== "root"
      visible: shown
      anchors.left: searchIcon.right
      anchors.leftMargin: Tk.spacing.medium
      anchors.verticalCenter: parent.verticalCenter
      implicitWidth: crumbText.implicitWidth + Tk.padding.medium * 2
      implicitHeight: crumbText.implicitHeight + Tk.padding.extraSmall * 2
      radius: Tk.rounding.full
      color: Colours.m3secondaryContainer
      MText {
        id: crumbText
        anchors.centerIn: parent
        text: MenuService.pathLabel(root.menuPath)
        color: Colours.m3onSecondaryContainer
        font.pointSize: Tk.label.large
        weight: Font.Medium
      }
      StateLayer {
        radius: Tk.rounding.full
        color: Colours.m3onSecondaryContainer
        onClicked: root.menuBack()
      }
    }
    MTextField {
      id: search
      anchors.left: crumb.shown ? crumb.right : searchIcon.right
      anchors.leftMargin: Tk.spacing.medium
      anchors.right: clearBtn.left
      anchors.rightMargin: Tk.spacing.medium
      anchors.verticalCenter: parent.verticalCenter
      font.pointSize: Tk.body.medium
      clip: true
      onTextChanged: list.currentIndex = 0
      Keys.onPressed: function(e) {
        root.disarmPointer()
        if (e.key === Qt.Key_Escape) { root.dismissed(); e.accepted = true }
        else if (e.key === Qt.Key_Down || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier))
                 || (root.cfg.vimKeybinds && (e.modifiers & Qt.ControlModifier) && (e.key === Qt.Key_J || e.key === Qt.Key_N))) { root.stepList(1); e.accepted = true }
        else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab
                 || (root.cfg.vimKeybinds && (e.modifiers & Qt.ControlModifier) && (e.key === Qt.Key_K || e.key === Qt.Key_P))) { root.stepList(-1); e.accepted = true }
        // Omarchy's menu keys: Backspace and Left climb back out of a submenu
        // once the query is empty, Right walks into the row under the cursor.
        // At the top of the menu Backspace is left alone, so it eats the ":"
        // and drops back to the apps list.
        else if (root.menuMode && !root.menuQuery && root.menuPath !== "root"
                 && (e.key === Qt.Key_Backspace || e.key === Qt.Key_Left)) { root.menuBack(); e.accepted = true }
        else if (root.menuMode && e.key === Qt.Key_Right && search.cursorPosition === search.text.length) {
          root.activate(list.currentItem ? list.currentItem.modelData : null)
          e.accepted = true
        }
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
          if (root.listMode) root.activate(list.currentItem ? list.currentItem.modelData : null)
          else if (root.carouselView && root.carouselView.currentItem) root.carouselView.activate(root.carouselView.currentItem.modelData)
          e.accepted = true
        }
      }
      MText {
        anchors.verticalCenter: parent.verticalCenter
        text: 'Type "' + root.prefix + '" for commands, "' + root.menuPrefix + '" for the Omarchy menu'
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
