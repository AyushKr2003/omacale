import QtQuick

// Omarchy's Ui/PanelKeyCatcher.qml, as a dispatcher rather than an Item: the
// same keys and signals, so stock muscle memory carries over (arrows and
// h/j/k/l move, Enter/Space activate, Escape closes, Tab/Shift+Tab go to the
// next or previous panel, x deletes, other printable keys arrive as text).
//
// Upstream wraps the panel content and takes focus itself. Here the owner
// calls handle() from its own Keys.onPressed, so keys a focused child leaves
// unaccepted (a text field, the window info panel) still reach it by
// propagation. `blocked` hands every key to the child instead.
QtObject {
  id: root

  property bool blocked: false

  signal moveRequested(int dx, int dy)
  signal activateRequested()
  signal closeRequested()
  signal deleteRequested()
  signal tabRequested(int direction)
  signal textKey(string text)

  function handle(event) {
    if (blocked) return
    const t = event.text
    if (event.key === Qt.Key_Escape) closeRequested()
    else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
      tabRequested((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab ? -1 : 1)
    else if (event.key === Qt.Key_Down || t === "j") moveRequested(0, 1)
    else if (event.key === Qt.Key_Up || t === "k") moveRequested(0, -1)
    else if (event.key === Qt.Key_Right || t === "l") moveRequested(1, 0)
    else if (event.key === Qt.Key_Left || t === "h") moveRequested(-1, 0)
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) activateRequested()
    else if (t === "x" || t === "X") deleteRequested()
    else if (t && t.length === 1) { textKey(t); return }
    else return
    event.accepted = true
  }
}
