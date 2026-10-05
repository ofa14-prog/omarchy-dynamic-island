import QtQuick
import "../components"

// Brief banner: icon (or artwork / an agent's mark) on the left, two lines of text.
Page {
  id: view

  property var island
  readonly property var info: island.peekData
  readonly property bool isAgent: info.icon.indexOf("agent") === 0
  readonly property bool isApp: info.icon.indexOf("app:") === 0
  readonly property string agentLogo: isAgent ? island.logoFor(info.icon.split(":")[1] || island.agentId) : ""

  Accessible.role: Accessible.AlertMessage
  Accessible.name: info.title + (info.subtitle ? ", " + info.subtitle : "")

  Item {
    id: lead
    x: 14
    width: 38; height: 38
    anchors.verticalCenter: parent.verticalCenter

    Art {
      anchors.fill: parent
      visible: view.info.icon === "music"
      source: view.island.music.artUrl
      radius: 10
    }
    Rectangle {
      anchors.fill: parent
      visible: view.info.icon !== "music"
      radius: width / 2
      color: Qt.rgba(view.info.tint.r, view.info.tint.g, view.info.tint.b, 0.18)
      Icon {
        anchors.centerIn: parent
        size: 20
        name: view.isApp ? "" : view.isAgent ? (view.agentLogo ? "" : "sparkles") : view.info.icon
        source: view.isApp ? view.info.icon.substring(4) : view.agentLogo
        color: view.info.tint
      }
    }
  }

  Column {
    anchors.left: lead.right
    anchors.leftMargin: 12
    anchors.right: parent.right
    anchors.rightMargin: view.info.icon === "music" ? 50 : 20
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2
    Label {
      width: parent.width
      text: view.info.title
      font.pixelSize: 15
      strong: true
    }
    Label {
      width: parent.width
      visible: text !== ""
      text: view.info.subtitle
      font.pixelSize: 13
      color: Theme.secondary
    }
  }

  Equalizer {
    visible: view.info.icon === "music"
    anchors.right: parent.right
    anchors.rightMargin: 18
    anchors.verticalCenter: parent.verticalCenter
    playing: view.island.music.playing
    color: view.island.music.accent
    maxHeight: 20
  }
}
