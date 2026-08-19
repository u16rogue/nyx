{ ... }: {
    perSystem = { pkgs, ... }: {
        packages.nyx = pkgs.callPackage ./package.nix {};
    };
}
