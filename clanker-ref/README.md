# nyx clanker reference

nyx is a NixOS flake: host and user configurations (`nixos/`), wrapped packages (`overrides/`), scripts (`scripts/`), project templates (`templates/`) and CI automation (`_nyx/`, `.github/workflows`). The root `README.md` is the user's own overview of the layout and conventions, read it for those.

## Subtleties

- The search tools honor the root `.ignore`, which hides `.ssm/`. A plain grep or glob silently skips everything under `templates/ssm/.ssm`. Search it with `rg --no-ignore --hidden`, or grep the output of `jj file list`.
- The repo is inverse ignore, every directory has a `.gitignore` listing its files. A new file that isn't un-ignored is invisible to jj, to the flake and to your clanker change. Check `jj status` shows it. Four clanker READMEs were lost from history this way.
- `clanker-ref/` is un-ignored with a `*.md` glob in the root `.gitignore` and in the ssm template's `.gitignore.mo`. Only markdown ends up tracked.
- The root `AGENTS.md` and `.jj.toml` are symlinks into `templates/ssm/.ssm/`. Editing them edits the template that `ssm init` copies into new projects.
- `{{! ... }}` in the `.mo` templates is a mustache comment, it doesn't reach the rendered file.
- Disclosure used to be comment markers (`THIS WAS WRITTEN BY A CLANKER`, `CLANKER START/END/ASSISTED/EDITED`, `AI-assisted:`). They were removed in one clanker change, its diff is the record of what was marked. Don't add new ones. Ssm projects generated before that still carry them.
- There is no python in the sandbox. `nix run --inputs-from . nixpkgs#python3` works.

## File Index

- [nixos/efsp.md](nixos/efsp.md): partial preservation, how it rides on the preservation module, the generation links, installer interaction
- [scripts/sbx-shell.md](scripts/sbx-shell.md): the sandbox's terms, mount and cover semantics, what is exposed inside, nix-develop, hazards
- [overrides/hyprland.md](overrides/hyprland.md): host versus user split for desktops, the uwsm launch chain, NYX_HYPR_PATH, config generation
- [overrides/neovim.md](overrides/neovim.md): what the editor override carries versus what a project provides, lua-language-server setup
- [overrides/nixpak.md](overrides/nixpak.md): conventions of the nixpak sandboxed overrides, the document portal ordering, obs-studio and moonlight-stream notes
