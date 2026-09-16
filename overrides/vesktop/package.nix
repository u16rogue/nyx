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
                [[ ! -e "$config_dir/state.json" ]] && ${pkgs.coreutils}/bin/ln -sfnT "${./state.json}" "$config_dir/state.json";
                # These might be better as copy operations as it seems like vesktop does not do atomic replace
                [[ ! -e "$config_dir/settings/settings.json" ]] && ${pkgs.coreutils}/bin/cp "${./vesktop-settings.json}" "$config_dir/settings/settings.json";

                exec ${exePath} --enable-features=WebRTCPipeWireCapturer --ozone-platform=wayland "$@"
            '';
        };
        app.binPath = "bin/vesktop";
        flatpak.appId = "dev.vencord.Vesktop";
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
                [ (sloth.mkdir "/tmp/.nyx-tmp/vesktop") "/tmp" ]
                (sloth.concat' sloth.runtimeDir "/doc") # for document portal
            ];

            env = {
                HOME = sloth.env "HOME";
                XDG_RUNTIME_DIR = sloth.runtimeDir;
                WAYLAND_DISPLAY = sloth.envOr "WAYLAND_DISPLAY" "wayland-0";
                NIXOS_OZONE_WL = "1";
            };
        };
    };
}).config.env
