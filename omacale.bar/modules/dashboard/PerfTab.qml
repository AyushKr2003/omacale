import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import "../.."

// Caelestia dashboard "Performance" tab: CPU and GPU hero cards, then
// storage, network and memory cards, with a battery "tank" on the right.
Item {
  id: root
  property bool active: false
  readonly property var cfg: Config.o.dashboard.performance
  readonly property bool laptop: UPower.displayDevice && UPower.displayDevice.isLaptopBattery
  readonly property bool gpuShown: cfg.showGpu && Sys.gpuType !== "none"
  readonly property bool anyShown: cfg.showCpu || gpuShown || cfg.showMemory || cfg.showStorage || cfg.showNetwork || (laptop && cfg.showBattery)

  // Caelestia Strings.percentOne: one decimal, dropped when whole ("100%").
  function pct(v) { return isNaN(v) ? "..." : (Math.round(v * 1000) / 10) + "%" }

  implicitWidth: anyShown ? content.implicitWidth : Tk.px(700)
  implicitHeight: anyShown ? content.implicitHeight : placeholder.implicitHeight + Tk.padding.extraLarge * 2

  // ----------------------------------------------------- placeholder
  ColumnLayout {
    id: placeholder
    anchors.centerIn: parent
    visible: !root.anyShown
    spacing: Tk.spacing.medium
    MIcon { Layout.alignment: Qt.AlignHCenter; text: "tune"; size: Tk.iconSize.extraLarge * 2; color: Colours.m3onSurfaceVariant }
    MText { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: -Tk.spacing.small; text: "No widgets enabled"; font.pointSize: Tk.title.large; weight: Font.Medium }
    MText { Layout.alignment: Qt.AlignHCenter; text: "Enable widgets in the dashboard settings"; color: Colours.m3onSurfaceVariant }
  }

  RowLayout {
    id: content
    visible: root.anyShown
    spacing: Tk.spacing.medium

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Tk.spacing.medium

      RowLayout {
        spacing: Tk.spacing.medium
        visible: root.cfg.showCpu || root.gpuShown
        HeroCard {
          visible: root.cfg.showCpu
          Layout.fillWidth: true
          icon: "memory"; label: "CPU"
          subLabel: Sys.cpuName
          usage: Sys.cpu; temperature: Sys.cpuTemp
          accent: Colours.m3primary
        }
        HeroCard {
          visible: root.gpuShown
          Layout.fillWidth: true
          icon: "desktop_windows"; label: "GPU"
          subLabel: Sys.gpuName + (Sys.gpuSleeping ? " · sleeping" : "")
          usage: Sys.gpu; temperature: Sys.gpuTemp
          accent: Colours.m3secondary
        }
      }

      RowLayout {
        spacing: Tk.spacing.medium
        visible: root.cfg.showStorage || root.cfg.showNetwork || root.cfg.showMemory
        StorageCard { visible: root.cfg.showStorage; Layout.fillWidth: true; Layout.fillHeight: true }
        NetworkCard { visible: root.cfg.showNetwork; Layout.fillWidth: true; Layout.fillHeight: true }
        MemoryCard { visible: root.cfg.showMemory; Layout.fillWidth: true; Layout.fillHeight: true }
      }
    }

    BatteryTank {
      visible: root.laptop && root.cfg.showBattery
      Layout.fillHeight: true
    }
  }

  // ======================================================== components
  component HeroCard: Rectangle {
    id: hero
    property string icon
    property string label
    property string subLabel
    property color accent
    property real usage
    property real temperature
    color: Colours.m3surfaceContainer
    radius: Tk.rounding.extraLarge
    implicitWidth: Tk.px(400)
    implicitHeight: Math.max(tempProg.height + detailsCol.implicitHeight + Tk.spacing.large, usageShape.height + usageLabel.implicitHeight) + Tk.padding.large * 2

    CircularProgress {
      id: tempProg
      anchors.left: parent.left; anchors.top: parent.top
      anchors.margins: Tk.padding.large
      fgColour: hero.accent
      spacing: Tk.spacing.extraSmall
      strokeWidth: Tk.padding.extraSmall
      implicitSize: heroIcon.implicitHeight + Tk.padding.medium * 2
      width: implicitSize; height: implicitSize
      value: hero.usage
      MIcon { id: heroIcon; anchors.centerIn: parent; text: hero.icon; color: hero.accent; size: Tk.iconSize.medium }
    }
    ColumnLayout {
      anchors.left: tempProg.right; anchors.right: usageShape.left
      anchors.verticalCenter: tempProg.verticalCenter
      anchors.leftMargin: Tk.spacing.large; anchors.rightMargin: Tk.spacing.large
      spacing: Tk.spacing.extraSmall
      MText { text: hero.label; font.pointSize: Tk.title.medium; weight: Font.Medium; color: hero.accent }
      MText { Layout.fillWidth: true; text: hero.subLabel; color: Colours.m3onSurfaceVariant; elide: Text.ElideRight }
    }
    ColumnLayout {
      id: detailsCol
      anchors.left: parent.left; anchors.bottom: parent.bottom
      anchors.margins: Tk.padding.largeIncreased
      spacing: Tk.spacing.extraSmall
      RowLayout {
        Layout.leftMargin: -Tk.padding.extraSmall
        spacing: Tk.spacing.extraSmall
        MIcon {
          text: hero.temperature > 90 ? "thermometer_alert" : "thermometer"
          color: hero.temperature > 90 ? Colours.m3error : hero.accent
          size: Tk.iconSize.medium
          fill: 1
        }
        MText { text: Math.round(hero.temperature) + "°C"; font.pointSize: Tk.body.medium }
      }
      MProgress { implicitWidth: Tk.px(200); implicitHeight: Tk.padding.small; value: hero.temperature / 100; fgColour: hero.accent }
    }
    MShape {
      id: usageShape
      anchors.right: parent.right; anchors.bottom: parent.bottom
      anchors.margins: Tk.padding.medium
      implicitSize: Tk.px(100)
      width: Tk.px(100); height: Tk.px(100)
      color: Colours.m3secondaryContainer
      shape: hero.usage >= 0.8 ? "softBurst" : hero.usage >= 0.4 ? "sunny" : "cookie4"
      MText { id: usageLabel; anchors.bottom: parent.top; anchors.horizontalCenter: parent.horizontalCenter; text: "Usage"; color: Colours.m3onSurfaceVariant }
      MText { anchors.centerIn: parent; text: root.pct(hero.usage); color: hero.accent; font.pointSize: Tk.headline.small; axes: ({ "ROND": 25, "wdth": 50 }) }
    }
  }

  component StorageCard: Rectangle {
    id: storage
    readonly property color accent: Colours.m3secondary
    readonly property var disk: Sys.primaryDisk
    readonly property real perc: disk && disk.total ? disk.used / disk.total : 0
    color: Colours.m3surfaceContainer
    radius: Tk.rounding.extraExtraLarge
    implicitWidth: sl.implicitWidth + Tk.padding.extraLarge * 2
    implicitHeight: sl.implicitHeight + Tk.padding.large * 2
    ColumnLayout {
      id: sl
      anchors.left: parent.left; anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: Tk.padding.extraLarge
      spacing: 0
      RowLayout {
        id: srow
        Layout.alignment: Qt.AlignHCenter
        spacing: Tk.spacing.large
        CircularProgress {
          fgColour: storage.accent
          value: storage.perc
          startAngle: -225; sweepAngle: 270
          implicitSize: sCol.implicitHeight + thickness + Tk.padding.large * 2
          width: implicitSize; height: implicitSize
          ColumnLayout {
            id: sCol
            anchors.centerIn: parent
            spacing: 0
            MIcon { Layout.alignment: Qt.AlignHCenter; text: "hard_drive"; color: storage.accent; size: Tk.iconSize.medium }
            MText { Layout.alignment: Qt.AlignHCenter; text: root.pct(storage.perc); font.pointSize: Tk.title.large; weight: Font.Medium; axes: ({ "ROND": 25, "wdth": 90 }); color: storage.accent }
            MText { Layout.alignment: Qt.AlignHCenter; text: "Used"; color: Colours.m3onSurfaceVariant }
          }
        }
        ColumnLayout {
          Layout.minimumWidth: Tk.px(160)
          spacing: Tk.spacing.extraSmall
          MText { text: "Storage"; font.pointSize: Tk.title.medium; weight: Font.Medium }
          MText { text: storage.disk ? Sys.fmtBytes(storage.disk.used) + " / " + Sys.fmtBytes(storage.disk.total) : "No disks detected"; font.pointSize: Tk.body.large; color: storage.accent }
        }
      }
      SplitSelect {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Tk.spacing.small
        menuOnTop: true
        minLeftWidth: srow.implicitWidth * 0.6
        fallbackIcon: "storage"
        fallbackText: "No disks"
        items: Sys.disks.map(d => ({ icon: "storage", text: d.mount, value: d.mount }))
        current: Sys.primaryDisk ? Sys.primaryDisk.mount : ""
        onSelected: v => { Sys.primaryMount = v; Sys.diskProbe.running = true }
      }
    }
  }

  component NetworkCard: Rectangle {
    color: Colours.m3surfaceContainer
    radius: Tk.rounding.extraLarge
    implicitWidth: Tk.px(390)
    implicitHeight: Tk.px(220)
    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Tk.padding.large
      anchors.bottomMargin: Tk.padding.medium
      spacing: 0
      RowLayout {
        spacing: Tk.spacing.small
        MIcon { text: "swap_vert"; color: Colours.m3primary; size: Tk.iconSize.medium }
        MText { text: "Network"; font.pointSize: Tk.title.medium; weight: Font.Medium }
      }
      Item {
        Layout.topMargin: Tk.spacing.medium
        Layout.bottomMargin: Tk.spacing.small
        Layout.fillWidth: true
        Layout.fillHeight: true
        Sparkline {
          anchors.fill: parent
          line1: Sys.upHistory
          line2: Sys.downHistory
          historyLength: Sys.netHistory
        }
        MText { anchors.centerIn: parent; text: "Collecting data..."; color: Colours.m3outline; visible: Sys.downHistory.length < 2 }
      }
      NetRow { icon: "download"; label: "Download"; value: Sys.fmtBytes(Sys.downSpeed, true); colour: Colours.m3tertiary }
      NetRow { icon: "upload"; label: "Upload"; value: Sys.fmtBytes(Sys.upSpeed, true); colour: Colours.m3secondary }
      RowLayout {
        Layout.fillWidth: true
        spacing: Tk.spacing.small
        MIcon { text: "history"; color: Colours.m3onSurfaceVariant; size: Tk.iconSize.medium }
        MText { text: "Total"; color: Colours.m3onSurfaceVariant }
        Item { Layout.fillWidth: true }
        MText { text: "↓" + Sys.fmtBytes(Sys.downTotal) + " ↑" + Sys.fmtBytes(Sys.upTotal); color: Colours.m3onSurfaceVariant }
      }
    }
  }

  component NetRow: RowLayout {
    property string icon
    property string label
    property string value
    property color colour
    Layout.fillWidth: true
    spacing: Tk.spacing.small
    MIcon { text: parent.icon; color: parent.colour; size: Tk.iconSize.medium }
    MText { text: parent.label; color: Colours.m3onSurfaceVariant }
    Item { Layout.fillWidth: true }
    MText { text: parent.value; color: parent.colour; font.pointSize: Tk.body.medium; weight: Font.Medium }
  }

  component MemoryCard: Rectangle {
    readonly property color accent: Colours.m3tertiary
    color: Colours.m3surfaceContainer
    radius: Tk.rounding.medium
    implicitWidth: ml.implicitWidth + Tk.padding.extraLargeIncreased * 2
    implicitHeight: ml.implicitHeight + Tk.padding.large * 2
    ColumnLayout {
      id: ml
      anchors.centerIn: parent
      spacing: Tk.spacing.extraSmall
      RowLayout {
        Layout.leftMargin: -Tk.padding.extraSmall
        spacing: Tk.spacing.small
        MIcon { text: "memory_alt"; fill: 1; weight: Font.DemiBold; color: Colours.m3tertiary; size: Tk.iconSize.medium }
        MText { text: "Memory"; font.pointSize: Tk.title.medium; weight: Font.Medium }
      }
      CircularProgress {
        Layout.topMargin: Tk.spacing.large
        Layout.alignment: Qt.AlignHCenter
        implicitSize: mCol.implicitHeight + thickness + Tk.padding.largeIncreased * 2
        width: implicitSize; height: implicitSize
        startAngle: -225; sweepAngle: 270
        fgColour: Colours.m3tertiary
        value: Sys.mem
        ColumnLayout {
          id: mCol
          anchors.centerIn: parent
          anchors.verticalCenterOffset: Tk.padding.extraSmall
          spacing: 0
          MText { Layout.alignment: Qt.AlignHCenter; text: root.pct(Sys.mem); font.pointSize: Tk.title.large; weight: Font.Medium; axes: ({ "ROND": 25, "wdth": 90 }); color: Colours.m3tertiary }
          MText { Layout.alignment: Qt.AlignHCenter; text: "Used"; color: Colours.m3onSurfaceVariant }
        }
      }
      MText { Layout.alignment: Qt.AlignHCenter; text: Sys.memUsedGb.toFixed(1) + " / " + Sys.memTotalGb.toFixed(1) + " GiB"; font.pointSize: Tk.body.medium }
    }
  }

  component BatteryTank: Rectangle {
    id: tank
    readonly property var dev: UPower.displayDevice
    property real animPerc: dev ? dev.percentage : 0
    Behavior on animPerc { Anim {} }
    color: Colours.m3secondaryContainer
    radius: Tk.rounding.large
    implicitWidth: root.cfg.showCpu || root.gpuShown || root.cfg.showStorage || root.cfg.showMemory ? Tk.px(150) : Tk.px(400)
    implicitHeight: Tk.px(160)
    clip: true
    layer.enabled: true
    layer.effect: ShaderMaskEffect { maskItem: tankMask }
    Rectangle { id: tankMask; anchors.fill: parent; radius: parent.radius; visible: false; layer.enabled: true }

    TankContents {
      id: tankLayout
      anchors.fill: parent
      anchors.margins: Tk.padding.medium
      accentColour: Colours.m3primary
      textColour: Colours.m3onSurface
      subTextColour: Colours.m3onSurfaceVariant
    }
    Rectangle {
      anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
      height: parent.height * tank.animPerc
      color: Colours.m3secondary
      radius: Tk.rounding.extraSmall
      clip: true
      TankContents {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: Tk.padding.medium
        height: tankLayout.height
        accentColour: Colours.m3primaryContainer
        textColour: Colours.m3onSecondary
        subTextColour: Colours.m3secondaryContainer
      }
    }
  }

  component TankContents: ColumnLayout {
    id: tc
    property color accentColour
    property color textColour
    property color subTextColour
    readonly property var dev: UPower.displayDevice
    readonly property bool charging: dev && [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].indexOf(dev.state) >= 0
    spacing: 0
    MIcon { Layout.leftMargin: -Tk.padding.extraSmall; text: "battery_full"; color: tc.accentColour; size: Tk.iconSize.large }
    MText { Layout.fillWidth: true; text: "Battery"; color: tc.textColour; font.pointSize: Tk.body.medium }
    Item { Layout.fillHeight: true }
    MText {
      Layout.alignment: Qt.AlignRight
      animate: true
      color: tc.subTextColour
      text: {
        if (!tc.dev) return ""
        if (tc.dev.state === UPowerDeviceState.FullyCharged) return "Full"
        if (tc.charging) return "Charging"
        const s = tc.dev.timeToEmpty
        if (!s) return "..."
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60)
        return h > 0 ? h + "h " + m + "m" : m + "m"
      }
    }
    RowLayout {
      Layout.topMargin: -Tk.padding.extraSmall
      Layout.bottomMargin: -Tk.padding.small
      Layout.rightMargin: -Tk.padding.extraSmall
      Layout.alignment: Qt.AlignRight
      spacing: Tk.spacing.extraSmall
      MIcon {
        text: "bolt"; fill: 1
        color: tc.accentColour
        size: Tk.iconSize.large
        scale: tc.charging ? 1 : 0
        opacity: tc.charging ? 1 : 0
        Behavior on scale { Anim { type: "fastSpatial" } }
        Behavior on opacity { Anim { type: "fastEffects" } }
      }
      MText { text: root.pct(tc.dev ? tc.dev.percentage : 0); color: tc.accentColour; font.pointSize: Tk.headline.medium }
    }
  }
}
