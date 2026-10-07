import QtQuick
import Quickshell
import Quickshell.Io

// How loud the music is right now, 0..1, from cava (the terminal audio
// visualizer, `pacman -S cava`), for the ambient glow to breathe with.
// cava runs only while `active` (something plays and the island is on
// screen) and reads PipeWire's output monitor, so it hears what you hear.
// Without cava, `available` stays false and the glow simply holds still.
Item {
  id: audio

  property bool active: false
  property bool available: false
  property real level: 0          // smoothed loudness, bass-weighted
  property real beat: 0           // short kick on sudden rises, decays fast
  property real peak: 0.3

  readonly property string configPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/dynamic-island/cava.conf"

  Process {
    running: true
    command: ["sh", "-c", "command -v cava"]
    onExited: code => audio.available = code === 0
  }

  // 12 bars, 0..100 each, one ASCII line per frame: "12;40;…;3;"
  Process {
    id: cava
    running: audio.active && audio.available
    command: ["sh", "-c", `
      mkdir -p "$(dirname "$1")"
      cat > "$1" <<'CONF'
[general]
bars = 12
framerate = 45
autosens = 1
lower_cutoff_freq = 40
higher_cutoff_freq = 10000
[input]
method = pipewire
source = auto
[output]
channels = mono
mono_option = average
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
frame_delimiter = 10
[smoothing]
noise_reduction = 55
CONF
      exec cava -p "$1"`, "sh", audio.configPath]
    stdout: SplitParser {
      onRead: line => audio.frame(line)
    }
    onRunningChanged: if (!running) { audio.level = 0; audio.beat = 0; audio.peak = 0.3 }
  }

  function frame(line) {
    var bars = line.split(";")
    var n = 0, bass = 0, all = 0
    for (var i = 0; i < bars.length; i++) {
      if (bars[i] === "") continue
      var v = Number(bars[i]) / 100
      if (n < 4) bass += v
      all += v
      n++
    }
    if (!n) return
    var raw = (bass / 4) * 0.65 + (all / n) * 0.35
    // Relative to the recent peak (falls back over ~10 s), so quiet and
    // loud songs both move through the whole range.
    peak = Math.max(raw, peak * 0.997, 0.08)
    var target = Math.min(1, raw / peak)
    // Quick to rise, slow to fall, like a VU meter.
    var next = target > level ? level + (target - level) * 0.55 : level + (target - level) * 0.12
    beat = Math.max(beat * 0.82, Math.max(0, target - level) * 2.2)
    level = next
  }
}
