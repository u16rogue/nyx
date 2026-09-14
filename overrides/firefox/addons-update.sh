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
target="$directory/addons.nix"
temporary="$(mktemp "$directory/.addons.nix.XXXXXX")"
trap 'rm -f "$temporary"' EXIT

log "Reading addon list from $target."
{
    printf '{\n'
    while IFS= read -r addon; do
        log "Fetching $addon metadata from AMO."
        metadata="$(curl --fail --location --retry 3 --silent --show-error "https://addons.mozilla.org/api/v5/addons/addon/$addon/")"
        extid="$(jq --raw-output '.guid' <<< "$metadata")"
        version="$(jq --raw-output '.current_version.version' <<< "$metadata")"
        url="$(jq --raw-output '.current_version.file.url' <<< "$metadata")"
        sha256="$(jq --raw-output '.current_version.file.hash | split(":")[1]' <<< "$metadata")"

        log "Pinned $addon $version ($extid)."
        printf '    %s = {\n' "$addon"
        printf '        extid = "%s";\n' "$extid"
        printf '        version = "%s";\n' "$version"
        printf '        url = "%s";\n' "$url"
        printf '        sha256 = "%s";\n' "$sha256"
        printf '    };\n'
    done < <(nix eval --json --file "$target" --apply builtins.attrNames | jq --raw-output '.[]')
    printf '}\n'
} > "$temporary"

mv "$temporary" "$target"
log "Wrote $target."
