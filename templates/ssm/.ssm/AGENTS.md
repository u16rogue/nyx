# Environment
* You are most likely running in a constructed sandbox environment. You can check the env `NYX_SBX_ID` as a ***hint*** if you're in one.
    * Do not rely on the information in the environment itself as the sandbox uses `bwrap --unshare-all` and reconstructs what it needs. Hostname, `/etc`, installed tools, network, the nix store and service states may not reflect the host.
    * Always take note of this especially on diagnosing. Never draw conclusions about the host from what you see in the sandbox.
* You must notify the user if you need something from the host
* If you need something create a bash script in `.nyx-sbx/share` with an appropriate name
    * This script should write its output to a log in `.nyx-sbx/share` named after the script (`foo.sh` writes `foo.log`) for you to read back since you can't run it yourself
    * It must be concise and easy to read to be reviewed
    * It must only gather information unless the user explicitly asked for changes on the host
    * Wait for the user to run it, do not guess its result

# Remote machines
* When you are asked to diagnose a remote machine remember that you can offer to generate a keypair and offer your public key. Serve it as a one liner that can be run in a shell and ensure that this access expires in a few minutes or as appropriate to the requested operation (e.g. `expiry-time="YYYYMMDDHHMM"` in `authorized_keys`).

# Code Style
* Functions and methods are camel case. (eg. `treeAppend`)
* Prefer noun verb for functions `arrayPush(&array, elem)` as it mirrors `array.push` and it simplified regex lookups.
* Types are pascal case. (eg. `FlatArray`)
* Variables and members are snake case (eg. `array_of_elems`)
* Always minimize scope by localizing it to where its used. A scope that doesn't use it should not have it in the first place.
    ```c
    // DO NOT
    void main() {
        int x;
        int y;
        // use x
        // ... a bunch of code ...
        // use y
    }

    // DO
    void main() {
        int x;
        // use x
        // ... a bunch of code ...
        int y;
        // use y
    }
    ```

# Disclosure
* When you're writing anything important (code, configs, scripts) you are REQUIRED to add disclosure that it's written by you, a clanker. Use the comment syntax of the language you're writing in.
    * `CLANKER START/END`: wraps a block you wrote
    * `CLANKER ASSISTED`: lines you added into existing code
    * `CLANKER EDITED`: code the user wrote that you modified, describe what changed
    * `ASSISTED` and `EDITED` cover the lines directly below them up to the next blank line. If you removed lines mention it in the description.
* The example below is shown as a diff to illustrate when to use each marker: `+` added, `-` removed, `~` modified. Do NOT write these prefixes into actual files. Assume the prompt was "<thing> is necessary for bar but its setup is tedious, can you add a stub that automatically does <thing> instead of just exiting?"
    ```diff
    + # CLANKER START <short_slug_topic>: implement the foo function that sets up <thing>
    + foo() {
    +     # ...
    + }
    + # CLANKER END <short_slug_topic>

    + # CLANKER ASSISTED: setup <thing> with foo instead of exiting, removed the die
    - [[ ! -f "thing" ]] && die "you dont have thing (todo)"
    + [[ ! -f "thing" ]] && foo "parameters"

    + # CLANKER EDITED: pass the result of foo to bar
    ~ bar "more parameters and bash operation" "$foo_result"
    ```
* If you wrote the entire file put `# THIS WAS WRITTEN BY A CLANKER` at the top instead

# Dependencies
* If you need a quick dependency or a package for something specific always use the project's flake nixpkgs instead of ad-hoc sourcing it yourself. It is important to use the same nixpkgs as the project's flake you're in not only for cache but for reproducibility.
    * `nix run --inputs-from . nixpkgs#<package>` when you need the package's main program
    * `nix shell --inputs-from . nixpkgs#<package> [nixpkgs#<other>...] --command <cmd>` when the command isn't the main program or you need multiple packages
* If this is a dependency that should actually be part of the project notify the user, otherwise if it's a one off then this is better.

# Bash scripts
* When implementing bash scripts always write them into self sustaining units (a single file that doesn't source external helpers and sets up what it needs itself)
* Use these for logging
    ```bash
    printErr() {
        printf '\033[37m[\033[91merr\033[37m]\033[0m %s\n' "$1" >&2
    }

    printWarn() {
        printf '\033[37m[\033[93mwarn\033[37m]\033[0m %s\n' "$1" >&2
    }

    printLog() {
        printf '\033[37m[log]\033[0m %s\n' "$1" >&2
    }

    die() {
        printErr "$1"
        exit 1
    }
    ```
* Always check hard dependencies are available such as `if ! command -v "git" &> /dev/null; then die "git is required"; fi`
* Scripts must stay usable without nix. Nix is only a hard dependency when the script is explicitly about nix, otherwise it's just a convenience for acquiring missing dependencies.
* Always check soft dependencies and aggregate them. If any are unavailable rerun the script itself once in a nix shell with all of them. Guard against looping and forward the arguments.
    * Never assume experimental features are enabled, always pass `--extra-experimental-features 'nix-command flakes'` since `nix shell` and `--inputs-from` are not available by default.
    * If nix isn't available, die with the list of missing commands so non nix users know what to install.
    ```bash
    script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    missing_cmds=()
    missing_pkgs=()
    if ! command -v "hello" &> /dev/null; then missing_cmds+=("hello"); missing_pkgs+=("nixpkgs#hello"); fi
    if ! command -v "jq" &> /dev/null; then missing_cmds+=("jq"); missing_pkgs+=("nixpkgs#jq"); fi
    if (( ${#missing_cmds[@]} )); then
        if [[ -n "${_SOFTDEPS_REEXEC:-}" ]]; then die "still missing after nix shell: ${missing_cmds[*]}"; fi
        if ! command -v "nix" &> /dev/null; then die "missing dependencies, please install: ${missing_cmds[*]}"; fi
        printWarn "missing ${missing_cmds[*]}, rerunning in a nix shell"
        _SOFTDEPS_REEXEC=1 exec nix --extra-experimental-features 'nix-command flakes' shell --inputs-from "$script_dir" "${missing_pkgs[@]}" --command "${BASH_SOURCE[0]}" "$@"
    fi
    ```

# Version Control
* Prefer `jj` (jujutsu) over `git` if it's available.
* With `jj`, treat the working copy (`@`) as staging: don't commit it wholesale, instead split specific changes out of it into focused commits below `@`, like `jj split` does (`jj into <change> [paths]`, `jj imbue <change> [paths]` to pick hunks). The target must be an ancestor of `@` so the change stays visible in the working copy; only `@`'s own diff shrinks. Never squash into a commit outside `@`'s ancestry unless told to. `jj todo "msg"` inserts a placeholder change directly below `@` for this, it stays private (unpushable) until `jj done <change>`.
* NEVER DO VERSION CONTROL OPERATIONS (`git` OR `jj`) UNLESS YOU'RE **EXPLICITLY** TOLD SO. Read-only commands (`status`, `log`, `diff`, `show`) are fine.
* NEVER GLOB THE UNIGNORE. These project(s) intentionally use explicit inverse ignore which means EVERYTHING is ignored by default and specific files are then unignored. The only exception is when it comes to obviously globbed directories such as source directories, if unsure always ask.
    * Remember that git can't re-include a file if its parent directory is ignored, so globbed directories also need their subdirectories unignored (`!src/**/`)
    * .gitignore
    ```
    **
    .*
    !.gitignore
    !build.zig
    !src/
    # This makes sense because in this context `src` is expected to only contain zig source code
    !src/**/
    !src/**/*.zig
    # This folder despite having a similar role is not "predictable" and hence should NOT be globbed, it gets its own .gitignore listing every file
    !assets/
    # Same kind of content as `src`, but it's a small fixed set of files, so list them explicitly instead of globbing
    !scripts/
    !scripts/setup.sh
    !scripts/deploy.sh
    ```
    * assets/.gitignore
    ```
    **
    .*
    !.gitignore
    !foo.svg
    !bar.svg
    ```
