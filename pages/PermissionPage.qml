import QtQuick
import "../components"

// A coding agent is asking to use a tool. Allow, always allow, or deny — from
// here or the terminal, whichever you reach first.
Page {
  id: page

  property var island
  readonly property var agents: island.agents
  readonly property var req: agents.currentRequest
  readonly property bool hasDetail: req && req.detail !== ""
  readonly property bool isDiff: req && ["Edit", "MultiEdit", "replace", "edit", "apply_patch"].indexOf(req.tool) !== -1
  readonly property var profile: island.profile(req ? req.agent : "")
  readonly property string logo: island.logoFor(req ? req.agent : "")

  implicitHeight: col.implicitHeight + 14

  Accessible.role: Accessible.AlertMessage
  Accessible.name: req ? I18n.t("%1 izin istiyor").arg(profile.name) + ": " + req.tool + " " + req.title : ""

  // Keep the decisive button under the keyboard once the island has focus.
  onShownChanged: if (shown) allowButton.forceActiveFocus()

  Column {
    id: col
    width: parent.width
    topPadding: 14
    spacing: 12

    // ---- header
    Item {
      width: parent.width
      height: 42

      Rectangle {
        id: badge
        width: 42; height: 42; radius: 21
        anchors.verticalCenter: parent.verticalCenter
        color: Qt.rgba(page.profile.color.r, page.profile.color.g, page.profile.color.b, 0.18)
        Icon { anchors.centerIn: parent; source: page.logo; name: page.logo ? "" : "sparkles"; color: page.profile.color; size: 24 }
      }
      Column {
        anchors.left: badge.right
        anchors.leftMargin: 10
        anchors.right: counter.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        Label {
          width: parent.width
          text: I18n.t("%1 izin istiyor").arg(page.profile.name)
          font.pixelSize: 16
          strong: true
        }
        Label {
          width: parent.width
          text: page.req ? page.req.project + (page.req.mode && page.req.mode !== "default" ? " · " + page.req.mode : "") : ""
          font.pixelSize: 13
          color: Theme.secondary
        }
      }
      Label {
        id: counter
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: agents.pending.length > 1
        text: "1 / " + agents.pending.length
        font.pixelSize: 12
        tabular: true
        color: Theme.tertiary
      }
    }

    // ---- what it wants to do
    Rectangle {
      width: parent.width
      height: what.implicitHeight + 24
      radius: 18
      color: Theme.fill

      Column {
        id: what
        x: 14
        y: 12
        width: parent.width - 28
        spacing: 6

        Row {
          spacing: 8
          width: parent.width
          Rectangle {
            id: chip
            height: 24
            width: chipLabel.implicitWidth + 16
            radius: 12
            color: Qt.rgba(page.profile.color.r, page.profile.color.g, page.profile.color.b, 0.25)
            Label {
              id: chipLabel
              anchors.centerIn: parent
              text: page.req ? page.req.tool : ""
              font.pixelSize: 12
              strong: true
              color: page.profile.color
            }
          }
          Label {
            width: parent.width - chip.width - 8
            anchors.verticalCenter: parent.verticalCenter
            text: page.req ? page.req.title : ""
            font.pixelSize: 14
            strong: true
          }
        }

        // Command / diff preview, monospace, a few lines max. One plain-text
        // line per row (the detail comes from the agent: never rich text);
        // diff lines are colored by their row.
        Column {
          visible: page.hasDetail
          width: parent.width
          spacing: 1
          Accessible.role: Accessible.StaticText
          Accessible.name: page.req ? page.req.detail : ""
          Repeater {
            model: page.req ? page.req.detail.split("\n").slice(0, 7) : []
            delegate: Text {
              required property string modelData
              width: parent.width
              text: modelData
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              wrapMode: Text.NoWrap
              elide: Text.ElideRight
              font.family: Theme.mono
              font.pixelSize: 12
              color: page.isDiff && modelData.indexOf("+ ") === 0 ? Theme.green
                : page.isDiff && modelData.indexOf("- ") === 0 ? Theme.red : Theme.fg
            }
          }
        }
      }
    }

    // ---- decision
    Row {
      id: buttons
      width: parent.width
      spacing: 8
      readonly property int count: page.req && page.req.canAlways ? 3 : 2
      readonly property real cell: (width - spacing * (count - 1)) / count

      IslandButton {
        id: denyButton
        width: buttons.cell
        size: 42
        text: I18n.t("Reddet")
        icon: "x"
        accessibleName: I18n.t("Reddet")
        hint: I18n.t("Esc veya N")
        KeyNavigation.right: page.req && page.req.canAlways ? alwaysButton : allowButton
        onClicked: { agents.respond(page.req.id, "deny"); island.shake() }
      }
      IslandButton {
        id: alwaysButton
        visible: page.req && page.req.canAlways
        width: buttons.cell
        size: 42
        text: I18n.t("Her zaman")
        icon: "check-all"
        accessibleName: I18n.t("Bu oturumda her zaman izin ver")
        hint: "A"
        KeyNavigation.left: denyButton
        KeyNavigation.right: allowButton
        onClicked: agents.respond(page.req.id, "always")
      }
      IslandButton {
        id: allowButton
        width: buttons.cell
        size: 42
        text: I18n.t("İzin ver")
        icon: "check"
        prominent: true
        tint: Theme.fg
        accessibleName: I18n.t("İzin ver")
        hint: I18n.t("Enter veya Y")
        KeyNavigation.left: page.req && page.req.canAlways ? alwaysButton : denyButton
        onClicked: agents.respond(page.req.id, "allow")
      }
    }

    // ---- footer: keyboard hints + jump to terminal
    Item {
      width: parent.width
      height: 20
      Label {
        anchors.left: parent.left
        anchors.right: termRow.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: I18n.t("⏎ izin · esc ret") + (page.req && page.req.canAlways ? I18n.t(" · A hep") : "") + I18n.t(" · T terminal")
        font.pixelSize: 11
        color: Theme.tertiary
      }
      Row {
        id: termRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5
        Label {
          anchors.verticalCenter: parent.verticalCenter
          text: I18n.t("Terminalde aç")
          font.pixelSize: 12
          color: termMouse.containsMouse ? Theme.fg : Theme.secondary
        }
        Icon {
          anchors.verticalCenter: parent.verticalCenter
          name: "arrow-up-right"
          size: 14
          color: termMouse.containsMouse ? Theme.fg : Theme.secondary
        }
      }
      MouseArea {
        id: termMouse
        anchors.fill: termRow
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: page.req && agents.focusTerminal(agents.sessions[page.req.session])
        Accessible.role: Accessible.Link
        Accessible.name: I18n.t("Terminale git")
      }
    }
  }
}
