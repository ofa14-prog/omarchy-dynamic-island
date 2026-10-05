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
}
