pragma Singleton
import QtQuick

// Visual language of the island. It is deliberately not tied to the Omarchy
// theme: like the real Dynamic Island it is a pure black shape with white
// content, so it reads the same on every wallpaper and color scheme.
QtObject {
  id: theme

  // Set from config. Springs become short fades and nothing wobbles or shakes.
  property bool reduceMotion: false

  property color bg: "#000000"
  // Liquid Glass theme on: surfaces get GlassSheen, popups turn translucent.
  property bool glass: false
  readonly property color fg: "#ffffff"
  readonly property color secondary: Qt.rgba(1, 1, 1, 0.62)
  readonly property color tertiary: Qt.rgba(1, 1, 1, 0.40)
  readonly property color fill: Qt.rgba(1, 1, 1, 0.12)
  readonly property color fillHover: Qt.rgba(1, 1, 1, 0.20)
  readonly property color fillPressed: Qt.rgba(1, 1, 1, 0.28)
  readonly property color hairline: Qt.rgba(1, 1, 1, 0.08)
  readonly property color focusRing: "#0A84FF"

  // iOS system colors (dark appearance).
  readonly property color orange: "#FF9F0A"
  readonly property color green: "#30D158"
  readonly property color red: "#FF453A"
  readonly property color blue: "#0A84FF"
  readonly property color claude: "#D97757"       // official Claude brand color
  readonly property color claudeGlow: "#F0B49B"   // Claude Code's shimmer band

  // The Omarchy system font (`omarchy-font-current`), set by Island.qml.
  property string font: "JetBrainsMono Nerd Font"
  readonly property string mono: font
  readonly property string icons: "JetBrainsMono Nerd Font"

  readonly property string claudeLogo: Qt.resolvedUrl("../icons/brand/claude.svg")

  // Spring presets. QML's SpringAnimation is a damped harmonic oscillator;
  // these approximate SwiftUI's .spring(response:dampingFraction:) curves the
  // Dynamic Island uses: a lively open with a small overshoot and a firmer,
  // nearly critically damped close.
  readonly property real openSpring: 3.6
  readonly property real openDamping: 0.27
  readonly property real closeSpring: 4.6
  readonly property real closeDamping: 0.36
  // Size changes while already open (switching tabs): no visible bounce.
  readonly property real resizeSpring: 4.4
  readonly property real resizeDamping: 0.62
  readonly property real snapSpring: 6.0
  readonly property real snapDamping: 0.42
  readonly property real mass: 1.0

  function ms(value) { return reduceMotion ? Math.min(value, 90) : value }
}
