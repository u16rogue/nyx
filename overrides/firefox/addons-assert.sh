#!/usr/bin/env bash
set -euo pipefail

log() {
    printf '[firefox addons] %s\n' "$*" >&2
}

for package in dirname realpath nix jq; do
    if ! command -v "$package" &> /dev/null; then
        log "'$package' is required."
        exit 1
    fi
done

script="$(realpath "${BASH_SOURCE[0]}")"
directory="$(dirname "$script")"
target="$directory/addons/addons.nix"

declare -A addon_names
while IFS= read -r addon; do
    addon_names["$addon"]=1
done < <(nix eval --json --file "$target" --apply builtins.attrNames | jq --raw-output '.[]')

valid=true
for path in "$directory/addons"/*/; do
    addon="${path%/}"
    addon="${addon##*/}"
    if [[ ! ${addon_names[$addon]+_} ]]; then
        log "'$addon' has a directory but no entry in $target."
        valid=false
    fi
done

if ! "$valid"; then
    exit 1
fi

log "Addon directories match $target."
