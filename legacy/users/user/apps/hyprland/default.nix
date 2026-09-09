{ username, host-custom, ... }: { lib, pkgs, ... }: {

    programs.hyprland = {
        enable = true;
        xwayland.enable = true;
    };

    xdg.portal = {
        enable = true;
        extraPortals = with pkgs; [
            xdg-desktop-portal-hyprland
            xdg-desktop-portal-gtk
        ];
        config.common = {
            "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        };
    };

    systemd.user.services.xdg-desktop-portal = {
        wants = [ "xdg-desktop-portal-gtk.service" ];
        after = [ "xdg-desktop-portal-gtk.service" ];
    };

    environment.sessionVariables.NIXOS_OZONE_WL = "1"; # electron app fix iirc

    home-manager.users.${username} = {
        home.packages = [ pkgs.xdg-desktop-portal-gtk ];

        services.hyprpaper = {
            enable = true;
            settings = {
                splash = false;
                wallpaper = [
                    {
                        monitor = "";
                        path = "/home/${username}/media/wallpaper";
                        fit_mode = "cover";
                    }
                ];
            };
        };

        wayland.windowManager.hyprland = {
            enable = true;
            settings = {
                "$mainMod" = "SUPER";
                "$up" = "W";
                "$left" = "A";
                "$right" = "D";
                "$down" = "S";

                bind = [
                    # toggles
                    "$mainMod SHIFT, grave, exec, kitty"
                    "$mainMod, grave, exec, fuzzel"
                    "$mainMod, F1, exec, hyprctl dispatch dpms toggle"
                    "CTRL, Print, exec, ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp -o -r -c '##ff0000ff')\" -t png - | ${pkgs.satty}/bin/satty -f - -o - --fullscreen --actions-on-enter save-to-file --early-exit | ${pkgs.wl-clipboard}/bin/wl-copy"

                    # https://github.com/hyprwm/Hyprland/issues/4906
                    # movement
                    "$mainMod, $right, execr, sh -c 'if [ $(hyprctl activewindow -j | ${pkgs.jq}/bin/jq \"(.grouped|length==0) or (.address==.grouped[-1])\") = \"true\" ]; then hyprctl dispatch movefocus r; else hyprctl dispatch changegroupactive f; fi'"
                    "$mainMod, $left,  execr, sh -c 'if [ $(hyprctl activewindow -j | ${pkgs.jq}/bin/jq \"(.grouped|length==0) or (.address==.grouped[0])\") = \"true\" ]; then hyprctl dispatch movefocus l; else hyprctl dispatch changegroupactive b; fi'"
                    "$mainMod, $up, movefocus, u"
                    "$mainMod, $down, movefocus, d"
                ];

                # only show waybar if mod key is pressed: https://old.reddit.com/r/hyprland/comments/11cdj3d/deleted_by_user/kv3zeuv/
                bindit = [ "$mainMod, SUPER_L, exec, pkill -SIGUSR1 waybar" ];
                bindirt = [ "$mainMod, SUPER_L, exec, pkill -SIGUSR1 waybar" ];
            } // host-custom.hyprland.settings.append;
            extraConfig = builtins.readFile ./hyprland.conf;
        };
    };
}
