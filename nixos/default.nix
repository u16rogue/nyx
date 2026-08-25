{ lib, ... }: let
    aggregate_from = [ ./hosts ./users ];
in {
    imports = lib.flatten (lib.forEach aggregate_from (subdir:
        (lib.pipe (builtins.readDir subdir) [
            (lib.filterAttrs (subdir_file: file_type: file_type == "regular" && builtins.match ".*\\.nix" subdir_file != null))
            builtins.attrNames
            (builtins.map (nix_file: subdir + "/${nix_file}"))
        ])
    ));

    options.nyx.nixos.hosts = lib.mkOption {
        description = "Nyx nixos hosts";

        type = lib.types.attrsOf (lib.types.submodule {
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
            #--
        });

        default = {};
        example = {
            computer = {
                keys = {
                    pub = "ssh-ed25519 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA+bbbbbbbbbbbbb root@host";
                    prv = {
                        age = ''
                            -----BEGIN AGE ENCRYPTED FILE-----
                            ...
                            -----END AGE ENCRYPTED FILE-----
                        '';
                        sha256 = "9d1398d0544800a282ec897ad35d0fe10376b02bc5b76dcb2754477433c62504";
                    };
                };
            };
        };
    };
}
