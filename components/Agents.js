// Coding agents Omarchy can set as its default (`omarchy default agent`).
//
//   logo         icons/brand/<logo>.svg (Simple Icons); "" falls back to a
//                generic glyph
//   frames       the busy spinner. Claude Code's is its exact terminal
//                spinner; the others follow their CLI's look (braille dots)
//   integration  "full"   live sessions + permission allow/deny on the island
//                "status" live sessions; permissions can only be shown
//                "none"   launch, branding and usage only (no event API)
//   always       permission answer "always" is supported
.pragma library

var braille = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

var profiles = {
  "claude":       { name: "Claude",   product: "Claude Code", logo: "claude",       color: "#D97757", glow: "#F0B49B", frames: ["·", "✢", "*", "✶", "✻", "✽"], pingpong: true, interval: 120, integration: "full",   always: true },
  "codex":        { name: "Codex",    product: "Codex",       logo: "openai",       color: "#E6E6E6", glow: "#FFFFFF", frames: braille, pingpong: false, interval: 80,  integration: "full",   always: false },
  "opencode":     { name: "OpenCode", product: "OpenCode",    logo: "opencode",     color: "#E6E6E6", glow: "#FFFFFF", frames: braille, pingpong: false, interval: 80,  integration: "full",   always: true },
  "gemini":       { name: "Gemini",   product: "Gemini CLI",  logo: "googlegemini", color: "#8E75B2", glow: "#C9B8E6", frames: braille, pingpong: false, interval: 80,  integration: "status", always: false },
  "copilot":      { name: "Copilot",  product: "GitHub Copilot", logo: "githubcopilot", color: "#E6E6E6", glow: "#FFFFFF", frames: braille, pingpong: false, interval: 80, integration: "none", always: false },
  "cursor-agent": { name: "Cursor",   product: "Cursor CLI",  logo: "cursor",       color: "#E6E6E6", glow: "#FFFFFF", frames: braille, pingpong: false, interval: 80,  integration: "none",   always: false },
  "grok":         { name: "Grok",     product: "Grok",        logo: "x",            color: "#E6E6E6", glow: "#FFFFFF", frames: braille, pingpong: false, interval: 80,  integration: "none",   always: false },
  "pi":           { name: "Pi",       product: "Pi",          logo: "", color: "#E6E6E6", glow: "#FFFFFF", frames: braille, pingpong: false, interval: 80, integration: "none", always: false },
  "omp":          { name: "Oh My Pi", product: "Oh My Pi",    logo: "", color: "#E6E6E6", glow: "#FFFFFF", frames: braille, pingpong: false, interval: 80, integration: "none", always: false },
  "crush":        { name: "Crush",    product: "Crush",       logo: "", color: "#E6E6E6", glow: "#FFFFFF", frames: braille, pingpong: false, interval: 80, integration: "none", always: false },
  "hermes":       { name: "Hermes",   product: "Hermes",      logo: "", color: "#E6E6E6", glow: "#FFFFFF", frames: braille, pingpong: false, interval: 80, integration: "none", always: false },
  "openclaw":     { name: "OpenClaw", product: "OpenClaw",    logo: "", color: "#E6E6E6", glow: "#FFFFFF", frames: braille, pingpong: false, interval: 80, integration: "none", always: false },
  "muse":         { name: "Muse",     product: "Muse Code",   logo: "", color: "#E6E6E6", glow: "#FFFFFF", frames: braille, pingpong: false, interval: 80, integration: "none", always: false }
}

function get(id) {
  return profiles[id] || { name: id || "Agent", product: id || "Agent", logo: "", color: "#E6E6E6", glow: "#FFFFFF",
    frames: braille, pingpong: false, interval: 80, integration: "none", always: false }
}
