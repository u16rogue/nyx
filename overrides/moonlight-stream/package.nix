{ inputs, pkgs, overridesOpts ? {}, ... }: let
    mkNixPak = inputs.nixpak.lib.nixpak {
        inherit (pkgs) lib;
        inherit pkgs;
    };
    jailedMoonlight = let
        jail = inputs.jail-nix.lib.init pkgs;
        moonlight-qt' = jail "moonlight-jail-nix-tmpfix" pkgs.moonlight-qt (with jail.combinators; [
                network
                gui
                gpu
                (rw-bind (noescape "~/.nyx/app-fake-root/moonlight-stream/home/user") (noescape "~"))
                (add-runtime /*bash*/ ''
                    # NVIDIA requires these device nodes in addition to /dev/dri.
                    for device in /dev/nvidia*; do
                        [[ -e "$device" ]] && RUNTIME_ARGS+=(--dev-bind "$device" "$device")
                    done
                '')
            ]);
        in pkgs.runCommand "moonlight-jailed" { meta.mainProgram = "moonlight-jail-nix-tmpfix"; } ''
            mkdir -p $out/share/applications
            ln -s ${moonlight-qt'}/bin $out/bin
            ln -s ${pkgs.moonlight-qt}/share/icons $out/share/icons
            cp ${pkgs.moonlight-qt}/share/applications/com.moonlight_stream.Moonlight.desktop \
                $out/share/applications/com.moonlight_stream.Moonlight-jail-nix-tmpfix.desktop
            substituteInPlace $out/share/applications/com.moonlight_stream.Moonlight-jail-nix-tmpfix.desktop \
                --replace-fail 'Name=Moonlight' 'Name=Moonlight (jail.nix tmpfix)' \
                --replace-fail 'Exec=moonlight' 'Exec=${moonlight-qt'}/bin/moonlight-jail-nix-tmpfix'
        ''
    ;
in if (overridesOpts.use_jail_tmpfix or false) then
    jailedMoonlight
else
    (mkNixPak {
        config = { sloth, ... }: {
            app = {
                package = pkgs.moonlight-qt;
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
                # Host graphics-driver symlinks resolve into /nix/store. TODO: not do this
                bindEntireStore = true;
                clearEnv = true;
                newSession = true;
                dieWithParent = true;
                sockets = {
                    wayland = true;
                    pulse = true;
                };

                # CLANKER: nixpak's GPU module mounts /dev/dri but not NVIDIA's decoder nodes.
                bind.dev = [
                    "/dev/nvidia0"
                    "/dev/nvidiactl"
                    "/dev/nvidia-modeset"
                    "/dev/nvidia-uvm"
                    "/dev/nvidia-uvm-tools"
                    "/dev/nvidia-caps"
                ];

                bind.rw = [
                    [ (sloth.mkdir (sloth.concat [ (sloth.env "HOME") "/.nyx/app-fake-root/moonlight-stream/" (sloth.env "HOME") ])) (sloth.env "HOME") ]
                    [ (sloth.mkdir (sloth.concat' sloth.runtimeDir "/nyx/moonlight-stream")) "/tmp" ]
                ];
                env = {
                    HOME = sloth.env "HOME";
                    XDG_RUNTIME_DIR = sloth.runtimeDir;
                    DISPLAY = sloth.env "DISPLAY";
                    XDG_CURRENT_DESKTOP = sloth.env "XDG_CURRENT_DESKTOP";
                    PIPEWIRE_REMOTE = sloth.envOr "PIPEWIRE_REMOTE" "pipewire-0";
                    PIPEWIRE_RUNTIME_DIR = sloth.envOr "PIPEWIRE_RUNTIME_DIR" sloth.runtimeDir;
                    PULSE_SERVER = sloth.envOr "PULSE_SERVER" (sloth.concat [ "unix:" sloth.runtimeDir "/pulse/native" ]);
                    PULSE_RUNTIME_PATH = sloth.envOr "PULSE_RUNTIME_PATH" sloth.runtimeDir;
                    WAYLAND_DISPLAY = sloth.envOr "WAYLAND_DISPLAY" "wayland-0";

                    # -- CLANKER --
                    # VA-API's NVIDIA driver fails to export surfaces in this sandbox;
                    # Moonlight successfully test-decodes with Vulkan, so prefer that path.
                    LIBVA_DRIVER_NAME = "disabled";
                    # Qt's OpenGL RHI cannot create an EGL context in this sandbox;
                    # Vulkan has already been initialized successfully above.
                    QSG_RHI_BACKEND = "vulkan";
                };
            };
        };
    }).config.env
