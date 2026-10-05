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

  Text {
    anchors.centerIn: parent
    text: spinner.sequence[Math.min(spinner.step, spinner.sequence.length - 1)]
    font.family: Theme.mono
    font.pixelSize: spinner.size
    color: spinner.color
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }
}
