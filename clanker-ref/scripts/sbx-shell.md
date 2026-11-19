# sbx-shell

Bubblewrap sandbox with persistent per-context state. Everything is in `scripts/sbx-shell/sbx-shell`, `sbx-shell help` lists the commands. This file only has what the help and a quick read don't give you.

## Terms

- Context: `$NYX_SBX_SHELL_DIR/<context-id>` (default `$HOME/.nyx/sbx-shell`). Holds `fs-root/`, `refs/`, `mount/{ro,rw,o}/`, `overlay/`, `cover/`, `enter`.
- Ctxlink: `$PWD/.nyx-sbx/ptr`, a symlink to the context. It is the authoritative reference, deleting `ptr` releases the directory.
- Backlink: `<context>/refs/<directory-id>/ptr`, a symlink back to the working directory. Only gc uses it.
- Directory ID: md5 of the `pwd -P` path. `init '?'` uses it as the context ID.
- Both link containers are real directories with a symlink named `ptr` inside. An older layout used direct symlinks, there is no migration code.

## Not obvious

- Nothing is mounted by default, not even the project. `madd . rw .` after `init`.
- `/` inside is a read-write bind of `<context>/fs-root`, so everything outside `/run`, `/tmp` and the explicit mounts persists and is shared by every directory on that context. Home is `fs-root/$HOME`.
- `madd` mode `o` is not a cover. It is an OverlayFS mount with the host directory as lower and `<context>/overlay/<md5>/{upper,work}`, so writes stay in the context.
- A cover (`mcover`) is a plain bind of `<context>/cover/<md5>/upper` over the target, so host content is hidden, not layered. An existing target needs `--force` (hide) or `--move` (move its entries in). A cover wins over a `madd` at the same path. `scan-coverables` lists directories with no repo files as candidates.
- Selectors differ: `madd` takes an ID or `.`, `mcover` and `scan-coverables` take an ID or a ctxlink path. A bare name matching the ID charset is read as an ID, write `./name` for a directory.
- `$PWD/.nyx-sbx` gets a tmpfs over it after all mounts, which hides `ptr`. tmpfs rather than ro-bind so `path:.` flake evaluation can't copy context metadata into the store. Only the entering directory's `.nyx-sbx` is masked.
- Over that tmpfs, in every mode: `.nyx-sbx/share/` is bound read-write (the host/sandbox exchange directory AGENTS.md relies on) and `.nyx-sbx/dev-hook.sh` read-only (so git inside doesn't report it deleted). A symlink at either is a hard error.
- The environment is cleared. Only `USER HOME SHELL TERM COLORTERM LANG LC_ALL LC_CTYPE NIX_CONFIG PATH` survive, plus `NYX_SBX_ID=<context id>`. `PATH` is a fixed list of profile directories, not the host's.
- `/nix` is bound read-only as a whole. The store isn't writable inside, which is why `nix-develop` runs `nix print-dev-env --profile` on the host before bwrap starts and only sources the result inside.
- There is no `/sys` in the sandbox. `/run/wrappers/bin` is bound when present.
- Arguments after the first `--` go to `$SHELL`, they are not run as a command. `SHELL` is taken as is, so under a host `nix develop` it is bash.

## nix-develop

- Needs `flake.nix` in `$PWD` and an existing project or ancestor mount. It reports an error rather than registering a mount.
- GC roots are at `<context>/refs/<directory-id>/nix-develop/<fragment-id>/devshell`, so they go away with the backlink. gc also prunes generations older than the current one.
- Order inside the sandbox: source the dev environment (runs the flake `shellHook`), restore `SHELL`, default `NIX_FRAGMENT`, source `.nyx-sbx/dev-hook.sh`, exec the shell. A failing hook aborts entry. Hooks get the shell args.
- Extra packages come from a flake devshell fragment. A `packages.list` mechanism existed once and is gone.
- The hook templates (`templates/dev/.nyx-sbx/dev-hook.sh`, `templates/ssm/.ssm/.nyx-sbx/dev-hook.sh`) start Zellij with `.nyx-sbx/share/zellij.kdl` when there are no shell args.
- `scripts/nix-develop/nix-develop` execs `sbx-shell nix-develop` and falls back to plain `nix develop`.

## Session bus

- Each sandbox gets its own `xdg-dbus-proxy` at `/run/nyx-sbx-bus`. The `bus_rules` array only allows showing a notification on `org.freedesktop.Notifications`.
- Only set up when the host `DBUS_SESSION_BUS_ADDRESS` starts with `unix:` and `XDG_RUNTIME_DIR` is a directory. If the proxy doesn't signal within 5 seconds the sandbox continues without a bus.
- The proxy's lifetime is tied to an fd the sandbox inherits, it exits with the last sandboxed process.

## Hazards

- gc takes no lock and doesn't check for running sandboxes before removing a context.
- `<context>/enter` is rewritten on every entry and embeds fd numbers, simultaneous entries into one context share it.
- A context with a missing `refs/` is kept with a warning, one with an empty `refs/` is deleted. A `.nyx-sbx` without `ptr` counts as stale.
- `madd` refuses `/`, top-level directories, `/home/*`, account homes, the store and anything inside a `.nyx-sbx`. Registrations are validated again on entry, a changed symlink target aborts.

## Tests

There are none. Two old test scripts sat git-ignored next to the script, went stale and were deleted. Throwaway test files go in a temporary directory or `.nyx-sbx/share`, not into the source tree.
