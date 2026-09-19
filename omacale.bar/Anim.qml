import QtQuick

// Caelestia's Anim: expressive spatial by default.
// type: fastSpatial | spatial | slowSpatial | fastEffects | effects | slowEffects
//       | standardSmall | standard | standardLarge | standardExtraLarge | emphasized | emphasizedLarge
NumberAnimation {
  property string type: "spatial"
  readonly property var _spec: ({
    fastSpatial: [Tk.durations.fastSpatial, Tk.curves.fastSpatial],
    spatial: [Tk.durations.defaultSpatial, Tk.curves.defaultSpatial],
    slowSpatial: [Tk.durations.slowSpatial, Tk.curves.slowSpatial],
    fastEffects: [Tk.durations.fastEffects, Tk.curves.fastEffects],
    effects: [Tk.durations.defaultEffects, Tk.curves.defaultEffects],
    slowEffects: [Tk.durations.slowEffects, Tk.curves.slowEffects],
    standardSmall: [Tk.durations.small, Tk.curves.standard],
    standard: [Tk.durations.normal, Tk.curves.standard],
    standardLarge: [Tk.durations.large, Tk.curves.standard],
    standardExtraLarge: [Tk.durations.extraLarge, Tk.curves.standard],
    emphasized: [Tk.durations.normal, Tk.curves.emphasized],
    emphasizedLarge: [Tk.durations.large, Tk.curves.emphasized]
  })[type] || [Tk.durations.defaultSpatial, Tk.curves.defaultSpatial]
  duration: _spec[0]
  easing.type: Easing.BezierSpline
  easing.bezierCurve: _spec[1]
}
