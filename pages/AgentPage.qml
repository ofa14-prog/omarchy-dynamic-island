import QtQuick
import "../components"

// Every coding-agent session: what it is doing right now, and a jump to it.
// Branded after Omarchy's default agent; each session row keeps its own agent.
Page {
  id: page

  property var island
  readonly property var agents: island.agents
  readonly property var sessions: agents.sessionList.slice(0, 4)

  implicitHeight: col.implicitHeight + 8

  readonly property var profile: island.agent
  // "full" / "status": the agent reports sessions once connected;
  // "none": it has no event API, so there is nothing to connect.
  readonly property bool connectable: profile.integration !== "none"
  readonly property bool connected: agents.hooksInstalled

  // ---- live preview (Claude Code and Codex)
  // Follows the focused session; with several, click a row to watch it.
  property string pickedId: ""
  readonly property var previewSession: {
    void agents.revision
    var picked = agents.sessions[pickedId]
    if (agents.canPreview(picked)) return picked
    if (agents.canPreview(agents.focusSession)) return agents.focusSession
    return sessions.find(x => agents.canPreview(x)) || null
  }
  Binding {
    target: page.agents
    property: "previewCount"
    value: page.island.feedExpanded ? 120 : 40
  }
  Binding {
    target: page.agents
    property: "previewLines"
    value: page.island.feedExpanded ? 0 : 2      // 0: every line
  }
  Binding {
    target: page.agents
    property: "previewId"
    value: page.shown && page.previewSession ? page.previewSession.id : ""
  }

  // Transcript items → terminal lines, drawn the way the agent's own CLI
  // draws them: "● Bash(…)" / "  ⎿ output" for Claude Code, "•" / "└" for Codex.
  function feedLines(items, agent, busy) {
    var codex = agent === "codex"
    var out = []
    for (var i = 0; i < items.length; i++) {
      var it = items[i]
      var next = items[i + 1]
      switch (it.k) {
        case "prompt":
          out.push({ g: codex ? "›" : ">", t: it.t, c: Theme.tertiary })
          break
        case "text":
          it.t.split("\n").forEach((l, j) => out.push({ g: j === 0 ? (codex ? "•" : "●") : "", t: l, c: Theme.fg }))
          break
        case "tool": {
          // Green / red once its output is in; orange while it still runs.
          var tone = !it.done ? (busy ? Theme.orange : Theme.tertiary)
            : next && next.k === "result" && next.err ? Theme.red : Theme.green
          out.push({ g: codex ? "•" : "●", t: it.t + (it.d ? "(" + it.d + ")" : ""), c: Theme.fg, gc: tone, strong: true })
          break
        }
        case "result":
          it.t.split("\n").forEach((l, j) => out.push({ g: j === 0 ? (codex ? "└" : "⎿") : "", t: l, c: it.err ? Theme.red : Theme.secondary, indent: true }))
          break
        case "interrupt":
          out.push({ g: codex ? "└" : "⎿", t: I18n.t("Kullanıcı tarafından kesildi"), c: Theme.red, indent: true })
          break
      }
    }
    return out.slice(-400)
  }

  function working(s) {
    var st = agents.displayState(s)
    return st === "thinking" || st === "tool" || st === "compacting"
  }

  // Labels and tones come from AgentBridge.stateLook; rows add detail.
  function stateText(s) {
    var st = agents.displayState(s)
    switch (st) {
      case "waiting": return I18n.t("İzin bekliyor · ") + (s.tool || "")
      case "input": return s.message || I18n.t("Seni bekliyor")
      case "compacting": return I18n.t("Bağlamı sıkıştırıyor…")
      case "tool": return (s.tool || I18n.t("Araç")) + (s.title ? " · " + s.title : "") + "…"
      case "done": return I18n.t("Bitti") + (s.lastDuration ? " · " + island.duration(s.lastDuration) : "")
      case "error": return I18n.t("Hata") + (s.error ? " · " + s.error : "")
    }
    return I18n.t(agents.look(s).label)
  }

  function stateColor(s) {
    var tone = agents.look(s).tone
    return tone === "agent" ? island.profile(s.agent).color : tone === "green" ? Theme.green
      : tone === "red" ? Theme.red : Theme.secondary
  }

  Column {
    id: col
    width: parent.width
    spacing: 12

    // ---- header
    Item {
      width: parent.width
      height: 30
      Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        Icon {
          anchors.verticalCenter: parent.verticalCenter
          source: island.agentLogo
          name: island.agentLogo ? "" : "sparkles"
          color: island.agentColor
          size: 22
        }
        Label {
          anchors.verticalCenter: parent.verticalCenter
          text: island.agentProduct
          font.pixelSize: 16
          strong: true
        }
        Label {
          anchors.verticalCenter: parent.verticalCenter
          text: agents.sessionList.length > 0 ? agents.sessionList.length + I18n.t(" oturum") : ""
          font.pixelSize: 13
          color: Theme.tertiary
        }
      }
      // Compact usage readout; click for Omarchy's full usage panel.
      Row {
        id: usageRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
        visible: agents.usage.session >= 0
        Repeater {
          model: [
            { label: I18n.t("5s"), v: agents.usage.session },
            { label: I18n.t("7g"), v: agents.usage.weekly }
          ]
          delegate: Row {
            required property var modelData
            spacing: 6
            visible: modelData.v >= 0
            Label { text: modelData.label; font.pixelSize: 12; color: Theme.tertiary; anchors.verticalCenter: parent.verticalCenter }
            Rectangle {
              width: 40; height: 6; radius: 3
              anchors.verticalCenter: parent.verticalCenter
              color: Theme.fill
              Rectangle {
                width: Math.max(6, parent.width * Math.min(1, modelData.v))
                height: parent.height; radius: 3
                color: modelData.v >= 0.9 ? Theme.red : modelData.v >= 0.7 ? Theme.orange : island.agentColor
              }
            }
            Label { text: Math.round(modelData.v * 100) + "%"; font.pixelSize: 12; tabular: true; color: Theme.secondary; anchors.verticalCenter: parent.verticalCenter }
          }
        }
      }
      MouseArea {
        anchors.fill: usageRow
        cursorShape: Qt.PointingHandCursor
        onClicked: agents.openUsage()
        Accessible.role: Accessible.Button
        Accessible.name: I18n.t("Kullanım ayrıntıları")
      }
    }

    // ---- sessions
    Column {
      width: parent.width
      spacing: 8
      visible: page.sessions.length > 0

      Repeater {
        model: page.sessions
        delegate: Rectangle {
          id: row
          required property var modelData
          readonly property var s: modelData
          readonly property bool waiting: agents.displayState(s) === "waiting"
          // With several sessions, a click picks which one the feed shows.
          readonly property bool watched: page.sessions.length > 1 && page.previewSession !== null && page.previewSession.id === s.id
          readonly property bool watchable: page.sessions.length > 1 && !watched && agents.canPreview(s)
          width: parent.width
          height: 58
          radius: 18
          color: rowMouse.containsMouse || watched ? Theme.fillHover : Theme.fill
          border.width: waiting ? 1 : 0
          border.color: island.profile(s.agent).color
          Behavior on color { ColorAnimation { duration: Theme.ms(140) } }

          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (row.waiting) island.setPage("permission")
              else if (row.watchable) page.pickedId = row.s.id
              else agents.focusTerminal(row.s)
            }
          }

          Accessible.role: Accessible.ListItem
          Accessible.name: (s.project || "oturum") + ", " + page.stateText(s)

          Item {
            id: lead
            x: 14
            width: 24; height: 24
            anchors.verticalCenter: parent.verticalCenter
            AgentSpinner {
              anchors.centerIn: parent
              agent: row.s.agent || "claude"
              size: 20
              visible: agents.look(row.s).icon === ""
              running: page.working(row.s)
            }
            Icon { anchors.centerIn: parent; visible: agents.look(row.s).icon !== ""; name: agents.look(row.s).icon; size: 20; color: page.stateColor(row.s) }
          }

          Column {
            anchors.left: lead.right
            anchors.leftMargin: 12
            anchors.right: actions.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Row {
              width: parent.width
              spacing: 8
              Label {
                text: row.s.project || "oturum"
                font.pixelSize: 14
                strong: true
                width: Math.min(implicitWidth, parent.width - (timeLabel.visible ? timeLabel.width + 8 : 0))
              }
              Label {
                id: timeLabel
                visible: agents.isBusy(row.s) && row.s.turnStartedAt > 0
                text: island.duration(island.nowMs - row.s.turnStartedAt) + (row.s.toolCount ? " · " + row.s.toolCount + I18n.t(" araç") : "")
                font.pixelSize: 12
                tabular: true
                color: Theme.tertiary
              }
            }
            ShimmerText {
              width: parent.width
              label: page.stateText(row.s)
              running: page.working(row.s)
              font.pixelSize: 13
              baseColor: page.stateColor(row.s)
              glowColor: island.profile(row.s.agent).glow
            }
          }

          Row {
            id: actions
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            IslandButton {
              visible: row.waiting
              size: 34
              text: I18n.t("Yanıtla")
              fontSize: 13
              prominent: true
              tint: island.profile(row.s.agent).color
              accessibleName: I18n.t("İzin isteğini yanıtla")
              onClicked: island.setPage("permission")
            }
            IslandButton {
              size: 34
              iconSource: island.apps.editorIcon
              icon: island.apps.editorIcon ? "" : "code"
              iconSize: 18
              accessibleName: I18n.t("Klasörü editörde aç")
              onClicked: { agents.openInEditor(row.s); island.collapse() }
            }
            IslandButton {
              size: 34
              icon: "terminal"
              accessibleName: I18n.t("Terminale git")
              onClicked: { agents.focusTerminal(row.s); island.collapse() }
            }
          }
        }
      }
    }

    // ---- live feed
    // Compact by default; the corner button makes it taller. Either way it
    // scrolls (wheel or drag) and follows new output while you are at the
    // bottom; scroll up to read back and it stays where you left it.
    Rectangle {
      id: feed
      readonly property var s: page.previewSession
      readonly property bool busy: s !== null && agents.isBusy(s)
      readonly property var lines: page.feedLines(s && agents.previewOf === s.id ? agents.previewItems : [], s ? s.agent : "", busy)
      readonly property bool big: island.feedExpanded
      onLinesChanged: sync()
      Component.onCompleted: sync()
      function sync() {
        var src = lines
        for (var i = 0; i < src.length; i++) {
          var l = src[i]
          var row = { mark: l.g || "", body: l.t || "", tone: String(l.c), markTone: l.gc ? String(l.gc) : "",
            bold: !!l.strong, nested: !!l.indent }
          if (i < feedModel.count) {
            var old = feedModel.get(i)
            if (old.body !== row.body || old.mark !== row.mark || old.tone !== row.tone || old.markTone !== row.markTone) feedModel.set(i, row)
          } else feedModel.append(row)
        }
        if (feedModel.count > src.length) feedModel.remove(src.length, feedModel.count - src.length)
        if (feedList.follow) Qt.callLater(feedList.positionViewAtEnd)
      }
      visible: s !== null
      width: parent.width
      height: big ? 340 : 168
      radius: 16
      color: Qt.rgba(1, 1, 1, 0.05)
      border.width: 1
      border.color: Theme.hairline
      // Quick and soft: starts at once, eases out.
      Behavior on height {
        enabled: !Theme.reduceMotion
        NumberAnimation { duration: 260; easing.type: Easing.OutQuint }
      }

      Accessible.role: Accessible.StaticText
      Accessible.name: I18n.t("Canlı akış") + ": " + lines.slice(-8).map(l => l.t).join(". ")

      Row {
        id: feedHead
        x: 14
        y: 10
        spacing: 7
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 6; height: 6; radius: 3
          color: feed.busy ? island.profile(feed.s ? feed.s.agent : "").color : Theme.tertiary
          SequentialAnimation on opacity {
            running: feed.busy && page.shown && !Theme.reduceMotion
            loops: Animation.Infinite
            onRunningChanged: if (!running) parent.opacity = 1
            NumberAnimation { to: 0.3; duration: 650; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutSine }
          }
        }
        Label {
          anchors.verticalCenter: parent.verticalCenter
          text: I18n.t("Canlı akış") + (feed.s && feed.s.project ? " · " + feed.s.project : "")
          font.pixelSize: 11
          color: Theme.tertiary
        }
      }

      // Back to the newest line, when scrolled up.
      IslandButton {
        anchors.right: sizeButton.left
        anchors.rightMargin: 4
        anchors.verticalCenter: sizeButton.verticalCenter
        visible: !feedList.atYEnd && feedList.contentHeight > feedList.height
        size: 22
        iconSize: 12
        icon: "chevron-up"
        rotation: 180
        accessibleName: I18n.t("En alta git")
        onClicked: { feedList.follow = true; feedList.positionViewAtEnd() }
      }
      IslandButton {
        id: sizeButton
        anchors.right: parent.right
        anchors.rightMargin: 8
        y: 5
        size: 22
        iconSize: 12
        icon: "chevron-up"
        rotation: feed.big ? 0 : 180
        accessibleName: feed.big ? I18n.t("Akışı küçült") : I18n.t("Akışı büyüt")
        onClicked: { island.springMode = "resize"; island.feedExpanded = !island.feedExpanded }
      }

      ListView {
        id: feedList
        anchors.top: feedHead.bottom
        anchors.topMargin: 7
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 8
        clip: true
        spacing: 2
        // Updated row by row (not replaced) so the scroll position holds
        // while new output arrives.
        model: ListModel { id: feedModel }
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 2400
        // Sticks to the newest line until you scroll up.
        property bool follow: true
        onMovementEnded: follow = atYEnd
        onContentHeightChanged: if (follow) Qt.callLater(positionViewAtEnd)
        onHeightChanged: if (follow) Qt.callLater(positionViewAtEnd)
        Component.onCompleted: positionViewAtEnd()
        WheelHandler {
          // Wheel scrolls the feed by lines, not the island.
          onWheel: event => {
            feedList.contentY = Math.max(0, Math.min(feedList.contentHeight - feedList.height,
              feedList.contentY - event.angleDelta.y / 120 * 51))
            feedList.follow = feedList.atYEnd
          }
        }

        delegate: Item {
          id: lineItem
          required property string mark
          required property string body
          required property string tone
          required property string markTone
          required property bool bold
          required property bool nested
          // Same shape as a feedLines() entry, for the drawing below.
          readonly property var modelData: ({ g: mark, t: body, c: tone, gc: markTone, strong: bold, indent: nested })
          width: ListView.view.width - 6
          // Expanded, long lines wrap so nothing is cut; compact, they end in "…".
          height: feed.big ? Math.max(15, lineText.implicitHeight) : 15
          Item {
            id: glyph
            x: modelData.indent ? 12 : 0
            width: 14
            height: 15
            // Bullets are drawn, not typed: fonts disagree on ● and ⏺.
            readonly property bool dot: modelData.g === "●" || modelData.g === "•"
            Rectangle {
              visible: glyph.dot
              anchors.verticalCenter: parent.verticalCenter
              x: 1
              width: modelData.g === "●" ? 7 : 5
              height: width
              radius: width / 2
              color: modelData.gc || modelData.c
            }
            Text {
              visible: !glyph.dot
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.g
              color: modelData.gc || modelData.c
              font.family: Theme.mono
              font.pixelSize: 11
              renderType: Text.NativeRendering
            }
          }
          Text {
            id: lineText
            anchors.left: glyph.right
            anchors.leftMargin: 3
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: feed.big ? 0 : Math.round((15 - implicitHeight) / 2)
            text: modelData.t
            color: modelData.c
            elide: feed.big ? Text.ElideNone : Text.ElideRight
            wrapMode: feed.big ? Text.WrapAnywhere : Text.NoWrap
            textFormat: Text.PlainText
            font.family: Theme.mono
            font.pixelSize: 12
            font.weight: modelData.strong ? Font.DemiBold : Font.Normal
            renderType: Text.NativeRendering
          }
        }

        Label {
          visible: feed.lines.length === 0
          anchors.centerIn: parent
          text: I18n.t("Henüz bir şey yok")
          font.pixelSize: 12
          color: Theme.tertiary
        }
      }

      // Scroll position, thin and only while there is more than fits.
      Rectangle {
        visible: feedList.contentHeight > feedList.height + 1
        anchors.right: parent.right
        anchors.rightMargin: 4
        y: feedList.y + feedList.visibleArea.yPosition * feedList.height
        width: 3
        height: Math.max(16, feedList.visibleArea.heightRatio * feedList.height)
        radius: 1.5
        color: Qt.rgba(1, 1, 1, 0.22)
      }
    }

    // ---- message box: type to the watched session
    Rectangle {
      id: composer
      readonly property var s: page.previewSession
      readonly property bool can: s !== null && agents.canMessage(s)
      readonly property color tint: island.profile(s ? s.agent : "").color
      visible: s !== null
      width: parent.width
      height: 42
      radius: 21
      color: field.activeFocus ? Theme.fillHover : Theme.fill
      border.width: field.activeFocus ? 1 : 0
      border.color: tint
      Behavior on color { ColorAnimation { duration: Theme.ms(140) } }

      function send() {
        if (!agents.sendMessage(s, field.text)) return
        field.text = ""
        // Hands keyboard focus back before the text is typed into the terminal.
        island.collapse()
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: field.forceActiveFocus()
      }

      TextInput {
        id: field
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.right: sendButton.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        enabled: composer.can
        clip: true
        color: Theme.fg
        selectionColor: composer.tint
        selectedTextColor: "#000000"
        selectByMouse: true
        font.family: Theme.font
        font.pixelSize: 13
        renderType: Text.NativeRendering
        maximumLength: 4000
        Accessible.role: Accessible.EditableText
        Accessible.name: placeholder.text

        Keys.onReturnPressed: event => { composer.send(); event.accepted = true }
        Keys.onEnterPressed: event => { composer.send(); event.accepted = true }
        Keys.onEscapePressed: event => {
          if (text !== "") text = ""
          else island.collapse()
          event.accepted = true
        }

        Text {
          id: placeholder
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          visible: field.text === ""
          elide: Text.ElideRight
          text: !composer.s ? "" : composer.can
            ? I18n.t("%1 oturumuna yaz…").arg(composer.s.project || island.profile(composer.s.agent).name)
            : I18n.t("Önce terminaldeki soruyu yanıtla")
          color: Theme.tertiary
          font: field.font
          renderType: Text.NativeRendering
        }
      }

      IslandButton {
        id: sendButton
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        size: 30
        iconSize: 16
        icon: "arrow-up"
        prominent: field.text.trim() !== ""
        tint: composer.tint
        enabled2: composer.can && field.text.trim() !== ""
        accessibleName: I18n.t("Gönder")
        onClicked: composer.send()
      }
    }
    // Typing keeps the island open even if the pointer wanders off.
    Binding {
      target: page.island
      property: "composing"
      value: page.shown && field.activeFocus && field.text !== ""
    }

    // ---- empty / setup state
    Rectangle {
      visible: page.sessions.length === 0
      width: parent.width
      height: 72
      radius: 18
      color: Theme.fill
      Column {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: connect.visible ? connect.left : parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Label {
          width: parent.width
          text: !page.connectable ? I18n.t("%1 canlı oturum paylaşmıyor").arg(island.agentProduct)
            : page.connected ? I18n.t("Aktif oturum yok") : I18n.t("%1 bağlı değil").arg(island.agentProduct)
          font.pixelSize: 14
          strong: true
        }
        Label {
          width: parent.width
          text: !page.connectable ? I18n.t("Kısayol ve kullanım bilgisi yine burada.")
            : page.connected ? I18n.t("Bir oturum başlatınca burada görünür.")
            : page.profile.integration === "full" ? I18n.t("Bağlayınca oturumlar ve izinler burada.")
            : I18n.t("Bağlayınca oturumlar burada.")
          font.pixelSize: 13
          color: Theme.secondary
        }
      }
      IslandButton {
        id: connect
        visible: page.connectable && !page.connected
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        size: 36
        text: I18n.t("Bağla")
        prominent: true
        tint: island.agentColor
        accessibleName: I18n.t("%1 bağlantısını kur").arg(island.agentProduct)
        onClicked: agents.installHooks(island.agentId)
      }
    }

    // ---- shortcuts
    Row {
      spacing: 8
      IslandButton {
        size: 36
        icon: "plus"
        text: I18n.t("Yeni oturum")
        fontSize: 13
        accessibleName: I18n.t("Yeni ") + island.agentName + I18n.t(" oturumu")
        onClicked: { agents.newSession(); island.collapse() }
      }
      IslandButton {
        size: 36
        icon: "terminal"
        text: "Terminal"
        fontSize: 13
        enabled2: agents.focusSession !== null
        accessibleName: I18n.t("Etkin oturumun terminaline git")
        onClicked: { agents.focusTerminal(null); island.collapse() }
      }
      IslandButton {
        size: 36
        iconSource: island.apps.editorIcon
        icon: island.apps.editorIcon ? "" : "code"
        text: island.editorLabels[island.apps.editor] || I18n.t("Editör")
        fontSize: 13
        enabled2: agents.focusSession !== null
        accessibleName: I18n.t("Etkin oturumun klasörünü editörde aç")
        onClicked: { agents.openInEditor(null); island.collapse() }
      }
      IslandButton {
        size: 36
        icon: "trash"
        filled: false
        tint: Theme.secondary
        visible: agents.sessionList.some(s => !agents.isBusy(s))
        accessibleName: I18n.t("Biten oturumları temizle")
        onClicked: agents.clearFinished()
      }
    }
  }
}
