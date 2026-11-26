/** @jsxImportSource @opentui/solid */
// Signs Claude Code in and connects the Claude Agent provider without leaving opencode.
// /connect-claude runs it on demand, and it offers to sign in when a Claude Agent model is selected while logged out.
// While a session runs on a Claude Agent model the sidebar shows the subscription's limits, /claude-usage shows them anywhere.
import { spawn } from "node:child_process"
import { readFile } from "node:fs/promises"
import { homedir } from "node:os"
import { join } from "node:path"
import { Plugin } from "@opencode/plugin/tui"
import type { Context } from "@opencode/plugin/tui/context"
import { For, Show, createEffect, createMemo, createSignal, on, onCleanup } from "solid-js"

const INTEGRATION = "claude-agent"
const METHOD = "claude-login"
const TITLE = "Connect Claude"
const URL_TIMEOUT_MS = 20_000
const RECHECK_MS = 5 * 60_000

// The endpoint behind Claude Code's own /usage screen, it is not a documented API.
const USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
const USAGE_BETA = "oauth-2025-04-20"
const USAGE_TITLE = "Claude usage"
const USAGE_REFRESH_MS = 60_000
const USAGE_MIN_AGE_MS = 30_000
// Wait for a turn's usage to be counted before refetching on a cost change.
const USAGE_SETTLE_MS = 5_000
const USAGE_TIMEOUT_MS = 10_000
const CLOCK_MS = 30_000
const TOKEN_MARGIN_MS = 60_000

type Limit = { label: string; percent?: number; detail?: string; resets_at?: number; severity?: string }
type UsageState = { limits?: Limit[]; error?: string; time: number }
type Token = { access_token: string; expires_at?: number }

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

// Claude Code keeps its login here on linux, and renews the access token in place.
async function tokenRead(): Promise<Token | undefined> {
  const directory = process.env.CLAUDE_CONFIG_DIR || join(homedir(), ".claude")
  const text = await readFile(join(directory, ".credentials.json"), "utf8").catch(() => undefined)
  if (!text) return
  const oauth = (JSON.parse(text) as { claudeAiOauth?: { accessToken?: string; expiresAt?: number } }).claudeAiOauth
  if (!oauth?.accessToken) return
  return { access_token: oauth.accessToken, expires_at: oauth.expiresAt }
}

const tokenExpired = (token: Token) => token.expires_at !== undefined && token.expires_at - Date.now() < TOKEN_MARGIN_MS

function timeParse(value: unknown) {
  const time = typeof value === "string" ? Date.parse(value) : NaN
  return Number.isNaN(time) ? undefined : time
}

// Every entry of `limits` is shown, so a limit for a new model appears without a change here.
function limitsParse(data: any): Limit[] {
  const limits: Limit[] = []
  if (Array.isArray(data?.limits) && data.limits.length > 0) {
    for (const item of data.limits) {
      if (typeof item?.percent !== "number") continue
      const scope = item.scope?.model?.display_name ?? item.scope?.surface?.display_name
      const base =
        item.kind === "session"
          ? "Session"
          : item.group === "weekly"
            ? "Weekly"
            : String(item.kind ?? item.group ?? "Limit").replaceAll("_", " ")
      limits.push({
        label: scope ? `${base} ${scope}` : base,
        percent: item.percent,
        resets_at: timeParse(item.resets_at),
        severity: typeof item.severity === "string" ? item.severity : undefined,
      })
    }
  } else {
    // What the endpoint returned before it had `limits`.
    const windows: [string, string][] = [
      ["five_hour", "Session"],
      ["seven_day", "Weekly"],
      ["seven_day_opus", "Weekly Opus"],
      ["seven_day_sonnet", "Weekly Sonnet"],
    ]
    for (const [key, label] of windows) {
      const window = data?.[key]
      if (typeof window?.utilization !== "number") continue
      limits.push({ label, percent: window.utilization, resets_at: timeParse(window.resets_at) })
    }
  }

  // Pay as you go credits on top of the plan, capped per month.
  const extra = data?.extra_usage
  if (extra?.is_enabled && typeof extra.used_credits === "number") {
    const scale = 10 ** (typeof extra.decimal_places === "number" ? extra.decimal_places : 2)
    const money = new Intl.NumberFormat("en-US", { style: "currency", currency: extra.currency || "USD" })
    const cap = typeof extra.monthly_limit === "number" ? money.format(extra.monthly_limit / scale) : "∞"
    limits.push({
      label: "Extra",
      percent: typeof extra.utilization === "number" ? extra.utilization : undefined,
      detail: `${money.format(extra.used_credits / scale)} / ${cap}/mo`,
    })
  }
  return limits
}

async function usageFetch(): Promise<Limit[]> {
  let token = await tokenRead()
  if (!token) throw new Error("not signed in, run /connect-claude")
  for (let attempt = 0; ; attempt++) {
    // Any claude invocation renews an expired token, so ask it for something cheap and read the file again.
    if (tokenExpired(token)) {
      await statusGet().catch(() => {})
      token = (await tokenRead()) ?? token
      if (tokenExpired(token)) throw new Error("login token expired, it renews on the next Claude request")
    }
    const response = await fetch(USAGE_URL, {
      headers: { Authorization: `Bearer ${token.access_token}`, "anthropic-beta": USAGE_BETA },
      signal: AbortSignal.timeout(USAGE_TIMEOUT_MS),
    })
    if (response.status === 401 && attempt === 0) {
      token = { ...token, expires_at: 0 }
      continue
    }
    if (!response.ok) throw new Error(`HTTP ${response.status}`)
    return limitsParse(await response.json())
  }
}

function durationFormat(ms: number) {
  const minutes = Math.max(0, Math.round(ms / 60_000))
  if (minutes < 1) return "now"
  if (minutes < 60) return `${minutes}m`
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `${hours}h ${minutes % 60}m`
  return `${Math.floor(hours / 24)}d ${hours % 24}h`
}

// The percentage and what follows it (the countdown, or the amounts of the extra usage) are separate columns.
function limitParts(limit: Limit, now: number) {
  return {
    percent: limit.percent !== undefined ? `${Math.round(limit.percent)}%` : "",
    rest: limit.detail ?? (limit.resets_at !== undefined ? durationFormat(limit.resets_at - now) : ""),
  }
}

function limitValue(limit: Limit, now: number) {
  const parts = limitParts(limit, now)
  return [parts.percent, parts.rest].filter(Boolean).join(" · ")
}

function limitLevel(limit: Limit): "normal" | "warning" | "error" {
  const percent = limit.percent ?? 0
  if (percent >= 100) return "error"
  if (percent >= 80 || (limit.severity !== undefined && limit.severity !== "normal")) return "warning"
  return "normal"
}

const isClaude = (context: Context, session_id: string) =>
  (context.data.session.get(session_id)?.model?.providerID ?? context.ui.model.current()?.providerID) === INTEGRATION

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

    // One login, so one state shared by every session's sidebar.
    const [usage, setUsage] = createSignal<UsageState>()
    let usage_inflight: Promise<void> | undefined
    let usage_timer: ReturnType<typeof setTimeout> | undefined

    function usageRefresh(force = false): Promise<void> {
      if (usage_inflight) return usage_inflight
      const previous = usage()
      if (!force && previous && Date.now() - previous.time < USAGE_MIN_AGE_MS) return Promise.resolve()
      usage_inflight = usageFetch()
        .then((limits) => void setUsage({ limits, time: Date.now() }))
        .catch((error) => {
          const message = error instanceof Error ? error.message : String(error)
          // Keep the last good numbers around, only flag that they are stale.
          setUsage((state) => ({ ...state, error: message, time: Date.now() }))
        })
        .finally(() => (usage_inflight = undefined))
      return usage_inflight
    }

    function Limits(props: { sessionID: string }) {
      const theme = () => context.theme
      const active = createMemo(() => isClaude(context, props.sessionID))
      const session_cost = createMemo(() => context.data.session.cost(context.data.session.root(props.sessionID)))

      createEffect(
        on(active, (value) => {
          if (value) void usageRefresh()
        }),
      )
      createEffect(
        on(
          session_cost,
          () => {
            if (!active()) return
            clearTimeout(usage_timer)
            usage_timer = setTimeout(() => void usageRefresh(true), USAGE_SETTLE_MS)
          },
          { defer: true },
        ),
      )
      const refresh = setInterval(() => {
        if (active()) void usageRefresh()
      }, USAGE_REFRESH_MS)
      // The countdowns move without a refetch.
      const [now, setNow] = createSignal(Date.now())
      const clock = setInterval(() => setNow(Date.now()), CLOCK_MS)
      onCleanup(() => {
        clearInterval(refresh)
        clearInterval(clock)
      })

      const color = (limit: Limit) => {
        const level = limitLevel(limit)
        if (level === "error") return theme().text.feedback.error.base
        if (level === "warning") return theme().text.feedback.warning.base
        return theme().text.muted
      }

      // The values are right aligned as a whole, so pad both columns to a common width to line them up across rows.
      const rows = createMemo(() => {
        const parts = (usage()?.limits ?? []).map((limit) => ({ limit, ...limitParts(limit, now()) }))
        const percent_width = Math.max(0, ...parts.map((part) => part.percent.length))
        const rest_width = Math.max(0, ...parts.map((part) => part.rest.length))
        return parts.map((part) => ({
          limit: part.limit,
          value: `${part.percent.padStart(percent_width)}${part.rest ? " · " : "   "}${part.rest.padEnd(rest_width)}`,
        }))
      })

      // Same layout as the built-in sidebar "Context" section it sits above.
      return (
        <Show when={active() && usage()}>
          <box>
            <text fg={theme().text.base}>
              <b>Claude</b>
            </text>
            <For each={rows()}>
              {(row) => (
                <box flexDirection="row" justifyContent="space-between">
                  <text fg={theme().text.muted}>{row.limit.label}</text>
                  <text fg={color(row.limit)}>{row.value}</text>
                </box>
              )}
            </For>
            <Show when={usage()?.error}>
              {(error) => (
                <text fg={theme().text.faint} wrapMode="word">
                  {usage()?.limits ? `stale: ${error()}` : error()}
                </text>
              )}
            </Show>
          </box>
        </Show>
      )
    }

    const stopSidebar = context.ui.slot({
      prepend: "sidebar.content",
      render: (input) => <Limits sessionID={input.sessionID} />,
    })

    async function usageShow() {
      await usageRefresh(true)
      const state = usage()
      if (!state?.limits) return context.ui.toast.show({ title: USAGE_TITLE, message: state?.error ?? "no data", variant: "error" })
      const now = Date.now()
      const clock = new Intl.DateTimeFormat(undefined, { weekday: "short", hour: "2-digit", minute: "2-digit" })
      const lines = state.limits.map((limit) => {
        const resets = limit.resets_at !== undefined ? `, resets ${clock.format(limit.resets_at)}` : ""
        return `${limit.label}: ${limitValue(limit, now)}${resets}`
      })
      if (state.error) lines.push(`stale: ${state.error}`)
      const levels = state.limits.map(limitLevel)
      context.ui.toast.show({
        title: USAGE_TITLE,
        message: lines.join("\n") || "no limits reported",
        variant: levels.includes("error") ? "error" : levels.includes("warning") ? "warning" : "info",
      })
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
        {
          id: "nyx.connect-claude.usage",
          title: "Show Claude usage limits",
          group: "Provider",
          palette: true,
          slash: { name: "claude-usage" },
          run: () => void usageShow(),
        },
      ],
    }))

    // Offer to sign in when a Claude Agent model is selected (also at startup) while claude is logged out.
    let checked_at = 0
    const stopApp = context.ui.slot({
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

    return () => {
      stopSidebar()
      stopApp()
      clearTimeout(usage_timer)
    }
  },
})
