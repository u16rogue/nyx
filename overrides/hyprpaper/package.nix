{ inputs, pkgs, hyprpaper, overridesOpts ? {}, ... }: let
    config = pkgs.replaceVars ./hyprpaper.conf {
        wallpaper = overridesOpts.wallpaper or "/etc/wallpaper";
    };
in inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = hyprpaper;
    flags."--config" = config;
}
