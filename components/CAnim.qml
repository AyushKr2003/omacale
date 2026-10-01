import QtQuick
import ".."

ColorAnimation {
  duration: Tk.durations.slowEffects
  easing.type: Easing.BezierSpline
  easing.bezierCurve: Tk.curves.slowEffects
}
