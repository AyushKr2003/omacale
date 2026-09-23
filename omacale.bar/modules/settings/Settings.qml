import QtQuick
import QtQuick.Layouts
import "SettingsModel.js" as Model
import "../.."

// Omacale settings, modelled on Caelestia's Nexus: a navigation pane with
// search on the left, pages on the right inside a rounded inner frame that is
// drawn by the same blob shader as the shell (so the pop-out button melts
// into the frame). Used both as a floating drawer and as a real window.
Item {
  id: root

  property bool isWindow: false
  property bool active: true
  property real screenWidth: 1920
  property real screenHeight: 1080
  property string version: ""
  signal closeRequested()
  signal popOutRequested()

  // ------------------------------------------------------------- state
  property string pageId: "style"
  property var stack: []
  property var selectedApp: null   // Apps › All apps › <app>
  property string selectedPlugin: ""  // Plugins › <plugin id>
  property string search: ""
  readonly property string viewId: search.trim() !== "" ? "__search" : (stack.length ? stack[stack.length - 1] : pageId)
  readonly property var view: viewId === "__search"
    ? { id: "__search", label: "Search results", rows: Model.searchRows(search) }
    : Model.pageById(viewId)

  function go(id) { searchField.text = ""; stack = []; pageId = id }
  function push(id) { stack = stack.concat([id]) }
  function back() { if (stack.length) stack = stack.slice(0, -1) }
  function openPage(id) { go(id) }

  // Dropdown menu host (RowSelect asks for it).
  property Item menuOwner: null
  property Item menuAnchor: null
  property var menuOptions: []
  property string menuValue: ""
  property var menuPick: null
  function openMenu(owner, anchor, options, value, pick) {
    if (menuOwner === owner) { closeMenu(); return }
    menuOwner = owner; menuAnchor = anchor; menuOptions = options; menuValue = value; menuPick = pick
  }
  function closeMenu() { menuOwner = null }

  readonly property int navWidth: Math.min(600, Math.round(width / 3))
  readonly property int frameSide: Tk.padding.medium
  readonly property real holeX: navWidth + Tk.padding.large * 2
  implicitHeight: Math.round(screenHeight * 0.7)
  implicitWidth: Math.min(Math.round(implicitHeight * 16 / 9), screenWidth - Tk.barWidth - 80)

  focus: true
  Keys.onEscapePressed: {
    if (menuOwner) closeMenu()
    else if (searchField.text) searchField.text = ""
    else if (stack.length) back()
    else closeRequested()
  }
  onActiveChanged: if (active) forceActiveFocus()

  // -------------------------------------------------- inner blob frame
  Rectangle { id: outerMask; anchors.fill: parent; radius: root.isWindow ? 0 : Tk.rounding.extraLarge; visible: false; layer.enabled: true }
  Item {
    anchors.fill: parent
    layer.enabled: true
    layer.effect: ShaderMaskEffect { maskItem: outerMask }
    ShaderEffect {
      anchors.fill: parent
      fragmentShader: Qt.resolvedUrl("../../shaders/blob.frag.qsb")
      property size res: Qt.size(width, height)
      property real smoothing: Tk.rounding.medium
      property real holeRadius: Tk.rounding.large
      property real panelRadius: Tk.rounding.medium
      property rect hole: Qt.rect(root.holeX, root.frameSide, root.width - root.holeX - root.frameSide, root.height - root.frameSide * 2)
      property color color: Colours.m3surfaceContainerLow
      property rect r0: Qt.rect(winBtnRect.x, winBtnRect.y, winBtnRect.width, winBtnRect.height)
      property rect r1: Qt.rect(0, 0, 0, 0)
      property rect r2: Qt.rect(0, 0, 0, 0)
      property rect r3: Qt.rect(0, 0, 0, 0)
      property rect r4: Qt.rect(0, 0, 0, 0)
      property rect r5: Qt.rect(0, 0, 0, 0)
      // Edge each drawer grows out of (0 none, 1 top, 2 right, 3 bottom, 4 left).
      property vector4d attachA: Qt.vector4d(1, 0, 0, 0)
      property vector4d attachB: Qt.vector4d(0, 0, 0, 0)
    }
  }

  // Pop-out / close button, sitting in a tab of the frame.
  Item {
    id: winBtnRect
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: root.isWindow ? 0 : Tk.padding.extraSmall
    width: winBtn.implicitWidth + (root.isWindow ? Tk.padding.extraSmall : Tk.padding.small) * 2
    height: winBtn.implicitHeight + (root.isWindow ? Tk.padding.extraSmall : Tk.padding.small)
  }
  Item {
    id: winBtn
    anchors.centerIn: winBtnRect
    implicitWidth: winIcon.implicitWidth + Tk.padding.small * 2
    implicitHeight: winIcon.implicitHeight + Tk.padding.small
    MIcon {
      id: winIcon
      anchors.centerIn: parent
      text: root.isWindow ? "close" : "pip"
      size: Tk.iconSize.medium
      color: winMouse.containsMouse ? (root.isWindow ? Colours.m3error : Colours.m3primary) : Colours.m3onSurfaceVariant
      scale: winMouse.pressed ? 0.8 : 1
      Behavior on scale { Anim {} }
    }
    MouseArea {
      id: winMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.isWindow ? root.closeRequested() : root.popOutRequested()
    }
  }

  // ------------------------------------------------------ navigation
  ColumnLayout {
    id: nav
    x: Tk.padding.large
    y: Tk.padding.large
    width: root.navWidth
    height: root.height - Tk.padding.large * 2
    spacing: Tk.spacing.large

    // Search
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: searchField.implicitHeight + Tk.padding.large * 2
      radius: height / 2
      color: Colours.m3surfaceContainerLowest
      border.width: 1
      border.color: Colours.m3outlineVariant
      // Caelestia SearchBar: the field is one big hover/press target.
      StateLayer {
        cursorShape: Qt.IBeamCursor
        disabled: searchField.activeFocus
        onClicked: searchField.forceActiveFocus()
      }
      MIcon {
        id: sIcon
        anchors.left: parent.left
        anchors.leftMargin: Tk.padding.largeIncreased
        anchors.verticalCenter: parent.verticalCenter
        text: "search"
        size: Tk.iconSize.medium
        color: Colours.m3onSurfaceVariant
      }
      MTextField {
        id: searchField
        anchors.left: sIcon.right
        anchors.leftMargin: Tk.spacing.medium
        anchors.right: clearBtn.left
        anchors.rightMargin: Tk.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        font.pointSize: Tk.body.large
        clip: true
        onTextChanged: root.search = text
        Keys.onEscapePressed: text ? text = "" : root.closeRequested()
        MText {
          anchors.verticalCenter: parent.verticalCenter
          text: "Search settings"
          color: Colours.m3onSurfaceVariant
          font.pointSize: Tk.body.large
          opacity: searchField.text ? 0 : 1
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
        padding: Tk.padding.extraSmall
        opacity: searchField.text ? 1 : 0
        enabled: searchField.text !== ""
        Behavior on opacity { Anim { type: "effects" } }
        onClicked: searchField.text = ""
      }
    }

    // Pages (Caelestia navpane/NavLocations.qml)
    FadeFlickable {
      id: navFlick
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.topMargin: -topMargin
      Layout.bottomMargin: -bottomMargin
      topMargin: Tk.padding.large
      bottomMargin: Tk.padding.large
      contentHeight: navCol.implicitHeight
      ColumnLayout {
        id: navCol
        width: navFlick.width
        spacing: Tk.spacing.extraSmall
        Repeater {
          model: Model.pages
          Rectangle {
            id: item
            required property var modelData
            required property int index
            readonly property bool current: root.search.trim() === "" && root.pageId === modelData.id
            readonly property bool catStart: index === 0 || Model.pages[index - 1].category !== modelData.category
            readonly property bool catEnd: index === Model.pages.length - 1 || Model.pages[index + 1].category !== modelData.category
            readonly property real r: st.pressed ? Tk.rounding.medium : current ? Tk.rounding.extraLargeIncreased : 0
            Layout.fillWidth: true
            Layout.topMargin: index !== 0 && catStart ? Tk.spacing.medium : 0
            implicitHeight: { const h = il.implicitHeight + Tk.padding.large * 2; return h % 2 ? h + 1 : h }
            color: current ? Colours.m3secondaryContainer : Colours.m3surfaceContainerHigh
            topLeftRadius: r || (catStart ? Tk.rounding.extraLarge : Tk.rounding.extraSmall)
            topRightRadius: topLeftRadius
            bottomLeftRadius: r || (catEnd ? Tk.rounding.extraLarge : Tk.rounding.extraSmall)
            bottomRightRadius: bottomLeftRadius
            Behavior on topLeftRadius { Anim { type: "effects" } }
            Behavior on bottomLeftRadius { Anim { type: "effects" } }
            Behavior on color { CAnim {} }

            StateLayer { id: st; onClicked: root.go(item.modelData.id) }
            RowLayout {
              id: il
              anchors.fill: parent
              anchors.margins: Tk.padding.large
              spacing: Tk.spacing.medium
              Rectangle {
                Layout.fillHeight: true
                Layout.topMargin: -1
                Layout.bottomMargin: -1
                implicitWidth: height
                radius: height / 2
                color: item.current ? Colours.m3primary : Colours.m3secondaryContainer
                Behavior on color { CAnim {} }
                MIcon {
                  anchors.centerIn: parent
                  anchors.verticalCenterOffset: 1
                  text: item.modelData.icon
                  size: Tk.iconSize.medium
                  weight: Font.Medium
                  grade: 25
                  fill: 1
                  color: item.current ? Colours.m3onPrimary : Colours.m3onSecondaryContainer
                }
              }
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                MText { Layout.fillWidth: true; text: item.modelData.label; font.pointSize: Tk.body.medium; elide: Text.ElideRight }
                MText { Layout.fillWidth: true; text: item.modelData.description; color: Colours.m3onSurfaceVariant; font.pointSize: Tk.label.small; elide: Text.ElideRight }
              }
            }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------- pages
  Item {
    id: pagesArea
    // Caelestia Pages: navPane margin + padding.extraLarge past the nav pane.
    x: root.holeX + Tk.padding.extraLarge
    y: Tk.padding.extraLarge
    width: root.width - x - Tk.padding.extraLarge
    height: root.height - Tk.padding.extraLarge * 2

    property string shownId: ""
    property var shownView: null
    property bool shownSub: false
    property int depth: 0
    property int lastIdx: 0

    Item {
      id: container
      width: parent.width
      height: parent.height
      SettingsPage {
        anchors.fill: parent
        page: pagesArea.shownView
        isSub: pagesArea.shownSub
        settings: root
      }
    }

    function show() {
      shownView = root.view
      shownId = root.viewId
      shownSub = root.stack.length > 0 && root.viewId !== "__search"
    }
    Component.onCompleted: show()

    Connections {
      target: root
      function onViewIdChanged() {
        const newDepth = root.stack.length
        const horizontal = newDepth !== pagesArea.depth && root.viewId !== "__search"
        swap.dirX = horizontal ? (newDepth > pagesArea.depth ? 1 : -1) * Tk.padding.extraExtraLarge * 2 : 0
        // Caelestia Pages: a new page rises from below when it is further
        // down the nav list, and drops from above when it is further up.
        const idx = id => Model.pages.findIndex(p => p.id === id)
        swap.dirY = horizontal ? 0 : Tk.padding.extraLarge * (idx(root.pageId) >= pagesArea.lastIdx ? 1 : -1)
        pagesArea.lastIdx = idx(root.pageId)
        pagesArea.depth = newDepth
        root.closeMenu()
        swap.restart()
      }
      function onViewChanged() { if (root.viewId === "__search" && !swap.running) pagesArea.shownView = root.view }
    }
    SequentialAnimation {
      id: swap
      property real dirX
      property real dirY
      Anim { target: container; property: "opacity"; to: 0; type: "effects" }
      ScriptAction { script: pagesArea.show() }
      PropertyAction { target: container; property: "x"; value: swap.dirX }
      PropertyAction { target: container; property: "y"; value: swap.dirY }
      ParallelAnimation {
        Anim { target: container; property: "opacity"; to: 1; type: "slowEffects" }
        Anim { target: container; properties: "x,y"; to: 0; type: "slowEffects" }
      }
    }
  }

  // ------------------------------------------------------ dropdown menu
  // Caelestia components/controls/Menu.qml: right-aligned under the split
  // button's chevron, it grows from 10% height while fading in.
  MouseArea {
    anchors.fill: parent
    enabled: menu.open
    hoverEnabled: menu.open
    onClicked: root.closeMenu()
    onWheel: root.closeMenu()
  }
  Elevation {
    id: menu
    readonly property bool open: root.menuOwner !== null
    readonly property point anchorPos: root.menuAnchor ? root.menuAnchor.mapToItem(root, root.menuAnchor.width, root.menuAnchor.height) : Qt.point(0, 0)
    readonly property bool above: anchorPos.y + implicitHeight + Tk.spacing.small > root.height - Tk.padding.large
    x: Math.max(Tk.padding.large, anchorPos.x - width)
    y: above ? anchorPos.y - (root.menuAnchor ? root.menuAnchor.height : 0) - height - Tk.spacing.small : anchorPos.y + Tk.spacing.small
    implicitWidth: Math.max(200, menuCol.implicitWidth + menuCol.anchors.margins * 2)
    implicitHeight: menuCol.implicitHeight + menuCol.anchors.margins * 2
    width: implicitWidth
    height: implicitHeight
    radius: Tk.rounding.large
    level: 2
    opacity: open ? 1 : 0
    visible: opacity > 0
    layer.enabled: opacity < 1
    Behavior on opacity { Anim { type: "effects" } }
    transform: Scale {
      yScale: menu.open ? 1 : 0.1
      origin.y: menu.above ? menu.height : 0
      Behavior on yScale { Anim {} }
    }

    MouseArea { anchors.fill: parent; hoverEnabled: true; onWheel: e => e.accepted = true }
    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      color: Colours.m3surfaceContainerLow
      ColumnLayout {
        id: menuCol
        anchors.fill: parent
        anchors.margins: Tk.padding.extraSmall
        spacing: 0
        Repeater {
          id: menuRep
          model: root.menuOptions
          Rectangle {
            id: mi
            required property var modelData
            required property int index
            readonly property bool sel: modelData.value === root.menuValue
            Layout.fillWidth: true
            implicitWidth: miRow.implicitWidth + Tk.padding.medium * 2
            implicitHeight: miRow.implicitHeight + Tk.padding.medium * 2
            radius: sel ? Tk.rounding.medium : Tk.rounding.extraSmall
            topLeftRadius: index === 0 ? Tk.rounding.medium : radius
            topRightRadius: index === 0 ? Tk.rounding.medium : radius
            bottomLeftRadius: index === menuRep.count - 1 ? Tk.rounding.medium : radius
            bottomRightRadius: index === menuRep.count - 1 ? Tk.rounding.medium : radius
            color: Qt.alpha(Colours.m3tertiaryContainer, sel ? 1 : 0)
            Behavior on radius { Anim {} }
            StateLayer {
              color: mi.sel ? Colours.m3onTertiaryContainer : Colours.m3onSurface
              disabled: !menu.open
              onClicked: { if (root.menuPick) root.menuPick(mi.modelData.value); root.closeMenu() }
            }
            RowLayout {
              id: miRow
              anchors.fill: parent
              anchors.margins: Tk.padding.medium
              spacing: Tk.spacing.small
              MIcon { Layout.alignment: Qt.AlignVCenter; text: mi.modelData.icon || ""; color: mi.sel ? Colours.m3onTertiaryContainer : Colours.m3onSurfaceVariant }
              MText { Layout.alignment: Qt.AlignVCenter; Layout.fillWidth: true; text: mi.modelData.label; color: mi.sel ? Colours.m3onTertiaryContainer : Colours.m3onSurface }
            }
          }
        }
      }
    }
  }
}
