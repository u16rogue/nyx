{ ... }: {
    perSystem = { pkgs, ... }: {
        packages.nix-pkgvercmp = import ./package.nix { inherit pkgs; };
    };
}
