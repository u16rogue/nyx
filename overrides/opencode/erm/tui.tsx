/** @jsxImportSource @opentui/solid */
import { Plugin } from "@opencode/plugin/tui"
import type { Context, PanelInput } from "@opencode/plugin/tui/context"
import { SyntaxStyle } from "@opentui/core"
import { For, Show, createMemo, createSignal } from "solid-js"

const PANEL = "erm.panel"
const PREVIEW_LINES = 6

type Status = "pending" | "done" | "error" | "interrupted"
type Turn = { question: string; answer?: string; error?: string; status: Status }
type Entry = {
  id: string
  time: number
  turns: Turn[]
  collapsed?: boolean
  added?: boolean
  forkID?: string
}
type State = { sessions: Record<string, Entry[]> }

const id = () => `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`

function instructions(turns: Turn[]) {
  const previous = turns.slice(0, -1).filter((turn) => turn.answer)
  const current = turns[turns.length - 1]!
  return [
    "The user is asking a quick side question about the conversation so far.",
    "Answer it directly and concisely. Do not continue the main task, call tools, or propose edits unless asked.",
    ...(previous.length
      ? [
          "",
          "Earlier side questions in this thread:",
          ...previous.flatMap((turn) => ["", `Q: ${turn.question}`, `A: ${turn.answer}`]),
        ]
      : []),
    "",
    `Side question: ${current.question}`,
  ].join("\n")
}

function transcript(entry: Entry) {
  return entry.turns
    .filter((turn) => turn.answer)
    .map((turn) => `Q: ${turn.question}\nA: ${turn.answer}`)
    .join("\n\n")
}

function contextText(entry: Entry) {
  return [
    `<side-question source="erm">`,
    "The user asked this side question earlier and chose to keep the answer in context.",
    "",
    transcript(entry),
    "</side-question>",
  ].join("\n")
}

function preview(text: string, lines: number) {
  const all = text.split("\n")
  return all.length > lines ? `${all.slice(0, lines).join("\n")}\n…` : text
}

function syntax(context: Context) {
  const theme = context.theme
  const rule = (scope: string[], foreground: unknown, style: Record<string, unknown> = {}) => ({
    scope,
    style: { foreground, ...style },
  })
  return SyntaxStyle.fromTheme(
    [
      rule(["default"], theme.text.base),
      rule(["markup.heading", "markup.heading.1", "markup.heading.2", "markup.heading.3"], theme.markdown.heading, {
        bold: true,
      }),
      rule(["markup.bold", "markup.strong"], theme.markdown.strong, { bold: true }),
      rule(["markup.italic"], theme.markdown.emphasis, { italic: true }),
      rule(["markup.list"], theme.markdown.listItem),
      rule(["markup.quote"], theme.markdown.blockQuote, { italic: true }),
      rule(["markup.raw", "markup.raw.block", "markup.raw.inline"], theme.markdown.code),
      rule(["markup.link", "markup.link.url"], theme.markdown.link, { underline: true }),
      rule(["markup.link.label"], theme.markdown.linkText, { underline: true }),
    ] as any,
    context.renderer.nativeScene,
  )
}

export default Plugin.define({
  id: "erm",
  setup(context) {
    const [state, update] = context.storage.store<State>("state", { initial: { sessions: {} } })
    const [inflight, setInflight] = context.storage.memory<Record<string, true>>("inflight", { initial: {} })
    const style = syntax(context)

    // Requests from a previous TUI process can never resolve, so surface them as interrupted.
    void update((draft) => {
      for (const entries of Object.values(draft.sessions))
        for (const entry of entries)
          entry.turns.forEach((turn, index) => {
            if (turn.status === "pending" && !inflight[`${entry.id}:${index}`]) turn.status = "interrupted"
          })
    })

    const entries = (sessionID: string) => state.sessions[sessionID] ?? []
    const find = (sessionID: string, entryID: string) => entries(sessionID).find((entry) => entry.id === entryID)
    const edit = (sessionID: string, entryID: string, fn: (entry: Entry) => void) =>
      update((draft) => {
        const entry = draft.sessions[sessionID]?.find((item) => item.id === entryID)
        if (entry) fn(entry)
      })

    const currentSession = () => {
      const route = context.ui.router.current()
      return route.type === "session" ? route.sessionID : undefined
    }

    async function run(sessionID: string, entryID: string, index: number) {
      const key = `${entryID}:${index}`
      setInflight((draft) => {
        draft[key] = true
      })
      try {
        const entry = find(sessionID, entryID)
        if (!entry) return
        const turns = entry.turns.slice(0, index + 1).map((turn) => ({ ...turn }))
        const result = await context.client.session.generate({ sessionID, prompt: instructions(turns) })
        await edit(sessionID, entryID, (draft) => {
          const turn = draft.turns[index]
          if (!turn) return
          turn.status = "done"
          turn.answer = result.text.trim()
          draft.collapsed = false
        })
        if (currentSession() !== sessionID)
          context.ui.toast.show({ title: "erm", message: "Side question answered", sessionID })
      } catch (error) {
        await edit(sessionID, entryID, (draft) => {
          const turn = draft.turns[index]
          if (!turn) return
          turn.status = "error"
          turn.error = error instanceof Error ? error.message : String(error)
        })
      } finally {
        setInflight((draft) => {
          delete draft[key]
        })
      }
    }

    async function ask(sessionID: string, question: string, entryID?: string) {
      const turn: Turn = { question, status: "pending" }
      if (entryID) {
        let index = -1
        await edit(sessionID, entryID, (entry) => {
          index = entry.turns.push(turn) - 1
          entry.added = false
        })
        if (index >= 0) await run(sessionID, entryID, index)
        return
      }
      const entry: Entry = { id: id(), time: Date.now(), turns: [turn] }
      await update((draft) => {
        draft.sessions[sessionID] = [...(draft.sessions[sessionID] ?? []), entry]
      })
      await run(sessionID, entry.id, 0)
    }

    async function retry(sessionID: string, entry: Entry) {
      const index = entry.turns.length - 1
      const last = entry.turns[index]
      if (!last || (last.status !== "error" && last.status !== "interrupted")) return
      await edit(sessionID, entry.id, (draft) => {
        draft.turns[index]!.status = "pending"
        draft.turns[index]!.error = undefined
      })
      await run(sessionID, entry.id, index)
    }

    const ready = (entry: Entry) => entry.turns.some((turn) => turn.answer)
    const busy = (entry: Entry) => entry.turns.some((turn) => turn.status === "pending")

    async function addToContext(sessionID: string, entry: Entry) {
      if (!ready(entry) || busy(entry)) return
      await context.client.session.synthetic({
        sessionID,
        text: contextText(entry),
        description: `erm: ${entry.turns[0]!.question}`,
        metadata: { plugin: "erm", entryID: entry.id },
        resume: false,
      })
      await edit(sessionID, entry.id, (draft) => {
        draft.added = true
      })
      context.ui.toast.show({ message: "Side answer added to context", variant: "success" })
    }

    async function fork(sessionID: string, entry: Entry) {
      if (!ready(entry) || busy(entry)) return
      const copied: Entry = { ...JSON.parse(JSON.stringify(entry)), added: true, forkID: undefined }
      const forked = await context.client.session.fork({ sessionID })
      await context.client.session.synthetic({
        sessionID: forked.id,
        text: contextText(entry),
        description: `erm: ${entry.turns[0]!.question}`,
        metadata: { plugin: "erm", entryID: entry.id },
        resume: false,
      })
      await update((draft) => {
        draft.sessions[forked.id] = [...(draft.sessions[forked.id] ?? []), copied]
        const source = draft.sessions[sessionID]?.find((item) => item.id === entry.id)
        if (source) source.forkID = forked.id
      })
      context.ui.panel.close()
      if (!context.ui.tabs.focus(forked.id)) context.ui.router.navigate({ type: "session", sessionID: forked.id })
    }

    function copy(entry: Entry) {
      const ok = context.renderer.copyToClipboardOSC52(transcript(entry))
      context.ui.toast.show({ message: ok ? "Copied" : "Clipboard unavailable", variant: ok ? "info" : "warning" })
    }

    async function dismiss(sessionID: string, entryID: string) {
      await update((draft) => {
        const list = draft.sessions[sessionID]?.filter((entry) => entry.id !== entryID) ?? []
        if (list.length) draft.sessions[sessionID] = list
        else delete draft.sessions[sessionID]
      })
    }

    const guard = (fn: () => Promise<unknown> | unknown) => {
      Promise.resolve()
        .then(fn)
        .catch((error) =>
          context.ui.toast.show({
            title: "erm",
            message: error instanceof Error ? error.message : String(error),
            variant: "error",
          }),
        )
    }

    const shortcut = () => context.keymap.shortcuts("erm.panel")[0]

    function TurnView(props: { turn: Turn; full: boolean }) {
      const theme = () => context.theme
      return (
        <box flexDirection="column">
          <text fg={theme().text.muted} wrapMode="word">
            {`› ${props.turn.question}`}
          </text>
          <Show when={props.turn.status === "pending"}>
            <text fg={theme().text.faint}>thinking…</text>
          </Show>
          <Show when={props.turn.status === "interrupted"}>
            <text fg={theme().text.feedback.warning.base}>interrupted (r to retry in panel)</text>
          </Show>
          <Show when={props.turn.status === "error"}>
            <text fg={theme().text.feedback.error.base} wrapMode="word">
              {`error: ${props.turn.error ?? "unknown"}`}
            </text>
          </Show>
          <Show when={props.turn.answer}>
            <markdown
              content={props.full ? props.turn.answer! : preview(props.turn.answer!, PREVIEW_LINES)}
              syntaxStyle={style}
              conceal
            />
          </Show>
        </box>
      )
    }

    function Bar(props: { sessionID: string }) {
      const theme = () => context.theme
      const latest = createMemo(() => entries(props.sessionID).at(-1))
      const count = () => entries(props.sessionID).length
      return (
        <Show when={latest()}>
          {(entry) => (
            <box
              flexDirection="column"
              border={["left"]}
              borderColor={theme().text.action.primary.base}
              paddingLeft={1}
              marginBottom={1}
              flexShrink={0}
            >
              <box flexDirection="row" justifyContent="space-between">
                <text fg={theme().text.action.primary.base}>
                  {`erm${count() > 1 ? ` (${count()})` : ""}${entry().added ? " · in context" : ""}`}
                </text>
                <text fg={theme().text.faint}>{`${shortcut() ?? "/erm-open"} open · ${
                  entry().collapsed ? "/erm-show" : "/erm-hide"
                }`}</text>
              </box>
              <Show
                when={!entry().collapsed}
                fallback={
                  <text fg={theme().text.muted} wrapMode="none">
                    {`› ${entry().turns.at(-1)!.question}`}
                  </text>
                }
              >
                <TurnView turn={entry().turns.at(-1)!} full={false} />
              </Show>
            </box>
          )}
        </Show>
      )
    }

    function Panel(props: { panel: PanelInput }) {
      const theme = () => context.theme
      const list = createMemo(() => entries(props.panel.sessionID))
      const [selected, setSelected] = createSignal(Math.max(0, list().length - 1))
      const current = createMemo(() => list()[Math.min(selected(), list().length - 1)])
      const move = (delta: number) => setSelected((index) => Math.max(0, Math.min(list().length - 1, index + delta)))
      const act = (fn: (entry: Entry) => Promise<unknown> | unknown) => () => {
        const entry = current()
        if (entry) guard(() => fn(entry))
      }

      context.keymap.layer(() => ({
        priority: 10,
        commands: [
          { title: "Previous", bind: "k,up", run: () => move(-1) },
          { title: "Next", bind: "j,down", run: () => move(1) },
          { title: "Add to context", bind: "a", run: act((entry) => addToContext(props.panel.sessionID, entry)) },
          { title: "Fork", bind: "f", run: act((entry) => fork(props.panel.sessionID, entry)) },
          {
            title: "Follow up",
            bind: "r",
            run: act(async (entry) => {
              if (busy(entry)) return
              const last = entry.turns.at(-1)
              if (last && last.status !== "done") return retry(props.panel.sessionID, entry)
              const question = await context.ui.dialog.prompt({ title: "erm follow-up", placeholder: "Ask…" })
              if (question?.trim()) await ask(props.panel.sessionID, question.trim(), entry.id)
            }),
          },
          { title: "Copy", bind: "c,y", run: act(copy) },
          {
            title: "Dismiss",
            bind: "x,d",
            run: act(async (entry) => {
              await dismiss(props.panel.sessionID, entry.id)
              move(0)
              if (!list().length) props.panel.close()
            }),
          },
          { title: "Close", bind: "escape,q", run: () => props.panel.close() },
          { title: "Fullscreen", bind: "z", run: () => props.panel.toggleFullscreen() },
        ],
      }))

      return (
        <box flexDirection="column" flexGrow={1} padding={1}>
          <text fg={theme().text.action.primary.base}>erm · side questions</text>
          <Show when={list().length} fallback={<text fg={theme().text.muted}>No side questions yet. Use /erm.</text>}>
            <box flexDirection="column" marginTop={1} flexShrink={0}>
              <For each={list()}>
                {(entry, index) => (
                  <text
                    fg={index() === selected() ? theme().text.base : theme().text.muted}
                    bg={index() === selected() ? theme().background.raised.high : undefined}
                    wrapMode="none"
                  >
                    {`${index() === selected() ? "›" : " "} ${entry.turns[0]!.question}${
                      busy(entry) ? " …" : ""
                    }${entry.added ? " ✓" : ""}${entry.forkID ? " ⑂" : ""}`}
                  </text>
                )}
              </For>
            </box>
            <scrollbox flexGrow={1} marginTop={1} border={["top"]} borderColor={theme().border.base}>
              <Show when={current()}>
                {(entry) => (
                  <box flexDirection="column" gap={1}>
                    <For each={entry().turns}>{(turn) => <TurnView turn={turn} full />}</For>
                  </box>
                )}
              </Show>
            </scrollbox>
            <text fg={theme().text.faint} wrapMode="word">
              j/k select · a add to context · f fork · r follow-up/retry · c copy · x dismiss · z fullscreen · esc
              close
            </text>
          </Show>
        </box>
      )
    }

    const stripCommand = (input: string | undefined) => (input ?? "").replace(/^\s*\/erm\b/, "").trim()

    const setCollapsed = (collapsed: boolean) => {
      const sessionID = currentSession()
      const latest = sessionID ? entries(sessionID).at(-1) : undefined
      if (sessionID && latest) void edit(sessionID, latest.id, (entry) => (entry.collapsed = collapsed))
    }

    context.keymap.layer(() => ({
      mode: "global",
      commands: [
        {
          id: "erm.ask",
          title: "Ask a side question (erm)",
          group: "erm",
          palette: true,
          slash: { name: "erm", arguments: true },
          run: async (input) => {
            const sessionID = currentSession()
            if (!sessionID) {
              context.ui.toast.show({ message: "Open a session first", variant: "warning" })
              return
            }
            const question =
              stripCommand(input) ||
              (await context.ui.dialog.prompt({ title: "erm", placeholder: "Ask a side question…" }))?.trim()
            if (question) guard(() => ask(sessionID, question))
          },
        },
        {
          id: "erm.panel",
          title: "Open side questions (erm)",
          group: "erm",
          bind: "<leader>j",
          palette: true,
          slash: { name: "erm-open" },
          enabled: () => currentSession() !== undefined,
          run: () => {
            context.ui.panel.open(PANEL)
          },
        },
        {
          id: "erm.hide",
          title: "Collapse latest side question (erm)",
          group: "erm",
          palette: true,
          slash: { name: "erm-hide" },
          run: () => setCollapsed(true),
        },
        {
          id: "erm.show",
          title: "Expand latest side question (erm)",
          group: "erm",
          palette: true,
          slash: { name: "erm-show" },
          run: () => setCollapsed(false),
        },
      ],
    }))

    const stopBar = context.ui.slot({
      append: "session.composer.top",
      render: (input) => <Bar sessionID={input.sessionID} />,
    })
    const stopPanel = context.ui.slot({
      append: "session.panel",
      render: (panel) => (
        <Show when={panel.name === PANEL}>
          <Panel panel={panel} />
        </Show>
      ),
    })

    return () => {
      stopBar()
      stopPanel()
      void context.renderer.idle().then(() => style.destroy())
    }
  },
})
