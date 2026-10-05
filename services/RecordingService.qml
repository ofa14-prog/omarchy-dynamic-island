import QtQuick
import Quickshell
import Quickshell.Io

// Screen recording started by Omarchy (gpu-screen-recorder), shown as the
// red recording activity iPhone users know. Stopping goes through Omarchy's
// own script so the file is finalized and its notification fires.
Item {
  id: rec

  property bool active: false
  property double startedAt: 0

  function stop() {
    Quickshell.execDetached(["omarchy-capture-screenrecording", "--stop-recording"])
  }

  Process {
    id: probe
    command: ["pgrep", "-f", "^gpu-screen-recorder"]
    onExited: (code, status) => {
      var now = code === 0
      if (now && !rec.active) rec.startedAt = Date.now()
      rec.active = now
    }
  }

  Timer {
    interval: 1500
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: if (!probe.running) probe.running = true
  }
}
