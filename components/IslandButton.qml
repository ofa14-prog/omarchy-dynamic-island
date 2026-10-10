import QtQuick

// The island's one button. Circular when it only carries an icon, a capsule
// when it has text. Icon and label are measured and centered as one block, so
// they sit in the optical middle of the control. Presses sink with a spring
// like iOS controls, keyboard focus draws a ring, Enter/Space activate it.
FocusScope {
  id: button

  property string icon: ""                // name in ../icons (tinted)
  property string iconSource: ""          // original image (brand logo), untinted
  property string text: ""
  property string accessibleName: text
  property string hint: ""
  property color tint: Theme.fg
  property color fillColor: Theme.fill
  property bool filled: true
  property bool prominent: false          // solid tint background, black content
  property int size: 38
  property int iconSize: Math.round(size * 0.48)
  property int fontSize: 14
  property bool enabled2: true

  signal clicked()
  signal rightClicked()

  readonly property bool hasIcon: icon !== "" || iconSource !== ""
  readonly property bool hovered: mouse.containsMouse
  readonly property bool down: mouse.pressed || keyDown
  property bool keyDown: false
  readonly property color contentColor: prominent ? Theme.onTint : tint

  implicitHeight: size
  implicitWidth: text === "" ? size : content.width + Math.round(size * 0.9)
  opacity: enabled2 ? 1 : 0.35
  activeFocusOnTab: enabled2

  Accessible.role: Accessible.Button
  Accessible.name: accessibleName || icon
  Accessible.description: hint
  Accessible.focusable: true
  Accessible.onPressAction: if (enabled2) button.clicked()

  Keys.onPressed: event => {
    if (!enabled2) return
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
      keyDown = true
      event.accepted = true
    }
  }
  Keys.onReleased: event => {
    if (!keyDown) return
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
      keyDown = false
      button.clicked()
      event.accepted = true
    }
  }

  Rectangle {
    id: body
    anchors.fill: parent
    radius: height / 2
    color: button.prominent ? button.tint
      : !button.filled ? (Theme.glass ? "transparent" : button.down ? Theme.fill : button.hovered ? Theme.hairline : "transparent")
      : button.down ? Theme.fillPressed : button.hovered ? Theme.fillHover : button.fillColor
    GlassSheen {
      visible: Theme.glass && (button.filled || button.prominent)
      takeFill: true
      fill: button.prominent ? button.tint : button.fillColor
      lit: button.hovered
      pressed: button.down
      strength: button.prominent ? 0.8 : 1
    }
    scale: button.down ? 0.92 : 1

    Behavior on color { ColorAnimation { duration: Theme.ms(140) } }
    Behavior on scale {
      enabled: !Theme.reduceMotion
      SpringAnimation { spring: Theme.snapSpring; damping: Theme.snapDamping; epsilon: 0.002 }
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: -3
      radius: height / 2
      color: "transparent"
      border.color: Theme.focusRing
      border.width: 2
      visible: button.activeFocus
    }

    Item {
      id: content
      anchors.centerIn: parent
      width: (button.hasIcon ? button.iconSize : 0)
        + (button.hasIcon && button.text !== "" ? gap : 0)
        + (button.text !== "" ? Math.ceil(label.implicitWidth) : 0)
      height: Math.max(button.hasIcon ? button.iconSize : 0, label.implicitHeight)
      readonly property int gap: Math.round(button.fontSize * 0.5)

      Icon {
        id: glyph
        visible: button.hasIcon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        name: button.icon
        source: button.iconSource
        size: button.iconSize
        color: button.contentColor
      }
      Label {
        id: label
        visible: button.text !== ""
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: button.text
        font.pixelSize: button.fontSize
        strong: true
        color: button.contentColor
      }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: button.enabled2 ? Qt.PointingHandCursor : Qt.ArrowCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: mouseEvent => {
      if (!button.enabled2) return
      if (mouseEvent.button === Qt.RightButton) button.rightClicked()
      else button.clicked()
    }
  }
}
