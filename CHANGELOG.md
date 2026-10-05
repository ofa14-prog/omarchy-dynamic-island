# Changelog

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
