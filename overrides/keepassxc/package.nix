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
                [ (sloth.mkdir (sloth.concat [ (sloth.env "HOME") "/.nyx/app-fake-root/keepassxc/" (sloth.env "HOME") ])) (sloth.env "HOME") ]
                [ (sloth.mkdir (sloth.concat' sloth.runtimeDir "/nyx/keepassxc")) "/tmp" ]
                (sloth.concat' sloth.runtimeDir "/doc") # for document portal
            ];

            env = {
                HOME = sloth.env "HOME";
                XDG_RUNTIME_DIR = sloth.runtimeDir;
                XDG_CURRENT_DESKTOP = sloth.env "XDG_CURRENT_DESKTOP";
                WAYLAND_DISPLAY = sloth.envOr "WAYLAND_DISPLAY" "wayland-0";
                QT_QPA_PLATFORM = "wayland";
                QT_QPA_PLATFORMTHEME = "xdgdesktopportal";
                QT_PLUGIN_PATH  = "${pkgs.qt5.qtwayland.bin}/lib/qt-${pkgs.qt5.qtbase.version}/plugins:${pkgs.qt5.qtbase.bin}/lib/qt-${pkgs.qt5.qtbase.version}/plugins";
                TMPDIR = "/tmp";
            };
        };
    };
}).config.env
