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

  // Images and text pasted onto the shelf are saved here, named by content
  // so the same clip is never stored twice. They go when they leave the shelf.
  readonly property string clipDir: stateDir + "/clips"
  readonly property real fullness: Math.min(1, count / limit)

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
    dropClips([path])
  }

  function clear() {
    var paths = items.map(it => it.path)
    items = []
    save()
    dropClips(paths)
  }

  function dropClips(paths) {
    // Only files the shelf itself saved: directly in clipDir, no "..".
    var mine = paths.filter(p => p.indexOf(clipDir + "/") === 0
      && p.substring(clipDir.length + 1).indexOf("/") === -1 && p.indexOf("..") === -1)
    if (mine.length) Quickshell.execDetached(["rm", "-f", "--"].concat(mine))
  }

  // ---- add what is on the clipboard
  // Copied files (Files, any file manager: text/uri-list) go on as they are;
  // a copied image or text is saved as a file first. `pasted(added, what)`
  // reports the outcome: what = "files" | "image" | "text" | "known" | "empty".
  signal pasted(int added, string what)

  function addFromClipboard() {
    if (clipboard.running) return
    clipboard.running = true
  }

  Process {
    id: clipboard
    command: ["sh", "-c", `
      dir="$1"
      types=$(wl-paste --list-types 2>/dev/null) || { echo empty; exit 0; }
      has() { printf '%s\n' "$types" | grep -qx "$1"; }
      if has text/uri-list; then
        echo files; wl-paste -n -t text/uri-list | tr -d '\r' | grep '^file://'; exit 0
      fi
      if has x-special/gnome-copied-files; then
        echo files; wl-paste -n -t x-special/gnome-copied-files | grep '^file://'; exit 0
      fi
      mkdir -p "$dir"
      img=$(printf '%s\n' "$types" | grep -m1 '^image/')
      if [ -n "$img" ]; then
        ext=\${img#image/}; ext=\${ext%%+*}; [ "$ext" = jpeg ] && ext=jpg
        tmp="$dir/.paste"; wl-paste -t "$img" > "$tmp" || exit 0
        f="$dir/Pano-$(sha1sum "$tmp" | cut -c1-8).$ext"
        mv -f "$tmp" "$f"; echo image; echo "$f"; exit 0
      fi
      if printf '%s\n' "$types" | grep -q '^text/plain'; then
        tmp="$dir/.paste"; wl-paste -n -t text/plain > "$tmp" || exit 0
        [ -s "$tmp" ] || { rm -f "$tmp"; echo empty; exit 0; }
        # A copied path is the file itself.
        p=$(head -c 4096 "$tmp")
        case "$p" in "~/"*) p="$HOME/\${p#??}" ;; esac
        if [ "$(wc -l < "$tmp")" -le 1 ] && [ -e "$p" ]; then
          rm -f "$tmp"; echo files; echo "$p"; exit 0
        fi
        f="$dir/Not-$(sha1sum "$tmp" | cut -c1-8).txt"
        mv -f "$tmp" "$f"; echo text; echo "$f"; exit 0
      fi
      echo empty`, "sh", shelf.clipDir]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.split("\n").filter(l => l !== "")
        var what = lines.length ? lines[0] : "empty"
        var paths = lines.slice(1)
        if (!paths.length) { shelf.pasted(0, "empty"); return }
        var fresh = paths.filter(p => !shelf.items.some(it => it.path === shelf.decode(p)))
        var added = shelf.addUrls(paths)
        shelf.pasted(fresh.length, fresh.length ? what : (added ? "known" : "empty"))
      }
    }
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
