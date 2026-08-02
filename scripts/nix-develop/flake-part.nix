{ ... }: {
    perSystem = { pkgs, ... }: {
        packages.nix-develop = pkgs.callPackage ./package.nix {};
    };
}
