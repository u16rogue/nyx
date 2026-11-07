#!/usr/bin/env bash
{{! THIS WAS WRITTEN BY A CLANKER: a proxy to cmake, every command is one native call with the args passed through }}
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

# configure <tree> [cmake args], only the first time. .clangd reads the compile commands of the last one
configure() {
    local tree="$1"
    shift
    if [[ ! -f ".build/$tree/build.ninja" ]]; then
        # the mingw toolchain in the devshell exports its own CC/CXX
        CC=clang CXX=clang++ cmake -S . -B ".build/$tree" -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON "$@" || return 1
    fi
    ln -sfn -- "$tree/compile_commands.json" .build/compile_commands.json
}

for dep in cmake ninja; do
    command -v "$dep" &> /dev/null || die "$dep is required, run this in the devshell"
done

cmd="${1:-}"
(( $# )) && shift
case "$cmd" in
    run|run-debug)     configure debug -DCMAKE_BUILD_TYPE=Debug && cmake --build .build/debug && exec ".build/debug/$name" "$@" ;;
    run-release)       configure release -DCMAKE_BUILD_TYPE=Release && cmake --build .build/release && exec ".build/release/$name" "$@" ;;
    build|build-debug) configure debug -DCMAKE_BUILD_TYPE=Debug && cmake --build .build/debug "$@" ;;
    build-release)     configure release -DCMAKE_BUILD_TYPE=Release && cmake --build .build/release "$@" ;;
    test)              configure debug -DCMAKE_BUILD_TYPE=Debug && cmake --build .build/debug && ctest --test-dir .build/debug --output-on-failure --no-tests=error "$@" ;;
    check)             configure debug -DCMAKE_BUILD_TYPE=Debug && find src -name '*.cc' -exec clang-tidy -p .build/debug --quiet "$@" {} + ;;
    lock)              none "the dependencies come from nixpkgs, there's nothing to lock" ;;
    dev)               none "cmake has no watch mode" ;;
    *)                 die "usage: ./do <run (run-debug)|run-release|build (build-debug)|build-release|test|check|lock|dev> [args]" ;;
esac
