# Dynamic Island for Omarchy

[Türkçe](README.tr.md)

An Apple-style Dynamic Island in the middle of the [Omarchy](https://omarchy.org) bar. One black
shape that springs open, splits into bubbles and shakes like the real thing, with live music,
timers, screen recording, a file shelf, launch shortcuts, and your **coding agent** sessions
(Claude Code, Codex, Antigravity CLI, OpenCode), including approving or denying tool permissions
right from the island.

![Dynamic Island](preview.png)

## Screenshots

**Closed**: the agent at work in the middle, music and a timer split off into bubbles.

<p align="center"><img src="docs/screenshots/compact.png" width="560" alt="Closed island with music and timer bubbles"></p>

| Home | Music |
|---|---|
| <img src="docs/screenshots/home.png" alt="Home page: clock, usage and battery rings, shortcuts, quick timers"> | <img src="docs/screenshots/music.png" alt="Music page with artwork-colored backdrop and player picker"> |
| **Agent**: sessions, live feed, message box | **Permission**: allow / always / deny from the island |
| <img src="docs/screenshots/agent.png" alt="Agent page with two Claude Code sessions and the live feed"> | <img src="docs/screenshots/permission.png" alt="Permission request for writing notes.md"> |
| **Timer** | **Shelf** |
| <img src="docs/screenshots/timer.png" alt="Timer page counting down"> | <img src="docs/screenshots/shelf.png" alt="Shelf with four files"> |

## Features

| | |
|---|---|
| **Compact** | Idle clock, or the live activity's leading/trailing content around a clean middle |
| **Bubbles** | A second live activity splits off to the right, a third to the left. Each works on its own; double-click one to swap it with the center |
| **Peek** | Brief banner for a track change, Claude finishing, charging… |
| **Expanded** | Home · Music · Claude · Timer · Shelf, as a segmented control |
| **Alerts** | A Claude permission request or a finished timer opens the island and holds it open |

- **Home**: time and date, Claude usage rings (5-hour / weekly), battery, shortcuts to your
  *default* agent, editor, browser, file manager and terminal (with their own app icons), quick timers.
- **Music**: any MPRIS player; artwork, a draggable scrubber, transport. The waveform takes the artwork's color.
  The music activity shows only while something plays and leaves the moment it is paused or closed.
- **Refresh**: the round arrow on Home restarts the whole Omarchy shell (bar and island reload);
  right-click it to only clear a stuck island (sessions, requests, alerts).
- **Agent**: follows Omarchy's default agent (`omarchy default agent …`): its name, mark, colors and
  spinner. Every session, what it is doing right now, elapsed time; jump to its terminal, open its
  folder in your editor, start a new session.
- **AI tab**: named after what is running: the agent's mark and name when one agent has a live
  session, only the marks when several do (two, then "…"), and "AI" when none does.
- **Agent bar**: with several agents running, the AI page's mark becomes a small bar. Click it to
  open it onto the running agents and pick one: sessions, live feed, usage, Connect and "New
  session" switch to it. It opens on the most urgent agent (waiting on you, then working) and
  goes back to that after the island closes. A dot on the closed bar, or on an agent's icon,
  means another agent is busy (its color) or waiting for you (orange, pulsing).
- **Two agents at once**: while two different agents are working, the closed island splits into two
  halves, one per agent (spinner, status, mark); each keeps its side while it works. The halves
  act on their own: the one under the pointer lights up in its agent's color, and hovering or
  clicking it opens that agent's page. When one of them goes idle the halves join back into one island.
- **Usage**: the AI page and Home show the 5-hour and weekly limits of the agent on screen: Claude
  and Codex from Omarchy's agents panel, Antigravity from `agy -p /usage` (local, no model call;
  the quota group of the model agy is set to).
- **Live feed** (Claude Code, Codex, Antigravity CLI): under the sessions, the last prompts, replies, tool calls and
  their output, drawn the way the agent's terminal draws them. With several sessions, click a row
  to watch that one. It scrolls (wheel or drag) and follows new output while you are at the
  bottom; the corner arrow makes it taller and shows every line of output, nothing cut.
- **Message box**: type under the feed and press Enter to send it to that session's prompt. In
  tmux it goes straight to the pane in the background; otherwise the session's own terminal window
  is focused and the text typed into it (`wtype`). It never guesses a window: if the session's
  window can't be found exactly, nothing is typed. Disabled while a permission or question is open.
- **Permissions**: tool, file or command, colored diff; **Allow / Always / Deny**. The agent races
  the island against its own terminal prompt: answer in either place, the other one closes.
- **Timer**: countdown (+1 min, pause, repeat) and stopwatch, with a chime when time is up.
- **Screen recording**: Omarchy's recorder shows as the red recording activity; click to stop.
- **Several players**: when more than one app has media (two browsers, a browser and Spotify…),
  a small chip next to the transport buttons names the one shown. Click it for the list and pick
  the one to follow; it stays picked until another player starts playing (that one takes over). Right-click or scroll the chip for the
  next one, "Automatic" to follow whatever plays.
- **Ambient light**: while music plays, the artwork's colors glow softly from behind the player,
  like YouTube's ambient mode (left and right take its two most vivid colors). Only the player
  glows: the island when music is in the middle, otherwise the music bubble. Open on the music
  tab, the colors fill the card itself and drift slowly, like Apple Music. With
  [cava](https://github.com/karlstav/cava) installed (`sudo pacman -S cava`) the glow breathes with
  the sound; without it, it holds still. Turn off with `"ambient": false` (or just the movement
  with `"ambientAudio": false`).
- **Shelf**: drop files on the island to park them, drag them back out into any app later. While
  it holds anything, a shelf bubble shows how many items and how full it is; click the bubble to
  put what you copied on the shelf (files from Files, or a copied image or text, saved as a file).
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
| Antigravity CLI | yes | Allow · Always (this conversation) · Deny, pressed as agy's own prompt keys |
| Pi, Oh My Pi, Grok, Crush, Cursor, Copilot, Hermes, OpenClaw, Muse | — | — (no event API; branding, launch and usage only) |

Headless runs (`claude -p`, SDK scripts) never show up as sessions or banners.
- English, Spanish, Russian and Turkish UI; follows the Omarchy system font.

Antigravity CLI (`agy`) tells hooks about every tool call but not about its permission prompt, and a
hook's "allow" does not skip that prompt. So the island watches agy's own log (`Surfacing tool
confirmation … at step N`, matched to the hook's step) and, when you answer on the island, presses
the prompt's key in agy's terminal: `1` run, `2` allow for this conversation, `Esc` cancel. It uses
tmux in the background when agy runs there, otherwise Hyprland's `send_shortcut` straight to agy's
own window (matched exactly by process), which never moves focus. Answering a permission on the
island never takes you to the terminal, for any agent. Answering in the terminal closes the island's card on its own.

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
| Bubble: click | Open that activity (shelf bubble: add the clipboard to the shelf) |
| Bubble: double-click (or right-click) | Swap it with the center: it moves into the island, the center takes its place |
| Bubble: middle-click | Play / pause music, pause / resume the timer |

Keyboard while the island has focus: `Esc` close or deny · `Enter`/`Y` allow · `A` always ·
`N` deny · `T` go to terminal · `[` `]` switch tabs · `Tab` move between controls · `Space` play/pause.

## Requirements

- Omarchy 4 (the Quickshell-based `omarchy-shell`) on Hyprland
- Already part of Omarchy: `python3`, `jq`, `wl-clipboard`, `wtype`, `tmux`, `pw-play`,
  `notify-send`, `xdg-open`, `nautilus`
- Optional:
  - [`cava`](https://github.com/karlstav/cava) (`sudo pacman -S cava`): the ambient light moves with
    the sound; without it the light holds still
  - `sound-theme-freedesktop`: the chime when a timer ends; without it the timer ends silently
    (the notification still shows)
  - any of the agents above

Nothing is installed or changed on your system when you enable the plugin. Connecting an agent
and making room in the bar are separate, explicit steps (below), and both can be undone.

## Install

```sh
omarchy plugin add https://github.com/ofa14-prog/omarchy-dynamic-island.git
omarchy plugin enable io.github.ofa14-prog.dynamic-island
```

### Recommended setup

The island is designed for the [Islands](https://github.com/DanielLob-o/Islands) bar
(`lobo.islands`, also on plugins.omarchy.org) with an empty bar center. On any other bar, or with
widgets in the center, the island's Home page shows a **Set up** card that does this for you;
nothing changes until you press it. From a terminal:

```sh
~/.config/omarchy/plugins/io.github.ofa14-prog.dynamic-island/bin/dynamic-island-bar-setup --recommended
# only clear the center, keep your bar: …/bin/dynamic-island-bar-setup
# undo (restores your previous bar and layout): …/bin/dynamic-island-bar-setup --undo
```

`--recommended` adds the Islands bar with `omarchy plugin add` if it is missing and switches to
it, then moves the center widgets to the start of the right section with `omarchy bar move`.
Your previous `~/.config/omarchy/shell.json` is backed up first. The island also works on
Omarchy's stock bar.

Connect your agents, either with the **Connect** button on the island's agent page (for the
default agent) or:

```sh
~/.config/omarchy/plugins/io.github.ofa14-prog.dynamic-island/bin/dynamic-island-agent-setup claude codex
# any of: claude codex antigravity opencode all · --remove … · --status
```

| Agent | What it changes |
|---|---|
| Claude Code | hooks in `~/.claude/settings.json` (or `$CLAUDE_CONFIG_DIR`) |
| Codex | hooks in `~/.codex/hooks.json` (or `$CODEX_HOME`) |
| Antigravity CLI | hooks in `~/.gemini/config/hooks.json` (shared by the Antigravity CLI, IDE and app) |
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
| `language` | `"en"` | `"en"`, `"es"`, `"ru"`, `"tr"`, or `"auto"` (the system language if the island has it, else English). Also set from the flag on the Home page |
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
| `agentQuietSeconds` | `180` | A busy turn with no sign of life for this long shows as "quiet" |
| `shortcuts` | `[]` | Empty uses your defaults. Example: `[{"icon":"globe","label":"Web","command":["omarchy-launch-browser"]}]`. Actions: `agent`, `editor`, `browser`, `files`, `terminal`, `screenshot`, `stopwatch`, `{"action":"timer","seconds":600}`, `page:<name>` |

## Languages

English (default), Spanish, Russian and Turkish. Pick one from the flag button on the Home page
(it is saved to `~/.config/omarchy/dynamic-island.json`); dates follow the language. Strings live
in `components/Translations.js`, keyed by the Turkish source; `tests/check_i18n.py` lists anything
missing, so adding a language is one more table there plus its entry in `components/I18n.qml`.

## IPC

```sh
omarchy-shell dynamicisland toggle | open <home|music|agent|timer|shelf> | close
omarchy-shell dynamicisland reset | restartShell   # clear a stuck island | restart the shell
omarchy-shell dynamicisland approve | always | deny
omarchy-shell dynamicisland timer 300 | stopwatch | timerStop
omarchy-shell dynamicisland shelfAdd /path/to/file
omarchy-shell dynamicisland notify "Title" "Subtitle"
omarchy-shell dynamicisland status | sessions | events
```

## How the agent bridge works

`bin/dynamic-island-hook --agent <id>` is registered for the agent's lifecycle events (Antigravity's
events are mapped onto the same vocabulary; its path never blocks and never prints a decision,
because agy treats any answer, even `{}`, as one) and writes one JSON line per event to
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
CC BY 4.0). Agent marks (Claude, OpenAI, Gemini, OpenCode, Copilot, Cursor, X) via Simple Icons, Antigravity via
[LobeHub Icons](https://github.com/lobehub/lobe-icons) (MIT);
they are trademarks of their owners, and this project is not affiliated with any of them. See [icons/NOTICE.md](icons/NOTICE.md).

MIT License, see [LICENSE](LICENSE).
