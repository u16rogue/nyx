# THIS WAS WRITTEN BY A CLANKER
# A live installer containing the selected host's exact prebuilt runtime closure.
{ flake, hostName }:
let
    inherit (flake.inputs.nixpkgs) lib;
    host = flake.nixosConfigurations.${hostName};
    target = host.config;
    pkgs = host.pkgs;
    # Disko's nodev bind mount creates the destination, but not its source.
    # Extend only the preparation scripts; install the original host closure.
    diskPreparation = host.extendModules {
        modules = [{
            disko.devices.nodev."/nix".preMountHook = lib.mkBefore ''
                mountpoint -q ${lib.escapeShellArg "${target.disko.rootMountPoint}/persist"}
                test ! -L ${lib.escapeShellArg "${target.disko.rootMountPoint}/persist/nix"}
                install -d -m 0755 ${lib.escapeShellArg "${target.disko.rootMountPoint}/persist/nix"}
            '';
        }];
    };
    diskScripts = {
        mount = diskPreparation.config.system.build.mountScript;
        format = diskPreparation.config.system.build.diskoScript;
    };
    manifest = import ./manifest.nix { inherit flake hostName; };
    manifestFile = pkgs.writeText "nyxos-install-${hostName}.json" (builtins.toJSON manifest);
    bundle = pkgs.runCommand "nyxos-install-${hostName}-bundle" {} ''
        mkdir -p "$out"
        ln -s ${manifestFile} "$out/manifest.json"
        ln -s ${target.system.build.toplevel} "$out/system"
    '';
    installer = flake.inputs.nixpkgs.lib.nixosSystem {
        system = manifest.platform;
        modules = [
            (flake.inputs.nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
            ({ ... }: {
                networking.hostName = "nyxos-installer";
                nixpkgs.config.allowUnfree = true;
                nix.settings.experimental-features = [ "nix-command" "flakes" "pipe-operators" ];
                # Use the target kernel and storage drivers, but keep the live
                # ISO's generic hardware support and disk-independent root.
                boot.kernelPackages = target.boot.kernelPackages;
                boot.initrd.availableKernelModules = target.boot.initrd.availableKernelModules;
                boot.initrd.kernelModules = target.boot.initrd.kernelModules;
                # installation-device already enables software RAID support.
                boot.swraid.mdadmConf = lib.mkAfter target.boot.swraid.mdadmConf;
                isoImage.edition = lib.mkForce "nyxos-${hostName}";
                isoImage.volumeID = "NYXOS_${lib.toUpper (builtins.substring 0 24 hostName)}";
                image.baseName = lib.mkForce "nyxos-${hostName}-installer";
                isoImage.storeContents = [ target.system.build.toplevel bundle ];
                environment.etc."nyxos-install".source = bundle;
                environment.systemPackages = (import ./dependencies.nix { inherit pkgs; }) ++ [
                    # These commands only exist in the live image. The checkout
                    # entry point remains an ordinary, directly runnable script.
                    (pkgs.writeScriptBin "nyxos-install" (builtins.readFile ./nyxos-install))
                    (pkgs.writeShellScriptBin "nyxos-mount" ''exec ${diskScripts.mount} "$@"'')
                    (pkgs.writeShellScriptBin "nyxos-disko" ''exec ${diskScripts.format} "$@"'')
                ];
                services.getty.helpLine = lib.mkAfter ''

                  Nyx offline installer for ${hostName} (written by a clanker).
                  Existing prepared disks: sudo nyxos-mount
                  ERASE and prepare configured disks: sudo nyxos-disko
                  Install the bundled system: sudo nyxos-install
                  The registered host-key backup passphrase is required.
                '';
            })
        ];
    };
in {
    inherit bundle manifest installer diskScripts;
    iso = installer.config.system.build.isoImage;
}
