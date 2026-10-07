# Changelog

## 1.6.1

- The refresh button on Home now restarts the Omarchy shell on click; right-click only clears
  the island.

## 1.6.0

- No more squashed island after a shell restart: it stays hidden until the bar has been
  measured (re-measured every 300 ms until found), then drops in from above as a circle and
  springs open into the island. A bar that reloads keeps the last fit instead of the fallback.

## 1.5.1

- The ambient light glows only around the player: the island when music is in the middle (or
  the music page is open), otherwise the music bubble. Softer backlight that swells and settles
  with the sound instead of flashing.

## 1.5.0

- Ambient light: an artwork-colored glow around the island while music plays, pulsing with
  the sound through cava (optional; `services/AudioLevel.qml`). cava runs only while music
  plays and the island is on screen. Config: `ambient`, `ambientAudio`.
- `omarchy-shell dynamicisland status` reports the ambient state and audio level.

## 1.4.0

- Message box on the agent page (Claude Code, Codex): send a message to the watched session
  from the island (`bin/dynamic-island-send`). tmux panes get it in the background; otherwise
  the session's own window is focused and typed into, and only when it is found exactly.
- `dynamic-island-focus --exact`: no fallback window.

## 1.3.0

- Live feed on the agent page for Claude Code and Codex: the last prompts, replies, tool calls
  and their output, read from the session transcript (`bin/dynamic-island-transcript`) only
  while the page is open. Click a session row to watch it when several run.
- Shelf bubble: while the shelf holds anything it shows as a side bubble with the item count
  and a fill ring. Clicking it shelves the clipboard: copied files as they are, a copied image
  or text saved as a file (removed again when it leaves the shelf). Alone, it never takes the
  center unless you double-click it there.
- "Add clipboard" on the shelf page, and a click on the empty shelf does the same.

## 1.2.0

- Double-click a bubble to swap it with the center; the center activity takes that bubble's
  place, and the arrangement is kept while those activities stay live.
- The music activity shows only while something plays and leaves as soon as it is paused or
  the player closes.
- Refresh button on Home: click clears a stuck island, right-click restarts the Omarchy shell
  (`omarchy-shell dynamicisland reset | restartShell`).
- Agent state labels now update on every event (they could stick, e.g. "Idle" while the agent
  worked).
- Agent state machine rewritten and documented trigger by trigger in
  services/AgentBridge.qml: tool failures, API errors, manual compaction, questions
  (AskUserQuestion), permissions answered in the terminal, and interrupts (read from the
  transcript, since no hook reports them) are all handled.
- Shortcuts: Files opens through Omarchy's launcher, an "Opening…" banner confirms the click,
  and repeated clicks are ignored for a moment.

## 1.1.0

- Follows Omarchy's default coding agent: name, mark, colors and spinner on the agent page,
  tab, shortcut and banners. New `agent` setting to override it.
- Codex (hooks, allow/deny), OpenCode (plugin, allow/always/deny) and Gemini CLI (hooks, live
  sessions; permissions shown) join Claude Code. `bin/dynamic-island-agent-setup` connects any of
  them; `dynamic-island-claude-setup` still works.
- Sharp rendering at fractional scales: no offscreen pass for the island's content, hinted text,
  icons painted as vectors in their final color.
- Fewer false alerts: headless runs (`claude -p`) are ignored, a compaction no longer reads as
  "ready", only "waiting for you" notifications raise a banner, track changes and charging are
  debounced, and hook events are acknowledged so none get lost.
- `omarchy-shell dynamicisland sessions` / `events` for troubleshooting.

## 1.0.0

- Dynamic Island service for the Omarchy shell: compact, peek and expanded states with spring
  physics, blur-morph content transitions, pointer lean, press sink and shake.
- Live activities: Claude Code, screen recording, timer/stopwatch, music; extra activities split
  into independent bubbles on the right and left.
- Pages: Home (default-app shortcuts, usage and battery rings, quick timers), Music, Claude Code,
  Timer, Shelf; Claude permission alerts with Allow / Always / Deny.
- Claude Code bridge over a private unix socket, with installer/remover for the hooks.
- Island size and position measured from the running bar.
- English and Turkish interface.
