# CLANKER EDITED FILE: whole file
{ inputs, pkgs, lib, mako, wlr-randr, jq, overridesOpts ? {}, ... }: let
    # A host monitor entry (`{ id }` or `{ edid }`, see `nyx.nixos.hosts.<name>.monitors`) to pin notifications to.
    # null leaves it to mako, which shows them on the focused output.
    monitor = overridesOpts.monitor or null;
    edid = if monitor == null then null else monitor.edid or null;
    id = if monitor == null then null else monitor.id or null;
in inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = mako;
    env.FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.comfortaa ]; };
    flags = { "--config" = "${./config}"; } // lib.optionalAttrs (id != null) { "--output" = id; };
    # mako only matches `output` against the connector name, so an EDID is resolved to it at startup.
    # If the monitor isn't connected nothing is pinned.
    preHook = lib.optionalString (edid != null) /*bash*/ ''
        output="$(${wlr-randr}/bin/wlr-randr --json | ${jq}/bin/jq -r \
            --arg make ${lib.escapeShellArg edid.make} \
            --arg model ${lib.escapeShellArg edid.model} \
            --arg serial ${lib.escapeShellArg (if (edid.serial or null) == null then "" else edid.serial)} \
            '[.[] | select(.make == $make and .model == $model and ($serial == "" or .serial == $serial)) | .name][0] // ""' \
        || true)"
        if [[ -n "$output" ]]; then set -- --output "$output" "$@"; fi
    '';
    # Keep D-Bus/systemd activation on the wrapper instead of the bare binary.
    filesToPatch = [ "share/dbus-1/services/*.service" "share/systemd/user/*.service" ];
}
