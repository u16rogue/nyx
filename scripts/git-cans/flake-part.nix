{ ... }: {
    perSystem = { pkgs, ... }: {
        packages.git-cans = import ./package.nix { inherit pkgs; };
    };
}
