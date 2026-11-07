#!/usr/bin/env bash
{{! THIS WAS WRITTEN BY A CLANKER: a proxy to bun, every command is one native call with the args passed through }}
cd -- "$(dirname -- "${BASH_SOURCE[0]}")" || exit 1
name="{{subproject_name}}"
entry="index.ts"

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

cmd="${1:-}"
(( $# )) && shift
case "$cmd" in
    run|run-debug)             bun run "$entry" "$@" ;;
    run-release)               bun build "$entry" --outdir .build/bundle --entry-naming "$name.[ext]" --target=bun --production --sourcemap=linked && exec bun ".build/bundle/$name.js" "$@" ;;
    build-debug|build-release) none "bun has no debug/release split, use build-bundle or build-compile" ;;
    # `--outfile` loses its directory with linked sourcemaps
    build|build-bundle)        bun build "$entry" --outdir .build/bundle --entry-naming "$name.[ext]" --target=bun --production --sourcemap=linked "$@" ;;
    build-compile)             bun build "$entry" --outfile ".build/compile/$name" --compile --minify --sourcemap "$@" ;;
    test)                      bun test "$@" ;;
    check)                     bun x tsc --noEmit "$@" ;;
    # the postinstall regenerates bun.lock.nix
    lock)                      bun install "$@" ;;
    dev)                       bun --watch run "$entry" "$@" ;;
    *)                         die "usage: ./do <run (run-debug)|run-release|build (build-bundle)|build-compile|test|check|lock|dev> [args]" ;;
esac
