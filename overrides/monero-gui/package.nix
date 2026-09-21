{ inputs, pkgs, monero-gui, ... }: let
    mkNixPak = inputs.nixpak.lib.nixpak {
        inherit (pkgs) lib;
        inherit pkgs;
    };
in (mkNixPak {
    config = { sloth, ... }: {
        app = {
            package = monero-gui;
            binPath = "bin/monero-wallet-gui";
        };
        flatpak.appId = "org.getmonero.monero-wallet-gui";
        dbus.policies."org.freedesktop.portal.Desktop" = "talk";
        etc.sslCertificates.enable = true;
        fonts.enable = true;
        gpu.enable = true;
        bubblewrap = {
            network = true;
            bindEntireStore = false;
            clearEnv = true;
            newSession = true;
            dieWithParent = true;
            sockets = {
                wayland = true;
                x11 = true;
            };
            bind.rw = [
                [ (sloth.mkdir (sloth.concat [ (sloth.env "HOME") "/.nyx/app-fake-root/monero-gui/" (sloth.env "HOME") ])) (sloth.env "HOME") ]
                [ (sloth.mkdir (sloth.concat' sloth.runtimeDir "/nyx/monero-gui")) "/tmp" ]
                (sloth.concat' sloth.runtimeDir "/doc")
            ];
            env = {
                HOME = sloth.env "HOME";
                XDG_RUNTIME_DIR = sloth.runtimeDir;
                WAYLAND_DISPLAY = sloth.envOr "WAYLAND_DISPLAY" "wayland-0";
            };
        };
    };
}).config.env
