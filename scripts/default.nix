{ lib, ... }: {
    imports = lib.pipe (builtins.readDir ./.) [
        (lib.filterAttrs (name: value:
            value == "directory"
            && builtins.pathExists (./. + "/${name}/flake-part.nix")))
        builtins.attrNames
        (builtins.map (name: ./. + "/${name}/flake-part.nix"))
    ];
}
