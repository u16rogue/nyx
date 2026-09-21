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
        timeZone.enable = true;
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
                [ (sloth.mkdir (sloth.concat' sloth.runtimeDir "/nyx/moonlight-stream")) "/tmp" ]
            ];
            env = {
                HOME = sloth.env "HOME";
                XDG_RUNTIME_DIR = sloth.runtimeDir;
                XDG_CURRENT_DESKTOP = sloth.env "XDG_CURRENT_DESKTOP";
                PIPEWIRE_REMOTE = sloth.envOr "PIPEWIRE_REMOTE" "pipewire-0";
                PIPEWIRE_RUNTIME_DIR = sloth.envOr "PIPEWIRE_RUNTIME_DIR" sloth.runtimeDir;
                PULSE_SERVER = sloth.envOr "PULSE_SERVER" (sloth.concat [ "unix:" sloth.runtimeDir "/pulse/native" ]);
                PULSE_RUNTIME_PATH = sloth.envOr "PULSE_RUNTIME_PATH" sloth.runtimeDir;
                WAYLAND_DISPLAY = sloth.envOr "WAYLAND_DISPLAY" "wayland-0";
            };
        };
    };
}).config.env
