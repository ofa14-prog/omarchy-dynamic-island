import QtQuick
import "../components"

// Claude Code is asking to use a tool. Allow, always allow, or deny — from
// here or the terminal, whichever you reach first.
Page {
  id: page

  property var island
  readonly property var claude: island.claude
  readonly property var req: claude.currentRequest
  readonly property bool hasDetail: req && req.detail !== ""
  readonly property bool isDiff: req && (req.tool === "Edit" || req.tool === "MultiEdit")

  implicitHeight: col.implicitHeight + 14

  Accessible.role: Accessible.AlertMessage
  Accessible.name: req ? I18n.t("Claude izin istiyor: ") + req.tool + " " + req.title : ""

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
        color: Qt.rgba(0.85, 0.47, 0.34, 0.18)
        Icon { anchors.centerIn: parent; source: Theme.claudeLogo; size: 24 }
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
          text: I18n.t("Claude izin istiyor")
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
        visible: claude.pending.length > 1
        text: "1 / " + claude.pending.length
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
            color: Qt.rgba(0.85, 0.47, 0.34, 0.25)
            Label {
              id: chipLabel
              anchors.centerIn: parent
              text: page.req ? page.req.tool : ""
              font.pixelSize: 12
              strong: true
              color: Theme.claude
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

        // Command / diff preview, monospace, a few lines max.
        Text {
          visible: page.hasDetail
          width: parent.width
          textFormat: Text.RichText
          wrapMode: Text.WrapAnywhere
          maximumLineCount: 7
          elide: Text.ElideRight
          font.family: Theme.mono
          font.pixelSize: 12
          color: Theme.fg
          lineHeight: 1.15
          text: {
            if (!page.req) return ""
            var esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/ /g, "&nbsp;")
            var lines = page.req.detail.split("\n").slice(0, 7)
            return lines.map(l => {
              if (page.isDiff && l.indexOf("+ ") === 0) return "<span style='color:" + Theme.green + "'>" + esc(l) + "</span>"
              if (page.isDiff && l.indexOf("- ") === 0) return "<span style='color:" + Theme.red + "'>" + esc(l) + "</span>"
              return esc(l)
            }).join("<br>")
          }
          Accessible.role: Accessible.StaticText
          Accessible.name: page.req ? page.req.detail : ""
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
        onClicked: { claude.respond(page.req.id, "deny"); island.shake() }
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
        onClicked: claude.respond(page.req.id, "always")
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
        onClicked: claude.respond(page.req.id, "allow")
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
        onClicked: page.req && claude.focusTerminal(claude.sessions[page.req.session])
        Accessible.role: Accessible.Link
        Accessible.name: I18n.t("Terminale git")
      }
    }
  }
}
