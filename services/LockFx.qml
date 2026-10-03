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
// So the closing is drawn by an overlay of Omacale's own (LockUnlockFx, one
// per screen), mapped once the lock's card is open and kept up until the
// unlock. Hyprland draws nothing but the lock surface while the session is
// locked, so the overlay sits behind it unseen, showing the lock's last
// frame; when the lock surface goes, the overlay is what is left, and it
// plays the closing over the desktop. Nothing in Omarchy's lock service
// changes.
//
// LockUi shares this singleton (it imports Omacale's module) and reports, per
// screen name:
//   arm(name)            the real lock is up on that screen
//   ready(name, frame)   its opening has finished: the overlay may show the
//                        open card, over `frame`, a grab of the lock's
//                        blurred backdrop (null: the surface colour)
//   unlock(name)         the password was accepted: play the closing
//   disarm(name)         the lock surface went without an unlock
Singleton {
  id: root

  // name -> { ready: bool, frame: grab result | null, playing: bool }
  property var screens: ({})

  function entry(name) {
    return screens[name] || null
  }

  function put(name, patch) {
    const next = Object.assign({}, screens)
    next[name] = Object.assign({ ready: false, frame: null, playing: false }, screens[name] || {}, patch)
    screens = next
  }

  function drop(name) {
    if (!(name in screens))
      return
    const next = Object.assign({}, screens)
    delete next[name]
    screens = next
  }

  function arm(name) {
    if (!name)
      return
    put(name, { ready: false, frame: null, playing: false })
  }

  function ready(name, frame) {
    if (name in screens && !screens[name].playing)
      put(name, { ready: true, frame: frame })
  }

  function unlock(name) {
    const e = entry(name)
    if (e && e.ready)
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
    for (const s of Quickshell.screens) {
      put(s.name, { ready: true, frame: null, playing: false })
    }
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
