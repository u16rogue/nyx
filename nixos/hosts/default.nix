{ nixpkgs, ... }: let
    lib = nixpkgs.lib;
in lib.pipe (builtins.readDir ./.) [
    (lib.filterAttrs (name: value: value == "directory"))
    (lib.mapAttrs (name: value: {
        path = ./. + "/${name}"; # sloppa told me this is the right thing to do
        description = ""; # just to satisfy nix flake check
    }))
]
