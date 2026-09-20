import QtQuick

// What the lock says under the password field (Caelestia
// center/StateMessage.qml): a red message that flashes when a password is
// refused, and, when there is nothing to complain about, the caps / num lock
// hint. Omarchy's lock service counts the attempts, so the wording carries
// its count rather than a second one of ours.
Item {
  id: root

  required property var lock

  readonly property string msg: {
    if (!lock.failureMessage)
      return ""

    const attempts = lock.failedAttempts > 1 ? ` (${lock.failedAttempts})` : ""
    if (lock.fingerprint)
      return `Incorrect password${attempts}. Please try again or use fingerprint.`
    return `Incorrect password${attempts}. Please try again.`
  }

  readonly property string stateMsg: {
    if (Sys.capsLock && Sys.numLock)
      return "Caps lock and Num lock are ON."
    if (Sys.capsLock)
      return "Caps lock is ON."
    if (Sys.numLock)
      return "Num lock is ON."
    return ""
  }

  property bool stateMsgShouldBeVisible

  implicitHeight: Math.max(message.implicitHeight, stateMessage.implicitHeight)

  Behavior on implicitHeight {
    Anim {}
  }

  onMsgChanged: {
    if (msg) {
      if (message.opacity > 0) {
        message.animate = true
        message.text = msg
        message.animate = false

        exitAnim.stop()
        if (message.scale < 1)
          appearAnim.restart()
        else
          flashAnim.restart()
      } else {
        message.text = msg
        exitAnim.stop()
        appearAnim.restart()
      }
    } else {
      appearAnim.stop()
      flashAnim.stop()
      exitAnim.start()
    }
  }

  onStateMsgChanged: {
    if (stateMsg) {
      if (stateMessage.opacity > 0) {
        stateMessage.animate = true
        stateMessage.text = stateMsg
        stateMessage.animate = false
      } else {
        stateMessage.text = stateMsg
      }
      stateMsgShouldBeVisible = true
    } else {
      stateMsgShouldBeVisible = false
    }
  }

  MText {
    id: stateMessage

    anchors.left: parent.left
    anchors.right: parent.right

    scale: root.stateMsgShouldBeVisible && !root.msg ? 1 : 0.7
    opacity: root.stateMsgShouldBeVisible && !root.msg ? 1 : 0
    color: Colours.m3onSurfaceVariant

    font.pointSize: Tk.body.small
    horizontalAlignment: Qt.AlignHCenter
    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    lineHeight: 1.2

    Behavior on scale {
      Anim {}
    }

    Behavior on opacity {
      Anim {
        type: "effects"
      }
    }
  }

  MText {
    id: message

    anchors.left: parent.left
    anchors.right: parent.right

    scale: 0.7
    opacity: 0
    color: Colours.m3error

    font.pointSize: Tk.body.small
    horizontalAlignment: Qt.AlignHCenter
    wrapMode: Text.WrapAtWordBoundaryOrAnywhere

    Anim {
      id: appearAnim

      type: "effects"
      target: message
      properties: "scale,opacity"
      to: 1
      onFinished: flashAnim.restart()
    }

    // Two blinks, as Caelestia flashes a refused password.
    SequentialAnimation {
      id: flashAnim

      loops: 2

      FlashAnim {
        to: 0.3
      }
      FlashAnim {
        to: 1
      }
    }

    ParallelAnimation {
      id: exitAnim

      Anim {
        target: message
        property: "scale"
        to: 0.7
        type: "standardLarge"
      }
      Anim {
        target: message
        property: "opacity"
        to: 0
        type: "standardLarge"
      }
    }
  }

  component FlashAnim: NumberAnimation {
    target: message
    property: "opacity"
    duration: Tk.durations.small
    easing.type: Easing.Linear
  }
}
