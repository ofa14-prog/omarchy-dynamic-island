import QtQuick
import "../components"

// Home: time and battery at a glance, the usage of every agent that is
// running (rings, like Claude Code's), and the launch shortcuts as a grid.
Page {
  id: page

  property var island
  implicitHeight: col.implicitHeight + 8

  // Usage cards: every installed agent with usage data (running ones first).
  readonly property var usageAgents: island.usageAgents

  component Gauge: Column {
    id: gauge
    property real value: 0
    property string caption: ""
    property color tone: island.agentColor
    property int ring: 40
    spacing: 4
    Item {
      width: gauge.ring; height: gauge.ring
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
        font.pixelSize: gauge.ring >= 40 ? 12 : 11
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
    spacing: 18

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

    // ---- the bar's center is under the island: offer to make room
    Rectangle {
      visible: island.barHint
      width: parent.width
      height: 52
      radius: 18
      color: Theme.fill
      Icon {
        id: barIcon
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        name: "sparkles"
        size: 18
        color: Theme.secondary
      }
      Column {
        anchors.left: barIcon.right
        anchors.leftMargin: 12
        anchors.right: barButtons.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Label {
          width: parent.width
          text: island.onIslandsBar ? I18n.t("Bar'ın ortası dolu") : I18n.t("Önerilen: Islands bar")
          font.pixelSize: 13
          strong: true
        }
        Label {
          width: parent.width
          text: island.onIslandsBar ? I18n.t("Öğeler sağa taşınır, geri alınabilir") : I18n.t("Ada onunla tasarlandı, geri alınabilir")
          font.pixelSize: 12
          color: Theme.secondary
        }
      }
      Row {
        id: barButtons
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        IslandButton {
          size: 34
          text: island.onIslandsBar ? I18n.t("Yer aç") : I18n.t("Kur")
          fontSize: 13
          prominent: true
          tint: Theme.blue
          accessibleName: island.onIslandsBar ? I18n.t("Bar'ın ortasındaki öğeleri sağa taşı") : I18n.t("Islands bar'ı kur ve bar'ın ortasını boşalt")
          onClicked: island.makeRoomInBar()
        }
        IslandButton {
          size: 34
          icon: "x"
          iconSize: 14
          filled: false
          tint: Theme.secondary
          accessibleName: I18n.t("Bir daha gösterme")
          onClicked: island.setConfig("barHintDismissed", true)
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

    // ---- usage: one card per installed agent that reports usage (running
    // ones first), its mark and two rings: the 5-hour and the weekly limit.
    Flow {
      id: usageFlow
      width: parent.width
      spacing: 10
      readonly property var shown: page.usageAgents.filter(id => {
        var u = island.agents.usageOf(id)
        return u.session >= 0 || u.weekly >= 0
      })
      visible: shown.length > 0
      Repeater {
        model: usageFlow.shown
        delegate: Rectangle {
          id: card
          required property string modelData
          readonly property var u: island.agents.usageOf(modelData)
          readonly property color tint: island.profile(modelData).color
          width: cardRow.implicitWidth + 24
          height: 74
          radius: 20
          color: Theme.fill
          Row {
            id: cardRow
            anchors.centerIn: parent
            spacing: 11
            Icon {
              anchors.verticalCenter: parent.verticalCenter
              source: island.logoFor(card.modelData)
              name: source ? "" : "sparkles"
              color: card.tint
              size: 22
            }
            Gauge {
              visible: card.u.session >= 0
              ring: 36
              value: Math.max(0, card.u.session)
              caption: I18n.t("5 sa")
              tone: value >= 0.9 ? Theme.red : value >= 0.7 ? Theme.orange : card.tint
            }
            Gauge {
              visible: card.u.weekly >= 0
              ring: 36
              value: Math.max(0, card.u.weekly)
              caption: I18n.t("Hafta")
              tone: value >= 0.9 ? Theme.red : value >= 0.7 ? Theme.orange : card.tint
            }
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: island.showAgent(card.modelData)
          }
          Accessible.role: Accessible.Button
          Accessible.name: island.profile(modelData).product + ", " + I18n.t("5 sa") + " " + Math.round(Math.max(0, u.session) * 100) + "%, "
            + I18n.t("Hafta") + " " + Math.round(Math.max(0, u.weekly) * 100) + "%"
        }
      }
    }

    // ---- shortcuts: a grid of tiles (icon and name side by side), three
    // per row, so marks have room and the page stays short.
    Grid {
      id: grid
      width: parent.width
      columns: 3
      columnSpacing: 8
      rowSpacing: 8
      readonly property real cell: (width - columnSpacing * (columns - 1)) / columns

      Repeater {
        model: island.shortcuts
        delegate: Rectangle {
          id: tile
          required property var modelData
          width: grid.cell
          height: 46
          radius: 16
          color: tileMouse.pressed ? Theme.fillPressed : tileMouse.containsMouse ? Theme.fillHover : Theme.fill
          scale: tileMouse.pressed ? 0.96 : 1
          Behavior on color { ColorAnimation { duration: Theme.ms(120) } }
          Behavior on scale {
            enabled: !Theme.reduceMotion
            SpringAnimation { spring: Theme.snapSpring; damping: Theme.snapDamping; epsilon: 0.002 }
          }
          Icon {
            id: tileIcon
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            size: 22
            name: tile.modelData.image ? "" : (tile.modelData.icon || "arrow-up-right")
            source: tile.modelData.image || ""
            color: Theme.fg
          }
          Label {
            anchors.left: tileIcon.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: tile.modelData.label || ""
            font.pixelSize: 13
          }
          MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: island.runShortcut(tile.modelData)
          }
          Accessible.role: Accessible.Button
          Accessible.name: modelData.label || I18n.t("Kısayol")
          Accessible.onPressAction: island.runShortcut(modelData)
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
