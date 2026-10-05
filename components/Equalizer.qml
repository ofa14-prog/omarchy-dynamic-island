import QtQuick

// The "now playing" waveform from the compact music activity. Each bar eases
// toward a fresh random height on its own beat so the motion never loops
// visibly; paused, the bars settle into a low flat line.
Row {
  id: eq

  property bool playing: true
  property color color: Theme.fg
  property int bars: 5
  property int barWidth: 3
  property int maxHeight: 16

  spacing: 2
  height: maxHeight

  Accessible.role: Accessible.Animation
  Accessible.name: playing ? I18n.t("Çalıyor") : I18n.t("Duraklatıldı")

  Repeater {
    model: eq.bars
    Rectangle {
      id: bar
      property real level: 0.3
      width: eq.barWidth
      height: Math.max(eq.barWidth, eq.maxHeight * (eq.playing ? level : 0.18))
      radius: width / 2
      color: eq.color
      anchors.verticalCenter: parent.verticalCenter

      Behavior on height {
        NumberAnimation { duration: Theme.reduceMotion ? 0 : 190; easing.type: Easing.OutQuad }
      }

      Timer {
        interval: 150 + index * 37
        repeat: true
        running: eq.playing && eq.visible && !Theme.reduceMotion
        onTriggered: {
          // Center bars swing taller, like a voice/music spectrum.
          var center = 1 - Math.abs(index - (eq.bars - 1) / 2) / eq.bars
          bar.level = 0.22 + Math.random() * (0.45 + center * 0.33)
        }
      }
    }
  }
}
