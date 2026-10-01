import QtQuick
import Quickshell
import "../.."

// Caelestia modules/utilities/toasts/Toasts.qml: the toast column above the
// utilities corner, newest at the bottom. At most `maxToasts` show; the rest
// wait their turn. A toast scales and fades out when it closes, and the
// ones above it move down as it goes.
Item {
  id: root

  readonly property int spacing: Tk.spacing.small
  readonly property int maxToasts: Config.o.utilities.maxToasts
  property bool flag

  implicitWidth: Tk.sizes.toastWidth - Tk.padding.medium * 2
  implicitHeight: {
    flag // Force update
    let h = -spacing
    for (let i = 0; i < repeater.count; i++) {
      const item = repeater.itemAt(i)
      if (item && !item.modelData.closed && !item.previewHidden)
        h += item.implicitHeight + spacing
    }
    return Math.max(0, h)
  }

  Repeater {
    id: repeater

    // A ScriptModel, as Caelestia's: it keeps the delegates of toasts that
    // stay in the list, where a plain array would rebuild them all.
    model: ScriptModel {
      values: {
        const toasts = []
        let count = 0
        for (const toast of Toaster.toasts) {
          toasts.push(toast)
          if (!toast.closed) {
            count++
            if (count > root.maxToasts)
              break
          }
        }
        return toasts
      }
      onValuesChanged: root.flagChanged()
    }

    ToastWrapper {}
  }

  component ToastWrapper: MouseArea {
    id: toast

    required property int index
    required property var modelData

    readonly property bool previewHidden: {
      let extraHidden = 0
      for (let i = 0; i < index; i++)
        if (Toaster.toasts[i] && Toaster.toasts[i].closed)
          extraHidden++
      return index >= root.maxToasts + extraHidden
    }

    onPreviewHiddenChanged: {
      if (initAnim.running && previewHidden)
        initAnim.stop()
    }

    opacity: modelData.closed || previewHidden ? 0 : 1
    scale: modelData.closed || previewHidden ? 0.7 : 1

    property real bottomMargin: {
      root.flag // Force update
      let y = 0
      for (let i = 0; i < index; i++) {
        const item = repeater.itemAt(i)
        if (item && !item.modelData.closed && !item.previewHidden)
          y += item.implicitHeight + root.spacing
      }
      return y
    }

    x: 0
    y: root.height - height - bottomMargin
    width: root.width
    height: implicitHeight
    implicitHeight: toastInner.implicitHeight

    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: modelData.close()

    Component.onCompleted: {
      modelData.lock(this)
      root.flagChanged()
    }
    Component.onDestruction: if (modelData) modelData.unlock(this)

    Anim {
      id: initAnim

      Component.onCompleted: running = !toast.previewHidden

      target: toast
      properties: "opacity,scale"
      from: 0
      to: 1
    }

    ParallelAnimation {
      running: toast.modelData.closed
      onStarted: toast.bottomMargin = toast.bottomMargin
      onFinished: toast.modelData.unlock(toast)

      Anim {
        type: "effects"
        target: toast
        property: "opacity"
        to: 0
      }
      Anim {
        target: toast
        property: "scale"
        to: 0.7
      }
    }

    ToastItem {
      id: toastInner

      modelData: toast.modelData
    }

    Behavior on opacity {
      Anim {
        type: "effects"
      }
    }

    Behavior on scale {
      Anim {}
    }

    Behavior on bottomMargin {
      Anim {}
    }
  }
}
