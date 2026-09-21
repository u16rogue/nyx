{
    inputs, pkgs, lib, writeText,
    hyprland, xwayland, grim, slurp, satty, wl-clipboard, jq,
    hyprpaper, waybar,
    overridesOpts ? {}, ...
}: let
    jq' = "${jq}/bin/jq";
    monitors = overridesOpts.monitors or [{
        id = "";
        resolution = null;
        refreshrate = null;
        position = null;
        scale = 1;
        enabled = true;
    }];
    renderMonitor = monitor: if !monitor.enabled then
            "${monitor.id},disable"
        else let
            mode = if monitor.resolution == null then "highrr" else "${toString monitor.resolution.x}x${toString monitor.resolution.y}";
            refreshrate = lib.optionalString (monitor.refreshrate != null) "@${toString monitor.refreshrate}";
            position = if monitor.position == null then "auto" else "${toString monitor.position.x}x${toString monitor.position.y}";
        in "${monitor.id},${mode}${refreshrate},${position},${toString monitor.scale}";
    hyprland_config = writeText "hyprland.conf" ''
        exec-once = ${hyprpaper}/bin/hyprpaper
        exec-once = ${waybar}/bin/waybar
        $mainMod = SUPER
        $up = W
        $left = A
        $right = D
        $down = S
        
        bind = $mainMod, X, exit,
        bind = $mainMod, tab, togglegroup
        bind = $mainMod SHIFT, Q, killactive,
        bind = $mainMod SHIFT, space, togglefloating,
        bind = $mainMod SHIFT, grave, exec, kitty
        bind = $mainMod, grave, exec, fuzzel
        bind = $mainMod, F1, exec, hyprctl dispatch dpms toggle
        bind = CTRL, Print, exec, ${grim}/bin/grim -g "$(${slurp}/bin/slurp -o -r -c '##ff0000ff')" -t png - | ${satty}/bin/satty -f - -o - --fullscreen --actions-on-enter save-to-file --early-exit | ${wl-clipboard}/bin/wl-copy
        
        bind = $mainMod, $right, execr, sh -c 'if [ $(hyprctl activewindow -j | ${jq'} "(.grouped|length==0) or (.address==.grouped[-1])") = "true" ]; then hyprctl dispatch movefocus r; else hyprctl dispatch changegroupactive f; fi'
        bind = $mainMod, $left, execr, sh -c 'if [ $(hyprctl activewindow -j | ${jq'} "(.grouped|length==0) or (.address==.grouped[0])") = "true" ]; then hyprctl dispatch movefocus l; else hyprctl dispatch changegroupactive b; fi'
        bind = $mainMod, $up, movefocus, u
        bind = $mainMod, $down, movefocus, d
        
        bindit = $mainMod, SUPER_L, exec, pkill -SIGUSR1 waybar
        bindirt = $mainMod, SUPER_L, exec, pkill -SIGUSR1 waybar
        
        bind = $mainMod SHIFT, $left, movewindoworgroup, l
        bind = $mainMod SHIFT, $right, movewindoworgroup, r
        bind = $mainMod SHIFT, $up, movewindoworgroup, u
        bind = $mainMod SHIFT, $down, movewindoworgroup, d
        
        bind = $mainMod, 1, workspace, 1
        bind = $mainMod, 2, workspace, 2
        bind = $mainMod, 3, workspace, 3
        bind = $mainMod, 4, workspace, 4
        bind = $mainMod, 5, workspace, 5
        bind = $mainMod, 6, workspace, 6
        bind = $mainMod, 7, workspace, 7
        bind = $mainMod, 8, workspace, 8
        bind = $mainMod, 9, workspace, 9
        bind = $mainMod, 0, workspace, 10
        
        bind = $mainMod SHIFT, 1, movetoworkspace, 1
        bind = $mainMod SHIFT, 2, movetoworkspace, 2
        bind = $mainMod SHIFT, 3, movetoworkspace, 3
        bind = $mainMod SHIFT, 4, movetoworkspace, 4
        bind = $mainMod SHIFT, 5, movetoworkspace, 5
        bind = $mainMod SHIFT, 6, movetoworkspace, 6
        bind = $mainMod SHIFT, 7, movetoworkspace, 7
        bind = $mainMod SHIFT, 8, movetoworkspace, 8
        bind = $mainMod SHIFT, 9, movetoworkspace, 9
        bind = $mainMod SHIFT, 0, movetoworkspace, 10
        
        bindm = $mainMod, mouse:272, movewindow
        bindm = $mainMod, mouse:273, resizewindow
        
        env = XCURSOR_SIZE,24
        env = HYPRCURSOR_SIZE,24
        
        general {
            gaps_in = 0
            gaps_out = 0
            border_size = 2
            col.active_border = rgb(d2e1fa)
            col.inactive_border = rgb(6d7b91)
            resize_on_border = false
            allow_tearing = false
            layout = dwindle
        }
        
        animations {
            enabled = no
        }
        
        dwindle {
            smart_split = true
            preserve_split = true
        }
        
        master {
            new_status = master
        }
        
        misc {
            force_default_wallpaper = 0
            disable_hyprland_logo = true
        }
        
        input {
            kb_layout = us
            follow_mouse = 0
            sensitivity = 0
            touchpad {
                natural_scroll = false
            }
        }

        windowrule {
            name = suppress-maximize-events
            match:class = .*
            suppress_event = maximize
        }
        
        windowrule {
            name = fix-xwayland-drag
            no_focus = true
            match:class = ^$
            match:title = ^$
            match:xwayland = true
            match:float = true
            match:fullscreen = false
            match:pin = false
        }

        ${lib.concatMapStringsSep "\n" (monitor: "monitor = ${renderMonitor monitor}") monitors}
    '';
in inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = hyprland;
    exePath = "${hyprland}/bin/Hyprland";
    binName = "start-hyprland";
    runtimeInputs = [ hyprland xwayland ];
    flags."--config" = hyprland_config;
}
