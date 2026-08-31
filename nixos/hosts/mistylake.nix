{ ... }: let
    hostName = "mistylake";
in {
    nyx.nixos.hosts.${hostName} = {
        keys = {
            pub = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE0ZgVVQZfW3BYIUT3fa9T1ncUnpIF+X8ZZysapPU5nQ root@mistylake";
            prv = {
                age = ''
                    -----BEGIN AGE ENCRYPTED FILE-----
                    YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IHNjcnlwdCBzSVZNVHRzT2cxK0lMWFFi
                    UWVTU25nIDE4CitxMEttaitmWHk0MXNyNFpSY0p6TlZjY1kzR014ZS9IN0NpT2lM
                    MlVPcXMKLS0tIFVKOEhRU3dsbTk3ZitXNWJFcHhKdTAzd2c3UUdiSy94R3lNd0c0
                    Qjk3K28KMjOXqSZN+Dyrqh/eFVCLgTaPW7cXfIwCGd0yBVyLU8FW0MAn9+sA7Ezv
                    E1f3v4Ar71Zxo+2Ou/AJbx1ZGKiMWCbekM6A/+ZNkAW4et6WoBUolZy1Et09EaNe
                    52ZKmY7uHCp+cD5p5dj5fwgdmyEIuulyCgF7udSVC0ODuSojnCxiZajszbqsVNvg
                    Tg7/JxdyOCvMAiYmiq9208JIUfEdMu0WMz/jKOZENA3dvpY7B64/bFbw9MdhEfeC
                    LA4IZ8diJqx+7uqfYpBQQvLD+QCI+goSWrsAS1s/0/hTDbXRVayD+HtoxwQJPLNs
                    NRyBkxx+VzDWIkALRy19j5WigUPBmsVBkQX5psebJlJPcWUm1nSKFJI9zhq3Bkqw
                    gi+/fRD+ExTMQWEwI4B/gQCkoG2KHStRxqDAPRHfbdzdCZcq4sY7S5lSp8Dk1YQh
                    JfWiiwMmbN4HWMG4k6TR+S2OM324Q4fls6a6fCHkBXW4wDeB5jMe8RG74eQx5IuD
                    Kk4ArrQ9TaTgz8ll17LLMW9hzeiRtfPdjPcutWISVdnK/6aUScOsMLOv2uOBQH0w
                    zS59HS4IUAEmZq8nk4Fdwfg=
                    -----END AGE ENCRYPTED FILE-----
                '';
                sha256 = "6866baa25c2a18c4f739b09a122aedf7953a72ae8c9a5adb4a12b1444e575ba6";
            };
        };

        ephemeralfs.preserve = {
            at = "/persist";

            directories = [
                # System state
                "/var/lib/nixos"
                "/var/lib/systemd/coredump"
                # Networking
                "/etc/NetworkManager/system-connections"
                # Bluetooth
                "/var/lib/bluetooth"
            ];

            files = [
                "/etc/ssh/ssh_host_ed25519_key"
                "/etc/ssh/ssh_host_ed25519_key.pub"
                "/etc/machine-id"
            ];
        };

        users = [ "user" ];

        configuration = { self, inputs, ... }: {
            imports = with self.modules.nixos; [
                host-defaults
                cpu-intel
                gpu-nvidia
                pipewire
                openssh
                swraid
                luks
            ];

            nixpkgs.hostPlatform = "x86_64-linux";
            system.stateVersion = "25.11";
            boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];

            disko.enableConfig = true;
            disko.devices = {
                disk = {
                    nvme0 = {
                        type = "disk";
                        device = "/dev/disk/by-id/nvme-eui.0025384751a1d7e4";
                        content = {
                            type = "gpt";
                            partitions = {
                                legacy = {
                                    size = "511M";
                                    label = "primary";
                                    device = "/dev/disk/by-id/nvme-eui.0025384751a1d7e4-part1";
                                    content = {
                                        type = "filesystem";
                                        format = "ext4";
                                    };
                                };
                                raid = {
                                    size = "100%";
                                    label = "primary";
                                    device = "/dev/disk/by-id/nvme-eui.0025384751a1d7e4-part2";
                                    content = {
                                        type = "mdraid";
                                        name = "nixos:persist-raid";
                                    };
                                };
                            };
                        };
                    };
                    nvme1 = {
                        type = "disk";
                        device = "/dev/disk/by-id/nvme-eui.0025384751a1db23";
                        content = {
                            type = "gpt";
                            partitions = {
                                ESP = {
                                    size = "511M";
                                    type = "EF00";
                                    label = "ESP";
                                    device = "/dev/disk/by-id/nvme-eui.0025384751a1db23-part1";
                                    content = {
                                        type = "filesystem";
                                        format = "vfat";
                                        mountpoint = "/boot";
                                        mountOptions = [ "fmask=0077" "dmask=0077" ];
                                    };
                                };
                                raid = {
                                    size = "100%";
                                    label = "primary";
                                    device = "/dev/disk/by-id/nvme-eui.0025384751a1db23-part2";
                                    content = {
                                        type = "mdraid";
                                        name = "nixos:persist-raid";
                                    };
                                };
                            };
                        };
                    };
                };
                mdadm."nixos:persist-raid" = {
                    type = "mdadm";
                    level = 0;
                    metadata = "1.2";
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
            fileSystems."/var/log" = {
                depends = [ "/persist" ];
                device = "/persist/var/log";
                fsType = "none";
                options = [ "bind" ];
            };
        };
    };
}
