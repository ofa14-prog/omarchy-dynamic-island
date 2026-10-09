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
    // The AI tab names the agent that is running: one → its mark and name;
    // several → only their marks (two, then "…"); none → "AI".
    agent:  { icon: "sparkles", name: island.runningAgents.length === 1 ? island.profile(island.runningAgents[0]).name : "AI" },
    timer:  { icon: "timer",  name: I18n.t("Sayaç") },
    shelf:  { icon: "shelf",  name: I18n.t("Raf") }
  })
  readonly property var names: ({ home: I18n.t("Ana sayfa"), music: I18n.t("Müzik"),
    agent: "AI" + (island.runningAgents.length ? ": " + island.runningAgents.map(id => island.profile(id).product).join(", ") : ""),
    timer: I18n.t("Zamanlayıcı"), shelf: I18n.t("Raf") })

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

  // ---- selection
  // Its two edges move on their own springs, integrated here (the loop
  // runs only while they move): the edge on the way leads with a stiff
  // spring, the other follows with a soft one, so the selection stretches
  // toward its target like a drop and pulls itself together (iOS tab bar).
  // It can be grabbed and dragged along the bar; letting go lands it on the
  // nearest tab. With glass on it is a small glass lens
  // (components/LiquidGlass.qml, drawn only while the island is open);
  // otherwise the plain pill.
  readonly property real targetLeft: Math.max(0, currentIndex) * segment + 2
  readonly property real targetRight: targetLeft + segment - 4
  property real leftEdge: targetLeft
  property real rightEdge: targetRight
  property real goalLeft: targetLeft
  property real goalRight: targetRight
  property real velLeft: 0
  property real velRight: 0
  property real kLeft: 300
  property real kRight: 300
  property int lastIndex: currentIndex
  property bool dragging: false

  // Aim both edges, the one in the direction of travel leading.
  function aim(left, right) {
    var forward = (left + right) / 2 >= (leftEdge + rightEdge) / 2
    kLeft = forward ? 140 : 560
    kRight = forward ? 560 : 140
    goalLeft = left
    goalRight = right
    if (Theme.reduceMotion) { leftEdge = left; rightEdge = right; velLeft = velRight = 0; return }
    physics.running = true
  }
  Timer {
    id: physics
    interval: 16
    repeat: true
    onTriggered: {
      var dt = 0.016, steps = 2, h = dt / steps
      for (var i = 0; i < steps; i++) {
        var cl = 2 * 0.6 * Math.sqrt(strip.kLeft), cr = 2 * 0.6 * Math.sqrt(strip.kRight)
        strip.velLeft += (strip.kLeft * (strip.goalLeft - strip.leftEdge) - cl * strip.velLeft) * h
        strip.velRight += (strip.kRight * (strip.goalRight - strip.rightEdge) - cr * strip.velRight) * h
        strip.leftEdge += strip.velLeft * h
        strip.rightEdge += strip.velRight * h
      }
      // Never thinner than a dot, never inside out.
      if (strip.rightEdge - strip.leftEdge < 16) {
        var mid = (strip.leftEdge + strip.rightEdge) / 2
        strip.leftEdge = mid - 8; strip.rightEdge = mid + 8
      }
      var still = Math.abs(strip.goalLeft - strip.leftEdge) < 0.05 && Math.abs(strip.goalRight - strip.rightEdge) < 0.05
        && Math.abs(strip.velLeft) < 0.5 && Math.abs(strip.velRight) < 0.5
      if (still && !strip.dragging) {
        strip.leftEdge = strip.goalLeft; strip.rightEdge = strip.goalRight
        strip.velLeft = 0; strip.velRight = 0
        running = false
      }
    }
  }
  onCurrentIndexChanged: {
    // Computed here: the targetLeft/Right bindings may not have caught up.
    var tl = Math.max(0, currentIndex) * segment + 2, tr = tl + segment - 4
    if (lastIndex < 0 || currentIndex < 0) {
      physics.running = false
      leftEdge = goalLeft = tl; rightEdge = goalRight = tr; lastIndex = currentIndex; return
    }
    aim(tl, tr)
    lastIndex = currentIndex
    if (island.glassOn) lensFlash.restart()
  }
  // Size changes (pages added, width): follow without the drop.
  function settle() {
    if (physics.running || dragging || currentIndex !== lastIndex) return
    leftEdge = goalLeft = targetLeft; rightEdge = goalRight = targetRight
  }
  onTargetLeftChanged: settle()
  onTargetRightChanged: settle()

  // ---- grab and drag the selection
  MouseArea {
    id: grab
    z: 5
    x: strip.leftEdge
    width: Math.max(16, strip.rightEdge - strip.leftEdge)
    height: strip.height
    enabled: strip.currentIndex !== -1
    cursorShape: strip.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    preventStealing: true
    property real grabOffset: 0
    property real pressX: 0
    onPressed: mouse => {
      var sx = mapToItem(strip, mouse.x, 0).x
      pressX = sx
      grabOffset = sx - (strip.leftEdge + strip.rightEdge) / 2
    }
    onPositionChanged: mouse => {
      var sx = mapToItem(strip, mouse.x, 0).x
      if (!strip.dragging && Math.abs(sx - pressX) < 4) return
      if (!strip.dragging) { strip.dragging = true; if (island.glassOn) lensFlash.restart() }
      var half = (strip.segment - 4) / 2
      var c = Math.max(half + 2, Math.min(strip.segment * island.pages.length - half - 2, sx - grabOffset))
      strip.aim(c - half, c + half)
    }
    onReleased: mouse => {
      if (!strip.dragging) return
      strip.dragging = false
      var c = (strip.goalLeft + strip.goalRight) / 2
      var idx = Math.max(0, Math.min(island.pages.length - 1, Math.floor(c / strip.segment)))
      if (island.pages[idx] !== island.page) island.setPage(island.pages[idx])
      else strip.aim(strip.targetLeft, strip.targetRight)
    }
    onCanceled: { strip.dragging = false; strip.aim(strip.targetLeft, strip.targetRight) }
  }

  property real lensEnergy: 0
  SequentialAnimation {
    id: lensFlash
    NumberAnimation { target: strip; property: "lensEnergy"; to: 1; duration: 80 }
    NumberAnimation { target: strip; property: "lensEnergy"; to: 0; duration: 420; easing.type: Easing.OutCubic }
  }

  Rectangle {
    id: pill
    visible: strip.currentIndex !== -1 && !island.glassOn
    x: strip.leftEdge
    width: Math.max(height, strip.rightEdge - strip.leftEdge)
    height: parent.height - 4
    y: 2
    radius: height / 2
    color: Theme.fillHover
  }
  LiquidGlass {
    id: lens
    visible: strip.currentIndex !== -1 && island.glassOn && strip.shown
    x: 0
    y: -6
    width: strip.segment * island.pages.length
    height: parent.height + 12
    // Squeezes a little as it stretches, like a drop in motion.
    readonly property real stretch: Math.max(0, (strip.rightEdge - strip.leftEdge) - (strip.segment - 4))
    readonly property real squeeze: Math.min(5, stretch * 0.05)
    rectA: Qt.vector4d(strip.leftEdge, 8 + squeeze / 2, Math.max(10, strip.rightEdge - strip.leftEdge), strip.height - 4 - squeeze)
    radA: { var r = (strip.height - 4 - squeeze) / 2; return Qt.vector4d(r, r, r, r) }
    blend: 4
    tint: Qt.rgba(1, 1, 1, 0.13)
    light: island.glassLight
    rim: 1.25
    energy: strip.lensEnergy
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
      // Long labels (some languages) step down instead of spilling over:
      // first a 12 px font, then no icon, then an ellipsis.
      readonly property real room: strip.segment - 14
      TextMetrics { id: wide; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold; text: tab.info.name }
      readonly property int fontSize: 25 + wide.advanceWidth <= room ? 13 : 12
      // The AI tab always keeps the running agent's mark; its name gives way.
      readonly property bool showIcon: key === "agent" || 25 + Math.min(wide.advanceWidth, label.implicitWidth) <= room
      // Several agents running: their marks side by side, no name.
      readonly property bool marksOnly: key === "agent" && island.runningAgents.length > 1
      Row {
        visible: tab.marksOnly
        anchors.centerIn: parent
        spacing: 5
        Repeater {
          model: island.runningAgents.slice(0, 2)
          delegate: Icon {
            required property string modelData
            anchors.verticalCenter: parent.verticalCenter
            size: 18
            source: island.logoFor(modelData)
            name: source ? "" : "sparkles"
            color: island.profile(modelData).color
          }
        }
        Label {
          visible: island.runningAgents.length > 2
          anchors.verticalCenter: parent.verticalCenter
          text: "…"
          font.pixelSize: 13
          color: tab.current ? Theme.fg : Theme.secondary
        }
      }
      Item {
        visible: !tab.marksOnly
        anchors.centerIn: parent
        width: (tab.showIcon ? 25 : 0) + label.width
        height: 18
        Icon {
          visible: tab.showIcon
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          size: 18
          readonly property string running: tab.key === "agent" && island.runningAgents.length === 1 ? island.runningAgents[0] : ""
          source: running ? island.logoFor(running) : ""
          name: source ? "" : tab.info.icon
          color: running ? island.profile(running).color : tab.current ? Theme.fg : Theme.secondary
        }
        Label {
          id: label
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: Math.min(implicitWidth, tab.room - (tab.showIcon ? 25 : 0))
          text: tab.info.name
          font.pixelSize: tab.fontSize
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
