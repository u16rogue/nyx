{ ... }: let
    username = "user";
in {
    nyx.nixos.users.${username} = {
        password = ''
            -----BEGIN AGE ENCRYPTED FILE-----
            YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IHNzaC1lZDI1NTE5IGwxamN3ZyBSTGpp
            QTErYXVKU0g0S1VEeHhqSmxJbWpmZWhIUWJHalcxcSs4SGFRUDJrCkxwZXlMK1BI
            RCs1NjUybmRnZDl3RFEzUDhOQitkMWNIQlFTbDErV0hpVHcKLT4gfm8kbC1ncmVh
            c2UgMmFJPyZKNCBsbENAISBgXCBgCk9lOEdEeWhnM2xybwotLS0gQnpaS2x1OTdt
            OFhYSG5qc1FPelBLWVgxU0JrbVovRmZPdjlFcmhrVlM2VQpKYBZlu8nHhfonkZgO
            au5bCd1fdnetyZNnl1CInp0A7bbosFWXjxZpHnIoktPhL3ZqRvyPQK3iYtPyy94Y
            XcjyxwhteLPRhQv+mEG0u3oHtr0aVepJtGMqYPwx21JR7PqLFzu18QYk3lw=
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
            
                pkgs.writeShellApplication {
                    name = "start";
                    runtimeInputs = [];
                    text = /*bash*/ ''
                        exec start-hyprland
                    '';
                }
            ];
        };
    };
}
