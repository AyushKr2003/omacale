pragma Singleton
import QtQuick
import Quickshell
import ".."

// The notification-popup handover (scripts/notif-popups): Omarchy's daemon,
// cloned and patched headless so Omacale draws the toasts. Unlike the lock it
// has no setting that installs it -- the installer asks -- so this only keeps
// an existing clone in step with Omarchy and hands the toasts back if an
// update breaks it.
Handover {
  id: root

  script: String(Qt.resolvedUrl("../scripts/notif-popups")).replace("file://", "")
  installArgs: ["install", "--no-restart"]
  configKey: "notifs"
  title: "Notification popups"
  stockPaths: [Quickshell.env("OMARCHY_PATH") + "/shell/plugins/notifications/Service.qml"]

  readonly property bool installed: clone !== "" && fields.patched === "yes"
  // Stock changed shape and the patch no longer applies; the old clone runs.
  readonly property bool refused: fields.patch === "refused"
  readonly property string refusedReason: fields.refused || ""
  // Stock differs from the Service.qml the patch was tested against.
  readonly property bool unverified: installed && fields.verified === "no"

  // Which daemon draws the toasts may have changed; ask again once the
  // plugin reload has had a moment.
  onChanged: reprobe.restart()
  property Timer reprobe: Timer {
    interval: 3000
    onTriggered: NotifService.probePopups()
  }
}
