import QtQuick
import QtQuick.Shapes

// Circular progress, drawn clockwise from 12 o'clock like the iOS timer.
Item {
  id: ring

  property real progress: 0      // 0..1
  property color color: Theme.orange
  property color track: Qt.rgba(color.r, color.g, color.b, 0.25)
  property real thickness: 3

  implicitWidth: 20
  implicitHeight: 20

  Accessible.role: Accessible.ProgressBar
  Accessible.name: Math.round(progress * 100) + "%"

  Behavior on progress {
    enabled: !Theme.reduceMotion
    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeColor: ring.track
      strokeWidth: ring.thickness
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      PathAngleArc {
        centerX: ring.width / 2; centerY: ring.height / 2
        radiusX: (ring.width - ring.thickness) / 2; radiusY: (ring.height - ring.thickness) / 2
        startAngle: 0; sweepAngle: 360
      }
    }
    ShapePath {
      strokeColor: ring.color
      strokeWidth: ring.thickness
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      PathAngleArc {
        centerX: ring.width / 2; centerY: ring.height / 2
        radiusX: (ring.width - ring.thickness) / 2; radiusY: (ring.height - ring.thickness) / 2
        startAngle: -90
        sweepAngle: 360 * Math.max(0, Math.min(1, ring.progress))
      }
    }
  }
}
