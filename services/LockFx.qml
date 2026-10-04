pragma Singleton

import QtQuick
import Quickshell

// The unlock animation's hand-off from the lock surface to the bar.
//
// Caelestia owns its session lock, so it plays the card's closing first and
// only then sets `locked: false`. Omacale's lock is Omarchy's (see
// LockService): its `finishUnlock()` drops the session lock in the same call
// that tells our view the password was accepted, and the lock surface goes
// with it, so nothing drawn on that surface is ever seen leaving.
//
// So the card the user sees is drawn by an overlay of Omacale's own
// (LockUnlockFx, one per screen), which Hyprland draws *above* the lock
// (the `above_lock = 2` layer rule, set in Bar.qml and omacale.lua). It is up
// for the whole lock, mirroring the lock's own card frame for frame, while
// the lock surface below it keeps the keyboard, the backdrop and PAM. When
// the lock goes, the card is already on screen, so the closing simply plays
// on, with no hand-off frame. Nothing in Omarchy's lock service changes.
//
// LockUi shares this singleton (it imports Omacale's module) and reports, per
// screen name:
//   arm(name, ui)        the real lock is up on that screen, drawn by `ui`
//   ready(name, frame)   its opening has finished: `frame` is a grab of the
//                        lock's blurred backdrop, for the overlay to fade out
//   unlock(name)         the lock let go: play the closing
//   disarm(name)         the lock surface went without an unlock
// and the overlay reports cover(name, on): whether Hyprland is really
// drawing it above the lock. Only then does the lock hide its own card, so a
// Hyprland without the rule still shows the lock's card, just no closing.
Singleton {
  id: root

  // name -> { ui: LockUi | null, frame: grab result | null,
  //           covering: bool, playing: bool }
  property var screens: ({})

  function entry(name) {
    return screens[name] || null
  }

  function put(name, patch) {
    const next = Object.assign({}, screens)
    next[name] = Object.assign({ ui: null, frame: null, covering: false, playing: false }, screens[name] || {}, patch)
    screens = next
  }

  function drop(name) {
    if (!(name in screens))
      return
    const next = Object.assign({}, screens)
    delete next[name]
    screens = next
  }

  function arm(name, ui) {
    if (!name)
      return
    put(name, { ui: ui, frame: null, covering: false, playing: false })
  }

  function ready(name, frame) {
    const e = entry(name)
    if (e && !e.playing)
      put(name, { frame: frame })
  }

  function cover(name, on) {
    const e = entry(name)
    if (e && !e.playing && e.covering !== on)
      put(name, { covering: on })
  }

  function unlock(name) {
    const e = entry(name)
    if (e && e.covering)
      put(name, { playing: true })
    else
      drop(name)
  }

  function disarm(name) {
    const e = entry(name)
    if (e && !e.playing)
      drop(name)
  }

  // The overlay is done (or gave up): unmap it.
  function finished(name) {
    drop(name)
  }

  // Dev loop (IPC `omacale unlockFx`): the closing on every screen, over the
  // desktop, without a real lock -- nothing else can show it, since only the
  // real password ends a real lock.
  function test() {
    for (const s of Quickshell.screens)
      put(s.name, { ui: null, frame: null, covering: true, playing: false })
    testTimer.restart()
  }

  Timer {
    id: testTimer

    interval: 1200
    onTriggered: {
      for (const s of Quickshell.screens)
        root.unlock(s.name)
    }
  }
}
