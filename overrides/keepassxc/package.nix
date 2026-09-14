{ inputs, pkgs, ... }: let
    keepassxc = inputs.wrappers.lib.wrapPackage {
        inherit pkgs;
        package = pkgs.keepassxc;
        flags."--config" = pkgs.writeText "keepassxc.ini" (builtins.readFile ./keepassxc.ini);
    };
    mkNixPak = inputs.nixpak.lib.nixpak {
        inherit (pkgs) lib;
        inherit pkgs;
    };
in (mkNixPak {
    config = { sloth, ... }: {
        app = {
            package = keepassxc;
            binPath = "bin/keepassxc";
        };

        flatpak.appId = "org.keepassxc.KeePassXC";
        dbus.policies."org.freedesktop.portal.Desktop" = "talk";
        fonts = {
            enable = true;
            fonts = [ pkgs.dejavu_fonts ];
        };
        bubblewrap = {
            network = false;
            bindEntireStore = false;
            clearEnv = true;
            newSession = true;
            dieWithParent = true;
            extraStorePaths = [ pkgs.qt5.qtwayland.bin ];
            sockets.wayland = true;

            bind.rw = [
                [ (sloth.mkdir (sloth.concat [ (sloth.env "HOME") "/.emulated-root/keepassxc/" (sloth.env "HOME") ])) (sloth.env "HOME") ]
                [ (sloth.mkdir "/tmp/.emulated-tmp/keepassxc") "/tmp" ]
                (sloth.concat' sloth.runtimeDir "/doc") # for document portal
            ];

            env = let
                resolveHomePath = appends: (sloth.concat' (sloth.env "HOME") "${appends}");
            in {
                HOME = sloth.env "HOME";
                XDG_RUNTIME_DIR = sloth.runtimeDir;
                WAYLAND_DISPLAY = sloth.envOr "WAYLAND_DISPLAY" "wayland-0";
                QT_QPA_PLATFORM = "wayland";
                QT_QPA_PLATFORMTHEME = "xdgdesktopportal";
                QT_PLUGIN_PATH  = "${pkgs.qt5.qtwayland.bin}/lib/qt-${pkgs.qt5.qtbase.version}/plugins:${pkgs.qt5.qtbase.bin}/lib/qt-${pkgs.qt5.qtbase.version}/plugins";
                XDG_CACHE_HOME  = resolveHomePath "/.cache";
                XDG_CONFIG_HOME = resolveHomePath "/.config";
                XDG_DATA_HOME   = resolveHomePath "/.local/share";
                XDG_STATE_HOME  = resolveHomePath "/.local/state";
                TMPDIR = "/tmp";
            };
        };
    };
}).config.env
