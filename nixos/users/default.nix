{ lib, ... }: {
    imports = lib.pipe (builtins.readDir ./.) [
        (lib.filterAttrs (name: value:
            value == "regular"
            && name != "default.nix"
            && builtins.match ".*\\.nix" name != null))
        builtins.attrNames
        (builtins.map (name: ./. + "/${name}"))
    ];
}
