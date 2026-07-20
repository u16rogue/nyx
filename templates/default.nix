{ lib, ... }: {
    flake.templates = lib.pipe (builtins.readDir ./.) [
        (lib.filterAttrs (name: value: value == "directory"))
        (lib.mapAttrs (name: value: {
            path = ./. + "/${name}";
            description = "";
        }))
    ];
}
