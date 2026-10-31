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
  visible: true
  when: windowShown
  property var launched: []
  property var toggled: []
  property bool clearMenuOnClose: false
  QtObject {
    id: fakeHost
    property var widgetIds: []
    property var thirdPartyPlugins: []
    function entryId(e) { return e.id }
    property var shell: ({ appLibrary: { launch: (id,name) => { test.launched=test.launched.concat([id]) } } })
    function toggle(name,page) { test.toggled=test.toggled.concat([name+":"+page]) }
  }
  QtObject {
    id: fakeScope
    property bool barFocus: false
    property string appGroup: ""
    property var appMenuItem: null
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
  Component { id: fullBarFactory; BarContent { host: fakeHost; scope: fakeScope; screen: ({name:"test"}); width: vertical ? Tk.barWidth : 600; height: vertical ? 600 : Tk.barWidth } }
  Component { id: entryFactory; AppsEntry { bar: fakeBar; width: implicitWidth; height: implicitHeight } }
  Component { id: settingsFactory; TaskbarAppsPage { width: 700; height: implicitHeight; settings: navigator } }
  Component { id: appInfoFactory; AppInfo { width: 700; height: implicitHeight; settings: navigator } }
  Component { id: pickerFactory; TaskbarAppPicker { width: 700; height: implicitHeight; settings: navigator } }
  Component { id: folderPickerFactory; FileDialog { selectFolder: true; cwd: Quickshell.env("OMACALE_TEST_FOLDER").split("/") } }
  Component { id: groupFactory; AppsGroup { groupId: "group:work"; host: fakeHost; width: 320; height: implicitHeight } }
  Component { id: menuFactory; AppsMenu { host: fakeHost; width: implicitWidth; height: implicitHeight; onCloseRequested: if(test.clearMenuOnClose) appItem=null } }
  QtObject {
    id: navigator
    property var selectedApp: null
    property string taskbarGroup: ""
    property var folderPick: null
    function push(page) {}
    function folderRequested(title, pick) { folderPick = pick }
  }
  function initTestCase() { failOnWarning(/.*/) }
  function init() {
    failOnWarning(/.*/)
    fakeBar.vertical = true
    fakeBar.edge = "left"
    fakeBar.appsExtra = 200
    fakeScope.popout = ""
    Config.set("bar.apps.maxShown", 8)
    Config.set("bar.apps.useAvailableSpace", true)
    Config.set("bar.apps.showSettings", false)
    Config.set("bar.apps.enabled", true)
    Config.set("bar.apps.items", [{type:"app",app:"editor"}, {id:"group:work",type:"group",name:"Work",apps:["browser"]}])
    DesktopEntries.applications.values=[{id:"editor",name:"Editor",icon:"",command:[]},{id:"browser",name:"Browser",icon:"",command:[]}]
    Hyprland.toplevels.values=[]
    Sys.activeToplevel=null
    Sys.calls=[]
    test.launched=[]
    test.toggled=[]
    test.clearMenuOnClose=false
    TaskbarApps.quitRun.running=false
    Toaster.messages=[]
    navigator.folderPick = null
    fakeHost.shell = ({ appLibrary: { launch: (id,name) => { test.launched=test.launched.concat([id]) } } })
  }
  function test_full_bar_budget_and_default_off() {
    const item = createTemporaryObject(fullBarFactory, test)
    verify(item)
    tryVerify(() => !!item.entryFor("apps"))
    for (const edge of ["left", "right", "top", "bottom"]) {
      item.edge = edge
      item.vertical = edge === "left" || edge === "right"
      wait(50)
      verify(isFinite(item.budget))
      verify(isFinite(item.appsExtra))
      const apps = item.entryFor("apps")
      verify(apps.sizeLen <= apps.fullLen)
      verify(apps.sizeLen >= apps.minLen)
      verify(item.centreOf(apps) >= 0)
      verify(item.centreOf(apps) <= 600)
    }
    Config.set("bar.apps.enabled", false)
    tryVerify(() => !item.entryFor("apps"))
    compare(item.appsExtra, 0)
    compare(item.budget, item.flexibleBudget)
  }
  function test_folded_apps_release_the_shared_budget() {
    Config.set("bar.layout.start", ["logo", "workspaces"])
    Config.set("bar.layout.drawer", ["apps"])
    const item = createTemporaryObject(fullBarFactory, test)
    verify(item)
    tryVerify(() => !!item.entryFor("apps"))
    compare(item.entries().indexOf(item.entryFor("apps")), -1)
    compare(item.appsExtra, 0)
    compare(item.budget, item.flexibleBudget)
    item.drawerOpen = true
    tryVerify(() => item.entries().indexOf(item.entryFor("apps")) >= 0)
    verify(item.appsExtra > 0)
    item.drawerOpen = false
    tryCompare(item, "appsExtra", 0)
    Config.set("bar.layout.drawer", [])
    Config.set("bar.layout.start", ["logo", "workspaces", "apps"])
  }
  function test_full_bar_caps_many_apps_and_scrolls_with_keys() {
    Config.set("bar.apps.showSettings", true)
    const entries = []
    const pins = []
    for (let i = 0; i < 20; i++) {
      const id = "app" + i
      entries.push({id:id,name:"App " + i,icon:"",command:[]})
      pins.push({type:"app",app:id})
    }
    DesktopEntries.applications.values = entries
    Config.set("bar.apps.items", pins)
    Config.set("bar.apps.maxShown", 24)
    const item = createTemporaryObject(fullBarFactory, test)
    verify(item)
    tryVerify(() => !!item.entryFor("apps"))
    const apps = item.entryFor("apps")
    tryVerify(() => apps.fullLen > apps.sizeLen)
    wait(500)
    const stops = apps.navStops()
    compare(stops.length, 21)
    apps.cursorMoved(stops[20])
    wait(20)
    const button = stops[20].item
    const position = button.mapToItem(apps, 0, 0)
    verify(position.y >= 0)
    verify(position.y + button.height <= apps.height + 0.5, JSON.stringify({y:position.y,button:button.height,height:apps.height,target:apps.sizeLen}))
  }
  function test_bar_cursor_tracks_scrolled_app_cells() {
    Config.set("bar.apps.showSettings", true)
    const entries = [], pins = []
    for (let i = 0; i < 20; i++) {
      entries.push({id:"app"+i,name:"App "+i,icon:"",command:[]})
      pins.push({type:"app",app:"app"+i})
    }
    DesktopEntries.applications.values = entries
    Config.set("bar.apps.items",pins)
    Config.set("bar.apps.maxShown",24)
    const item = createTemporaryObject(fullBarFactory,test)
    verify(item)
    tryVerify(() => !!item.entryFor("apps"))
    item.keyMode = true
    wait(400)
    const apps = item.entryFor("apps"), stops = apps.navStops(), last = stops.length-1
    const cursor = findChild(item,"barCursor")
    verify(cursor)
    item.cursorStop = stops[last]
    const previous = cursor.r.y // Materialize the rect before the content moves.
    apps.cursorMoved(stops[last])
    wait(100)
    const position = stops[last].item.mapToItem(item,0,0)
    verify(previous !== position.y)
    fuzzyCompare(cursor.r.y,position.y,0.5)
    fuzzyCompare(cursor.r.x,position.x,0.5)
  }
  function test_entry_loads_and_turns() {
    const item=createTemporaryObject(entryFactory,test)
    verify(item)
    wait(20)
    compare(item.navStops().length,2)
    for (const edge of ["left","right","top","bottom"]) {
      fakeBar.edge=edge; fakeBar.vertical=edge==="left"||edge==="right";wait(10)
      verify(item.width>0);verify(item.height>0)
    }
    Config.set("bar.apps.enabled",false)
    compare(item.shown,false)
    compare(TaskbarApps.windows.length,0)
  }
  function test_settings_button_optional_and_empty_bar_has_no_gap() {
    const item=createTemporaryObject(entryFactory,test)
    wait(20)
    compare(item.navStops().length,2)
    const shortLength=item.naturalLen
    Config.set("bar.apps.showSettings",true)
    compare(item.navStops().length,3)
    verify(item.naturalLen>shortLength)
    Config.set("bar.apps.showSettings",false)
    Config.set("bar.apps.items",[])
    tryCompare(item,"empty",true)
    compare(item.shown,false)
    compare(item.fullLen,0)
  }
  function test_available_space_and_manual_slot_limit() {
    const entries=[],pins=[]
    for(let i=0;i<40;i++) { entries.push({id:"app"+i,name:"App "+i,icon:"",command:[]});pins.push({type:"app",app:"app"+i}) }
    DesktopEntries.applications.values=entries
    Config.set("bar.apps.items",pins)
    const item=createTemporaryObject(entryFactory,test)
    wait(20)
    compare(item.fullLen,item.naturalLen)
    verify(item.sizeLen<=item.minLen+fakeBar.appsExtra)
    Config.set("bar.apps.useAvailableSpace",false)
    verify(item.fullLen<item.naturalLen)
    const capped=item.fullLen
    Config.set("bar.apps.maxShown",40)
    verify(item.fullLen>capped)
  }
  function test_available_space_keeps_other_widget_pill_room() {
    const entries=[],pins=[]
    for(let i=0;i<40;i++) { entries.push({id:"app"+i,name:"App "+i,icon:"",command:[]});pins.push({type:"app",app:"app"+i}) }
    DesktopEntries.applications.values=entries
    Config.set("bar.apps.items",pins)
    const item=createTemporaryObject(fullBarFactory,test)
    tryVerify(()=>!!item.entryFor("plugins"))
    const plugins=item.entryFor("plugins")
    plugins.pill.minLen=40
    plugins.pill.collapsedLen=160
    plugins.shown=true
    tryVerify(()=>item.appsExtra>0)
    verify(item.budget>=160)
    verify(item.appsExtra<=item.flexibleBudget-160)
  }
  function test_running_section_divider_and_emphasis() {
    Config.set("bar.apps.items",[{type:"app",app:"editor"}])
    const win={address:"a",workspace:{id:1,name:"1"},wayland:{appId:"browser",parent:null}}
    Hyprland.toplevels.values=[win]
    const item=createTemporaryObject(entryFactory,test)
    wait(20)
    mouseMove(test,900,800)
    compare(item.pinnedCount,1)
    compare(item.divided,true)
    const stops=item.navStops()
    compare(stops[0].item.saved,true)
    compare(stops[1].item.saved,false)
    compare(stops[1].item.iconOpacity,0.65)
    Sys.activeToplevel=win
    compare(stops[1].item.iconOpacity,1)
    TaskbarApps.pin("browser",true)
    compare(item.divided,false)
    TaskbarApps.pin("editor",false)
    TaskbarApps.pin("browser",false)
    compare(item.pinnedCount,0)
    compare(item.divided,false)
  }
  function test_right_click_and_keyboard_open_app_menu() {
    const item=createTemporaryObject(entryFactory,test)
    tryVerify(()=>Math.abs(item.height-item.sizeLen)<0.5)
    const slot=item.navStops()[0].item
    mouseClick(slot,slot.width/2,slot.height/2,Qt.RightButton)
    compare(fakeScope.popout,"appmenu")
    compare(fakeScope.appMenuItem.app,"editor")
    compare(test.toggled.length,0)
    fakeScope.popout=""
    item.navStops()[0].menu()
    compare(fakeScope.popout,"appmenu")
  }
  function test_menu_pin_unpin_close_all_and_quit() {
    let closed=0
    const wins=["a","b"].map(a=>({address:a,lastIpcObject:{pid:12345},workspace:{id:1,name:"1"},wayland:{appId:"editor",parent:null,close:()=>closed++}}))
    Hyprland.toplevels.values=wins
    const menu=createTemporaryObject(menuFactory,test,{appItem:TaskbarApps.items[0]})
    verify(menu.actions.some(a=>a.id==="quit"))
    menu.invoke("pin")
    verify(!TaskbarApps.isPinned("editor"))
    menu.invoke("pin")
    verify(TaskbarApps.isPinned("editor"))
    menu.invoke("close")
    compare(closed,2)
    menu.invoke("quit")
    verify(TaskbarApps.quitting)
    const command=TaskbarApps.quitRun.command
    compare(command[0],"/usr/bin/python3")
    const selection=JSON.parse(command[command.length-1])
    compare(selection.windows.length,2)
    compare(selection.windows[0].address,"0xa")
    compare(selection.terminate,true)
    TaskbarApps.quitRun.running=false
    TaskbarApps.quitRun.finished({state:"ok",stdout:JSON.stringify({state:"windows-open"})})
    compare(Toaster.messages.length,1)
  }
  function test_quit_webapp_preserves_browser_process() {
    DesktopEntries.applications.values=[{id:"YouTube",name:"YouTube",startupClass:"chrome-youtube.com__-Default",icon:"",command:[]}]
    Hyprland.toplevels.values=[{address:"a",lastIpcObject:{pid:12345},workspace:{id:1,name:"1"},wayland:{appId:"brave-youtube.com__-Default",parent:null}}]
    TaskbarApps.quit({type:"app",app:"YouTube"})
    const command=TaskbarApps.quitRun.command
    compare(JSON.parse(command[command.length-1]).terminate,false)
  }
  function test_quit_native_terminal_wrapper_is_not_a_webapp() {
    DesktopEntries.applications.values=[{id:"native",name:"Native",icon:"",command:["foot","--app-id=native","settings"]}]
    Hyprland.toplevels.values=[{address:"a",lastIpcObject:{pid:12345},workspace:{id:1,name:"1"},wayland:{appId:"native",parent:null}}]
    TaskbarApps.quit({type:"app",app:"native"})
    const command=TaskbarApps.quitRun.command
    compare(JSON.parse(command[command.length-1]).terminate,true)
  }
  function test_pin_click_survives_menu_close_state_cleanup() {
    test.clearMenuOnClose=true
    const menu=createTemporaryObject(menuFactory,test,{appItem:({id:"app:browser",type:"app",app:"browser"})})
    wait(20)
    const pin=findChild(menu,"taskbarAction_pin")
    verify(pin)
    mouseClick(pin,pin.width/2,pin.height/2)
    verify(TaskbarApps.isPinned("browser"))
    compare(menu.appItem,null)
  }
  function test_drag_inside_running_section_does_not_pin() {
    Config.set("bar.apps.items",[{type:"app",app:"editor"}])
    DesktopEntries.applications.values=DesktopEntries.applications.values.concat([{id:"music",name:"Music",icon:"",command:[]}])
    Hyprland.toplevels.values=["browser","music"].map((app,index)=>({address:String(index+1),workspace:{id:1,name:"1"},wayland:{appId:app,parent:null}}))
    const item=createTemporaryObject(entryFactory,test)
    tryVerify(()=>Math.abs(item.height-item.sizeLen)<0.5)
    const running=item.navStops()[1].item,last=item.navStops()[2].item
    item.beginPress(running.appItem,running.mapToItem(item,0,0))
    item.moveDrag(last.mapToItem(item,last.width/2,last.height/2))
    item.finishDrag()
    compare(TaskbarApps.pins.length,1)
    compare(TaskbarApps.pins[0].app,"editor")
  }
  function check_pointer_reorder(vertical) {
    fakeBar.vertical=vertical
    Config.set("bar.apps.items",[{type:"app",app:"editor"},{type:"app",app:"browser"}])
    const item=createTemporaryObject(entryFactory,test)
    tryVerify(()=>Math.abs((vertical?item.height:item.width)-item.sizeLen)<0.5)
    const first=item.navStops()[0].item,last=item.navStops()[1].item
    const target=last.mapToItem(first,last.width-2,last.height-2)
    mousePress(first,first.width/2,first.height/2)
    mouseMove(first,target.x,target.y,30)
    verify(item.dragging)
    mouseRelease(first,target.x,target.y)
    compare(TaskbarApps.pins[0].app,"browser")
    compare(TaskbarApps.pins[1].app,"editor")
    compare(test.launched.length,0)
    wait(20)
    const stops=item.navStops(),p0=stops[0].item.mapToItem(item,0,0),p1=stops[1].item.mapToItem(item,0,0)
    verify(vertical?p0.y<p1.y:p0.x<p1.x)
  }
  function test_pointer_reorder_vertical() { check_pointer_reorder(true) }
  function test_pointer_reorder_horizontal() { check_pointer_reorder(false) }
  function test_drag_running_app_to_pin_section_and_cancel_outside() {
    Config.set("bar.apps.items",[{type:"app",app:"editor"}])
    Hyprland.toplevels.values=[{address:"a",workspace:{id:1,name:"1"},wayland:{appId:"browser",parent:null}}]
    const item=createTemporaryObject(entryFactory,test)
    wait(50)
    const running=item.navStops()[1].item
    item.beginPress(running.appItem,running.mapToItem(item,0,0))
    item.moveDrag(Qt.point(item.width/2,item.pad+1))
    item.finishDrag()
    compare(TaskbarApps.pins[0].app,"browser")
    const before=JSON.stringify(TaskbarApps.pins)
    item.beginPress(TaskbarApps.items[0],Qt.point(0,0))
    item.moveDrag(Qt.point(-50,-50))
    item.finishDrag()
    compare(JSON.stringify(TaskbarApps.pins),before)
  }
  function test_slots_survive_window_changes_and_scroll() {
    const item = createTemporaryObject(entryFactory, test)
    verify(item)
    wait(10)
    const editorSlot = item.navStops()[0].item
    Hyprland.toplevels.values = [{address:"a",workspace:{id:1,name:"1"},wayland:{appId:"editor",parent:null}}]
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
      {address:"a",workspace:{id:-1,name:"special:scratch"},wayland:{appId:"editor",parent:null}},
      {address:"b",workspace:{id:1,name:"1"},wayland:{appId:"editor",parent:{}}},
      {address:"c",workspace:{id:-2,name:"special:minimized"},wayland:{appId:"editor",parent:null}}]
    compare(TaskbarApps.windows.length, 1)
    TaskbarApps.activate({type:"app",app:"editor"}, fakeHost, false)
    compare(Sys.calls[0], "move:0xc:1")
    compare(Sys.calls[1], "focus:0xc")
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
  function test_folder_button_pins_only_after_selection() {
    const page = createTemporaryObject(settingsFactory, test)
    const before = JSON.stringify(TaskbarApps.pins)
    findChild(page, "taskbarAddFolder").clicked()
    verify(typeof navigator.folderPick === "function")
    compare(JSON.stringify(TaskbarApps.pins), before)
    navigator.folderPick("/home/test/Folder #?")
    const folder = TaskbarApps.pins[TaskbarApps.pins.length - 1]
    compare(folder.type, "folder")
    compare(folder.name, "Folder #?")
    compare(folder.path, "/home/test/Folder #?")
  }
  function test_folder_picker_navigation_empty_selection_and_cancel() {
    const picker = createTemporaryObject(folderPickerFactory, test)
    const accepted = Qt.createQmlObject('import QtTest; SignalSpy { signalName: "accepted" }', test)
    const rejected = Qt.createQmlObject('import QtTest; SignalSpy { signalName: "rejected" }', test)
    accepted.target = picker
    rejected.target = picker
    picker.open()
    tryVerify(() => !!picker.item)
    let contents = findChild(picker.item, "fileDialogContents")
    tryCompare(contents, "count", 1) // Files are excluded from folder mode.
    tryVerify(() => picker.item.selectionValid)
    compare(picker.item.selectedPath, Quickshell.env("OMACALE_TEST_FOLDER"))
    contents.currentIndex = 0
    tryVerify(() => !!contents.currentItem)
    compare(picker.item.selectedPath, Quickshell.env("OMACALE_TEST_FOLDER") + "/Empty")
    contents.forceActiveFocus()
    keyClick(Qt.Key_Return)
    tryCompare(contents, "count", 0)
    tryVerify(() => picker.item.selectionValid)
    compare(picker.item.selectedPath, Quickshell.env("OMACALE_TEST_FOLDER") + "/Empty")
    const select = findChild(picker.item, "fileDialogSelect")
    mouseClick(select, select.width / 2, select.height / 2)
    compare(accepted.count, 1)
    compare(accepted.signalArguments[0][0], Quickshell.env("OMACALE_TEST_FOLDER") + "/Empty")
    picker.open()
    tryVerify(() => !!picker.item)
    const cancel = findChild(picker.item, "fileDialogCancel")
    mouseClick(cancel, cancel.width / 2, cancel.height / 2)
    compare(rejected.count, 1)
    compare(accepted.count, 1)
    accepted.destroy()
    rejected.destroy()
  }
  function test_file_picker_retains_image_filter() {
    const picker = createTemporaryObject(folderPickerFactory, test, {selectFolder:false, filters:["svg"]})
    const accepted = Qt.createQmlObject('import QtTest; SignalSpy { signalName: "accepted" }', test)
    accepted.target = picker
    picker.open()
    tryVerify(() => !!picker.item)
    const contents = findChild(picker.item, "fileDialogContents")
    tryCompare(contents, "count", 3)
    contents.currentIndex = 0 // Directory.
    tryVerify(() => !!contents.currentItem)
    verify(!picker.item.selectionValid)
    contents.currentIndex = 1 // Text file.
    tryVerify(() => !!contents.currentItem && contents.currentItem.file.suffix === "txt")
    verify(!picker.item.selectionValid)
    contents.currentIndex = 2 // Image.
    tryVerify(() => picker.item.selectionValid)
    const select = findChild(picker.item, "fileDialogSelect")
    mouseClick(select, select.width / 2, select.height / 2)
    compare(accepted.count, 1)
    compare(accepted.signalArguments[0][0], Quickshell.env("OMACALE_TEST_FOLDER") + "/picture.svg")
    accepted.destroy()
  }
  function test_webapp_browser_change_keeps_window_identity() {
    DesktopEntries.applications.values = [{id:"YouTube",name:"YouTube",icon:"",startupClass:"chrome-youtube.com__-Default",command:[]}]
    const window = {address:"abc",workspace:{id:1,name:"1"},wayland:{appId:"brave-youtube.com__-Default",parent:null}}
    Hyprland.toplevels.values = [window]
    TaskbarApps.activate({type:"app",app:"YouTube"},fakeHost,false)
    compare(Sys.calls[0],"focus:0xabc")
    compare(launched.length,0)
  }
  function test_terminal_without_menu_capability_uses_omarchy() {
    DesktopEntries.applications.values = [{id:"nvim",name:"Neovim",icon:"",runInTerminal:true,command:["/usr/bin/nvim","%F"]}]
    fakeHost.shell = ({ appLibrary: null })
    Quickshell.commands = []
    TaskbarApps.activate({type:"app",app:"nvim"},fakeHost,false)
    compare(Quickshell.commands.length,1)
    compare(Quickshell.commands[0], ["/home/test/bin/omarchy-launch-tui","/usr/bin/nvim"])
    compare(launched.length,0)
  }
  function test_launch_and_cycle() {
    TaskbarApps.activate({type:"app",app:"editor"},fakeHost,false)
    compare(launched.length,1)
    const first={address:"a",workspace:{id:1,name:"1"},wayland:{appId:"editor",parent:null}}
    const second={address:"b",workspace:{id:2,name:"2"},wayland:{appId:"editor",parent:null}}
    Hyprland.toplevels.values=[first,second]
    Sys.activeToplevel=first
    TaskbarApps.activate({type:"app",app:"editor"},fakeHost,false)
    compare(Sys.calls[0],"focus:0xb")
    TaskbarApps.activate({type:"app",app:"editor"},fakeHost,true)
    compare(launched.length,2)
  }
}
