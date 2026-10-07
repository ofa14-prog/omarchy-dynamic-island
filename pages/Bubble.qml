import QtQuick
import Quickshell
import "../components"

// A live activity split off the island into its own circle, like iOS when
// two activities run at once. `side` is +1 (right of the island) or -1 (left).
// It emerges from under the island's edge on a spring and tucks back in.
//
//   click         open that activity (stop, for a screen recording; for the
//                 shelf: put what is on the clipboard on the shelf, or open
//                 it when the clipboard holds nothing new)
//   double-click  swap it with the center: it moves into the island and the
//                 center activity takes this bubble's place
//   right-click   same swap
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
  // The bubble's resting place is fixed by the *compact* island, not the
  // live (animating) shape: opening and closing the island never moves it,
  // it just fades out and back in place. It only slides, tucking in under
  // the island's edge, when its activity starts or ends.
  readonly property bool tucked: activity === ""
  readonly property real restX: side > 0
    ? Math.round(parent.width / 2 + island.liveW / 2 + gap)
    : Math.round(parent.width / 2 - island.liveW / 2 - gap - width)
  width: island.compactH
  height: width
  y: Math.round(island.topY + (island.compactH - height) / 2)
  x: tucked ? restX - side * width * 0.9 : restX
  scale: shown ? 1 : (tucked ? 0.3 : 0.85)
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
      case "shelf": return I18n.t("Raf · %1 öğe").arg(i.shelf.count) + I18n.t(" · tıkla: panodakini ekle")
      case "agent": {
        var s = i.agents.focusSession
        return i.profile(s ? s.agent : "").name + (s && s.project ? " · " + s.project : "") + (i.agents.pending.length ? I18n.t(" · izin bekliyor") : "")
      }
    }
    return ""
  }

  function activate() {
    if (kind === "shelf") { island.shelf.addFromClipboard(); return }
    if (kind === "recording") {
      island.recording.stop()
      island.peek("record", I18n.t("Kayıt durduruluyor"), "", Theme.red, 1500)
      return
    }
    island.openPage(kind === "agent" && island.agents.pending.length ? "permission" : kind, "pointer")
  }

  Rectangle {
    id: body
    anchors.fill: parent
    radius: width / 2
    color: Theme.bg
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.06)
    scale: (mouse.pressed ? 0.88 : bubble.hovered ? 1.08 : 1) * bubble.pop
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
    // Shelf: how full it is as a ring, how many items in the middle.
    Item {
      visible: bubble.kind === "shelf"
      anchors.centerIn: parent
      width: body.inner + 2; height: width
      ProgressRing {
        anchors.fill: parent
        thickness: 2.5
        progress: Math.max(0.04, island.shelf.fullness)
        color: island.shelf.count >= island.shelf.limit ? Theme.orange : Theme.blue
      }
      Text {
        anchors.centerIn: parent
        text: island.shelf.count
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Math.round(parent.width * (island.shelf.count > 9 ? 0.4 : 0.48))
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering
      }
    }
    AgentSpinner {
      agent: island.agents.focusSession ? island.agents.focusSession.agent : island.agentId
      visible: bubble.kind === "agent"
      anchors.centerIn: parent
      size: Math.round(bubble.width * 0.5)
      running: island.agents.busy && island.agents.pending.length === 0
    }
    Rectangle {
      visible: bubble.kind === "agent" && island.agents.pending.length > 0
      anchors.right: parent.right
      anchors.top: parent.top
      width: 9; height: 9; radius: 5
      color: island.agentColor
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

  // A swap lands with a small spring "pop" as the new content arrives.
  property real pop: 1
  onKindChanged: if (shown && !Theme.reduceMotion) popAnim.restart()
  SequentialAnimation {
    id: popAnim
    NumberAnimation { target: bubble; property: "pop"; to: 0.55; duration: 90; easing.type: Easing.InQuad }
    SpringAnimation { target: bubble; property: "pop"; to: 1; spring: 5; damping: 0.28; epsilon: 0.005 }
  }

  // A single click waits out the system's double-click interval, so a
  // double-click (however slow, within that interval) never also opens the
  // page underneath.
  Timer {
    id: singleClick
    interval: Qt.styleHints.mouseDoubleClickInterval + 30
    onTriggered: bubble.activate()
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    enabled: bubble.shown
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: event => {
      if (event.button === Qt.RightButton) { island.swapToCenter(bubble.kind); return }
      if (event.button === Qt.MiddleButton) {
        if (bubble.kind === "music") island.music.togglePlaying()
        else if (bubble.kind === "timer") island.timer.togglePause()
        return
      }
      singleClick.restart()
    }
    onDoubleClicked: event => {
      if (event.button !== Qt.LeftButton) return
      singleClick.stop()
      island.swapToCenter(bubble.kind)
    }
    onWheel: wheel => {
      if (bubble.kind === "music")
        Quickshell.execDetached(["omarchy-audio-output-volume", wheel.angleDelta.y > 0 ? "+5" : "-5"])
    }
    Accessible.role: Accessible.Button
    Accessible.name: bubble.label()
    Accessible.description: I18n.t("Tıkla: aç. Çift tık: ortaya al.")
  }
}
