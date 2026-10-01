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
  stockPaths: [Quickshell.env("OMARCHY_PATH") + "/shell/plugins/osd/Osd.qml"]

  readonly property bool installed: clone !== "" && fields.patched === "yes"
  readonly property bool refused: fields.patch === "refused"
  readonly property string refusedReason: fields.refused || ""
  readonly property bool unverified: installed && fields.verified === "no"
}
