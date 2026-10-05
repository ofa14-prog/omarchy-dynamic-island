import QtQuick
import Quickshell

// Countdown timer and stopwatch. Wall-clock based, so pausing the shell or a
// slow frame never drifts the time.
Item {
  id: timer

  property string mode: ""        // "" | "countdown" | "stopwatch"
  property bool paused: false
  property double startedAt: 0    // ms, adjusted for pauses
  property double pausedAt: 0
  property double durationMs: 0   // countdown length
  property double nowMs: Date.now()
  property bool ringing: false
  property string label: ""

  readonly property bool active: mode !== ""
  readonly property double elapsedMs: !active ? 0 : Math.max(0, (paused ? pausedAt : nowMs) - startedAt)
  readonly property double remainingMs: mode === "countdown" ? Math.max(0, durationMs - elapsedMs) : 0
  readonly property real progress: mode === "countdown" && durationMs > 0 ? Math.min(1, elapsedMs / durationMs) : 0
  readonly property string display: format(mode === "countdown" ? Math.ceil(remainingMs / 1000) * 1000 : elapsedMs, mode === "stopwatch")

  signal finished()

  function format(ms, tenths) {
    var total = Math.floor(ms / 1000)
    var h = Math.floor(total / 3600), m = Math.floor((total % 3600) / 60), s = total % 60
    var pad = n => (n < 10 ? "0" : "") + n
    var out = h > 0 ? h + ":" + pad(m) + ":" + pad(s) : m + ":" + pad(s)
    if (tenths && h === 0 && m < 10) out += "," + Math.floor((ms % 1000) / 100)
    return out
  }

  function startCountdown(seconds, name) {
    if (!(seconds > 0)) return
    mode = "countdown"
    durationMs = seconds * 1000
    startedAt = Date.now()
    nowMs = startedAt
    paused = false
    ringing = false
    label = name || ""
  }

  function startStopwatch() {
    mode = "stopwatch"
    durationMs = 0
    startedAt = Date.now()
    nowMs = startedAt
    paused = false
    ringing = false
    label = ""
  }

  function togglePause() {
    if (!active) return
    if (paused) { startedAt += Date.now() - pausedAt; paused = false }
    else { pausedAt = Date.now(); paused = true }
    nowMs = Date.now()
  }

  function addSeconds(seconds) {
    if (mode !== "countdown") return
    durationMs += seconds * 1000
    ringing = false
  }

  function cancel() {
    mode = ""
    paused = false
    ringing = false
  }

  function dismissRing() {
    ringing = false
    if (mode === "countdown" && remainingMs <= 0) cancel()
  }

  Timer {
    interval: timer.mode === "stopwatch" ? 100 : 250
    repeat: true
    running: timer.active && !timer.paused
    onTriggered: {
      timer.nowMs = Date.now()
      if (timer.mode === "countdown" && timer.remainingMs <= 0 && !timer.ringing) {
        timer.ringing = true
        timer.paused = true
        timer.pausedAt = timer.startedAt + timer.durationMs
        timer.finished()
      }
    }
  }

  // Chime a few times until acknowledged, like the iOS timer.
  Timer {
    id: chime
    property int count: 0
    interval: 2200
    repeat: true
    running: timer.ringing
    triggeredOnStart: true
    onRunningChanged: count = 0
    onTriggered: {
      if (count++ >= 5) { stop(); return }
      Quickshell.execDetached(["pw-play", "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"])
    }
  }
}
