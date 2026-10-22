# THIS WAS WRITTEN BY A CLANKER
{ config, ... }: {
    nyx.nixos.hosts."mistypuddle" = {
        platform = "x86_64-linux";

        monitors = [
            {
                id = "eDP-1";
                resolution = { x = 1920; y = 1080; };
                refreshrate = 60;
            }
        ];

        keys = {
            pub = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOzCtcCXDjyFOuFrmBruCoyLVWsqUI9W2ixmflH2zDLg ";
            prv = {
                age = ''
                    -----BEGIN AGE ENCRYPTED FILE-----
                    YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IHNjcnlwdCBjSGg4SUR2R0dPWGVTN1kx
                    bmVOeFNnIDE4CkJqTmY2ZzgwUklFTCtnSGE2LzdiWUZ3MlNaeWlLQ2k1eHc2VVpX
                    NlkxNG8KLS0tIGFadUUyOWVMc0ZQbGFpM3c4emVqdUZnTGQ1M3FqNTZmUUFBbmhJ
                    N2pJOXMKzgUNUrPJQblK7ZedA6Z0byNN1BbR8mLIFMJ8KyPjhzG9JUkywgE5RajR
                    K7E9nEc7y6yGXwEYoluqGgHudFyOIQyXMhLbwJiExyN88XFGYgUvu8Z9yMjGrLVK
                    rqLQaGYR9FLm5p65oUYw8wNEa5K+AlwalrFy5lCnlc5cbQVXedlJXXyYaMgv8JLw
                    tofZ+uBVTBz7KYkM53bfaUYdkzAmKyW423QBQRAzloMY754Vxro06wDaylka30e/
                    0qFZYK7uyi3G3m3g8Ct+wVul98Kx/Lk/3T4spAufTNs8EpYJiwBB3tKsaFNaARg+
                    CRY5A37nrkBymsr9xu0YE24ZNtVH+Nj4oIYZLi9iOecg8W8pw+PbjuUmqkG8LRGW
                    HLfW03/ceSmUrs/S38gSOgOKlsiyXXCORT1igGecbjSVGK5bHlq8md9VKfxwClSB
                    8zlnaj2NKeayT6d6KCjnQm4a7kWrHIZnx/gbjFvzBUC0EuuRdseyzan8VBoo1WeW
                    kpBhGZVJNq4DXxxdfyAOsfhmfHlRDBmwJo5wL2IK4b3U6CLX+6ArwUA=
                    -----END AGE ENCRYPTED FILE-----
                '';
                sha256 = "ee197446789da90f5ad84dd5ac37e20b393855cfc962e9deb83f4ff578a17d97"; };
        };

        ephemeralfs.preserve = {
            directories = [
                { directory = "/var/lib/nixos"; inInitrd = true; }
                "/var/lib/systemd/coredump"
                "/var/log"
                "/etc/NetworkManager/system-connections"
                "/var/lib/bluetooth"
                "/var/lib/nyx-auto-upgrade"
            ];
            files = [
                { file = "/etc/machine-id"; inInitrd = true; }
                { file = "/etc/ssh/ssh_host_ed25519_key"; how = "symlink"; configureParent = true; }
                { file = "/etc/ssh/ssh_host_ed25519_key.pub"; how = "symlink"; configureParent = true; }
            ];
        };

        users = with config.nyx.nixos.users; [
            sysadmin
        ];

        configuration = { self, config, pkgs, ... }: let
            ssdId = "/dev/disk/by-id/ata-TOSHIBA_KSG60ZMV512G_M.2_2280_512GB_19HA11FWK8HN";
            hddId = "/dev/disk/by-id/ata-ST2000LM007-1R8174_WDZ76VAB";
            # Everything below about the HDD is read back from its disko definition
            hddPart = config.disko.devices.disk.hdd.content.partitions.data;
            hddLuks = hddPart.content;
            hddMount = hddLuks.content.mountpoint;
            forgejo = config.services.forgejo;
            monero = config.systemd.services.monero.serviceConfig;
        in {
            imports = with self.modules.nixos; [
                systemd-boot
                cpu-intel
                luks
                networkmanager
                mdns-publish
                ssh-server
                auto-upgrade
                svc-traefik
                svc-forgejo
                svc-monero
            ];

            environment.systemPackages = [
            ];

            # Bulk state on the HDD; services must not start on an empty tmpfs dir if it fails to mount
            preservation.preserveAt.${hddMount}.directories = [
                { directory = forgejo.stateDir; user = forgejo.user; group = forgejo.group; mode = "0750"; }
                { directory = config.services.monero.dataDir; user = monero.User; group = monero.Group; mode = "0750"; }
            ];
            systemd.services.forgejo.unitConfig.RequiresMountsFor = [ forgejo.stateDir ];
            systemd.services.monero.unitConfig.RequiresMountsFor = [ config.services.monero.dataDir ];

            # Server: run with the lid closed and never sleep
            services.logind.settings.Login = {
                HandleLidSwitch = "ignore";
                HandleLidSwitchExternalPower = "ignore";
                HandleLidSwitchDocked = "ignore";
            };
            systemd.targets = {
                sleep.enable = false;
                suspend.enable = false;
                hibernate.enable = false;
                hybrid-sleep.enable = false;
            };

            # Dimmest non-off backlight;
            services.udev.extraRules = ''ACTION=="add", SUBSYSTEM=="backlight", KERNEL=="intel_backlight", ATTR{brightness}="1"'';

            # Compressed RAM swap first, encrypted on-disk swapfile as overflow (16G RAM + tmpfs root)
            zramSwap.enable = true;
            swapDevices = [{
                device = "/persist/swapfile";
                size = 8 * 1024;
            }];

            # Prefer efficiency; intel_pstate still boosts under load
            services.thermald.enable = true;
            services.tlp = {
                enable = true;
                settings = {
                    CPU_SCALING_GOVERNOR_ON_AC = "powersave";
                    CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
                    CPU_ENERGY_PERF_POLICY_ON_AC = "balance_power";
                    CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
                    CPU_BOOST_ON_AC = 1;
                    CPU_BOOST_ON_BAT = 0;
                    RUNTIME_PM_ON_AC = "auto"; # lets the idle AMD dGPU power down
                    RUNTIME_PM_ON_BAT = "auto";
                    # Always plugged in: keep the battery between 50-60% (Dell supports custom thresholds)
                    START_CHARGE_THRESH_BAT0 = 50;
                    STOP_CHARGE_THRESH_BAT0 = 60;
                };
            };

            # Allow SSH on initrd to remotely unlock luks
            boot.initrd = {
                network = {
                    enable = true;
                    ssh = {
                        enable = true;
                        port = 22;
                        hostKeys = [ "/persist/etc/ssh/initrd_ssh_host_ed25519_key" ];
                        authorizedKeys = config.users.users.sysadmin.openssh.authorizedKeys.keys;
                    };
                };
                systemd.network.networks."10-ethernet" = {
                    matchConfig.Type = "ether";
                    networkConfig.DHCP = "yes";
                    dhcpV4Config.ClientIdentifier = "mac";
                    networkConfig.MulticastDNS = true;
                };
                systemd.contents."/etc/systemd/resolved.conf.d/mdns.conf".text = ''
                    [Resolve]
                    MulticastDNS=yes
                '';
                systemd.users.root.shell = "/bin/systemd-tty-ask-password-agent";
            };

            system.stateVersion = "25.11";
            boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usb_storage" "sd_mod" "sr_mod" "rtsx_usb_sdmmc" "r8169" "realtek" ];
            # SSD: boot + system state (/persist, including /nix)
            disko.devices.disk.ssd = {
                type = "disk";
                device = ssdId;
                content = {
                    type = "gpt";
                    partitions = {
                        ESP = {
                            size = "511M";
                            type = "EF00";
                            label = "ESP";
                            device = "${ssdId}-part1";
                            content = {
                                type = "filesystem";
                                format = "vfat";
                                mountpoint = "/boot";
                                mountOptions = [ "fmask=0077" "dmask=0077" ];
                            };
                        };
                        persist = {
                            size = "100%";
                            label = "primary";
                            device = "${ssdId}-part2";
                            content = {
                                type = "luks";
                                name = "persist-luks";
                                content = {
                                    type = "filesystem";
                                    format = "ext4";
                                    extraArgs = [ "-L" "persist" ];
                                    mountpoint = "/persist";
                                };
                            };
                        };
                    };
                };
            };
            # HDD: bulk service data, unlocked after boot with a keyfile kept on the SSD
            disko.devices.disk.hdd = {
                type = "disk";
                device = hddId;
                content = {
                    type = "gpt";
                    partitions = {
                        # Former ESP, left unmounted
                        legacy = {
                            size = "511M";
                            type = "EF00";
                            device = "${hddId}-part1";
                        };
                        data = {
                            size = "100%";
                            label = "primary";
                            device = "${hddId}-part2";
                            content = {
                                type = "luks";
                                name = "data-luks";
                                initrdUnlock = false;
                                settings.keyFile = "/persist/etc/keys/data.key";
                                content = {
                                    type = "filesystem";
                                    format = "ext4";
                                    extraArgs = [ "-L" "data" ];
                                    mountpoint = "/data";
                                    mountOptions = [ "defaults" "nofail" ];
                                };
                            };
                        };
                    };
                };
            };
            environment.etc.crypttab.text = ''${hddLuks.name} ${hddPart.device} ${hddLuks.settings.keyFile} luks,nofail'';
        };
    };
}
