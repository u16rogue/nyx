{ ... }: {
    perSystem = { pkgs, ... }: {
        packages.tmuxss = pkgs.callPackage ./package.nix {};
    };
}
