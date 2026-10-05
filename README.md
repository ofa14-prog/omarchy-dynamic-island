# Dynamic Island for Omarchy

[Türkçe](README.tr.md)

An Apple-style Dynamic Island in the middle of the [Omarchy](https://omarchy.org) bar. One black
shape that springs open, splits into bubbles and shakes like the real thing, with live music,
timers, screen recording, a file shelf, launch shortcuts, and your **coding agent** sessions
(Claude Code, Codex, OpenCode, Gemini CLI), including approving or denying tool permissions
right from the island.

![Dynamic Island](preview.png)

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
- **Agent**: follows Omarchy's default agent (`omarchy default agent …`): its name, mark, colors and
  spinner. Every session, what it is doing right now, elapsed time; jump to its terminal, open its
  folder in your editor, start a new session.
- **Permissions**: tool, file or command, colored diff; **Allow / Always / Deny**. The agent races
  the island against its own terminal prompt: answer in either place, the other one closes.
- **Timer**: countdown (+1 min, pause, repeat) and stopwatch, with a chime when time is up.
- **Screen recording**: Omarchy's recorder shows as the red recording activity; click to stop.
- **Shelf**: drop files on the island to park them, drag them back out into any app later.
- Claude Code's own spinner (`· ✢ * ✶ ✻ ✽`) and status shimmer, captured from a live `claude`
  session; other agents use their CLI's braille spinner.
- Sharp at fractional scaling: text is hinted and icons are rasterized at the screen's real pixel
  density, with no offscreen passes.

### Agents

| Default agent | Live sessions | Permissions on the island |
|---|---|---|
| Claude Code | yes | Allow · Always · Deny |
| Codex | yes | Allow · Deny |
| OpenCode | yes | Allow · Always · Deny |
| Gemini CLI | yes | Shown; answered in the terminal (Gemini hooks cannot answer) |
| Pi, Oh My Pi, Grok, Crush, Cursor, Copilot, Hermes, OpenClaw, Muse | — | — (no event API; branding, launch and usage only) |

Headless runs (`claude -p`, SDK scripts) never show up as sessions or banners.
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
- Optional: any of the agents above

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

Connect your agents, either with the **Connect** button on the island's agent page (for the
default agent) or:

```sh
~/.config/omarchy/plugins/io.github.ofa14-prog.dynamic-island/bin/dynamic-island-agent-setup claude codex
# any of: claude codex gemini opencode all · --remove … · --status
```

| Agent | What it changes |
|---|---|
| Claude Code | hooks in `~/.claude/settings.json` (or `$CLAUDE_CONFIG_DIR`) |
| Codex | hooks in `~/.codex/hooks.json` (or `$CODEX_HOME`) |
| Gemini CLI | hooks in `~/.gemini/settings.json` |
| OpenCode | a plugin symlink in `~/.config/opencode/plugins/` |

Each file is backed up first and only the island's own entries are added or removed. State events
run asynchronously where the agent supports it. When the island is not running, the hooks print
nothing and the agent behaves exactly as without them.

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
| `agent` | `""` | Agent the island is styled after; empty follows `omarchy default agent` |
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
| `peekOnTrackChange` / `peekOnAgentDone` | `true` | |
| `shortcuts` | `[]` | Empty uses your defaults. Example: `[{"icon":"globe","label":"Web","command":["omarchy-launch-browser"]}]`. Actions: `agent`, `editor`, `browser`, `files`, `terminal`, `screenshot`, `stopwatch`, `{"action":"timer","seconds":600}`, `page:<name>` |

## IPC

```sh
omarchy-shell dynamicisland toggle | open <home|music|claude|timer|shelf> | close
omarchy-shell dynamicisland approve | always | deny
omarchy-shell dynamicisland timer 300 | stopwatch | timerStop
omarchy-shell dynamicisland shelfAdd /path/to/file
omarchy-shell dynamicisland notify "Title" "Subtitle"
omarchy-shell dynamicisland status | sessions | events
```

## How the agent bridge works

`bin/dynamic-island-hook --agent <id>` is registered for the agent's lifecycle events (Gemini's
events are mapped onto the same vocabulary) and writes one JSON line per event to
`$XDG_RUNTIME_DIR/dynamic-island/agents.sock`, in a directory only you can open. A permission
request keeps the connection open until the island answers, and the hook hands that verdict back
as the agent's own hook decision. OpenCode uses `agents/opencode/dynamic-island.js`, which listens
to OpenCode's events and answers permissions through its API. Nothing leaves your machine.

## Uninstall

```sh
~/.config/omarchy/plugins/io.github.ofa14-prog.dynamic-island/bin/dynamic-island-agent-setup --remove all
~/.config/omarchy/plugins/io.github.ofa14-prog.dynamic-island/bin/dynamic-island-bar-setup --undo
omarchy plugin remove io.github.ofa14-prog.dynamic-island
```

## Credits

Interface icons from [Reicon](https://github.com/dqev/reicon) (MIT; base icons from Solar Icons,
CC BY 4.0). Agent marks (Claude, OpenAI, Gemini, OpenCode, Copilot, Cursor, X) via Simple Icons;
they are trademarks of their owners, and this project is not affiliated with any of them. See [icons/NOTICE.md](icons/NOTICE.md).

MIT License, see [LICENSE](LICENSE).
