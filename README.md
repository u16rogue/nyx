# nyx
my nix slop

## General

* This repo is ***explicit*** inverse ignore. Everything is ignored by default and must be explicitly included by excluding it from the glob within the `.gitignore`. A utility script [mkignore](./scripts/mkignore/mkignore) is available to auto generate these ignore files.

* Any code or wall of text written by a clanker must be disclosed for sanity.

* Q: Why a separate `nyx` "namespace" ? A: To query `#nyx` for the builtin scripts, to extend `nixosSystem` way beyond (especially `users.users.*.*`), to make things easier to assert, and to minimize duplication (eg. if the `users` extended options was implemented in nixosSystem).

## Contents

* [scripts](./scripts) - A set of custom scripts
    * Each entry is treated as a package with its own dependencies and contains its own `package.nix` and the actual script itself as a plain file.
    * Script entries are aggregated by [scripts/default.nix](./scripts/default.nix) filtering for entries that have `package.nix` on them and added as a `packages` entry via flake-parts.
    * Entries are **not** flake-part modules and should be treated as their own standalone unit.

* [overrides](./overrides) - A set of customized packages
    * Each entry is an override of an existing package exported via its own `package.nix`.
    * Each package should be self contained (eg. homeless) and be treated as a standalone.
    * Packages are aggregated by [overrides/default.nix](./overrides/default.nix) filtering for entries that have `package.nix` on them and added as a `packages` entry via flake-parts.
    * Entries are **not** flake-part modules and should be treated as their own standalone unit.
    * Package entries uses [wrappers](https://github.com/lassulus/wrappers).
    * Packages provide an `overridesOpts` attr that can be use to further customize the package. eg. `package.override { overridesOpts = { color = "#fff"; }; }`

* [templates](./templates) - A set of templates with flakes. Mostly for development; includes a sandboxing shell hook.

* [nixos](./nixos) - NixOS configurations.
    * `nyx` related options are defined in [nixos/default.nix](./nixos/default.nix)
    * Host configurations must provide the disks for the paths `/boot` and `/persist`. Host should follow the common `fileSystems` provided by `nyx`.
    * Systems/NixOS/Hosts are expected to use an ephemeral filesystem where each host and user are required to explicitly state which files and directories are to be preserved.
        * A `partial` preservation is available via `nyx.nixos.hosts.<hostname>.ephemeralfs.preserve.partial.directories` to list directories that can be preserved and should possibly be stored to disk without the explicit necessity that it should be saved. Useful for systems that does not have a large enough RAM space for a root tmpfs or for directories that do need large spaces (eg home directories as its used by some programs and scripts to download large blobs that are discarded later or cache)
    * [modules](./nixos/modules) - Set of flake-parts `nixos` modules. All `*.nix` are aggregated and imported to be available.
    * [hosts](./nixos/hosts) - Set of flake-parts+nyx modules specifically defining host machines.
        * All `*.nix` are aggregated and imported to be evaluated.
        * Hosts are aggregated from `nyx.nixos.hosts.*`
        * `nixosSystem` are managed by `nyx` and the entries must ***not*** provide its own `flake.nixosConfigurations` attr.
        * All host must provide its own ed25519 keys. The `nyx` script provides multiple utilities for managing this.
    * [users](./nixos/users) - Set of flake-parts+nyx modules.

* [legacy](./legacy) - My old nixos config

* [_nyx](./_nyx) + [workflow](./.github/workflow) - Meta folder(s). Contains scripts that are meant for automation. Mostly written by clankers.
    * Flake check
    * [assert_hosts](./_nyx/assert_hosts) - Checks host registration against `nixosConfigurations`, requires at least one `users` entry, verifies `networking.hostName`, ensures `/boot`, `/persist`, and `/var/log` are wired correctly, and validates `keys.pub` and `keys.prv`.
    * [assert_templates](./_nyx/assert_templates) - Ensure template lock files are in sync.

## TODO
* `sbx-shell` +/ `sbx-develop` as a replacement to the current [`.devshellshook.sh` -> setup custom env -> bwrap] pipeline. `flake.nix` shouldn't be deploying development sandboxes.
    * side: get `devenv.sh` working with `bwrap` and figure out a way to have the project `flake.nix` and devenv sync locks.
    * find a way to safely bind the nix socket inside or an alternative to caching as to not duplicate `~/.local/nix/store` per project sandbox (it currently just binds it as ro)
* `overrides.opencode` that carry my auth keys and config so i dont have to setup and auth opencode per project
    * the current setup might be a better idea. tedious but "clean"-er.
    * alt: setup a script+age that auto configures opencode for that project sandbox
* `nyx.nixos.users.<user>.ephemeralfs.preserve` files and directories that are not absolute paths (just check if it starts with `/`) should automatically assume it prepends `/home/${username}/${value}`
* `nyx user-make-secret <user>` command where the script can automatically derive the hosts that the user belong to, collect the pk's and generate the age'd output with recipients to that host
* outputs for `nyx` related entries such as `nyx.overrides`, `nyx.scripts` and aggregated to `nyx.packages` etc
