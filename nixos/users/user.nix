{ ... }: let
    username = "user";
in {
    nyx.nixos.users.${username} = {
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
            shell = nyxpkgs.fish;
            # initialPassword = "12345678"; # this is a bad idea as we have secrets in here. we MUST have a password.
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
