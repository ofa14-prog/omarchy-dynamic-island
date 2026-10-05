# Changelog

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
