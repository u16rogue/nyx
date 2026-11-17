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
* What you write is disclosed through version control. The final result of your work is always a clanker change: a `!clanker! <msg>` commit of its own directly below `@` with an `Assisted-by: <your model name>` trailer, holding everything you wrote and nothing else. Nothing you wrote is left in `@`'s own diff.
    * It's an ancestor of `@` so the user still sees your work in the working copy, and `jj show <change>` is their reference for what you did.
    * It stays private (unpushable) until the user releases it.
    * `<msg>` is a normal commit message for what the change does, the user reads it in the log.
* How you get there is up to you, only the result counts:
    * Run `jj clank-start "<msg>" "<your model name>"` before your first edit, it puts the change on top of `@` so everything edited from then on lands in it. Run `jj clank-finish` when you're done editing, it moves the change below the user's working copy and makes theirs `@` again. If it says the change was left on top, leave it there and tell the user.
    * Or edit in `@` and split it out afterwards with `jj clank-split "<msg>" "<your model name>" <paths>...`. It moves everything `@` changed in those paths, so only give it paths where all of `@`'s changes are yours. If a path also has uncommitted edits of the user, don't guess, tell the user which files are mixed.
    * Check `jj status` before you edit. If `@` already has changes in files you're about to touch, use the first way.
* A new task gets a new clanker change, don't add to one from an earlier task.
* Tell the user the change id when you're done.
* Releasing it is the user's review. Never run `jj reviewed`, never remove the `!clanker! ` prefix or the `Assisted-by` trailer, never squash a clanker change into another change and never push.
* The `jj clank-*` aliases are the only version control you run on your own. If they don't exist or it isn't a `jj` repo, run nothing and tell the user that what you wrote is sitting undisclosed in the working copy.
* The example below is what the user should be left with. Assume the prompt was "<thing> is necessary for bar but its setup is tedious, can you add a stub that automatically does <thing> instead of just exiting?" while they had their own uncommitted work in `@`.
    ```
    $ jj log
    @  kxwzmtlp user@mail 2026-01-01 12:00:00 3f1c9a2e
    │  (no description set)
    ○  rmquqtvr user@mail 2026-01-01 12:00:00 1725417d
    │  !clanker! setup: do <thing> with foo instead of exiting
    ○  wtnutmwz user@mail 2026-01-01 11:00:00 d2202ed3
    │  setup: added bar

    $ jj show --git rmquqtvr
    Change ID: rmquqtvrotzooywwstpxxoutlzytnnro
    Author   : user <user@mail> (2026-01-01 12:00:00)

        !clanker! setup: do <thing> with foo instead of exiting

        Assisted-by: <your model name>

    diff --git a/setup.sh b/setup.sh
    @@ -10,4 +10,8 @@
    +foo() {
    +    # ...
    +}
    +
    -[[ ! -f "thing" ]] && die "you dont have thing (todo)"
    -bar "more parameters and bash operation"
    +[[ ! -f "thing" ]] && foo "parameters"
    +bar "more parameters and bash operation" "$foo_result"
    ```

# Clanker reference
* `clanker-ref/` at the project root is your own knowledge base for this project, adapted from https://srcmd.org. It's written by clankers for clankers so a session doesn't spend inference rediscovering what an earlier one already figured out. It is not user documentation, a specification or a changelog.
* Read `clanker-ref/README.md` before you start exploring, then only the files its index points to for your task. If the answer is there, use it instead of deriving it again. If the directory doesn't exist there's nothing to read yet.
* Write to it when you learned something that was expensive to find and that a later session would need again:
    * intent and design decisions (why it's shaped this way, what was rejected and why)
    * subtleties and gotchas that aren't visible from the code
    * where things live and how they connect when that took real exploring
    * how to build, run and test when it isn't obvious
    * dead ends, so they aren't tried again
* Don't write what a single grep or reading one file answers, restated code, task plans or status, a log of what you did, or secrets. Most tasks add nothing, that's fine.
* Layout, create it the first time you have something worth keeping:
    * `README.md`: short technical overview, the important subtleties and a `## File Index`
    * The index links every other file in `clanker-ref`, one per line with a brief description, paths relative to `clanker-ref` (`- [build/flake.md](build/flake.md): how the dev shell is assembled`)
    * Everything else is one topic per file, grouped into subdirectories once there's enough of them. Use the subproject's name as the directory for things specific to it.
* Keep the signal high: short, plain, technical sentences. Point at code with paths instead of copying it.
* It's only worth something if it's right. When a change of yours makes an entry wrong, fix it in the same task. When it disagrees with the code, the code wins and you correct or delete the entry. Delete what's stale and keep the index in sync.
* What the user says and what this file says always outranks `clanker-ref`.
* Tell the user when you added or changed something in it.

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
* NEVER DO VERSION CONTROL OPERATIONS (`git` OR `jj`) UNLESS YOU'RE **EXPLICITLY** TOLD SO. Read-only commands (`status`, `log`, `diff`, `show`) are fine. The only standing exception is making your clanker change, see Disclosure.
* NEVER GLOB THE UNIGNORE. These project(s) intentionally use explicit inverse ignore which means EVERYTHING is ignored by default and specific files are then unignored. The only exception is when it comes to obviously globbed directories such as source directories, if unsure always ask.
    * Remember that git can't re-include a file if its parent directory is ignored, so globbed directories also need their subdirectories unignored (`!/src/**/`)
    * Always anchor every unignore to the directory of its `.gitignore` with a leading `/` (`!/flake.nix`, not `!flake.nix`). An unanchored pattern matches at any depth, so a subdirectory without its own `.gitignore` inherits it and silently re-includes every same named file below it
    * .gitignore
    ```
    **
    .*
    !/.gitignore
    !/build.zig
    !/src/
    # This makes sense because in this context `src` is expected to only contain zig source code
    !/src/**/
    !/src/**/*.zig
    # This folder despite having a similar role is not "predictable" and hence should NOT be globbed, it gets its own .gitignore listing every file
    !/assets/
    # Same kind of content as `src`, but it's a small fixed set of files, so list them explicitly instead of globbing
    !/scripts/
    !/scripts/setup.sh
    !/scripts/deploy.sh
    ```
    * assets/.gitignore
    ```
    **
    .*
    !/.gitignore
    !/foo.svg
    !/bar.svg
    ```
