# THIS WAS WRITTEN BY A CLANKER
# Evaluate only the selected host; unfinished sibling hosts are allowed.
{ flake, hostName }:
let
    inherit (flake.inputs.nixpkgs) lib;
    host = flake.nyx.nixos.hosts.${hostName};
    config = flake.nixosConfigurations.${hostName}.config;
    fs = config.fileSystems;
    state = config.preservation.preserveAt."/persist";
    hasFile = path: lib.any (f: f.file == path) state.files;
    checks = [
        { assertion = config.networking.hostName == hostName; message = "Host name differs from Nyx registration."; }
        { assertion = host.users != [] && lib.length host.users == lib.length (lib.unique (map (u: u.name) host.users)); message = "A host needs uniquely named registered users."; }
        { assertion = lib.all (u: builtins.hasAttr u.name flake.nyx.nixos.users) host.users; message = "Host references an unregistered user."; }
        { assertion = fs."/".fsType == "tmpfs" && fs."/nix".device == "/persist/nix" && builtins.elem "bind" fs."/nix".options && fs."/nix".neededForBoot && fs."/persist".neededForBoot; message = "Expected Nyx tmpfs root and persistent /nix bind mount."; }
        { assertion = lib.all (p: fs.${p}.device != "" && fs.${p}.fsType != "" && fs.${p}.fsType != "tmpfs") [ "/persist" "/boot" ]; message = "Boot and persistence must have backing filesystems."; }
        { assertion = builtins.elem "/persist" fs."/nix".depends && builtins.elem "/" fs."/persist".depends; message = "Persistent filesystems must have Nyx boot dependencies."; }
        { assertion = !fs."/boot".neededForBoot && (fs."/boot".fsType != "vfat" || lib.all (o: builtins.elem o fs."/boot".options) [ "fmask=0077" "dmask=0077" ]); message = "Boot filesystem must retain Nyx FAT permissions and boot ordering."; }
        { assertion = config.preservation.enable && state.persistentStoragePath == "/persist"; message = "Preservation must use /persist."; }
        { assertion = lib.all hasFile [ "/etc/machine-id" "/etc/ssh/ssh_host_ed25519_key" "/etc/ssh/ssh_host_ed25519_key.pub" ]; message = "Preserve the machine ID and both ED25519 host key files."; }
        { assertion = lib.all (f: f.file != "/etc/ssh/ssh_host_ed25519_key" || (f.user == "root" && f.group == "root" && ((f.how == "symlink" && !f.createLinkTarget) || f.mode == "0600"))) state.files; message = "Preservation must not make the private host key readable by other users."; }
        { assertion = lib.any (d: d.directory == "/var/lib/nixos" && d.inInitrd && d.how == "bindmount") state.directories; message = "Preserve /var/lib/nixos with an initrd bind mount for stable account IDs."; }
        { assertion = lib.any (f: f.file == "/etc/machine-id" && f.inInitrd && f.how == "bindmount") state.files; message = "Preserve /etc/machine-id with an initrd bind mount."; }
        { assertion = builtins.elem "/persist/etc/ssh/ssh_host_ed25519_key" config.age.identityPaths; message = "Agenix must use the persistent host identity."; }
        { assertion = config.users.users.root.hashedPassword == "!" && !config.users.mutableUsers; message = "Expected immutable users and locked root password."; }
        { assertion = lib.any (u: config.users.users.${u.name}.isNormalUser && builtins.elem "wheel" config.users.users.${u.name}.extraGroups) host.users; message = "At least one registered normal user must have wheel access."; }
        { assertion = lib.all (u: config.users.users.${u.name}.hashedPasswordFile == config.age.secrets."nyx.secrets.user.${u.name}.password".path) host.users; message = "Registered users must use their Nyx password secret."; }
    ] ++ config.assertions;
    failures = map (a: a.message) (builtins.filter (a: !a.assertion) checks);
    # Use preservation's evaluated rules, including its generated user parents.
    # Initrd rules normally use /sysroot; installation uses --root instead.
    render = prefix: rules: lib.concatStrings (lib.mapAttrsToList (path: types:
        lib.concatStrings (lib.mapAttrsToList (_: rule:
            let
                quote = s: "\"${lib.strings.escapeC [ "\"" "\\" "\n" "\r" "\t" ] s}\"";
                argument = lib.removePrefix prefix rule.argument;
            in lib.concatStringsSep " " (map quote [ rule.type (lib.removePrefix prefix path) rule.mode rule.user rule.group rule.age ])
                + lib.optionalString (argument != "") (" " + lib.strings.escapeC [ "\t" "\n" "\r" " " "\\" ] argument) + "\n"
        ) types)
    ) rules);
in
assert lib.assertMsg (builtins.hasAttr hostName flake.nyx.nixos.hosts && builtins.hasAttr hostName flake.nixosConfigurations) "Host '${hostName}' must be registered in both nyx.nixos.hosts and nixosConfigurations.";
assert lib.assertMsg (failures == []) (lib.concatStringsSep "\n" failures);
{
    version = 1;
    inherit hostName;
    inherit (host) keys platform;
    filesystems = lib.genAttrs [ "/" "/boot" "/persist" ] (p: {
        inherit (fs.${p}) device fsType options;
    });
    users = map (u: { inherit (u) name password; }) host.users;
    secrets = lib.mapAttrsToList (name: s: { inherit name; file = toString s.file; }) config.age.secrets;
    tmpfiles = render "" (config.systemd.tmpfiles.settings.preservation or {})
        + render "/sysroot" (config.boot.initrd.systemd.tmpfiles.settings.preservation or {});
    efi = config.boot.loader.efi.canTouchEfiVariables;
    # Forcing this also checks NixOS's toplevel assertions before disk writes.
    # Use the output, not its derivation: an ISO needs the runtime closure only.
    toplevel = config.system.build.toplevel.outPath;
}
