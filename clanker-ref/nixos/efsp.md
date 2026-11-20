# efsp (partial preservation)

`ephemeralfs.preserve.partial.directories` on hosts and users, spec in https://github.com/u16rogue/nyx/issues/3. Code: the preservation builder block in `nixos/default.nix` and `scripts/nyx-efsp/nyx-efsp`. It is part of nyx itself, every host gets it. The user rejected a separate `flake.modules.nixos.efsp` module with `nyxos.efsp` options, don't reintroduce one.

## Design

- The mounts are not ours. The builder declares a second preservation root, `preservation.preserveAt."/persist/.partial/current"`. Preservation then produces the bind mounts, the user-owned parents and the tmpfiles rules, and its layout under a root is already the one the spec asks for (`<generation>/home/user/.cache`).
- `current` and `next` are relative symlinks into `generation/<timestamp>`. `nyx-efsp boot` (unit `nyx-efsp.service`) sets `current` to `next` before the mounts. It is `requiredBy` and `before` each mount unit, whose names are derived from preservation's evaluated directories with `utils.escapeSystemdPath`.
- A generation is kept across reboots. Only `nyx-efsp new` makes the next boot start empty. This is a reading of the draft spec, not something the user confirmed in detail.
- `current` must never move while the mounts of this boot are up, otherwise `gc` would delete the generation that is mounted. Two guards: `restartIfChanged = false` on the unit, and the script records the kernel boot id in `<partial>/boot-id` and does nothing when it matches.
- `gc` refuses to remove anything when it can't resolve `current`.
- `current` as a real directory is the failure mode to expect. It appears when someone creates `<partial>/current/...` by hand before the first boot (this happened on mistylake while moving data in), and also after any failed start of the unit, because the mounts fail with it and tmpfiles then creates its rules' paths through the missing link. Left alone it fails every later boot. `nyx-efsp boot` therefore adopts such a directory as a new generation (`currentAdopt`). It becomes `next` only when the pending generation is empty, otherwise the pending one holds the real data and the adopted one is left for gc.
- When the unit fails, the directories silently stay on the tmpfs root. `systemctl --failed` shows `nyx-efsp.service`, the mount units only show as inactive.
- The partial root is fixed at `/persist/.partial` in both the builder and the script default. The CLI runs under sudo, which drops the environment, so a configurable path would have to be baked into the package.

## Gotchas

- Nobody creates the source directory of a bind mount explicitly. systemd does it when it starts a bind mount unit, tmpfiles fixes the ownership afterwards. Both follow the `current` symlink.
- `nixos/nyxos-install/manifest.nix` renders every rule of `systemd.tmpfiles.settings.preservation` into the installer. Rules under `/persist/.partial/` are filtered out there, otherwise the installer would create `current` as a real directory and `nyx-efsp boot` would refuse it.
- The same volatile parent (`/home/user/.nyx`) gets a tmpfiles rule from both preservation roots. They merge because the values are equal. A different mode on one side would be an eval error.

## Testing

No KVM in the sandbox, a NixOS VM test still runs under emulation in a few minutes. The logic sits in the core builder, so a test node has to copy the efsp part of that block next to `preservation.nixosModules.default` (build from outside the repo with `nix build --impure -f test.nix` and `builtins.getFlake "git+file://<repo>"`). It passed that way when it was written. For a refactor, an unchanged `system.build.toplevel.drvPath` of the hosts proves nothing changed. The script alone can be exercised unprivileged with `NYX_EFSP_DIR` pointing at a temp directory.
