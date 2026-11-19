{ inputs, pkgs, qt5, dejavu_fonts, keepassxc, ... }: let
    mkNixPak = inputs.nixpak.lib.nixpak {
        inherit (pkgs) lib;
        inherit pkgs;
    };
in (mkNixPak {
    config = { sloth, ... }: {
        app = {
            package = inputs.wrappers.lib.wrapPackage {
                inherit pkgs;
                package = keepassxc;
                flags."--config" = pkgs.writeText "keepassxc.ini" (builtins.readFile ./keepassxc.ini);
            };
            binPath = "bin/keepassxc";
        };

        flatpak.appId = "org.keepassxc.KeePassXC";
        timeZone.enable = true;
        dbus.policies."org.freedesktop.portal.Desktop" = "talk";
        fonts = {
            enable = true;
            fonts = [ dejavu_fonts ];
        };
        bubblewrap = {
            network = false;
            bindEntireStore = false;
            clearEnv = true;
            newSession = true;
            dieWithParent = true;
            extraStorePaths = [ qt5.qtwayland.bin ];
            sockets.wayland = true;

            bind.rw = [
                [ (sloth.mkdir (sloth.concat [ (sloth.env "HOME") "/.nyx/app-fake-root/keepassxc/" (sloth.env "HOME") ])) (sloth.env "HOME") ]
                [ (sloth.mkdir (sloth.concat' sloth.runtimeDir "/nyx/keepassxc")) "/tmp" ]
                [ (sloth.concat' sloth.runtimeDir "/doc/by-app/org.keepassxc.KeePassXC") (sloth.concat' sloth.runtimeDir "/doc") ]
            ];

            env = {
                HOME = sloth.env "HOME";
                XDG_RUNTIME_DIR = sloth.runtimeDir;
                XDG_CURRENT_DESKTOP = sloth.env "XDG_CURRENT_DESKTOP";
                WAYLAND_DISPLAY = sloth.envOr "WAYLAND_DISPLAY" "wayland-0";
                QT_QPA_PLATFORM = "wayland";
                QT_QPA_PLATFORMTHEME = "xdgdesktopportal";
                QT_PLUGIN_PATH  = "${qt5.qtwayland.bin}/lib/qt-${qt5.qtbase.version}/plugins:${qt5.qtbase.bin}/lib/qt-${qt5.qtbase.version}/plugins";
                TMPDIR = "/tmp";
            };
        };
    };
}).config.env
