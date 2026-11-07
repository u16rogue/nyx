#!/usr/bin/env bash
{{! THIS WAS WRITTEN BY A CLANKER: a proxy to roc, every command is one native call with the args passed through }}
cd -- "$(dirname -- "${BASH_SOURCE[0]}")" || exit 1
name="{{subproject_name}}"

printErr() {
    printf '\033[37m[\033[91merr\033[37m]\033[0m %s\n' "$1" >&2
}

printLog() {
    printf '\033[37m[log]\033[0m %s\n' "$1" >&2
}

die() {
    printErr "$1"
    exit 1
}

# for the standard commands this project has no equivalent of
none() {
    die "./do $cmd isn't available here, $1"
}

# roc <args>, roc exits with 2 if there were only warnings
rocOk() {
    roc "$@"
    local rc=$?
    (( rc == 0 || rc == 2 ))
}

# rocBuild <output> [roc build args]
rocBuild() {
    local output="$1"
    shift
    mkdir -p -- "$(dirname -- "$output")" && rocOk build main.roc --output="$output" "$@"
}

# roc has no lock of its own, package.nix fetches every package url of main.roc with its sha256
# from roc.lock.json. locked urls keep their hash
lock() {
    command -v curl &> /dev/null || die "curl is required, run this in the devshell"
    local deps url hash sep=""
    local -a urls=()
    mkdir -p .build && deps="$(roc deps main.roc)" || return 1
    mapfile -t urls < <(grep -oE 'https://[^ ]+' <<< "$deps")
    {
        printf '['
        for url in "${urls[@]}"; do
            hash="$(awk -v url="$url" -F '"' '$4 == url { print $8 }' roc.lock.json 2> /dev/null)"
            if [[ -z "$hash" ]]; then
                curl -sSfL -o .build/package -- "$url" && hash="$(sha256sum < .build/package)" || return 1
                hash="${hash%% *}"
            fi
            printf '%s\n  { "url": "%s", "sha256": "%s" }' "$sep" "$url" "$hash"
            sep=","
        done
        printf '\n]\n'
    } > .build/roc.lock.json && mv -f -- .build/roc.lock.json roc.lock.json && printLog "locked ${#urls[@]} packages"
}

command -v roc &> /dev/null || die "roc is required, run this in the devshell"

cmd="${1:-}"
(( $# )) && shift
case "$cmd" in
    run|run-debug)     rocBuild ".build/debug/$name" --opt=dev --debug && exec ".build/debug/$name" "$@" ;;
    run-release)       rocBuild ".build/release/$name" --opt=speed && exec ".build/release/$name" "$@" ;;
    build|build-debug) rocBuild ".build/debug/$name" --opt=dev --debug "$@" ;;
    build-release)     rocBuild ".build/release/$name" --opt=speed "$@" ;;
    test)              rocOk test main.roc "$@" ;;
    check)             rocOk check main.roc "$@" ;;
    # after changing the packages in main.roc
    lock)              lock ;;
    dev)               none "roc has no watch mode" ;;
    *)                 die "usage: ./do <run (run-debug)|run-release|build (build-debug)|build-release|test|check|lock|dev> [args]" ;;
esac
