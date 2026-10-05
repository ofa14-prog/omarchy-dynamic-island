import QtQuick
import Quickshell
import Quickshell.Io

// Live model of every Claude Code session on the machine, fed by
// bin/dynamic-island-hook over a unix socket. Permission requests keep their
// socket open; answering writes the verdict back down that same socket.
Item {
  id: bridge

  property string pluginDir: ""
  readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/dynamic-island"
  readonly property string socketPath: runtimeDir + "/claude.sock"
  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string usagePath: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/omarchy/agents/usage/claude.json"

  property var sessions: ({})
  property var sessionList: []
  property var pending: []          // oldest first
  property var sockets: ({})        // request id -> Socket
  property var usage: ({ session: -1, weekly: -1, sessionResets: "", weeklyResets: "" })

  readonly property bool listening: server.active
  readonly property var currentRequest: pending.length > 0 ? pending[0] : null
  readonly property var busySessions: sessionList.filter(s => isBusy(s))
  readonly property bool busy: busySessions.length > 0 || pending.length > 0
  // The session the compact island narrates: whoever needs you, else the most
  // recently active busy session, else the most recent one at all.
  readonly property var focusSession: {
    if (currentRequest) return sessions[currentRequest.session] || null
    if (busySessions.length > 0) return busySessions[0]
    return sessionList.length > 0 ? sessionList[0] : null
  }

  signal permissionArrived(var request)
  signal permissionResolved(string requestId, string how)
  signal sessionFinished(var session)
  signal sessionNeedsInput(var session, string message)

  function isBusy(s) {
    return s && (s.state === "thinking" || s.state === "tool" || s.state === "compacting" || hasPending(s.id))
  }

  function hasPending(sessionId) {
    for (var i = 0; i < pending.length; i++) if (pending[i].session === sessionId) return true
    return false
  }

  function displayState(s) {
    if (!s) return "ready"
    return hasPending(s.id) ? "waiting" : s.state
  }

  // ---------------------------------------------------------------- socket

  Process {
    id: prepare
    command: ["sh", "-c", "mkdir -p \"$1\" && chmod 700 \"$1\" && rm -f \"$2\"", "sh", bridge.runtimeDir, bridge.socketPath]
    running: true
    onExited: server.active = true
  }

  SocketServer {
    id: server
    active: false
    path: bridge.socketPath

    handler: Socket {
      id: connection
      property string requestId: ""

      parser: SplitParser {
        onRead: line => bridge.receive(line, connection)
      }
      onConnectedChanged: {
        // Hook killed (you answered in the terminal) or Claude gave up.
        if (!connected && requestId !== "") bridge.dropRequest(requestId, "elsewhere")
      }
    }
  }

  // ---------------------------------------------------------------- events

  function now() { return Date.now() }

  function sessionFor(msg) {
    var id = msg.session || "unknown"
    var s = sessions[id]
    if (!s) {
      s = {
        id: id, state: "ready", project: msg.project || "", cwd: msg.cwd || "",
        tool: "", title: "", detail: "", prompt: "", message: "",
        turnStartedAt: 0, updatedAt: now(), createdAt: now(), toolCount: 0,
        pids: [], claudePid: 0, mode: ""
      }
    }
    if (msg.project) s.project = msg.project
    if (msg.cwd) s.cwd = msg.cwd
    if (msg.pids && msg.pids.length) s.pids = msg.pids
    if (msg.claudePid) s.claudePid = msg.claudePid
    if (msg.mode) s.mode = msg.mode
    s.updatedAt = now()
    return s
  }

  function commit(s) {
    var next = {}
    for (var k in sessions) next[k] = sessions[k]
    if (s) next[s.id] = s
    sessions = next
    rebuild()
  }

  function rebuild() {
    var list = []
    for (var k in sessions) list.push(sessions[k])
    list.sort((a, b) => b.updatedAt - a.updatedAt)
    sessionList = list
  }

  function receive(line, socket) {
    var msg
    try { msg = JSON.parse(line) } catch (e) { return }
    if (!msg || msg.agent !== "claude") return
    // Acknowledge fire-and-forget events so the hook hangs up only after we
    // have the line. Permission requests are answered with the verdict later.
    if (msg.event !== "PermissionRequest") { socket.write("ok\n"); socket.flush() }

    var ev = msg.event
    if (ev === "SessionEnd") {
      removeSession(msg.session)
      return
    }

    var s = sessionFor(msg)
    // Async hooks can land out of order; a state event older than the last
    // one applied must not rewind the session (e.g. PostToolUse after the
    // next PreToolUse).
    var ts = Number(msg.ts) || 0
    var ordered = ["UserPromptSubmit", "PreToolUse", "PostToolUse", "PreCompact", "Stop"]
    if (ordered.indexOf(ev) !== -1) {
      if (ts && s.lastTs && ts < s.lastTs) { commit(s); return }
      if (ts) s.lastTs = ts
    }
    if (ev === "SessionStart") {
      if (s.state !== "thinking" && s.state !== "tool") s.state = "ready"
    } else if (ev === "UserPromptSubmit") {
      s.state = "thinking"
      s.prompt = msg.prompt || ""
      s.turnStartedAt = now()
      s.toolCount = 0
      s.tool = ""; s.title = ""; s.detail = ""
    } else if (ev === "PreToolUse") {
      s.state = "tool"
      s.tool = msg.tool || ""
      s.title = msg.title || ""
      s.detail = msg.detail || ""
      s.toolCount += 1
      if (!s.turnStartedAt) s.turnStartedAt = now()
    } else if (ev === "PostToolUse") {
      if (s.state === "tool") s.state = "thinking"
    } else if (ev === "PreCompact") {
      s.state = "compacting"
    } else if (ev === "Notification") {
      s.message = msg.message || ""
      // Permission prompts arrive as their own PermissionRequest event.
      if (msg.kind !== "permission_prompt" && !hasPending(s.id)) {
        if (s.state !== "thinking" && s.state !== "tool") s.state = "input"
        commit(s)
        sessionNeedsInput(s, s.message)
        return
      }
    } else if (ev === "Stop") {
      s.state = "done"
      s.finishedAt = now()
      s.lastDuration = s.turnStartedAt ? now() - s.turnStartedAt : 0
      commit(s)
      sessionFinished(s)
      return
    } else if (ev === "PermissionRequest") {
      s.tool = msg.tool || s.tool
      s.title = msg.title || ""
      s.detail = msg.detail || ""
      var request = {
        id: msg.request || ("req-" + now()),
        session: s.id,
        project: s.project,
        cwd: s.cwd,
        tool: msg.tool || "",
        title: msg.title || "",
        detail: msg.detail || "",
        canAlways: msg.canAlways === true,
        mode: msg.mode || "",
        at: now()
      }
      socket.requestId = request.id
      var socks = {}
      for (var k in sockets) socks[k] = sockets[k]
      socks[request.id] = socket
      sockets = socks
      pending = pending.concat([request])
      commit(s)
      permissionArrived(request)
      return
    }
    commit(s)
  }

  // behavior: "allow" | "always" | "deny"
  function respond(requestId, behavior, message) {
    var id = requestId || (currentRequest ? currentRequest.id : "")
    var socket = sockets[id]
    if (!socket) return false
    var reply = { behavior: behavior }
    if (message) reply.message = message
    socket.requestId = ""   // our own answer, not a disconnect
    socket.write(JSON.stringify(reply) + "\n")
    socket.flush()
    var req = null
    for (var i = 0; i < pending.length; i++) if (pending[i].id === id) req = pending[i]
    if (req && sessions[req.session]) {
      var s = sessions[req.session]
      s.state = behavior === "deny" ? "thinking" : "tool"
      s.updatedAt = now()
      commit(s)
    }
    dropRequest(id, behavior)
    return true
  }

  function dropRequest(requestId, how) {
    var next = pending.filter(r => r.id !== requestId)
    if (next.length === pending.length) return
    pending = next
    var socks = {}
    for (var k in sockets) if (k !== requestId) socks[k] = sockets[k]
    sockets = socks
    permissionResolved(requestId, how)
  }

  function removeSession(id) {
    if (!sessions[id]) return
    var next = {}
    for (var k in sessions) if (k !== id) next[k] = sessions[k]
    sessions = next
    pending.filter(r => r.session === id).forEach(r => dropRequest(r.id, "ended"))
    rebuild()
  }

  function clearFinished() {
    var next = {}
    for (var k in sessions) if (isBusy(sessions[k])) next[k] = sessions[k]
    sessions = next
    rebuild()
  }

  // ---------------------------------------------------------------- actions

  function focusTerminal(session) {
    var s = session || focusSession
    var argv = [pluginDir + "/bin/dynamic-island-focus"]
    if (s && s.pids) for (var i = 0; i < s.pids.length; i++) argv.push(String(s.pids[i]))
    Quickshell.execDetached(argv)
  }

  function openInEditor(session) {
    var s = session || focusSession
    if (s && s.cwd) Quickshell.execDetached(["omarchy-launch-editor", s.cwd])
  }

  function newSession() {
    Quickshell.execDetached(["omarchy-agent"])
  }

  // ---------------------------------------------------------------- liveness

  // A session whose claude process is gone (terminal closed, crash) never
  // sends SessionEnd. Sweep them out.
  Process {
    id: livenessCheck
    property var checked: []
    stdout: StdioCollector {
      onStreamFinished: {
        var dead = text.split("\n").filter(l => l !== "")
        for (var i = 0; i < livenessCheck.checked.length; i++) {
          var s = livenessCheck.checked[i]
          if (dead.indexOf(String(s.claudePid)) !== -1) bridge.removeSession(s.id)
        }
      }
    }
  }

  Timer {
    interval: 15000
    repeat: true
    running: bridge.sessionList.length > 0
    onTriggered: {
      var stale = Date.now() - 6 * 3600 * 1000
      bridge.sessionList.filter(s => s.updatedAt < stale && !bridge.isBusy(s)).forEach(s => bridge.removeSession(s.id))
      var withPid = bridge.sessionList.filter(s => s.claudePid > 0)
      if (withPid.length === 0 || livenessCheck.running) return
      livenessCheck.checked = withPid
      livenessCheck.command = ["sh", "-c", "for p; do [ -d /proc/$p ] || echo $p; done", "sh"].concat(withPid.map(s => String(s.claudePid)))
      livenessCheck.running = true
    }
  }

  // ---------------------------------------------------------------- setup

  property bool hooksInstalled: false
  FileView {
    path: (Quickshell.env("CLAUDE_CONFIG_DIR") || bridge.home + "/.claude") + "/settings.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: bridge.hooksInstalled = text().indexOf("dynamic-island-hook") !== -1
  }

  function installHooks() {
    Quickshell.execDetached([pluginDir + "/bin/dynamic-island-claude-setup"])
  }

  function openUsage() {
    Quickshell.execDetached(["omarchy-shell", "-q", "omarchy.agents", "open"])
  }

  // ---------------------------------------------------------------- usage

  FileView {
    path: bridge.usagePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var rec = JSON.parse(text())
        var out = { session: -1, weekly: -1, sessionResets: "", weeklyResets: "" }
        var limits = rec.limits || []
        for (var i = 0; i < limits.length; i++) {
          var l = limits[i]
          var label = String(l.label || "").toLowerCase()
          if (label.indexOf("session") !== -1 || label.indexOf("5-hour") !== -1) {
            out.session = Number(l.percent); out.sessionResets = l.resetsAt || ""
          } else if (label.indexOf("week") !== -1) {
            out.weekly = Number(l.percent); out.weeklyResets = l.resetsAt || ""
          }
        }
        bridge.usage = out
      } catch (e) {}
    }
  }
}
