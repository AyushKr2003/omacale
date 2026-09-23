# Plan: four Caelestia features Omacale is missing

Four Caelestia UI features to port into Omacale. They are built one at a time,
and each step is verified (screenshot + log) and committed on its own with a
version bump. The rules in `CLAUDE.md` apply throughout: match Caelestia's
structure, use `Tk.*` tokens and `Colours.m3*` roles, go through `Anim`/`CAnim`,
and prefer Omarchy, then Quickshell/Hyprland, then our own code.

| # | Feature | Caelestia source | Version |
|---|---|---|---|
| 0 | Sticky popouts (shared groundwork) | `bar/popouts/Wrapper.qml` (focus + detach) | part of 1 |
| 1 | Wi-Fi password popout | `bar/popouts/WirelessPassword.qml`, `Network.qml` | 0.19.0 |
| 2 | Keyboard layout status icon + popout | `bar/popouts/kblayout/KbLayout.qml`, `KbLayoutModel.qml`, `bar/components/StatusIcons.qml`, `services/Hypr.qml` | 0.20.0 |
| 3 | Launcher calculator | `launcher/items/CalcItem.qml`, `AppList.qml`, `launcherconfig.hpp` | 0.21.0 |
| 4 | Window info panel | `windowinfo/*.qml`, `bar/popouts/ActiveWindow.qml`, `Wrapper.qml` (`detach("winfo")`) | 0.22.0 |

---

## Status

All four are done: 0.19.0 (password), 0.20.0 (keyboard layout), 0.21.0
(calculator), 0.22.0 (window info). Where the build differs from this plan,
there's a **Done** note in that section.

## 0. Groundwork: popouts that can be sticky and take the keyboard

> **Done, with one change:** the tray menu stays sticky-but-swappable as before,
> but the two keyboard popouts are *held* (`ScreenScope.popoutHeld`): hovering
> other bar icons doesn't replace them, so crossing the bar can't throw away a
> half-typed password. Escape, their own buttons or a click outside close them.

Right now every bar popout is hover-only. It closes as soon as the pointer
leaves (`ScreenScope.updatePointer` and `onContainsMouseChanged`) and never gets
the keyboard. `traymenu` is the one exception, special-cased by name in four
places. Both the password popout and the window info panel need what the tray
menu has. They also need the keyboard.

In `modules/drawers/ScreenScope.qml`:

- Add `readonly property bool stickyPopout: ["traymenu", "wirelesspassword", "winfo"].indexOf(popout) >= 0`
  and replace the `scope.popout !== "traymenu"` checks with `!scope.stickyPopout`.
  The tray menu keeps its own `trayItem` handling.
- Add `readonly property bool popoutKeys: popout === "wirelesspassword" || popout === "winfo"`.
  Add it to `win`'s `WlrLayershell.keyboardFocus` (OnDemand) and to `grabWanted`.
  Caelestia does the same thing with its `Binding` on `keyboardFocus` plus a
  `HyprlandFocusGrab` while detached.
- Hovering another bar icon still replaces a sticky popout, as it does for the tray
  menu. Clicking outside clears the grab, which closes it (`closeAll`).
- `PopoutContent` gets `signal switchRequested(string name)`, so a page can
  change the popout (network → password → network, activewindow → winfo). It
  also gets `property string passwordSsid`. ScreenScope handles the signal by
  setting `scope.popout`.

## 1. Wi-Fi password popout (bar)

**Caelestia behaviour:** you click a secured network you haven't saved in the
network popout. The popout morphs into a password card: a lock icon, "Enter
password", "Network: <ssid>", a password field that draws a rounded dot per
character, a status line ("Connecting…" / "Connection failed…"), and Cancel /
Connect buttons. Enter connects and Escape or Cancel goes back to the network
popout. When the connection succeeds, it returns to the network popout.

**Omacale today:** `PopoutContent` opens Settings › Network with the inline
prompt already expanded.

**Engine:** `NetService` (Quickshell.Networking, as Omarchy's network panel).
`activate(net)` decides whether a password is needed (`passwordSsid`),
`connectWithPsk(net, psk)` connects, and `failureSsid`/`failureReason` +
`actionKind` report the result. There's nothing new on the engine side.

Steps:
1. In the network popout's link button, call `NetService.activate(net)`. If
   `NetService.passwordSsid === net.name`, emit `switchRequested("wirelesspassword")`
   with the ssid, instead of opening Settings. Enterprise (802.1X) networks
   need an identity as well, so they keep opening Settings › Network, where that
   field exists.
2. Also switch to the password popout when a saved network fails with
   "Password required" / "Wrong password". `NetService.fail` sets `passwordSsid`,
   so watch it while the network popout is showing.
3. New `wirelesspassword` component in `PopoutContent.qml`, ported from
   `WirelessPassword.qml`, width 400:
   - a `FocusScope` that collects keys into `passwordBuffer`. Backspace deletes a
     character and Ctrl+Backspace clears the field. Enter connects and Escape cancels.
   - the dot `ListView` with its add/remove animations, the focus border (4px
     primary, error on failure), and the "Password" placeholder in mono
   - Cancel (`secondaryContainer`) and Connect (`primary`) buttons, with Connect
     disabled while the field is empty or connecting
   - the status line, driven by `NetService.busy/actionSsid` (connecting) and
     `failureSsid/failureReason` (error). On error the buffer clears.
   - on success (`NetService.connectedNetwork.name === ssid`), go back to the
     network popout
4. Check: open the popout on an unsaved secured network, type a wrong password
   (expect the error), then Cancel. Confirm hovering elsewhere replaces the popout,
   clicking outside closes it, and the log is clean.

## 2. Keyboard layout (bar)

**Caelestia behaviour:** an optional `kbLayout` status icon shows the active
layout's short code (e.g. `US`) in mono text. Hovering it opens the "Keyboard
layouts" popout, which lists the other configured layouts (click to switch;
layouts past the 4th are greyed out, since XKB allows only 4), then a divider,
then the active layout with a keyboard icon in primary. That row pops in on every
change.

**Engine:** Omarchy has no layout command, so this uses Hyprland (tier 3).
- The configured layouts come from `hyprctl -j getoption input:kb_layout`. If
  that's empty, the fallback is `hyprctl -j devices` (main keyboard's `layout`).
- The active index and keymap come from `hyprctl -j devices` once, then from
  Hyprland's `activelayout` raw event, so there's no polling.
- Switching uses `hyprctl switchxkblayout all <index>`. That's a hyprctl command,
  not a dispatcher, so it works with the Lua config.
- Names come from `/usr/share/X11/xkb/rules/base.lst` (via `FileView`), parsed the
  way Caelestia's `Hypr.qml` does for both the layout and variant sections. This
  file is enough for both the popout and the icon, so the xmllint call Caelestia
  uses for `base.xml` isn't needed.

Steps:
1. New singleton `services/KbService.qml`: `layouts` (`[{ index, token, code, label }]`),
   `activeIndex`, `activeLabel`, `code` (short code for the bar), `switchTo(i)`, `refresh()`.
   The popout calls `refresh()` when it opens, as Caelestia does.
2. Status icon in `BarContent.qml`: `MText` in `Tk.mono`, `popout: "kblayout"`,
   gated by a new `bar.status.kbLayout` config key (default `false`, as in
   Caelestia's `barconfig.hpp`). Add it to `Defaults.js`, the Status icons settings
   page, and the pill's `visible` sum.
3. `kblayout` component in `PopoutContent.qml`, ported from `KbLayout.qml`, width
   `Tk.sizes.kbLayoutWidth` (320, new token). Keep its list transitions, the
   4-layout limit with tooltip, the divider, and the `popIn` animation on the active row.
4. Check: with `us` alone, the popout shows only the active row. Temporarily add a
   second layout with `hyprctl keyword input:kb_layout us,de` (the Lua config
   may need `hl.config`; restore it afterwards), switch from the popout, and
   confirm the icon and the active row update. The log should be clean.

## 3. Launcher calculator

**Caelestia behaviour:** the `>` actions list includes "Calculator" ("Do simple
maths equations"), which autocompletes to `>calc `. In that mode the list shows
exactly one row: a `function` icon, the result (the prompt text when the query is
empty, the error colour for errors), and a tertiary pill that widens on hover to
show "Open in calculator". Enter or a click copies the result (`wl-copy`) and
closes the launcher. The pill opens `qalc -i '<expr>'` in the terminal.

**Engine:** Omarchy ships no calculator, and Caelestia's `Qalculator` is a C++
libqalculate binding Omacale can't load. So this is our own code (tier 4), kept
small.

> **Done (0.21.0), with one change from this plan:** evaluation always uses
> `Calc.js`. The `qalc` evaluation path was dropped: qalc isn't installed on
> the dev machine, so it couldn't be verified, and two engines would print
> different forms. qalc is used only by the "Open in calculator" button, which
> shows when it's installed (`omarchy-launch-tui qalc -i <expr>`).

- `services/Calc.js`: a recursive-descent evaluator. It supports numbers
  (including `1e3`, `.5`), `+ - * / % ^`, unary minus, parentheses, `!`, the
  constants `pi e tau`, and the functions `sqrt cbrt abs sin cos tan asin acos atan
  ln log log2 exp floor ceil round min max pow`. It never uses `eval`, and it
  returns `{ result }` or `{ error }`. Results are formatted to 12 significant
  digits with trailing zeros trimmed.
- If `qalc` is installed (checked once with `command -v qalc`), use it instead
  (`qalc -t <expr>`, debounced). That's the same engine as Caelestia, and it adds
  units and conversions. The "Open in calculator" pill only shows when `qalc`
  exists.

Steps:
1. Add `{ name: "Calculator", comment: "Do simple maths equations", icon: "calculate", autocomplete: "calc" }` to `actions`.
2. Add a `calc` mode to `Launcher.qml`: `search.text.startsWith(prefix + "calc ")`.
   `results` becomes `[{ calc: true }]`, and the list draws a calc delegate for it
   (a `Loader` on the row picking the calc layout), so sizing, highlight and
   Enter all go through the existing list.
3. `activate` for the calc row runs `wl-copy <result>` and dismisses the launcher.
   An error or empty result does nothing.
4. Check: `>calc 2+3*4` gives `14`, `>calc sqrt(2)^2` gives `2`, `>calc 1/0` gives an
   error, and `>calc (` gives an error. Confirm Enter puts the result on the
   clipboard (`wl-paste`). Screenshot.

## 4. Window info panel

> **Done, with two changes:** Kill also closes the panel. Caelestia's stays
> open and turns to the next active window, so a second click would kill that
> window too. And because the popout keeps its last page loaded, the panel
> resets (grid collapsed, toplevels refreshed, keyboard retaken) each time it
> opens. Its parts are named `WinfoPreview`/`WinfoDetails`/`WinfoButtons`,
> since the qmldir is flat and `Preview` etc. are too generic.

**Caelestia behaviour:** the active-window popout has a header row (app icon,
title, class, and a `chevron_right` button) above a live preview. The chevron
"detaches" the popout into the window info panel, which is `screen.height * 0.7`
tall and grabs focus:
- **Preview**: a live `ScreencopyView` at the window's aspect ratio, with
  "<title> on monitor <m> at x, y" under it. There's a "No active client" empty
  state.
- **Details** card (500 wide): title, class, a divider, then icon rows for address,
  position, size, workspace, monitor, initial title, initial class, pid,
  floating, xwayland, pinned, and fullscreen state.
- **Buttons** card: "Move to workspace" with an expanding 5×2 grid of the
  current group of 10 (the current one disabled), Float/Tile, Pin/Unpin (floating
  only), and Kill (error container).

**Engine:** Quickshell Hyprland (`Sys.activeToplevel`, `lastIpcObject`, refreshed
with `Hyprland.refreshToplevels()` when the panel opens). Actions go through
`Sys.hypr` with Lua dispatchers, like the existing `Sys.moveWindow`, using new
helpers `Sys.floatWindow`, `Sys.pinWindow` and `Sys.killWindow`.

Steps:
1. Rework the `activewindow` popout to Caelestia's layout (header row on top,
   preview under it at `windowPreviewSize` 400), adding the chevron that emits
   `switchRequested("winfo")`. Omacale currently has it upside down (preview
   first), which is itself a divergence to fix.
2. New `modules/windowinfo/WindowInfo.qml`, `Preview.qml`, `Details.qml` and
   `Buttons.qml`, ported one-to-one and registered in `qmldir`. New tokens
   `Tk.sizes.winfoHeightMult` (0.7) and `Tk.sizes.winfoDetailsWidth` (500).
3. `winfo` component in `PopoutContent.qml` hosts `WindowInfo` and needs the
   screen height (`host`/scope passes `screen`). Escape closes it.
4. Also add an IPC `omacale windowInfo` (and a keybind comment in `keybinds.lua`)
   that opens it centred on the bar. Caelestia only reaches it from the popout;
   this is an Omacale addition, noted in the README.
5. Check: open it from the popout and via IPC, use move to workspace, float/tile,
   pin, and kill on a throwaway terminal. Screenshot the panel. The log should be
   clean.

---

## Per-step routine

1. Edit in `shell/omacale/omacale.bar`.
2. `rsync -a ./ ~/.config/omarchy/plugins/omacale.bar/`, then
   `HYPRLAND_INSTANCE_SIGNATURE=… omarchy-restart-shell`.
3. Read the log for `WARN|ERROR`, drive the feature, and screenshot it.
4. Bump the version in `manifest.json`, `scripts/omacale` and `Bar.qml`. Update
   the README feature list and the `CLAUDE.md` port table.
5. Commit in `shell/omacale` (`feat: …`), then commit the submodule pointer in
   omarchy-dotfiles. Don't push.

## Out of scope

- Caelestia's keyboard-layout toasts (`kbLayoutChanged`, `kbLimit`). Omacale has
  no utilities toasts yet, so this waits for that feature.
- The lock screen's layout line in `StateMessage.qml`.
- Caelestia's other detach modes (audio/bluetooth into Nexus).
