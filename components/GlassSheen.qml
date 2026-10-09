import QtQuick

// Liquid Glass finish for a surface (button, tile, card, row, popup):
// a faint edge all round, a bright rim along the upper curve that fades
// down the sides, and a soft highlight across the top, as light falls on
// curved glass. Plain rectangles (one clip each), so it costs next to
// nothing; drawn only with the Liquid Glass theme. Put it inside the
// surface: it fills it and follows its radius.
Item {
  id: sheen

  property real radius: parent ? parent.radius || 0 : 0
  property real strength: 1          // 0..1, e.g. lower for small rows
  property bool lit: false           // hovered / pressed: a little brighter

  anchors.fill: parent
  visible: Theme.glass
  readonly property real k: strength * (lit ? 1.35 : 1)

  // Edge all round.
  Rectangle {
    anchors.fill: parent
    radius: sheen.radius
    color: "transparent"
    border.width: 1
    // Light: a faint shade outlines the glass; dark: a faint light edge.
    border.color: Theme.light ? Qt.rgba(0, 0, 0, 0.07 * sheen.k) : Qt.rgba(1, 1, 1, 0.09 * sheen.k)
  }
  // Highlight across the top.
  Rectangle {
    anchors.fill: parent
    radius: sheen.radius
    gradient: Gradient {
      GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, (Theme.light ? 0.55 : 0.10) * sheen.k) }
      GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, (Theme.light ? 0.18 : 0.015) * sheen.k) }
      GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, (Theme.light ? 0.03 : 0.06) * sheen.k) }
    }
  }
  // Bright rim along the upper curve, in two steps so it fades.
  Item {
    width: parent.width
    height: Math.round(parent.height * 0.5)
    clip: true
    Rectangle {
      width: sheen.width
      height: sheen.height
      radius: sheen.radius
      color: "transparent"
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, (Theme.light ? 0.6 : 0.12) * sheen.k)
    }
  }
  Item {
    width: parent.width
    height: Math.max(2, Math.round(parent.height * 0.22))
    clip: true
    Rectangle {
      width: sheen.width
      height: sheen.height
      radius: sheen.radius
      color: "transparent"
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, (Theme.light ? 0.9 : 0.20) * sheen.k)
    }
  }
}
