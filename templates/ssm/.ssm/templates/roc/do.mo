#!/usr/bin/env bash
{{! THIS WAS WRITTEN BY A CLANKER: a proxy to roc, every command is one native call with the args passed through }}
cd -- "$(dirname -- "${BASH_SOURCE[0]}")" || exit 1
name="{{subproject_name}}"

printErr() {
    printf '\033[37m[\033[91merr\033[37m]\033[0m %s\n' "$1" >&2
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
    lock)              none "the builtin platform has no packages to lock" ;;
    dev)               none "roc has no watch mode" ;;
    *)                 die "usage: ./do <run (run-debug)|run-release|build (build-debug)|build-release|test|check|lock|dev> [args]" ;;
esac
