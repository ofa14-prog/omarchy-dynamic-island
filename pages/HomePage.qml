import QtQuick
import "../components"

// Home: time and status at a glance, launch shortcuts, quick timers.
Page {
  id: page

  property var island
  implicitHeight: col.implicitHeight + 8

  component Gauge: Column {
    id: gauge
    property real value: 0
    property string caption: ""
    property color tone: island.agentColor
    spacing: 4
    Item {
      width: 40; height: 40
      anchors.horizontalCenter: parent.horizontalCenter
      ProgressRing {
        anchors.fill: parent
        thickness: 4
        progress: gauge.value
        color: gauge.tone
      }
      Label {
        anchors.centerIn: parent
        text: Math.round(gauge.value * 100)
        font.pixelSize: 12
        strong: true
        tabular: true
        horizontalAlignment: Text.AlignHCenter
      }
    }
    Label {
      anchors.horizontalCenter: parent.horizontalCenter
      text: gauge.caption
      font.pixelSize: 11
      color: Theme.tertiary
      horizontalAlignment: Text.AlignHCenter
    }
    Accessible.role: Accessible.ProgressBar
    Accessible.name: caption + I18n.t(" yüzde ") + Math.round(value * 100)
  }

  Column {
    id: col
    width: parent.width
    spacing: 16

    // ---- glance row
    Item {
      width: parent.width
      height: 60

      Column {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Label {
          text: Qt.formatTime(new Date(island.nowMs), "HH:mm")
          font.pixelSize: 34
          font.weight: Font.Bold
          tabular: true
        }
        Label {
          text: Qt.locale(island.localeName).toString(new Date(island.nowMs), "dddd, d MMMM")
          font.pixelSize: 13
          color: Theme.secondary
        }
      }

      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16
        Gauge {
          visible: island.agents.usage.session >= 0
          value: island.agents.usage.session
          caption: I18n.t("5 sa")
          tone: value >= 0.9 ? Theme.red : value >= 0.7 ? Theme.orange : island.agentColor
        }
        Gauge {
          visible: island.agents.usage.weekly >= 0
          value: island.agents.usage.weekly
          caption: I18n.t("Hafta")
          tone: value >= 0.9 ? Theme.red : value >= 0.7 ? Theme.orange : island.agentColor
        }
        Gauge {
          visible: island.hasBattery
          value: island.batteryPercent / 100
          caption: I18n.t("Pil")
          tone: island.batteryPercent <= 15 ? Theme.red : Theme.green
        }
        // Refresh: click clears a stuck island; right-click restarts the
        // Omarchy shell (the bar blinks once).
        IslandButton {
          anchors.verticalCenter: parent.verticalCenter
          size: 40
          iconSize: 20
          icon: "restart"
          accessibleName: I18n.t("Adayı yenile")
          hint: I18n.t("Sağ tık: Omarchy kabuğunu yeniden başlat")
          onClicked: island.resetIsland()
          onRightClicked: island.restartShell()
        }
      }
    }

    // ---- screen recording in progress
    Rectangle {
      visible: island.recording.active
      width: parent.width
      height: 46
      radius: 23
      color: Qt.rgba(1, 0.27, 0.23, 0.14)
      Row {
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 12; height: 12; radius: 6
          color: Theme.red
        }
        Label {
          anchors.verticalCenter: parent.verticalCenter
          text: I18n.t("Ekran kaydı  ") + island.timer.format(island.nowMs - island.recording.startedAt, false)
          font.pixelSize: 14
          strong: true
          tabular: true
          color: Theme.red
        }
      }
      IslandButton {
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        size: 34
        text: I18n.t("Durdur")
        prominent: true
        tint: Theme.red
        accessibleName: I18n.t("Ekran kaydını durdur")
        onClicked: { island.recording.stop(); island.collapse() }
      }
    }

    // ---- shortcuts
    Grid {
      id: grid
      width: parent.width
      columns: Math.min(6, island.shortcuts.length)
      readonly property real cell: width / Math.max(1, columns)

      Repeater {
        model: island.shortcuts
        delegate: Item {
          required property var modelData
          width: grid.cell
          height: 76
          IslandButton {
            id: sc
            anchors.horizontalCenter: parent.horizontalCenter
            size: 50
            iconSize: modelData.image ? 28 : 24
            icon: modelData.image ? "" : (modelData.icon || "arrow-up-right")
            iconSource: modelData.image || ""
            accessibleName: modelData.label || I18n.t("Kısayol")
            onClicked: island.runShortcut(modelData)
          }
          Label {
            anchors.top: sc.bottom
            anchors.topMargin: 7
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 4
            horizontalAlignment: Text.AlignHCenter
            text: modelData.label || ""
            font.pixelSize: 12
            color: Theme.secondary
          }
        }
      }
    }

    // ---- quick timers
    Row {
      spacing: 8
      anchors.horizontalCenter: parent.horizontalCenter
      Icon {
        name: "timer"
        size: 20
        color: Theme.orange
        anchors.verticalCenter: parent.verticalCenter
      }
      Repeater {
        model: [1, 5, 10, 25, 50]
        delegate: IslandButton {
          required property int modelData
          size: 32
          fontSize: 13
          text: modelData + I18n.t(" dk")
          tint: Theme.orange
          fillColor: Qt.rgba(1, 0.62, 0.04, 0.16)
          accessibleName: modelData + I18n.t(" dakikalık zamanlayıcı başlat")
          onClicked: {
            island.timer.startCountdown(modelData * 60, modelData === 25 ? "Pomodoro" : "")
            island.setPage("timer")
          }
        }
      }
    }
  }
}
