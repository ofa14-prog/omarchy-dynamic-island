import QtQuick
import Quickshell
import Quickshell.Io
import "../components/Agents.js" as Agents

// Live model of every coding-agent session on the machine (Claude Code,
// Codex, Antigravity CLI via bin/dynamic-island-hook; OpenCode via its
// plugin), fed over a unix socket. Permission requests keep their connection
// open; answering writes the verdict back down that same connection.
// Antigravity has no permission event and ignores a hook's "allow": the
// island notices its prompt (see "Antigravity prompts" below) and answers it
// with a key press in agy's own terminal.
//
// ════════════════════════════════════════════════════════════════ STATES
//
//   ready        session open, no turn running (fresh start, /clear, resume,
//                after a manual /compact). Shown as "Idle".
//   thinking     a turn is running and the model is working
//   tool         a turn is running a tool (s.tool says which)
//   compacting   the context is being compacted
//   waiting      (derived) a permission request is open on the island
//   notice       the agent asked for permission in its own terminal and
//                cannot hand it to the island
//   input        the agent is waiting for you: a question, an MCP
//                elicitation, or "waiting for your input" after a while
//   done         the turn finished normally
//   interrupted  you stopped the turn (Esc, or rejected a permission in
//                the terminal)
//   error        the turn ended on an API error
//   quiet        a turn looked busy but showed no sign of life for
//                quietAfterMs: probably stopped in a way no agent reports
//
//   Busy (spinner, live activity): thinking, tool, compacting, waiting, notice
//   Needs you (live activity, pulsing dot): waiting, notice, input
//
// ══════════════════════════════════════════════════════════════ TRIGGERS
//
//   event                 sent by                 effect
//   ──────────────────────────────────────────────────────────────────────
//   SessionStart          Claude, Codex,          new session → ready.
//                         OpenCode                source "compact": stays as the
//                                                 compaction left it (see below)
//   UserPromptSubmit      all                     → thinking; starts the turn clock
//   PreToolUse            all                     → tool (s.tool, title, detail)
//   PostToolUse           all                     tool | notice | input → thinking
//   PostToolUseFailure    Claude                  is_interrupt → interrupted,
//                                                 else → thinking (tool failed)
//   PermissionRequest     Claude, Codex,          opens an island request
//                         OpenCode                (→ waiting). Answered here, or
//                                                 the connection closes when you
//                                                 answer in the terminal
//   PermissionResolved    OpenCode                closes the island request
//   PermissionDenied      Claude (auto mode)      → thinking (Claude carries on)
//   (agy prompt)          Antigravity             PreToolUse of a gated tool, no
//                                                 PostToolUse and no child process
//                                                 after ~1 s → key-press request
//                                                 (→ waiting)
//   Question              Claude                  → input with the question text
//                         (AskUserQuestion)
//   Notification          Claude                  idle_prompt / elicitation_dialog
//                                                 → input + banner; others ignored
//   Elicitation           Claude                  → input + banner
//   PreCompact            Claude, Codex           → compacting (remembers trigger)
//   PostCompact           Claude, Codex           manual → ready, auto → thinking
//   Stop                  all                     → done + "finished" banner
//   StopFailure           Claude                  → error + banner
//   Interrupt             Codex, Antigravity      → interrupted
//   SessionEnd            all                     session removed
//
//   Signals the agents never send, and how they are recovered:
//
//   Permission allowed in     Claude Code leaves the hook running. The request
//   the terminal              is settled by the next event that proves it was
//                             answered (PostToolUse/Failure of that tool, Stop,
//                             StopFailure, a new prompt) and the hook is told
//                             to step aside ("pass")
//   Esc while Claude writes   no event; Claude appends "[Request interrupted by
//                             user]" to the transcript → transcript watch
//                             → interrupted
//   Permission rejected in    the hook's connection closes and the transcript
//   the terminal              gets "[Request interrupted by user for tool use]"
//                             → interrupted (allowed: PostToolUse follows)
//   Esc before any output     nothing at all; after quietAfterMs without an
//                             event or transcript write → quiet
//   Terminal closed / crash   the agent process is gone → session removed
//
//   Ordering: hooks run as separate processes, so events can arrive out of
//   order. Each carries a microsecond timestamp; an older turn event never
//   rewinds a newer one (s.lastTs).
//
//   Headless runs (`claude -p`, SDK scripts) are ignored except for their
//   permission requests, which something is actually waiting on.
Item {
  id: bridge

  property string pluginDir: ""
  readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/dynamic-island"
  readonly property string socketPath: runtimeDir + "/agents.sock"
  readonly property string home: Quickshell.env("HOME") || ""
  property string defaultAgent: ""   // Omarchy's default agent id
  // Usage records written by Omarchy's agents panel (claude.json, codex.json…).
  // The agent whose usage is shown (the AI page's agent). Omarchy's agents
  // panel writes usage records for Claude and Codex; Antigravity's comes
  // from `agy -p /usage` (see below).
  property string usageAgent: ""
  readonly property string usageFor: usageAgent || defaultAgent || "claude"
  // Agents whose usage is wanted at once (Home shows every running agent).
  property var usageAgents: []
  readonly property var noUsage: ({ session: -1, weekly: -1, sessionResets: "", weeklyResets: "" })
  readonly property string usageDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/omarchy/agents/usage/"
  // agent id → { session, weekly, sessionResets, weeklyResets } (0..1 used)
  property var usageByAgent: ({})
  function usageOf(id) { return usageByAgent[id] || noUsage }
  function setUsage(id, u) {
    var next = {}
    for (var k in usageByAgent) next[k] = usageByAgent[k]
    next[id] = u
    usageByAgent = next
  }

  // A busy turn with no event and no transcript write for this long is shown
  // as "quiet". Long enough for a slow model to think without tools.
  property int quietAfterMs: 180000

  // Session objects are mutated in place, which QML cannot see. Every change
  // bumps `revision`, and every helper that reads a session's state touches
  // it, so bindings that call them (labels, spinners, the live activity)
  // re-evaluate on each event instead of keeping a stale state.
  property int revision: 0

  property var sessions: ({})
  property var sessionList: []
  property var pending: []          // oldest first
  property var sockets: ({})        // request id -> Socket
  readonly property var usage: usageOf(usageFor)

  readonly property bool listening: server.active
  readonly property var currentRequest: pending.length > 0 ? pending[0] : null
  readonly property var busySessions: sessionList.filter(s => isBusy(s))
  readonly property var attentionSessions: sessionList.filter(s => needsYou(s))
  readonly property bool busy: busySessions.length > 0 || pending.length > 0
  // The agent is a live activity while something runs or something needs you.
  readonly property bool live: busy || attentionSessions.length > 0
  // The session the compact island narrates: an open request first, then
  // whoever needs you, then the most recently active busy session, then the
  // most recent session at all.
  readonly property var focusSession: {
    if (currentRequest) return sessions[currentRequest.session] || null
    if (attentionSessions.length > 0) return attentionSessions[0]
    if (busySessions.length > 0) return busySessions[0]
    return sessionList.length > 0 ? sessionList[0] : null
  }

  signal permissionArrived(var request)
  signal permissionResolved(string requestId, string how)
  signal sessionFinished(var session)
  signal sessionFailed(var session)
  signal sessionNeedsInput(var session, string message)

  readonly property var busyStates: ["thinking", "tool", "compacting", "notice"]

  function isBusy(s) {
    void revision
    return !!s && (busyStates.indexOf(s.state) !== -1 || hasPending(s.id))
  }

  function needsYou(s) {
    void revision
    return !!s && (s.state === "input" || s.state === "notice" || hasPending(s.id))
  }

  function hasPending(sessionId) {
    for (var i = 0; i < pending.length; i++) if (pending[i].session === sessionId) return true
    return false
  }

  // How each state looks, for every view: label key (I18n), whether the
  // spinner runs, the end-of-turn icon, and its tone.
  readonly property var stateLook: ({
    ready:       { label: "Boşta",                     spin: false, icon: "",      tone: "dim" },
    thinking:    { label: "Düşünüyor…",                spin: true,  icon: "",      tone: "agent" },
    tool:        { label: "",                          spin: true,  icon: "",      tone: "agent" },
    compacting:  { label: "Sıkıştırıyor…",             spin: true,  icon: "",      tone: "agent" },
    waiting:     { label: "İzin gerekiyor",            spin: false, icon: "",      tone: "agent" },
    input:       { label: "Seni bekliyor",             spin: false, icon: "",      tone: "agent" },
    done:        { label: "Bitti",                     spin: false, icon: "check", tone: "green" },
    interrupted: { label: "Durduruldu",                spin: false, icon: "x",     tone: "dim" },
    error:       { label: "Hata",                      spin: false, icon: "x",     tone: "red" },
    quiet:       { label: "Sessiz · durmuş olabilir",  spin: false, icon: "",      tone: "dim" }
  })
  function look(s) { return stateLook[displayState(s)] || stateLook.ready }

  // What the views show. "notice" reads as waiting (answer in the terminal).
  function displayState(s) {
    void revision
    if (!s) return "ready"
    return hasPending(s.id) || s.state === "notice" ? "waiting" : s.state
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
        // The hook went away without our answer: you answered in the
        // terminal, or the agent gave up. See requestClosedElsewhere().
        if (!connected && requestId !== "") bridge.requestClosedElsewhere(requestId)
      }
    }
  }

  // ---------------------------------------------------------------- events

  function now() { return Date.now() }

  // Last events received, for `omarchy-shell dynamicisland events` when
  // something looks wrong. Kept small and in memory only.
  property var eventLog: []
  function logEvent(msg, note) {
    var s = sessions[msg.session]
    var entry = { at: now(), ts: msg.ts || 0, event: msg.event, session: (msg.session || "").substring(0, 8),
      agent: msg.agent || "", tool: msg.tool || "", entry: msg.entry || "", before: s ? s.state : "", note: note || "" }
    eventLog = eventLog.concat([entry]).slice(-80)
  }

  function sessionFor(msg) {
    var id = msg.session || "unknown"
    var s = sessions[id]
    if (!s && msg.agentPid) {
      // A placeholder from the scan (no id yet) for this same process.
      for (var k in sessions) {
        var o = sessions[k]
        if (o.agentPid === msg.agentPid && o.agent === msg.agent && /-\d+$/.test(k) && k !== id) {
          var next = {}
          for (var j in sessions) if (j !== k) next[j] = sessions[j]
          sessions = next
        }
      }
    }
    if (!s) {
      s = {
        id: id, agent: msg.agent || "", state: "ready", project: msg.project || "", cwd: msg.cwd || "",
        tool: "", title: "", detail: "", prompt: "", message: "", error: "",
        turnStartedAt: 0, updatedAt: now(), createdAt: now(), lastEventAt: now(), toolCount: 0,
        pids: [], agentPid: 0, mode: "", transcript: "", compactTrigger: "", lastTs: 0
      }
    }
    if (msg.project) s.project = msg.project
    if (msg.cwd) s.cwd = msg.cwd
    if (msg.pids && msg.pids.length) s.pids = msg.pids
    if (msg.agentPid) s.agentPid = msg.agentPid
    if (msg.mode) s.mode = msg.mode
    if (msg.entry) s.entry = msg.entry
    if (msg.transcript) s.transcript = msg.transcript
    s.updatedAt = now()
    s.lastEventAt = now()
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
    revision++
    var list = []
    for (var k in sessions) list.push(sessions[k])
    list.sort((a, b) => b.updatedAt - a.updatedAt)
    sessionList = list
  }

  function startTurn(s) {
    s.state = "thinking"
    s.turnStartedAt = now()
    s.toolCount = 0
    s.tool = ""; s.title = ""; s.detail = ""; s.message = ""; s.error = ""
  }

  function endTurn(s, state) {
    s.state = state
    s.finishedAt = now()
    s.lastDuration = s.turnStartedAt ? now() - s.turnStartedAt : 0
  }

  // Events that move a turn along; an older one never rewinds a newer one.
  readonly property var orderedEvents: ["UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure",
    "PermissionDenied", "PreCompact", "PostCompact", "Stop", "StopFailure", "Interrupt", "Question"]

  function receive(line, socket) {
    var msg
    try { msg = JSON.parse(line) } catch (e) { return }
    if (!msg || !msg.agent || !msg.event) return
    // Acknowledge fire-and-forget events so the hook hangs up only after we
    // have the line. Permission requests are answered with the verdict later.
    if (msg.event !== "PermissionRequest") { socket.write("ok\n"); socket.flush() }

    if (String(msg.entry || "").indexOf("sdk") === 0 && msg.event !== "PermissionRequest") {
      logEvent(msg, "headless, ignored")
      return
    }

    var ev = msg.event
    settleAnswered(msg)
    if (ev === "PermissionResolved") {
      logEvent(msg)
      dropRequest(msg.request, "elsewhere")
      return
    }
    if (ev === "SessionEnd") {
      logEvent(msg)
      removeSession(msg.session)
      return
    }

    var s = sessionFor(msg)
    var ts = Number(msg.ts) || 0
    if (orderedEvents.indexOf(ev) !== -1) {
      if (ts && s.lastTs && ts < s.lastTs) {
        logEvent(msg, "older than last event, skipped")
        commit(s)
        return
      }
      if (ts) s.lastTs = ts
    }
    logEvent(msg)

    switch (ev) {
    case "SessionStart":
      // `compact` arrives in the middle of a compaction: leave the state to
      // PreCompact/PostCompact. Anything else is a fresh, idle session
      // (unless an out-of-order turn event already got here first).
      if (msg.source === "compact") {
        if (s.state === "compacting") s.state = s.compactTrigger === "manual" ? "ready" : "thinking"
      } else if (!isBusy(s)) {
        s.state = "ready"
      }
      break

    case "UserPromptSubmit":
      startTurn(s)
      s.prompt = msg.prompt || ""
      break

    case "PreToolUse":
      s.state = "tool"
      s.tool = msg.tool || ""
      s.title = msg.title || ""
      s.detail = msg.detail || ""
      s.toolCount += 1
      if (!s.turnStartedAt) s.turnStartedAt = now()
      if (msg.agent === "antigravity") {
        // A new step means any earlier prompt of this session was answered.
        pending.filter(r => r.session === s.id && r.step !== msg.step).forEach(r => dropRequest(r.id, "elsewhere"))
        s.agyStep = msg.gated ? { step: msg.step, at: now(), quiet: 0 } : null
      }
      break

    case "PostToolUse":
      if (s.state === "tool" || s.state === "notice" || s.state === "input") s.state = "thinking"
      s.agyStep = null
      break

    case "PostToolUseFailure":
      if (msg.interrupt) endTurn(s, "interrupted")
      else if (s.state === "tool") s.state = "thinking"
      break

    case "PermissionDenied":
      // Auto mode turned a tool down; Claude keeps going.
      if (s.state === "tool") s.state = "thinking"
      break

    case "Interrupt":
      endTurn(s, "interrupted")
      break

    case "PermissionNotice":
      s.state = "notice"
      s.tool = msg.tool || s.tool
      s.title = msg.title || s.title
      s.message = msg.message || ""
      commit(s)
      sessionNeedsInput(s, s.message)
      return

    case "Question":
    case "Elicitation":
      s.state = "input"
      s.message = msg.message || ""
      commit(s)
      sessionNeedsInput(s, s.message)
      return

    case "Notification": {
      // Only "the agent is waiting for you" kinds deserve attention.
      // Permission prompts arrive as PermissionRequest; the rest
      // (auth_success, …) are not about you.
      var wantsYou = msg.kind === "idle_prompt" || msg.kind === "elicitation_dialog"
        || (msg.kind === "" && /waiting for your input/i.test(msg.message || ""))
      if (wantsYou && !hasPending(s.id) && busyStates.indexOf(s.state) === -1) {
        s.state = "input"
        s.message = msg.message || ""
        commit(s)
        sessionNeedsInput(s, s.message)
        return
      }
      break
    }

    case "PreCompact":
      s.compactTrigger = msg.trigger || ""
      s.state = "compacting"
      break

    case "PostCompact":
      // /compact by hand leaves Claude idle; an automatic one continues the turn.
      s.state = (msg.trigger || s.compactTrigger) === "manual" ? "ready" : "thinking"
      s.compactTrigger = ""
      break

    case "Stop":
      s.agyStep = null
      endTurn(s, "done")
      commit(s)
      sessionFinished(s)
      return

    case "StopFailure":
      endTurn(s, "error")
      s.error = msg.error || ""
      commit(s)
      sessionFailed(s)
      return

    case "PermissionRequest": {
      s.tool = msg.tool || s.tool
      s.title = msg.title || ""
      s.detail = msg.detail || ""
      var request = {
        id: msg.request || ("req-" + now()),
        agent: s.agent,
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
    }
    commit(s)
  }

  // behavior: "allow" | "always" | "deny"
  function respond(requestId, behavior, message) {
    var id = requestId || (currentRequest ? currentRequest.id : "")
    var keyReq = pending.find(r => r.id === id && r.via === "keys")
    if (keyReq) return answerWithKey(keyReq, behavior)
    var socket = sockets[id]
    if (!socket) return false
    var reply = { behavior: behavior }
    if (message) reply.message = message
    socket.requestId = ""   // our own answer, not a disconnect
    socket.write(JSON.stringify(reply) + "\n")
    socket.flush()
    var req = null
    for (var i = 0; i < pending.length; i++) if (pending[i].id === id) req = pending[i]
    if (req) logEvent({ event: "(answered " + behavior + " on island)", session: req.session, agent: req.agent, tool: req.tool })
    if (req && sessions[req.session]) {
      var s = sessions[req.session]
      // Allowed: the tool runs. Denied from the island: Claude is told why
      // and keeps going.
      s.state = behavior === "deny" ? "thinking" : "tool"
      s.updatedAt = now()
      commit(s)
    }
    dropRequest(id, behavior)
    return true
  }

  // ---------------------------------------------------------------- Antigravity prompts

  // agy asks before running a command or touching a file, but tells no hook
  // about it, and a hook's "allow" does not skip its prompt. Its own log
  // (the cli-*.log the agy process holds open) does say it:
  //   Surfacing tool confirmation: "RunCommand" at step N   → it is asking
  //   Responding to tool confirmation: … stepIdx=N …         → answered there
  //   Interrupt cleared pending tool confirmation / Cancelling conversation
  //                                                          → cancelled there
  // N is the stepIdx the hook reports. So while a gated step is open
  // (s.agyStep) or an island request is, the end of that log is read every
  // 400 ms. Without the log (another agy build), the fallback is: no
  // PostToolUse and no child process twice in a row (a running command is
  // always a child of agy). Answers are the prompt's own keys: 1 run,
  // 2 allow for this conversation, Esc cancel.
  readonly property var agyWatch: sessionList.filter(s => s.agent === "antigravity" && s.agentPid
    && ((s.agyStep && s.state === "tool") || hasPending(s.id)))
  Timer {
    interval: 400
    repeat: true
    running: bridge.agyWatch.length > 0
    onTriggered: {
      if (agyProbe.running) return
      var due = bridge.agyWatch.filter(s => bridge.hasPending(s.id) || bridge.now() - s.agyStep.at > 300)
      if (!due.length) return
      agyProbe.ids = due.map(s => s.id)
      // Per session: "<pid>\t<children>\t<last confirmation line>".
      agyProbe.command = ["sh", "-c",
        "for p; do log=$(ls -l /proc/$p/fd 2>/dev/null | grep -o '/[^ ]*/log/cli-[^ ]*[.]log' | head -n 1); " +
        "last=; [ -n \"$log\" ] && last=$(tail -c 16384 \"$log\" | grep -E 'Surfacing tool confirmation|Responding to tool confirmation|Interrupt cleared pending tool confirmation|Cancelling conversation' | tail -n 1); " +
        "printf '%s\\t%s\\t%s\\t%s\\n' \"$p\" \"$(pgrep -c -P \"$p\")\" \"${log:+log}\" \"$last\"; done", "sh"]
        .concat(due.map(s => String(s.agentPid)))
      agyProbe.running = true
    }
  }
  Process {
    id: agyProbe
    property var ids: []
    stdout: StdioCollector {
      onStreamFinished: {
        var byPid = {}
        text.split("\n").forEach(l => {
          var p = l.split("\t")
          if (p.length >= 4) byPid[p[0]] = { children: Number(p[1]) || 0, hasLog: p[2] === "log", last: p.slice(3).join("\t") }
        })
        agyProbe.ids.forEach(id => {
          var s = bridge.sessions[id]
          var info = s ? byPid[String(s.agentPid)] : null
          if (!s || !info) return
          var req = bridge.pending.find(r => r.session === id && r.via === "keys")
          if (info.hasLog) {
            var asking = info.last.match(/Surfacing tool confirmation: .* at step (\d+)/)
            var answered = info.last.indexOf("Responding to tool confirmation") !== -1
            var cancelled = info.last.indexOf("Interrupt cleared pending") !== -1 || info.last.indexOf("Cancelling conversation") !== -1
            if (asking && !req && s.agyStep && s.state === "tool" && String(asking[1]) === String(s.agyStep.step)) {
              bridge.openKeyRequest(s)
            } else if (req && answered) {
              bridge.logEvent({ event: "(request answered in terminal)", session: id, agent: s.agent, tool: req.tool }, "agy log")
              bridge.dropRequest(req.id, "elsewhere")
            } else if (req && cancelled) {
              bridge.logEvent({ event: "(request cancelled in terminal)", session: id, agent: s.agent, tool: req.tool }, "agy log")
              bridge.dropRequest(req.id, "elsewhere")
              s.agyStep = null
              bridge.setState(id, "interrupted", "agy: cancelled at its prompt")
            }
            return
          }
          // No log: infer from the process tree.
          if (req || !s.agyStep || s.state !== "tool") return
          if (info.children > 0) { s.agyStep.quiet = 0; return }
          s.agyStep.quiet += 1
          if (s.agyStep.quiet >= 3) bridge.openKeyRequest(s)
        })
      }
    }
  }

  function openKeyRequest(s) {
    var request = {
      id: "agy-" + s.id.substring(0, 8) + "-" + s.agyStep.step,
      agent: s.agent, session: s.id, project: s.project, cwd: s.cwd,
      tool: s.tool, title: s.title, detail: s.detail,
      canAlways: true, mode: "", at: now(),
      via: "keys", step: s.agyStep.step, pids: s.pids || []
    }
    logEvent({ event: "(agy prompt)", session: s.id, agent: s.agent, tool: s.tool }, "gated tool waiting, no child process")
    pending = pending.concat([request])
    commit(s)
    permissionArrived(request)
  }

  // Presses the prompt's key in agy's terminal (tmux in the background, or
  // its own window, matched exactly) via bin/dynamic-island-send --key.
  signal keyAnswerFailed(string sessionId)
  function answerWithKey(req, behavior) {
    if (keySender.running) return false
    var key = behavior === "allow" ? "1" : behavior === "always" ? "2" : "Escape"
    keySender.forId = req.session
    keySender.command = [pluginDir + "/bin/dynamic-island-send", "--key", key].concat((req.pids || []).map(String))
    keySender.running = true
    logEvent({ event: "(answered " + behavior + " on island)", session: req.session, agent: req.agent, tool: req.tool }, "key " + key)
    var s = sessions[req.session]
    if (s) {
      s.agyStep = null
      // Esc at agy's prompt cancels the whole turn and agy reports nothing
      // more ("Interrupted · What should Antigravity CLI do instead?").
      if (behavior === "deny") endTurn(s, "interrupted")
      else s.state = "tool"
      s.updatedAt = now()
      commit(s)
    }
    dropRequest(req.id, behavior)
    return true
  }
  Process {
    id: keySender
    property string forId: ""
    onExited: code => { if (code !== 0) bridge.keyAnswerFailed(forId) }
  }

  // An open island request whose prompt was evidently answered in the
  // terminal: the tool already ran or failed, the turn ended, or a new prompt
  // started. Close it and release the hook (it exits without a decision).
  readonly property var settlingEvents: ["PostToolUse", "PostToolUseFailure", "PermissionDenied",
    "Stop", "StopFailure", "UserPromptSubmit", "Interrupt"]
  function settleAnswered(msg) {
    if (settlingEvents.indexOf(msg.event) === -1) return
    var sameTool = msg.event === "PostToolUse" || msg.event === "PostToolUseFailure" || msg.event === "PermissionDenied"
    pending.filter(r => r.session === msg.session && (!sameTool || !msg.tool || r.tool === msg.tool)).forEach(r => {
      var socket = sockets[r.id]
      if (socket) {
        socket.requestId = ""
        socket.write(JSON.stringify({ behavior: "pass" }) + "\n")
        socket.flush()
      }
      logEvent({ event: "(request answered in terminal)", session: r.session, agent: r.agent, tool: r.tool }, "settled by " + msg.event)
      dropRequest(r.id, "elsewhere")
    })
  }

  // Answered in the terminal (or abandoned). Allowed → PostToolUse follows;
  // rejected → the transcript gets an interrupt marker. Look right away.
  function requestClosedElsewhere(requestId) {
    var req = null
    for (var i = 0; i < pending.length; i++) if (pending[i].id === requestId) req = pending[i]
    if (req) logEvent({ event: "(request closed by agent)", session: req.session, agent: req.agent, tool: req.tool })
    dropRequest(requestId, "elsewhere")
    if (req && sessions[req.session]) transcriptCheck.restart()
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

  // Forget every session and open request (the island's "refresh"). Hooks
  // still waiting on a request are released without a decision, so each
  // agent falls back to its own terminal prompt. Sessions reappear with
  // their next event.
  function reset() {
    pending.forEach(r => {
      var socket = sockets[r.id]
      if (socket) {
        socket.requestId = ""
        socket.write(JSON.stringify({ behavior: "pass" }) + "\n")
        socket.flush()
      }
    })
    pending = []
    sockets = ({})
    sessions = ({})
    sessionList = []
    logEvent({ event: "(reset)", session: "", agent: "" }, "refresh from the island")
    refreshInstalled()
  }

  function clearFinished() {
    var next = {}
    for (var k in sessions) if (isBusy(sessions[k]) || needsYou(sessions[k])) next[k] = sessions[k]
    sessions = next
    rebuild()
  }

  function setState(id, state, note) {
    var s = sessions[id]
    if (!s || s.state === state) return
    logEvent({ event: "(" + state + ")", session: id, agent: s.agent }, note)
    endTurn(s, state)
    s.updatedAt = now()
    commit(s)
  }

  // ---------------------------------------------------------------- transcript watch

  // Catches what no hook reports, by reading the end of the transcript:
  //   "[Request interrupted by user…]"  Esc while writing, or a permission
  //                                      rejected in the terminal → interrupted
  //   system "turn_duration"             the turn is over; if no Stop came
  //                                      within a few seconds → done
  //   nothing new for quietAfterMs       → quiet (Esc before any output
  //                                      leaves no trace at all)
  // Runs only while some session with a transcript is busy.

  // Reads the last turn's ending from transcript lines (oldest first).
  function transcriptEnding(lines, since) {
    var textOf = c => typeof c === "string" ? c : (Array.isArray(c) ? c.map(p => p && p.text ? p.text : "").join("") : "")
    var ended = 0, interrupted = 0
    for (var i = lines.length - 1; i >= 0; i--) {
      var e
      try { e = JSON.parse(lines[i]) } catch (err) { continue }   // partial first line
      // Only conversation entries matter; Claude Code interleaves many
      // bookkeeping types (snapshots, titles, modes, …) and adds new ones.
      if (!e || (e.type !== "user" && e.type !== "assistant" && e.type !== "system")) continue
      var at = Date.parse(e.timestamp || "") || 0
      if (at && at < since - 1000) break                            // previous turn
      if (e.type === "system" && e.subtype === "turn_duration") { ended = ended || at || 1; continue }
      if (e.type === "system") continue
      var content = e.message ? e.message.content : null
      if (e.type === "user" && textOf(content).indexOf("[Request interrupted by user") === 0) { interrupted = at || 1; break }
      break   // a prompt, an assistant message or a tool result: the turn's real content
    }
    return { ended: ended, interrupted: interrupted }
  }

  Process {
    id: transcriptProbe
    stdout: StdioCollector {
      onStreamFinished: {
        var blocks = text.split("\u001e")
        for (var b = 0; b < blocks.length; b++) {
          var lines = blocks[b].split("\n").filter(l => l !== "")
          if (lines.length < 1) continue
          var head = lines[0].split("\t")
          var s = bridge.sessions[head[0]]
          if (!s || !bridge.isBusy(s) || bridge.hasPending(s.id)) continue
          var mtime = Number(head[1]) * 1000
          var end = bridge.transcriptEnding(lines.slice(1), s.turnStartedAt)
          if (end.interrupted) {
            bridge.setState(s.id, "interrupted", "transcript: interrupted by user")
          } else if (end.ended && bridge.now() - end.ended > 3000) {
            // Stop normally lands first; this only catches a lost one.
            bridge.setState(s.id, "done", "transcript: turn ended without Stop")
          } else if (s.state !== "tool" && bridge.now() - Math.max(s.lastEventAt, mtime) > bridge.quietAfterMs) {
            // Tools may legitimately run for a long time; thinking may not.
            bridge.setState(s.id, "quiet", "no event or transcript write for " + Math.round(bridge.quietAfterMs / 1000) + "s")
          }
        }
      }
    }
  }

  Timer {
    id: transcriptCheck
    interval: 1500
    repeat: true
    running: bridge.busySessions.some(s => s.transcript)
    triggeredOnStart: true
    onTriggered: {
      if (transcriptProbe.running) return
      var watch = bridge.sessionList.filter(s => s.transcript && bridge.isBusy(s))
      if (!watch.length) return
      var args = []
      watch.forEach(s => { args.push(s.id); args.push(s.transcript) })
      // Per session: "id<TAB>mtime" then the last lines of the transcript,
      // blocks separated by an ASCII record separator.
      transcriptProbe.command = ["sh", "-c",
        "while [ $# -gt 1 ]; do if [ -f \"$2\" ]; then printf '%s\\t%s\\n' \"$1\" \"$(stat -c %Y \"$2\")\"; tail -c 32768 \"$2\" | tail -n 16; printf '\\036'; fi; shift 2; done",
        "sh"].concat(args)
      transcriptProbe.running = true
    }
  }

  // ---------------------------------------------------------------- live preview

  // The agent page's terminal-style feed: the last prompts, replies, tool
  // calls and their output, summarised from the session's transcript by
  // bin/dynamic-island-transcript. Claude Code and Codex only, the two that
  // hand their hooks a transcript path. It is read only while someone looks
  // at it (`previewId` is set by the agent page while it is open).
  readonly property var previewAgents: ["claude", "codex", "antigravity"]
  property string previewId: ""
  property var previewItems: []
  property string previewOf: ""        // session the items belong to
  property int previewCount: 40        // transcript items to fetch (scrollback)
  property int previewLines: 2         // output lines shown per tool result

  function canPreview(s) { return !!s && !!s.transcript && previewAgents.indexOf(s.agent) !== -1 }

  onPreviewIdChanged: {
    if (previewOf !== previewId) previewItems = []
    previewFeed.restart()
  }

  Process {
    id: previewProbe
    property string forId: ""
    stdout: StdioCollector {
      onStreamFinished: {
        if (previewProbe.forId !== bridge.previewId) return
        try {
          var items = JSON.parse(text)
          if (Array.isArray(items) && JSON.stringify(items) !== JSON.stringify(bridge.previewItems)) bridge.previewItems = items
          bridge.previewOf = previewProbe.forId
        } catch (e) {}
      }
    }
  }

  Timer {
    id: previewFeed
    interval: 1200
    repeat: true
    triggeredOnStart: true
    running: bridge.previewId !== ""
    onTriggered: {
      var s = bridge.sessions[bridge.previewId]
      if (!bridge.canPreview(s) || previewProbe.running) return
      previewProbe.forId = s.id
      previewProbe.command = [bridge.pluginDir + "/bin/dynamic-island-transcript", s.agent, s.transcript, String(bridge.previewCount), String(bridge.previewLines)]
      previewProbe.running = true
    }
  }

  // ---------------------------------------------------------------- actions

  function focusTerminal(session) {
    var s = session || focusSession
    var argv = [pluginDir + "/bin/dynamic-island-focus"]
    if (s && s.pids) for (var i = 0; i < s.pids.length; i++) argv.push(String(s.pids[i]))
    Quickshell.execDetached(argv)
  }

  // Types a message at the session's prompt (bin/dynamic-island-send): in
  // the background through tmux when the session runs there, otherwise by
  // focusing its terminal and typing. A busy Claude Code queues it for after
  // the current step. Not while a permission or question is open there: its
  // terminal shows a menu, and typing would pick from it.
  signal messageSent(string sessionId, bool ok)
  function canMessage(s) { return canPreview(s) && !hasPending(s.id) }
  function sendMessage(session, text) {
    var s = session || focusSession
    var line = String(text || "").replace(/\s*\n\s*/g, " ").trim()
    if (!canMessage(s) || !line || sender.running) return false
    // The text goes over stdin, never on a command line: process arguments
    // are visible to every local user.
    sender.forId = s.id
    sender.text = line.substring(0, 16000)
    sender.command = [pluginDir + "/bin/dynamic-island-send"].concat((s.pids || []).map(String))
    sender.stdinEnabled = true
    sender.running = true
    return true
  }
  Process {
    id: sender
    property string forId: ""
    property string text: ""
    onStarted: {
      write(text)
      text = ""
      stdinEnabled = false     // closes stdin: the helper sees end of input
    }
    onExited: code => bridge.messageSent(forId, code === 0)
  }

  function openInEditor(session) {
    var s = session || focusSession
    if (s && s.cwd) Quickshell.execDetached(["omarchy-launch-editor", s.cwd])
  }

  // Opens a new session of the island's agent: Omarchy's own launcher when it
  // is Omarchy's default agent, otherwise the same kind of terminal window
  // (in ~/Work when it exists, as Omarchy does).
  property string omarchyAgent: ""
  function newSession(agentId) {
    var id = agentId || defaultAgent || omarchyAgent
    var p = Agents.get(id)
    if (!id || id === omarchyAgent || !p.launch) { Quickshell.execDetached(["omarchy-agent", "--pick"]); return }
    Quickshell.execDetached(["sh", "-c", "[ -d \"$HOME/Work\" ] && cd \"$HOME/Work\"; exec omarchy-launch-tui --app-id=org.omarchy.agent \"$@\"", "sh"].concat(p.launch))
  }

  // ---------------------------------------------------------------- scan

  // Finds the agent sessions open right now (bin/dynamic-island-scan), for
  // when no hook has spoken yet: after a shell restart, or a session started
  // before the island. Run at start and from the AI page's refresh button.
  // Known sessions only get missing details; new ones come in idle (or
  // working, when Claude Code says it is busy). A session found without an
  // id ("agy-<pid>"…) is replaced by the real one at its first hook event.
  signal scanned(int found, int added)
  property bool scanning: scanner.running
  function scan() { if (!scanner.running) scanner.running = true }
  Process {
    id: scanner
    command: [bridge.pluginDir + "/bin/dynamic-island-scan"]
    stdout: StdioCollector {
      onStreamFinished: {
        var found = 0, added = 0
        text.split("\n").forEach(line => {
          var m
          try { m = JSON.parse(line) } catch (e) { return }
          if (!m || !m.session || !m.agent) return
          found++
          var known = bridge.sessions[m.session]
          var s = bridge.sessionFor({ session: m.session, agent: m.agent, cwd: m.cwd, project: m.project,
                                      pids: m.pids, agentPid: m.agentPid, transcript: m.transcript })
          if (!known) {
            added++
            if (m.busy) { bridge.startTurn(s) } else { s.state = "ready" }
            bridge.logEvent({ event: "(found by scan)", session: m.session, agent: m.agent })
          }
          bridge.commit(s)
        })
        bridge.scanned(found, added)
      }
    }
  }
  Timer { running: bridge.pluginDir !== ""; interval: 1500; onTriggered: bridge.scan() }

  // ---------------------------------------------------------------- liveness

  // A session whose agent process is gone (terminal closed, crash) never
  // sends SessionEnd. Sweep them out.
  Process {
    id: livenessCheck
    property var checked: []
    stdout: StdioCollector {
      onStreamFinished: {
        var dead = text.split("\n").filter(l => l !== "")
        for (var i = 0; i < livenessCheck.checked.length; i++) {
          var s = livenessCheck.checked[i]
          if (dead.indexOf(String(s.agentPid)) !== -1) bridge.removeSession(s.id)
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
      var withPid = bridge.sessionList.filter(s => s.agentPid > 0)
      if (withPid.length === 0 || livenessCheck.running) return
      livenessCheck.checked = withPid
      livenessCheck.command = ["sh", "-c", "for p; do [ -d /proc/$p ] || echo $p; done", "sh"].concat(withPid.map(s => String(s.agentPid)))
      livenessCheck.running = true
    }
  }

  // ---------------------------------------------------------------- setup

  // Which agents are wired to the island: { claude: true, codex: false, … }.
  property var installed: ({})
  readonly property bool hooksInstalled: installed[defaultAgent] === true
  Process {
    id: statusProbe
    command: [bridge.pluginDir + "/bin/dynamic-island-agent-setup", "--status"]
    running: bridge.pluginDir !== ""
    stdout: StdioCollector {
      onStreamFinished: { try { bridge.installed = JSON.parse(text) } catch (e) {} }
    }
  }
  Timer {
    interval: 30000
    repeat: true
    running: true
    onTriggered: bridge.refreshInstalled()
  }
  function refreshInstalled() { if (!statusProbe.running) statusProbe.running = true }

  function installHooks(agent) {
    installer.command = [pluginDir + "/bin/dynamic-island-agent-setup", agent || defaultAgent || "claude"]
    installer.running = true
  }
  Process {
    id: installer
    onExited: bridge.refreshInstalled()
  }

  function openUsage() {
    if (usageFor === "antigravity") { agyUsageRefresh(); return }
    Quickshell.execDetached(["omarchy-shell", "-q", "omarchy.agents", "open"])
  }

  // ---------------------------------------------------------------- usage

  // Omarchy's agents panel keeps a usage record per agent it knows
  // (claude.json, codex.json); each is watched.
  Instantiator {
    model: ["claude", "codex"]
    delegate: FileView {
      required property string modelData
      path: bridge.usageDir + modelData + ".json"
      watchChanges: true
      printErrors: false
      onFileChanged: reload()
      onLoadFailed: bridge.setUsage(modelData, bridge.noUsage)
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
          bridge.setUsage(modelData, out)
        } catch (e) {}
      }
    }
  }
  // ---- Antigravity: `agy -p /usage` prints one tab-separated line per
  // limit ("Gemini Models<TAB>Five Hour Limit Remaining<TAB>97%<TAB><reset>"),
  // locally, without a model call or a new conversation. The group shown is
  // the one of the model agy is set to (its settings.json), else the first.
  // Read while Antigravity's usage is on screen, every 5 minutes, and after
  // each of its turns.
  function agyUsageRefresh() { if (!agyUsageProbe.running) agyUsageProbe.running = true }
  Process {
    id: agyUsageProbe
    workingDirectory: bridge.home || "/tmp"
    command: ["sh", "-c", "command -v agy >/dev/null || exit 0; " +
      "m=$(sed -n 's/.*\"model\": *\"\\([^\"]*\\)\".*/\\1/p' \"$HOME/.gemini/antigravity-cli/settings.json\" 2>/dev/null | head -n 1); " +
      "printf 'model\\t%s\\n' \"$m\"; timeout 30 agy -p /usage 2>/dev/null | head -c 8192"]
    stdout: StdioCollector {
      onStreamFinished: {
        var model = "", rows = []
        text.split("\n").forEach(l => {
          var c = l.split("\t")
          if (c[0] === "model") model = (c[1] || "").toLowerCase()
          else if (c.length >= 4 && /\d+%/.test(c[2])) rows.push({ group: c[0], label: c[1].toLowerCase(), left: parseFloat(c[2]) / 100, reset: c[3] })
        })
        if (!rows.length) return
        var groups = rows.map(r => r.group).filter((g, i, a) => a.indexOf(g) === i)
        var group = groups.find(g => model && model.indexOf(g.split(" ")[0].toLowerCase()) !== -1) || groups[0]
        var out = { session: -1, weekly: -1, sessionResets: "", weeklyResets: "", group: group }
        rows.filter(r => r.group === group).forEach(r => {
          if (r.label.indexOf("five hour") !== -1 || r.label.indexOf("5") !== -1) { out.session = Math.max(0, 1 - r.left); out.sessionResets = r.reset }
          else if (r.label.indexOf("week") !== -1) { out.weekly = Math.max(0, 1 - r.left); out.weeklyResets = r.reset }
        })
        bridge.setUsage("antigravity", out)
      }
    }
  }
  Timer {
    interval: 300000
    repeat: true
    running: bridge.usageFor === "antigravity" || bridge.usageAgents.indexOf("antigravity") !== -1
    triggeredOnStart: true
    onTriggered: bridge.agyUsageRefresh()
  }
  onSessionFinished: session => { if (session && session.agent === "antigravity") agyUsageRefresh() }

}
