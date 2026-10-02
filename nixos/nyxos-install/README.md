# nyxos-install

**THIS WAS WRITTEN BY A CLANKER**, including the script, Nix helpers, tests, and
this documentation.

An ordinary executable script wrapping `nixos-install`, with a second mode for
building a host-specific offline installer ISO. No package or flake output is
registered. Run `nixos/nyxos-install/nyxos-install` directly from the checkout.
If installation dependencies are missing, it enters a `nix shell` pinned to this
checkout's `flake.lock` and re-executes itself with the original arguments.
Bash, Nix, and basic coreutils must already be available (as on a NixOS ISO).

## Direct installation

Boot a NixOS installer matching the host's architecture. For the current hosts,
boot in UEFI mode. Prepare the configured disks, unlock LUKS, and mount the tmpfs
root, `/persist`, and `/boot` under `/mnt`, using disko or manual preparation.

```sh
sudo ./nixos/nyxos-install/nyxos-install --flake .#mistyriver --root /mnt
```

Use `mistylake` for that host instead. The host configuration must be complete;
unfinished sibling hosts do not prevent installing a complete one. The source
flake is archived once so validation and the system build use the same revision.
Normal Git-backed flake rules apply to host configuration files: new files must
be tracked to be included. The installer and its Nix helpers themselves can run
directly without being Git-tracked.

The script prompts for the passphrase protecting the registered age backup of
the host key. Alternatively, supply a recovered **unencrypted** private key:

```sh
sudo ./nixos/nyxos-install/nyxos-install \
  --flake .#mistyriver --host-key /run/recovered-host-key
```

An existing matching key under the target's `/persist/etc/ssh` is reused.
The exact private-key bytes, including the final newline, must match the
registered SHA-256 digest, and its public key must match the registered ED25519
key. Existing mismatched keys are rejected.

## Build an offline installer ISO

On an online build machine, without sudo:

```sh
./nixos/nyxos-install/nyxos-install --build-image \
  --flake .#mistyriver --out-link ./mistyriver-installer
```

The ISO appears under `./mistyriver-installer/iso/`. This builds the host's entire
system closure as well as the live installer; allow enough disk space and build
time. `--dry-run` checks the build plan without producing the image.

The live system is based on NixOS's minimal installation ISO, using the target
kernel and initrd storage drivers alongside the installer's generic hardware,
firmware, LUKS, and software RAID support. The target's own root filesystem and
users are not used as the live environment. The ISO contains:

- The exact prebuilt host system and its full runtime closure.
- Build-time-validated host metadata, preservation rules, and encrypted secrets.
- The installation script and all its runtime dependencies.
- Prebuilt disko format-and-mount and mount-only scripts for that host's disks.

Only the **encrypted** host-key backup is embedded. Image creation does not ask
for a key or accept `--host-key`. The decryption passphrase or recovered private
key is still required when installing. Treat the ISO as a host configuration
snapshot; rebuild it after changing the configuration, passwords, or host keys.

### Install with the network disconnected

Write the ISO to installation media and boot it. On the live console:

```sh
# Choose the appropriate preparation operation:
sudo nyxos-mount       # mount existing prepared disks; unlock LUKS as prompted
# OR:
sudo nyxos-disko       # ERASES and prepares the host's configured disks

sudo nyxos-install
```

The disko commands are generated from the selected host's disk configuration and
use its configured `/dev/disk/by-id/...` paths and `/mnt` mount root. They do not
guess replacement disks. The installation command itself never formats disks.
The image's preparation scripts create the persistent Nix directory before
disko attempts its bind mount, including on a newly formatted filesystem.

On the image, `nyxos-install` automatically selects `/etc/nyxos-install` as its
offline bundle. It copies the bundled closure into the target store, without
flake evaluation, building, channel copying, remote builders, or network
substitution. Missing tools or missing store paths cause a failure rather than
an attempt to download them. The same key, mount, secret, activation, and login
checks used by direct installation still run.

`--offline-bundle DIR` explicitly selects a generated bundle when needed. A
bundle directory alone is insufficient: its referenced system and runtime
closure must already be present and registered in the live Nix store, as they
are on the generated ISO. It cannot be combined with `--flake` or `--build-image`.

## Bootstrap and verification

The script checks the selected host's NixOS assertions and Nyx invariants:
persistent `/nix`, immutable users, a normal wheel user, agenix identity, and
preserved machine ID, host keys, and initrd account state. It validates mounted
filesystems against their configured block devices, types, writable state, and
declared btrfs subvolumes, and rejects unsafe bootstrap symlinks. A lock on the
persistence volume serializes concurrent installers.

Before activation it restores the verified host key, proves it decrypts user
passwords, generates a machine ID only if missing, and bind-mounts persistent
`/nix`, `/var/lib/nixos`, and `/etc/machine-id`. This keeps allocated account IDs
across the first reboot. Existing nonempty state is never silently hidden by a
new bind mount. Direct mode builds into the persistent target store; offline
mode copies the prebuilt system there. All configured age secrets are checked
for successful decryption before invoking `nixos-install`.

Installation always supplies `--no-root-passwd` and requires an explicit
successful activation. It applies both boot stages' evaluated preservation
tmpfiles rules with target user ownership, including generated home parents,
then checks installed password hashes, host-key identity/permissions, and the
system profile. Normal preservation bind mounts are established at boot.
`partial.directories` is not used by Nyx's preservation builder and is not
treated as persistent state here.

Temporary plaintext is held in a private `/run` directory and removed on exit.
It is never included in an image or Nix store output. Target mounts and persistent
bootstrap state remain in place after success or failure. Fix a reported issue
and rerun against the same target; matching keys and machine IDs are retained.
After success, unmount the target recursively before rebooting.

Other options: `--no-bootloader`, `--no-channel-copy`, `--show-trace`, and
`--verbose`. With `--no-bootloader`, arrange bootloader installation separately.
Arbitrary upstream arguments and `--system` are rejected so they cannot bypass
the host/bundle validation.

## Tests

```sh
bash nixos/nyxos-install/test.sh
```

Tests cover argument rejection, real ED25519 validation, both complete host
manifests and ISO derivations, invalid configuration assertions, symlink rejection,
and copying a small real closure into an isolated offline store. Where user
namespaces are available, they also exercise real bind mounts and preservation
tmpfiles rules. The offline-copy test rejects any attempt to evaluate, build, or
bootstrap dependencies. These tests require Nix, jq, OpenSSH, and standard shell
utilities; `systemd-tmpfiles` is used when available.

A full ISO build and boot/install test additionally require the system closure's
build resources, appropriate disks, and the host backup passphrase or private key.
