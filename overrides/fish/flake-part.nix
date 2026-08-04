{ inputs, ... }: {
    perSystem = { pkgs, ... }: {
        packages.fish = pkgs.callPackage ./package.nix {
            wrapPackage = inputs.wrappers.lib.wrapPackage;
        };
    };
}
