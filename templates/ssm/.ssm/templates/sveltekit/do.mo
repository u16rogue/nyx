#!/usr/bin/env bash
{{! THIS WAS WRITTEN BY A CLANKER: a proxy to the vite scripts in package.json, every command is one native call with the args passed through }}
cd -- "$(dirname -- "${BASH_SOURCE[0]}")" || exit 1
# adapter-bun's buildOptions for `build-compile`, package.nix overrides them through ADAPTER_BUILD_OPTIONS
compile_options='{"compile":true,"bytecode":true}'

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

command -v bun &> /dev/null || die "bun is required, run this in the devshell"

# vite.config.ts reads ADAPTER_OUT and ADAPTER_BUILD_OPTIONS
cmd="${1:-}"
(( $# )) && shift
case "$cmd" in
    run|run-debug|dev)         bun run --bun dev "$@" ;;
    run-release)               ADAPTER_OUT=.build/bundle ADAPTER_BUILD_OPTIONS='{}' bun run --bun build && exec bun .build/bundle/index.js "$@" ;;
    build-debug|build-release) none "vite has no debug/release split, use build-bundle or build-compile" ;;
    build|build-bundle)        ADAPTER_OUT=.build/bundle ADAPTER_BUILD_OPTIONS='{}' bun run --bun build "$@" ;;
    build-compile)             ADAPTER_OUT=.build/compile ADAPTER_BUILD_OPTIONS="${ADAPTER_BUILD_OPTIONS:-$compile_options}" bun run --bun build "$@" ;;
    test)                      none "there's no test runner yet, add vitest with \`bunx sv add vitest\` and point ./do test at it" ;;
    check)                     bun run --bun check "$@" ;;
    # the postinstall regenerates bun.lock.nix
    lock)                      bun install "$@" ;;
    *)                         die "usage: ./do <run (run-debug, dev)|run-release|build (build-bundle)|build-compile|test|check|lock> [args]" ;;
esac
