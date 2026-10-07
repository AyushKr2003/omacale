import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import "../../.."

// The active window (Caelestia bar/components/ActiveWindow.qml). The entry is
// the free space of its section; the icon and title are centred in it.
Item {
  id: entry
  required property var bar
  Component.onCompleted: bar.registerEntry(entry)
  Component.onDestruction: bar.unregisterEntry(entry)
  property string entryId: "activeWindow"
  // Switched off, it takes no room at all, and the center section is centred.
  readonly property bool shown: bar.cfg.activeWindow.enabled
  property alias win: activeWin
  Layout.fillWidth: true
  Layout.fillHeight: true
  clip: true

  Item {
    id: activeWin
    visible: bar.cfg.activeWindow.enabled
    readonly property var tl: Sys.activeToplevel
    readonly property string title: {
      const t = tl && tl.title ? tl.title : "Desktop"
      if (!bar.cfg.activeWindow.compact) return t
      const parts = t.split(/\s+[\-\u2013\u2014]\s+/)
      return parts.length > 1 ? parts[parts.length - 1].trim() : t
    }
    // The room the title has beside the icon, along the bar. Caelestia's
    // elideWidth comes out three medium gaps short of the space between
    // its neighbours (the spacers' gaps), and elides that much earlier.
    readonly property real maxLen: (bar.vertical ? parent.height - winIcon.height : parent.width - winIcon.width)
      - 3 * Tk.spacing.medium

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    // A column turns the title a quarter and stacks it under the icon; a
    // row leaves it upright beside the icon.
    width: bar.vertical ? Math.max(winIcon.implicitWidth, metrics.height)
      : winIcon.implicitWidth + Tk.spacing.small + Math.min(metrics.width, maxLen)
    height: bar.vertical ? winIcon.implicitHeight + Tk.spacing.small + Math.min(metrics.width, maxLen)
      : Math.max(winIcon.implicitHeight, metrics.height)
    Behavior on height { enabled: bar.vertical; Anim {} }
    Behavior on width { enabled: !bar.vertical; Anim {} }

    MIcon {
      id: winIcon
      // Centred across the bar (by x/y: see Workspaces `list`).
      x: bar.vertical ? Math.round((parent.width - width) / 2) : 0
      y: bar.vertical ? 0 : Math.round((parent.height - height) / 2)
      animate: true
      text: Sys.appIcon(activeWin.tl && activeWin.tl.wayland ? activeWin.tl.wayland.appId : "", "desktop_windows")
      color: Colours.m3primary
    }
    // Caelestia ActiveWindow: two titles cross-fade when the text changes.
    property Item current: title1
    // A step above Caelestia's body.small, which read small beside the
    // status icons. Measured and drawn at the same size.
    readonly property int titleSize: Tk.font(13)
    TextMetrics {
      id: metrics
      text: activeWin.title
      font.family: Tk.sans
      font.pointSize: activeWin.titleSize
      font.letterSpacing: 1.4
      elide: Qt.ElideRight
      elideWidth: Math.max(0, activeWin.maxLen)
      // Cross-fade only when the title itself changes; a change in the
      // room it has re-elides in place (Caelestia onElideWidthChanged).
      onTextChanged: {
        if (!title1 || !title2) return
        const next = activeWin.current === title1 ? title2 : title1
        next.text = elidedText
        activeWin.current = next
      }
      onElideWidthChanged: if (activeWin.current) activeWin.current.text = elidedText
    }
    component Title: MText {
      id: t
      // Under the icon on a column, beside it on a row.
      x: bar.vertical ? winIcon.x + Math.round((winIcon.width - width) / 2) : winIcon.x + winIcon.width + Tk.spacing.small
      y: bar.vertical ? winIcon.y + winIcon.height + Tk.spacing.small : winIcon.y + Math.round((winIcon.height - height) / 2)
      width: bar.vertical ? implicitHeight : implicitWidth
      height: bar.vertical ? implicitWidth : implicitHeight
      font.pointSize: activeWin.titleSize
      font.letterSpacing: 1.4
      color: Colours.m3primary
      opacity: activeWin.current === t ? 1 : 0
      Behavior on opacity { Anim { type: "effects" } }
      transform: Rotation { angle: bar.vertical ? 90 : 0; origin.x: t.implicitHeight / 2; origin.y: t.implicitHeight / 2 }
    }
    Title { id: title1; Component.onCompleted: text = metrics.elidedText }
    Title { id: title2 }
  }

  function navStops() {
    return activeWin.visible && Sys.activeToplevel ? [{ item: activeWin, act: () => bar.scope.openPopoutKeys("activewindow") }] : []
  }
  function popoutAt(a) {
    const w = bar.pointAlong(bar.pointOn(activeWin, a))
    if (bar.cfg.popouts.activeWindow && activeWin.visible && w >= 0 && w <= bar.alen(activeWin) && Sys.activeToplevel)
      return { name: "activewindow", center: bar.centreOf(activeWin) }
    return null
  }
  function popoutCenterFor(name) {
    return name === "activewindow" && activeWin.visible ? bar.centreOf(activeWin) : undefined
  }
}
