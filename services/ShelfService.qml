import QtQuick
import Quickshell
import Quickshell.Io

// The file shelf: drop files on the island to park them, drag them back out
// into any app later. Stores references (paths), never copies, and survives
// restarts.
Item {
  id: shelf

  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/dynamic-island"
  readonly property string storePath: stateDir + "/shelf.json"
  property var items: []           // [{ path, name, ext, isImage, added }]
  readonly property int count: items.length
  readonly property int limit: 24

  readonly property var imageExt: ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "avif", "heic"]

  function decode(url) {
    var s = String(url)
    if (s.indexOf("file://") === 0) s = s.substring(7)
    try { s = decodeURIComponent(s) } catch (e) {}
    return s
  }

  function entryFor(path) {
    var clean = path.replace(/\/+$/, "")
    var name = clean.substring(clean.lastIndexOf("/") + 1) || clean
    var dot = name.lastIndexOf(".")
    var ext = dot > 0 ? name.substring(dot + 1).toLowerCase() : ""
    return { path: clean, name: name, ext: ext, isImage: imageExt.indexOf(ext) !== -1, added: Date.now() }
  }

  function addUrls(urls) {
    var next = items.slice()
    var added = 0
    for (var i = 0; i < urls.length; i++) {
      var path = decode(urls[i])
      if (!path || path[0] !== "/") continue
      next = next.filter(it => it.path !== path)
      next.unshift(entryFor(path))
      added++
    }
    if (!added) return 0
    items = next.slice(0, limit)
    save()
    return added
  }

  function remove(path) {
    items = items.filter(it => it.path !== path)
    save()
  }

  function clear() {
    items = []
    save()
  }

  function open(path) { Quickshell.execDetached(["xdg-open", path]) }
  // Nautilus (Omarchy's default) can highlight the file; any other file
  // manager opens the containing folder.
  function reveal(path) {
    Quickshell.execDetached(["sh", "-c",
      "if command -v nautilus >/dev/null; then exec nautilus --select \"$1\"; else exec xdg-open \"$(dirname \"$1\")\"; fi",
      "sh", path])
  }
  function copyPaths() {
    if (!items.length) return
    Quickshell.execDetached(["wl-copy", items.map(it => it.path).join("\n")])
  }
  function uriList(list) {
    return (list || items).map(it => "file://" + encodeURI(it.path)).join("\r\n")
  }

  function save() {
    store.setText(JSON.stringify(items))
  }

  Process {
    running: true
    command: ["mkdir", "-p", shelf.stateDir]
  }

  FileView {
    id: store
    path: shelf.storePath
    printErrors: false
    atomicWrites: true
    blockLoading: true
    onLoaded: {
      try {
        var parsed = JSON.parse(text())
        if (Array.isArray(parsed)) shelf.items = parsed.filter(it => it && it.path)
      } catch (e) {}
    }
  }

  // Files deleted or moved since they were shelved quietly drop out.
  Process {
    id: prune
    stdout: StdioCollector {
      onStreamFinished: {
        var missing = text.split("\n").filter(l => l !== "")
        if (missing.length) {
          shelf.items = shelf.items.filter(it => missing.indexOf(it.path) === -1)
          shelf.save()
        }
      }
    }
  }

  function pruneMissing() {
    if (!items.length || prune.running) return
    prune.command = ["sh", "-c", "for p; do [ -e \"$p\" ] || printf '%s\\n' \"$p\"; done", "sh"].concat(items.map(it => it.path))
    prune.running = true
  }
}
