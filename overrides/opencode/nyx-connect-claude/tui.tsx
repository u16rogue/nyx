/** @jsxImportSource @opentui/solid */
// THIS WAS WRITTEN BY A CLANKER
// Signs Claude Code in and connects the Claude Agent provider without leaving opencode.
// /connect-claude runs it on demand, and it offers to sign in when a Claude Agent model is selected while logged out.
import { spawn } from "node:child_process"
import { Plugin } from "@opencode/plugin/tui"
import { createEffect } from "solid-js"

const INTEGRATION = "claude-agent"
const METHOD = "claude-login"
const TITLE = "Connect Claude"
const URL_TIMEOUT_MS = 20_000
const RECHECK_MS = 5 * 60_000

type Status = { loggedIn: boolean; email?: string; subscriptionType?: string }

const claudeBin = () => process.env.OPENCODE_CLAUDE_PATH || "claude"

function claudeRun(args: string[]): Promise<{ code: number; stdout: string }> {
  return new Promise((resolve, reject) => {
    const child = spawn(claudeBin(), args, { stdio: ["ignore", "pipe", "ignore"] })
    let stdout = ""
    child.stdout.on("data", (chunk) => (stdout += chunk))
    child.on("error", reject)
    child.on("close", (code) => resolve({ code: code ?? 1, stdout }))
  })
}

// `claude auth status` exits non-zero when logged out but still prints its JSON.
async function statusGet(): Promise<Status> {
  const result = await claudeRun(["auth", "status", "--json"])
  return JSON.parse(result.stdout) as Status
}

export default Plugin.define({
  id: "nyx.connect-claude",
  setup(context) {
    const toast = (message: string, variant: "info" | "success" | "warning" | "error" = "info") =>
      context.ui.toast.show({ title: TITLE, message, variant })

    // Runs `claude auth login`, shows its link and feeds it the code typed into an opencode prompt.
    async function loginRun(): Promise<boolean> {
      const child = spawn(claudeBin(), ["auth", "login"], { stdio: ["pipe", "pipe", "pipe"] })
      let output = ""
      let prompting = false
      child.stdout.on("data", (chunk) => (output += chunk))
      child.stderr.on("data", (chunk) => (output += chunk))
      child.stdin.on("error", () => {})
      const exited = new Promise<number>((resolve) => {
        child.on("error", (error) => {
          output += String(error)
          resolve(1)
        })
        child.on("close", (code) => resolve(code ?? 1))
      })
      // The browser can finish the login on its own, the prompt is pointless once claude is gone.
      void exited.then(() => {
        if (prompting) context.ui.dialog.clear()
      })

      const url = await new Promise<string | undefined>((resolve) => {
        const urlFind = () => output.match(/https:\/\/[^\s\x07\x1b]+/)?.[0]
        const timer = setTimeout(() => finish(), URL_TIMEOUT_MS)
        const finish = () => {
          clearTimeout(timer)
          child.stdout.off("data", check)
          resolve(urlFind())
        }
        const check = () => {
          if (urlFind()) finish()
        }
        child.stdout.on("data", check)
        void exited.then(finish)
      })

      if (child.exitCode === null) {
        if (!url) {
          child.kill()
          await exited
          toast(`claude printed no sign-in link: ${output.trim().slice(-200)}`, "error")
          return false
        }
        prompting = true
        const code = await context.ui.dialog.prompt({
          title: TITLE,
          description: `Sign in in the browser, then paste the code it gives you here.\n\n${url}`,
          placeholder: "code",
        })
        prompting = false
        if (child.exitCode === null) {
          if (!code?.trim()) {
            child.kill()
            await exited
            toast("Sign-in cancelled", "warning")
            return false
          }
          child.stdin.write(`${code.replace(/\s/g, "")}\n`)
        }
      }
      child.stdin.end()

      if ((await exited) === 0) return true
      const reason = output
        .split(/\r?\n/)
        .map((line) => line.replace(/^Paste code here if prompted >/, "").trim())
        .filter(Boolean)
        .at(-1)
      toast(reason ?? "claude auth login failed", "error")
      return false
    }

    async function integrationConnect() {
      const location = context.location ?? context.data.location.default()
      const integration = await context.client.integration.get({ integrationID: INTEGRATION, location })
      if (integration.data.connections.length === 0)
        await context.client.integration.connect.external({ integrationID: INTEGRATION, methodID: METHOD, location })
      context.data.location.integration.invalidate(location)
      context.data.location.provider.invalidate(location)
      context.data.location.model.invalidate(location)
    }

    let running = false
    async function connect(ask: boolean) {
      if (running) return
      running = true
      try {
        let status = await statusGet()
        if (!status.loggedIn) {
          if (ask) {
            const confirmed = await context.ui.dialog.confirm({
              title: TITLE,
              message: "Claude Code is not signed in. Sign in now?",
              label: { confirm: "Sign in", cancel: "Not now" },
            })
            if (!confirmed) return
          }
          if (!(await loginRun())) return
          status = await statusGet()
          if (!status.loggedIn) return toast("claude still reports it is not signed in", "error")
        }
        await integrationConnect()
        toast(`Claude Agent connected${status.email ? ` as ${status.email}` : ""}, pick a model in /models`, "success")
      } catch (error) {
        toast(error instanceof Error ? error.message : String(error), "error")
      } finally {
        running = false
      }
    }

    context.keymap.layer(() => ({
      mode: "global",
      commands: [
        {
          id: "nyx.connect-claude",
          title: "Connect Claude (sign in to Claude Code)",
          group: "Provider",
          palette: true,
          slash: { name: "connect-claude" },
          run: () => void connect(false),
        },
      ],
    }))

    // Offer to sign in when a Claude Agent model is selected (also at startup) while claude is logged out.
    let checked_at = 0
    return context.ui.slot({
      append: "app",
      render: () => {
        createEffect(() => {
          if (context.ui.model.current()?.providerID !== INTEGRATION) return
          if (Date.now() - checked_at < RECHECK_MS) return
          checked_at = Date.now()
          void statusGet()
            .then((status) => {
              if (!status.loggedIn) void connect(true)
            })
            .catch(() => {})
        })
        return null
      },
    })
  },
})
