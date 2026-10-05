import QtQuick
import Quickshell.Widgets

// Rounded album art with a glyph placeholder while nothing (or nothing yet)
// has loaded.
ClippingRectangle {
  id: art

  property string source: ""
  property string placeholder: "music"
  readonly property bool ready: image.status === Image.Ready

  color: Theme.fill
  radius: Math.round(width * 0.22)

  Accessible.role: Accessible.Graphic
  Accessible.name: I18n.t("Albüm kapağı")

  Icon {
    anchors.centerIn: parent
    visible: !art.ready && art.placeholder !== ""
    name: art.placeholder
    size: Math.round(art.width * 0.5)
    color: Theme.secondary
  }

  Image {
    id: image
    anchors.fill: parent
    source: art.source
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: true
    smooth: true
    mipmap: true
    sourceSize.width: 256
    sourceSize.height: 256
    opacity: art.ready ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.ms(220) } }
  }
}
