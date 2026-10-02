# THIS WAS WRITTEN BY A CLANKER
# Used by the script's nix shell and the offline ISO, not exported as a package.
{ pkgs ? import (builtins.fetchTree
    (builtins.fromJSON (builtins.readFile ../../flake.lock)).nodes.nixpkgs.locked
) { system = builtins.currentSystem; } }:
with pkgs; [ bash coreutils util-linux nix nixos-install-tools jq rage openssh systemd ]
