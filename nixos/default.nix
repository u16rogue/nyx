{ config, inputs, lib, self, ... }: {
    # TODO: make this more linear by using builtins.map [fn] [val] instead then pipe to have lib.flatten at the end
    imports = lib.flatten (lib.forEach [ ./hosts ./users ./modules ] (subdir:
        (lib.pipe (builtins.readDir subdir) [
            (lib.filterAttrs (filename: filetype: filetype == "regular" && builtins.match ".*\\.nix" filename != null))
            builtins.attrNames
            (builtins.map (filename: subdir + "/${filename}"))
        ])
    ));

    config.flake.nixosConfigurations = lib.pipe config.nyx.nixos.hosts [
        (lib.mapAttrs (hostname: nyxhost: (inputs.nixpkgs.lib.nixosSystem {
            specialArgs = { inherit inputs self; };
            modules = [
                # config.nyx.nixos.hosts.${hostname}.configuration
                nyxhost.configuration 
                {
                    networking.hostName = lib.mkDefault "${hostname}";
                    system.stateVersion = lib.mkDefault "25.11";
                }
            ];
        })))
    ];

    options.nyx.nixos = {
        hosts = lib.mkOption {
            description = "Nyx nixos hosts";

            type = lib.types.attrsOf (lib.types.submodule {
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
                                    type = lib.types.str;
                                    description = "Armored encrypted backup of the host private key. Can be used to apply it on the host or as a backup.";
                                    example = ''
                                        -----BEGIN AGE ENCRYPTED FILE-----
                                        ...
                                        -----END AGE ENCRYPTED FILE-----
                                    '';
                                };
                                options.sha256 = lib.mkOption {
                                    type = lib.types.str;
                                    description = "SHA256 hash of the hosts private key.";
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
                    type = lib.types.deferredModule;
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
