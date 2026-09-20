{ inputs, pkgs, waybar, ... }: inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = waybar;
    flags."--config" = ./config.jsonc;
}
