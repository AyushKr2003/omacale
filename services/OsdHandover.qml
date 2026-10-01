pragma Singleton
import QtQuick
import Quickshell
import ".."

// The OSD handover (scripts/osd-handover): Omarchy's OSD, cloned and patched
// so that it lets Omacale draw volume and brightness the way Caelestia does
// and keeps drawing everything else. Installed from Settings › Panels › OSD
// (or by the installer); this keeps the clone in step with Omarchy and gives
// the OSD back if an update breaks it.
Handover {
  id: root

  script: String(Qt.resolvedUrl("../scripts/osd-handover")).replace("file://", "")
  configKey: "osd"
  title: "Volume and brightness OSD"
  // Every stock file the clone is rebuilt from: a model or manifest change
  // makes it stale as much as the view does.
  stockPaths: [
    Quickshell.env("OMARCHY_PATH") + "/shell/plugins/osd/Osd.qml",
    Quickshell.env("OMARCHY_PATH") + "/shell/plugins/osd/OsdModel.js",
    Quickshell.env("OMARCHY_PATH") + "/shell/plugins/osd/manifest.json"
  ]

  readonly property bool installed: clone !== "" && fields.patched === "yes"
  readonly property bool refused: fields.patch === "refused"
  readonly property string refusedReason: fields.refused || ""
  readonly property bool unverified: installed && fields.verified === "no"
  // The shell compiled the clone before it was patched (an older Omacale
  // installed it, or it was your own clone) and runs Omarchy's stock OSD
  // under its name until it restarts; `running` is only probed while the
  // clone is enabled.
  readonly property bool needsRestart: installed && cloneEnabled
    && (fields.running === "stock" || lastAction === "restart-pending")
  // An older patch is running (the clone was re-synced to this Omacale's
  // while the shell ran): the sliders work, the rest takes a restart.
  readonly property bool outdated: installed && cloneEnabled && fields.running === "outdated"
  // The volume and brightness keys reach Omacale: the patched OSD is the one
  // running, so Omarchy's draws none of them.
  readonly property bool active: installed && cloneEnabled && !needsRestart

  // Detached and a moment late, so the restart outlives the shell it stops
  // (as scripts/lock-screen's --heal does).
  function restartShell() {
    Quickshell.execDetached(["bash", "-c", "sleep 1; exec omarchy-restart-shell"])
  }
}
