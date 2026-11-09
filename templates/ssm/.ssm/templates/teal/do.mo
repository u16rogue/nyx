#!/usr/bin/env bash
{{! THIS WAS WRITTEN BY A CLANKER: a proxy to cyan/lua, every command is one native call with the args passed through }}
cd -- "$(dirname -- "${BASH_SOURCE[0]}")" || exit 1

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

# runs the compiled entry point, the build dir comes first so its modules win over the lua env's
luaRun() {
    LUA_PATH="./.build/lua/?.lua;./.build/lua/?/init.lua;${LUA_PATH:-;}" lua .build/lua/main.lua "$@"
}

command -v cyan &> /dev/null || die "cyan is required, run this in the devshell"
command -v lua &> /dev/null || die "lua is required, run this in the devshell"

cmd="${1:-}"
(( $# )) && shift
case "$cmd" in
    # lua has no separate debug/release output, both map to the same build
    run|run-debug|run-release)       cyan build && luaRun "$@" ;;
    build|build-debug|build-release) cyan build "$@" ;;
    test)                            none "teal has no test runner, add busted to package.nix's lua env if you need one" ;;
    check)                           shopt -s globstar && cyan check src/**/*.tl "$@" ;;
    lock)                            none "lua dependencies come from nixpkgs, add them to package.nix's lua env" ;;
    dev)                             none "cyan has no watch mode" ;;
    *)                               die "usage: ./do <run (run-debug)|run-release|build (build-debug)|build-release|test|check|lock|dev> [args]" ;;
esac
