{ config, inputs, lib, self, ... }: {
    imports = lib.pipe [ ./hosts ./users ./modules ] [
        (builtins.map (subdir: lib.pipe (builtins.readDir subdir) [
            (lib.filterAttrs (filename: filetype: filetype == "regular" && builtins.match ".*\\.nix" filename != null))
            builtins.attrNames
            (builtins.map (filename: subdir + "/${filename}"))
        ]))
        lib.flatten
    ];

    config.flake.nixosConfigurations = lib.pipe config.nyx.nixos.hosts [
        (lib.mapAttrs (hostname: nyxhost: let
            nyxhost_users = lib.genAttrs nyxhost.users (username: config.nyx.nixos.users.${username});
            result = inputs.nixpkgs.lib.nixosSystem {
                specialArgs = {
                    inherit inputs self;
                    nyxpkgs = self.packages.${nyxhost.platform};
                };
                modules = [
                    inputs.disko.nixosModules.disko
                    inputs.preservation.nixosModules.default
                    inputs.ragenix.nixosModules.default
                    nyxhost.configuration # config.nyx.nixos.hosts.${hostname}.configuration
                    # Core builder
                    ({ config, modulesPath, pkgs, nyxpkgs, ... }: {
                        imports = [(modulesPath + "/installer/scan/not-detected.nix")];
                        networking.hostName = lib.mkDefault "${hostname}";
                        nixpkgs.hostPlatform = nyxhost.platform;
                        disko.enableConfig = true;
                        disko.devices.nodev = {
                            "/" = {
                                fsType = "tmpfs";
                                mountOptions = [ "defaults" "size=1G" "mode=755" ];
                            };
                            "/nix" = {
                                device = "/persist/nix";
                                fsType = "none";
                                mountOptions = [ "bind" ];
                            };
                        };
                        fileSystems = {
                            "/".neededForBoot = true;
                            "/nix" = {
                                depends = [ "/persist" ];
                                neededForBoot = true;
                            };
                            "/persist" = {
                                depends = [ "/" ];
                                neededForBoot = true;
                            };
                        };

                        # Derive the requested nyx users into a nixosSystem users
                        users.users = lib.flip lib.mapAttrs nyxhost_users (username: nyxuser: nyxuser.configuration { inherit pkgs nyxpkgs; });

                        age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

                        assertions = let
                            assertFileSystemMountPoint = mount_point: {
                                assertion = config.fileSystems ? "${mount_point}"
                                    && config.fileSystems."${mount_point}" ? device
                                    && config.fileSystems."${mount_point}".device != ""
                                    && config.fileSystems."${mount_point}" ? fsType
                                    && config.fileSystems."${mount_point}".fsType != "";
                                message = "nyx host '${hostname}' must provide a ${mount_point} filesystem device and type.";
                            };
                        in [
                            (assertFileSystemMountPoint "/boot")
                            (assertFileSystemMountPoint "/persist")
                        ];
                    })
                    # User password builder
                    ({ config, pkgs, ... }:
                        let
                            deriveAgeAttr = username: "nyx.secrets.user.${username}.password";
                        in {
                        users.users = lib.flip lib.mapAttrs nyxhost_users (username: nyxuser: { hashedPasswordFile = config.age.secrets."${deriveAgeAttr username}".path; });
                        age.secrets = lib.flip lib.mapAttrs' nyxhost_users (username: nyxuser: lib.nameValuePair "${deriveAgeAttr username}" {
                            file = pkgs.writeText "${deriveAgeAttr username}" nyxuser.password;
                            mode = "0400";
                        });
                    })
                    # Ephemeral file system preservation builder
                    (/*{ ... }:*/{
                        preservation = {
                            enable = true;
                            preserveAt."/persist" = {
                                files = nyxhost.ephemeralfs.preserve.files;
                                directories = nyxhost.ephemeralfs.preserve.directories;
                                users = lib.flip lib.mapAttrs nyxhost_users (username: nyxuser: {
                                    files = nyxuser.ephemeralfs.preserve.files;
                                    directories = nyxuser.ephemeralfs.preserve.directories;
                                });
                            };
                        };
                    })
                ];
            };
            in result
        ))
    ];

    options.nyx.nixos = {
        hosts = lib.mkOption {
            description = "Nyx nixos hosts";

            type = lib.types.attrsOf (lib.types.submodule {
                options.platform = lib.mkOption { type = lib.types.str; };
                options.configuration = lib.mkOption {
                    description = "NixOs system for this host";
                    type = lib.types.deferredModule;
                };
                options.keys = lib.mkOption {
                    description = "SSH host keys used for ssh and secrets management.";
                    type = lib.types.submodule {
                        options.pub = lib.mkOption {
                            type = lib.types.strMatching "^ssh-ed25519 [A-Za-z0-9+/]+={0,3}( .*)?$";
                            description = "Required SSH ED25519 public host key.";
                            example = "ssh-ed25519 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA+bbbbbbbbbbbbb root@host";
                        };
                        options.prv = lib.mkOption {
                            description = "Encrypted backup of the host private key with its hash for verification.";
                            type = lib.types.submodule {
                                options.age = lib.mkOption {
                                    type = lib.types.strMatching "^-----BEGIN AGE ENCRYPTED FILE-----\n([A-Za-z0-9+/=]+\n)+-----END AGE ENCRYPTED FILE-----\n?$";
                                    description = "Symmetric armored encrypted backup of the host private key.";
                                    example = ''
                                        -----BEGIN AGE ENCRYPTED FILE-----
                                        ...
                                        -----END AGE ENCRYPTED FILE-----
                                    '';
                                };
                                options.sha256 = lib.mkOption {
                                    type = lib.types.strMatching "^[0-9a-f]{64}$";
                                    description = "SHA-256 hash of the host private key.";
                                    example = "9d1398d0544800a282ec897ad35d0fe10376b02bc5b76dcb2754477433c62504";
                                };
                            };
                        };
                    };
                };
                options.ephemeralfs.preserve = lib.mkOption {
                    description = "Host preservation configuration.";
                    type = lib.types.submodule {
                        options.files = lib.mkOption {
                            description = "Absolute path to files for preservation.";
                            type = lib.types.listOf lib.types.raw;
                        };

                        options.directories = lib.mkOption {
                            description = "Absolute path to directories for preservation.";
                            type = lib.types.listOf lib.types.raw;
                        };

                        options.partial.directories = lib.mkOption {
                            description = "Absolute path to directories for partial preservation.";
                            type = lib.types.listOf lib.types.str;
                        };
                    };
                };
                options.users = lib.mkOption {
                    description = "Users assigned to this host derived from `nyx.nixos.users.*`";
                    type = lib.types.listOf lib.types.str;
                };
            });
        };

        users = lib.mkOption {
            description = "Nyx nixos users";
            type = lib.types.attrsOf (lib.types.submodule {
                options.configuration = lib.mkOption {
                    description = "NixOS user configuration for this user.";
                    type = lib.types.raw;
                };

                options.password = lib.mkOption {
                    type = lib.types.strMatching "^-----BEGIN AGE ENCRYPTED FILE-----\n([A-Za-z0-9+/=]+\n)+-----END AGE ENCRYPTED FILE-----\n?$";
                    description = "Host recipient encrypted of the user's password hash.";
                    example = ''
                        -----BEGIN AGE ENCRYPTED FILE-----
                        ...
                        -----END AGE ENCRYPTED FILE-----
                    '';
                };

                options.ephemeralfs.preserve = lib.mkOption {
                    description = "User preservation configuration.";
                    type = lib.types.submodule {
                        options.files = lib.mkOption {
                            description = "Absolute path to files for preservation.";
                            type = lib.types.listOf lib.types.raw;
                        };

                        options.directories = lib.mkOption {
                            description = "Absolute path to directories for preservation.";
                            type = lib.types.listOf lib.types.raw;
                        };

                        options.partial.directories = lib.mkOption {
                            description = "Absolute path to directories for partial preservation.";
                            type = lib.types.listOf lib.types.str;
                        };
                    };
                };
            });
        };
    };
}
