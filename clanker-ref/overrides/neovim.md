# overrides/neovim

Plain Neovim wrapped with `wrapNeovimUnstable`, no plugin manager. Files: `overrides/neovim/package.nix`, `init.lua`, `lua/`.

## Split between the editor and the project

The override carries the editor only: plugins, keymaps and the grammars for files found in any project (bash, nix, json, toml, yaml, ...). Language servers, language grammars and snippets belong to the project. Don't add a language server to the override.

What a project provides:

- `.nvim.lua` at its root, run through `exrc` after `init.lua` once trusted. It calls `vim.lsp.enable(...)` with `nvim-lspconfig` names. A server only starts if its binary is on `PATH`, so only inside the devshell. A missing binary is logged to the LSP log, not shown.
- Grammars: a devshell package with `share/nvim/site/parser/<lang>.so`. stdenv adds every package's `share` to `XDG_DATA_DIRS`, which puts it on the runtimepath. The queries for every language come from nvim-treesitter's `runtime/`, appended in `package.nix`. The ssm `shell.nix.mo` templates and the root `flake.nix` do this with an inline `linkFarm "nvim-grammars"`.
- Snippets: the nearest `.nvim/snippets` at or above the startup directory, VS Code format, found once at startup. Nothing else is loaded, friendly-snippets is not installed.

nyx follows this itself: `.nvim.lua` at the root, servers and grammars in the `flake.nix` devshell. `nushell` is enabled in `.nvim.lua` but the devshell has no `nu`, it comes from outside.

## Not obvious

- The config loads through `VIMINIT` (`wrapRc`), `~/.config/nvim/init.lua` is never read.
- Only `./lua` goes onto the runtimepath, as a fileset. A new module there also needs its own line in `overrides/neovim/.gitignore` or the flake doesn't see it.
- Plugins missing from nixpkgs: add a `flake = false` input and put its name in the empty list at the end of the `map` in `package.nix`. Nothing uses it yet.
- `ripgrep` and `fd` are suffixed to `PATH` so a devshell's copies win.
- Telescope greps with `--hidden --no-ignore-vcs`: `.gitignore` is not applied (these repos are inverse ignore, everything would be hidden) and `.ignore` is. That is why the repo and the ssm template ship a `.ignore`.
- `lua/statusline.lua` enables `vim._core.ui2` and patches `msg_show` and `cmdline_show` to put short messages into the statusline with `cmdheight=0`. Those are experimental internals, check them first when a Neovim upgrade breaks messages.
- Trust is per environment. `ssm init` adds a sandbox step that trusts the rendered `.nvim.lua` (`addEditorTrustStep` in `templates/ssm/.ssm/ssm`). Outside of that Neovim asks, or use `:trust`.
- The ssm `.nvim.lua.mo` is one file for every project type. It enables every server and relies on the `PATH` check. `tsc` and `ts_ls` are made mutually exclusive through `root_dir` because a function `cmd` skips the executable check.

## lua-language-server

The devshell `shellHook` in `flake.nix` links a generated `.luarc.json` into `overrides/hyprland` (Hyprland's `hl` stubs) and `overrides/neovim` (`vim` API and the plugins' `lua/`), so they are separate workspaces. The links are only made when `$PWD/overrides` exists, so enter the devshell at the repo root, and again after a flake update. Only top-level plugins are listed, not their dependencies.
