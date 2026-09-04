{ config, lib, pkgs, utils, nyxPartial, nyxpkgs, ... }:

let
    cfg = nyxPartial;
    partialUsers = lib.filterAttrs (_: user: user.directories != []) cfg.users;
    enabled = cfg.rootEnable || cfg.directories != [] || partialUsers != {};
    storageRelativeToPersist = lib.removePrefix "/persist" cfg.storagePath;
    storagePathComponents = lib.splitString "/" (lib.removePrefix "/persist/" cfg.storagePath);
    initrdStoragePath = "/sysroot/persist${storageRelativeToPersist}";
    temporaryPersistPath = "/run/nyx-partial-persist";

    directoryPath = entry: if builtins.isString entry then entry else entry.directory;
    filePath = entry: if builtins.isString entry then entry else entry.file;
    permanent = config.preservation.preserveAt."/persist";
    permanentDirectories = permanent.directories
        ++ lib.flatten (lib.mapAttrsToList (_: user: user.directories) permanent.users);
    permanentFiles = permanent.files
        ++ lib.flatten (lib.mapAttrsToList (_: user: user.files) permanent.users);
    permanentDirectoryPaths = builtins.map directoryPath permanentDirectories;
    permanentFilePaths = builtins.map filePath permanentFiles;
    isPermanentlyCovered = path:
        builtins.elem path permanentFilePaths
        || lib.any (permanentPath:
            path == permanentPath || lib.hasPrefix "${lib.removeSuffix "/" permanentPath}/" path
        ) permanentDirectoryPaths;
    partialDirectories = builtins.filter
        (entry: !isPermanentlyCovered (directoryPath entry))
        cfg.directories;
    filteredPartialUsers = lib.mapAttrs (username: user: {
        directories = builtins.filter (entry:
            let
                path = directoryPath entry;
                absolutePath = "${config.users.users.${username}.home}/${lib.removePrefix "/" path}";
            in !isPermanentlyCovered absolutePath
        ) user.directories;
    }) partialUsers;

    preservationConfigs = builtins.attrValues config.preservation.preserveAt;
    preservationDirectories = lib.flatten (builtins.map (preserveAt:
        preserveAt.directories
        ++ lib.flatten (lib.mapAttrsToList (_: user: user.directories) preserveAt.users)
    ) preservationConfigs);
    preservationFiles = lib.flatten (builtins.map (preserveAt:
        preserveAt.files
        ++ lib.flatten (lib.mapAttrsToList (_: user: user.files) preserveAt.users)
    ) preservationConfigs);
    initrdBindPaths = lib.pipe (preservationDirectories ++ preservationFiles) [
        (builtins.filter (entry: entry.inInitrd && entry.how == "bindmount"))
        (builtins.map (entry: if entry ? directory then entry.directory else entry.file))
    ];
    initrdBindMountUnits = builtins.map
        (path: "${utils.escapeSystemdPath "/sysroot${path}"}.mount")
        initrdBindPaths;
    initrdRootSubmountUnits = lib.pipe config.boot.initrd.systemd.mounts [
        (builtins.filter (mount:
            cfg.rootEnable
            && lib.hasPrefix "/sysroot/" mount.where
            && mount.where != "/sysroot/persist"
        ))
        (builtins.map (mount: "${utils.escapeSystemdPath mount.where}.mount"))
    ];
    permanentSymlinkPaths = lib.pipe (permanentDirectories ++ permanentFiles) [
        (builtins.filter (entry: entry.how == "symlink"))
        (builtins.map (entry: if entry ? directory then entry.directory else entry.file))
    ];
    permanentBindDirectoryPaths = lib.pipe permanentDirectories [
        (builtins.filter (entry: entry.how == "bindmount"))
        (builtins.map (entry: entry.directory))
    ];
    permanentBindFilePaths = lib.pipe permanentFiles [
        (builtins.filter (entry: entry.how == "bindmount"))
        (builtins.map (entry: entry.file))
    ];

    prepareScript = pkgs.writeShellScript "nyx-partial-prepare" ''
        set -eu

        base=${lib.escapeShellArg initrdStoragePath}
        generations="$base/generations"

        install_link() {
            local name="$1"
            local target="$2"
            local temporary="$base/.$name.$$"

            rm -f -- "$temporary"
            ln -s -- "$target" "$temporary"
            mv -Tf -- "$temporary" "$base/$name"
        }

        valid_link() {
            local name="$1"
            local target generation

            [[ -L "$base/$name" ]] || return 1
            target="$(readlink -- "$base/$name")"
            case "$target" in
                generations/*) ;;
                *) return 1 ;;
            esac

            generation="''${target#generations/}"
            [[ "$generation" =~ ^[0-9]{8}T[0-9]{6}-[[:alnum:]]{6}$ ]] || return 1
            [[ -d "$generations/$generation" && ! -L "$generations/$generation" ]] || return 1
            [[ -d "$generations/$generation/root" && ! -L "$generations/$generation/root" ]] || return 1
        }

        new_generation() {
            local stamp directory generation
            stamp="$(date -u +%Y%m%dT%H%M%S)"
            directory="$(mktemp -d -- "$generations/$stamp-XXXXXX")"
            generation="''${directory##*/}"
            chmod 0700 "$directory"
            mkdir -m 0755 "$directory/root"
            printf '%s' "$generation"
        }

        normalize_bind_directory() {
            local path="$1"
            local target
            [[ -n "$path" && "$path" != "/" ]] || return 0
            target="$(partial_target "$path")"
            if [[ -e "$target" || -L "$target" ]] && [[ ! -d "$target" || -L "$target" ]]; then
                rm -rf -- "$target"
            fi
            mkdir -p -- "$target"
        }

        normalize_bind_file() {
            local path="$1"
            local target
            [[ -n "$path" && "$path" != "/" ]] || return 0
            target="$(partial_target "$path")"
            if [[ -e "$target" || -L "$target" ]] && [[ ! -f "$target" || -L "$target" ]]; then
                rm -rf -- "$target"
            fi
        }

        remove_partial_path() {
            local path="$1"
            local target
            [[ -n "$path" && "$path" != "/" ]] || return 0
            target="$(partial_target "$path")"
            rm -rf -- "$target"
        }

        partial_target() {
            local path="$1"
            local current="$base/current/root"
            local component
            local -a components

            [[ "$path" == /* ]] || return 1
            case "/''${path#/}/" in
                *//*|*/./*|*/../*) return 1 ;;
            esac
            IFS=/ read -r -a components <<< "''${path#/}"
            for component in "''${components[@]}"; do
                [[ -n "$component" && "$component" != "." && "$component" != ".." ]] || return 1
                current="$current/$component"
                if [[ "$current" != "$base/current/root$path" ]]; then
                    [[ ! -L "$current" ]] || return 1
                    [[ ! -e "$current" || -d "$current" ]] || return 1
                fi
            done
            printf '%s' "$current"
        }

        if [[ "$(realpath -m -- "$base")" != "$base" || -L "$base" || -L "$generations" ]]; then
            echo "nyx partial preservation: storage directories must not be symlinks" >&2
            exit 1
        fi
        mkdir -p -m 0700 "$generations"
        chmod 0700 "$base" "$generations"
        exec 9>"$base/.lock"
        flock -x 9

        if valid_link next; then
            install_link current "$(readlink -- "$base/next")"
            rm -f -- "$base/next"
            sync -f "$base"
        elif [[ -e "$base/next" || -L "$base/next" ]]; then
            echo "nyx partial preservation: ignoring invalid next generation" >&2
        fi

        if ! valid_link current && [[ -e "$base/current" || -L "$base/current" ]]; then
            echo "nyx partial preservation: current generation is invalid" >&2
            exit 1
        elif ! valid_link current; then
            generation="$(new_generation)"
            install_link current "generations/$generation"
            sync -f "$generations/$generation"
            sync -f "$base"
        fi

        mkdir -p -m 0755 "$base/current/root"

        # Permanent entries are mounted or linked later and always take
        # precedence. Remove stale partial entries of an incompatible type.
        ${lib.concatMapStringsSep "\n" (path:
            "normalize_bind_directory ${lib.escapeShellArg path}"
        ) permanentBindDirectoryPaths}
        ${lib.concatMapStringsSep "\n" (path:
            "normalize_bind_file ${lib.escapeShellArg path}"
        ) permanentBindFilePaths}
        ${lib.concatMapStringsSep "\n" (path:
            "remove_partial_path ${lib.escapeShellArg path}"
        ) permanentSymlinkPaths}

        ${lib.optionalString cfg.rootEnable ''
            # Keep the persistent filesystem reachable while its generation is
            # mounted over /sysroot, then put it back inside the selected root.
            normalize_bind_directory /persist
            normalize_bind_directory /nix
            normalize_bind_directory /boot
            normalize_bind_directory /run
            mkdir -p -m 0755 ${lib.escapeShellArg temporaryPersistPath}
            mount --bind /sysroot/persist ${lib.escapeShellArg temporaryPersistPath}

            selected=${lib.escapeShellArg "${temporaryPersistPath}${storageRelativeToPersist}/current/root"}
            if ! mount --bind "$selected" /sysroot; then
                echo "nyx partial preservation: root bind failed; retaining tmpfs root" >&2
                umount ${lib.escapeShellArg temporaryPersistPath}
                exit 0
            fi

            mkdir -p -m 0755 /sysroot/persist
            if ! mount --bind ${lib.escapeShellArg temporaryPersistPath} /sysroot/persist; then
                echo "nyx partial preservation: persist bind failed; retaining tmpfs root" >&2
                umount /sysroot
                umount ${lib.escapeShellArg temporaryPersistPath}
                exit 0
            fi
            umount ${lib.escapeShellArg temporaryPersistPath}
        ''}
    '';
in {
    assertions = lib.optionals enabled [
        {
            assertion = lib.hasPrefix "/persist/" cfg.storagePath
                && lib.all (component: component != "" && component != "." && component != "..") storagePathComponents;
            message = "nyx partial preservation storagePath must be a normalized path strictly below /persist";
        }
        {
            assertion = !builtins.elem "/" (builtins.map
                (entry: if builtins.isString entry then entry else entry.directory)
                cfg.directories);
            message = "Use ephemeralfs.preserve.partial.root.enable instead of listing / as a partial directory";
        }
        {
            assertion = lib.all (entry: lib.hasPrefix "/" (directoryPath entry)) cfg.directories;
            message = "nyx host partial directories must use absolute paths";
        }
        {
            assertion = lib.all (user:
                lib.all (entry: !lib.hasPrefix "/" (directoryPath entry)) user.directories
            ) (builtins.attrValues cfg.users);
            message = "nyx user partial directories must use home-relative paths";
        }
    ];

    preservation.preserveAt = lib.mkIf (enabled && !cfg.rootEnable) {
        "${cfg.storagePath}/current/root" = {
            directories = partialDirectories;
            users = lib.mapAttrs (_: user: { directories = user.directories; }) filteredPartialUsers;
        };
    };

    environment.systemPackages = lib.optionals enabled [ nyxpkgs.nyx ];
    environment.variables.NYX_PARTIAL_STORAGE = lib.mkIf enabled cfg.storagePath;

    boot.initrd.systemd.services.nyx-partial-prepare = lib.mkIf enabled {
        description = "Prepare the Nyx partial preservation generation";
        wantedBy = [ "initrd.target" ];
        requires = [ "sysroot-persist.mount" ];
        after = [ "sysroot-persist.mount" ];
        before = [
            "initrd-root-fs.target"
            "initrd-preservation.target"
            "systemd-tmpfiles-setup-sysroot.service"
        ] ++ initrdBindMountUnits ++ initrdRootSubmountUnits;
        unitConfig.DefaultDependencies = "no";
        path = [ pkgs.coreutils pkgs.util-linux ];
        serviceConfig = {
            Type = "oneshot";
            ExecStart = prepareScript;
        };
    };
}
