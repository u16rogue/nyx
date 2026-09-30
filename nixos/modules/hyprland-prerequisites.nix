# enables host level requirements for hyprland.
{
    flake.modules.nixos.hyprland-prerequisites = {
        programs.hyprland = {
            enable = true;
            xwayland.enable = true;
            withUWSM = true;
        };

        xdg.portal.config.hyprland = {
            default = [ "hyprland" "gtk" ];
            "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
            "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
            "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
        };
    };
}
