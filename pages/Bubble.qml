import QtQuick
import Quickshell
import "../components"

// A live activity split off the island into its own circle, like iOS when
// two activities run at once. `side` is +1 (right of the island) or -1 (left).
// It emerges from under the island's edge on a spring and tucks back in.
//
//   click        open that activity (stop, for a screen recording)
//   right-click  swap it into the main island
//   middle-click play/pause music, pause/resume the timer
//   wheel        volume (music)
Item {
  id: bubble

  property var island
  property Item anchor               // the island's stage
  property int side: 1
  property string activity: ""
  readonly property bool shown: activity !== "" && island.mode === "compact" && !island.fullscreenHidden
  property string kind: activity !== "" ? activity : kind   // keep content while hiding

  readonly property int gap: 7
  width: island.compactH + island.hoverGrowH
  height: width
  y: anchor.y + (anchor.height - height) / 2
  x: side > 0
    ? anchor.x + anchor.width + (shown ? gap : -width * 0.9)
    : anchor.x - width - (shown ? gap : -width * 0.9)
  scale: shown ? 1 : 0.3
  opacity: shown ? 1 : 0
  z: -1

  readonly property bool hovered: mouse.containsMouse

  Behavior on x {
    enabled: !Theme.reduceMotion
    SpringAnimation { spring: 3.4; damping: 0.3; epsilon: 0.2 }
  }
  Behavior on scale {
    enabled: !Theme.reduceMotion
    SpringAnimation { spring: 3.8; damping: 0.32; epsilon: 0.005 }
  }
  Behavior on opacity { NumberAnimation { duration: Theme.ms(180) } }

  function label() {
    var i = island
    switch (kind) {
      case "music": return (i.music.title || I18n.t("Müzik")) + (i.music.artist ? " — " + i.music.artist : "")
      case "timer": return (i.timer.mode === "stopwatch" ? I18n.t("Kronometre ") : I18n.t("Sayaç ")) + i.timer.display + (i.timer.paused ? I18n.t(" (duraklatıldı)") : "")
      case "recording": return I18n.t("Ekran kaydı ") + i.duration(i.nowMs - i.recording.startedAt) + I18n.t(" · durdurmak için tıkla")
      case "claude": {
        var s = i.claude.focusSession
        return "Claude" + (s && s.project ? " · " + s.project : "") + (i.claude.pending.length ? I18n.t(" · izin bekliyor") : "")
      }
    }
    return ""
  }

  function activate() {
    if (kind === "recording") {
      island.recording.stop()
      island.peek("record", I18n.t("Kayıt durduruluyor"), "", Theme.red, 1500)
      return
    }
    island.openPage(kind === "claude" && island.claude.pending.length ? "permission" : kind, "pointer")
  }

  Rectangle {
    id: body
    anchors.fill: parent
    radius: width / 2
    color: Theme.bg
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.06)
    scale: mouse.pressed ? 0.88 : bubble.hovered ? 1.08 : 1
    Behavior on scale {
      enabled: !Theme.reduceMotion
      SpringAnimation { spring: Theme.snapSpring; damping: Theme.snapDamping; epsilon: 0.002 }
    }

    readonly property int inner: Math.round(bubble.width * 0.62)

    Art {
      visible: bubble.kind === "music"
      anchors.centerIn: parent
      width: body.inner; height: width
      radius: width / 2
      source: visible ? island.music.artUrl : ""
      // The record keeps spinning while it plays.
      RotationAnimation on rotation {
        running: bubble.kind === "music" && island.music.playing && bubble.shown && !Theme.reduceMotion
        from: 0; to: 360; duration: 9000; loops: Animation.Infinite
      }
    }
    Item {
      visible: bubble.kind === "timer"
      anchors.centerIn: parent
      width: body.inner; height: width
      ProgressRing {
        anchors.fill: parent
        thickness: 2.5
        progress: island.timer.mode === "countdown" ? 1 - island.timer.progress : 1
        color: Theme.orange
      }
      Icon {
        anchors.centerIn: parent
        name: island.timer.paused ? "pause" : "timer"
        size: Math.round(parent.width * 0.5)
        color: Theme.orange
      }
    }
    ClaudeSpinner {
      visible: bubble.kind === "claude"
      anchors.centerIn: parent
      size: Math.round(bubble.width * 0.5)
      running: island.claude.busy && island.claude.pending.length === 0
    }
    Rectangle {
      visible: bubble.kind === "claude" && island.claude.pending.length > 0
      anchors.right: parent.right
      anchors.top: parent.top
      width: 9; height: 9; radius: 5
      color: Theme.claude
    }
    Rectangle {
      visible: bubble.kind === "recording"
      anchors.centerIn: parent
      width: Math.round(bubble.width * 0.36); height: width; radius: width / 2
      color: Theme.red
      SequentialAnimation on opacity {
        running: bubble.kind === "recording" && bubble.shown && !Theme.reduceMotion
        loops: Animation.Infinite
        NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
      }
    }
  }

  // Hover label under the bubble.
  Rectangle {
    id: tip
    readonly property bool open: bubble.hovered && bubble.shown
    anchors.horizontalCenter: parent.horizontalCenter
    y: parent.height + (open ? 8 : 2)
    width: Math.min(320, tipText.implicitWidth + 24)
    height: 30
    radius: 15
    color: Theme.bg
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.10)
    opacity: open ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: Theme.ms(160) } }
    Behavior on y {
      enabled: !Theme.reduceMotion
      SpringAnimation { spring: 5; damping: 0.5; epsilon: 0.1 }
    }
    Label {
      id: tipText
      anchors.centerIn: parent
      width: Math.min(implicitWidth, 296)
      text: bubble.label()
      font.pixelSize: 12
      color: Theme.fg
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    enabled: bubble.shown
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: event => {
      if (event.button === Qt.RightButton) { island.pinned = bubble.kind; return }
      if (event.button === Qt.MiddleButton) {
        if (bubble.kind === "music") island.music.togglePlaying()
        else if (bubble.kind === "timer") island.timer.togglePause()
        return
      }
      bubble.activate()
    }
    onWheel: wheel => {
      if (bubble.kind === "music")
        Quickshell.execDetached(["omarchy-audio-output-volume", wheel.angleDelta.y > 0 ? "+5" : "-5"])
    }
    Accessible.role: Accessible.Button
    Accessible.name: bubble.label()
    Accessible.description: I18n.t("Tıkla: aç. Sağ tık: öne getir.")
  }
}
