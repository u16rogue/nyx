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
                x11 = true;
            };
            bind.ro = [
                [ "/etc/zoneinfo" "/usr/share/zoneinfo" ]
                # `.local` lookups in-process: host nsswitch -> nss-mdns (from the `mdns-query` module) -> avahi.
                # Binds are skipped when missing, so hosts without the module just fall back to plain DNS
                "/etc/nsswitch.conf"
                [ "/etc/nss-mdns/lib" "/run/host-nss" ]
                [ "/run/avahi-daemon" "/var/run/avahi-daemon" ] # nss-mdns talks to avahi at /var/run/avahi-daemon/socket
            ];
            bind.rw = [
                [ (sloth.mkdir (sloth.concat [ (sloth.env "HOME") "/.nyx/app-fake-root/monero-gui/" (sloth.env "HOME") ])) (sloth.env "HOME") ]
                [ (sloth.mkdir (sloth.concat' sloth.runtimeDir "/nyx/monero-gui")) "/tmp" ]
                (sloth.concat' sloth.runtimeDir "/doc")
            ];
            env = {
                HOME = sloth.env "HOME";
                XDG_RUNTIME_DIR = sloth.runtimeDir;
                XDG_CURRENT_DESKTOP = sloth.env "XDG_CURRENT_DESKTOP";
                WAYLAND_DISPLAY = sloth.envOr "WAYLAND_DISPLAY" "wayland-0";
                LD_LIBRARY_PATH = "/run/host-nss"; # where glibc finds libnss_mdns4_minimal
            };
        };
    };
}).config.env
