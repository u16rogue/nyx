// THIS WAS WRITTEN BY A CLANKER
//
// Desktop notifications over the session bus, for when opencode's own can't arrive.
// opencode's notification is a terminal escape and gets lost on the way out of zellij inside tmux (the sbx-shell
// setup). notify-send doesn't depend on the terminal: sbx-shell gives the sandbox a session bus that only allows
// showing a notification, and outside a sandbox the session bus is simply there.
// Without a session bus this plugin does nothing.
import { Plugin } from "@opencode/plugin/tui"
import { spawn } from "node:child_process"

function notificationSend(notify_send: string, title: string, message: string) {
  const clean = (text: string) => text.replace(/[\x00-\x1f\x7f]/g, " ").slice(0, 200)
  try {
    // Arguments, not a shell. "--" keeps a title starting with "-" from being read as an option.
    const child = spawn(notify_send, ["--app-name=OpenCode", "--", clean(title), clean(message)], {
      stdio: "ignore",
      detached: true,
    })
    child.on("error", () => {})
    child.unref()
  } catch {}
}

export default Plugin.define({
  id: "nyx.notify",
  setup(context) {
    const notify_send = context.options.notify_send
    if (typeof notify_send !== "string" || !process.env.DBUS_SESSION_BUS_ADDRESS) return

    // Unknown until the terminal reports focus. Only a known focused terminal suppresses a notification.
    let focused = false
    const onFocus = () => (focused = true)
    const onBlur = () => (focused = false)
    context.renderer.on("focus", onFocus)
    context.renderer.on("blur", onBlur)

    const seen = new Set<string>()
    const notify = (key: string, sessionID: string, message: string) => {
      if (seen.has(key)) return
      seen.add(key)
      if (focused) return
      notificationSend(notify_send, context.data.session.get(sessionID)?.title ?? "OpenCode", message)
    }
    const isRoot = (sessionID: string) => !context.data.session.get(sessionID)?.parentID

    const stops = [
      context.data.on("permission.asked", (event: any) =>
        notify(`permission:${event.data.id}`, event.data.sessionID, "Permission needs input"),
      ),
      context.data.on("form.created", (event: any) =>
        notify(`form:${event.data.form.id}`, event.data.form.sessionID, "Input needs response"),
      ),
      context.data.on("session.execution.started", (event: any) => {
        seen.delete(`done:${event.data.sessionID}`)
      }),
      context.data.on("session.execution.succeeded", (event: any) => {
        if (isRoot(event.data.sessionID)) notify(`done:${event.data.sessionID}`, event.data.sessionID, "Session done")
      }),
      context.data.on("session.execution.failed", (event: any) => {
        if (isRoot(event.data.sessionID))
          notify(`done:${event.data.sessionID}`, event.data.sessionID, `Session failed: ${event.data.error?.message ?? ""}`)
      }),
    ]

    return () => {
      stops.forEach((stop) => stop())
      context.renderer.off("focus", onFocus)
      context.renderer.off("blur", onBlur)
    }
  },
})
