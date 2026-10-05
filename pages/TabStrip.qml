import QtQuick
import "../components"

// Page switcher across the top of the open island: a segmented control with
// fixed, equal segments (nothing reflows when the selection changes) and one
// selection pill that glides between them without overshoot.
Page {
  id: strip

  property var island
  height: 36

  readonly property var meta: ({
    home:   { icon: "home",   name: I18n.t("Ana") },
    music:  { icon: "music",  name: I18n.t("Müzik") },
    agent:  { icon: island.agentLogo ? "" : "sparkles", name: island.agentName },
    timer:  { icon: "timer",  name: I18n.t("Sayaç") },
    shelf:  { icon: "shelf",  name: I18n.t("Raf") }
  })
  readonly property var names: ({ home: I18n.t("Ana sayfa"), music: I18n.t("Müzik"), agent: island.agentProduct, timer: I18n.t("Zamanlayıcı"), shelf: I18n.t("Raf") })

  readonly property int closeSize: 36
  readonly property real segment: (width - closeSize - 8) / Math.max(1, island.pages.length)
  readonly property int currentIndex: island.pages.indexOf(island.page)

  Accessible.role: Accessible.PageTabList

  Rectangle {
    id: track
    width: strip.segment * island.pages.length
    height: parent.height
    radius: height / 2
    color: Qt.rgba(1, 1, 1, 0.06)
  }

  Rectangle {
    id: pill
    visible: strip.currentIndex !== -1
    width: strip.segment - 4
    height: parent.height - 4
    y: 2
    x: Math.max(0, strip.currentIndex) * strip.segment + 2
    radius: height / 2
    color: Theme.fillHover
    Behavior on x {
      enabled: !Theme.reduceMotion
      SpringAnimation { spring: 5.0; damping: 0.7; epsilon: 0.1 }
    }
  }

  Repeater {
    model: island.pages
    delegate: Item {
      id: tab
      required property string modelData
      required property int index
      readonly property string key: modelData
      readonly property bool current: island.page === key
      readonly property var info: strip.meta[key] || { icon: "", name: key }
      x: index * strip.segment
      width: strip.segment
      height: strip.height
      activeFocusOnTab: true

      Accessible.role: Accessible.PageTab
      Accessible.name: strip.names[key] || key
      Accessible.selected: current
      Accessible.onPressAction: island.setPage(key)
      Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) { island.setPage(key); event.accepted = true }
      }

      Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: height / 2
        color: "transparent"
        border.color: Theme.focusRing
        border.width: 2
        visible: tab.activeFocus
      }

      // Icon + label measured as one block and centered in the segment.
      Item {
        anchors.centerIn: parent
        width: 18 + 7 + Math.ceil(label.implicitWidth)
        height: 18
        Icon {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          size: 18
          name: tab.info.icon
          source: tab.key === "agent" ? island.agentLogo : ""
          color: tab.current ? Theme.fg : Theme.secondary
        }
        Label {
          id: label
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: tab.info.name
          font.pixelSize: 13
          strong: tab.current
          color: tab.current ? Theme.fg : Theme.secondary
          Behavior on color { ColorAnimation { duration: Theme.ms(160) } }
        }
      }

      // Badges: pending permissions, shelf count.
      Rectangle {
        readonly property int n: tab.key === "agent" ? island.agents.pending.length : tab.key === "shelf" ? island.shelf.count : 0
        visible: n > 0 && !tab.current
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 4
        width: Math.max(16, badgeText.implicitWidth + 8); height: 16; radius: 8
        color: tab.key === "agent" ? island.agentColor : Theme.blue
        Label { id: badgeText; anchors.centerIn: parent; text: parent.n; font.pixelSize: 10; strong: true; horizontalAlignment: Text.AlignHCenter }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: island.setPage(tab.key)
      }
    }
  }

  IslandButton {
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    size: strip.closeSize
    icon: "chevron-up"
    iconSize: 18
    filled: false
    tint: Theme.secondary
    accessibleName: I18n.t("Adayı kapat")
    hint: "Esc"
    onClicked: island.collapse()
  }
}
