{ inputs, ... }: {
    perSystem = { pkgs, ... }: {
        packages.nushell = pkgs.callPackage ./package.nix {
            wrapPackage = inputs.wrappers.lib.wrapPackage;
        };
    };
}
