import QtQuick
import "../components"

// File shelf. Drop onto the island to park files; drag them back out, click
// to open, right-click to reveal in Files, × to drop from the shelf.
Page {
  id: page

  property var island
  readonly property var shelf: island.shelf

  implicitHeight: shelf.count === 0 ? 124 : 172

  onShownChanged: if (shown) shelf.pruneMissing()

  // ---- empty / drop target
  Rectangle {
    anchors.fill: parent
    anchors.bottomMargin: 4
    visible: shelf.count === 0 || island.dragHover
    z: 2
    radius: 18
    color: island.dragHover ? Qt.rgba(0.04, 0.52, 1, 0.16) : "transparent"
    border.width: 1.5
    border.color: island.dragHover ? Theme.blue : Theme.fill
    Behavior on color { ColorAnimation { duration: Theme.ms(160) } }

    Column {
      anchors.centerIn: parent
      spacing: 6
      Icon {
        anchors.horizontalCenter: parent.horizontalCenter
        name: "shelf"
        size: 30
        color: island.dragHover ? Theme.blue : Theme.secondary
        scale: island.dragHover ? 1.15 : 1
        Behavior on scale {
          enabled: !Theme.reduceMotion
          SpringAnimation { spring: 4; damping: 0.3; epsilon: 0.005 }
        }
      }
      Label {
        anchors.horizontalCenter: parent.horizontalCenter
        text: island.dragHover ? I18n.t("Rafa bırak") : I18n.t("Dosyaları buraya sürükle")
        font.pixelSize: 14
        strong: true
        color: island.dragHover ? Theme.fg : Theme.secondary
      }
      Label {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: !island.dragHover
        text: I18n.t("ya da tıkla: kopyaladığını rafa ekle")
        font.pixelSize: 12
        color: Theme.tertiary
      }
    }
    MouseArea {
      anchors.fill: parent
      enabled: shelf.count === 0 && !island.dragHover
      cursorShape: Qt.PointingHandCursor
      onClicked: shelf.addFromClipboard()
      Accessible.role: Accessible.Button
      Accessible.name: I18n.t("Panodakini rafa ekle")
    }
  }

  // ---- items
  ListView {
    id: list
    visible: shelf.count > 0
    anchors.left: parent.left
    anchors.right: parent.right
    height: 104
    orientation: ListView.Horizontal
    spacing: 8
    clip: true
    model: shelf.items
    boundsBehavior: Flickable.StopAtBounds
    activeFocusOnTab: true
    keyNavigationEnabled: true

    Accessible.role: Accessible.List
    Accessible.name: I18n.t("Raf, ") + shelf.count + I18n.t(" dosya")

    add: Transition {
      enabled: !Theme.reduceMotion
      NumberAnimation { property: "scale"; from: 0.4; to: 1; duration: 320; easing.type: Easing.OutBack }
      NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
    }
    displaced: Transition {
      NumberAnimation { properties: "x"; duration: Theme.ms(260); easing.type: Easing.OutCubic }
    }

    delegate: Item {
      id: tile
      required property var modelData
      required property int index
      width: 86
      height: 104

      Accessible.role: Accessible.ListItem
      Accessible.name: modelData.name

      Rectangle {
        id: card
        width: 86; height: 74
        radius: 16
        color: tileMouse.containsMouse || tile.ListView.isCurrentItem && list.activeFocus ? Theme.fillHover : Theme.fill
        scale: tileMouse.pressed ? 0.94 : 1
        Behavior on scale {
          enabled: !Theme.reduceMotion
          SpringAnimation { spring: Theme.snapSpring; damping: Theme.snapDamping; epsilon: 0.002 }
        }

        Art {
          anchors.centerIn: parent
          width: 62; height: 56
          radius: 8
          visible: tile.modelData.isImage
          source: tile.modelData.isImage ? "file://" + tile.modelData.path : ""
          placeholder: "image"
        }
        Column {
          anchors.centerIn: parent
          visible: !tile.modelData.isImage
          spacing: 2
          Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: tile.modelData.ext === "" ? "folder" : tile.modelData.ext === "pdf" ? "file-pdf" : ["zip", "tar", "gz", "xz", "7z", "zst"].indexOf(tile.modelData.ext) !== -1 ? "file-zip" : ["mp3", "flac", "wav", "ogg", "m4a"].indexOf(tile.modelData.ext) !== -1 ? "music" : ["mp4", "mkv", "webm", "mov"].indexOf(tile.modelData.ext) !== -1 ? "video" : "file"
            size: 28
            color: Theme.secondary
          }
          Label {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: tile.modelData.ext !== ""
            text: tile.modelData.ext.toUpperCase()
            font.pixelSize: 10
            strong: true
            color: Theme.tertiary
          }
        }

        // Remove (hover reveals it).
        IslandButton {
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: -4
          size: 22
          iconSize: 12
          icon: "x"
          fillColor: "#3a3a3c"
          opacity: tileMouse.containsMouse || hovered ? 1 : 0
          visible: opacity > 0
          accessibleName: tile.modelData.name + I18n.t(" dosyasını raftan kaldır")
          onClicked: shelf.remove(tile.modelData.path)
          Behavior on opacity { NumberAnimation { duration: Theme.ms(120) } }
        }

        MouseArea {
          id: tileMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          drag.target: dragProxy
          onClicked: mouse => mouse.button === Qt.RightButton ? shelf.reveal(tile.modelData.path) : shelf.open(tile.modelData.path)
          onReleased: dragProxy.Drag.active = false
          z: -1
        }

        // Dragging the tile hands a real file URI to whatever app is under
        // the pointer (browser upload, chat, Files, editor…).
        Item {
          id: dragProxy
          width: 1; height: 1
          Drag.active: tileMouse.drag.active
          Drag.dragType: Drag.Automatic
          Drag.supportedActions: Qt.CopyAction
          Drag.mimeData: ({ "text/uri-list": shelf.uriList([tile.modelData]) })
          Drag.onDragFinished: dropAction => { dragProxy.x = 0; dragProxy.y = 0 }
        }
      }

      Label {
        anchors.top: card.bottom
        anchors.topMargin: 5
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: tile.modelData.name
        font.pixelSize: 12
        elide: Text.ElideMiddle
        color: Theme.secondary
      }

      Keys.onReturnPressed: shelf.open(modelData.path)
      Keys.onDeletePressed: shelf.remove(modelData.path)
    }
  }

  Row {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 2
    anchors.horizontalCenter: parent.horizontalCenter
    visible: shelf.count > 0
    spacing: 8
    IslandButton {
      size: 32
      icon: "plus"
      text: I18n.t("Panodan ekle")
      fontSize: 13
      accessibleName: I18n.t("Panodakini rafa ekle")
      onClicked: shelf.addFromClipboard()
    }
    IslandButton {
      size: 32
      icon: "copy"
      text: I18n.t("Yolları kopyala")
      fontSize: 13
      accessibleName: I18n.t("Tüm dosya yollarını panoya kopyala")
      onClicked: shelf.copyPaths()
    }
    IslandButton {
      size: 32
      icon: "trash"
      text: I18n.t("Rafı boşalt")
      fontSize: 13
      tint: Theme.red
      accessibleName: I18n.t("Raftaki tüm dosyaları kaldır (dosyalar silinmez)")
      onClicked: shelf.clear()
    }
  }
}
