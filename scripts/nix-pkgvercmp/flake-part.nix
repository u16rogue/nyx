{ ... }: {
    perSystem = { pkgs, ... }: {
        packages.nix-pkgvercmp = pkgs.callPackage ./package.nix {};
    };
}
