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
