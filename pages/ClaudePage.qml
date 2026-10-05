import QtQuick
import "../components"

// Every Claude Code session: what it is doing right now, and a jump to it.
Page {
  id: page

  property var island
  readonly property var claude: island.claude
  readonly property var sessions: claude.sessionList.slice(0, 4)

  implicitHeight: col.implicitHeight + 8

  function working(s) {
    var st = claude.displayState(s)
    return st === "thinking" || st === "tool" || st === "compacting"
  }

  function stateText(s) {
    switch (claude.displayState(s)) {
      case "waiting": return I18n.t("İzin bekliyor · ") + (s.tool || "")
      case "input": return s.message || I18n.t("Girdi bekliyor")
      case "thinking": return I18n.t("Düşünüyor…")
      case "compacting": return I18n.t("Bağlamı sıkıştırıyor…")
      case "tool": return (s.tool || I18n.t("Araç")) + (s.title ? " · " + s.title : "") + "…"
      case "done": return I18n.t("Bitti") + (s.lastDuration ? " · " + island.duration(s.lastDuration) : "")
    }
    return I18n.t("Hazır")
  }

  function stateColor(s) {
    var st = claude.displayState(s)
    if (st === "waiting" || st === "input" || working(s)) return Theme.claude
    if (st === "done") return Theme.green
    return Theme.secondary
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
          source: Theme.claudeLogo
          size: 22
        }
        Label {
          anchors.verticalCenter: parent.verticalCenter
          text: "Claude Code"
          font.pixelSize: 16
          strong: true
        }
        Label {
          anchors.verticalCenter: parent.verticalCenter
          text: claude.sessionList.length > 0 ? claude.sessionList.length + I18n.t(" oturum") : ""
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
        visible: claude.usage.session >= 0
        Repeater {
          model: [
            { label: I18n.t("5s"), v: claude.usage.session },
            { label: I18n.t("7g"), v: claude.usage.weekly }
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
                color: modelData.v >= 0.9 ? Theme.red : modelData.v >= 0.7 ? Theme.orange : Theme.claude
              }
            }
            Label { text: Math.round(modelData.v * 100) + "%"; font.pixelSize: 12; tabular: true; color: Theme.secondary; anchors.verticalCenter: parent.verticalCenter }
          }
        }
      }
      MouseArea {
        anchors.fill: usageRow
        cursorShape: Qt.PointingHandCursor
        onClicked: claude.openUsage()
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
          readonly property bool waiting: claude.displayState(s) === "waiting"
          width: parent.width
          height: 58
          radius: 18
          color: rowMouse.containsMouse ? Theme.fillHover : Theme.fill
          border.width: waiting ? 1 : 0
          border.color: Theme.claude
          Behavior on color { ColorAnimation { duration: Theme.ms(140) } }

          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.waiting ? island.setPage("permission") : claude.focusTerminal(row.s)
          }

          Accessible.role: Accessible.ListItem
          Accessible.name: (s.project || "oturum") + ", " + page.stateText(s)

          Item {
            id: lead
            x: 14
            width: 24; height: 24
            anchors.verticalCenter: parent.verticalCenter
            ClaudeSpinner {
              anchors.centerIn: parent
              size: 20
              visible: claude.displayState(row.s) !== "done"
              running: page.working(row.s)
            }
            Icon { anchors.centerIn: parent; visible: claude.displayState(row.s) === "done"; name: "check"; size: 20; color: Theme.green }
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
                visible: claude.isBusy(row.s) && row.s.turnStartedAt > 0
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
              tint: Theme.claude
              accessibleName: I18n.t("İzin isteğini yanıtla")
              onClicked: island.setPage("permission")
            }
            IslandButton {
              size: 34
              iconSource: island.apps.editorIcon
              icon: island.apps.editorIcon ? "" : "code"
              iconSize: 18
              accessibleName: I18n.t("Klasörü editörde aç")
              onClicked: { claude.openInEditor(row.s); island.collapse() }
            }
            IslandButton {
              size: 34
              icon: "terminal"
              accessibleName: I18n.t("Terminale git")
              onClicked: { claude.focusTerminal(row.s); island.collapse() }
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
          text: claude.hooksInstalled ? I18n.t("Aktif oturum yok") : I18n.t("Claude Code bağlı değil")
          font.pixelSize: 14
          strong: true
        }
        Label {
          width: parent.width
          text: claude.hooksInstalled ? I18n.t("Bir oturum başlatınca burada görünür.") : I18n.t("Hook'ları kurunca oturumlar ve izinler burada.")
          font.pixelSize: 13
          color: Theme.secondary
        }
      }
      IslandButton {
        id: connect
        visible: !claude.hooksInstalled
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        size: 36
        text: I18n.t("Bağla")
        prominent: true
        tint: Theme.claude
        accessibleName: I18n.t("Claude Code hook'larını kur")
        onClicked: claude.installHooks()
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
        onClicked: { claude.newSession(); island.collapse() }
      }
      IslandButton {
        size: 36
        icon: "terminal"
        text: "Terminal"
        fontSize: 13
        enabled2: claude.focusSession !== null
        accessibleName: I18n.t("Etkin oturumun terminaline git")
        onClicked: { claude.focusTerminal(null); island.collapse() }
      }
      IslandButton {
        size: 36
        iconSource: island.apps.editorIcon
        icon: island.apps.editorIcon ? "" : "code"
        text: island.editorLabels[island.apps.editor] || I18n.t("Editör")
        fontSize: 13
        enabled2: claude.focusSession !== null
        accessibleName: I18n.t("Etkin oturumun klasörünü editörde aç")
        onClicked: { claude.openInEditor(null); island.collapse() }
      }
      IslandButton {
        size: 36
        icon: "trash"
        filled: false
        tint: Theme.secondary
        visible: claude.sessionList.some(s => !claude.isBusy(s))
        accessibleName: I18n.t("Biten oturumları temizle")
        onClicked: claude.clearFinished()
      }
    }
  }
}
