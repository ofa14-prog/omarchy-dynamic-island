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
        Column {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 6
          // Language: the current flag; click for the list.
          Rectangle {
            id: langButton
            width: 28; height: 28
            radius: 14
            color: langMouse.containsMouse || page.langOpen ? Theme.fillHover : Theme.fill
            Flag {
              anchors.centerIn: parent
              code: I18n.lang
              size: 18
            }
            MouseArea {
              id: langMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: page.langOpen = !page.langOpen
            }
            Accessible.role: Accessible.ComboBox
            Accessible.name: I18n.t("Dil") + ": " + (I18n.languages.find(l => l.code === I18n.lang) || {}).name
            Accessible.onPressAction: page.langOpen = !page.langOpen
          }
          // Refresh: click restarts the Omarchy shell (bar and island reload,
          // the island drops back in); right-click only clears a stuck island.
          IslandButton {
            size: 28
            iconSize: 15
            icon: "restart"
            accessibleName: I18n.t("Omarchy kabuğunu yeniden başlat")
            hint: I18n.t("Sağ tık: yalnızca adayı yenile")
            onClicked: island.restartShell()
            onRightClicked: island.resetIsland()
          }
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

  // ---- language list
  property bool langOpen: false
  onShownChanged: if (!shown) langOpen = false

  MouseArea {
    anchors.fill: parent
    visible: page.langOpen
    z: 9
    onClicked: page.langOpen = false
  }
  Rectangle {
    z: 10
    anchors.right: parent.right
    y: 64
    width: 176
    height: langList.implicitHeight + 12
    radius: 16
    color: "#1c1c1e"
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.10)
    opacity: page.langOpen ? 1 : 0
    visible: opacity > 0.01
    scale: page.langOpen ? 1 : 0.94
    transformOrigin: Item.TopRight
    Behavior on opacity { NumberAnimation { duration: Theme.ms(140) } }
    Behavior on scale {
      enabled: !Theme.reduceMotion
      SpringAnimation { spring: 5; damping: 0.45; epsilon: 0.005 }
    }

    Column {
      id: langList
      x: 6; y: 6
      width: parent.width - 12
      spacing: 2
      Repeater {
        model: I18n.languages
        delegate: Rectangle {
          id: langRow
          required property var modelData
          readonly property bool current: modelData.code === I18n.lang
          width: parent.width
          height: 36
          radius: 11
          color: rowMouse.containsMouse ? Theme.fillHover : current ? Theme.fill : "transparent"
          Flag {
            id: rowFlag
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            code: langRow.modelData.code
            size: 20
          }
          Label {
            anchors.left: rowFlag.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: langRow.modelData.name
            font.pixelSize: 13
            strong: langRow.current
          }
          Icon {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: langRow.current
            name: "check"
            size: 15
            color: Theme.blue
          }
          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { island.setConfig("language", langRow.modelData.code); page.langOpen = false }
          }
          Accessible.role: Accessible.ListItem
          Accessible.name: langRow.modelData.name
        }
      }
    }
  }
}
