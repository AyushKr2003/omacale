import QtQuick
import QtTest
import Quickshell
import Quickshell.Hyprland
import ".."
TestCase {
  id: test
  name: "TaskbarAppsUI"
  width: 1000
  height: 900
  when: windowShown
  property var launched: []
  QtObject {
    id: fakeHost
    property var shell: ({ appLibrary: { launch: (id,name) => { test.launched=test.launched.concat([id]) } } })
    function toggle(name,page) {}
  }
  QtObject {
    id: fakeScope
    property bool barFocus: false
    property string appGroup: ""
    property real popoutCenter: 0
    property string popout: ""
    function openPopoutKeys(name) { popout=name }
  }
  QtObject {
    id: fakeBar
    property var cfg: Config.o.bar
    property var scope: fakeScope
    property var host: fakeHost
    property bool vertical: true
    property string edge: "left"
    property real appsExtra: 200
    property int crossAlign: Qt.AlignHCenter
    function registerEntry(e) {}
    function unregisterEntry(e) {}
    function centreOf(e) { return 100 }
    function apos(e) { return vertical ? e.y : e.x }
    function alen(e) { return vertical ? e.height : e.width }
    function scrollList(f,a,dy) { return false }
  }
  Component { id: entryFactory; AppsEntry { bar: fakeBar; width: implicitWidth; height: implicitHeight } }
  Component { id: settingsFactory; TaskbarAppsPage { width: 700; height: implicitHeight; settings: navigator } }
  Component { id: appInfoFactory; AppInfo { width: 700; height: implicitHeight; settings: navigator } }
  Component { id: pickerFactory; TaskbarAppPicker { width: 700; height: implicitHeight; settings: navigator } }
  Component { id: groupFactory; AppsGroup { groupId: "group:work"; host: fakeHost; width: 320; height: implicitHeight } }
  QtObject { id: navigator; property var selectedApp: null; property string taskbarGroup: ""; function push(page) {} }
  function initTestCase() { failOnWarning(/.*/) }
  function init() {
    fakeBar.vertical = true
    fakeBar.edge = "left"
    fakeBar.appsExtra = 200
    fakeScope.popout = ""
    Config.set("bar.apps.enabled", true)
    Config.set("bar.apps.items", [{type:"app",app:"editor"}, {id:"group:work",type:"group",name:"Work",apps:["browser"]}])
    DesktopEntries.applications.values=[{id:"editor",name:"Editor",icon:"",command:[]},{id:"browser",name:"Browser",icon:"",command:[]}]
    Hyprland.toplevels.values=[]
    Sys.activeToplevel=null
    Sys.calls=[]
    test.launched=[]
  }
  function test_entry_loads_and_turns() {
    const item=createTemporaryObject(entryFactory,test)
    verify(item)
    wait(20)
    compare(item.navStops().length,3)
    for (const edge of ["left","right","top","bottom"]) {
      fakeBar.edge=edge; fakeBar.vertical=edge==="left"||edge==="right";wait(10)
      verify(item.width>0);verify(item.height>0)
    }
    Config.set("bar.apps.enabled",false)
    compare(item.shown,false)
    compare(TaskbarApps.windows.length,0)
  }
  function test_slots_survive_window_changes_and_scroll() {
    const item = createTemporaryObject(entryFactory, test)
    verify(item)
    wait(10)
    const editorSlot = item.navStops()[0].item
    Hyprland.toplevels.values = [{address:"0xa",workspace:{id:1,name:"1"},wayland:{appId:"editor",parent:null}}]
    wait(10)
    compare(item.navStops()[0].item, editorSlot)
    fakeBar.appsExtra = 0
    wait(10)
    tryVerify(() => item.height <= item.minLen + 1, 1000)
    const stops = item.navStops()
    item.cursorMoved(stops[stops.length - 1])
    item.openItem(TaskbarApps.items[1], stops[1].item, false)
    compare(fakeScope.popout, "appgroup")
    compare(fakeScope.appGroup, "group:work")
    item.openItem(TaskbarApps.items[1], stops[1].item, false)
    compare(fakeScope.popout, "")
    item.openItem(TaskbarApps.items[1], stops[1].item, false)
    fakeScope.barFocus = true
    item.openItem(TaskbarApps.items[0], stops[0].item, false)
    compare(fakeScope.popout, "")
    compare(fakeScope.barFocus, false)
  }
  function test_groups_close_when_removed() {
    const item = createTemporaryObject(groupFactory, test)
    verify(item)
    const spy = Qt.createQmlObject('import QtTest; SignalSpy {}', test)
    spy.target = item
    spy.signalName = "closeRequested"
    Config.set("bar.apps.items", [])
    compare(spy.count, 1)
    spy.destroy()
  }
  function test_tui_and_special_windows() {
    DesktopEntries.applications.values = DesktopEntries.applications.values.concat([
      {id:"neovim",name:"Neovim",command:["nvim"],runInTerminal:true},
      {id:"wrapper",name:"Wrapper",command:["terminal","--app-id=custom"]}])
    compare(TaskbarApps.claimingEntry("org.omarchy.nvim"), "neovim")
    compare(TaskbarApps.claimingEntry("custom"), "wrapper")
    Hyprland.toplevels.values = [
      {address:"0xa",workspace:{id:-1,name:"special:scratch"},wayland:{appId:"editor",parent:null}},
      {address:"0xb",workspace:{id:1,name:"1"},wayland:{appId:"editor",parent:{}}},
      {address:"0xc",workspace:{id:-2,name:"special:minimized"},wayland:{appId:"editor",parent:null}}]
    compare(TaskbarApps.windows.length, 1)
    TaskbarApps.activate({type:"app",app:"editor"}, fakeHost, false)
    compare(Sys.calls[0], "move:0xc:1")
    compare(Sys.calls[1], "focus:0xc")
  }
  function test_directory_is_one_encoded_argument() {
    Quickshell.commands = []
    TaskbarApps.activate({type:"folder",path:"/tmp/a b/#?$(echo no)"}, fakeHost, false)
    compare(Quickshell.commands.length, 1)
    compare(Quickshell.commands[0][0], "xdg-open")
    compare(Quickshell.commands[0].length, 2)
    compare(Quickshell.commands[0][1], "file:///tmp/a%20b/%23%3F%24(echo%20no)")
  }
  function test_member_activation_emits_dismissal() {
    const item = createTemporaryObject(groupFactory, test)
    verify(item)
    const activated = Qt.createQmlObject('import QtTest; SignalSpy {}', test)
    activated.target = item
    activated.signalName = "appActivated"
    const closed = Qt.createQmlObject('import QtTest; SignalSpy {}', test)
    closed.target = item
    closed.signalName = "closeRequested"
    wait(20)
    const targets = []
    function walk(node) {
      if (node.navTarget === true) targets.push(node)
      for (const child of node.children) walk(child)
    }
    walk(item)
    verify(targets.length >= 2)
    targets[targets.length - 1].navActivate()
    compare(activated.count, 1)
    compare(closed.count, 1)
    compare(test.launched[0], "browser")
    activated.destroy()
    closed.destroy()
  }
  function test_pages_load() {
    navigator.selectedApp = DesktopEntries.applications.values[0]
    verify(createTemporaryObject(appInfoFactory,test))
    verify(createTemporaryObject(settingsFactory,test))
    verify(createTemporaryObject(pickerFactory,test))
    verify(createTemporaryObject(groupFactory,test))
  }
  function test_launch_and_cycle() {
    TaskbarApps.activate({type:"app",app:"editor"},fakeHost,false)
    compare(launched.length,1)
    const first={address:"0xa",workspace:{id:1,name:"1"},wayland:{appId:"editor",parent:null}}
    const second={address:"0xb",workspace:{id:2,name:"2"},wayland:{appId:"editor",parent:null}}
    Hyprland.toplevels.values=[first,second]
    Sys.activeToplevel=first
    TaskbarApps.activate({type:"app",app:"editor"},fakeHost,false)
    compare(Sys.calls[0],"focus:0xb")
    TaskbarApps.activate({type:"app",app:"editor"},fakeHost,true)
    compare(launched.length,2)
  }
}
