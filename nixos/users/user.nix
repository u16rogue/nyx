{ self, ... }: let
    username = "user";
in {
    nyx.nixos.users.${username} = {
        ephemeralfs.preserve = {
            files = [

            ];
            directories = [
                "/home/${username}/downloads"
                "/home/${username}/media"
                "/home/${username}/documents"
                "/home/${username}/projects"
            ];
            partial.directories = [];
        };

        configuration = { pkgs, ... }: let nyxpkgs = self.packages.${pkgs.system}; in {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            shell = nyxpkgs.fish;
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
