import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Picks the player worth showing and keeps its position fresh while visible.
Item {
  id: music

  property bool tracking: false   // a view shows the progress bar

  readonly property var players: Mpris.players ? Mpris.players.values : []
  // The player you picked on the music page. It stays the shown one while it
  // exists, whatever else starts or stops; when it goes away the choice
  // falls back to automatic (the one playing).
  property string preferredKey: ""
  // The player that most recently started playing. When a player starts,
  // it takes over: an earlier pick is dropped, so switching from one app to
  // another just works (art, colors and controls follow the new one).
  property string lastStartedKey: ""
  Instantiator {
    model: Mpris.players
    delegate: Connections {
      required property var modelData
      target: modelData
      function onIsPlayingChanged() {
        if (!modelData.isPlaying) return
        var key = music.keyOf(modelData)
        music.lastStartedKey = key
        if (music.preferredKey && music.preferredKey !== key) music.preferredKey = ""
      }
    }
  }

  function keyOf(p) { return p ? (p.dbusName || p.identity || "") : "" }
  function hasTrack(p) { return p && (p.trackTitle || p.trackArtist) }

  // Every player with something loaded, playing ones first. Browsers may
  // also expose a playerctld proxy that mirrors a real player: left out.
  readonly property var choices: {
    var list = players.filter(p => hasTrack(p) && keyOf(p).indexOf("playerctld") === -1)
    if (!list.length) list = players.filter(p => hasTrack(p))
    return list.slice().sort((a, b) => (b.isPlaying ? 1 : 0) - (a.isPlaying ? 1 : 0))
  }
  readonly property bool pinned: preferredKey !== "" && choices.some(p => keyOf(p) === preferredKey)

  readonly property var player: {
    var list = choices
    if (list.length === 0) return null
    if (preferredKey) {
      var pref = list.filter(p => keyOf(p) === preferredKey)
      if (pref.length) return pref[0]
    }
    // Several playing at once: the one started last.
    var playing = list.filter(p => p.isPlaying)
    var newest = playing.filter(p => keyOf(p) === lastStartedKey)
    if (newest.length) return newest[0]
    return playing.length ? playing[0] : list[0]
  }

  function select(p) { preferredKey = keyOf(p) }
  function unpin() { preferredKey = "" }
  // Next player in the list (wraps), for a quick cycle.
  function cycle() {
    if (choices.length < 2) return
    var i = choices.indexOf(player)
    select(choices[(i + 1) % choices.length])
  }
  // A readable name: the app, plus the tab or track when several share it.
  function nameOf(p) {
    if (!p) return ""
    var app = p.identity || keyOf(p).replace("org.mpris.MediaPlayer2.", "").split(".")[0]
    return app.charAt(0).toUpperCase() + app.slice(1)
  }
  function iconOf(p) {
    if (!p) return ""
    void DesktopEntries.applications.values   // entries load asynchronously
    var id = p.desktopEntry || ""
    var entry = (id && (DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id)))
      || (p.identity && DesktopEntries.heuristicLookup(p.identity))
      || DesktopEntries.heuristicLookup(keyOf(p).replace("org.mpris.MediaPlayer2.", "").split(".")[0])
    return entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""
  }

  readonly property bool available: player !== null
  readonly property bool playing: player ? player.isPlaying : false
  readonly property string title: player ? (player.trackTitle || "") : ""
  readonly property string artist: player ? (player.trackArtist || "") : ""
  readonly property string album: player ? (player.trackAlbum || "") : ""
  readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
  readonly property string identity: player ? (player.identity || "") : ""
  readonly property real length: player && player.lengthSupported ? player.length : 0
  readonly property real position: player && player.positionSupported ? player.position : 0
  readonly property bool canSeek: player ? (player.canSeek && player.positionSupported && length > 0) : false
  readonly property bool canNext: player ? player.canGoNext : false
  readonly property bool canPrevious: player ? player.canGoPrevious : false
  readonly property string trackKey: title + "\u0001" + artist

  // The waveform and progress tint come from the artwork, as on iOS: the most
  // vivid of a few quantized colors, lifted so it stays legible on black.
  ColorQuantizer {
    id: quantizer
    source: music.artUrl
    depth: 3
    rescaleSize: 48
  }
  // No artwork (many video sites, some players): neutral colors. The
  // quantizer keeps its last result when the source goes away, which would
  // carry the previous player's colors over.
  readonly property bool hasArt: artUrl !== ""
  readonly property color accent: {
    if (!hasArt) return "#ffffff"
    var colors = quantizer.colors || []
    var best = null, bestScore = -1
    for (var i = 0; i < colors.length; i++) {
      var c = colors[i]
      var score = c.hsvSaturation * 0.7 + c.hsvValue * 0.3
      if (c.hsvValue < 0.25) score -= 1
      if (score > bestScore) { bestScore = score; best = c }
    }
    if (!best) return "#ffffff"
    return Qt.hsva(best.hsvHue < 0 ? 0 : best.hsvHue, Math.min(best.hsvSaturation, 0.75), Math.max(best.hsvValue, 0.85), 1)
  }

  // Ambient glow around the island: the two most vivid, clearly different
  // colors of the artwork (left and right), lifted so they glow on black.
  readonly property var ambient: {
    if (!hasArt) return [Qt.rgba(0.85, 0.88, 0.95, 1), Qt.rgba(0.85, 0.88, 0.95, 1)]
    var colors = (quantizer.colors || []).filter(c => c.hsvValue >= 0.18)
    var lift = c => Qt.hsva(c.hsvHue < 0 ? 0 : c.hsvHue, Math.min(1, c.hsvSaturation * 1.15), Math.max(c.hsvValue, 0.8), 1)
    if (!colors.length) return [accent, accent]
    colors.sort((a, b) => (b.hsvSaturation * 0.75 + b.hsvValue * 0.25) - (a.hsvSaturation * 0.75 + a.hsvValue * 0.25))
    var first = colors[0], second = null
    for (var i = 1; i < colors.length && !second; i++) {
      var dh = Math.abs(colors[i].hsvHue - first.hsvHue)
      if (Math.min(dh, 1 - dh) > 0.07 || Math.abs(colors[i].hsvValue - first.hsvValue) > 0.3) second = colors[i]
    }
    return [lift(first), lift(second || first)]
  }

  // Last time something stopped playing, so a pause doesn't instantly drop
  // the live activity.
  property double lastPlayingAt: 0
  onPlayingChanged: lastPlayingAt = Date.now()

  // A new track is announced only once it has settled and is actually
  // playing: browsers flip metadata while you hover video previews, change
  // tabs or seek, and none of that is "the song changed".
  signal trackChanged()
  property string lastTrackKey: ""
  property string announcedKey: ""
  onTrackKeyChanged: {
    if (title === "") return
    if (lastTrackKey === "") { lastTrackKey = trackKey; announcedKey = trackKey; return }
    lastTrackKey = trackKey
    settle.restart()
  }
  Timer {
    id: settle
    interval: 1500
    onTriggered: {
      if (music.trackKey !== music.lastTrackKey || music.trackKey === music.announcedKey) return
      music.announcedKey = music.trackKey
      if (music.playing && music.length > 0 && music.length < 4 * 3600) music.trackChanged()
    }
  }

  function togglePlaying() { if (player && player.canTogglePlaying) player.togglePlaying() }
  function next() { if (player && player.canGoNext) player.next() }
  function previous() {
    if (!player) return
    // Like every media app: first press restarts, a quick second press skips back.
    if (player.positionSupported && player.position > 4 && player.canSeek) player.position = 0
    else if (player.canGoPrevious) player.previous()
  }
  function seek(seconds) { if (canSeek) player.position = Math.max(0, Math.min(length, seconds)) }
  function raise() { if (player && player.canRaise) player.raise() }

  FrameAnimation {
    // Position is not pushed by MPRIS; ask for it a few times a second.
    property real acc: 0
    running: music.tracking && music.playing
    onTriggered: {
      acc += frameTime
      if (acc < 0.25) return
      acc = 0
      if (music.player) music.player.positionChanged()
    }
  }
}
