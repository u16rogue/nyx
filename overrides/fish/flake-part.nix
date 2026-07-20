{ inputs, ... }: {
    perSystem = { pkgs, ... }: {
        packages.fish = import ./package.nix {
            inherit inputs pkgs;
        };
    };
}
