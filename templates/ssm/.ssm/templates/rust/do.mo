#!/usr/bin/env bash
{{! a proxy to cargo, every command is one native call with the args passed through }}
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

command -v cargo &> /dev/null || die "cargo is required, run this in the devshell"

# the target dir is .build, set in .cargo/config.toml
cmd="${1:-}"
(( $# )) && shift
case "$cmd" in
    run|run-debug)     cargo run -- "$@" ;;
    run-release)       cargo run --release -- "$@" ;;
    build|build-debug) cargo build "$@" ;;
    build-release)     cargo build --release "$@" ;;
    test)              cargo test "$@" ;;
    check)             cargo fmt --check && cargo clippy --all-targets "$@" -- -D warnings ;;
    # after changing the dependencies in Cargo.toml, package.nix reads Cargo.lock.
    # only what changed is resolved again, `cargo update` is what bumps the versions
    lock)              cargo update --workspace "$@" ;;
    dev)               none "cargo has no watch mode" ;;
    *)                 die "usage: ./do <run (run-debug)|run-release|build (build-debug)|build-release|test|check|lock|dev> [args]" ;;
esac
