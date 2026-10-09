import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.UPower
import "components"
import "services"
import "pages"
import "components/Agents.js" as Agents

// Dynamic Island for the Omarchy bar.
//
// One black shape, three sizes:
//   compact  – sits in the bar; idle clock or a live activity's leading/trailing
//   peek     – a brief wider banner (track change, agent finished, charging…)
//   expanded – the full card; pages for home, music, agent, timer and shelf
// Alerts (an agent permission request, a finished timer) expand on their own
// and hold the island open until answered.
//
// ═══════════════════════════════════════════════ WHAT THE ISLAND REACTS TO
//
//   trigger                                  island reaction
//   ──────────────────────────────────────────────────────────────────────
//   agent permission request                 opens on the permission page
//                                            (autoExpandPermission) or banner;
//                                            stays open until answered
//   permission answered on the island        closes + "Allowed" / "Denied" banner
//   permission answered in the terminal      closes quietly
//   agent turn finished (Stop)               "<agent> finished" banner
//                                            (peekOnAgentDone), ✓ in compact for 8 s
//   agent turn failed (StopFailure)          "<agent> stopped on an error" banner
//   agent waiting for you (question,         "<agent> is waiting for you" banner,
//   elicitation, idle prompt)                pulsing dot in compact until you act
//   Antigravity at its permission prompt     same as a permission request: the
//                                            island opens on it; answers are
//                                            pressed as keys in agy's terminal
//   agent turn interrupted / quiet           no banner; compact falls back
//   timer finished                           opens on the timer, shakes, chimes
//   new track (settled 1.5 s, playing)       banner (peekOnTrackChange)
//   charger plugged in (settled 1.5 s)       "Charging" banner
//   screen recording starts/stops            red activity appears/disappears
//   file dragged over the island             opens the shelf
//   message typed on the agent page          sent to the session's prompt
//                                            (tmux, or its terminal is focused
//                                            and typed into); banner after
//   music playing                            ambient glow in the artwork's
//                                            colors, moving with the sound
//                                            when cava is installed
//   shell (re)start                          hidden until the bar's size has
//                                            settled (it grows in steps),
//                                            then drops in as a circle and
//                                            springs open (intro)
//   files on the shelf                       shelf bubble (count + fill ring);
//                                            Ctrl+V on the open shelf shelves
//                                            the clipboard
//   pointer hover                            grows slightly (opens only with
//                                            hoverExpand); click opens
//   pointer leaves (opened by pointer)       closes after collapseDelay
//   permission / question / agent error      short horizontal shake (nudge)
//
//   Agent session states and the events behind them are documented in
//   services/AgentBridge.qml.
Item {
  id: island

  // Host injection (unused but accepted so the shell can hand them over).
  property var shell: null
  property var manifest: null
  property string omarchyPath: ""

  readonly property string pluginDir: {
    var u = String(Qt.resolvedUrl("."))
    return u.indexOf("file://") === 0 ? decodeURIComponent(u.substring(7)).replace(/\/$/, "") : u
  }
  readonly property string home: Quickshell.env("HOME") || ""

  // ================================================================ config

  readonly property var defaults: ({
    hoverExpand: false,     // true: also open on hover (default: hover only grows; click opens)
    hoverDelay: 380,
    collapseDelay: 650,
    reduceMotion: false,
    idleClock: true,
    clockFormat: "ddd d MMM  HH:mm",
    language: "en",         // en | es | ru | tr | auto (follow the system)
    locale: "",
    priority: ["agent", "recording", "timer", "music"],
    compactHeight: "auto",
    topOffset: "auto",
    expandedWidth: 500,
    color: "#000000",
    screen: "",
    peekOnTrackChange: true,
    peekOnAgentDone: true,
    autoExpandPermission: true,
    hideOnFullscreen: true,
    glass: true,            // Liquid Glass: translucent, blurred, light on the edges, liquid merges
    glassOpacity: 0.56,     // how dark the glass is (0..1)
    ambient: true,          // artwork-colored glow around the island while music plays
    ambientAudio: true,     // …breathing with the sound (needs cava)
    shortcuts: [],
    agent: "",
    agentQuietSeconds: 180
  })
  property var userConfig: ({})
  function cfg(key) { return userConfig[key] !== undefined ? userConfig[key] : defaults[key] }

  FileView {
    id: configFile
    path: island.home + "/.config/omarchy/dynamic-island.json"
    atomicWrites: true
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { island.userConfig = JSON.parse(text()) || {} } catch (e) { console.warn("dynamic-island: bad config", e) } }
    onLoadFailed: island.userConfig = ({})
  }

  Binding { target: Theme; property: "reduceMotion"; value: island.cfg("reduceMotion") === true }

  // English unless set; "auto" follows the system language when the island
  // has it (en, es, ru, tr) and falls back to English.
  readonly property string language: {
    var l = String(cfg("language") || "en")
    if (l === "auto") {
      var sys = (Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "").substring(0, 2)
      l = sys
    }
    return I18n.codes.indexOf(l) !== -1 ? l : "en"
  }
  Binding { target: I18n; property: "lang"; value: island.language }
  readonly property string localeName: cfg("locale") || I18n.localeFor(language)

  // Saves one setting to the user's config file (only on an explicit choice
  // in the UI, such as the language picker); every other key is kept.
  function setConfig(key, value) {
    var next = {}
    for (var k in userConfig) next[k] = userConfig[k]
    next[key] = value
    userConfig = next
    configFile.setText(JSON.stringify(next, null, 2) + "\n")
  }
  Binding { target: Theme; property: "bg"; value: island.cfg("color") }

  // Text follows the Omarchy system font (omarchy font set …).
  Process {
    id: fontProbe
    command: ["omarchy-font-current"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: { var f = text.trim(); if (f) Theme.font = f }
    }
  }

  // Omarchy's default agent, unless the island's own `agent` setting overrides it.
  property string omarchyAgent: ""
  readonly property string agentId: cfg("agent") || omarchyAgent
  FileView {
    path: island.home + "/.config/omarchy/defaults/agent"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: island.omarchyAgent = text().trim()
  }
  // ---- agents installed here (the ones the island connects to), for the
  // usage cards on Home.
  property var installedAgents: []
  Process {
    id: agentProbe
    running: true
    command: ["sh", "-c", "for a; do id=${a%%:*}; bin=${a#*:}; command -v \"$bin\" >/dev/null 2>&1 && echo \"$id\"; done", "sh"]
      .concat(Agents.connectable.map(id => id + ":" + Agents.get(id).bin))
    stdout: StdioCollector { onStreamFinished: island.installedAgents = text.split("\n").filter(l => l !== "") }
  }
  Timer { interval: 120000; repeat: true; running: true; onTriggered: if (!agentProbe.running) agentProbe.running = true }
  // Usage cards: running agents first (most urgent first), then the other
  // installed ones, then the island's own agent if it is neither.
  readonly property var usageAgents: {
    var out = runningAgents.slice()
    installedAgents.forEach(id => { if (out.indexOf(id) === -1) out.push(id) })
    if (agentId && out.indexOf(agentId) === -1) out.push(agentId)
    return out
  }

  // ---- agents that are running right now (a live session), most urgent
  // first: waiting on you, then working, then idle. They drive the AI tab's
  // label, the agent bar on its page and the split compact island.
  readonly property var runningAgents: {
    void agents.revision
    var rank = id => {
      var mine = agents.sessionList.filter(x => x.agent === id)
      if (agents.pending.some(r => r.agent === id) || mine.some(x => agents.needsYou(x))) return 0
      if (mine.some(x => agents.isBusy(x))) return 1
      return 2
    }
    var ids = []
    agents.sessionList.forEach(x => { if (x.agent && ids.indexOf(x.agent) === -1) ids.push(x.agent) })
    return ids.sort((a, b) => rank(a) - rank(b))
  }
  // Agents with a turn in progress (or waiting on you): two or more split
  // the compact island in half, one agent per side.
  readonly property var workingAgents: {
    void agents.revision
    return runningAgents.filter(id => agents.pending.some(r => r.agent === id)
      || agents.sessionList.some(x => x.agent === id && (agents.isBusy(x) || agents.needsYou(x))))
  }
  readonly property bool splitIsland: workingAgents.length >= 2 && primary === "agent"
  // Which agent sits on which half. An agent keeps its side for as long as
  // it works; a newcomer takes the free side. Never more than two.
  property var splitOrder: []
  onWorkingAgentsChanged: {
    var keep = splitOrder.filter(id => workingAgents.indexOf(id) !== -1)
    workingAgents.forEach(id => { if (keep.indexOf(id) === -1) keep.push(id) })
    keep = keep.slice(0, 2)
    if (JSON.stringify(keep) !== JSON.stringify(splitOrder)) splitOrder = keep
  }
  // The gap between the two halves springs open and closed; while it is
  // open the island is drawn as two pills (CompactView's halves) instead of
  // one shape. Only in compact: opening the island always starts whole.
  property real splitGap: splitIsland && mode === "compact" && introDone ? 8 : 0
  Behavior on splitGap {
    enabled: !Theme.reduceMotion
    SpringAnimation { spring: 4; damping: 0.38; epsilon: 0.05 }
  }
  readonly property bool halvesOn: mode === "compact" && (splitIsland || splitGap > 0.05)
  // The agent the AI page shows: the one picked in its bar while it still
  // runs, else the most urgent running one, else the island's agent.
  property string viewAgent: ""
  onModeChanged: {
    if (mode === "compact") viewAgent = ""
    glassModeMotion()
  }
  readonly property string pageAgent: viewAgent && runningAgents.indexOf(viewAgent) !== -1 ? viewAgent
    : runningAgents.length ? runningAgents[0] : agentId
  function showAgent(id) {
    viewAgent = id || ""
    openPage(agents.pending.some(r => r.agent === id) ? "permission" : "agent", "pointer")
  }

  // The agent Omarchy launches by default shapes the agent page: its name,
  // mark, colors and spinner. Sessions of other agents keep their own look.
  readonly property var agent: profile(agentId)
  readonly property string agentName: agentId ? agent.name : I18n.t("Ajan")
  readonly property string agentProduct: agentId ? agent.product : I18n.t("Ajan")
  readonly property color agentColor: agent.color
  readonly property string agentLogo: logoFor(agentId || "claude")
  // Profile with real colors (Agents.js stores them as strings).
  function profile(id) {
    var p = Agents.get(id || agentId || "claude")
    var out = {}
    for (var k in p) out[k] = p[k]
    out.color = Qt.lighter(p.color, 1.0)
    out.glow = Qt.lighter(p.glow, 1.0)
    return out
  }
  function logoFor(id) {
    var p = Agents.get(id)
    return p.logo ? Qt.resolvedUrl("icons/brand/" + p.logo + ".svg") : ""
  }

  readonly property var editorLabels: ({
    code: "Code", cursor: "Cursor", zed: "Zed", sublime_text: "Sublime", nvim: "Neovim",
    vim: "Vim", helix: "Helix", hx: "Helix", emacs: "Emacs"
  })

  // Built-in shortcuts follow the system defaults (agent, editor, browser,
  // file manager, terminal) and show each app's own icon. `shortcuts` in the
  // config replaces them.
  // ---- bar center
  // The island sits over the middle of the bar. Omarchy's stock layout keeps
  // widgets there (clock, indicators, weather…), so the Home page offers to
  // move them to the right (bin/dynamic-island-bar-setup: `omarchy bar move`,
  // backed up, `--undo` restores). Nothing moves until that button is pressed.
  // It is designed with the Islands bar (lobo.islands); on another bar the
  // same card offers that setup ("--recommended"), which the user can undo.
  property int barCenterCount: 0
  property string activeBar: ""
  readonly property bool onIslandsBar: activeBar === "lobo.islands"
  readonly property bool barHint: activeBar !== "" && (!onIslandsBar || barCenterCount > 0)
    && cfg("barHintDismissed") !== true
  Process {
    id: barCenterProbe
    running: true
    command: ["sh", "-c",
      "f=\"$HOME/.config/omarchy/shell.json\"; [ -f \"$f\" ] || f=\"${OMARCHY_PATH:-/usr/share/omarchy}/config/omarchy/shell.json\"; " +
      "printf '%s\\n' \"$(jq -r '.bar.layout.center | length' \"$f\" 2>/dev/null)\"; " +
      "omarchy plugin list --json 2>/dev/null | jq -r '[.[] | select(.enabled and ((.kinds // []) | index(\"bar\")))][0].id // \"\"' | head -c 256"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.split("\n")
        island.barCenterCount = parseInt(lines[0]) || 0
        island.activeBar = (lines[1] || "").trim()
      }
    }
  }
  Process {
    id: barSetup
    onExited: barCenterProbe.running = true
  }
  function makeRoomInBar() {
    if (barSetup.running) return
    barSetup.command = [pluginDir + "/bin/dynamic-island-bar-setup"].concat(onIslandsBar ? [] : ["--recommended"])
    barSetup.running = true
  }

  readonly property var shortcuts: {
    var list = cfg("shortcuts")
    if (list && list.length) return list
    return [
      { action: "agent", label: agentName, image: agentLogo, icon: "sparkles" },
      { action: "editor", label: editorLabels[apps.editor] || apps.editorName, image: apps.editorIcon, icon: "code" },
      { action: "browser", label: I18n.t("Tarayıcı"), image: apps.browserIcon, icon: "globe" },
      { action: "files", label: I18n.t("Dosyalar"), image: apps.filesIcon, icon: "folder" },
      { action: "terminal", label: I18n.t("Terminal"), image: apps.terminalIcon, icon: "terminal" },
      { action: "screenshot", label: I18n.t("Ekran"), icon: "camera" }
    ]
  }

  // Models hand nested arrays to JS as list wrappers, not Arrays; copy.
  function argv(value) {
    if (!value) return []
    if (typeof value === "string") return ["sh", "-c", value]
    var out = []
    for (var i = 0; i < value.length; i++) out.push(String(value[i]))
    return out
  }

  // A second click on the same shortcut while its app is still starting
  // would open it twice: ignore repeats for a moment.
  property string lastShortcut: ""
  property double lastShortcutAt: 0

  function runShortcut(item) {
    if (!item) return
    var action = item.action || ""
    var key = action + "|" + (item.label || "")
    if (key === lastShortcut && Date.now() - lastShortcutAt < 2000) return
    lastShortcut = key
    lastShortcutAt = Date.now()
    if (action === "stopwatch") { timer.startStopwatch(); openPage("timer"); return }
    if (action === "timer") { timer.startCountdown(Number(item.seconds) || 300); openPage("timer"); return }
    if (action.indexOf("page:") === 0) { openPage(action.substring(5)); return }
    if (action === "agent") agents.newSession()
    else if (action === "editor") apps.openEditor()
    else if (action === "browser") apps.openBrowser()
    else if (action === "files") apps.openFiles()
    else if (action === "terminal") apps.openTerminal()
    else if (action === "screenshot") Quickshell.execDetached(["omarchy-capture-screenshot"])
    else {
      var cmd = argv(item.command)
      if (!cmd.length) { console.warn("dynamic-island: shortcut has no action or command:", JSON.stringify(item)); return }
      Quickshell.execDetached(cmd)
    }
    collapse()
    // Apps take a second or two to show up; say it's coming.
    if (action !== "screenshot")
      peek(item.image ? "app:" + item.image : (item.icon || "arrow-up-right"), I18n.t("Açılıyor"), item.label || "", Theme.fg, 1600)
  }

  // ================================================================ services

  AgentBridge {
    id: agentsSvc
    pluginDir: island.pluginDir
    defaultAgent: island.agentId
    omarchyAgent: island.omarchyAgent
    usageAgent: island.pageAgent
    usageAgents: island.usageAgents
    quietAfterMs: Math.max(20, Number(island.cfg("agentQuietSeconds")) || 180) * 1000
    onPermissionArrived: request => {
      if (island.cfg("autoExpandPermission")) {
        island.openPage("permission", "alert")
        island.nudge()
      } else {
        island.peek("agent:" + request.agent, I18n.t("%1 izin istiyor").arg(island.profile(request.agent).name), request.project + " · " + request.tool, island.profile(request.agent).color, 3500)
        island.nudge()
      }
    }
    onPermissionResolved: (requestId, how) => {
      if (pending.length > 0) return
      if (island.page === "permission") {
        island.collapse()
        if (how === "allow" || how === "always") island.peek("check", I18n.t("İzin verildi"), "", Theme.green, 1300)
        else if (how === "deny") island.peek("x", I18n.t("Reddedildi"), "", Theme.red, 1300)
      }
    }
    onSessionFailed: s => {
      if (island.mode !== "expanded") {
        island.peek("agent:" + s.agent, I18n.t("%1 bir hatayla durdu").arg(island.profile(s.agent).name), s.project + (s.error ? " · " + s.error : ""), Theme.red, 3600, "agent")
        island.nudge()
      }
    }
    onSessionFinished: s => {
      if (island.cfg("peekOnAgentDone") !== false && island.cfg("peekOnClaudeDone") !== false && island.mode !== "expanded")
        island.peek("agent:" + s.agent, I18n.t("%1 bitirdi").arg(island.profile(s.agent).name), s.project + (s.lastDuration ? " · " + island.duration(s.lastDuration) : ""), island.profile(s.agent).color, 2600, "agent")
    }
    onSessionNeedsInput: (s, message) => {
      if (island.mode === "expanded") return
      var title = (s.state === "notice" ? I18n.t("%1 izin istiyor") : message ? I18n.t("%1 soruyor") : I18n.t("%1 seni bekliyor")).arg(island.profile(s.agent).name)
      var detail = s.state === "notice" ? (s.title || s.project) : (message || s.project)
      island.peek("agent:" + s.agent, title, detail, island.profile(s.agent).color, 4000, "agent")
      island.nudge()
    }
  }

  MusicService {
    id: musicSvc
    tracking: island.mode === "expanded" && island.page === "music"
    onTrackChanged: {
      if (island.cfg("peekOnTrackChange") && island.mode === "compact" && island.primary === "music")
        island.peek("music", music.title, music.artist, Theme.fg, 2400, "music")
    }
  }

  TimerService {
    id: timerSvc
    onFinished: {
      island.openPage("timer", "alert")
      island.shake()
      Quickshell.execDetached(["notify-send", "-a", "Dynamic Island", "-i", "alarm-symbolic", I18n.t("Süre doldu"), timer.label || I18n.t("Zamanlayıcı bitti")])
    }
  }

  Connections {
    target: agentsSvc
    function onMessageSent(sessionId, ok) {
      var s = agentsSvc.sessions[sessionId]
      var name = s ? (s.project || island.profile(s.agent).name) : ""
      if (ok) island.peek("agent:" + (s ? s.agent : island.agentId), I18n.t("Mesaj gönderildi"), name, Theme.green, 1500)
      else island.peek("terminal", I18n.t("Gönderilemedi"), I18n.t("Oturumun terminal penceresi bulunamadı"), Theme.red, 2600)
    }
  }

  ShelfService {
    id: shelfSvc
    onPasted: (added, what) => {
      if (added > 0) {
        island.bounce()
        island.peek("shelf", what === "image" ? I18n.t("Görsel rafa eklendi") : what === "text" ? I18n.t("Metin rafa eklendi")
          : added === 1 ? I18n.t("Rafa eklendi") : I18n.t("%1 dosya rafa eklendi").arg(added),
          I18n.t("Rafta: %1").arg(I18n.count(shelfSvc.count, "item")), Theme.blue, 1600, "shelf")
      } else if (what === "known") {
        island.peek("shelf", I18n.t("Zaten rafta"), "", Theme.secondary, 1300, "shelf")
      } else {
        island.openPage("shelf", "pointer")
      }
    }
  }
  DefaultApps { id: appsSvc }
  RecordingService { id: recordingSvc }
  AudioLevel {
    id: audioSvc
    active: island.ambientOn && island.cfg("ambientAudio") && !Theme.reduceMotion
  }
  readonly property alias audio: audioSvc
  readonly property bool ambientOn: cfg("ambient") && musicLive && !fullscreenHidden

  readonly property alias agents: agentsSvc
  readonly property alias music: musicSvc
  readonly property alias timer: timerSvc
  readonly property alias shelf: shelfSvc
  readonly property alias apps: appsSvc
  readonly property alias recording: recordingSvc

  // Charging peek, the same moment iOS shows the green battery.
  readonly property var battery: UPower.displayDevice
  readonly property bool hasBattery: battery && battery.isLaptopBattery
  readonly property real batteryPercent: hasBattery ? (battery.percentage <= 1 ? battery.percentage * 100 : battery.percentage) : 0
  property bool lastOnBattery: true
  // Debounced: a loose cable or a dock can flap the power state.
  Connections {
    target: UPower
    function onOnBatteryChanged() { chargeSettle.restart() }
  }
  Timer {
    id: chargeSettle
    interval: 1500
    onTriggered: {
      if (!island.hasBattery) return
      if (!UPower.onBattery && island.lastOnBattery)
        island.peek("battery-charge", I18n.t("Şarj oluyor"), Math.round(island.batteryPercent) + "%", Theme.green, 2200)
      island.lastOnBattery = UPower.onBattery
    }
  }
  Component.onCompleted: lastOnBattery = UPower.onBattery

  // ================================================================ clock

  property double nowMs: Date.now()
  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: island.nowMs = Date.now()
  }
  readonly property string clockText: Qt.locale(localeName).toString(new Date(nowMs), cfg("clockFormat"))

  function duration(ms) {
    var s = Math.max(0, Math.floor(ms / 1000))
    if (s < 60) return s + I18n.t(" sn")
    var m = Math.floor(s / 60)
    if (m < 60) return m + ":" + ((s % 60) < 10 ? "0" : "") + (s % 60)
    return Math.floor(m / 60) + I18n.t(" sa ") + (m % 60) + I18n.t(" dk")
  }

  // ================================================================ activities

  // Music is a live activity only while it plays: pausing or closing the
  // player removes it from the island at once.
  readonly property bool musicLive: music.available && music.playing
  readonly property var live: {
    // "claude" is the pre-1.1 name of the agent activity.
    var order = (cfg("priority") || []).map(k => k === "claude" ? "agent" : k)
    var out = []
    for (var i = 0; i < order.length; i++) {
      var k = order[i]
      if (k === "agent" && (agents.live || recentlyFinished)) out.push(k)
      else if (k === "timer" && timer.active) out.push(k)
      else if (k === "music" && musicLive) out.push(k)
      else if (k === "recording" && recording.active) out.push(k)
      else if (k === "shelf" && shelf.count > 0) out.push(k)
    }
    // Activities missing from a user's custom priority still show, last.
    var all = ["agent", "recording", "timer", "music", "shelf"]
    for (var j = 0; j < all.length; j++) {
      var a = all[j]
      if (out.indexOf(a) !== -1 || order.indexOf(a) !== -1) continue
      if ((a === "agent" && (agents.live || recentlyFinished)) || (a === "timer" && timer.active)
          || (a === "music" && musicLive) || (a === "recording" && recording.active)
          || (a === "shelf" && shelf.count > 0)) out.push(a)
    }
    return out
  }
  // A finished agent turn lingers in compact for a moment with a checkmark.
  // A turn that just ended (done, stopped or failed) lingers in compact for a
  // moment so you see how it ended.
  readonly property bool recentlyFinished: agents.revision >= 0 && agents.focusSession !== null
    && ["done", "interrupted", "error"].indexOf(agents.focusSession.state) !== -1
    && nowMs - (agents.focusSession.finishedAt || 0) < 8000
  // ---- slots: [center pill, right bubble, left bubble]
  // By default activities fill the slots in priority order. Double-clicking
  // a bubble swaps it with the center, and that arrangement is kept: an
  // activity that ends just leaves its slot (the others close up), a new one
  // takes the next free slot. Once nothing is live the arrangement resets.
  property var arrangement: []
  // The shelf is a side bubble: alone, it leaves the center to the clock
  // ("idle") unless you double-click it into the middle.
  readonly property var slots: {
    var out = arrangement.filter(k => live.indexOf(k) !== -1)
    for (var i = 0; i < live.length; i++) if (out.indexOf(live[i]) === -1) out.push(live[i])
    if (out.length === 1 && out[0] === "shelf" && arrangement[0] !== "shelf") out.unshift("idle")
    return out
  }
  onLiveChanged: if (live.length === 0 && arrangement.length) arrangement = []

  function swapToCenter(kind) {
    var s = slots.slice()
    var i = s.indexOf(kind)
    if (i <= 0) return
    s[i] = s[0]
    s[0] = kind
    arrangement = s
  }

  readonly property string primary: slots.length ? slots[0] : "idle"
  readonly property string secondary: slots.length > 1 && slots[1] !== "idle" ? slots[1] : ""
  readonly property string tertiary: slots.length > 2 && slots[2] !== "idle" ? slots[2] : ""

  // ================================================================ state

  property string mode: "compact"      // compact | peek | expanded
  property string page: "home"
  property string openedBy: "pointer"  // pointer | key | alert
  property bool pointerVisited: false
  property bool dragHover: false
  readonly property bool alertActive: agents.pending.length > 0 || timer.ringing
  property bool feedExpanded: false    // the agent page's live feed, taller
  property bool composing: false       // a message is being typed on the agent page
  readonly property bool locked: (page === "permission" && agents.pending.length > 0) || (page === "timer" && timer.ringing) || dragHover || composing

  readonly property var pages: {
    var list = ["home"]
    if (music.available) list.push("music")
    list.push("agent", "timer", "shelf")
    return list
  }

  function defaultPage() {
    if (agents.pending.length > 0) return "permission"
    if (timer.ringing) return "timer"
    return primary === "idle" || primary === "recording" ? "home" : primary
  }

  // -1 / +1 while switching tabs in the open island (pages slide), 0 when the
  // island itself opens (pages blur-morph). Set before `page` changes so the
  // outgoing and incoming page agree on it.
  property int pageSlide: 0
  function setPage(name) {
    if (!name || name === page) return
    var from = pages.indexOf(page), to = pages.indexOf(name)
    pageSlide = mode === "expanded" && from !== -1 && to !== -1 ? (to > from ? 1 : -1) : 0
    springMode = "resize"
    page = name
  }

  function openPage(name, by) {
    peekTimer.stop()
    if (name === "claude") name = "agent"
    if (name === "permission" && agents.pending.length === 0) name = "agent"
    name = name || defaultPage()
    if (mode === "expanded") { setPage(name); openedBy = by || openedBy; focusScope.forceActiveFocus(); return }
    pageSlide = 0
    page = name
    openedBy = by || "pointer"
    pointerVisited = hover.hovered
    springMode = "open"
    mode = "expanded"
    collapseTimer.stop()
    focusScope.forceActiveFocus()
  }

  // ---- refresh
  // Quick: clears stuck agent sessions and requests, alerts, banners and
  // motion, and returns to compact. Nothing else on the desktop is touched.
  function resetIsland() {
    agents.reset()
    timer.dismissRing()
    peekTimer.stop()
    hoverTimer.stop()
    collapseTimer.stop()
    shakeAnim.stop(); shakeX = 0
    bounceAnim.stop(); bounceY = 0
    arrangement = []
    dragHover = false
    springMode = "close"
    pageSlide = 0
    page = "home"
    mode = "compact"
    peek("restart", I18n.t("Ada yenilendi"), "", Theme.green, 1500)
  }

  // Full: restarts the whole Omarchy shell (bar included), which reloads the
  // island from disk; it then drops back in (intro). Uses Omarchy's own
  // `omarchy-restart-shell`, in its own session so it outlives the shell it
  // restarts.
  function restartShell() {
    Quickshell.execDetached(["setsid", "omarchy-restart-shell"])
  }

  function toggle() {
    if (mode === "expanded") collapse()
    else openPage(defaultPage(), "key")
  }

  function collapse() {
    if (mode === "compact") return
    springMode = "close"
    pageSlide = 0
    mode = "compact"
    collapseTimer.stop()
  }

  function cyclePage(delta) {
    if (page === "permission") return
    var i = pages.indexOf(page)
    if (i === -1) i = 0
    setPage(pages[(i + delta + pages.length) % pages.length])
  }

  // ---- peek
  property var peekData: ({ icon: "", title: "", subtitle: "", tint: "#ffffff", target: "" })
  function peek(icon, title, subtitle, tint, ms, target) {
    if (mode === "expanded" || !introDone) return
    peekData = { icon: icon, title: title || "", subtitle: subtitle || "", tint: tint || Theme.fg, target: target || "" }
    springMode = "open"
    mode = "peek"
    peekTimer.interval = ms || 2200
    peekTimer.restart()
  }
  Timer {
    id: peekTimer
    onTriggered: if (island.mode === "peek" && !hover.hovered) island.collapse(); else if (island.mode === "peek") restart()
  }

  // ---- motion helpers
  property string springMode: "open"     // open | close | resize
  readonly property real springK: springMode === "open" ? Theme.openSpring : springMode === "close" ? Theme.closeSpring : Theme.resizeSpring
  readonly property real springD: springMode === "open" ? Theme.openDamping : springMode === "close" ? Theme.closeDamping : Theme.resizeDamping
  property real shakeX: 0
  function shake() {
    if (Theme.reduceMotion) return
    shakeAnim.restart()
  }
  SequentialAnimation {
    id: shakeAnim
    NumberAnimation { target: island; property: "shakeX"; to: -11; duration: 55; easing.type: Easing.OutSine }
    NumberAnimation { target: island; property: "shakeX"; to: 10; duration: 80; easing.type: Easing.InOutSine }
    NumberAnimation { target: island; property: "shakeX"; to: -8; duration: 75; easing.type: Easing.InOutSine }
    NumberAnimation { target: island; property: "shakeX"; to: 6; duration: 70; easing.type: Easing.InOutSine }
    NumberAnimation { target: island; property: "shakeX"; to: -3; duration: 65; easing.type: Easing.InOutSine }
    NumberAnimation { target: island; property: "shakeX"; to: 0; duration: 60; easing.type: Easing.OutSine }
  }

  // A notification that wants you (a permission, a question, an error): a
  // short, light side-to-side shake, like a notification on iPhone. Lighter
  // and quicker than shake(), which says "no".
  function nudge() {
    if (Theme.reduceMotion) return
    nudgeStart.restart()
  }
  // Starts once the banner has begun to open, so the shake reads on it.
  Timer { id: nudgeStart; interval: 140; onTriggered: nudgeAnim.restart() }
  SequentialAnimation {
    id: nudgeAnim
    NumberAnimation { target: island; property: "shakeX"; to: -6; duration: 50; easing.type: Easing.OutSine }
    NumberAnimation { target: island; property: "shakeX"; to: 5; duration: 70; easing.type: Easing.InOutSine }
    NumberAnimation { target: island; property: "shakeX"; to: -3; duration: 65; easing.type: Easing.InOutSine }
    NumberAnimation { target: island; property: "shakeX"; to: 0; duration: 60; easing.type: Easing.OutSine }
  }

  // A soft vertical "drop" for alerts: the shape dips and springs back.
  property real bounceY: 0
  function bounce() {
    if (Theme.reduceMotion) return
    bounceAnim.restart()
  }
  SequentialAnimation {
    id: bounceAnim
    NumberAnimation { target: island; property: "bounceY"; to: 4; duration: 110; easing.type: Easing.OutQuad }
    SpringAnimation { target: island; property: "bounceY"; to: 0; spring: 5; damping: 0.22; epsilon: 0.05 }
  }

  // ================================================================ geometry

  // ---- fit the bar in use. Measured from the bar's layer surface so the
  // island lines up with the stock 26 px bar, floating island bars, or any
  // replacement bar, unless compactHeight / topOffset are set explicitly.
  property var barGeom: null    // { y, h } of a top bar on the island's monitor
  property int barStable: 0     // probes in a row that saw the same size
  property bool barSettled: false
  Process {
    id: barProbe
    property string monitor: ""
    command: ["hyprctl", "layers", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          var found = null
          for (var mon in data) {
            if (barProbe.monitor && mon !== barProbe.monitor) continue
            var levels = data[mon].levels || {}
            for (var lv in levels) {
              var list = levels[lv]
              for (var i = 0; i < list.length; i++) {
                var l = list[i]
                if (l.namespace === "omarchy-bar" && l.w > l.h && l.y <= 4) found = { y: l.y, h: l.h }
              }
            }
          }
          // A bar that is reloading is briefly missing: keep the last fit
          // rather than snapping to the fallback size.
          if (!found) return
          // A freshly started bar grows in steps (26 → 30 → its real size,
          // over about half a second): only call it settled once the same
          // size comes back three times in a row.
          var same = island.barGeom && island.barGeom.y === found.y && island.barGeom.h === found.h
          island.barStable = same ? island.barStable + 1 : 0
          if (!same) island.barGeom = found
          if (island.barStable >= 2) island.barSettled = true
        } catch (e) {}
      }
    }
  }
  Timer {
    // Right after a shell (re)start the bar may not exist yet: look again
    // quickly until it does, then only now and then.
    interval: island.barSettled ? 10000 : 250
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      barProbe.monitor = window.screen ? window.screen.name : ""
      if (!barProbe.running) barProbe.running = true
    }
  }

  readonly property int compactH: {
    var v = cfg("compactHeight")
    if (typeof v === "number" && v > 0) return v
    if (!barGeom) return 34
    // Floating "island" bars leave a gap above their pills: match the pill.
    // Slim bars (Omarchy's stock bar is 26–30 px): a little air above and
    // below so the island floats in the bar instead of filling it.
    return barGeom.h >= 40 ? Math.min(38, barGeom.h - 7) : Math.max(22, barGeom.h - 4)
  }
  readonly property int topY: {
    var v = cfg("topOffset")
    if (typeof v === "number" && v >= 0) return v
    if (!barGeom) return 6
    return barGeom.h >= 40 ? barGeom.y + barGeom.h - compactH - 1
      : barGeom.y + Math.max(0, Math.round((barGeom.h - compactH) / 2))
  }
  // ---- Liquid Glass
  // The island is a translucent glass body (components/LiquidGlass.qml) on
  // a backdrop blur only behind its own layer (bin/dynamic-island-glass,
  // runtime only, undone with "glass": false or Hyprland's reload). It moves
  // like liquid: the glass flexes ("jelly") on opening, closing and touch,
  // lights up when touched ("energy"), and its specular edge follows the
  // pointer.
  readonly property bool glassOn: cfg("glass") !== false
  onGlassOnChanged: glassSetup.run()
  QtObject {
    id: glassSetup
    function run() {
      blurProc.command = [island.pluginDir + "/bin/dynamic-island-glass", island.glassOn ? "on" : "off"]
      blurProc.running = true
    }
  }
  Process { id: blurProc }
  Timer { running: true; interval: 50; onTriggered: glassSetup.run() }
  // Hyprland reloads its config (and drops runtime rules) on every save.
  Connections {
    target: Hyprland
    function onRawEvent(event) { if (event.name === "configreloaded" && island.glassOn) glassSetup.run() }
  }

  property real jelly: 0
  function wobble(amount) {
    if (!glassOn || Theme.reduceMotion) return
    jellyAnim.amount = amount
    jellyAnim.restart()
  }
  SequentialAnimation {
    id: jellyAnim
    property real amount: 0
    NumberAnimation { target: island; property: "jelly"; to: jellyAnim.amount; duration: 110; easing.type: Easing.OutQuad }
    SpringAnimation { target: island; property: "jelly"; to: 0; spring: 2.6; damping: 0.16; epsilon: 0.0005 }
  }
  // The pointer's pull on the glass. Its position trails the pointer on a
  // soft spring (liquid lag) and its strength fades in and out, so leaving
  // lets the glass flow back.
  property real pullX: 0
  property real pullY: 0
  property real pullAmp: 0
  // Stiff and quick: it answers the pointer at once, with just enough
  // trail to read as liquid. Rises in 90 ms; lets go a little softer.
  Behavior on pullX { enabled: !Theme.reduceMotion; SpringAnimation { spring: 16; damping: 0.75; epsilon: 0.1 } }
  Behavior on pullY { enabled: !Theme.reduceMotion; SpringAnimation { spring: 16; damping: 0.75; epsilon: 0.1 } }
  Behavior on pullAmp {
    enabled: !Theme.reduceMotion
    NumberAnimation { duration: island.pullAmp > 0.1 && !hover.hovered ? 260 : 90; easing.type: Easing.OutCubic }
  }
  property real glassEnergy: 0
  function flash() {
    if (!glassOn || Theme.reduceMotion) return
    flashAnim.restart()
  }
  SequentialAnimation {
    id: flashAnim
    NumberAnimation { target: island; property: "glassEnergy"; to: 1; duration: 90; easing.type: Easing.OutQuad }
    NumberAnimation { target: island; property: "glassEnergy"; to: 0; duration: 520; easing.type: Easing.OutCubic }
  }
  function glassModeMotion() {
    if (mode === "expanded") { wobble(0.035); flash() }
    else if (mode === "peek") wobble(0.03)
    else wobble(-0.025)
  }
  onSplitIslandChanged: wobble(splitIsland ? 0.03 : -0.02)
  // The light: from the top-left at rest; toward the pointer over the
  // island, so the edge highlight slides around as you move.
  property real lightX: -0.55
  property real lightY: -0.83
  Behavior on lightX { SpringAnimation { spring: 3; damping: 0.5; epsilon: 0.002 } }
  Behavior on lightY { SpringAnimation { spring: 3; damping: 0.5; epsilon: 0.002 } }
  readonly property point glassLight: {
    var l = Math.sqrt(lightX * lightX + lightY * lightY) || 1
    return Qt.point(lightX / l, lightY / l)
  }

  // ---- intro
  // The island stays hidden until it knows where the bar is (so it never
  // shows at a wrong, squashed size), then drops in from above the screen as
  // a small circle and springs open into the island.
  //   hidden → drop (circle falls into place) → done (morphs to full width)
  readonly property bool geometryKnown: barSettled
    || (typeof cfg("compactHeight") === "number" && typeof cfg("topOffset") === "number")
  property string intro: "hidden"
  readonly property bool introDone: intro === "done"
  property real introY: 0
  onGeometryKnownChanged: if (geometryKnown) introStart.restart()
  Timer {
    // Bar never found or never still (none, or a different one): start anyway.
    interval: 4000
    running: island.intro === "hidden"
    onTriggered: introStart.restart()
  }
  Timer {
    id: introStart
    interval: 120          // let the size settle on the measured bar first
    onTriggered: {
      if (island.intro !== "hidden") return
      if (Theme.reduceMotion) { island.intro = "done"; return }
      introDrop.from = -(island.topY + island.compactH + 16)
      island.intro = "drop"
      introDrop.restart()
    }
  }
  SequentialAnimation {
    id: introDrop
    property real from: -60
    SpringAnimation { target: island; property: "introY"; from: introDrop.from; to: 0; spring: 3.2; damping: 0.32; epsilon: 0.2 }
    PauseAnimation { duration: 60 }
    ScriptAction { script: island.intro = "done" }
  }

  readonly property int expandedW: cfg("expandedWidth")
  readonly property bool hovered: hover.hovered
  // Split in two, each half reacts on its own: no whole-island grow or lean;
  // the half under the pointer lights up and hovering opens its agent.
  readonly property int hoveredHalf: halvesOn && hovered ? (hover.point.position.x < stage.width / 2 ? 0 : 1) : -1
  readonly property string hoveredAgent: hoveredHalf >= 0 ? (splitOrder[hoveredHalf] || "") : ""
  readonly property int hoverGrowW: mode === "compact" && hovered && !halvesOn ? 12 : 0
  readonly property int hoverGrowH: mode === "compact" && hovered && !halvesOn ? 2 : 0

  readonly property int idleW: cfg("idleClock") ? Math.max(130, Math.ceil(clockMetrics.advanceWidth) + 44) : 130
  readonly property int liveW: {
    if (splitIsland) return 352
    if (primary === "agent") return 300
    if (primary === "timer") return 236
    if (primary === "music") return 268
    if (primary === "recording") return 210
    return idleW
  }

  readonly property int expandedChromeH: page === "permission" ? 0 : 52
  readonly property int pageH: pageStack.currentHeight
  readonly property int targetW: !introDone ? compactH
    : mode === "expanded" ? expandedW
    : mode === "peek" ? Math.min(expandedW, Math.max(320, Math.ceil(peekMetrics.advanceWidth) + 130))
    : liveW + hoverGrowW
  readonly property int targetH: !introDone ? compactH
    : mode === "expanded" ? expandedChromeH + pageH + 16
    : mode === "peek" ? 64
    : compactH + hoverGrowH
  readonly property real targetR: !introDone ? compactH / 2
    : mode === "expanded" ? 34 : mode === "peek" ? 32 : (compactH + hoverGrowH) / 2

  TextMetrics {
    id: clockMetrics
    font.family: Theme.font
    font.pixelSize: 14
    font.weight: Font.DemiBold
    text: island.clockText
  }
  TextMetrics {
    id: peekMetrics
    font.family: Theme.font
    font.pixelSize: 15
    font.weight: Font.DemiBold
    text: island.peekData.title.length > island.peekData.subtitle.length ? island.peekData.title : island.peekData.subtitle
  }

  // ================================================================ timers

  Timer {
    id: hoverTimer
    interval: island.cfg("hoverDelay")
    onTriggered: {
      if (!hover.hovered || island.mode === "expanded") return
      // Over one half of a split island: that half's agent.
      if (island.hoveredAgent) island.showAgent(island.hoveredAgent)
      else island.openPage(island.defaultPage(), "pointer")
    }
  }

  Timer {
    id: collapseTimer
    interval: island.cfg("collapseDelay")
    onTriggered: if (!hover.hovered && !island.locked && island.mode === "expanded") island.collapse()
  }

  onHoveredChanged: {
    if (hovered) {
      pointerVisited = true
      collapseTimer.stop()
      if (mode !== "expanded" && cfg("hoverExpand")) hoverTimer.restart()
    } else {
      hoverTimer.stop()
      if (mode === "expanded" && !locked && (openedBy === "pointer" || pointerVisited)) collapseTimer.restart()
    }
  }
  onLockedChanged: if (!locked && mode === "expanded" && !hovered && pointerVisited) collapseTimer.restart()

  // ================================================================ fullscreen

  readonly property var focusedMonitor: Hyprland.focusedMonitor
  readonly property bool fullscreenHidden: cfg("hideOnFullscreen") && !alertActive && mode === "compact"
    && focusedMonitor && focusedMonitor.activeWorkspace && focusedMonitor.activeWorkspace.hasFullscreen === true

  // ================================================================ IPC

  IpcHandler {
    target: "dynamicisland"
    function toggle(): string { island.toggle(); return "ok" }
    function reset(): string { island.resetIsland(); return "ok" }
    function restartShell(): string { island.restartShell(); return "ok" }
    function open(page: string): string { island.openPage(page || island.defaultPage(), "key"); return "ok" }
    function close(): string { island.collapse(); return "ok" }
    function approve(): string { return island.agents.respond("", "allow") ? "ok" : "no-request" }
    function always(): string { return island.agents.respond("", "always") ? "ok" : "no-request" }
    function deny(): string { return island.agents.respond("", "deny") ? "ok" : "no-request" }
    function timer(seconds: string): string { island.timer.startCountdown(Number(seconds) || 300); island.peek("timer", I18n.t("Zamanlayıcı"), island.timer.display, Theme.orange, 1600); return "ok" }
    function stopwatch(): string { island.timer.startStopwatch(); return "ok" }
    function timerStop(): string { island.timer.cancel(); return "ok" }
    function shelfAdd(path: string): string { return island.shelf.addUrls([path]) > 0 ? "ok" : "invalid" }
    function notify(title: string, subtitle: string): string { island.peek("bell", title, subtitle, Theme.fg, 3000); return "ok" }
    function shortcut(index: string): string { island.runShortcut(island.shortcuts[Number(index)]); return "ok" }
    function events(): string {
      var out = []
      var log = island.agents.eventLog
      for (var i = 0; i < log.length; i++) {
        var e = log[i], s = island.agents.sessions[Object.keys(island.agents.sessions).filter(k => k.indexOf(e.session) === 0)[0]]
        out.push(new Date(e.at).toISOString().substring(11, 23) + " " + e.agent + " " + e.session + " " + e.event + (e.tool ? "(" + e.tool + ")" : "") + " entry=" + e.entry + " ts=" + e.ts + " was=" + e.before + (e.note ? "  ← " + e.note : ""))
      }
      return out.join("\n")
    }
    function sessions(): string {
      return JSON.stringify(island.agents.sessionList.map(s => ({ id: s.id.substring(0, 8), agent: s.agent, state: island.agents.displayState(s), tool: s.tool, project: s.project, lastTs: s.lastTs, transcript: s.transcript, turnStartedAt: s.turnStartedAt })))
    }
    function status(): string {
      return JSON.stringify({ agent: island.agentId, mode: island.mode, page: island.page, primary: island.primary, secondary: island.secondary, tertiary: island.tertiary,
        pending: agents.pending.length, sessions: agents.sessionList.length, listening: agents.listening,
        running: island.runningAgents, working: island.workingAgents, split: island.splitIsland, pageAgent: island.pageAgent,
        usage: island.agents.usage,
        ambient: island.ambientOn, audio: island.audio.active ? Math.round(island.audio.level * 100) / 100 : -1 })
    }
  }

  // ================================================================ window

  PanelWindow {
    id: window

    screen: {
      var want = island.cfg("screen") || (island.focusedMonitor ? island.focusedMonitor.name : "")
      var screens = Quickshell.screens
      for (var i = 0; i < screens.length; i++) if (screens[i].name === want) return screens[i]
      return screens.length ? screens[0] : null
    }
    anchors { top: true; left: true; right: true }
    // Tall enough for the biggest page (the agent page with its feed
    // expanded); the surface is transparent and clicks pass through.
    implicitHeight: 720
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "dynamic-island"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: island.mode === "expanded" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Only the island (and its bubble) take input; everything else on this
    // full-width surface clicks straight through to the bar and windows.
    mask: Region {
      item: island.fullscreenHidden ? null : maskItem
      Region { item: island.fullscreenHidden || !rightBubble.shown ? null : rightHit }
      Region { item: island.fullscreenHidden || !leftBubble.shown ? null : leftHit }
    }

    FocusScope {
      id: focusScope
      anchors.fill: parent
      focus: true

      Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
          if (island.page === "permission" && agents.currentRequest) agents.respond("", "deny")
          else if (island.page === "timer" && timer.ringing) timer.dismissRing()
          else island.collapse()
          event.accepted = true
        } else if (island.page === "permission" && agents.currentRequest) {
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Y) {
            agents.respond("", "allow"); event.accepted = true
          } else if (event.key === Qt.Key_A && agents.currentRequest.canAlways) {
            agents.respond("", "always"); event.accepted = true
          } else if (event.key === Qt.Key_N) {
            agents.respond("", "deny"); event.accepted = true
          } else if (event.key === Qt.Key_T) {
            agents.focusTerminal(agents.sessions[agents.currentRequest.session]); event.accepted = true
          }
        } else if (island.mode === "expanded" && (event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Tab) {
          island.cyclePage(1); event.accepted = true
        } else if (island.mode === "expanded" && event.key === Qt.Key_BracketRight) {
          island.cyclePage(1); event.accepted = true
        } else if (island.mode === "expanded" && event.key === Qt.Key_BracketLeft) {
          island.cyclePage(-1); event.accepted = true
        } else if (island.page === "shelf" && island.mode === "expanded" && (event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
          // Ctrl+V on the open shelf: what you copied goes on it.
          island.shelf.addFromClipboard(); event.accepted = true
        } else if (island.page === "music" && event.key === Qt.Key_Space && island.mode === "expanded") {
          music.togglePlaying(); event.accepted = true
        }
      }

      // ------------------------------------------------------------ shape

      Item {
        id: stage
        width: shape.width
        height: shape.height
        x: Math.round((parent.width - width) / 2 + island.shakeX + leanX)
        y: Math.round(island.topY + island.bounceY + island.introY)
        opacity: island.fullscreenHidden || island.intro === "hidden" ? 0 : 1
        scale: (island.fullscreenHidden ? 0.6 : 1) * pressScale
        transformOrigin: Item.Top

        property real leanX: 0
        property real pressScale: 1

        Behavior on opacity { NumberAnimation { duration: Theme.ms(220) } }
        Behavior on scale {
          enabled: !Theme.reduceMotion
          SpringAnimation { spring: Theme.snapSpring; damping: Theme.snapDamping; epsilon: 0.002 }
        }
        Behavior on leanX {
          enabled: !Theme.reduceMotion
          SpringAnimation { spring: 3; damping: 0.4; epsilon: 0.05 }
        }

        // The glass's light leans toward the pointer while it is over the
        // island (from the top-left otherwise).
        Binding {
          target: island
          property: "lightX"
          value: hover.hovered ? (hover.point.position.x - stage.width / 2) / Math.max(1, stage.width / 2) * 0.9 - 0.2 : -0.55
        }
        Binding {
          target: island
          property: "lightY"
          value: hover.hovered ? (hover.point.position.y - stage.height / 2) / Math.max(1, stage.height / 2) * 0.7 - 0.6 : -0.83
        }

        // The glass reaches for the pointer (compact, glass on).
        Binding {
          target: island
          property: "pullAmp"
          value: island.glassOn && island.mode === "compact" && hover.hovered && !Theme.reduceMotion ? 5 : 0
        }
        Binding {
          target: island
          property: "pullX"
          when: hover.hovered
          value: hover.point.position.x / Math.max(0.01, stage.scale)
        }
        Binding {
          target: island
          property: "pullY"
          when: hover.hovered
          value: hover.point.position.y / Math.max(0.01, stage.scale)
        }

        // The pointer gently pulls the compact island toward itself.
        Binding {
          target: stage
          property: "leanX"
          // Measured against where the island rests (position + leanX), not
          // where it has leaned to, or each lean moves the pointer's
          // relative position and leans it again: that was the jitter.
          // Under glass the glass itself reaches for the pointer instead.
          value: island.mode === "compact" && hover.hovered && !island.halvesOn && !island.glassOn
            ? Math.max(-1, Math.min(1, (hover.point.position.x + stage.leanX - stage.width / 2) / (stage.width / 2))) * 3.5
            : 0
        }

        // Ambient light, like YouTube's ambient mode: the artwork's colors
        // glow softly out of the island's edges while music plays (left and
        // right take the two most vivid colors) and breathe with the sound
        // when cava is installed. Kept small: a halo, not a lamp.
        Item {
          id: ambient
          anchors.fill: shape
          // Only around the player: the island glows when music is the
          // activity in the middle (or the open music page); when music sits
          // in a bubble, that bubble glows instead (pages/Bubble.qml).
          readonly property bool here: island.mode === "expanded" ? island.page === "music"
            : island.mode === "compact" && island.primary === "music"
          // Open on the music page, the light moves inside the card instead
          // (musicBackdrop below), so the outer glow steps aside.
          opacity: island.ambientOn && here && island.mode !== "expanded" ? 1 : 0
          visible: opacity > 0.01
          Behavior on opacity { NumberAnimation { duration: Theme.ms(900); easing.type: Easing.InOutQuad } }

          // A backlight: wide and faint, starting just inside the edge so it
          // seems to come from behind the island, and swelling softly with
          // the sound (no flashes).
          readonly property bool moving: island.audio.available && island.audio.active
          readonly property real level: moving ? island.audio.level : 0.45
          readonly property real strength: 0.26 + level * 0.3
          property color leftColor: island.music.ambient[0]
          property color rightColor: island.music.ambient[1]
          Behavior on leftColor { ColorAnimation { duration: 1500 } }
          Behavior on rightColor { ColorAnimation { duration: 1500 } }

          RectangularShadow {
            x: 0
            width: Math.round(parent.width * 0.7)
            height: parent.height
            radius: shape.radius
            blur: 24 + ambient.level * 10
            spread: -2 + ambient.level * 3
            color: Qt.rgba(ambient.leftColor.r, ambient.leftColor.g, ambient.leftColor.b, ambient.strength)
          }
          RectangularShadow {
            x: Math.round(parent.width * 0.3)
            width: parent.width - x
            height: parent.height
            radius: shape.radius
            blur: 24 + ambient.level * 10
            spread: -2 + ambient.level * 3
            color: Qt.rgba(ambient.rightColor.r, ambient.rightColor.g, ambient.rightColor.b, ambient.strength)
          }
        }

        // Soft drop shadow, only once the island leaves the bar.
        RectangularShadow {
          anchors.fill: shape
          radius: shape.radius
          blur: 28
          spread: 0
          offset.y: 8
          // Under glass a dark shadow would show through: kept light, and
          // below the blur threshold so it is never frosted.
          color: Qt.rgba(0, 0, 0, island.glassOn ? 0.28 : 0.55)
          opacity: island.mode === "compact" ? 0 : 1
          Behavior on opacity { NumberAnimation { duration: Theme.ms(260) } }
        }

        // ---- Liquid Glass surface (the glass bodies of the island, its
        // halves and the bubbles, in one liquid field). Spans the bubbles'
        // reach on both sides; coordinates are the stage's own.
        LiquidGlass {
          id: liquid
          visible: island.glassOn
          readonly property real s: Math.max(0.01, stage.scale)
          x: -padX
          y: -12
          width: shape.width + padX * 2
          height: shape.height + 80
          readonly property real padX: Math.max(80, island.compactH * 2 + 40)
          // Jelly: the glass stretches and settles on its own while the
          // content stays put.
          readonly property real jw: shape.width * island.jelly
          readonly property real jh: -shape.height * island.jelly * 0.55
          function box(x, y, w, h) { return Qt.vector4d(x + padX - jw / 2, y + 12 - jh / 2, w + jw, h + jh) }
          rectA: island.halvesOn ? box(0, 0, (shape.width - island.splitGap) / 2, shape.height)
                                 : box(0, 0, shape.width, shape.height)
          radA: {
            var r = shape.radius, h = shape.height / 2, inner = Math.min(h, island.splitGap * 2.2)
            return island.halvesOn ? Qt.vector4d(inner, inner, h, h) : Qt.vector4d(r, r, r, r)
          }
          rectB: island.halvesOn ? box(shape.width - (shape.width - island.splitGap) / 2, 0, (shape.width - island.splitGap) / 2, shape.height)
                                 : Qt.vector4d(0, 0, 0, 0)
          radB: {
            var h = shape.height / 2, inner = Math.min(h, island.splitGap * 2.2)
            return Qt.vector4d(h, h, inner, inner)
          }
          function bubbleAt(b) {
            void b.x; void b.y; void b.bodyScale; void b.opacity; void stage.x; void stage.y; void stage.scale
            if (!b.visible || b.opacity < 0.02) return Qt.vector4d(0, 0, 0, 0)
            var c = stage.mapFromItem(b, b.width / 2, b.height / 2)
            var r = b.width / 2 * b.bodyScale * Math.min(1, b.opacity * 1.6) / s
            return Qt.vector4d(c.x + padX, c.y + 12, r, 0)
          }
          bub0: bubbleAt(rightBubble)
          bub1: bubbleAt(leftBubble)
          blend: island.mode === "compact" ? 11 : 4
          tint: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, Math.max(0.36, Math.min(0.95, Number(island.cfg("glassOpacity")) || 0.56)))
          light: island.glassLight
          energy: island.glassEnergy
          ambL: ambient.leftColor
          ambR: ambient.rightColor
          ambMix: ambient.opacity * (0.55 + ambient.level * 0.45)
          pull: Qt.vector4d(island.pullX + padX, island.pullY + 12, island.pullAmp, 22)
        }

        // Drawn directly (no offscreen texture) so text and icons inside stay
        // pixel-sharp at fractional scales. `clip` is a scissor rectangle:
        // content keeps clear of the rounded corners.
        Rectangle {
          id: shape
          clip: true
          width: island.targetW
          height: island.targetH
          radius: island.targetR
          color: island.halvesOn || island.glassOn ? "transparent" : Theme.bg
          border.width: island.halvesOn || island.glassOn ? 0 : 1
          border.color: island.mode === "compact" ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.10)
          antialiasing: true

          Behavior on width {
            enabled: !Theme.reduceMotion
            SpringAnimation { spring: island.springK; damping: island.springD; mass: Theme.mass; epsilon: 0.25 }
          }
          Behavior on height {
            enabled: !Theme.reduceMotion
            SpringAnimation { spring: island.springK; damping: Math.min(0.9, island.springD + 0.03); mass: Theme.mass; epsilon: 0.25 }
          }
          Behavior on radius {
            enabled: !Theme.reduceMotion
            SpringAnimation { spring: Theme.closeSpring; damping: 0.5; epsilon: 0.1 }
          }

          // Music page backdrop, like Apple Music: the artwork's colors fill
          // the open card as large, heavily blurred blobs that drift slowly.
          // Masked to the card's rounded shape; only this layer is rendered
          // offscreen, the text above stays sharp.
          Item {
            id: musicBackdrop
            anchors.fill: parent
            // Opening onto the music page, the colors come in with the card
            // as it grows (no black first). Between tabs they cross-fade
            // quickly. Closing, they vanish at once, so nothing is drawn
            // while the card shrinks into the compact island.
            readonly property bool expanded: island.mode === "expanded"
            readonly property bool on: island.cfg("ambient") && expanded
              && island.page === "music" && island.music.available
            readonly property bool moving: on && !Theme.reduceMotion
            opacity: on ? 1 : 0
            visible: opacity > 0.005
            Behavior on opacity {
              enabled: musicBackdrop.expanded
              NumberAnimation { duration: Theme.ms(280); easing.type: Easing.OutCubic }
            }

            property color c1: Qt.darker(island.music.ambient[0], 1.5)
            property color c2: Qt.darker(island.music.ambient[1], 1.5)
            Behavior on c1 { ColorAnimation { duration: 1500 } }
            Behavior on c2 { ColorAnimation { duration: 1500 } }

            // Blob positions as fractions of the card, each drifting on its
            // own slow loop so the pattern never visibly repeats.
            // Blob positions as fractions of the card, each drifting on its
            // own slow loop so the pattern never visibly repeats.
            property real ax: 0.18
            property real ay: 0.25
            property real bx: 0.82
            property real by: 0.7
            property real cx: 0.5
            property real cy: 0.9
            SequentialAnimation {
              loops: Animation.Infinite
              running: musicBackdrop.moving
              NumberAnimation { target: musicBackdrop; property: "ax"; to: 0.08; duration: 9000; easing.type: Easing.InOutSine }
              NumberAnimation { target: musicBackdrop; property: "ax"; to: 0.45; duration: 9000; easing.type: Easing.InOutSine }
            }
            SequentialAnimation {
              loops: Animation.Infinite
              running: musicBackdrop.moving
              NumberAnimation { target: musicBackdrop; property: "ay"; to: 0.15; duration: 11000; easing.type: Easing.InOutSine }
              NumberAnimation { target: musicBackdrop; property: "ay"; to: 0.75; duration: 11000; easing.type: Easing.InOutSine }
            }
            SequentialAnimation {
              loops: Animation.Infinite
              running: musicBackdrop.moving
              NumberAnimation { target: musicBackdrop; property: "bx"; to: 0.92; duration: 10000; easing.type: Easing.InOutSine }
              NumberAnimation { target: musicBackdrop; property: "bx"; to: 0.5; duration: 10000; easing.type: Easing.InOutSine }
            }
            SequentialAnimation {
              loops: Animation.Infinite
              running: musicBackdrop.moving
              NumberAnimation { target: musicBackdrop; property: "by"; to: 0.85; duration: 12500; easing.type: Easing.InOutSine }
              NumberAnimation { target: musicBackdrop; property: "by"; to: 0.2; duration: 12500; easing.type: Easing.InOutSine }
            }
            SequentialAnimation {
              loops: Animation.Infinite
              running: musicBackdrop.moving
              NumberAnimation { target: musicBackdrop; property: "cx"; to: 0.3; duration: 13000; easing.type: Easing.InOutSine }
              NumberAnimation { target: musicBackdrop; property: "cx"; to: 0.75; duration: 13000; easing.type: Easing.InOutSine }
            }
            SequentialAnimation {
              loops: Animation.Infinite
              running: musicBackdrop.moving
              NumberAnimation { target: musicBackdrop; property: "cy"; to: 0.95; duration: 9500; easing.type: Easing.InOutSine }
              NumberAnimation { target: musicBackdrop; property: "cy"; to: 0.45; duration: 9500; easing.type: Easing.InOutSine }
            }

            Item {
              id: blobs
              anchors.fill: parent
              visible: false
              // Kept ready while the card is open, so a fade-in never starts
              // with an unblurred frame.
              layer.enabled: musicBackdrop.expanded
              // Rendered small and scaled up: blurring a low-resolution
              // texture gives the very soft, edgeless look.
              layer.textureSize: Qt.size(Math.max(8, Math.round(width / 8)), Math.max(8, Math.round(height / 8)))
              layer.smooth: true
              readonly property real d: Math.max(width, height) * 0.95
              Rectangle {
                width: blobs.d; height: width; radius: width / 2
                x: blobs.width * musicBackdrop.ax - width / 2
                y: blobs.height * musicBackdrop.ay - height / 2
                color: musicBackdrop.c1
              }
              Rectangle {
                width: blobs.d * 0.9; height: width; radius: width / 2
                x: blobs.width * musicBackdrop.bx - width / 2
                y: blobs.height * musicBackdrop.by - height / 2
                color: musicBackdrop.c2
              }
              Rectangle {
                width: blobs.d * 0.6; height: width; radius: width / 2
                x: blobs.width * musicBackdrop.cx - width / 2
                y: blobs.height * musicBackdrop.cy - height / 2
                color: Qt.tint(musicBackdrop.c1, Qt.rgba(musicBackdrop.c2.r, musicBackdrop.c2.g, musicBackdrop.c2.b, 0.5))
              }
            }
            Rectangle {
              id: backdropMask
              anchors.fill: parent
              radius: shape.radius
              visible: false
              layer.enabled: musicBackdrop.expanded
            }
            MultiEffect {
              anchors.fill: parent
              source: blobs
              blurEnabled: true
              blur: 1
              blurMax: 64
              // No padding: the effect must not draw past the card.
              autoPaddingEnabled: false
              maskEnabled: true
              maskSource: backdropMask
              opacity: 0.7
            }
          }

          // Two agents at work: the pill as two halves with a gap between.
          // At gap 0 they are exactly the whole pill, so the split and the
          // merge are seamless.
          Repeater {
            model: island.halvesOn ? [0, 1] : []
            delegate: Rectangle {
              required property int modelData
              readonly property real inner: Math.min(height / 2, island.splitGap * 2.2)
              width: (shape.width - island.splitGap) / 2
              height: shape.height
              x: modelData === 0 ? 0 : shape.width - width
              readonly property bool lit: island.hoveredHalf === modelData
              readonly property color agentTint: island.profile(island.splitOrder[modelData] || "").color
              color: island.glassOn ? "transparent" : Theme.bg
              border.width: lit ? 1.5 : 1
              border.color: lit ? Qt.rgba(agentTint.r, agentTint.g, agentTint.b, 0.6) : island.glassOn ? "transparent" : Qt.rgba(1, 1, 1, 0.06)
              Behavior on border.color { ColorAnimation { duration: Theme.ms(160) } }
              topLeftRadius: modelData === 0 ? height / 2 : inner
              bottomLeftRadius: modelData === 0 ? height / 2 : inner
              topRightRadius: modelData === 1 ? height / 2 : inner
              bottomRightRadius: modelData === 1 ? height / 2 : inner
            }
          }

          // Background press target: compact/peek expand on click.
          MouseArea {
            id: shapeMouse
            anchors.fill: parent
            cursorShape: island.mode === "expanded" ? Qt.ArrowCursor : Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onPressed: if (island.mode !== "expanded") { stage.pressScale = 0.95; island.wobble(-0.03) }
            onReleased: { stage.pressScale = 1; if (island.mode !== "expanded") island.flash() }
            onCanceled: stage.pressScale = 1
            onClicked: mouseEvent => {
              if (island.mode === "expanded") return
              if (mouseEvent.button === Qt.MiddleButton && island.primary === "music") { music.togglePlaying(); return }
              if (mouseEvent.button === Qt.RightButton) { island.openPage("home", "pointer"); return }
              var target = island.mode === "peek" && island.peekData.target ? island.peekData.target : island.defaultPage()
              island.openPage(target, "pointer")
            }
            onWheel: wheel => {
              if (island.mode === "expanded") { wheel.accepted = false; return }
              // Scroll on the compact island nudges the volume, as on macOS notch apps.
              Quickshell.execDetached(["omarchy-audio-output-volume", wheel.angleDelta.y > 0 ? "+5" : "-5"])
            }

            Accessible.role: Accessible.Button
            Accessible.name: "Dynamic Island"
            Accessible.description: island.mode === "expanded" ? I18n.t("Açık") : I18n.t("Açmak için tıklayın")
          }

          // Drag files in → the shelf opens under the pointer.
          DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            onEntered: drag => {
              if (!drag.hasUrls) { drag.accepted = false; return }
              island.dragHover = true
              if (island.page !== "shelf" || island.mode !== "expanded") island.openPage("shelf", "pointer")
            }
            onExited: island.dragHover = false
            onDropped: drop => {
              island.dragHover = false
              var n = shelf.addUrls(drop.urls)
              if (n > 0) {
                drop.acceptProposedAction()
                island.bounce()
              }
            }
          }

          // ---------------------------------------------------- compact
          CompactView {
            anchors.fill: parent
            shown: island.mode === "compact" && island.introDone
            island: island
          }

          // ---------------------------------------------------- peek
          PeekView {
            anchors.fill: parent
            shown: island.mode === "peek"
            island: island
          }

          // ---------------------------------------------------- expanded
          TabStrip {
            id: tabs
            anchors.top: parent.top
            anchors.topMargin: 12
            x: Math.round((parent.width - width) / 2)
            width: island.expandedW - 32
            shown: island.mode === "expanded" && island.page !== "permission"
            island: island
          }

          Item {
            id: pageStack
            anchors.top: parent.top
            anchors.topMargin: island.expandedChromeH + 4
            x: Math.round((parent.width - width) / 2)
            width: island.expandedW - 40
            height: currentHeight

            readonly property bool open: island.mode === "expanded"
            readonly property int currentHeight: {
              switch (island.page) {
                case "music": return musicPage.implicitHeight
                case "agent": return agentPage.implicitHeight
                case "permission": return permissionPage.implicitHeight
                case "timer": return timerPage.implicitHeight
                case "shelf": return shelfPage.implicitHeight
                default: return homePage.implicitHeight
              }
            }

            HomePage { slide: island.pageSlide; id: homePage; island: island; width: parent.width; shown: pageStack.open && island.page === "home" }
            MusicPage { slide: island.pageSlide; id: musicPage; island: island; width: parent.width; shown: pageStack.open && island.page === "music" }
            AgentPage { slide: island.pageSlide; id: agentPage; island: island; width: parent.width; shown: pageStack.open && island.page === "agent" }
            PermissionPage { slide: island.pageSlide; id: permissionPage; island: island; width: parent.width; shown: pageStack.open && island.page === "permission" }
            TimerPage { slide: island.pageSlide; id: timerPage; island: island; width: parent.width; shown: pageStack.open && island.page === "timer" }
            ShelfPage { slide: island.pageSlide; id: shelfPage; island: island; width: parent.width; shown: pageStack.open && island.page === "shelf" }
          }
        }

        // Hover is tracked on the whole shape, children included.
        HoverHandler {
          id: hover
        }
      }

      // Input mask follows the *target* size while opening (so the pointer
      // doesn't fall off a still-growing shape) and the live size otherwise.
      Item {
        id: maskItem
        x: stage.x + (stage.width - width) / 2
        y: stage.y
        width: Math.max(shape.width, island.mode === "expanded" ? island.targetW : 0)
        height: Math.max(shape.height, island.mode === "expanded" ? island.targetH : 0)
      }

      // ------------------------------------------------------------ bubbles
      // Extra live activities split off as small circles, like iOS: the
      // second to the right, a third to the left. Each works on its own.
      Bubble {
        id: rightBubble
        island: island
        anchor: stage
        side: 1
        activity: island.secondary
      }
      Bubble {
        id: leftBubble
        island: island
        anchor: stage
        side: -1
        activity: island.tertiary
      }
      Item { id: rightHit; x: rightBubble.x; y: rightBubble.y; width: rightBubble.width; height: rightBubble.height }
      Item { id: leftHit; x: leftBubble.x; y: leftBubble.y; width: leftBubble.width; height: leftBubble.height }
    }
  }
}
