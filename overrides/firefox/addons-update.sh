#!/usr/bin/env bash
# clanker generated
set -euo pipefail

log() {
    printf '[firefox addons] %s\n' "$*" >&2
}

if ! command -v nix &> /dev/null; then
    log "Nix is unavailable; nothing to do."
    exit 0
fi

script="$(realpath "${BASH_SOURCE[0]}")"
for package in bash dirname mktemp realpath curl jq; do
    if ! command -v "$package" &> /dev/null; then
        log "'$package' is unavailable; starting a Nix shell."
        exec nix shell nixpkgs#bash nixpkgs#coreutils nixpkgs#curl nixpkgs#jq --command bash "$script" "$@"
    fi
done

directory="$(dirname "$script")"
target="$directory/addons/addons.nix"

log "Reading addon list from $target."
if ! addon_names="$(nix eval --json --file "$target" --apply builtins.attrNames | jq --raw-output '.[]')"; then
    log "Failed to evaluate addon names; leaving $target unchanged."
    exit 1
fi
if [[ -z "$addon_names" ]]; then
    log "Refusing to replace $target with an empty addon set."
    exit 1
fi

temporary="$(mktemp "$directory/.addons.nix.XXXXXX")"
trap 'rm -f "$temporary"' EXIT
{
    printf '{\n'
    while IFS= read -r addon; do
        log "Fetching $addon metadata from AMO."
        metadata="$(curl --fail --location --retry 3 --silent --show-error "https://addons.mozilla.org/api/v5/addons/addon/$addon/")"
        if ! jq -e '
            (.guid | type == "string" and length > 0)
            and (.current_version.version | type == "string" and length > 0)
            and (.current_version.file.url | type == "string" and test("^https://"))
            and (.current_version.file.hash | type == "string" and test("^sha256:[0-9a-fA-F]{64}$"))
        ' <<< "$metadata" > /dev/null; then
            log "AMO returned incomplete metadata for $addon."
            exit 1
        fi
        extid="$(jq --raw-output '.guid | @json' <<< "$metadata")"
        version="$(jq --raw-output '.current_version.version | @json' <<< "$metadata")"
        url="$(jq --raw-output '.current_version.file.url | @json' <<< "$metadata")"
        sha256="$(jq --raw-output '.current_version.file.hash | split(":")[1] | @json' <<< "$metadata")"

        log "Pinned $addon metadata."
        printf '    %s = {\n' "$addon"
        printf '        extid = %s;\n' "$extid"
        printf '        version = %s;\n' "$version"
        printf '        url = %s;\n' "$url"
        printf '        sha256 = %s;\n' "$sha256"
        printf '    };\n'
    done <<< "$addon_names"
    printf '}\n'
} > "$temporary"

mv "$temporary" "$target"
log "Wrote $target."
