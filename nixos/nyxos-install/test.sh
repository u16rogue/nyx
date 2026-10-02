#!/usr/bin/env bash
# THIS WAS WRITTEN BY A CLANKER
# Non-destructive regression checks; no host private keys or disks are needed.
# Child-shell programs below deliberately use single quotes.
# shellcheck disable=SC2016
set -euo pipefail
here=$(realpath -- "$(dirname -- "${BASH_SOURCE[0]}")")
repo=$(realpath -- "$here/../..")
scratch=$(mktemp -d)
trap 'chmod -R u+w -- "$scratch"; rm -rf -- "$scratch"' EXIT
# shellcheck source=nyxos-install
source "$here/nyxos-install"

expect_failure() {
    local message=$1; shift
    if ( "$@" ) > "$scratch/output" 2>&1; then
        printf 'Unexpected success: %s\n' "$message" >&2
        exit 1
    fi
    if ! grep -Fq -- "$message" "$scratch/output"; then
        cat "$scratch/output" >&2
        printf 'Missing diagnostic: %s\n' "$message" >&2
        exit 1
    fi
}
bash "$here/nyxos-install" --help >/dev/null
expect_failure 'requires a value' bash "$here/nyxos-install" --root
expect_failure 'unknown option' bash "$here/nyxos-install" --system /nix/store/anything
expect_failure 'specify --flake' bash "$here/nyxos-install"
expect_failure 'invalid flake or host name' bash "$here/nyxos-install" --flake '.#bad"host'
expect_failure 'cannot be combined' bash "$here/nyxos-install" --offline-bundle /missing --flake .#mistyriver
expect_failure 'does not accept' bash "$here/nyxos-install" --build-image --flake .#mistyriver --host-key /missing
expect_failure 'require --build-image' bash "$here/nyxos-install" --flake .#mistyriver --dry-run
root=$scratch/path-test
mkdir -p "$root/persist"
safe_path /persist/nix
ln -s / "$root/escape"
expect_failure 'unexpected symlink' safe_path /escape/etc
expect_failure 'unsafe target path' safe_path /persist/../etc
mkdir -p "$scratch/from" "$scratch/nonempty"
touch "$scratch/nonempty/state"
expect_failure 'refusing to hide' bind_state "$scratch/from" "$scratch/nonempty"
if unshare --user --map-root-user --mount true 2>/dev/null; then
    unshare --user --map-root-user --mount bash -euo pipefail -c '
        source "$1/nyxos-install"
        mkdir "$2/bind-target" "$2/wrong-source"
        bind_state "$2/from" "$2/bind-target"
        bind_state "$2/from" "$2/bind-target"
        if (bind_state "$2/wrong-source" "$2/bind-target") > "$2/bind-error" 2>&1; then exit 1; fi
        grep -Fq "wrong source" "$2/bind-error"
        touch "$2/from/state"
        [[ -f "$2/bind-target/state" ]]
        umount "$2/bind-target"
    ' bash "$here" "$scratch"
else
    printf 'Skipping bind-mount execution: user/mount namespaces unavailable.\n'
fi

ssh-keygen -q -t ed25519 -N '' -f "$scratch/key"
ssh-keygen -q -t ed25519 -N '' -f "$scratch/other-key"
digest=$(sha256sum "$scratch/key"); digest=${digest%% *}
metadata=$scratch/manifest.json
jq -n --arg pub "$(< "$scratch/key.pub")" --arg digest "$digest" '{keys: {pub: $pub, prv: {sha256: $digest}}}' > "$metadata"
verify_key "$scratch/key"
expect_failure 'SHA-256 differs' verify_key "$scratch/other-key"
jq --arg pub "$(< "$scratch/other-key.pub")" '.keys.pub = $pub' "$metadata" > "$scratch/modified"
mv "$scratch/modified" "$metadata"
expect_failure 'does not match' verify_key "$scratch/key"
ssh-keygen -q -t ed25519 -N 'test-only-passphrase' -f "$scratch/encrypted-key"
digest=$(sha256sum "$scratch/encrypted-key"); digest=${digest%% *}
jq -n --arg pub "$(< "$scratch/encrypted-key.pub")" --arg digest "$digest" '{keys: {pub: $pub, prv: {sha256: $digest}}}' > "$metadata"
expect_failure 'must be an unencrypted' verify_key "$scratch/encrypted-key"

base="builtins.getFlake $(jq -Rn --arg s "git+file://$repo" '$s')"
evaluate() {
    nix eval --impure --json --file "$here/manifest.nix" --apply "make: make { flake = $1; hostName = \"$2\"; }"
}
for host in mistyriver mistylake; do
    evaluate "$base" "$host" > "$scratch/evaluated"
    jq -e '
        (.version == 1) and
        (.toplevel | startswith("/nix/store/")) and
        (.toplevel | endswith(".drv") | not) and
        (.tmpfiles | contains("/persist/home/user")) and
        (.tmpfiles | contains("/persist/var/lib/nixos")) and
        (.tmpfiles | contains("/sysroot") | not)
    ' "$scratch/evaluated" >/dev/null
done
# Exercise the generated rules with real systemd-tmpfiles in a disposable root.
# User namespaces let this run without privileges on the host. Fixture users
# share mapped UID/GID 0 because this namespace only maps one account.
if command -v systemd-tmpfiles >/dev/null && unshare --user --map-root-user true 2>/dev/null; then
    jq -r .tmpfiles "$scratch/evaluated" > "$scratch/rules"
    unshare --user --map-root-user bash -euo pipefail -c '
        trap '\''printf "tmpfiles fixture failed at line %s\n" "$LINENO" >&2'\'' ERR
        root=$1/root
        install -d -m 0755 "$root/etc" "$root/persist/etc/ssh"
        printf "root:x:0:0::/root:/bin/sh\nuser:x:0:0::/home/user:/bin/sh\n" > "$root/etc/passwd"
        printf "root:x:0:\nusers:x:0:\n" > "$root/etc/group"
        install -m 0600 "$1/key" "$root/persist/etc/ssh/ssh_host_ed25519_key"
        systemd-tmpfiles --root="$root" --create - < "$1/rules"
        [[ -d "$root/persist/home/user/.nyx/app-fake-root/firefox" ]]
        [[ -d "$root/persist/var/lib/nixos" ]]
        [[ -f "$root/persist/etc/machine-id" ]]
        [[ $(readlink "$root/etc/ssh/ssh_host_ed25519_key") == /persist/etc/ssh/ssh_host_ed25519_key ]]
        [[ $(stat -c %a "$root/persist/etc/ssh/ssh_host_ed25519_key") == 600 ]]
    ' bash "$scratch"
else
    printf 'Skipping tmpfiles execution: systemd-tmpfiles or user namespaces unavailable.\n'
fi
expect_failure 'must be registered' evaluate "$base" not-a-registered-nyx-host
bad_fs="let f = $base; c = f.nixosConfigurations.mistyriver.config; in f // { nixosConfigurations = f.nixosConfigurations // { mistyriver.config = c // { fileSystems = c.fileSystems // { \"/nix\" = c.fileSystems.\"/nix\" // { device = \"/wrong\"; }; }; }; }; }"
expect_failure 'persistent /nix bind mount' evaluate "($bad_fs)" mistyriver
bad_users="let f = $base; h = f.nyx.nixos.hosts.mistyriver; in f // { nyx.nixos = f.nyx.nixos // { hosts = f.nyx.nixos.hosts // { mistyriver = h // { users = []; }; }; }; }"
expect_failure 'uniquely named registered users' evaluate "($bad_users)" mistyriver

# Check the ISO derivation and live configuration for each supported host.
for host in mistyriver mistylake; do
    nix eval --impure --json --file "$here/image.nix" --apply "make:
        let i = make { flake = $base; hostName = \"$host\"; }; c = i.installer.config;
        in { iso = i.iso.drvPath; target = i.manifest.toplevel;
             contents = map toString c.isoImage.storeContents;
             bundle = toString c.environment.etc.\"nyxos-install\".source;
             efi = c.isoImage.makeEfiBootable; usb = c.isoImage.makeUsbBootable;
             label = c.isoImage.volumeID; }" > "$scratch/image"
    jq -e '(.iso | endswith(".iso.drv")) and .efi and .usb and
        (.label | length <= 32) and
        (.target as $target | .contents | index($target) != null) and
        (.bundle as $bundle | .contents | index($bundle) != null)' "$scratch/image" >/dev/null
done

# A real tiny store closure, copied to a separate store without substitution.
# The offline path must not evaluate flakes, build, or enter a dependency shell.
fixture=$(nix build --impure --no-link --print-out-paths --expr "
    let f = $base; pkgs = import f.inputs.nixpkgs { system = builtins.currentSystem; };
    in pkgs.runCommand \"nyxos-offline-test-system\" {} ''
        mkdir -p \$out
        printf fixture > \$out/activate
        chmod +x \$out/activate
    ''")
mkdir "$scratch/bundle" "$scratch/work"
jq -n --arg system "$fixture" '{version: 1, hostName: "fixture", toplevel: $system, users: [{name: "fixture"}]}' > "$scratch/bundle/manifest.json"
ln -s "$fixture" "$scratch/bundle/system"
(
    nix() {
        local arg
        for arg in "$@"; do
            case "$arg" in eval|build|flake|shell) die 'offline installation attempted evaluation, building or fetching dependencies';; esac
        done
        command nix "$@"
    }
    offline_bundle=$scratch/bundle work=$scratch/work root=$scratch/store
    install_args=()
    load_offline_bundle
    copy_offline_system
    cmp "$fixture/activate" "$root$fixture/activate"
    [[ " ${install_args[*]} " == *' --no-channel-copy '* ]]
    command nix --offline path-info --store "$root" "$fixture" >/dev/null
    jq '.version = 999' "$offline_bundle/manifest.json" > "$scratch/bad-manifest"
    mv "$scratch/bad-manifest" "$offline_bundle/manifest.json"
    expect_failure 'unsupported or incomplete' load_offline_bundle
)
printf 'nyxos-install regression checks passed.\n'
