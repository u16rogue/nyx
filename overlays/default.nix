{ nixpkgs, inputs, pkgs, ... }: let
    lib = nixpkgs.lib;
in lib.pipe (builtins.readDir ./.) [
    (lib.filterAttrs (name: value: value == "directory"))
    (lib.mapAttrs (name: value: import ./${name}/package.nix { inherit inputs pkgs; } ))
]

