// omacale:lock-view v5
//
// Written into the clone of Omarchy's lock plugin by
// omacale.bar/scripts/lock-screen. Omarchy's own view is kept beside it as
// StockLockView.qml and its Service.qml is untouched, so every part of the
// lock that matters -- PAM, the stranded-lock recovery, the blanking timers
// and the `lock` IPC that `omarchy system lock` and `omarchy-system-sleep-lock`
// call -- is still Omarchy's.
//
// This file only chooses who draws. It deliberately imports nothing from
// Omacale: Omacale's UI is loaded by URL, so a missing, broken or removed
// Omacale still leaves a working lock screen (the stock one) behind.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  // The contract Omarchy's Service.qml drives, copied from its LockView.qml.
  property string backgroundPath: ""
  property string videoPosterPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property bool displaysBlank: false
  property bool powerSaverActive: false
  property string passwordText: ""
  property bool syncingPasswordText: false

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested
  signal wakeRequested

  // Omacale's settings file, read directly rather than through Config.qml so
  // this file keeps no import of its own. Missing or unreadable means "on":
  // the handover is only ever installed by someone turning the lock on.
  property bool omacaleEnabled: true
  readonly property url omacaleUi: Qt.resolvedUrl("../omacale.bar/modules/lock/LockUi.qml")
  // OWE's live lock feed, which Omarchy ships beside its view. Omacale's UI
  // loads it from here so it needs no path into this plugin of its own.
  readonly property url feedSurfaceUrl: Qt.resolvedUrl("LockFeedSurface.qml")

  function readEnabled(text) {
    try {
      const lock = JSON.parse(text).lock
      root.omacaleEnabled = !lock || lock.enabled !== false
    } catch (e) {
      root.omacaleEnabled = true
    }
  }

  FileView {
    path: Quickshell.env("HOME") + "/.config/omacale/settings.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readEnabled(text())
    onLoadFailed: root.omacaleEnabled = true
  }

  // Omacale's lock UI resolves its imports from its own plugin directory, so
  // it gets Omacale's tokens, palette and services (the same singletons the
  // bar runs on) without this plugin importing any of them.
  Loader {
    id: omacale

    anchors.fill: parent
    active: root.omacaleEnabled
    source: active ? root.omacaleUi : ""
    onLoaded: item.view = root
  }

  // Anything that stops Omacale drawing -- turned off, not installed, a QML
  // error in the UI -- falls back to the view Omarchy shipped.
  Loader {
    anchors.fill: parent
    active: !omacale.active || omacale.status === Loader.Error
    sourceComponent: stock
  }

  // What Omarchy's view gained after v4.0.x: the blanking pair on
  // 2026-09-09, the video poster with the OWE lock feed on 2026-09-20.
  // Assigning one the installed view lacks is a load error, and a broken view
  // takes Service.qml -- and with it the lock IPC and the lock itself -- down,
  // so these are bound only where the view has them. Everything assigned
  // directly below is in every Omarchy 4 (lock-screen checks that too).
  readonly property var stockOptional: ["displaysBlank", "powerSaverActive", "videoPosterPath"]

  Component {
    id: stock

    StockLockView {
      id: stockView

      backgroundPath: root.backgroundPath
      backgroundVersion: root.backgroundVersion
      fingerprintConfigured: root.fingerprintConfigured
      authenticatingPassword: root.authenticatingPassword
      failureMessage: root.failureMessage
      failedAttempts: root.failedAttempts
      inputEnabled: root.inputEnabled
      loadBackground: root.loadBackground
      passwordText: root.passwordText

      onSubmitPassword: password => root.submitPassword(password)
      onPasswordTextEdited: password => root.passwordTextEdited(password)
      onClearFailureRequested: root.clearFailureRequested()
      onWakeRequested: root.wakeRequested()

      Component.onCompleted: {
        for (const name of root.stockOptional)
          if (name in stockView)
            stockView[name] = Qt.binding(() => root[name])
      }
    }
  }
}
