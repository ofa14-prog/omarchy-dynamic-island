import QtQuick
import "IconData.js" as IconData

// An interface icon (Reicon) painted as a vector in `color`, or any image file
// shown as-is (`source`, for original app and brand icons).
//
// The color goes straight into the SVG and the image is rasterized at the
// screen's real pixel density, so icons stay razor sharp at fractional
// scales; there is no offscreen tint pass to soften them.
Item {
  id: icon

  property string name: ""
  property string source: ""          // absolute path or URL: shown untinted
  property color color: Theme.fg
  property int size: 18

  function hex(c) {
    var h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2)
    return "#" + h(c.r) + h(c.g) + h(c.b)
  }

  readonly property string markup: source === "" && name !== "" ? (IconData.svg[name] || "") : ""
  readonly property url url: {
    if (source !== "") return source.indexOf("/") === 0 ? "file://" + source : source
    if (markup === "") return ""
    var body = markup.split("#ffffff").join(hex(color))
    return "data:image/svg+xml;utf8," + encodeURIComponent(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">' + body + '</svg>')
  }

  implicitWidth: size
  implicitHeight: size
  width: size
  height: size

  Accessible.ignored: true

  Image {
    anchors.fill: parent
    source: icon.url
    // Logical size: Qt renders vector sources at size × device pixel ratio.
    sourceSize.width: icon.size
    sourceSize.height: icon.size
    fillMode: Image.PreserveAspectFit
    smooth: true
    // Color alpha (e.g. the secondary text tone) applies as opacity.
    opacity: icon.source === "" ? icon.color.a : 1
  }
}
