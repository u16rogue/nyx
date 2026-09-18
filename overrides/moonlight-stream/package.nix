{ inputs, pkgs, moonlight-qt, ... }: let
    mkNixPak = inputs.nixpak.lib.nixpak {
        inherit (pkgs) lib;
        inherit pkgs;
    };
in (mkNixPak {
    config = { sloth, ... }: {
        app = {
            package = moonlight-qt;
            binPath = "bin/moonlight";
        };
        flatpak.appId = "com.moonlight_stream.Moonlight";
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
                pulse = true;
            };
            bind.rw = [
                [ (sloth.mkdir (sloth.concat [ (sloth.env "HOME") "/.nyx/app-fake-root/moonlight-stream/" (sloth.env "HOME") ])) (sloth.env "HOME") ]
                [ (sloth.mkdir "/tmp/.nyx-tmp/moonlight-stream") "/tmp" ]
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
