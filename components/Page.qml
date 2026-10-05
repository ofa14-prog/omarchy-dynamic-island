import QtQuick
import QtQuick.Effects

// Content layer of the island.
//
// slide == 0 (the island itself changing shape): the Dynamic Island's "blur
// morph" — outgoing content blurs and fades fast; incoming content waits a
// beat for the shape to start moving, then sharpens out of a blur while
// settling up to full size.
//
// slide == ±1 (switching tabs inside the open island): a short directional
// cross-slide with no scale and no overshoot, so nothing wobbles.
Item {
  id: page

  property bool shown: false
  property int slide: 0
  property real blur: 0
  property real shift: 0
  default property alias content: holder.data

  visible: opacity > 0.001
  opacity: 0
  enabled: shown

  Component.onCompleted: if (shown) { opacity = 1; scale = 1 }

  onShownChanged: {
    showMorph.stop(); hideMorph.stop(); showSlide.stop(); hideSlide.stop()
    if (slide !== 0 && !Theme.reduceMotion) {
      scale = 1; blur = 0
      if (shown) { shift = 26 * slide; showSlide.start() } else hideSlide.start()
    } else {
      shift = 0
      if (shown) { scale = 0.9; blur = 1; showMorph.start() } else hideMorph.start()
    }
  }

  ParallelAnimation {
    id: showMorph
    SequentialAnimation {
      PauseAnimation { duration: Theme.ms(70) }
      NumberAnimation { target: page; property: "opacity"; to: 1; duration: Theme.ms(240); easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
      PauseAnimation { duration: Theme.ms(50) }
      NumberAnimation { target: page; property: "scale"; to: 1; duration: Theme.ms(380); easing.type: Easing.OutBack; easing.overshoot: 1.2 }
    }
    NumberAnimation { target: page; property: "blur"; to: 0; duration: Theme.ms(320); easing.type: Easing.OutCubic }
  }

  ParallelAnimation {
    id: hideMorph
    NumberAnimation { target: page; property: "opacity"; to: 0; duration: Theme.ms(120); easing.type: Easing.InQuad }
    NumberAnimation { target: page; property: "scale"; to: 0.92; duration: Theme.ms(150); easing.type: Easing.InQuad }
    NumberAnimation { target: page; property: "blur"; to: 1; duration: Theme.ms(130); easing.type: Easing.InQuad }
  }

  ParallelAnimation {
    id: showSlide
    SequentialAnimation {
      PauseAnimation { duration: 40 }
      NumberAnimation { target: page; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
    }
    NumberAnimation { target: page; property: "shift"; to: 0; duration: 300; easing.type: Easing.OutCubic }
  }

  ParallelAnimation {
    id: hideSlide
    NumberAnimation { target: page; property: "opacity"; to: 0; duration: 110; easing.type: Easing.OutQuad }
    NumberAnimation { target: page; property: "shift"; to: -26 * page.slide; duration: 160; easing.type: Easing.InQuad }
  }

  Item {
    id: holder
    width: parent.width
    height: parent.height
    x: page.shift

    // Only pay for the offscreen layer while a transition is blurring.
    layer.enabled: page.blur > 0.01 && page.visible && !Theme.reduceMotion
    layer.effect: MultiEffect {
      blurEnabled: true
      blurMax: 24
      blur: page.blur
      autoPaddingEnabled: true
    }
  }
}
