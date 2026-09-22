{
    inputs, pkgs, lib, writeText,
    hyprland, xwayland, grim, slurp, satty, wl-clipboard, jq,
    xdg-desktop-portal-hyprland,
    hyprpaper, waybar,
    overridesOpts ? {}, ...
}: let
    monitors = overridesOpts.monitors or [{
        id = "";
        resolution = null;
        refreshrate = null;
        position = null;
        scale = 1;
        enabled = true;
    }];
    renderMonitor = monitor:
        if !monitor.enabled then
            ''hl.monitor({ output = ${builtins.toJSON monitor.id}, disabled = true })''
        else let
            mode = if monitor.resolution == null then "highrr" else "${toString monitor.resolution.x}x${toString monitor.resolution.y}";
            refreshrate = lib.optionalString (monitor.refreshrate != null) "@${toString monitor.refreshrate}";
            position = if monitor.position == null then "auto" else "${toString monitor.position.x}x${toString monitor.position.y}";
        in ''hl.monitor({ output = ${builtins.toJSON monitor.id}, mode = "${mode}${refreshrate}", position = "${position}", scale = ${toString monitor.scale} })'';
    xdph = xdg-desktop-portal-hyprland;
    hyprland_config = writeText "hyprland.lua" ''
        local mainMod = "SUPER"

        ${lib.concatMapStringsSep "\n" renderMonitor monitors}

        hl.env("XCURSOR_SIZE", "24")
        hl.env("HYPRCURSOR_SIZE", "24")

        hl.config({
            general = {
                gaps_in = 0,
                gaps_out = 0,
                border_size = 2,
                col = {
                    active_border = "rgb(d2e1fa)",
                    inactive_border = "rgb(6d7b91)",
                },
                resize_on_border = false,
                allow_tearing = false,
                layout = "dwindle",
            },
            animations = {
                enabled = false,
            },
            dwindle = {
                smart_split = true,
                preserve_split = true,
            },
            master = {
                new_status = "master",
            },
            misc = {
                force_default_wallpaper = 0,
                disable_hyprland_logo = true,
            },
            input = {
                kb_layout = "us",
                follow_mouse = 0,
                sensitivity = 0,
                touchpad = {
                    natural_scroll = false,
                },
            },
            binds = {
                movefocus_cycles_groupfirst = true,
            },
        })

        hl.permission({
            binary = "${xdph}/libexec/.xdg-desktop-portal-hyprland-wrapped",
            type = "screencopy",
            mode = "allow",
        })
        hl.permission({
            binary = "${grim}/bin/grim",
            type = "screencopy",
            mode = "allow",
        })

        hl.on("hyprland.start", function()
            hl.exec_cmd("${hyprpaper}/bin/hyprpaper")
            hl.exec_cmd("${waybar}/bin/waybar")
        end)

        hl.bind(mainMod .. " + X", hl.dsp.exit())
        hl.bind(mainMod .. " + TAB", hl.dsp.group.toggle())
        hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.kill())
        hl.bind(mainMod .. " + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }))
        hl.bind(mainMod .. " + SHIFT + GRAVE", hl.dsp.exec_cmd("ghostty"))
        hl.bind(mainMod .. " + GRAVE", hl.dsp.exec_cmd("fuzzel"))
        hl.bind(mainMod .. " + F1", hl.dsp.dpms({ action = "toggle" }))
        hl.bind("CTRL + PRINT", hl.dsp.exec_cmd([=[grim -g "$(slurp -o -r -c '##ff0000ff')" -t png - | satty -f - -o - --fullscreen --actions-on-enter save-to-file --early-exit | wl-copy]=]))

        hl.bind(mainMod .. " + D", hl.dsp.focus({ direction = "r" }))
        hl.bind(mainMod .. " + A", hl.dsp.focus({ direction = "l" }))
        hl.bind(mainMod .. " + W", hl.dsp.focus({ direction = "u" }))
        hl.bind(mainMod .. " + S", hl.dsp.focus({ direction = "d" }))

        local waybarSignal = hl.dsp.exec_cmd("pkill -SIGUSR1 waybar")
        hl.bind(mainMod .. " + SUPER_L", waybarSignal, { ignore_mods = true, transparent = true })
        hl.bind(mainMod .. " + SUPER_L", waybarSignal, { ignore_mods = true, transparent = true, release = true })

        hl.bind(mainMod .. " + SHIFT + A", hl.dsp.window.move({ direction = "l", group_aware = true }))
        hl.bind(mainMod .. " + SHIFT + D", hl.dsp.window.move({ direction = "r", group_aware = true }))
        hl.bind(mainMod .. " + SHIFT + W", hl.dsp.window.move({ direction = "u", group_aware = true }))
        hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ direction = "d", group_aware = true }))

        for i = 1, 10 do
            local key = i % 10
            hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
            hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
        end

        hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
        hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

        hl.window_rule({
            name = "suppress-maximize-events",
            match = { class = ".*" },
            suppress_event = "maximize",
        })
        hl.window_rule({
            name = "fix-xwayland-drag",
            match = {
                class = "^$",
                title = "^$",
                xwayland = true,
                float = true,
                fullscreen = false,
                pin = false,
            },
            no_focus = true,
        })
    '';
in inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = hyprland;
    exePath = "${hyprland}/bin/start-hyprland";
    binName = "start-hyprland";
    runtimeInputs = [
        hyprland xwayland
        slurp grim satty wl-clipboard jq
    ];
    env = {
        NIXOS_OZONE_WL = "1";
        XDG_CURRENT_DESKTOP = "Hyprland";
        XDG_SESSION_DESKTOP = "Hyprland";
        XDG_SESSION_TYPE = "wayland";
    };
    args = [ "--" "--config" hyprland_config "$@" ];
}
