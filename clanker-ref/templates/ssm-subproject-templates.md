# ssm subproject templates

A template type is a directory in `templates/ssm/.ssm/templates/`, picked up by name (`loadSubprojectTemplateTypes` in `templates/ssm/.ssm/ssm`). Nothing else registers it. `zig` and `rust` are the reference for a compiled language with a lockfile.

## What a type ships

- `_ssm.sh`: optional, sourced by ssm. Declares `ssm_tpl_covers` and the flake additions, defines the `scaffold`, `stage` and `finalize` hooks. Not rendered into the project.
- `.gitignore.mo`: the subproject's inverse ignore. Without it one is generated per directory from the template's entries.
- `do.mo` (executable): the same commands for every type, `run`, `run-release`, `build`, `build-release`, `test`, `check`, `lock`, `dev`. One without an equivalent dies through `none`. `package.nix` builds with `bash ./do build-release`.
- `package.nix.mo`, `shell.nix.mo`: the root flake calls both with `callPackage`. The devshell frags are `mkShellNoCC` with `inputsFrom` every subproject shell.

`.mo` files are rendered with `subproject_name` and `subproject_version`, the rest is copied.

## Not obvious

- The hooks run inside the devshell, and evaluating the devshell evaluates `package.nix`. A lockfile that `package.nix` reads has to be shipped by the template (`Cargo.lock.mo`, `build.zig.zon.nix`, `roc.lock.json`, `bun.lock.nix`). A hook can only rewrite it.
- `inputsFrom` carries the inputs and the `shellHook`, not environment variables and not the stdenv's compiler. A `mkShellNoCC` shell that needs a linker lists `stdenv.cc` in `packages` (rust). Variables go into a `shellHook`.
- Build output goes into `.build` and is declared as a cover. Rust gets there with `target-dir` in the subproject's `.cargo/config.toml`, so plain cargo and rust-analyzer agree with `./do`. `cargoSetupHook` writes its vendoring config one directory above the source, the two merge.
- The editor side is shared: `.nvim.lua.mo` enables every language server, `.ignore.mo` lists every type's generated directories. A new type adds to those if it isn't there yet, plus the grammar in its own `shell.nix.mo`.

## Testing a type without the tui

`ssm add <name> <type>` ends in a `gum confirm`, it needs a tty. Rendering by hand is enough for the files: source `mo`, set `subproject_name` and `subproject_version`, render every `.mo` into a temporary directory. Then `nix develop --impure -f` an expression that wraps the rendered `shell.nix` in an outer `mkShellNoCC { inputsFrom = [ ... ]; }` like the root flake does, and `nix build --impure -f` the `package.nix`. Both take nixpkgs from `(builtins.getFlake "path:<repo>").inputs.nixpkgs`. `templates/try-ssm` is the full run, on the host.
