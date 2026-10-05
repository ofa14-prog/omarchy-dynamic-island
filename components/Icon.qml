import QtQuick
import QtQuick.Effects

// An icon from ../icons (Reicon, white SVG) tinted to `color`, or any image
// file shown as-is (`source`, for original brand marks). Always exactly
// `size` square and centered, so it sits dead-center in whatever holds it.
Item {
  id: icon

  property string name: ""
  property string source: ""          // absolute path/URL: shown untinted
  property color color: Theme.fg
  property int size: 18

  readonly property bool tinted: source === ""
  readonly property url url: source !== "" ? (source.indexOf("/") === 0 ? "file://" + source : source)
    : name !== "" ? Qt.resolvedUrl("../icons/" + name + ".svg") : ""

  implicitWidth: size
  implicitHeight: size
  width: size
  height: size

  Accessible.ignored: true

  // The SVGs are pure white, so colorization (luma × color) yields exactly
  // `color` with the original antialiased edges.
  Image {
    id: image
    anchors.fill: parent
    source: icon.url
    sourceSize.width: icon.size * 3
    sourceSize.height: icon.size * 3
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
    layer.enabled: icon.tinted && !Qt.colorEqual(icon.color, "#ffffff")
    layer.effect: MultiEffect {
      colorization: 1.0
      colorizationColor: icon.color
    }
    opacity: icon.tinted ? icon.color.a : 1
  }
}
