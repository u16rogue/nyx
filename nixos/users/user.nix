{ self, ... }: let
    username = "user";
in {
    flake.modules.nixos.users.${username} = { pkgs, ... }: let
        mypkgs = self.packages.${pkgs.system};
    in {
        users.users.${username} = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            shell = mypkgs.fish;
            packages = [
                # Scripts
                mypkgs.tmuxss
                mypkgs.git-cans
                mypkgs.mkignore
                mypkgs.nix-develop
                mypkgs.nix-gc
                mypkgs.nix-pkgvercmp
                mypkgs.nix-sync-lock-from-nixos

                # Custom overridden packages (homeless configs +/ sandbox)
                mypkgs.fish
                mypkgs.nushell

                # direct nixpkgs
                pkgs.git
                pkgs.jq
                pkgs.bubblewrap
            ];
        };
    };
}
