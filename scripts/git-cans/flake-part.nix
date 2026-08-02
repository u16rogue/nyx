{ ... }: {
    perSystem = { pkgs, ... }: {
        packages.git-cans = pkgs.callPackage ./package.nix {};
    };
}
