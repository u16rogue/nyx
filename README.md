# nyx
my nix slop

## General

* This repo is ***explicit*** inverse ignore. Everything is ignored by default and must be explicitly included by excluding it from the glob within the `.gitignore`. A utility script [mkignore](./scripts/mkignore/mkignore) is available to auto generate these ignore files.

* Any code or wall of text written by a clanker must be disclosed for sanity.

* Q: Why a separate `nyx` "namespace" ? A: To query `#nyx` for the builtin scripts, to extend `nixosSystem` way beyond (especially `users.users.*.*`), to make things easier to assert, and to minimize duplication (eg. if the `users` extended options was implemented in nixosSystem).

* Separation of concern. Things should go where they belong.
    * The desktop is a user preference. It goes to the [user](./nixos/users/)
    * Hardware is a host concern, therefore it goes to the hosts' configuration (hosts importing cpu-* and gpu-* modules) while audio (pipewire module) is a user concern and therefore it goes to the user who wants audio's `host-configuration`. (i think this is grammatically incorrect and im not delegating that judgement to a clanker)
        * The thought process is as follows: if no user wants pipewire/audio there will be no host with pipewire/audio.
    * Its okay to define these modules multiple times (per user and per host) as long as its clear. eg. gpg-agent module defined for a user because they use it for git and for a host because they use it to sign backups therefore the host and user will both import the `flake.modules.nixos.gpg-agent` module.

## Contents

* [scripts](./scripts) - A set of custom scripts
    * Each entry is treated as a package with its own dependencies and contains its own `package.nix` and the actual script itself as a plain file.
    * Script entries are aggregated by [scripts/default.nix](./scripts/default.nix) filtering for entries that have `package.nix` on them and added as a `packages` entry via flake-parts.
    * Entries are **not** flake-part modules and should be treated as their own standalone unit.
    * A custom `writeNuShellApplication` that mirrors nix `writeShellApplication` is made available which creates the executable package and also installs it as a nushell module that becomes available to nushell. This is useful to preserve nushell data allowing nushell scripts that just runs while also having them as proper modules that can be used in a nu shell operation.

* [overrides](./overrides) - A set of customized packages
    * Each entry is an override of an existing package exported via its own `package.nix`.
    * Each package should be self contained (eg. homeless) and be treated as a standalone.
    * Packages are aggregated by [overrides/default.nix](./overrides/default.nix) filtering for entries that have `package.nix` on them and added as a `packages` entry via flake-parts.
    * Entries are **not** flake-part modules and should be treated as their own standalone unit.
    * Package entries uses [wrappers](https://github.com/lassulus/wrappers).
    * Packages that expose `overridesOpts` can be further customized, for example `package.override { overridesOpts = { color = "#fff"; }; }`.
    * Sandboxed overrides uses `$HOME/.nyx/app-fake-root/<package>` as its bind point

* [templates](./templates) - A set of templates with flakes. Mostly for development; includes a sandboxing shell hook.

* [nixos](./nixos) - NixOS configurations.
    * [nyxos-install](./nixos/nyxos-install) - Clanker-written, directly runnable installation script with automatic `nix shell` dependencies; bootstraps host identity and persistence, and can build a host-specific offline installer ISO.
    * `nyx` related options are defined in [nixos/default.nix](./nixos/default.nix)
    * Host configurations must provide the disks for the paths `/boot` and `/persist`. Hosts should follow the common `fileSystems` provided by `nyx`.
    * Systems/NixOS/Hosts are expected to use an ephemeral filesystem where each host and user are required to explicitly state which files and directories are to be preserved.
    * [modules](./nixos/modules) - Set of flake-parts `nixos` modules. All `*.nix` are aggregated and imported to be available.
    * [hosts](./nixos/hosts) - Set of flake-parts+nyx modules specifically defining host machines.
        * All `*.nix` are aggregated and imported to be evaluated.
        * Hosts must derive its users from `nyx.nixos.users`.
        * `nixosSystem` are managed by `nyx` and the entries must ***not*** provide its own `flake.nixosConfigurations` attr.
        * All host must provide its own ed25519 keys. The `nyx` script provides multiple utilities for managing this.
    * [users](./nixos/users) - Set of flake-parts+nyx modules.

* [legacy](https://github.com/u16rogue/dotfiles/tree/nix/self) - My old nixos config (dropped from this repo)

* [_nyx](./_nyx) + [workflows](./.github/workflows) - Meta folder(s). Contains scripts that are meant for automation. Mostly written by clankers.
    * Flake check
    * [assert_hosts](./_nyx/assert_hosts) - Checks host registration against `nixosConfigurations`, requires at least one uniquely named registered user object, verifies `networking.hostName`, ensures `/boot` and `/persist` are wired correctly, validates `keys.pub` and `keys.prv`, and verifies password recipients.
    * [assert_templates](./_nyx/assert_templates) - Ensure template lock files are in sync.
    * [overrides/firefox/addons-assert.sh](./overrides/firefox/addons-assert.sh) - Ensure addon configuration entries are valid addons.
