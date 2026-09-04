{ config, lib, ... }: let
    cfg = config.nyx.nixos.luksUnlock;
in {
    flake.modules.nixos = {
        luks = {
            boot.initrd.kernelModules = [ "cryptd" ];
        };

        nyx-luks-unlockable = { config, lib, pkgs, ... }: let
            unlockShell = pkgs.writeShellScript "nyx-luks-unlock" ''
                exec ${config.boot.initrd.systemd.package}/bin/systemd-tty-ask-password-agent --query
            '';
        in {
            assertions = [{
                assertion = cfg.key != null;
                message = "nyx-luks-unlockable requires nyx.nixos.luksUnlock.key";
            }];

            boot.initrd.systemd = {
                enable = true;
                network = {
                    enable = true;
                    networks."10-nyx-luks-unlock" = {
                        matchConfig.Type = "ether";
                        networkConfig = {
                            DHCP = "no";
                            IPv6AcceptRA = false;
                            LinkLocalAddressing = "ipv6";
                            IPv6LinkLocalAddressGenerationMode = "eui64";
                        };
                    };
                };
                storePaths = [ unlockShell ];
                users.root.shell = unlockShell;
            };

            boot.initrd.network.ssh = {
                enable = true;
                port = cfg.port;
                authorizedKeys = lib.optional (cfg.key != null) cfg.key.public;
                hostKeys = [ cfg.hostKeyPath ];
                extraConfig = ''
                    DisableForwarding yes
                    PermitTunnel no
                    PermitUserEnvironment no
                '';
            };
        };
    };
}
