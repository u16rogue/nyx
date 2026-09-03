{ ... }: let
    username = "user";
in {
    nyx.nixos.users.${username} = {
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
            ];
            partial.directories = [];
        };

        configuration = { pkgs, nyxpkgs, ... }: {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            shell = nyxpkgs.nushell;
            packages = [
                # Scripts
                nyxpkgs.tmuxss
                nyxpkgs.git-cans
                nyxpkgs.mkignore
                nyxpkgs.nix-develop
                nyxpkgs.nix-gc
                nyxpkgs.nix-pkgvercmp
                nyxpkgs.nix-sync-lock-from-nixos

                # Custom overidden packages (homeless configs +/ sandbox)
                nyxpkgs.fish
                nyxpkgs.nushell

                # direct nixpkgs
                pkgs.git
                pkgs.jq
                pkgs.bubblewrap
            
                (pkgs.writeShellApplication {
                    name = "start";
                    runtimeInputs = [];
                    text = /*bash*/ ''
                        exec start-hyprland
                    '';
                })
            ];
        };
    };
}
