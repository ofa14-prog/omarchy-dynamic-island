import QtQuick
import Quickshell
import Quickshell.Io

// The user's default apps, resolved the same way Omarchy does, plus each
// app's own icon from the system icon theme. Launching always goes through
// Omarchy's launchers so the result matches the rest of the desktop.
Item {
  id: apps

  property string browserId: ""
  property string filesId: ""
  property string terminalId: ""
  property string editor: ""

  // Desktop entries load asynchronously; depending on the list makes every
  // lookup below re-run once it fills.
  readonly property var all: DesktopEntries.applications ? DesktopEntries.applications.values : []

  function entry(id, list) {
    if (!id || !list.length) return null
    var bare = id.replace(/\.desktop$/, "")
    return DesktopEntries.byId(bare) || DesktopEntries.heuristicLookup(bare)
  }

  // Editors are stored as a command (`code`, `zed`…); find the entry that runs it.
  function entryForCommand(cmd, list) {
    if (!cmd) return null
    for (var i = 0; i < list.length; i++) {
      var e = list[i]
      var argv = e.command || []
      var first = argv.length ? String(argv[0]) : ""
      if (first === cmd || first.endsWith("/" + cmd)) return e
    }
    return DesktopEntries.heuristicLookup(cmd)
  }

  function iconOf(e) {
    return e && e.icon ? Quickshell.iconPath(e.icon, true) : ""
  }

  readonly property var browserEntry: entry(browserId, all)
  readonly property var filesEntry: entry(filesId, all)
  readonly property var terminalEntry: entry(terminalId, all)
  readonly property var editorEntry: all.length ? entryForCommand(editor, all) : null

  readonly property string browserIcon: iconOf(browserEntry)
  readonly property string filesIcon: iconOf(filesEntry)
  readonly property string terminalIcon: iconOf(terminalEntry)
  readonly property string editorIcon: iconOf(editorEntry)
  readonly property string editorName: editorEntry ? editorEntry.name : (editor || "")

  function refresh() { if (!probe.running) probe.running = true }

  Process {
    id: probe
    running: true
    command: ["bash", "-c",
      "echo \"browser=$(xdg-settings get default-web-browser 2>/dev/null)\";" +
      "echo \"files=$(xdg-mime query default inode/directory 2>/dev/null)\";" +
      "t=$(xdg-terminal-exec --print-id 2>/dev/null); echo \"terminal=${t%%:*}\";" +
      "e=; f=\"${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/defaults/editor\"; [ -f \"$f\" ] && read -r e < \"$f\"; echo \"editor=${e:-nvim}\""]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var eq = lines[i].indexOf("=")
          if (eq < 0) continue
          var k = lines[i].substring(0, eq), v = lines[i].substring(eq + 1).trim()
          if (k === "browser") apps.browserId = v
          else if (k === "files") apps.filesId = v
          else if (k === "terminal") apps.terminalId = v
          else if (k === "editor") apps.editor = v.replace(/^.*\//, "")
        }
      }
    }
  }

  // Defaults change through Omarchy's menu; pick that up when the island opens.
  Timer {
    interval: 120000
    repeat: true
    running: true
    onTriggered: apps.refresh()
  }

  function openBrowser() { Quickshell.execDetached(["omarchy-launch-browser"]) }
  function openFiles(path) { Quickshell.execDetached(["xdg-open", path || Quickshell.env("HOME")]) }
  function openTerminal() { Quickshell.execDetached(["omarchy-launch-terminal"]) }
  function openEditor(path) {
    Quickshell.execDetached(path ? ["omarchy-launch-editor", path] : ["omarchy-launch-editor"])
  }
}
