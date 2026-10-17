# THIS WAS WRITTEN BY A CLANKER
# Polls the latest `hosts.json` release published by `_nyx/release_hosts` and
# rebuilds from that exact commit only when this host's released system differs
# from the running one.
{
    flake.modules.nixos.auto-upgrade = { config, lib, pkgs, ... }: let
        repo = "u16rogue/nyx";
        # TODO: decide the apply mechanism; any `nixos-rebuild` operation works here.
        operation = "switch";
        host = config.networking.hostName;

        nyx-auto-upgrade = pkgs.writeShellApplication {
            name = "nyx-auto-upgrade";
            runtimeInputs = [ pkgs.curl pkgs.jq pkgs.coreutils config.system.build.nixos-rebuild ];
            text = /*bash*/ ''
                manifest_url="https://github.com/${repo}/releases/latest/download/hosts.json"
                attempted="''${STATE_DIRECTORY:-/var/lib/nyx-auto-upgrade}/attempted"

                manifest="$(curl -fsSL --retry 3 --max-time 60 "$manifest_url")"
                if ! entry="$(jq -ce --arg host ${lib.escapeShellArg host} '.hosts[$host] // empty' <<< "$manifest")"; then
                    echo "${host} is not listed in the latest release, nothing to do"
                    exit 0
                fi
                out_path="$(jq -r .outPath <<< "$entry")"
                rev="$(jq -r .rev <<< "$entry")"
                if [[ ! "$rev" =~ ^[0-9a-f]{40}$ || ! "$out_path" =~ ^/nix/store/[0-9a-z]{32}-[^/]+$ ]]; then
                    echo "malformed release entry: $entry" >&2
                    exit 1
                fi

                if [[ "$(readlink -f /run/current-system)" == "$out_path" ]]; then
                    echo "up to date with $rev"
                    exit 0
                fi
                # Attempt each release once; a failed or non-activating build waits for the next release.
                if [[ -f "$attempted" && "$(< "$attempted")" == "$rev $out_path" ]]; then
                    echo "$rev was already attempted, waiting for a newer release"
                    exit 0
                fi
                printf '%s %s\n' "$rev" "$out_path" > "$attempted"

                echo "upgrading to $rev ($out_path)"
                nixos-rebuild ${operation} --flake "github:${repo}/$rev#${host}"
            '' + lib.optionalString (operation == "switch") /*bash*/ ''

                if [[ "$(readlink -f /run/current-system)" != "$out_path" ]]; then
                    echo "warning: activated system differs from the released $out_path" >&2
                fi
            '';
        };
    in {
        systemd.services.nyx-auto-upgrade = {
            description = "Nyx upgrade from GitHub releases";
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            # Don't let the switch it performs restart or stop itself.
            restartIfChanged = false;
            unitConfig.X-StopOnRemoval = false;
            environment = config.nix.envVars // {
                inherit (config.environment.sessionVariables) NIX_PATH;
                HOME = "/root";
            } // config.networking.proxy.envVars;
            path = [ pkgs.gitMinimal config.nix.package.out ];
            serviceConfig = {
                Type = "oneshot";
                StateDirectory = "nyx-auto-upgrade";
                ExecStart = lib.getExe nyx-auto-upgrade;
            };
        };

        systemd.timers.nyx-auto-upgrade = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
                OnBootSec = "5min";
                OnCalendar = "hourly";
                RandomizedDelaySec = "10min";
                Persistent = true;
            };
        };
    };
}
