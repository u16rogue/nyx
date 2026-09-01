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
            assert_nyxhost_invalid_users = lib.flip builtins.filter nyxhost.users (username: !(builtins.hasAttr username config.nyx.nixos.users));
            nyxhost_users = if assert_nyxhost_invalid_users != []
                then throw "nyx host '${hostname}' has invalid nyx user entries: ${lib.concatStringsSep ", " assert_nyxhost_invalid_users}"
                else lib.genAttrs nyxhost.users (username: config.nyx.nixos.users.${username});
            result = inputs.nixpkgs.lib.nixosSystem {
                specialArgs = {
                    inherit inputs self;
                    nyxpkgs = self.packages.${nyxhost.platform};
                };
                modules = [
                    inputs.disko.nixosModules.disko
                    nyxhost.configuration # config.nyx.nixos.hosts.${hostname}.configuration
                    ({ config, modulesPath, pkgs, nyxpkgs, ... }: {
                        imports = [(modulesPath + "/installer/scan/not-detected.nix")];
                        networking.hostName = lib.mkDefault "${hostname}";
                        nixpkgs.hostPlatform = nyxhost.platform;
                        disko.enableConfig = true;
                        fileSystems = {
                            "/" = {
                                device = "none";
                                fsType = "tmpfs";
                                options = [ "defaults" "size=1G" "mode=755" ];
                                neededForBoot = true;
                            };
                            "/nix" = {
                                depends = [ "/persist" ];
                                neededForBoot = true;
                                device = "/persist/nix";
                                fsType = "none";
                                options = [ "bind" ];
                            };
                            "/persist" = {
                                depends = [ "/" ];
                                neededForBoot = true;
                            };
                        };

                        # Derive the requested nyx users into a nixosSystem users
                        users.users = lib.flip lib.mapAttrs nyxhost_users (username: nyxuser: nyxuser.configuration {
                            # i'd honestly prefer where `configuration` receives the same thing as what nixosSystem.modules receives
                            # as the pattern usually goes: `{ pkgs, ... }: { users.users.<name> = { ... }: {/*use pkgs*/}; }` i'll
                            # prolly expose users directly by deriving it in `modules` instead of here when i find a use case.
                            inherit pkgs nyxpkgs;
                        });

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
                ];
            };
            in result
        ))
    ];

    options.nyx.nixos = {
        hosts = lib.mkOption {
            description = "Nyx nixos hosts";

            type = lib.types.attrsOf (lib.types.submodule {
                # -- host platform --
                options.platform = lib.mkOption { type = lib.types.str; };
                # -- base nixos configuration --
                options.configuration = lib.mkOption {
                    description = "NixOs system for this host";
                    type = lib.types.deferredModule;
                };
                # -- Host SSH ED25519 Keys --
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
                                    description = "Armored encrypted backup of the host private key.";
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
                # -- Host specified impermanence --
                options.ephemeralfs.preserve = lib.mkOption {
                    description = "Host preservation configuration.";
                    type = lib.types.submodule {
                        options.at = lib.mkOption {
                            description = "Path to directory where files and directories are preserved. Can be set to `null` if host is not ephemeral.";
                            type = lib.types.nullOr lib.types.str;
                        };

                        options.files = lib.mkOption {
                            description = "Absolute path to files for preservation.";
                            type = lib.types.listOf lib.types.str;
                        };

                        options.directories = lib.mkOption {
                            description = "Absolute path to directories for preservation.";
                            type = lib.types.listOf lib.types.str;
                        };

                        options.partial.directories = lib.mkOption {
                            description = "Absolute path to directories for partial preservation.";
                            type = lib.types.listOf lib.types.str;
                        };
                    };
                };
                # -- Host users
                options.users = lib.mkOption {
                    description = "Users assigned to this host derived from `nyx.nixos.users.*`";
                    type = lib.types.listOf lib.types.str;
                };
                # --
            });
        };

        users = lib.mkOption {
            description = "Nyx nixos users";
            type = lib.types.attrsOf (lib.types.submodule {
                options.configuration = lib.mkOption {
                    description = "NixOS user configuration for this user.";
                    type = lib.types.raw;
                };

                #-- User specified impermanence --
                options.ephemeralfs.preserve = lib.mkOption {
                    description = "User preservation configuration.";
                    type = lib.types.submodule {
                        options.files = lib.mkOption {
                            description = "Absolute path to files for preservation.";
                            type = lib.types.listOf lib.types.str;
                        };

                        options.directories = lib.mkOption {
                            description = "Absolute path to directories for preservation.";
                            type = lib.types.listOf lib.types.str;
                        };

                        options.partial.directories = lib.mkOption {
                            description = "Absolute path to directories for partial preservation.";
                            type = lib.types.listOf lib.types.str;
                        };
                    };
                };
                # --
            });
        };
    };
}
