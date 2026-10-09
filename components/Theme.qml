pragma Singleton
import QtQuick

// Visual language of the island. It is deliberately not tied to the Omarchy
// theme. Two modes, each with or without Liquid Glass:
//   dark   black shape, white content (the real Dynamic Island)
//   light  white shape, near-black content (iOS light appearance)
// Every color below follows `light`; pages use these instead of literals.
QtObject {
  id: theme

  // Set from config. Springs become short fades and nothing wobbles or shakes.
  property bool reduceMotion: false

  property color bg: "#000000"
  // Light appearance (white island, dark content).
  property bool light: false
  // Liquid Glass theme on: surfaces get GlassSheen, popups turn translucent.
  property bool glass: false

  // Content ink: white on dark, near-black on light. ink(a) is it at alpha a.
  readonly property color inkColor: light ? "#1d1d1f" : "#ffffff"
  function ink(a) { return Qt.rgba(inkColor.r, inkColor.g, inkColor.b, a) }
  readonly property color fg: inkColor
  readonly property color secondary: ink(light ? 0.62 : 0.62)
  readonly property color tertiary: ink(light ? 0.42 : 0.40)
  readonly property color fill: ink(light ? 0.07 : 0.12)
  readonly property color fillHover: ink(light ? 0.12 : 0.20)
  readonly property color fillPressed: ink(light ? 0.18 : 0.28)
  readonly property color hairline: ink(light ? 0.10 : 0.08)
  // The island's own edge, and borders of popups and cards.
  readonly property color edge: ink(light ? 0.12 : 0.07)
  // Popup menus (language, theme, player list).
  readonly property color popup: glass ? (light ? Qt.rgba(0.98, 0.98, 0.99, 0.94) : Qt.rgba(0.11, 0.11, 0.12, 0.88))
                                       : (light ? "#ffffff" : "#1c1c1e")
  // Small chips over content (e.g. the remove button on a shelf tile).
  readonly property color chip: light ? "#e5e5ea" : "#3a3a3c"
  // Text on a solid colored (prominent) button.
  readonly property color onTint: light ? "#ffffff" : "#000000"
  readonly property color focusRing: light ? "#007AFF" : "#0A84FF"

  // iOS system colors, per appearance.
  readonly property color orange: light ? "#FF9500" : "#FF9F0A"
  readonly property color green: light ? "#34C759" : "#30D158"
  readonly property color red: light ? "#FF3B30" : "#FF453A"
  readonly property color blue: light ? "#007AFF" : "#0A84FF"
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
