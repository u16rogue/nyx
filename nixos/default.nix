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
                    ({ config, modulesPath, pkgs, nyxpkgs, utils, ... }: let
                        partial_users = lib.flip lib.filterAttrs nyxhost_users (_: nyxuser: nyxuser.ephemeralfs.preserve.partial.directories != []);
                        partial_directories = lib.pipe (
                            lib.optional (nyxhost.ephemeralfs.preserve.partial.directories != []) "/persist/.partial/host/current"
                            ++ lib.flip lib.mapAttrsToList partial_users (username: _: "/persist/.partial/user/${username}/current")
                        ) [
                            (prefixes: lib.genAttrs prefixes (prefix: config.preservation.preserveAt.${prefix}))
                            (lib.mapAttrs (_: state: lib.pipe (
                                state.directories ++ lib.flatten (lib.mapAttrsToList (_: user: user.directories) state.users)
                            ) [
                                (builtins.filter (entry: entry.how != "_intermediate"))
                                (builtins.map (entry: entry.directory))
                            ]))
                        ];
                        permanent = config.preservation.preserveAt."/persist";
                        permanent_directories = builtins.filter (entry: entry.how != "_intermediate") (
                            permanent.directories
                            ++ lib.flatten (lib.mapAttrsToList (_: user: user.directories) permanent.users)
                        );
                        permanent_files = permanent.files
                            ++ lib.flatten (lib.mapAttrsToList (_: user: user.files) permanent.users);
                        under = parent: path:
                            path == parent || lib.hasPrefix "${lib.removeSuffix "/" parent}/" path;
                    in {
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
                        users.users = lib.flip lib.mapAttrs nyxhost_users (username: nyxuser:
                            (nyxuser.configuration {
                                # i'd honestly prefer where `configuration` receives the same thing as what nixosSystem.modules receives
                                # as the pattern usually goes: `{ pkgs, ... }: { users.users.<name> = { ... }: {/*use pkgs*/}; }` i'll
                                # prolly expose users directly by deriving it in `modules` instead of here when i find a use case.
                                inherit pkgs nyxpkgs;
                            })
                            //
                            { hashedPasswordFile = config.age.secrets."nyx.secrets.user.${username}.password".path; }
                        );

                        preservation = {
                            enable = true;
                            preserveAt = {
                                "/persist" = {
                                    files = nyxhost.ephemeralfs.preserve.files;
                                    directories = nyxhost.ephemeralfs.preserve.directories;
                                    users = lib.flip lib.mapAttrs nyxhost_users (username: nyxuser: {
                                        files = nyxuser.ephemeralfs.preserve.files;
                                        directories = nyxuser.ephemeralfs.preserve.directories;
                                    });
                                };
                            }
                            //
                            lib.optionalAttrs (nyxhost.ephemeralfs.preserve.partial.directories != []) {
                                "/persist/.partial/host/current".directories = builtins.map (directory: {
                                    inherit directory;
                                    inInitrd = true;
                                }) nyxhost.ephemeralfs.preserve.partial.directories;
                            }
                            //
                            lib.flip lib.mapAttrs' partial_users (username: nyxuser: let
                                wholeHome = builtins.elem "/" nyxuser.ephemeralfs.preserve.partial.directories;
                            in lib.nameValuePair "/persist/.partial/user/${username}/current" {
                                directories = lib.optionals wholeHome [{
                                    directory = config.users.users.${username}.home;
                                    user = username;
                                    group = config.users.users.${username}.group;
                                    mode = config.users.users.${username}.homeMode;
                                    inInitrd = true;
                                }];
                                users.${username}.directories = builtins.map (directory: {
                                    inherit directory;
                                    inInitrd = true;
                                }) (if wholeHome then [] else nyxuser.ephemeralfs.preserve.partial.directories);
                            });
                        };

                        environment.systemPackages = [ nyxpkgs.nyx-efs ];

                        security.sudo.extraRules = lib.mapAttrsToList (username: _: {
                            users = [ username ];
                            commands = [{
                                command = "${lib.getExe nyxpkgs.nyx-efs} partial-new --user ${username}";
                                options = [ "NOPASSWD" ];
                            }];
                        }) partial_users;

                        boot.initrd.systemd.services.nyx-partial-prepare = {
                            description = "Prepare Nyx partial preservation generations";
                            requiredBy = [ "initrd-preservation.target" ];
                            requires = [ "sysroot-persist.mount" ];
                            after = [ "sysroot-persist.mount" ];
                            before = [
                                "initrd-preservation.target"
                                "systemd-tmpfiles-setup-sysroot.service"
                            ] ++ lib.pipe partial_directories [
                                builtins.attrValues
                                lib.flatten
                                (builtins.map (path: "${utils.escapeSystemdPath "/sysroot${path}"}.mount"))
                            ];
                            unitConfig.DefaultDependencies = "no";
                            path = [ pkgs.coreutils pkgs.util-linux ];
                            serviceConfig = {
                                Type = "oneshot";
                                ExecStart = pkgs.writeShellScript "nyx-partial-prepare" ''
                                    set -eu

                                    install_link() {
                                        local base="$1"
                                        local name="$2"
                                        local target="$3"
                                        local temporary="$base/.$name.$$"

                                        rm -f -- "$temporary"
                                        ln -s -- "$target" "$temporary"
                                        mv -Tf -- "$temporary" "$base/$name"
                                    }

                                    valid_link() {
                                        local base="$1"
                                        local name="$2"
                                        local target

                                        [[ -L "$base/$name" ]] || return 1
                                        target="$(readlink -- "$base/$name")"
                                        [[ "$target" =~ ^[0-9]{8}T[0-9]{6}Z-[[:alnum:]]{6}$ ]] || return 1
                                        [[ -d "$base/$target" && ! -L "$base/$target" ]]
                                    }

                                    new_generation() {
                                        local base="$1"
                                        local stamp directory

                                        stamp="$(date -u +%Y%m%dT%H%M%SZ)"
                                        directory="$(mktemp -d -- "$base/$stamp-XXXXXX")"
                                        chmod 0700 "$directory"
                                        printf '%s' "''${directory##*/}"
                                    }

                                    prepare_scope() {
                                        local base="$1"
                                        local generation target

                                        install -d -m 0700 "$base"
                                        exec {lock}>"$base/.lock"
                                        flock -x "$lock"

                                        if valid_link "$base" next; then
                                            target="$(readlink -- "$base/next")"
                                            install_link "$base" current "$target"
                                        elif [[ -e "$base/next" || -L "$base/next" ]]; then
                                            echo "nyx partial preservation: invalid next link in $base" >&2
                                            exit 1
                                        elif valid_link "$base" current; then
                                            install_link "$base" next "$(readlink -- "$base/current")"
                                        elif [[ -e "$base/current" || -L "$base/current" ]]; then
                                            echo "nyx partial preservation: invalid current link in $base" >&2
                                            exit 1
                                        else
                                            generation="$(new_generation "$base")"
                                            install_link "$base" next "$generation"
                                            install_link "$base" current "$generation"
                                        fi

                                        sync -f "$base"
                                        flock -u "$lock"
                                        eval "exec $lock>&-"
                                    }

                                    partial_target() {
                                        local base="$1"
                                        local path="$2"
                                        local current="$base/current"
                                        local component
                                        local -a components

                                        IFS=/ read -r -a components <<< "''${path#/}"
                                        for component in "''${components[@]}"; do
                                            current="$current/$component"
                                            if [[ "$current" != "$base/current$path" ]]; then
                                                [[ ! -L "$current" ]] || return 1
                                                if [[ ! -e "$current" ]]; then
                                                    mkdir -- "$current"
                                                fi
                                                [[ -d "$current" ]] || return 1
                                            fi
                                        done
                                        printf '%s' "$current"
                                    }

                                    normalize_directory() {
                                        local target
                                        target="$(partial_target "$1" "$2")"
                                        if [[ -e "$target" || -L "$target" ]] && [[ ! -d "$target" || -L "$target" ]]; then
                                            rm -rf -- "$target"
                                        fi
                                        mkdir -p -- "$target"
                                    }

                                    normalize_file() {
                                        local target
                                        target="$(partial_target "$1" "$2")"
                                        if [[ -e "$target" || -L "$target" ]] && [[ ! -f "$target" || -L "$target" ]]; then
                                            rm -rf -- "$target"
                                        fi
                                    }

                                    remove_path() {
                                        local target
                                        target="$(partial_target "$1" "$2")"
                                        rm -rf -- "$target"
                                    }

                                    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (prefix: directories: let
                                        base = lib.escapeShellArg "/sysroot${lib.removeSuffix "/current" prefix}";
                                        covered = entry: lib.any (path: under path (entry.directory or entry.file)) directories;
                                    in ''
                                        prepare_scope ${base}
                                        ${lib.concatMapStringsSep "\n" (path: "normalize_directory ${base} ${lib.escapeShellArg path}") directories}
                                        ${lib.pipe permanent_directories [
                                            (builtins.filter (entry: entry.how == "bindmount" && covered entry))
                                            (lib.concatMapStringsSep "\n" (entry: "normalize_directory ${base} ${lib.escapeShellArg entry.directory}"))
                                        ]}
                                        ${lib.pipe permanent_files [
                                            (builtins.filter (entry: entry.how == "bindmount" && covered entry))
                                            (lib.concatMapStringsSep "\n" (entry: "normalize_file ${base} ${lib.escapeShellArg entry.file}"))
                                        ]}
                                        ${lib.pipe (permanent_directories ++ permanent_files) [
                                            (builtins.filter (entry: entry.how == "symlink" && covered entry))
                                            (lib.concatMapStringsSep "\n" (entry: "remove_path ${base} ${lib.escapeShellArg (entry.directory or entry.file)}"))
                                        ]}
                                    '') partial_directories)}
                                '';
                            };
                        };

                        age = {
                            identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
                            secrets = lib.flip lib.mapAttrs' nyxhost_users (username: nyxuser: lib.nameValuePair "nyx.secrets.user.${username}.password" {
                                file = pkgs.writeText "nyx.secrets.user.${username}.password" nyxuser.password;
                                mode = "0400";
                            });
                        };

                        assertions = let
                            validateComponents = path: lib.all (component: component != "" && component != "." && component != "..") (lib.splitString "/" path);
                            validateHostPath = path: lib.hasPrefix "/" path && path != "/" && validateComponents (lib.removePrefix "/" path);
                            validateUserPath = path: path == "/" || (!lib.hasPrefix "/" path && validateComponents path);
                            reserved_paths = [ "/boot" "/dev" "/nix" "/persist" "/proc" "/run" "/sys" ];
                            partial_paths = lib.flatten (builtins.attrValues partial_directories);
                            permanent_paths = builtins.map (entry: entry.directory) permanent_directories
                                ++ builtins.map (entry: entry.file) permanent_files;
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
                            {
                                assertion = lib.all validateHostPath nyxhost.ephemeralfs.preserve.partial.directories;
                                message = "nyx host partial directories must be normalized absolute paths other than /";
                            }
                            {
                                assertion = lib.all (path:
                                    !lib.any (reserved: under reserved path) reserved_paths
                                ) nyxhost.ephemeralfs.preserve.partial.directories;
                                message = "nyx host partial directories must not be inside a boot-critical or persistent filesystem";
                            }
                            {
                                assertion = lib.all (nyxuser:
                                    lib.all validateUserPath nyxuser.ephemeralfs.preserve.partial.directories
                                ) (builtins.attrValues partial_users);
                                message = "nyx user partial directories must be normalized home-relative paths; / selects the whole home";
                            }
                            {
                                assertion = lib.all validateHostPath partial_paths
                                    && lib.all (path: !lib.any (reserved: under reserved path) reserved_paths) partial_paths;
                                message = "nyx partial directories must resolve to safe normalized absolute paths";
                            }
                            {
                                assertion = builtins.length partial_paths == builtins.length (lib.unique partial_paths);
                                message = "nyx partial directories must not resolve to the same path across host and user scopes";
                            }
                            {
                                assertion = lib.all (partialPath:
                                    !lib.any (permanentPath: under permanentPath partialPath) permanent_paths
                                ) partial_paths;
                                message = "nyx partial directories must not be inside permanently preserved paths";
                            }
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
                            default = [];
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
                            description = "Home-relative paths to directories for partial preservation. / selects the entire home.";
                            type = lib.types.listOf lib.types.str;
                            default = [];
                        };
                    };
                };
            });
        };
    };
}
