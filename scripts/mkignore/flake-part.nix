{ ... }: {
    perSystem = { pkgs, ... }: {
        packages.mkignore = pkgs.callPackage ./package.nix {};
    };
}
