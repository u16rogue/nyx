/** @jsxImportSource @opentui/solid */
// THIS WAS WRITTEN BY A CLANKER
import { Plugin } from "@opencode/plugin/tui"
import type { Context } from "@opencode/plugin/tui/context"
import { Show, createEffect, createMemo, createSignal, on, onCleanup } from "solid-js"

const OPENROUTER_API = "https://openrouter.ai/api/v1"
const OPENROUTER_PACKAGE = "@opencode/ai/providers/openrouter"
const REFRESH_MS = 60_000
// OpenRouter settles a request's cost a moment after it finishes, so wait before refetching on a cost change.
const SETTLE_MS = 5_000
const MIN_AGE_MS = 10_000

type Usage = { total: number; limit?: number; window?: string }
type UsageState = { usage?: Usage; error?: string; time: number }

const money = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" })

const WINDOW_SUFFIX: Record<string, string> = { daily: "/day", weekly: "/wk", monthly: "/mo" }

async function openrouterGet(api_key: string, path: string): Promise<any> {
  const response = await fetch(`${OPENROUTER_API}${path}`, { headers: { Authorization: `Bearer ${api_key}` } })
  if (!response.ok) throw new Error(`${path}: HTTP ${response.status}`)
  return ((await response.json()) as { data: unknown }).data
}

async function usageFetch(api_key: string): Promise<Usage> {
  const key = await openrouterGet(api_key, "/key")
  // The budget that blocks first: covers the key's own limit, guardrails and workspace budgets.
  const budget = key.effective_budget
  if (budget) return { total: budget.spend_usd, limit: budget.limit_usd, window: budget.reset_interval ?? undefined }
  if (key.limit != null) {
    const window: string | undefined = key.limit_reset ?? undefined
    const total =
      window === "daily"
        ? key.usage_daily
        : window === "weekly"
          ? key.usage_weekly
          : window === "monthly"
            ? key.usage_monthly
            : key.usage
    return { total, limit: key.limit, window }
  }
  // No per-key cap, so the account balance is the limit.
  const credits = await openrouterGet(api_key, "/credits").catch(() => undefined)
  if (credits) return { total: credits.total_usage, limit: credits.total_credits }
  return { total: key.usage }
}

function openrouterTarget(context: Context, session_id: string) {
  const session = context.data.session.get(session_id)
  const provider_id = session?.model?.providerID ?? context.ui.model.current()?.providerID
  if (!provider_id) return
  const provider = context.data.location.provider.list(session?.location)?.find((item) => item.id === provider_id)
  const is_openrouter = provider
    ? provider.package.startsWith(OPENROUTER_PACKAGE) || (provider.canonical ?? provider.id) === "openrouter"
    : provider_id === "openrouter"
  if (!is_openrouter) return
  return provider?.integrationID ?? provider_id
}

async function apiKeyFind(context: Context, integration_id: string) {
  const credentials = await context.client.credential.list().catch(() => [])
  const entry = credentials.find((item) => item.integrationID === integration_id && item.active)
  if (entry?.value.type === "key") return entry.value.key
  return process.env.OPENROUTER_API_KEY
}

export default Plugin.define({
  id: "openrouter-tracker",
  setup(context) {
    const [states, setStates] = createSignal<Record<string, UsageState>>({})
    const inflight = new Set<string>()
    const timers = new Map<string, ReturnType<typeof setTimeout>>()

    async function usageRefresh(integration_id: string, force = false) {
      const previous = states()[integration_id]
      if (inflight.has(integration_id)) return
      if (!force && previous && Date.now() - previous.time < MIN_AGE_MS) return
      inflight.add(integration_id)
      try {
        const api_key = await apiKeyFind(context, integration_id)
        if (!api_key) throw new Error("no api key")
        const usage = await usageFetch(api_key)
        setStates((all) => ({ ...all, [integration_id]: { usage, time: Date.now() } }))
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error)
        // Keep the last good numbers around, only flag that they are stale.
        setStates((all) => ({ ...all, [integration_id]: { ...all[integration_id], error: message, time: Date.now() } }))
      } finally {
        inflight.delete(integration_id)
      }
    }

    function usageSchedule(integration_id: string, delay: number) {
      clearTimeout(timers.get(integration_id))
      timers.set(
        integration_id,
        setTimeout(() => {
          timers.delete(integration_id)
          void usageRefresh(integration_id, true)
        }, delay),
      )
    }

    function Limits(props: { sessionID: string }) {
      const theme = () => context.theme
      const target = createMemo(() => openrouterTarget(context, props.sessionID))
      const session_cost = createMemo(() => context.data.session.cost(context.data.session.root(props.sessionID)))

      createEffect(
        on(target, (integration_id) => {
          if (integration_id) void usageRefresh(integration_id)
        }),
      )
      createEffect(
        on(
          session_cost,
          () => {
            const integration_id = target()
            if (integration_id) usageSchedule(integration_id, SETTLE_MS)
          },
          { defer: true },
        ),
      )
      const interval = setInterval(() => {
        const integration_id = target()
        if (integration_id) void usageRefresh(integration_id)
      }, REFRESH_MS)
      onCleanup(() => clearInterval(interval))

      const state = createMemo(() => {
        const integration_id = target()
        return integration_id ? states()[integration_id] : undefined
      })

      const color = () => {
        const usage = state()?.usage
        if (!usage?.limit) return theme().text.muted
        const ratio = usage.total / usage.limit
        if (ratio >= 1) return theme().text.feedback.error.base
        if (ratio >= 0.9) return theme().text.feedback.warning.base
        return theme().text.muted
      }

      const label = () => {
        const usage = state()?.usage
        if (!usage) return
        const session = session_cost()
        const other = Math.max(0, usage.total - session)
        const limit = usage.limit != null ? money.format(usage.limit) : "∞"
        const suffix = (usage.window && WINDOW_SUFFIX[usage.window]) ?? ""
        return `(${money.format(session)} + ${money.format(other)}) ${money.format(usage.total)} / ${limit}${suffix}`
      }

      const percent = () => {
        const usage = state()?.usage
        if (!usage?.limit) return
        return Math.round((usage.total / usage.limit) * 100)
      }

      // Same layout as the built-in sidebar "Context" section it sits above.
      return (
        <Show when={target() && state()}>
          <box>
            <text fg={theme().text.base}>
              <b>OpenRouter</b>
            </text>
            <Show when={label()}>
              {(text) => (
                <text fg={color()} wrapMode="word">
                  {text()}
                </text>
              )}
            </Show>
            <Show when={percent() !== undefined}>
              <text fg={color()}>{`${percent()}% used`}</text>
            </Show>
            <Show when={state()?.error}>
              {(error) => (
                <text fg={theme().text.faint} wrapMode="word">
                  {state()?.usage ? `stale: ${error()}` : error()}
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

    context.keymap.layer(() => ({
      mode: "global",
      commands: [
        {
          id: "openrouter-tracker.refresh",
          title: "Refresh OpenRouter spend",
          group: "OpenRouter",
          palette: true,
          slash: { name: "openrouter-refresh" },
          run: () => {
            const route = context.ui.router.current()
            const integration_id = route.type === "session" ? openrouterTarget(context, route.sessionID) : undefined
            if (integration_id) void usageRefresh(integration_id, true)
            else context.ui.toast.show({ message: "Current session is not using OpenRouter", variant: "info" })
          },
        },
      ],
    }))

    return () => {
      stopSidebar()
      for (const timer of timers.values()) clearTimeout(timer)
      timers.clear()
    }
  },
})
