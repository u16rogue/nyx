{ ... }: {
    nyx.nixos.users.user = {
        password = ''
            -----BEGIN AGE ENCRYPTED FILE-----
            YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IHNzaC1lZDI1NTE5IGwxamN3ZyBhL2Qz
            aCtaMzFjNXQzUWZkUTZ6dC85WWJNMDhjMjE1YkdqbFpsb2RHWnlrClQxVjRFOWxG
            eHYrR2c3K3QyYmJIcjk1aUFRdGg2aHVnUHFlaUZhSHlzeG8KLT4gc3NoLWVkMjU1
            MTkgaHREa2hRIGdIUDV2OHRsWm10ZEU0b1ZvT0dNTktGdHlSY1JMSW1kRmRQb3Nv
            U1ZESDgKeTMwQndGSml0aEdib1VyTXBWUmNQN2xiayt6RnJPYk9QMERlaGlkVWJV
            dwotPiBpO3AiVi1ncmVhc2UgUD8gVydqI0Y4YWsKdG8yQkVMemZmOWF3emRzU040
            TjRFM3htRmpvSEhkaFJ6UTQKLS0tIDFQa1VSQlJhZ09rZHcrK3VZQ0llUTFIZlYv
            eXIyekQ3dU9WMWFoQ0d0ZGMKToQvGiLgiA6rR6pCcs3HQkVPjNWGICkihsP+ZFW/
            NqGeg3hqgEelofLUpTxDUtdR8jrf5SyMY/arfjX27rJC5OKdOhPa8fyzZV0U5Pye
            Yi2SNvX5PfLle6uZzbPie5q0PiRY2klYOL9q
            -----END AGE ENCRYPTED FILE-----
        '';

        ephemeralfs.preserve = {
            files = [];
            directories = [
                "downloads"
                "media"
                "documents"
                "projects"
                ".nyx/app-fake-root/firefox"
                ".nyx/app-fake-root/monero-gui"
                ".nyx/app-fake-root/moonlight-stream"
                ".nyx/app-fake-root/remmina"
                ".nyx/app-fake-root/steamguard-cli"
                ".nyx/app-fake-root/vesktop"
            ];
            partial.directories = [
                ".nyx/app-fake-root/keepassxc" # keepass has nothing important to save
            ];
        };

        # The whole hyprland implementation is currently a workaround as i cannot get the hyprland
        # package itself to be the core of its own instance. Can't get portals to work so in the mean
        # time we'll rely on the nixos module. TODO: make the `hyprland` override package itself manage
        # its own portals and session
        host-configuration = { pkgs, nyx, lib, ... }: {
            programs.hyprland = {
                enable = true;
                package = nyx.pkgs.hyprland.override {
                    overridesOpts.monitors = nyx.host.monitors;
                    hyprpaper = nyx.pkgs.hyprpaper.override { overridesOpts.wallpaper = "/home/user/media/wallpaper"; };
                    waybar = nyx.pkgs.waybar;
                };
            };

            xdg.portal = {
                xdgOpenUsePortal = true;
                extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
                config.common = {
                    default = [ "hyprland" "gtk" ];
                    "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
                };
            };

            # Clanker: Hyprland is launched directly rather than through a display manager.
            systemd.user.services.xdg-desktop-portal = {
                wants = [ "xdg-desktop-portal-gtk.service" ];
                after = [ "xdg-desktop-portal-gtk.service" ];
                unitConfig = {
                    PartOf = lib.mkForce [ "" ];
                    Requisite = lib.mkForce [ "" ];
                };
            };
        };

        configuration = { pkgs, nyx, ... }: {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            shell = nyx.pkgs.fish;
            packages = [
                # Shell
                nyx.pkgs.fish
                nyx.pkgs.nushell
                # Scripts
                nyx.pkgs.tmuxss
                nyx.pkgs.git-cans
                nyx.pkgs.mkignore
                nyx.pkgs.nix-develop
                nyx.pkgs.nix-gc
                nyx.pkgs.nix-pkgvercmp
                nyx.pkgs.nix-sync-lock-from-nixos

                # Custom overidden packages (homeless configs +/ sandbox)
                nyx.pkgs.firefox
                nyx.pkgs.fuzzel
                nyx.pkgs.ghostty
                nyx.pkgs.kitty
                nyx.pkgs.keepassxc
                nyx.pkgs.monero-gui
                nyx.pkgs.moonlight-stream
                (nyx.pkgs.moonlight-stream.override { overridesOpts.use_jail_tmpfix = true; })
                nyx.pkgs.neovim
                nyx.pkgs.remmina
                nyx.pkgs.steamguard-cli
                nyx.pkgs.tmux
                nyx.pkgs.vesktop
                (nyx.pkgs.vesktop.override { overridesOpts.use_jail_tmpfix = true; })
                nyx.pkgs.yazi
                nyx.pkgs.zellij

                # direct nixpkgs
                pkgs.git
                pkgs.jq
                pkgs.bubblewrap
                pkgs.btop
            
                (pkgs.writeShellApplication {
                    name = "start-desktop";
                    runtimeInputs = [];
                    text = /*bash*/ ''
                        exec start-hyprland
                    '';
                })
            ];
        };
    };
}
