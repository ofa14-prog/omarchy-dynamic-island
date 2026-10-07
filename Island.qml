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
//   elicitation, idle prompt) / Gemini       pulsing dot in compact until you act
//   permission in its terminal
//   agent turn interrupted / quiet           no banner; compact falls back
//   timer finished                           opens on the timer, shakes, chimes
//   new track (settled 1.5 s, playing)       banner (peekOnTrackChange)
//   charger plugged in (settled 1.5 s)       "Charging" banner
//   screen recording starts/stops            red activity appears/disappears
//   file dragged over the island             opens the shelf
//   files on the shelf                       shelf bubble (count + fill ring);
//                                            clicking it shelves the clipboard
//   pointer hover / leave                    opens after hoverDelay / closes
//                                            after collapseDelay
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
    hoverExpand: true,
    hoverDelay: 380,
    collapseDelay: 650,
    reduceMotion: false,
    idleClock: true,
    clockFormat: "ddd d MMM  HH:mm",
    language: "auto",
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
    shortcuts: [],
    agent: "",
    agentQuietSeconds: 180
  })
  property var userConfig: ({})
  function cfg(key) { return userConfig[key] !== undefined ? userConfig[key] : defaults[key] }

  FileView {
    path: island.home + "/.config/omarchy/dynamic-island.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { island.userConfig = JSON.parse(text()) || {} } catch (e) { console.warn("dynamic-island: bad config", e) } }
    onLoadFailed: island.userConfig = ({})
  }

  Binding { target: Theme; property: "reduceMotion"; value: island.cfg("reduceMotion") === true }

  // "auto" picks Turkish on a tr_* system, English everywhere else.
  readonly property string language: {
    var l = String(cfg("language") || "auto")
    if (l !== "auto") return l
    var sys = Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || ""
    return sys.indexOf("tr") === 0 ? "tr" : "en"
  }
  Binding { target: I18n; property: "lang"; value: island.language }
  readonly property string localeName: cfg("locale") || (language === "tr" ? "tr_TR" : Qt.locale().name)
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
  readonly property var shortcuts: {
    var list = cfg("shortcuts")
    if (list && list.length) return list
    return [
      { action: "agent", label: agentName, image: agentLogo, icon: "sparkles" },
      { action: "editor", label: editorLabels[apps.editor] || apps.editorName, image: apps.editorIcon, icon: "code" },
      { action: "browser", label: I18n.t("Tarayıcı"), image: apps.browserIcon, icon: "globe" },
      { action: "files", label: I18n.t("Dosyalar"), image: apps.filesIcon, icon: "folder" },
      { action: "terminal", label: "Terminal", image: apps.terminalIcon, icon: "terminal" },
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
    if (action === "agent") Quickshell.execDetached(["omarchy-agent"])
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
    quietAfterMs: Math.max(20, Number(island.cfg("agentQuietSeconds")) || 180) * 1000
    onPermissionArrived: request => {
      if (island.cfg("autoExpandPermission")) {
        island.openPage("permission", "alert")
        island.bounce()
      } else {
        island.peek("agent:" + request.agent, I18n.t("%1 izin istiyor").arg(island.profile(request.agent).name), request.project + " · " + request.tool, island.profile(request.agent).color, 3500)
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
      if (island.mode !== "expanded")
        island.peek("agent:" + s.agent, I18n.t("%1 bir hatayla durdu").arg(island.profile(s.agent).name), s.project + (s.error ? " · " + s.error : ""), Theme.red, 3600, "agent")
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

  ShelfService {
    id: shelfSvc
    onPasted: (added, what) => {
      if (added > 0) {
        island.bounce()
        island.peek("shelf", what === "image" ? I18n.t("Görsel rafa eklendi") : what === "text" ? I18n.t("Metin rafa eklendi")
          : added === 1 ? I18n.t("Rafa eklendi") : I18n.t("%1 dosya rafa eklendi").arg(added),
          I18n.t("Rafta %1 öğe").arg(shelfSvc.count), Theme.blue, 1600, "shelf")
      } else if (what === "known") {
        island.peek("shelf", I18n.t("Zaten rafta"), "", Theme.secondary, 1300, "shelf")
      } else {
        island.openPage("shelf", "pointer")
      }
    }
  }
  DefaultApps { id: appsSvc }
  RecordingService { id: recordingSvc }

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
  readonly property bool locked: (page === "permission" && agents.pending.length > 0) || (page === "timer" && timer.ringing) || dragHover

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
  // island from disk. Omarchy's launcher brings the shell back in a second.
  function restartShell() {
    Quickshell.execDetached(["sh", "-c",
      "pkill -KILL -f \"quickshell -n -p ${OMARCHY_PATH:-/usr/share/omarchy}/shell\""])
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
    if (mode === "expanded") return
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
          island.barGeom = found
        } catch (e) {}
      }
    }
  }
  Timer {
    interval: 10000
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
    return barGeom.h >= 40 ? Math.min(38, barGeom.h - 7) : Math.max(30, barGeom.h - 2)
  }
  readonly property int topY: {
    var v = cfg("topOffset")
    if (typeof v === "number" && v >= 0) return v
    if (!barGeom) return 6
    return barGeom.h >= 40 ? barGeom.y + barGeom.h - compactH - 1
      : barGeom.y + Math.max(0, Math.round((barGeom.h - compactH) / 2))
  }
  readonly property int expandedW: cfg("expandedWidth")
  readonly property bool hovered: hover.hovered
  readonly property int hoverGrowW: mode === "compact" && hovered ? 12 : 0
  readonly property int hoverGrowH: mode === "compact" && hovered ? 2 : 0

  readonly property int idleW: cfg("idleClock") ? Math.max(130, Math.ceil(clockMetrics.advanceWidth) + 44) : 130
  readonly property int liveW: {
    if (primary === "agent") return 300
    if (primary === "timer") return 236
    if (primary === "music") return 268
    if (primary === "recording") return 210
    return idleW
  }

  readonly property int expandedChromeH: page === "permission" ? 0 : 52
  readonly property int pageH: pageStack.currentHeight
  readonly property int targetW: mode === "expanded" ? expandedW
    : mode === "peek" ? Math.min(expandedW, Math.max(320, Math.ceil(peekMetrics.advanceWidth) + 130))
    : liveW + hoverGrowW
  readonly property int targetH: mode === "expanded" ? expandedChromeH + pageH + 16
    : mode === "peek" ? 64
    : compactH + hoverGrowH
  readonly property real targetR: mode === "expanded" ? 34 : mode === "peek" ? 32 : (compactH + hoverGrowH) / 2

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
    onTriggered: if (hover.hovered && island.mode !== "expanded") island.openPage(island.defaultPage(), "pointer")
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
        pending: agents.pending.length, sessions: agents.sessionList.length, listening: agents.listening })
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
    implicitHeight: 520
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
        y: Math.round(island.topY + island.bounceY)
        opacity: island.fullscreenHidden ? 0 : 1
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

        // The pointer gently pulls the compact island toward itself.
        Binding {
          target: stage
          property: "leanX"
          value: island.mode === "compact" && hover.hovered
            ? Math.max(-1, Math.min(1, (hover.point.position.x - stage.width / 2) / (stage.width / 2))) * 3.5
            : 0
        }

        // Soft drop shadow, only once the island leaves the bar.
        RectangularShadow {
          anchors.fill: shape
          radius: shape.radius
          blur: 28
          spread: 0
          offset.y: 8
          color: Qt.rgba(0, 0, 0, 0.55)
          opacity: island.mode === "compact" ? 0 : 1
          Behavior on opacity { NumberAnimation { duration: Theme.ms(260) } }
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
          color: Theme.bg
          border.width: 1
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

          // Background press target: compact/peek expand on click.
          MouseArea {
            id: shapeMouse
            anchors.fill: parent
            cursorShape: island.mode === "expanded" ? Qt.ArrowCursor : Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onPressed: if (island.mode !== "expanded") stage.pressScale = 0.95
            onReleased: stage.pressScale = 1
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
            shown: island.mode === "compact"
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
