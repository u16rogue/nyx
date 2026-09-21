{ inputs, pkgs, lib, ... }: let
    mkNixPak = inputs.nixpak.lib.nixpak {
        inherit (pkgs) lib;
        inherit pkgs;
    };
in (mkNixPak {
    config = { sloth, ... }: {
        app.package = inputs.wrappers.lib.wrapPackage {
            inherit pkgs;
            package = pkgs.vesktop;
            wrapper = { exePath, ... }: /*bash*/ ''
                config_dir="$HOME/.config/vesktop"
                ${pkgs.coreutils}/bin/mkdir -p "$config_dir/settings"
                ${pkgs.coreutils}/bin/ln -sfnT "${./discord-settings.json}" "$config_dir/settings.json"
                ${pkgs.coreutils}/bin/ln -sfnT "${./quickCss.css}" "$config_dir/settings/quickCss.css"
                if [[ ! -e "$config_dir/state.json" ]]; then
                    ${pkgs.coreutils}/bin/cp "${./state.json}" "$config_dir/state.json"
                    ${pkgs.coreutils}/bin/chmod u+w "$config_dir/state.json"
                fi
                if [[ ! -e "$config_dir/settings/settings.json" ]]; then
                    ${pkgs.coreutils}/bin/cp "${./vesktop-settings.json}" "$config_dir/settings/settings.json"
                    ${pkgs.coreutils}/bin/chmod u+w "$config_dir/settings/settings.json"
                fi

                exec ${exePath} --enable-features=WebRTCPipeWireCapturer --ozone-platform=wayland "$@"
            '';
        };
        app.binPath = "bin/vesktop";
        flatpak.appId = "dev.vencord.Vesktop";
        timeZone.enable = true;
        dbus.policies = {
            "org.freedesktop.Notifications" = "talk";
            "org.freedesktop.portal.Desktop" = "talk";
        };
        fonts.enable = true;
        etc.sslCertificates.enable = true;
        gpu.enable = true;
        bubblewrap = {
            network = true;
            bindEntireStore = false;
            clearEnv = true;
            newSession = true;
            dieWithParent = true;
            sockets = {
                wayland = true;
                pipewire = true;
                pulse = true;
            };

            bind.rw = [
                [ (sloth.mkdir (sloth.concat [ (sloth.env "HOME") "/.nyx/app-fake-root/vesktop/" (sloth.env "HOME") ])) (sloth.env "HOME") ]
                [ (sloth.mkdir (sloth.concat' sloth.runtimeDir "/nyx/vesktop")) "/tmp" ]
                (sloth.concat' sloth.runtimeDir "/doc") # for document portal
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
                NIXOS_OZONE_WL = "1";
            };
        };
    };
}).config.env
