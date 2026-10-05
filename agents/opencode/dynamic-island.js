// OpenCode -> Dynamic Island bridge.
//
// Installed by `dynamic-island-agent-setup opencode` as a symlink in
// ~/.config/opencode/plugins/. Reports session activity to the island over
// its unix socket and forwards permission requests: the island's answer is
// sent back through OpenCode's API while OpenCode's own prompt stays live, so
// answering in either place works. Without a running island it does nothing.

import net from "node:net"
import path from "node:path"

const runtime = process.env.XDG_RUNTIME_DIR || `/run/user/${process.getuid?.() ?? 1000}`
const SOCK = path.join(runtime, "dynamic-island", "agents.sock")

function send(msg, { waitForReply = false } = {}) {
  return new Promise((resolve) => {
    let buf = ""
    let settled = false
    const finish = (value) => {
      if (settled) return
      settled = true
      socket.destroy()
      resolve(value)
    }
    const socket = net.createConnection(SOCK)
    socket.setEncoding("utf8")
    socket.on("error", () => finish(null))
    socket.on("close", () => finish(null))
    socket.on("connect", () => socket.write(JSON.stringify(msg) + "\n"))
    socket.on("data", (chunk) => {
      buf += chunk
      const nl = buf.indexOf("\n")
      if (nl === -1) return
      const line = buf.slice(0, nl)
      if (!waitForReply) return finish(line)
      try { finish(JSON.parse(line)) } catch { finish(null) }
    })
    if (!waitForReply) setTimeout(() => finish(null), 1000)
  })
}

function describe(tool, args = {}) {
  if (tool === "bash") return [args.description || "Command", String(args.command || "")]
  if (tool === "edit") return [args.filePath || "", `- ${String(args.oldString || "").split("\n").slice(0, 6).join("\n- ")}\n+ ${String(args.newString || "").split("\n").slice(0, 6).join("\n+ ")}`]
  if (tool === "write") return [args.filePath || "", String(args.content || "").split("\n").slice(0, 8).join("\n")]
  if (tool === "read") return [args.filePath || "", ""]
  if (tool === "glob" || tool === "grep") return [args.pattern || "", args.path || ""]
  if (tool === "webfetch") return [args.url || "", ""]
  const first = Object.values(args).find((v) => typeof v === "string") || ""
  return [String(first).slice(0, 160), JSON.stringify(args).slice(0, 400)]
}

export const DynamicIsland = async ({ client, directory }) => {
  const cwd = directory || process.cwd()
  const base = () => ({
    agent: "opencode",
    cwd,
    project: path.basename(cwd) || cwd,
    pids: [process.pid, process.ppid],
    agentPid: process.pid,
    ts: Math.round(performance.timeOrigin * 1000 + performance.now() * 1000),
  })
  const busy = new Set()

  async function respond(sessionID, permissionID, behavior) {
    const response = behavior === "always" ? "always" : behavior === "deny" ? "reject" : "once"
    const opts = { path: { id: sessionID, permissionID }, body: { response } }
    if (typeof client.postSessionIdPermissionsPermissionId === "function") return client.postSessionIdPermissionsPermissionId(opts)
    if (client.permission?.respond) return client.permission.respond({ sessionID, permissionID, response })
    if (client.permission?.reply) return client.permission.reply({ requestID: permissionID, reply: response })
  }

  async function onPermission(p) {
    const sessionID = p.sessionID
    const permissionID = p.id
    if (!sessionID || !permissionID) return
    const [title, detail] = describe(p.type || p.permission || "", p.metadata || {})
    const reply = await send({
      ...base(), event: "PermissionRequest", session: sessionID,
      request: `opencode-${permissionID}`, tool: p.type || p.permission || "permission",
      title: p.title || title, detail, canAlways: true,
    }, { waitForReply: true })
    if (!reply || !reply.behavior) return
    try { await respond(sessionID, permissionID, reply.behavior) } catch {}
  }

  return {
    event: async ({ event }) => {
      const p = event.properties || {}
      switch (event.type) {
        case "session.created":
          if (!p.info?.parentID) send({ ...base(), event: "SessionStart", session: p.info?.id || p.sessionID })
          break
        case "session.deleted":
          send({ ...base(), event: "SessionEnd", session: p.info?.id || p.sessionID })
          break
        case "session.status":
          if (p.status?.type === "busy" && !busy.has(p.sessionID)) {
            busy.add(p.sessionID)
            send({ ...base(), event: "UserPromptSubmit", session: p.sessionID })
          } else if (p.status?.type === "idle" && busy.has(p.sessionID)) {
            busy.delete(p.sessionID)
            send({ ...base(), event: "Stop", session: p.sessionID })
          }
          break
        case "session.idle":
          if (busy.has(p.sessionID)) {
            busy.delete(p.sessionID)
            send({ ...base(), event: "Stop", session: p.sessionID })
          }
          break
        case "permission.updated":
        case "permission.asked":
          onPermission(p)
          break
        case "permission.replied":
          // Answered in OpenCode itself: close the island's request.
          send({ ...base(), event: "PermissionResolved", session: p.sessionID,
            request: `opencode-${p.permissionID || p.requestID || p.id}` })
          break
      }
    },
    "tool.execute.before": async (input, output) => {
      const [title, detail] = describe(input.tool, output?.args || {})
      send({ ...base(), event: "PreToolUse", session: input.sessionID, tool: input.tool, title, detail })
    },
    "tool.execute.after": async (input) => {
      send({ ...base(), event: "PostToolUse", session: input.sessionID, tool: input.tool })
    },
  }
}
