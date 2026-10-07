import QtQuick
import "../components"

// Countdown timer and stopwatch.
Page {
  id: page

  property var island
  readonly property var timer: island.timer
  property int pickMinutes: 5
  property double lastDurationMs: 300000

  implicitHeight: timer.active ? 120 : 146

  // ---------------------------------------------------------------- running
  Item {
    anchors.fill: parent
    visible: timer.active

    Item {
      id: dial
      width: 92; height: 92
      anchors.left: parent.left
      anchors.leftMargin: 6
      anchors.verticalCenter: parent.verticalCenter

      ProgressRing {
        anchors.fill: parent
        thickness: 6
        progress: timer.mode === "countdown" ? 1 - timer.progress : (timer.elapsedMs % 60000) / 60000
        color: timer.ringing ? Theme.red : Theme.orange
      }
      Icon {
        anchors.centerIn: parent
        name: timer.ringing ? "alarm" : (timer.paused ? "pause" : "timer")
        size: 30
        color: timer.ringing ? Theme.red : Theme.orange
        SequentialAnimation on rotation {
          running: timer.ringing && !Theme.reduceMotion
          loops: Animation.Infinite
          NumberAnimation { to: -14; duration: 70 }
          NumberAnimation { to: 14; duration: 140 }
          NumberAnimation { to: 0; duration: 70 }
          PauseAnimation { duration: 500 }
          onRunningChanged: if (!running) parent.rotation = 0
        }
      }
    }

    Column {
      anchors.left: dial.right
      anchors.leftMargin: 18
      anchors.verticalCenter: parent.verticalCenter
      spacing: 0
      Label {
        text: timer.ringing ? I18n.t("Süre doldu") : timer.mode === "stopwatch" ? I18n.t("Kronometre") : (timer.label || I18n.t("Zamanlayıcı"))
        font.pixelSize: 13
        color: timer.ringing ? Theme.red : Theme.secondary
      }
      Label {
        text: timer.ringing ? "0:00" : timer.display
        font.pixelSize: 40
        font.weight: Font.Bold
        tabular: true
        color: timer.ringing ? Theme.red : Theme.orange
        Accessible.role: Accessible.StaticText
        Accessible.name: (timer.mode === "stopwatch" ? I18n.t("Geçen süre ") : I18n.t("Kalan süre ")) + text
      }
    }

    Column {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 8
      Row {
        spacing: 8
        anchors.right: parent.right
        IslandButton {
          visible: timer.mode === "countdown"
          size: 44
          text: "+1"
          fontSize: 14
          accessibleName: I18n.t("Bir dakika ekle")
          onClicked: { timer.addSeconds(60); if (timer.ringing || timer.paused && timer.remainingMs > 0) timer.togglePause() }
        }
        IslandButton {
          visible: !timer.ringing
          size: 44
          icon: timer.paused ? "play" : "pause"
          iconSize: 20
          tint: Theme.orange
          fillColor: Qt.rgba(1, 0.62, 0.04, 0.18)
          accessibleName: timer.paused ? I18n.t("Devam et") : I18n.t("Duraklat")
          onClicked: timer.togglePause()
        }
        IslandButton {
          visible: timer.ringing
          size: 44
          icon: "restart"
          iconSize: 20
          tint: Theme.orange
          fillColor: Qt.rgba(1, 0.62, 0.04, 0.18)
          accessibleName: I18n.t("Tekrarla")
          onClicked: timer.startCountdown(page.lastDurationMs / 1000, timer.label)
        }
        IslandButton {
          size: 44
          icon: timer.ringing ? "check" : "x"
          iconSize: 20
          prominent: timer.ringing
          tint: timer.ringing ? Theme.fg : Theme.fg
          accessibleName: timer.ringing ? I18n.t("Tamam") : I18n.t("İptal")
          hint: "Esc"
          onClicked: { timer.ringing ? timer.dismissRing() : timer.cancel(); if (!timer.active) island.collapse() }
        }
      }
    }
  }

  Connections {
    target: page.timer
    function onDurationMsChanged() { if (page.timer.durationMs > 0) page.lastDurationMs = page.timer.durationMs }
  }

  // ---------------------------------------------------------------- picker
  Column {
    anchors.fill: parent
    visible: !timer.active
    spacing: 12

    Item {
      width: parent.width
      height: 66

      IslandButton {
        id: minus
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        size: 44
        icon: "minus"
        accessibleName: I18n.t("Bir dakika azalt")
        onClicked: page.pickMinutes = Math.max(1, page.pickMinutes - (page.pickMinutes > 10 ? 5 : 1))
      }
      Column {
        anchors.centerIn: parent
        Label {
          anchors.horizontalCenter: parent.horizontalCenter
          text: page.pickMinutes + ":00"
          font.pixelSize: 42
          font.weight: Font.Bold
          tabular: true
          color: Theme.orange
        }
      }
      MouseArea {
        anchors.centerIn: parent
        width: 140; height: parent.height
        onWheel: wheel => page.pickMinutes = Math.max(1, Math.min(180, page.pickMinutes + (wheel.angleDelta.y > 0 ? 1 : -1)))
        Accessible.role: Accessible.SpinBox
        Accessible.name: I18n.t("Süre ") + I18n.count(page.pickMinutes, "minute")
      }
      IslandButton {
        anchors.right: start.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        size: 44
        icon: "plus"
        accessibleName: I18n.t("Bir dakika artır")
        onClicked: page.pickMinutes = Math.min(180, page.pickMinutes + (page.pickMinutes >= 10 ? 5 : 1))
      }
      IslandButton {
        id: start
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        size: 44
        icon: "play"
        iconSize: 20
        prominent: true
        tint: Theme.orange
        accessibleName: I18n.t("Zamanlayıcıyı başlat")
        onClicked: timer.startCountdown(page.pickMinutes * 60)
      }
    }

    Row {
      spacing: 6
      anchors.horizontalCenter: parent.horizontalCenter
      Repeater {
        model: [1, 3, 5, 10, 15, 25]
        delegate: IslandButton {
          required property int modelData
          size: 32
          fontSize: 13
          text: modelData + I18n.t(" dk")
          tint: page.pickMinutes === modelData ? Theme.orange : Theme.fg
          accessibleName: I18n.count(modelData, "minute")
          onClicked: page.pickMinutes = modelData
        }
      }
    }

    IslandButton {
      anchors.horizontalCenter: parent.horizontalCenter
      size: 34
      icon: "timer"
      text: I18n.t("Kronometre başlat")
      fontSize: 13
      filled: false
      tint: Theme.secondary
      onClicked: timer.startStopwatch()
    }
  }
}
