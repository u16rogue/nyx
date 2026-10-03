{
    inputs, pkgs, lib, writeText,
    hyprland,
    hyprpaper, waybar, fuzzel, ghostty,
    xwayland, grim, slurp, satty, wl-clipboard, procps, dbus, systemd, uwsm, xdg-utils,
    overridesOpts ? {}, ...
}: let
    snippets = import ./snippets.nix { inherit lib; };
    monitors = overridesOpts.monitors or [];
    hyprland_config =
        if (monitors != []) then # if need to write something extra to the config
            writeText "hyprland.lua" (
                builtins.readFile ./hyprland.lua
                + "\n" + lib.concatMapStringsSep "\n" snippets.mkMonitor monitors + "\n"
            )
        else # otherwise it can just directly import the file
            ./hyprland.lua
    ;
    # AI-assisted: private session payload; the public launcher always enters UWSM.
    # Keep this basename so UWSM loads its start-hyprland environment plugin.
    session = pkgs.writeShellApplication {
        name = "start-hyprland";
        runtimeInputs = [
            hyprland hyprpaper waybar fuzzel ghostty
            xwayland grim slurp satty wl-clipboard procps dbus systemd uwsm xdg-utils
        ];
        text = /*bash*/ ''
            export NIXOS_OZONE_WL=1
            # Wait for $XDG_RUNTIME_DIR/doc before Nixpak apps bind it; failure aborts startup.
            busctl --user call \
                org.freedesktop.portal.Documents /org/freedesktop/portal/documents \
                org.freedesktop.portal.Documents GetMountPoint >/dev/null
            exec ${hyprland}/bin/start-hyprland -- --config ${hyprland_config} "$@"
        '';
    };

in inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = hyprland;
    exePath = "${uwsm}/bin/uwsm";
    binName = "start-hyprland";
    args = [ "start" "-U" "run" "-g" "-1" "-eD" "Hyprland" "--" "${session}/bin/start-hyprland" "$@" ];
    filesToPatch = [ "nix-support/*" "share/applications/*.desktop" "share/wayland-sessions/*.desktop" ];
    patchHook = ''
        # Both entries use the managed launcher; the upstream UWSM entry would nest UWSM.
        rm "$out/share/wayland-sessions/hyprland-uwsm.desktop"
        cp "$out/share/wayland-sessions/hyprland.desktop" "$out/share/wayland-sessions/hyprland-uwsm.desktop"
    '';
}
