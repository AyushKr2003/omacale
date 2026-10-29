#!/usr/bin/env python3
"""Load the actual taskbar components in QtTest, without starting Quickshell.

Only host services are mocked. Components, tokens and controls are copied from
this checkout unchanged. This does not test compositor IPC, icon lookup,
JsonAdapter persistence, or the shell's pointer/focus integration.
"""
from pathlib import Path
import atexit
import json
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
STAGE = Path(tempfile.mkdtemp(prefix="omacale-taskbar-ui-"))
atexit.register(shutil.rmtree, STAGE)
RUNNER = shutil.which("qmltestrunner6") or "/usr/lib/qt6/bin/qmltestrunner"
if not Path(RUNNER).is_file():
    raise SystemExit("Qt 6 qmltestrunner is required for the taskbar UI tests")

FILES = """
core/Tk.qml core/Defaults.js core/TaskbarApps.js services/TaskbarApps.qml
modules/bar/AppsGroup.qml modules/bar/entries/AppsEntry.qml
modules/bar/BarContent.qml core/BarLayout.js components/KeyNav.qml
modules/settings/pages/TaskbarAppsPage.qml modules/settings/pages/TaskbarAppPicker.qml
modules/settings/pages/AppInfo.qml modules/settings/rows/RowToggle.qml
components/filedialog/FileDialog.qml components/filedialog/FileDialogButtons.qml
components/filedialog/FileDialogCurrent.qml components/filedialog/FileDialogHeader.qml
components/filedialog/FileDialogSidebar.qml components/filedialog/FolderContents.qml
components/StateLayer.qml components/FocusRing.qml components/MText.qml
components/MIcon.qml components/Anim.qml components/CAnim.qml
components/controls/IconButton.qml components/controls/IconTextButton.qml
components/controls/MSwitch.qml components/controls/OutlinedField.qml
components/controls/MTextField.qml components/SectionHeader.qml
components/shapes/ConnectedRect.qml components/containers/MFlickable.qml
components/containers/FadeFlickable.qml components/controls/MScrollBar.qml
modules/settings/common/RowButton.qml modules/settings/common/RowLabel.qml
""".split()


def write(name, content):
    dest = STAGE / name
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(content)


module = []
for name in FILES:
    dest = STAGE / name
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / name, dest)
    if dest.suffix == ".qml":
        singleton = "singleton " if dest.stem in ("Tk", "TaskbarApps") else ""
        module.append(f"{singleton}{dest.stem} 1.0 {name}")
for name in ("Config", "Colours", "Sys", "AppService", "IconFiles", "Morph"):
    module.append(f"singleton {name} 1.0 {name}.qml")
write("qmldir", "\n".join(module) + "\n")

# QObject properties have the same change notifications as Config's adapter;
# the real defaults are used so the fixture cannot drift as settings are added.
defaults = json.loads(subprocess.check_output([
    "node", "-e",
    "const fs=require('fs'),vm=require('vm'),ctx={};"
    "vm.runInNewContext(fs.readFileSync(process.argv[1],'utf8').replace(/^\\.pragma.*$/m,''),ctx);"
    "process.stdout.write(JSON.stringify(ctx.values))",
    str(ROOT / "core/Defaults.js"),
], text=True))


def object_source(values):
    props = []
    for key, value in values.items():
        if isinstance(value, dict):
            props.append(f"property QtObject {key}: {object_source(value)}")
        else:
            props.append(f"property var {key}: {json.dumps(value)}")
    return "QtObject {\n" + "\n".join(props) + "\n}"


write("Config.qml", """pragma Singleton
import QtQuick
QtObject {
  property QtObject o: """ + object_source(defaults) + """
  function get(key) { return key.split(".").reduce((v,k) => v[k],o) }
  function set(key,value) {
    const keys=key.split("."), last=keys.pop()
    let v=o
    for (const k of keys) v=v[k]
    v[last]=value
  }
}
""")
colors = [
    "m3onSurface", "m3onSurfaceVariant", "m3surfaceContainer", "m3surfaceContainerHigh",
    "m3primary", "m3secondary", "m3onPrimary", "m3onSecondary", "m3secondaryContainer",
    "m3onSecondaryContainer", "m3outline", "m3error", "m3surfaceContainerHighest", "m3surface",
]
write("Colours.qml", "pragma Singleton\nimport QtQuick\nQtObject {\n"
      'function layer(c,n) { return c }\n'
      'property QtObject palette: QtObject { property color m3surfaceContainerHighest: "#383942" }\n'
      + "\n".join(f'property color {color}: "#adb5e0"' for color in colors) + "\n}\n")
write("Sys.qml", """pragma Singleton
import QtQuick
QtObject {
  property var activeToplevel: null
  property var calls: []
  function focusWindow(a) { calls=calls.concat(["focus:"+a]) }
  function moveWindow(a,w) { calls=calls.concat(["move:"+a+":"+w]) }
}
""")
write("AppService.qml", """pragma Singleton
import QtQuick
import Quickshell
QtObject { readonly property var launchable: DesktopEntries.applications.values }
""")
write("IconFiles.qml", """pragma Singleton
import QtQuick
QtObject { function source(name,fallback) { return "" } }
""")
write("Morph.qml", """pragma Singleton
import QtQuick
QtObject {
  property real slideIn: 300
  property real slideOut: 180
  property var curveIn: [0,0,1,1,1,1]
  property var curveOut: curveIn
}
""")

write("imports/Quickshell/qmldir", "module Quickshell\nsingleton Quickshell 1.0 Quickshell.qml\nsingleton DesktopEntries 1.0 DesktopEntries.qml\n")
fixture_folder = STAGE / "Folder #? %"
(fixture_folder / "Empty").mkdir(parents=True)
(fixture_folder / "ignored.txt").touch()
(fixture_folder / "picture.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"/>')
write("imports/Quickshell/Quickshell.qml", """pragma Singleton
import QtQuick
QtObject {
  property var commands: []
  function iconPath(name, fallback) { return "" }
  function env(key) { return key === "OMACALE_TEST_FOLDER" ? """ + json.dumps(str(fixture_folder)) + """ : "/home/test" }
  function execDetached(args) { commands=commands.concat([args]) }
}
""")
# Keep the actual picker/listing/controls; only its Quickshell window and
# lazy-loading container are hosted inside QtTest's offscreen window.
with (STAGE / "imports/Quickshell/qmldir").open("a") as registry:
    registry.write("LazyLoader 1.0 LazyLoader.qml\nFloatingWindow 1.0 FloatingWindow.qml\nTestWindowFormat 1.0 TestWindowFormat.qml\n")
write("imports/Quickshell/TestWindowFormat.qml", "import QtQuick\nQtObject { property bool opaque: false }\n")
write("imports/Quickshell/LazyLoader.qml", """import QtQuick
Loader {
  id: loader
  default property alias content: loader.sourceComponent
  property bool activeAsync: false
  active: activeAsync
}
""")
write("imports/Quickshell/FloatingWindow.qml", """import QtQuick
Window {
  visible: true
  property real implicitWidth: 0
  property real implicitHeight: 0
  width: implicitWidth
  height: implicitHeight
  property size minimumSize: Qt.size(0,0)
  property size maximumSize: Qt.size(0,0)
  property TestWindowFormat surfaceFormat: TestWindowFormat {}
}
""")
write("imports/Quickshell/DesktopEntries.qml", """pragma Singleton
import QtQuick
QtObject {
  property QtObject applications: QtObject { property var values: [] }
  function heuristicLookup(id) { return applications.values.find(e => e.id === id || e.startupClass === id) || null }
}
""")
write("imports/Quickshell/Hyprland/qmldir", "module Quickshell.Hyprland\nsingleton Hyprland 1.0 Hyprland.qml\n")
write("imports/Quickshell/Hyprland/Hyprland.qml", """pragma Singleton
import QtQuick
QtObject {
  property QtObject toplevels: QtObject { property var values: [] }
  property var focusedWorkspace: ({ id: 1 })
}
""")
write("imports/Quickshell/Widgets/qmldir", "module Quickshell.Widgets\nIconImage 1.0 IconImage.qml\n")
write("imports/Quickshell/Widgets/IconImage.qml", """import QtQuick
Item {
  property real implicitSize: 24
  property string source: ""
  property bool asynchronous: true
  implicitWidth: implicitSize
  implicitHeight: implicitSize
}
""")
write("imports/qs/Commons/qmldir", "module qs.Commons\nsingleton Style 1.0 Style.qml\nsingleton Util 1.0 Util.qml\n")
write("imports/qs/Commons/Util.qml", """pragma Singleton
import QtQuick
import Quickshell
QtObject { function execArgv(argv) { Quickshell.execDetached(argv) } }
""")
write("imports/qs/Commons/Style.qml", """pragma Singleton
import QtQuick
QtObject { property real fontScale: 1; property real spacingScale: 1 }
""")
# Exercise the real BarContent and AppsEntry together. Other built-ins keep
# their entry contract but use small deterministic stand-ins; no system service
# or compositor is started by this test.
with (STAGE / "qmldir").open("a") as registry:
    registry.write("FakeBarEntry 1.0 FakeBarEntry.qml\nsingleton PluginService 1.0 PluginService.qml\n")
write("PluginService.qml", "pragma Singleton\nimport QtQuick\nQtObject { function statusOn(id) { return false } }\n")
write("FakeBarEntry.qml", """import QtQuick
import QtQuick.Layouts
import "."
Item {
  id: entry
  required property var bar
  property string entryId: ""
  property bool shown: true
  property bool joinable: false
  property real length: Tk.barInner
  property real bareSize: length
  property real iconsSize: 0
  property real calendarLen: 0
  property bool expanded: false
  property real fullLen: length
  property real collapsedLen: length
  property string pluginId: ""
  property var ids: []
  property QtObject pill: QtObject {
    property real minLen: 0; property real collapsedLen: 0
    property real width: 0; property real height: 0
    property real implicitWidth: 0; property real implicitHeight: 0
  }
  visible: shown
  Layout.alignment: bar.crossAlign
  implicitWidth: bar.vertical ? Tk.barInner : length
  implicitHeight: bar.vertical ? length : Tk.barInner
  Component.onCompleted: bar.registerEntry(entry)
  Component.onDestruction: bar.unregisterEntry(entry)
  function navStops() { return [] }
}
""")
entries = {
    "LogoEntry": 'entryId: "logo"; shown: bar.cfg.logo',
    "WorkspacesEntry": 'entryId: "workspaces"',
    "ActiveWindowEntry": 'entryId: "activeWindow"; shown: bar.cfg.activeWindow.enabled; length: 0; Layout.fillWidth: true; Layout.fillHeight: true',
    "TrayEntry": 'entryId: "tray"; shown: false',
    "PluginsEntry": 'entryId: "plugins"; shown: false',
    "ClockEntry": 'entryId: "clock"; shown: bar.cfg.clock.enabled',
    "StatusRun": 'entryId: "status:" + ids.join(","); shown: false',
    "PowerEntry": 'entryId: "power"; shown: bar.cfg.power',
    "SinglePluginEntry": 'entryId: "plugin:" + pluginId; shown: false',
    "OverflowEntry": 'entryId: "overflow"; shown: false',
}
for name, properties in entries.items():
    write(name + ".qml", 'import QtQuick.Layouts\nimport "."\nFakeBarEntry { ' + properties + ' }\n')
    with (STAGE / "qmldir").open("a") as registry:
        registry.write(name + " 1.0 " + name + ".qml\n")
for name in ("Io", "Bluetooth", "Services/UPower"):
    write("imports/Quickshell/" + name + "/qmldir", "module Quickshell." + name.replace("/", ".") + "\nStub 1.0 Stub.qml\n")
    write("imports/Quickshell/" + name + "/Stub.qml", "import QtQuick\nQtObject {}\n")
write("imports/Quickshell/SystemClock.qml", "import QtQuick\nQtObject { enum Precision { Seconds, Minutes } property int precision: 0 }\n")
with (STAGE / "imports/Quickshell/qmldir").open("a") as registry:
    registry.write("SystemClock 1.0 SystemClock.qml\n")
write("imports/Quickshell/Services/SystemTray/qmldir", "module Quickshell.Services.SystemTray\nsingleton SystemTray 1.0 SystemTray.qml\nsingleton Status 1.0 Status.qml\n")
write("imports/Quickshell/Services/SystemTray/SystemTray.qml", "pragma Singleton\nimport QtQuick\nQtObject { property QtObject items: QtObject { property var values: [] } }\n")
write("imports/Quickshell/Services/SystemTray/Status.qml", "pragma Singleton\nimport QtQuick\nQtObject { readonly property int passive: 0 }\n")
write("imports/Quickshell/Services/Pipewire/qmldir", "module Quickshell.Services.Pipewire\nsingleton Pipewire 1.0 Pipewire.qml\nPwObjectTracker 1.0 PwObjectTracker.qml\n")
write("imports/Quickshell/Services/Pipewire/Pipewire.qml", "pragma Singleton\nimport QtQuick\nQtObject { property var defaultAudioSink: null; property var defaultAudioSource: null }\n")
write("imports/Quickshell/Services/Pipewire/PwObjectTracker.qml", "import QtQuick\nQtObject { property var objects: [] }\n")
write("tests/tst_apps.qml", (ROOT / "tests/fixtures/taskbar/tst_apps.qml").read_text())
env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="",
           QT_QUICK_CONTROLS_STYLE="Basic", QT_FORCE_STDERR_LOGGING="1")
result = subprocess.run([RUNNER, "-import", str(STAGE / "imports"),
                         "-input", str(STAGE / "tests"), "-o", "-,txt"], env=env)
raise SystemExit(result.returncode)
