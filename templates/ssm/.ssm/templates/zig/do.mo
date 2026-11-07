#!/usr/bin/env bash
{{! THIS WAS WRITTEN BY A CLANKER: a proxy to zig build, every command is one native call with the args passed through }}
cd -- "$(dirname -- "${BASH_SOURCE[0]}")" || exit 1

printErr() {
    printf '\033[37m[\033[91merr\033[37m]\033[0m %s\n' "$1" >&2
}

die() {
    printErr "$1"
    exit 1
}

command -v zig &> /dev/null || die "zig is required, run this in the devshell"

cmd="${1:-}"
(( $# )) && shift
case "$cmd" in
    run|run-debug)     zig build run --prefix .build/debug -- "$@" ;;
    run-release)       zig build run --prefix .build/release -Doptimize=ReleaseSafe -- "$@" ;;
    build|build-debug) zig build --prefix .build/debug "$@" ;;
    build-release)     zig build --prefix .build/release -Doptimize=ReleaseSafe "$@" ;;
    test)              zig build test --summary all "$@" ;;
    check)             zig fmt --check build.zig build.zig.zon src && zig build check "$@" ;;
    # after changing the dependencies in build.zig.zon, package.nix reads build.zig.zon.nix
    lock)              mkdir -p .build && zon2nix build.zig.zon > .build/lock.nix && mv -f -- .build/lock.nix build.zig.zon.nix ;;
    dev)               zig build run --watch --prefix .build/debug -- "$@" ;;
    *)                 die "usage: ./do <run (run-debug)|run-release|build (build-debug)|build-release|test|check|lock|dev> [args]" ;;
esac
