import QtQuick
import "../components"

// Every coding-agent session: what it is doing right now, and a jump to it.
// Branded after Omarchy's default agent; each session row keeps its own agent.
Page {
  id: page

  property var island
  readonly property var agents: island.agents
  readonly property var sessions: agents.sessionList.slice(0, 4)

  implicitHeight: col.implicitHeight + 8

  readonly property var profile: island.agent
  // "full" / "status": the agent reports sessions once connected;
  // "none": it has no event API, so there is nothing to connect.
  readonly property bool connectable: profile.integration !== "none"
  readonly property bool connected: agents.hooksInstalled

  function working(s) {
    var st = agents.displayState(s)
    return st === "thinking" || st === "tool" || st === "compacting"
  }

  // Labels and tones come from AgentBridge.stateLook; rows add detail.
  function stateText(s) {
    var st = agents.displayState(s)
    switch (st) {
      case "waiting": return I18n.t("İzin bekliyor · ") + (s.tool || "")
      case "input": return s.message || I18n.t("Seni bekliyor")
      case "compacting": return I18n.t("Bağlamı sıkıştırıyor…")
      case "tool": return (s.tool || I18n.t("Araç")) + (s.title ? " · " + s.title : "") + "…"
      case "done": return I18n.t("Bitti") + (s.lastDuration ? " · " + island.duration(s.lastDuration) : "")
      case "error": return I18n.t("Hata") + (s.error ? " · " + s.error : "")
    }
    return I18n.t(agents.look(s).label)
  }

  function stateColor(s) {
    var tone = agents.look(s).tone
    return tone === "agent" ? island.profile(s.agent).color : tone === "green" ? Theme.green
      : tone === "red" ? Theme.red : Theme.secondary
  }

  Column {
    id: col
    width: parent.width
    spacing: 12

    // ---- header
    Item {
      width: parent.width
      height: 30
      Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        Icon {
          anchors.verticalCenter: parent.verticalCenter
          source: island.agentLogo
          name: island.agentLogo ? "" : "sparkles"
          color: island.agentColor
          size: 22
        }
        Label {
          anchors.verticalCenter: parent.verticalCenter
          text: island.agentProduct
          font.pixelSize: 16
          strong: true
        }
        Label {
          anchors.verticalCenter: parent.verticalCenter
          text: agents.sessionList.length > 0 ? agents.sessionList.length + I18n.t(" oturum") : ""
          font.pixelSize: 13
          color: Theme.tertiary
        }
      }
      // Compact usage readout; click for Omarchy's full usage panel.
      Row {
        id: usageRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
        visible: agents.usage.session >= 0
        Repeater {
          model: [
            { label: I18n.t("5s"), v: agents.usage.session },
            { label: I18n.t("7g"), v: agents.usage.weekly }
          ]
          delegate: Row {
            required property var modelData
            spacing: 6
            visible: modelData.v >= 0
            Label { text: modelData.label; font.pixelSize: 12; color: Theme.tertiary; anchors.verticalCenter: parent.verticalCenter }
            Rectangle {
              width: 40; height: 6; radius: 3
              anchors.verticalCenter: parent.verticalCenter
              color: Theme.fill
              Rectangle {
                width: Math.max(6, parent.width * Math.min(1, modelData.v))
                height: parent.height; radius: 3
                color: modelData.v >= 0.9 ? Theme.red : modelData.v >= 0.7 ? Theme.orange : island.agentColor
              }
            }
            Label { text: Math.round(modelData.v * 100) + "%"; font.pixelSize: 12; tabular: true; color: Theme.secondary; anchors.verticalCenter: parent.verticalCenter }
          }
        }
      }
      MouseArea {
        anchors.fill: usageRow
        cursorShape: Qt.PointingHandCursor
        onClicked: agents.openUsage()
        Accessible.role: Accessible.Button
        Accessible.name: I18n.t("Kullanım ayrıntıları")
      }
    }

    // ---- sessions
    Column {
      width: parent.width
      spacing: 8
      visible: page.sessions.length > 0

      Repeater {
        model: page.sessions
        delegate: Rectangle {
          id: row
          required property var modelData
          readonly property var s: modelData
          readonly property bool waiting: agents.displayState(s) === "waiting"
          width: parent.width
          height: 58
          radius: 18
          color: rowMouse.containsMouse ? Theme.fillHover : Theme.fill
          border.width: waiting ? 1 : 0
          border.color: island.profile(s.agent).color
          Behavior on color { ColorAnimation { duration: Theme.ms(140) } }

          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.waiting ? island.setPage("permission") : agents.focusTerminal(row.s)
          }

          Accessible.role: Accessible.ListItem
          Accessible.name: (s.project || "oturum") + ", " + page.stateText(s)

          Item {
            id: lead
            x: 14
            width: 24; height: 24
            anchors.verticalCenter: parent.verticalCenter
            AgentSpinner {
              anchors.centerIn: parent
              agent: row.s.agent || "claude"
              size: 20
              visible: agents.look(row.s).icon === ""
              running: page.working(row.s)
            }
            Icon { anchors.centerIn: parent; visible: agents.look(row.s).icon !== ""; name: agents.look(row.s).icon; size: 20; color: page.stateColor(row.s) }
          }

          Column {
            anchors.left: lead.right
            anchors.leftMargin: 12
            anchors.right: actions.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Row {
              width: parent.width
              spacing: 8
              Label {
                text: row.s.project || "oturum"
                font.pixelSize: 14
                strong: true
                width: Math.min(implicitWidth, parent.width - (timeLabel.visible ? timeLabel.width + 8 : 0))
              }
              Label {
                id: timeLabel
                visible: agents.isBusy(row.s) && row.s.turnStartedAt > 0
                text: island.duration(island.nowMs - row.s.turnStartedAt) + (row.s.toolCount ? " · " + row.s.toolCount + I18n.t(" araç") : "")
                font.pixelSize: 12
                tabular: true
                color: Theme.tertiary
              }
            }
            ShimmerText {
              width: parent.width
              label: page.stateText(row.s)
              running: page.working(row.s)
              font.pixelSize: 13
              baseColor: page.stateColor(row.s)
              glowColor: island.profile(row.s.agent).glow
            }
          }

          Row {
            id: actions
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            IslandButton {
              visible: row.waiting
              size: 34
              text: I18n.t("Yanıtla")
              fontSize: 13
              prominent: true
              tint: island.profile(row.s.agent).color
              accessibleName: I18n.t("İzin isteğini yanıtla")
              onClicked: island.setPage("permission")
            }
            IslandButton {
              size: 34
              iconSource: island.apps.editorIcon
              icon: island.apps.editorIcon ? "" : "code"
              iconSize: 18
              accessibleName: I18n.t("Klasörü editörde aç")
              onClicked: { agents.openInEditor(row.s); island.collapse() }
            }
            IslandButton {
              size: 34
              icon: "terminal"
              accessibleName: I18n.t("Terminale git")
              onClicked: { agents.focusTerminal(row.s); island.collapse() }
            }
          }
        }
      }
    }

    // ---- empty / setup state
    Rectangle {
      visible: page.sessions.length === 0
      width: parent.width
      height: 72
      radius: 18
      color: Theme.fill
      Column {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: connect.visible ? connect.left : parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Label {
          width: parent.width
          text: !page.connectable ? I18n.t("%1 canlı oturum paylaşmıyor").arg(island.agentProduct)
            : page.connected ? I18n.t("Aktif oturum yok") : I18n.t("%1 bağlı değil").arg(island.agentProduct)
          font.pixelSize: 14
          strong: true
        }
        Label {
          width: parent.width
          text: !page.connectable ? I18n.t("Kısayol ve kullanım bilgisi yine burada.")
            : page.connected ? I18n.t("Bir oturum başlatınca burada görünür.")
            : page.profile.integration === "full" ? I18n.t("Bağlayınca oturumlar ve izinler burada.")
            : I18n.t("Bağlayınca oturumlar burada.")
          font.pixelSize: 13
          color: Theme.secondary
        }
      }
      IslandButton {
        id: connect
        visible: page.connectable && !page.connected
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        size: 36
        text: I18n.t("Bağla")
        prominent: true
        tint: island.agentColor
        accessibleName: I18n.t("%1 bağlantısını kur").arg(island.agentProduct)
        onClicked: agents.installHooks(island.agentId)
      }
    }

    // ---- shortcuts
    Row {
      spacing: 8
      IslandButton {
        size: 36
        icon: "plus"
        text: I18n.t("Yeni oturum")
        fontSize: 13
        accessibleName: I18n.t("Yeni ") + island.agentName + I18n.t(" oturumu")
        onClicked: { agents.newSession(); island.collapse() }
      }
      IslandButton {
        size: 36
        icon: "terminal"
        text: "Terminal"
        fontSize: 13
        enabled2: agents.focusSession !== null
        accessibleName: I18n.t("Etkin oturumun terminaline git")
        onClicked: { agents.focusTerminal(null); island.collapse() }
      }
      IslandButton {
        size: 36
        iconSource: island.apps.editorIcon
        icon: island.apps.editorIcon ? "" : "code"
        text: island.editorLabels[island.apps.editor] || I18n.t("Editör")
        fontSize: 13
        enabled2: agents.focusSession !== null
        accessibleName: I18n.t("Etkin oturumun klasörünü editörde aç")
        onClicked: { agents.openInEditor(null); island.collapse() }
      }
      IslandButton {
        size: 36
        icon: "trash"
        filled: false
        tint: Theme.secondary
        visible: agents.sessionList.some(s => !agents.isBusy(s))
        accessibleName: I18n.t("Biten oturumları temizle")
        onClicked: agents.clearFinished()
      }
    }
  }
}
