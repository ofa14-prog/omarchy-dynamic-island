# Dynamic Island for Omarchy

[Türkçe](README.tr.md)

An Apple-style Dynamic Island in the middle of the [Omarchy](https://omarchy.org) bar. One black
shape that springs open, splits into bubbles and shakes like the real thing, with live music,
timers, screen recording, a file shelf, launch shortcuts, and your **Claude Code** sessions,
including approving or denying tool permissions right from the island.

## Features

| | |
|---|---|
| **Compact** | Idle clock, or the live activity's leading/trailing content around a clean middle |
| **Bubbles** | A second live activity splits off to the right, a third to the left. Each works on its own |
| **Peek** | Brief banner for a track change, Claude finishing, charging… |
| **Expanded** | Home · Music · Claude · Timer · Shelf, as a segmented control |
| **Alerts** | A Claude permission request or a finished timer opens the island and holds it open |

- **Home**: time and date, Claude usage rings (5-hour / weekly), battery, shortcuts to your
  *default* agent, editor, browser, file manager and terminal (with their own app icons), quick timers.
- **Music**: any MPRIS player; artwork, a draggable scrubber, transport. The waveform takes the artwork's color.
- **Claude Code**: every session, what it is doing right now, elapsed time; jump to its terminal,
  open its folder in your editor, start a new session.
- **Permissions**: tool, file or command, colored diff; **Allow / Always / Deny**. Claude Code races
  the island against its own terminal prompt: answer in either place, the other one closes.
- **Timer**: countdown (+1 min, pause, repeat) and stopwatch, with a chime when time is up.
- **Screen recording**: Omarchy's recorder shows as the red recording activity; click to stop.
- **Shelf**: drop files on the island to park them, drag them back out into any app later.
- Claude's own spinner (`· ✢ * ✶ ✻ ✽`) and status shimmer, captured from a live `claude` session.
- English and Turkish UI; follows the Omarchy system font.

### Interaction

| Gesture | Result |
|---|---|
| Hover | Grows slightly and leans toward the pointer; opens after 380 ms |
| Click | Opens (the shape sinks while pressed) |
| Right-click | Home page |
| Middle-click on music | Play / pause |
| Scroll on the compact island | Volume |
| Drag a file onto it | Opens the shelf |
| Pointer leaves | Closes after 650 ms (not while an alert is waiting) |
| Bubble: click / right-click / middle-click | Open it / swap it into the island / play-pause |

Keyboard while the island has focus: `Esc` close or deny · `Enter`/`Y` allow · `A` always ·
`N` deny · `T` go to terminal · `[` `]` switch tabs · `Tab` move between controls · `Space` play/pause.

## Requirements

- Omarchy 4 (the Quickshell-based `omarchy-shell`) on Hyprland
- Already part of Omarchy: `python3`, `jq`, `pw-play`, `notify-send`, `wl-copy`, `xdg-open`
- Optional: [Claude Code](https://claude.com/claude-code) for the Claude features

## Install

```sh
omarchy plugin add https://github.com/ofa14-prog/omarchy-dynamic-island.git
omarchy plugin enable io.github.ofa14-prog.dynamic-island
```

Make room in the middle of the bar (moves the center widgets to the right; reversible):

```sh
~/.config/omarchy/plugins/io.github.ofa14-prog.dynamic-island/bin/dynamic-island-bar-setup
# undo: …/bin/dynamic-island-bar-setup --undo
```

Connect Claude Code, either with the **Connect** button on the island's Claude page or:

```sh
~/.config/omarchy/plugins/io.github.ofa14-prog.dynamic-island/bin/dynamic-island-claude-setup
```

It backs up `~/.claude/settings.json` (or `$CLAUDE_CONFIG_DIR`) and adds hooks; `--remove` takes
only those out again. State events run `async`, so the island never slows Claude down. When the
island is not running, the hook prints nothing and Claude behaves exactly as without it.

Optional keybindings, in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + ALT + I", "Dynamic Island", "omarchy-shell -q dynamicisland toggle")
o.bind("SUPER + ALT + Y", "Claude: allow", "omarchy-shell -q dynamicisland approve")
o.bind("SUPER + ALT + N", "Claude: deny", "omarchy-shell -q dynamicisland deny")
o.bind("SUPER + ALT + T", "Dynamic Island: timer", "omarchy-shell -q dynamicisland open timer")
```

## Settings

Optional `~/.config/omarchy/dynamic-island.json`; changes apply live.

| Key | Default | |
|---|---|---|
| `language` | `"auto"` | `"en"`, `"tr"`, or `"auto"` (Turkish on a `tr_*` locale, else English) |
| `hoverExpand` / `hoverDelay` | `true` / `380` | Open on hover |
| `collapseDelay` | `650` | Close after the pointer leaves (ms) |
| `reduceMotion` | `false` | Short fades instead of springs and shakes |
| `idleClock` / `clockFormat` / `locale` | `true` / `"ddd d MMM  HH:mm"` / `""` | Empty `locale` follows the language |
| `priority` | `["claude","recording","timer","music"]` | Which activity takes the island first |
| `compactHeight` / `topOffset` | `"auto"` | Measured from your bar; numbers override |
| `expandedWidth` | `500` | |
| `color` | `"#000000"` | Island color |
| `screen` | `""` | Empty follows the focused monitor |
| `autoExpandPermission` | `true` | Open on Claude permission requests |
| `hideOnFullscreen` | `true` | Hide over fullscreen windows (alerts still show) |
| `peekOnTrackChange` / `peekOnClaudeDone` | `true` | |
| `shortcuts` | `[]` | Empty uses your defaults. Example: `[{"icon":"globe","label":"Web","command":["omarchy-launch-browser"]}]`. Actions: `agent`, `editor`, `browser`, `files`, `terminal`, `screenshot`, `stopwatch`, `{"action":"timer","seconds":600}`, `page:<name>` |

## IPC

```sh
omarchy-shell dynamicisland toggle | open <home|music|claude|timer|shelf> | close
omarchy-shell dynamicisland approve | always | deny
omarchy-shell dynamicisland timer 300 | stopwatch | timerStop
omarchy-shell dynamicisland shelfAdd /path/to/file
omarchy-shell dynamicisland notify "Title" "Subtitle"
omarchy-shell dynamicisland status
```

## How the Claude bridge works

`bin/dynamic-island-hook` is registered for Claude Code's lifecycle events and writes one JSON
line per event to `$XDG_RUNTIME_DIR/dynamic-island/claude.sock`, in a directory only you can open.
`PermissionRequest` keeps the connection open until the island answers; the hook hands that
verdict back to Claude Code as its `PermissionRequest` decision. Nothing leaves your machine.

## Uninstall

```sh
~/.config/omarchy/plugins/io.github.ofa14-prog.dynamic-island/bin/dynamic-island-claude-setup --remove
~/.config/omarchy/plugins/io.github.ofa14-prog.dynamic-island/bin/dynamic-island-bar-setup --undo
omarchy plugin remove io.github.ofa14-prog.dynamic-island
```

## Credits

Interface icons from [Reicon](https://github.com/dqev/reicon) (MIT; base icons from Solar Icons,
CC BY 4.0). The Claude mark via Simple Icons; Claude is a trademark of Anthropic, and this project
is not affiliated with Anthropic. See [icons/NOTICE.md](icons/NOTICE.md).

MIT License, see [LICENSE](LICENSE).
