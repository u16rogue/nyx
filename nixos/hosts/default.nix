{ lib, ... }: {
    imports = lib.pipe (builtins.readDir ./.) [
        (lib.filterAttrs (name: value:
            value == "regular"
            && name != "default.nix"
            && builtins.match ".*\\.nix" name != null))
        builtins.attrNames
        (builtins.map (name: ./. + "/${name}"))
    ];

    # Add option to add `keys.hosts.<hostname> = "public key...";`
    options.keys.hosts = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
    };
}
