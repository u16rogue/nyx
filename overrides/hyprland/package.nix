{
    inputs, pkgs, lib, writeText,
    hyprland,
    hyprpaper, waybar,
    xwayland, grim, slurp, satty, wl-clipboard, jq, dbus, systemd,
    overridesOpts ? {}, ...
}: let
    snippets = import ./snippets.nix { inherit lib; };
    desktop_launcher = pkgs.writeShellApplication {
        name = "start-desktop";
        text = /*bash*/ ''
            exec ${pkgs.uwsm}/bin/uwsm start -eD Hyprland -- @hyprland@/bin/start-hyprland "$@"
        '';
    };
    monitors = overridesOpts.monitors or [];
    hyprland_config =
        if (monitors != []) then # if need to write something extra to the config
            writeText "hyprland.lua" (
                builtins.readFile ./hyprland.lua
                + lib.optionalString (monitors != []) ("\n" + lib.concatMapStringsSep "\n" snippets.mkMonitor monitors + "\n")
            )
        else # otherwise it can just directly import the file
            ./hyprland.lua
    ;

in (inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = hyprland;
    exePath = "${hyprland}/bin/start-hyprland";
    binName = "start-hyprland";
    runtimeInputs = [
        hyprland
        hyprpaper waybar
        xwayland grim slurp satty wl-clipboard jq dbus systemd
    ];
    env = {
        NIXOS_OZONE_WL = "1";
        XDG_CURRENT_DESKTOP = "Hyprland";
        XDG_SESSION_DESKTOP = "Hyprland";
        XDG_SESSION_TYPE = "wayland";
    };
    preHook = /*bash*/ ''
        busctl --user call \
            org.freedesktop.portal.Documents /org/freedesktop/portal/documents \
            org.freedesktop.portal.Documents GetMountPoint >/dev/null
    '';
    filesToPatch = [ "nix-support/*" "share/applications/*.desktop" "share/wayland-sessions/*.desktop" ];
    patchHook = ''
        substitute ${desktop_launcher}/bin/start-desktop "$out/bin/start-desktop" \
            --replace-fail '@hyprland@' "$out"
        chmod +x "$out/bin/start-desktop"
    '';
    args = [ "--" "--config" hyprland_config "$@" ];
}).overrideAttrs (old: {
    meta = old.meta // { mainProgram = "Hyprland"; };
})
