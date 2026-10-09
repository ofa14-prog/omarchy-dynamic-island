import QtQuick
import "Agents.js" as Agents

// The busy spinner of a coding agent. For Claude Code it is the terminal
// spinner frame for frame (· ✢ * ✶ ✻ ✽ and back, every 120 ms, captured
// from a live `claude` session); other agents get their CLI's braille dots.
// Idle, it rests on a steady frame.
Item {
  id: spinner

  property string agent: "claude"
  property bool running: true
  property int size: 16
  readonly property var profile: Agents.get(agent)
  property color color: profile.color

  readonly property var sequence: profile.pingpong ? profile.frames.concat(profile.frames.slice().reverse()) : profile.frames
  readonly property int restFrame: profile.pingpong ? 4 : 0
  property int step: restFrame

  implicitWidth: size
  implicitHeight: size

  Accessible.role: Accessible.Animation
  Accessible.name: running ? profile.name + " " + I18n.t("Çalışıyor") : profile.name

  onAgentChanged: step = restFrame

  Timer {
    interval: spinner.profile.interval
    repeat: true
    running: spinner.running && spinner.visible && !Theme.reduceMotion
    onTriggered: spinner.step = (spinner.step + 1) % spinner.sequence.length
    onRunningChanged: if (!running) spinner.step = spinner.restFrame
  }

  readonly property string frame: sequence[Math.min(step, sequence.length - 1)] || ""
  // Braille frames (every agent but Claude) are drawn as real dots on a 2×4
  // grid, centered in the box: font glyphs for braille sit off-center and
  // overflow their cell, so the spinner used to spill past the island.
  readonly property int code: frame.length === 1 ? frame.charCodeAt(0) : 0
  readonly property bool braille: code >= 0x2800 && code <= 0x28FF
  Item {
    visible: spinner.braille
    anchors.centerIn: parent
    readonly property real cell: spinner.size / 4.4
    width: cell * 2
    height: cell * 4
    Repeater {
      // dot n (1–8) → bit n-1; columns: 1 2 3 7 left, 4 5 6 8 right
      model: [[0, 0, 0], [1, 0, 1], [2, 0, 2], [3, 1, 0], [4, 1, 1], [5, 1, 2], [6, 0, 3], [7, 1, 3]]
      delegate: Rectangle {
        required property var modelData
        readonly property real d: parent.cell * 0.72
        x: modelData[1] * parent.cell + (parent.cell - d) / 2
        y: modelData[2] * parent.cell + (parent.cell - d) / 2
        width: d; height: d; radius: d / 2
        color: spinner.color
        visible: ((spinner.code - 0x2800) >> modelData[0]) & 1
      }
    }
  }
  Text {
    visible: !spinner.braille
    anchors.centerIn: parent
    text: spinner.frame
    font.family: Theme.mono
    font.pixelSize: spinner.size
    color: spinner.color
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }
}
