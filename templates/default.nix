{ lib, ... }: {
    flake.templates = lib.pipe (builtins.readDir ./.) [
        (lib.filterAttrs (filename: filetype: filetype == "directory"))
        (lib.mapAttrs (filename: filetype: {
            path = ./. + "/${filename}";
            description = "";
        }))
    ];
}
