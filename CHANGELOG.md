# Changelog

## 1.9.0

- Languages: English (now the default), Spanish, Russian and Turkish, picked from a flag button
  on the Home page (saved to the config). Translations live in `components/Translations.js`;
  counts use the right plural form per language. Tabs adapt to long labels (smaller font,
  then no icon, then an ellipsis).
- Security: no rich text anywhere untrusted text is shown. The permission page's command/diff
  preview is plain text line by line; ShimmerText escapes its input. `tests/check_qml.py`
  fails on any `Text` without a safe `textFormat`.
- The shelf only deletes clipboard files it saved itself (no `..` paths).
- Restart uses `omarchy-restart-shell` only.
- Bounded reads: clipboard file lists (64 KiB, 24 entries), pasted images (50 MiB) and text
  (10 MiB); the agent feed's JSON is capped at 1 MiB.
- `dynamic-island-bar-setup` writes backups and restores through a temp file and rename, so a
  symlink at the destination is replaced, never written through.
- CI: manifest, QML text safety, translation coverage, script syntax.
- README: full dependency list (all part of Omarchy; `cava` and the timer sound optional) and
  a note that enabling the plugin changes nothing on the system.

## 1.8.2

- Music backdrop: opening onto the music page brings the colors in with the card (no black
  first, no pop); tab switches cross-fade quickly (280 ms, ease-out).

## 1.8.1

- Music backdrop: no more square-cornered color block while the island morphs (the blur drew
  past the card, and the colors kept fading while the shape shrank). The colors now appear
  once the card has finished opening, vanish the instant it closes, and cross-fade softly
  (900 ms) between tabs.

## 1.8.0

- Music page backdrop: open on the music tab, the card fills with the artwork's colors as
  large blurred blobs drifting slowly (like Apple Music); the outer glow is only for the
  closed island now. Off with `"ambient": false`.

## 1.7.1

- Players: the one that starts playing takes over, even over an earlier pick, so switching
  apps switches the island (art, colors, controls). Several playing: the newest wins.
- No artwork: neutral colors instead of the previous track's (the color extractor kept its
  last result).
- Agent feed: compact keeps short "… +N" summaries; expanded shows every line of every
  output and full commands, wrapped. Expanding starts at once and eases out (260 ms).

## 1.7.0

- Player switcher on the music page: with several media players, a chip next to the transport
  buttons names the one shown and opens a list to pick the one to follow (kept until it
  closes; "Automatic" follows whatever plays). Right-click or scroll it for the next one.
- Agent live feed: scrollable (wheel or drag), follows new output only while at the bottom,
  a jump-to-newest button, and an expand button for a taller feed with more output per
  command. Terminal color codes are stripped from output.

## 1.6.2

- Fixed the squashed island after a manual shell restart: a starting bar grows in steps
  (26 → 30 → its real height), and the first step was taken as final. The island now waits
  until the bar's size has been the same for three probes in a row before dropping in.

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
