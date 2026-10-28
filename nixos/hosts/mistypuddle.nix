{ config, ... }: {
    nyx.nixos.hosts."mistypuddle" = let meta' = {
        svc = {
            traefik.enable = true;
            forgejo = {
                enable = true;
                port = 3000;
                subpath = "/git";
            };
            monero = {
                enable = true;
                port = 18089;
            };
            transmission = {
                enable = true;
                port = 9091;
                subpath = "/transmission";
            };
            jellyfin = {
                enable = false;
                port = 8096;
                subpath = "/jellyfin";
            };
            i2pd.enable = false;
        };
    }; in {
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

        configuration = { self, config, pkgs, lib, nyx, ... }: let
            disks' =
                let
                    diskoPartitionContentToMountpoint = (content: if content != null then
                        if builtins.hasAttr "mountpoint" content then
                            content.mountpoint
                        else if builtins.hasAttr "content" content then
                            diskoPartitionContentToMountpoint content.content
                        else
                            null
                    else null);
                in lib.pipe config.disko.devices.disk [
                    (builtins.mapAttrs (_: disk: {
                        partitions = lib.pipe (disk.content.partitions) [
                            (builtins.mapAttrs (_: partition: { mountpoint = diskoPartitionContentToMountpoint partition.content; }))
                        ];
                    }))
                ]
            ;

            # Generic setup for a service unit, as a module:
            #   preserve: preserves `directories` (paths or preservation entries) at `at` and makes the unit wait for their mounts
            #   route: routes `rule` on `entryPoints` through traefik to the local `port`, optionally stripping `stripPrefix`
            nyxosUnitSetup = { unit, preserve ? null, route ? null }: {
                imports = [
                    (lib.optionalAttrs (preserve != null) (let
                        entries = builtins.map (dir: { inherit (preserve) user group; mode = "0750"; } // (if builtins.isString dir then { directory = dir; } else dir)) preserve.directories;
                    in {
                        preservation.preserveAt.${preserve.at}.directories = entries;
                        systemd.services.${unit}.unitConfig.RequiresMountsFor = builtins.map (entry: entry.directory) entries;
                    }))
                    (lib.optionalAttrs (route != null) (let
                        name = route.name or unit;
                        stripPrefix = lib.defaultTo "" (route.stripPrefix or null);
                    in {
                        services.traefik.dynamicConfigOptions.http = {
                            routers.${name} = {
                                entryPoints = route.entryPoints or [ "web" ];
                                inherit (route) rule;
                                service = name;
                            } // lib.optionalAttrs (stripPrefix != "") {
                                middlewares = [ "${name}-strip-prefix" ];
                            };
                            services.${name}.loadBalancer.servers = [{ url = "http://127.0.0.1:${toString route.port}"; }];
                        } // lib.optionalAttrs (stripPrefix != "") {
                            middlewares."${name}-strip-prefix".stripPrefix.prefixes = [ stripPrefix ];
                        };
                    }))
                ];
            };
            # Matches the path itself and everything under it (`""` is the root)
            traefikPathRule = path: if path == "" then "PathPrefix(`/`)" else "Path(`${path}`) || PathPrefix(`${path}/`)";
        in {
            imports = let smnos = self.modules.nixos; in [
                smnos.systemd-boot
                smnos.cpu-intel
                smnos.luks
                smnos.networkmanager
                smnos.mdns-publish
                smnos.ssh-server
                smnos.lid-switch-ignore
                smnos.no-sleep
                smnos.auto-upgrade

                (lib.optionalAttrs meta'.svc.traefik.enable {
                    services.traefik = {
                        enable = true;
                        staticConfigOptions = {
                            entryPoints.web.address = ":80";
                            log.level = "INFO";
                        };
                    };
                    networking.firewall.allowedTCPPorts = [ 80 ];
                })

                (lib.optionalAttrs meta'.svc.forgejo.enable {
                    imports = [(nyxosUnitSetup {
                        unit = "forgejo";
                        preserve = {
                            at = disks'.ssd.partitions.persist.mountpoint;
                            inherit (config.services.forgejo) user group;
                            directories = [ config.services.forgejo.stateDir ];
                        };
                        route = {
                            # Matched on the path only so the host is also reachable by IP (the Host header is then the IP, not the domain)
                            rule = traefikPathRule meta'.svc.forgejo.subpath;
                            stripPrefix = meta'.svc.forgejo.subpath;
                            port = meta'.svc.forgejo.port;
                        };
                    })];
                    # Git over SSH goes through the system sshd: `forgejo@<host>:<owner>/<repo>.git`
                    services.forgejo = {
                        enable = true;
                        settings = {
                            server = rec {
                                DOMAIN = "${config.networking.hostName}.local";
                                ROOT_URL = "http://${DOMAIN}${meta'.svc.forgejo.subpath}/";
                                HTTP_ADDR = "127.0.0.1";
                                HTTP_PORT = meta'.svc.forgejo.port;
                            };
                            # Accounts are created with `forgejo admin user create`
                            service.DISABLE_REGISTRATION = true;
                            # Actions is opt-in: new repos start without it (Forgejo's default list minus `repo.actions`)
                            repository.DEFAULT_REPO_UNITS = lib.concatStringsSep "," [
                                "repo.code" "repo.releases" "repo.issues" "repo.pulls" "repo.wiki" "repo.projects" "repo.packages"
                            ];
                        };
                    };
                    # For the `forgejo admin` CLI
                    environment.systemPackages = [ config.services.forgejo.package ];
                })

                (lib.optionalAttrs meta'.svc.monero.enable {
                    imports = [(nyxosUnitSetup {
                        unit = "monero";
                        preserve = let serviceConfig = config.systemd.services.monero.serviceConfig; in {
                            at = disks'.hdd.partitions.data.mountpoint;
                            user = serviceConfig.User;
                            group = serviceConfig.Group;
                            directories = [ config.services.monero.dataDir ];
                        };
                        route = {
                            name = "monero-rpc";
                            entryPoints = [ "monero-rpc" ];
                            rule = "PathPrefix(`/`)";
                            port = config.services.monero.rpc.port;
                        };
                    })];
                    services.monero = {
                        enable = true;
                        prune = true;
                        rpc = {
                            address = "127.0.0.1";
                            port = 18081;
                            restricted = true;
                        };
                    };
                    services.traefik.staticConfigOptions.entryPoints.monero-rpc.address = ":${toString meta'.svc.monero.port}";
                    networking.firewall.allowedTCPPorts = [ meta'.svc.monero.port ];
                })

                (lib.optionalAttrs meta'.svc.transmission.enable {
                    imports = [(nyxosUnitSetup {
                        unit = "transmission";
                        preserve = {
                            at = disks'.hdd.partitions.data.mountpoint;
                            inherit (config.services.transmission) user group;
                            directories = [ config.services.transmission.home ];
                        };
                        route = {
                            rule = "PathPrefix(`${meta'.svc.transmission.subpath}/`)";
                            port = meta'.svc.transmission.port;
                        };
                    })];
                    services.transmission = {
                        enable = true;
                        openPeerPorts = true;
                        settings = {
                            rpc-bind-address = "127.0.0.1";
                            rpc-port = meta'.svc.transmission.port;
                            rpc-url = "${meta'.svc.transmission.subpath}/";
                            rpc-authentication-required = true;
                            rpc-host-whitelist-enabled = false;
                            rpc-whitelist-enabled = false;
                        };
                        credentialsFile = "/persist/etc/transmission/credentials.json";
                    };
                })

                (lib.optionalAttrs meta'.svc.jellyfin.enable {
                    imports = [(nyxosUnitSetup {
                        unit = "jellyfin";
                        preserve = let jellyfin' = config.services.jellyfin; in {
                            at = disks'.hdd.partitions.data.mountpoint;
                            inherit (jellyfin') user group;
                            directories = [
                                { directory = jellyfin'.dataDir; mode = "0700"; }
                                { directory = jellyfin'.cacheDir; mode = "0700"; }
                            ];
                        };
                        route = {
                            rule = traefikPathRule meta'.svc.jellyfin.subpath; # Jellyfin expects the base URL to be kept, so no prefix stripping
                            port = meta'.svc.jellyfin.port;
                        };
                    })];
                    # The first visitor gets the setup wizard and becomes the admin; libraries are added from the dashboard
                    services.jellyfin.enable = true;
                    # Listen address and base URL have no NixOS option, they live in Jellyfin's `network.xml`.
                    # Seeded only when missing so the dashboard can still change the other network settings.
                    systemd.services.jellyfin.preStart = let
                        networkXmlPath = lib.escapeShellArg "${config.services.jellyfin.configDir}/network.xml";
                        networkXml = pkgs.writeText "network.xml" ''
                            <?xml version="1.0" encoding="utf-8"?>
                            <NetworkConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
                              <BaseUrl>${meta'.svc.jellyfin.subpath}</BaseUrl>
                              <InternalHttpPort>${toString meta'.svc.jellyfin.port}</InternalHttpPort>
                              <LocalNetworkAddresses>
                                <string>127.0.0.1</string>
                              </LocalNetworkAddresses>
                              <KnownProxies>
                                <string>127.0.0.1</string>
                              </KnownProxies>
                              <AutoDiscovery>false</AutoDiscovery>
                              <EnableUPnP>false</EnableUPnP>
                            </NetworkConfiguration>
                        '';
                    in lib.mkBefore ''
                        if [[ ! -e ${networkXmlPath} ]]; then
                            install -D -m 600 ${networkXml} ${networkXmlPath}
                        fi
                    '';
                    users.users.${config.services.jellyfin.user}.extraGroups = [ "render" "video" ] ++ lib.optional meta'.svc.transmission.enable config.services.transmission.group;
                    # Transcode on the Intel iGPU (00:02.0); the AMD dGPU (01:00.0) stays asleep
                    hardware.graphics = {
                        enable = true;
                        extraPackages = [ pkgs.intel-media-driver ];
                    };
                    services.jellyfin.hardwareAcceleration = {
                        enable = true;
                        type = "vaapi";
                        device = "/dev/dri/by-path/pci-0000:00:02.0-render";
                    };
                    services.jellyfin.transcoding.hardwareDecodingCodecs = {
                        h264 = true;
                        mpeg2 = true;
                        vc1 = true;
                    };
                })
            ];

            nyxos.auto-upgrade.sources = [{
                git = {
                    url = "https://github.com/u16rogue/nyx-release.git";
                    branch = "main";
                    flake = "github:u16rogue/nyx/@rev@";
                };
            }];

            environment.systemPackages = [
                nyx.pkgs.nyx-tty-display
                pkgs.curl
                pkgs.btop
                pkgs.git
                pkgs.neovim
                pkgs.yazi
                pkgs.lm_sensors
            ];

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
                        port = 2222;
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
            disko.devices.disk.ssd = let id = "/dev/disk/by-id/ata-TOSHIBA_KSG60ZMV512G_M.2_2280_512GB_19HA11FWK8HN"; in {
                type = "disk";
                device = id;
                content = {
                    type = "gpt";
                    partitions = {
                        ESP = {
                            size = "511M";
                            type = "EF00";
                            label = "ESP";
                            device = "${id}-part1";
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
                            device = "${id}-part2";
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
            disko.devices.disk.hdd = let id = "/dev/disk/by-id/ata-ST2000LM007-1R8174_WDZ76VAB"; in {
                type = "disk";
                device = id;
                content = {
                    type = "gpt";
                    partitions = {
                        # Former ESP, left unmounted
                        legacy = {
                            size = "511M";
                            type = "EF00";
                            device = "${id}-part1";
                        };
                        data = {
                            size = "100%";
                            label = "primary";
                            device = "${id}-part2";
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
            environment.etc.crypttab.text = let
                part = config.disko.devices.disk.hdd.content.partitions.data;
                luks = part.content;
            in ''${luks.name} ${part.device} ${luks.settings.keyFile} luks,nofail'';
        };
    };
}
