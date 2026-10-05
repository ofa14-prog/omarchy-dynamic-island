import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Picks the player worth showing and keeps its position fresh while visible.
Item {
  id: music

  property bool tracking: false   // a view shows the progress bar

  readonly property var players: Mpris.players ? Mpris.players.values : []
  property string preferredKey: ""

  function keyOf(p) { return p ? (p.dbusName || p.identity || "") : "" }
  function hasTrack(p) { return p && (p.trackTitle || p.trackArtist) }

  readonly property var player: {
    var list = players.filter(p => hasTrack(p))
    if (list.length === 0) return null
    if (preferredKey) {
      var pref = list.filter(p => keyOf(p) === preferredKey)
      if (pref.length) return pref[0]
    }
    var playing = list.filter(p => p.isPlaying)
    // Browsers expose a playerctld-style proxy as well; prefer real players.
    playing.sort((a, b) => (keyOf(a).indexOf("playerctld") !== -1) - (keyOf(b).indexOf("playerctld") !== -1))
    return playing.length ? playing[0] : list[0]
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
  readonly property color accent: {
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

  // Last time something stopped playing, so a pause doesn't instantly drop
  // the live activity.
  property double lastPlayingAt: 0
  onPlayingChanged: lastPlayingAt = Date.now()

  signal trackChanged()
  property string lastTrackKey: ""
  onTrackKeyChanged: {
    if (trackKey === lastTrackKey || title === "") return
    var first = lastTrackKey === ""
    lastTrackKey = trackKey
    if (!first && playing) trackChanged()
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
