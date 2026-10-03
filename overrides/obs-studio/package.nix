{ inputs, pkgs, obs-studio, ... }: let
    mkNixPak = inputs.nixpak.lib.nixpak {
        inherit (pkgs) lib;
        inherit pkgs;
    };
in (mkNixPak {
    config = { sloth, ... }: {
        app = {
            package = obs-studio;
            binPath = "bin/obs";
        };
        flatpak.appId = "com.obsproject.Studio";
        timeZone.enable = true;
        dbus.policies = {
            "org.freedesktop.portal.Desktop" = "talk";
            "org.freedesktop.Notifications" = "talk";
        };
        etc.sslCertificates.enable = true;
        fonts.enable = true;
        gpu.enable = true;
        bubblewrap = {
            network = false; # dont think i need it
            bindEntireStore = true;
            clearEnv = true;
            newSession = true;
            dieWithParent = true;
            sockets = {
                wayland = true;
                pipewire = true;
                pulse = true;
            };
            bind.dev = [
                # NVIDIA's NVENC own device nodes.
                "/dev/nvidia0"
                "/dev/nvidiactl"
                "/dev/nvidia-modeset"
                "/dev/nvidia-uvm"
                "/dev/nvidia-uvm-tools"
                "/dev/nvidia-caps"
            ];
            bind.rw = [
                [ (sloth.mkdir (sloth.concat [ (sloth.env "HOME") "/.nyx/app-fake-root/obs-studio/" (sloth.env "HOME") ])) (sloth.env "HOME") ]
                [ (sloth.mkdir (sloth.concat' sloth.runtimeDir "/nyx/obs-studio")) "/tmp" ]
                (sloth.concat' sloth.runtimeDir "/doc") # Files selected through the document portal.
                # OBS's default Videos directory maps to the user's preserved media directory.
                [ (sloth.mkdir (sloth.concat' sloth.homeDir "/media/obs")) (sloth.concat' sloth.homeDir "/Videos") ]
            ];
            env = {
                HOME = sloth.env "HOME";
                XDG_RUNTIME_DIR = sloth.runtimeDir;
                XDG_CURRENT_DESKTOP = sloth.env "XDG_CURRENT_DESKTOP";
                XDG_SESSION_DESKTOP = sloth.env "XDG_SESSION_DESKTOP";
                XDG_SESSION_TYPE = sloth.envOr "XDG_SESSION_TYPE" "wayland";
                PIPEWIRE_REMOTE = sloth.envOr "PIPEWIRE_REMOTE" "pipewire-0";
                PIPEWIRE_RUNTIME_DIR = sloth.envOr "PIPEWIRE_RUNTIME_DIR" sloth.runtimeDir;
                PULSE_SERVER = sloth.envOr "PULSE_SERVER" (sloth.concat [ "unix:" sloth.runtimeDir "/pulse/native" ]);
                PULSE_RUNTIME_PATH = sloth.envOr "PULSE_RUNTIME_PATH" sloth.runtimeDir;
                WAYLAND_DISPLAY = sloth.envOr "WAYLAND_DISPLAY" "wayland-0";
                QT_QPA_PLATFORM = "wayland";
                QT_QPA_PLATFORMTHEME = "xdgdesktopportal"; # Host file picker with document exports.
            };
        };
    };
}).config.env
