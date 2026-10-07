import QtQuick
import Quickshell.Widgets

// A small round flag for the language picker, drawn from inline SVG (no
// emoji font needed) and clipped to a circle (Qt's SVG renderer has no
// clipPath). `code` is a language code: en, es, ru, tr.
ClippingRectangle {
  id: flag

  property string code: "en"
  property int size: 20

  readonly property var bodies: ({
    // Union Jack
    en: "<rect width='60' height='60' fill='#012169'/>"
      + "<path d='M0,0 60,60 M60,0 0,60' stroke='#fff' stroke-width='12'/>"
      + "<path d='M0,0 60,60 M60,0 0,60' stroke='#C8102E' stroke-width='5'/>"
      + "<path d='M30,0v60M0,30h60' stroke='#fff' stroke-width='18'/>"
      + "<path d='M30,0v60M0,30h60' stroke='#C8102E' stroke-width='10'/>",
    es: "<rect width='60' height='60' fill='#AA151B'/><rect y='15' width='60' height='30' fill='#F1BF00'/>",
    ru: "<rect width='60' height='20' fill='#fff'/><rect y='20' width='60' height='20' fill='#0039A6'/>"
      + "<rect y='40' width='60' height='20' fill='#D52B1E'/>",
    tr: "<rect width='60' height='60' fill='#E30A17'/><circle cx='25' cy='30' r='13' fill='#fff'/>"
      + "<circle cx='28.5' cy='30' r='10.4' fill='#E30A17'/>"
      + "<path fill='#fff' d='M44.6 30l-9.1 2.9 5.6-7.7v9.6l-5.6-7.7z'/>"
  })

  width: size
  height: size
  radius: size / 2
  color: "transparent"
  border.width: 1
  border.color: Qt.rgba(1, 1, 1, 0.3)
  Accessible.ignored: true

  Image {
    anchors.fill: parent
    sourceSize: Qt.size(flag.size * 3, flag.size * 3)
    smooth: true
    source: "data:image/svg+xml;utf8," + encodeURIComponent(
      "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 60 60'>" + (flag.bodies[flag.code] || flag.bodies.en) + "</svg>")
  }
}
