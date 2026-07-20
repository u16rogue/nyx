{ ... }: {
    perSystem = { pkgs, ... }: {
        packages.tmuxss = import ./package.nix { inherit pkgs; };
    };
}
