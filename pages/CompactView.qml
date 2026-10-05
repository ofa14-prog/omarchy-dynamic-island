import QtQuick
import "../components"

// Compact island: content hugs the two ends (leading / trailing), the middle
// stays clean black, exactly like a live activity around the camera. Leading
// items are square and inset by the same amount from the top, bottom and
// left edge, so they sit centered in the rounded end.
Page {
  id: view

  property var island
  readonly property string kind: island.primary
  readonly property int lead: Math.round(island.compactH * 0.62)          // leading item size
  readonly property int edge: Math.round((island.compactH - lead) / 2) + 2 // inset from the end
  readonly property var session: island.agents.focusSession
  readonly property var agentProfile: island.profile(session ? session.agent : "")
  readonly property string agentState: island.agents.displayState(session)
  readonly property bool agentWorking: agentState === "thinking" || agentState === "tool" || agentState === "compacting"

  function agentVerb() {
    var s = session
    switch (agentState) {
      case "waiting": return I18n.t("İzin gerekiyor")
      case "input": return I18n.t("Seni bekliyor")
      case "done": return I18n.t("Bitti")
      case "compacting": return I18n.t("Sıkıştırıyor…")
      case "tool": return (s && s.tool ? s.tool : I18n.t("Çalışıyor")) + "…"
      case "thinking": return I18n.t("Düşünüyor…")
    }
    return I18n.t("Hazır")
  }

  // ---------------------------------------------------------------- idle
  Page {
    anchors.fill: parent
    shown: view.kind === "idle"
    Label {
      anchors.centerIn: parent
      visible: island.cfg("idleClock")
      text: island.clockText
      strong: true
      tabular: true
      horizontalAlignment: Text.AlignHCenter
      Accessible.name: I18n.t("Saat ") + text
    }
  }

  // ---------------------------------------------------------------- music
  Page {
    anchors.fill: parent
    shown: view.kind === "music"
    Art {
      x: view.edge
      anchors.verticalCenter: parent.verticalCenter
      width: view.lead; height: view.lead
      radius: 7
      source: island.music.artUrl
    }
    Equalizer {
      anchors.right: parent.right
      anchors.rightMargin: view.edge + 4
      anchors.verticalCenter: parent.verticalCenter
      playing: island.music.playing
      color: island.music.accent
      barWidth: 3
      maxHeight: Math.round(view.lead * 0.75)
    }
  }

  // ---------------------------------------------------------------- agent
  Page {
    anchors.fill: parent
    shown: view.kind === "agent"

    Item {
      id: agentLead
      x: view.edge
      width: view.lead; height: view.lead
      anchors.verticalCenter: parent.verticalCenter
      AgentSpinner {
        agent: view.session ? view.session.agent : island.agentId
        anchors.centerIn: parent
        size: Math.round(view.lead * 0.82)
        visible: view.agentState !== "done"
        running: view.agentWorking
      }
      Icon {
        anchors.centerIn: parent
        visible: view.agentState === "done"
        name: "check"
        size: Math.round(view.lead * 0.8)
        color: Theme.green
      }
    }

    Row {
      anchors.right: parent.right
      anchors.rightMargin: view.edge + 4
      anchors.verticalCenter: parent.verticalCenter
      spacing: 7

      // Waiting for you: a pulsing dot reads instantly in the corner of your eye.
      Rectangle {
        visible: view.agentState === "waiting" || view.agentState === "input"
        width: 8; height: 8; radius: 4
        color: view.agentProfile.color
        anchors.verticalCenter: parent.verticalCenter
        SequentialAnimation on opacity {
          running: parent.visible && !Theme.reduceMotion
          loops: Animation.Infinite
          NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
          NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
        }
      }
      ShimmerText {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, 168)
        label: view.agentVerb()
        running: view.agentWorking
        font.pixelSize: 13
        font.weight: Font.DemiBold
        baseColor: view.agentState === "done" ? Theme.green : view.agentProfile.color
        glowColor: view.agentProfile.glow
      }
      Label {
        anchors.verticalCenter: parent.verticalCenter
        visible: view.agentWorking && view.session && view.session.turnStartedAt > 0
        font.pixelSize: 13
        tabular: true
        color: Theme.tertiary
        text: view.session ? island.duration(island.nowMs - view.session.turnStartedAt) : ""
      }
    }
  }

  // ---------------------------------------------------------------- recording
  Page {
    anchors.fill: parent
    shown: view.kind === "recording"
    Item {
      x: view.edge
      width: view.lead; height: view.lead
      anchors.verticalCenter: parent.verticalCenter
      Rectangle {
        anchors.centerIn: parent
        width: Math.round(view.lead * 0.55); height: width; radius: width / 2
        color: Theme.red
        SequentialAnimation on opacity {
          running: view.kind === "recording" && !Theme.reduceMotion
          loops: Animation.Infinite
          NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
          NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
        }
      }
    }
    Label {
      anchors.right: parent.right
      anchors.rightMargin: view.edge + 6
      anchors.verticalCenter: parent.verticalCenter
      text: island.timer.format(island.nowMs - island.recording.startedAt, false)
      font.pixelSize: 16
      strong: true
      tabular: true
      color: Theme.red
      Accessible.name: I18n.t("Ekran kaydı ") + text
    }
  }

  // ---------------------------------------------------------------- timer
  Page {
    anchors.fill: parent
    shown: view.kind === "timer"
    Item {
      x: view.edge
      width: view.lead; height: view.lead
      anchors.verticalCenter: parent.verticalCenter
      ProgressRing {
        anchors.fill: parent
        thickness: 2.5
        progress: island.timer.mode === "countdown" ? 1 - island.timer.progress : 1
        color: Theme.orange
      }
      Icon {
        anchors.centerIn: parent
        name: island.timer.paused ? "pause" : "timer"
        size: Math.round(view.lead * 0.5)
        color: Theme.orange
      }
    }
    Label {
      anchors.right: parent.right
      anchors.rightMargin: view.edge + 6
      anchors.verticalCenter: parent.verticalCenter
      text: island.timer.display
      font.pixelSize: 16
      strong: true
      tabular: true
      color: Theme.orange
      Accessible.name: I18n.t("Kalan süre ") + text
    }
  }
}
