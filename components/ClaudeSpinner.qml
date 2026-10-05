import QtQuick

// Claude Code's own spinner, frame for frame: on Linux it cycles
// · ✢ * ✶ ✻ ✽ and back every 120 ms in Claude orange (captured from a live
// `claude` session). Idle, it rests on the ✻ frame.
Item {
  id: spinner

  property bool running: true
  property color color: Theme.claude
  property int size: 16

  readonly property var frames: ["·", "✢", "*", "✶", "✻", "✽"]
  readonly property var sequence: frames.concat(frames.slice().reverse())
  property int step: 0

  implicitWidth: size
  implicitHeight: size

  Accessible.role: Accessible.Animation
  Accessible.name: running ? I18n.t("Claude çalışıyor") : "Claude"

  Timer {
    interval: 120
    repeat: true
    running: spinner.running && spinner.visible && !Theme.reduceMotion
    onTriggered: spinner.step = (spinner.step + 1) % spinner.sequence.length
    onRunningChanged: if (!running) spinner.step = 4
  }

  Text {
    anchors.centerIn: parent
    text: spinner.sequence[spinner.step]
    font.family: Theme.mono
    font.pixelSize: spinner.size
    color: spinner.color
    textFormat: Text.PlainText
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }
}
