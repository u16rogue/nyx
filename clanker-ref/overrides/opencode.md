# opencode override

`overrides/opencode/package.nix` is the whole setup. Nothing is written to `~/.config/opencode`, the wrapper carries the configuration in two environment variables, each only set when the caller hasn't set it (`setDefault`):

- `OPENCODE_CONFIG_CONTENT`: server and project configuration (what `opencode.json` holds): permissions, agents. Commands, skills, mcp and providers would go here too.
- `OPENCODE_CLI_CONFIG_CONTENT`: terminal preferences (what `cli.json` holds): theme, keybinds, tui plugins.

They are different schemas, a setting only works in the one it belongs to.

The JSON is a store file that the wrapper reads with `cat`. Inlined into the wrapper script it broke the build once a value contained backticks: the wrapper is shellchecked and fails on SC2016.

Because of `setDefault` an opencode started from inside another one (your own shell is one) inherits the outer configuration and ignores what the new wrapper carries. Test a built wrapper with `env -u OPENCODE_CONFIG_CONTENT -u OPENCODE_CLI_CONFIG_CONTENT`.

## Where a new thing goes

- Agent: system prompt in `agents/<id>.md` as plain markdown with no frontmatter, the rest (`description`, `mode`, `permissions`) as `agents.<id>` in `OPENCODE_CONFIG_CONTENT`, with `system = builtins.readFile ./agents/<id>.md`. Not opencode's own markdown agent format: that is only discovered from `~/.config/opencode/agents` and `.opencode/agents`, which the wrapper doesn't own.
- Tui plugin: its own `nyx-<name>/` directory with `package.json` and `tui.tsx`, listed in `plugins` of `OPENCODE_CLI_CONFIG_CONTENT` as a store path. Options go through `{ package; options; }`.
- Every new file needs its line in `overrides/opencode/.gitignore`, otherwise the flake doesn't see it and `readFile` fails on a path that exists on disk.

## Agents

- A non-empty `system` replaces the provider's base prompt. `AGENTS.md` and the other instruction sources are still appended, so an agent also gets the project's rules.
- Agent permissions are appended after the global ones and the last match wins.
- `mentor` is denied `edit` on purpose, the user writes the code. Its prompt is the user's three standing requests: short, point at what to use without writing the solution to their problem, verify before stating. Keep those when editing it.

## Testing without a rebuild

Both commands work in the sandbox. Setting the variable yourself replaces the wrapper's default, which is the point of `setDefault`.

- Is it loaded: `OPENCODE_CONFIG_CONTENT="$(nix eval --impure --json --expr '{ agents.<id> = { ... }; }')" opencode debug agents --standalone`
- The real thing: `nix build .#opencode --no-link --print-out-paths`, then `env -u OPENCODE_CONFIG_CONTENT <out>/bin/opencode debug agents --standalone`.
- Does it behave: the same variable with `opencode run --standalone --agent <id> --archived --auto "<prompt>"` from a temporary directory. This spends the user's inference.

The docs for the configuration shape are at https://opencode.ai/docs/agents and https://opencode.ai/docs/config. The schema at `opencode.ai/config.json` also accepts deprecated V1 fields, don't take field names from it.

## Testing a tui plugin without a rebuild

Point `plugins` at the working tree and drive a real tui in tmux, the plugin is loaded as source so no build is involved:

- A launcher script that exports `OPENCODE_CLI_CONFIG_CONTENT='{"plugins":["<abs path>/nyx-<name>"]}'` and runs `opencode --standalone`, started with `tmux -L <sock> -f /dev/null new-session -d -x 150 -y 40 <script>`. Passing the command inline loses the JSON quotes and the session dies at once.
- `send-keys` to type, `capture-pane -p` to read the screen, about 15 seconds for startup.
- A slash command of the plugin needs no session. The sidebar only exists inside one: `!echo hi` as the prompt creates a session without spending inference. It needs a wide pane.
- To see a section that is gated on the provider, test a copy of the plugin with the gate forced on instead of sending a prompt to that provider.
- `bun build --no-bundle tui.tsx` only proves it parses, there are no types for `@opencode/plugin` to check against.

## Claude usage (nyx-connect-claude)

- There is no `claude` subcommand that prints usage. The numbers come from `GET https://api.anthropic.com/api/oauth/usage` with the access token of `~/.claude/.credentials.json` (`claudeAiOauth.accessToken`, `expiresAt` in ms) and `anthropic-beta: oauth-2025-04-20`. It is what Claude Code's own `/usage` reads, found in its binary, undocumented and free to change.
- `limits[]` is the part to render: `kind` (`session`, `weekly_all`, `weekly_scoped`), `group`, `percent`, `severity`, `resets_at`, `scope.model.display_name`. The per model limit (Fable) only exists there, its legacy key `seven_day_overage_included` is null in the body. Most other keys are codenamed experiments and null.
- The plugin never refreshes the token itself, that would race claude's refresh token rotation. On an expired token it runs `claude auth status` and reads the file again. Whether that command renews the token wasn't verified, there was no expired token to test with.
- Not verified against real data: the `extra_usage` row (it was disabled on the account) and the `severity` values other than `normal`.
