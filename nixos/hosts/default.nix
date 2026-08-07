{ lib, ... }: {
    imports = lib.pipe (builtins.readDir ./.) [
        (lib.filterAttrs (name: value:
            value == "regular"
            && name != "default.nix"
            && builtins.match ".*\\.nix" name != null))
        builtins.attrNames
        (builtins.map (name: ./. + "/${name}"))
    ];

    # Allow nyx nixos hosts to define their ssh keys
    # via `nyx.nixos.hosts.<hostname>.keys = { pub = "<pubkey>"; prv = "<sym encrypted armor>"}`
    options.nyx.nixos.hosts = lib.mkOption {
        description = "Nyx nixos hosts";

        type = lib.types.attrsOf (lib.types.submodule {
            # --
            options.keys = lib.mkOption {
                description = "SSH host keys used for ssh and secrets management.";
                type = lib.types.submodule {
                    options.pub = lib.mkOption {
                        type = lib.types.strMatching "^ssh-ed25519 [A-Za-z0-9+/]+={0,3}( .*)?$";
                        description = "Required SSH ED25519 public host key.";
                        example = "ssh-ed25519 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA+bbbbbbbbbbbbb root@host";
                    };
                    options.prv = lib.mkOption {
                        type = lib.types.nullOr lib.types.str;
                        description = "Optional armored encrypted backup of the host private key. Can be used to apply it on the host or as a backup.";
                        example = ''
                            -----BEGIN AGE ENCRYPTED FILE-----
                            ...
                            -----END AGE ENCRYPTED FILE-----
                        '';
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
                    prv = null;
                };
            };
        };
    };
}
