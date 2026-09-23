import QtQuick
import QtQuick.Layouts
import "../.."

// The password field (Caelestia center/PasswordInput.qml + InputField.qml):
// a pill that grows with the password, an icon on the left that turns the
// characters visible, one Material shape per character, and an arrow on the
// right that morphs in once there is something to submit.
//
// The buffer itself lives in Omarchy's lock service (`lock.password`); this
// only draws it and hands keystrokes back, so PAM stays the only thing that
// ever holds the password.
Rectangle {
  id: root

  required property real centerScale
  required property int centerWidth
  required property var lock

  readonly property string buffer: lock.password
  readonly property bool authenticating: lock.authenticating
  property bool showPassword: false

  onBufferChanged: if (!buffer)
    showPassword = false

  implicitWidth: {
    const w = centerWidth * 0.8
    return buffer ? w : Math.min(w, placeholderMetrics.width + iconWrapper.implicitWidth + enterButton.implicitWidth + input.spacing * 2 + Tk.padding.medium * 2)
  }
  implicitHeight: input.implicitHeight + Tk.padding.small

  color: Colours.m3surfaceContainer
  radius: Tk.rounding.full

  Behavior on implicitWidth {
    Anim {}
  }

  TextMetrics {
    id: placeholderMetrics
    text: placeholder.text
    font: placeholder.font
  }

  StateLayer {
    hoverEnabled: false
    cursorShape: Qt.IBeamCursor
    onClicked: root.lock.wake()
  }

  RowLayout {
    id: input

    anchors.fill: parent
    anchors.margins: Tk.padding.extraSmall
    spacing: Tk.spacing.medium

    Item {
      id: iconWrapper

      Layout.fillHeight: true
      implicitWidth: height

      MIcon {
        anchors.centerIn: parent
        visible: !root.authenticating

        animate: true
        text: {
          if (root.showPassword)
            return "visibility"
          if (root.lock.fingerprint)
            return "fingerprint"
          return "lock"
        }
        fill: root.showPassword ? 1 : 0
        color: Colours.m3onSurfaceVariant
        size: Tk.iconSize.medium * root.centerScale

        StateLayer {
          anchors.fill: undefined
          anchors.centerIn: parent
          implicitWidth: {
            const w = parent.implicitHeight + Tk.padding.small * 2
            return w + (w % 2)
          }
          implicitHeight: implicitWidth
          radius: Tk.rounding.full

          onClicked: {
            parent.animate = false
            root.showPassword = !root.showPassword
            parent.animate = true
          }
        }
      }

      LoadingIndicator {
        anchors.centerIn: parent
        visible: root.authenticating
        implicitSize: iconWrapper.height - Tk.padding.small * 2
        colour: Colours.m3secondary
      }
    }

    // ------------------------------------------------------ the characters
    Item {
      id: field

      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true

      MText {
        id: placeholder

        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1

        animate: true
        text: {
          if (root.authenticating)
            return "Loading..."
          if (root.lock.fingerprint)
            return "Enter your password or touch the sensor"
          return "Enter your password"
        }
        color: root.authenticating ? Colours.m3secondary : Colours.m3outline
        font.pointSize: Tk.body.medium * root.centerScale
        axes: ({ "ROND": 25, "wdth": 110 })

        opacity: root.buffer ? 0 : 1

        Behavior on opacity {
          Anim {
            type: "effects"
          }
        }
      }

      ListView {
        id: charList

        readonly property int fullWidth: {
          let w = (count - 1) * spacing
          for (let i = 0; i < count; i++)
            w += ((itemAtIndex(i) as CharItem)?.nonAnimWidthScale ?? 1) * implicitHeight
          return w + implicitHeight // Extra padding at ends
        }

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: implicitWidth > field.width ? -(implicitWidth - field.width) / 2 : 0

        implicitWidth: fullWidth
        implicitHeight: Tk.body.medium * root.centerScale
        width: Math.min(implicitWidth, field.width)
        height: implicitHeight

        orientation: Qt.Horizontal
        spacing: Tk.spacing.extraSmall
        interactive: false

        model: root.buffer.length

        delegate: CharItem {}

        Behavior on implicitWidth {
          Anim {}
        }
      }
    }

    // ---------------------------------------------------- the enter button
    Item {
      id: enterButton

      implicitWidth: implicitHeight
      implicitHeight: {
        const h = enterIcon.implicitHeight + Tk.padding.extraSmall * 2
        return h % 2 === 0 ? h : h + 1
      }

      MShape {
        anchors.fill: parent

        color: root.buffer ? Colours.m3primary : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
        shape: root.buffer ? "arrow" : "circle"
        scale: !root.buffer ? 1 : mouse.pressed ? 0.6 : mouse.containsMouse ? 0.8 : 0.7
        rotation: 90

        Behavior on scale {
          Anim {
            type: "fastSpatial"
          }
        }

        MouseArea {
          id: mouse

          anchors.fill: parent
          hoverEnabled: true
          cursorShape: root.buffer ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: root.lock.submit()
        }
      }

      MIcon {
        id: enterIcon

        anchors.centerIn: parent
        text: "arrow_forward"
        color: Colours.m3onSurfaceVariant
        size: Tk.iconSize.medium * root.centerScale * 1.2
        opacity: root.buffer ? 0 : 1

        Behavior on opacity {
          Anim {
            type: "effects"
          }
        }
      }
    }
  }

  // One character: a Material shape that bulges in, settles into a circle,
  // and shrinks away when the character is deleted. The shape each position
  // gets is drawn from a queue shuffled once per lock, as Caelestia does.
  component CharItem: Item {
    id: char

    required property int index
    property real nonAnimWidthScale: 1

    implicitHeight: charList.implicitHeight

    ListView.onRemove: {
      initAnim.stop()
      removeAnim.start()
    }

    SequentialAnimation {
      id: initAnim

      running: true

      ParallelAnimation {
        Anim {
          target: char
          property: "opacity"
          from: 0
          to: 1
          type: "effects"
        }
        Anim {
          target: char
          property: "scale"
          from: 0
          to: 1
          type: "fastSpatial"
        }
        Anim {
          target: char
          property: "implicitWidth"
          from: charList.implicitHeight
          to: charList.implicitHeight * 1.3
          type: "effects"
        }
        PropertyAction {
          target: char
          property: "nonAnimWidthScale"
          value: 1.5
        }
      }
      PauseAnimation {
        duration: 180 * Tk.animScale
      }
      PropertyAction {
        target: charShape
        property: "shape"
        value: "circle"
      }
      ParallelAnimation {
        Anim {
          target: charShape
          property: "scale"
          to: 2 / 3
          type: "fastSpatial"
        }
        Anim {
          target: char
          property: "implicitWidth"
          to: charList.implicitHeight
          type: "effects"
        }
        PropertyAction {
          target: char
          property: "nonAnimWidthScale"
          value: 1
        }
      }
    }

    SequentialAnimation {
      id: removeAnim

      PropertyAction {
        target: char
        property: "ListView.delayRemove"
        value: true
      }
      ParallelAnimation {
        Anim {
          target: char
          property: "opacity"
          to: 0
          type: "effects"
        }
        Anim {
          target: char
          property: "scale"
          to: 0.5
        }
      }
      PropertyAction {
        target: char
        property: "ListView.delayRemove"
        value: false
      }
    }

    MShape {
      id: charShape

      anchors.centerIn: parent
      implicitSize: charList.implicitHeight * 1.5
      shape: root.shapeQueue[char.index % root.shapeQueue.length]
      color: Colours.m3onSurface

      opacity: root.showPassword ? 0 : 1

      Behavior on opacity {
        Anim {
          type: "effects"
        }
      }
    }

    MText {
      anchors.centerIn: parent
      opacity: root.showPassword ? 1 : 0
      text: root.buffer[char.index] ?? ""
      font.pointSize: Tk.body.medium * root.centerScale

      Behavior on opacity {
        Anim {
          type: "effects"
        }
      }
    }
  }

  readonly property list<string> shapeQueue: {
    const shapes = ["slanted", "arch", "fan", "arrow", "triangle", "diamond", "clamShell", "pentagon", "gem", "sunny", "verySunny", "cookie4", "ghostish", "softBurst"]
    for (let i = shapes.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1))
      ;[shapes[i], shapes[j]] = [shapes[j], shapes[i]]
    }
    return shapes
  }
}
