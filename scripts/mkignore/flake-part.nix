{ ... }: {
    perSystem = { pkgs, ... }: {
        packages.mkignore = import ./package.nix { inherit pkgs; };
    };
}
