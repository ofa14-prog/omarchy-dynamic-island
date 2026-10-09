import QtQuick
import "../components"

// Now playing: artwork, title, scrubber, transport.
Page {
  id: page

  property var island
  readonly property var music: island.music
  implicitHeight: 176

  Item {
    id: header
    width: parent.width
    height: 72

    Art {
      id: art
      width: 72; height: 72
      radius: 16
      source: music.artUrl
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: music.raise()
        Accessible.role: Accessible.Button
        Accessible.name: I18n.t("Oynatıcıyı göster")
      }
    }

    Column {
      anchors.left: art.right
      anchors.leftMargin: 16
      anchors.right: eq.left
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 3
      Label {
        width: parent.width
        text: music.title || I18n.t("Bir şey çalmıyor")
        font.pixelSize: 16
        strong: true
      }
      Label {
        width: parent.width
        text: music.artist || music.identity
        font.pixelSize: 14
        color: Theme.secondary
      }
      Label {
        width: parent.width
        visible: music.album !== ""
        text: music.album
        font.pixelSize: 12
        color: Theme.tertiary
      }
    }

    Equalizer {
      id: eq
      anchors.right: parent.right
      anchors.rightMargin: 4
      anchors.verticalCenter: parent.verticalCenter
      playing: music.playing
      color: music.accent
      maxHeight: 22
    }
  }

  // ---- scrubber
  Item {
    id: scrub
    anchors.top: header.bottom
    anchors.topMargin: 16
    width: parent.width
    height: 24
    visible: music.length > 0

    property bool dragging: false
    property real dragFraction: 0
    readonly property real fraction: dragging ? dragFraction : (music.length > 0 ? music.position / music.length : 0)

    Label {
      id: elapsed
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: 58
      text: island.timer.format(scrub.fraction * music.length * 1000, false)
      font.pixelSize: 12
      tabular: true
      color: Theme.secondary
    }
    Label {
      id: remain
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: 64
      horizontalAlignment: Text.AlignRight
      text: "-" + island.timer.format((1 - scrub.fraction) * music.length * 1000, false)
      font.pixelSize: 12
      tabular: true
      color: Theme.secondary
    }

    Item {
      id: track
      anchors.left: elapsed.right
      anchors.right: remain.left
      anchors.verticalCenter: parent.verticalCenter
      height: 22

      // The bar thickens under the pointer, as in iOS Control Center.
      readonly property real thickness: trackMouse.containsMouse || scrub.dragging ? 10 : 6
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: track.thickness
        radius: height / 2
        color: Theme.fill
GlassSheen { strength: 0.6 }
        Behavior on height { NumberAnimation { duration: Theme.ms(160); easing.type: Easing.OutCubic } }
        Rectangle {
          width: Math.max(parent.height, parent.width * scrub.fraction)
          height: parent.height
          radius: height / 2
          color: scrub.dragging ? Theme.fg : Qt.rgba(1, 1, 1, 0.85)
        }
      }

      MouseArea {
        id: trackMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: music.canSeek
        cursorShape: music.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
        preventStealing: true
        function fractionAt(x) { return Math.max(0, Math.min(1, x / width)) }
        onPressed: mouse => { scrub.dragging = true; scrub.dragFraction = fractionAt(mouse.x) }
        onPositionChanged: mouse => { if (scrub.dragging) scrub.dragFraction = fractionAt(mouse.x) }
        onReleased: { music.seek(scrub.dragFraction * music.length); scrub.dragging = false }
        onCanceled: scrub.dragging = false
      }

      Accessible.role: Accessible.Slider
      Accessible.name: I18n.t("Şarkı konumu")
      activeFocusOnTab: music.canSeek
      Keys.onLeftPressed: music.seek(music.position - 5)
      Keys.onRightPressed: music.seek(music.position + 5)
    }
  }

  // ---- transport
  Row {
    id: transport
    anchors.top: header.bottom
    anchors.topMargin: 48
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 28

    IslandButton {
      size: 46; iconSize: 24
      icon: "prev"
      filled: false
      enabled2: music.canPrevious || music.canSeek
      accessibleName: I18n.t("Önceki parça")
      onClicked: music.previous()
    }
    IslandButton {
      size: 52; iconSize: 30
      icon: music.playing ? "pause" : "play"
      filled: false
      accessibleName: music.playing ? I18n.t("Duraklat") : I18n.t("Oynat")
      hint: I18n.t("Boşluk")
      onClicked: music.togglePlaying()
    }
    IslandButton {
      size: 46; iconSize: 24
      icon: "next"
      filled: false
      enabled2: music.canNext
      accessibleName: I18n.t("Sonraki parça")
      onClicked: music.next()
    }
  }

  // ---- player switcher
  // Only with several players. The chip names the one shown; click it for
  // the list and pick the one to follow (it stays picked until it closes).
  property bool pickerOpen: false
  onShownChanged: if (!shown) pickerOpen = false

  Rectangle {
    id: chip
    visible: music.choices.length > 1
    anchors.left: parent.left
    anchors.verticalCenter: transport.verticalCenter
    width: Math.min(124, chipRow.implicitWidth + 22)
    height: 30
    radius: 15
    color: chipMouse.containsMouse || page.pickerOpen ? Theme.fillHover : Theme.fill
    GlassSheen { lit: chipMouse.containsMouse }
    Behavior on color { ColorAnimation { duration: Theme.ms(140) } }

    Row {
      id: chipRow
      anchors.centerIn: parent
      spacing: 6
      Icon {
        anchors.verticalCenter: parent.verticalCenter
        source: music.iconOf(music.player)
        name: source ? "" : "music"
        size: 15
        color: Theme.secondary
      }
      Label {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, 64)
        text: music.nameOf(music.player)
        font.pixelSize: 12
        color: Theme.fg
      }
      Label {
        anchors.verticalCenter: parent.verticalCenter
        text: music.choices.length
        font.pixelSize: 11
        tabular: true
        color: Theme.tertiary
      }
    }
    MouseArea {
      id: chipMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      // Click: the list. Right-click or scroll: straight to the next one.
      onClicked: event => event.button === Qt.RightButton ? music.cycle() : (page.pickerOpen = !page.pickerOpen)
      onWheel: wheel => music.cycle()
    }
    Accessible.role: Accessible.ComboBox
    Accessible.name: I18n.t("Oynatıcı: ") + music.nameOf(music.player)
    Accessible.description: I18n.t("%1 oynatıcı var. Tıkla: listeyi aç. Sağ tık: sıradaki.").arg(music.choices.length)
    Accessible.onPressAction: page.pickerOpen = !page.pickerOpen
  }

  // Click anywhere else on the page closes the list.
  MouseArea {
    anchors.fill: parent
    visible: page.pickerOpen
    z: 9
    onClicked: page.pickerOpen = false
  }

  Rectangle {
    id: picker
    z: 10
    visible: opacity > 0.01
    opacity: page.pickerOpen && chip.visible ? 1 : 0
    scale: page.pickerOpen ? 1 : 0.94
    transformOrigin: Item.BottomLeft
    Behavior on opacity { NumberAnimation { duration: Theme.ms(140) } }
    Behavior on scale {
      enabled: !Theme.reduceMotion
      SpringAnimation { spring: 5; damping: 0.45; epsilon: 0.005 }
    }
    anchors.left: parent.left
    anchors.bottom: chip.top
    anchors.bottomMargin: 6
    width: Math.min(parent.width, 320)
    height: Math.min(pickerList.contentHeight + 40, chip.y - 6)
    radius: 16
    color: Theme.glass ? Qt.rgba(0.11, 0.11, 0.12, 0.88) : "#1c1c1e"
    GlassSheen {}
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.10)

    Item {
      id: pickerHead
      width: parent.width
      height: 30
      Label {
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        text: I18n.t("Oynatıcı seç")
        font.pixelSize: 12
        color: Theme.tertiary
      }
      Label {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        visible: music.pinned
        text: I18n.t("Otomatik")
        font.pixelSize: 12
        color: autoMouse.containsMouse ? Theme.fg : Theme.blue
        MouseArea {
          id: autoMouse
          anchors.fill: parent
          anchors.margins: -6
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: { music.unpin(); page.pickerOpen = false }
          Accessible.role: Accessible.Button
          Accessible.name: I18n.t("Otomatik: çalanı göster")
        }
      }
    }

    ListView {
      id: pickerList
      anchors.top: pickerHead.bottom
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 6
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: 6
      anchors.topMargin: 0
      clip: true
      spacing: 2
      boundsBehavior: Flickable.StopAtBounds
      model: music.choices
      delegate: Rectangle {
        id: option
        required property var modelData
        readonly property bool current: modelData === music.player
        width: ListView.view.width
        height: 40
        radius: 11
        color: optMouse.containsMouse ? Theme.fillHover : current ? Theme.fill : "transparent"
        GlassSheen { strength: 0.8; visible: Theme.glass && parent.current }

        Icon {
          id: optIcon
          x: 10
          anchors.verticalCenter: parent.verticalCenter
          source: music.iconOf(option.modelData)
          name: source ? "" : "music"
          size: 20
          color: Theme.secondary
        }
        Column {
          anchors.left: optIcon.right
          anchors.leftMargin: 10
          anchors.right: optState.left
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          spacing: 1
          Label {
            width: parent.width
            text: music.nameOf(option.modelData)
            font.pixelSize: 13
            strong: option.current
          }
          Label {
            width: parent.width
            text: (option.modelData.trackTitle || "") + (option.modelData.trackArtist ? " — " + option.modelData.trackArtist : "")
            font.pixelSize: 11
            color: Theme.secondary
          }
        }
        Row {
          id: optState
          anchors.right: parent.right
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          spacing: 8
          Equalizer {
            anchors.verticalCenter: parent.verticalCenter
            visible: option.modelData.isPlaying
            playing: true
            color: Theme.green
            barWidth: 2
            maxHeight: 12
          }
          Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: option.current
            name: "check"
            size: 16
            color: Theme.blue
          }
        }
        MouseArea {
          id: optMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: { music.select(option.modelData); page.pickerOpen = false }
        }
        Accessible.role: Accessible.ListItem
        Accessible.name: music.nameOf(option.modelData) + ", " + (option.modelData.trackTitle || "") + (option.modelData.isPlaying ? I18n.t(", çalıyor") : "")
      }
    }
  }
}
