{ inputs, ... }: {
    perSystem = { pkgs, ... }: {
        packages.nushell = import ./package.nix {
            inherit inputs pkgs;
        };
    };
}
