# THIS WAS WRITTEN BY A CLANKER
# Polls the latest `hosts.json` published by `_nyx/release_hosts` and rebuilds
# from that exact commit only when this host's released system differs from the
# running one.
#
# Sources are tried in order; the first one with a valid entry for this host is
# used. Every source can deploy any system as root, so only list trusted ones.
{
    flake.modules.nixos.auto-upgrade = { config, lib, pkgs, ... }: let
        cfg = config.nyxos.auto-upgrade;
        hostname = config.networking.hostName;
        stateDir = "/var/lib/nyx-auto-upgrade";
        # Each source resolves to a name, a bash snippet printing its latest
        # `hosts.json`, and a flake ref where `@rev@` is replaced by the release rev.
        resolve = i: source:
            if source ? git then let inherit (source.git) url branch flake; dir = ''"$tmp/source_${toString i}"''; in {
                name = "git:${url}#${branch}";
                fetch = /*bash*/ ''
                    "''${git_cmd[@]}" init --quiet ${dir} \
                        && "''${git_cmd[@]}" -C ${dir} fetch --quiet --depth=1 --no-tags ${lib.escapeShellArgs [ url "refs/heads/${branch}" ]} \
                        || return 1
                    "''${git_cmd[@]}" -C ${dir} show FETCH_HEAD:hosts.json 2> /dev/null \
                        || { echo ${lib.escapeShellArg "${branch} has no hosts.json"} >&2; return 1; }
                '';
                inherit flake;
            }
            else if source ? github-releases then let inherit (source.github-releases) repo; in {
                name = "github-releases:${repo}";
                fetch = /*bash*/ ''"''${curl_cmd[@]}" ${lib.escapeShellArg "https://github.com/${repo}/releases/latest/download/hosts.json"}'';
                flake = "github:${repo}/@rev@";
            }
            else if source ? forgejo-releases then let inherit (source.forgejo-releases) url repo; in {
                name = "forgejo-releases:${url}/${repo}";
                fetch = /*bash*/ ''
                    local release asset
                    release="$("''${curl_cmd[@]}" ${lib.escapeShellArg "${url}/api/v1/repos/${repo}/releases/latest"})" || return 1
                    asset="$(jq -re 'first(.assets[] | select(.name == "hosts.json") | .browser_download_url)' <<< "$release" 2> /dev/null)" \
                        || { echo "latest release has no hosts.json asset" >&2; return 1; }
                    "''${curl_cmd[@]}" "$asset"
                '';
                flake = "git+${url}/${repo}?rev=@rev@";
            }
            else throw "nyxos.auto-upgrade: unknown source ${builtins.toJSON source}"
        ;
        sources = lib.imap1 resolve cfg.sources;
        # Shared by both scripts, which set the `curl_cmd` and `git_cmd` arrays first.
        # `latest` sets `rev`, `out_path`, `flake` and `source` from the first source with a valid entry for this host,
        # and `reasons` to why each source before it (or every source, on failure) was unusable.
        latest = /*bash*/ ''
            tmp="$(mktemp -d)"
            trap 'rm -rf -- "$tmp"' EXIT
            fetch_log="$tmp/fetch.log"
            entry_rev="" entry_out="" reason="" reasons=()
            export GIT_TERMINAL_PROMPT=0

            # Explains a failed fetch from what it printed to stderr: git's first `fatal:` line, otherwise the last line.
            fetch_error() {
                local line message=""
                while IFS= read -r line; do
                    if [[ "$line" == "fatal: "* ]]; then
                        message="$line"
                        break
                    fi
                    [[ -n "''${line//[[:space:]]/}" ]] && message="$line"
                done < "$fetch_log"
                message="''${message#curl: }"
                message="''${message#fatal: }"
                case "$message" in
                    *"error: 404"*) echo "no published release with hosts.json (404, drafts don't count)" ;;
                    *"couldn't find remote ref"*) echo "branch not found" ;;
                    *"could not read Username"* | *"Repository not found"* | *"does not appear to be a git repository"*)
                        echo "repository not found (or not public)" ;;
                    "") echo "fetch failed (or timed out)" ;;
                    *) echo "$message" ;;
                esac
            }

            # Sets `entry_rev` and `entry_out` from this host's entry in a source's manifest, or `reason` on failure.
            host_entry() {
                local manifest entry
                if ! manifest="$("$1" 2> "$fetch_log")"; then
                    reason="$(fetch_error)"
                    return 1
                fi
                if ! jq -e 'type == "object"' > /dev/null 2>&1 <<< "$manifest"; then
                    reason="hosts.json is not a JSON object"
                    return 1
                fi
                if ! entry="$(jq -ce --arg host ${lib.escapeShellArg hostname} '.hosts[$host]? // empty' <<< "$manifest")"; then
                    reason="${hostname} is not in hosts.json"
                    return 1
                fi
                entry_out="$(jq -r .outPath <<< "$entry")"
                entry_rev="$(jq -r .rev <<< "$entry")"
                if [[ ! "$entry_rev" =~ ^[0-9a-f]{40}$ || ! "$entry_out" =~ ^/nix/store/[0-9a-z]{32}-[^/]+$ ]]; then
                    reason="malformed entry for ${hostname}: $entry"
                    return 1
                fi
            }

            ${lib.concatImapStringsSep "\n" (i: source: /*bash*/ ''
                source_${toString i}() {
                    ${source.fetch}
                }
            '') sources}

            source_names=(${lib.escapeShellArgs (map (source: source.name) sources)})
            source_flakes=(${lib.escapeShellArgs (map (source: source.flake) sources)})

            # shellcheck disable=SC2034 # results are for the caller, which may not use all of them
            latest() {
                local i
                rev="" out_path="" flake="" source="" reasons=()
                for i in "''${!source_names[@]}"; do
                    if host_entry "source_$((i + 1))"; then
                        rev="$entry_rev" out_path="$entry_out"
                        flake="''${source_flakes[i]//@rev@/$rev}"
                        source="''${source_names[i]}"
                        return 0
                    fi
                    reasons+=("''${source_names[i]}: $reason")
                done
                return 1
            }
        '';

        nyx-what-version = pkgs.writeShellApplication {
            name = "nyx-what-version";
            runtimeInputs = [ pkgs.curl pkgs.gitMinimal pkgs.jq pkgs.coreutils ];
            text = /*bash*/ ''
                # The rev is resolved from `nyx-auto-upgrade`'s state and the latest release since the
                # system itself doesn't embed it (that would change every host's outPath on every commit).
                # shellcheck disable=SC2034 # only used by the sources that need them
                curl_cmd=(curl -fsSL --max-time 15) git_cmd=(timeout 15 git)
                ${latest}

                current="$(readlink -f /run/current-system)"
                running=""
                if [[ -r ${stateDir}/attempted ]]; then
                    read -r attempted_rev attempted_out < ${stateDir}/attempted || true
                    if [[ "''${attempted_out:-}" == "$current" ]]; then
                        running="$attempted_rev"
                    fi
                fi

                latest_rev=""
                if latest; then
                    latest_rev="$rev"
                    if [[ -z "$running" && "$out_path" == "$current" ]]; then
                        running="$rev"
                    fi
                fi

                echo "host:   ${hostname}"
                echo "system: $current"
                echo "rev:    ''${running:-unknown (not a released system)}"
                if [[ -z "$latest_rev" ]]; then
                    printf -v why '%s; ' "''${reasons[@]}"
                    echo "latest: unavailable (''${why%; })"
                elif [[ "$running" == "$latest_rev" ]]; then
                    echo "latest: $latest_rev (up to date, from $source)"
                else
                    echo "latest: $latest_rev (not running it, from $source)"
                fi
            '';
        };

        nyx-auto-upgrade = pkgs.writeShellApplication {
            name = "nyx-auto-upgrade";
            runtimeInputs = [ pkgs.curl pkgs.gitMinimal pkgs.jq pkgs.coreutils config.system.build.nixos-rebuild ];
            text = /*bash*/ ''
                attempted="''${STATE_DIRECTORY:-${stateDir}}/attempted"
                # shellcheck disable=SC2034 # only used by the sources that need them
                curl_cmd=(curl -fsSL --retry 3 --max-time 60) git_cmd=(timeout 60 git)
                ${latest}

                if ! latest; then
                    printf '%s\n' "''${reasons[@]}" >&2
                    echo "no source has a usable release for ${hostname}, nothing to do"
                    exit 0
                fi
                if [[ "''${#reasons[@]}" -gt 0 ]]; then
                    printf 'skipped %s\n' "''${reasons[@]}" >&2
                fi
                echo "using $source"

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
                nixos-rebuild ${cfg.operation} --flake "$flake#${hostname}"
            '' + lib.optionalString (builtins.elem cfg.operation [ "switch" "test" ]) /*bash*/ ''

                if [[ "$(readlink -f /run/current-system)" != "$out_path" ]]; then
                    echo "warning: activated system differs from the released $out_path" >&2
                fi
            '';
        };
    in {
        options.nyxos.auto-upgrade.operation = lib.mkOption {
            description = ''
                `nixos-rebuild` operation applied to a new release: `switch` activates it now, `boot` on the
                next reboot, `test` now without making it the boot default, `build` only builds it.
            '';
            type = lib.types.enum [ "switch" "boot" "test" "build" ];
            default = "switch";
        };

        options.nyxos.auto-upgrade.schedule = {
            onBoot = lib.mkOption {
                description = "How long after boot to first check, as a systemd time span (`OnBootSec`). `null` to not check on boot.";
                type = lib.types.nullOr lib.types.str;
                default = "5min";
            };
            onCalendar = lib.mkOption {
                description = "When to check, as a systemd calendar event (`OnCalendar`). Missed runs are caught up after downtime.";
                type = lib.types.str;
                default = "hourly";
                example = "*-*-* 04:00:00";
            };
            randomizedDelay = lib.mkOption {
                description = "Random delay added to each check, as a systemd time span (`RandomizedDelaySec`).";
                type = lib.types.str;
                default = "10min";
            };
        };

        options.nyxos.auto-upgrade.sources = lib.mkOption {
            description = "Where to poll `hosts.json` from, in order of preference.";
            type = lib.types.nonEmptyListOf (lib.types.attrTag {
                git = lib.mkOption {
                    description = "`hosts.json` at the tip of a branch in any git repository (eg. a separate release repository).";
                    type = lib.types.submodule ({ config, ... }: {
                        options.url = lib.mkOption {
                            description = "Repository to fetch, any URL `git fetch` accepts. Needs to be readable without credentials.";
                            type = lib.types.str;
                            example = "https://github.com/user/nyx-release.git";
                        };
                        options.branch = lib.mkOption {
                            description = "Branch whose `hosts.json` is the latest release.";
                            type = lib.types.str;
                            default = "main";
                        };
                        options.flake = lib.mkOption {
                            description = "Flake to rebuild from, `@rev@` is replaced by the released rev. Defaults to `url` itself, which only fits when the releases live in the code repository.";
                            type = lib.types.strMatching ".*@rev@.*";
                            default = "git+${config.url}?rev=@rev@";
                            defaultText = lib.literalExpression ''"git+''${url}?rev=@rev@"'';
                            example = "github:user/nyx/@rev@";
                        };
                    });
                };
                github-releases = lib.mkOption {
                    description = "The latest GitHub release's `hosts.json` asset; also the flake that is rebuilt from.";
                    type = lib.types.submodule {
                        options.repo = lib.mkOption { type = lib.types.str; example = "user/nyx"; };
                    };
                };
                forgejo-releases = lib.mkOption {
                    description = "The latest Forgejo (or Gitea) release's `hosts.json` asset; also the flake that is rebuilt from.";
                    type = lib.types.submodule {
                        options.url = lib.mkOption { type = lib.types.strMatching "https?://[^/]+"; example = "https://git.example.com"; };
                        options.repo = lib.mkOption { type = lib.types.str; example = "user/nyx"; };
                    };
                };
            });
            example = [
                { git = { url = "https://github.com/user/nyx-release.git"; flake = "github:user/nyx/@rev@"; }; }
                { forgejo-releases = { url = "https://git.example.com"; repo = "user/nyx"; }; }
                { github-releases.repo = "user/nyx"; }
            ];
        };

        config = {
            environment.systemPackages = [ nyx-what-version ];

            systemd.services.nyx-auto-upgrade = {
                description = "Nyx upgrade from published releases";
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
                    OnCalendar = cfg.schedule.onCalendar;
                    RandomizedDelaySec = cfg.schedule.randomizedDelay;
                    Persistent = true;
                } // lib.optionalAttrs (cfg.schedule.onBoot != null) {
                    OnBootSec = cfg.schedule.onBoot;
                };
            };
        };
    };
}
