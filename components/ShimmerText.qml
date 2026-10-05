import QtQuick

// Claude Code's status-verb shimmer: a three-character band of lighter color
// sweeps left to right across the text ("W[hat]chamacalliting…").
Text {
  id: shimmer

  property string label: ""
  property bool running: true
  property color baseColor: Theme.claude
  property color glowColor: Theme.claudeGlow
  property int band: 3
  property int pos: -band

  textFormat: running && !Theme.reduceMotion ? Text.StyledText : Text.PlainText
  font.family: Theme.font
  font.pixelSize: 14
  color: baseColor
  elide: Text.ElideRight
  maximumLineCount: 1
  verticalAlignment: Text.AlignVCenter

  function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }

  text: {
    if (!running || Theme.reduceMotion) return label
    var a = Math.max(0, pos), b = Math.max(0, Math.min(label.length, pos + band))
    return esc(label.substring(0, a))
      + "<font color='" + glowColor + "'>" + esc(label.substring(a, b)) + "</font>"
      + esc(label.substring(b))
  }

  Accessible.name: label

  Timer {
    interval: 80
    repeat: true
    running: shimmer.running && shimmer.visible && !Theme.reduceMotion
    onTriggered: shimmer.pos = shimmer.pos >= shimmer.label.length + shimmer.band ? -shimmer.band : shimmer.pos + 1
  }
}
