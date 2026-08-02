{ ... }: {
    perSystem = { pkgs, ... }: {
        packages.nix-gc = pkgs.callPackage ./package.nix {};
    };
}
