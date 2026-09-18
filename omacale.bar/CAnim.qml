import QtQuick

ColorAnimation {
  duration: Tk.durations.slowEffects
  easing.type: Easing.BezierSpline
  easing.bezierCurve: Tk.curves.slowEffects
}
