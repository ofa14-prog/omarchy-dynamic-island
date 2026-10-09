import QtQuick

// The island's Liquid Glass surface: draws every glass body (the island or
// its halves, and the bubbles) in one pass from shaders/liquid.frag, so
// they merge and part like liquid. Positions are in this item's own
// coordinates. The translucent tint sits on the compositor's backdrop blur
// (set up by Island.qml); text and icons are drawn above, unaffected.
ShaderEffect {
  id: glass

  property vector4d rectA: Qt.vector4d(0, 0, 0, 0)
  property vector4d radA: Qt.vector4d(0, 0, 0, 0)
  property vector4d rectB: Qt.vector4d(0, 0, 0, 0)
  property vector4d radB: Qt.vector4d(0, 0, 0, 0)
  property vector4d bub0: Qt.vector4d(0, 0, 0, 0)
  property vector4d bub1: Qt.vector4d(0, 0, 0, 0)
  property real blend: 10
  property color tint: Qt.rgba(0.06, 0.06, 0.07, 0.58)
  Behavior on tint { ColorAnimation { duration: 260 } }
  property point light: Qt.point(-0.55, -0.83)
  property real rim: 1
  property real energy: 0
  property color ambL: "black"
  property color ambR: "black"
  property real ambMix: 0
  property real dark: 0
  property vector4d pull: Qt.vector4d(0, 0, 0, 24)
  readonly property size size: Qt.size(width, height)

  fragmentShader: Qt.resolvedUrl("../shaders/liquid.frag.qsb")
  blending: true
}
