{ ... }: {
    perSystem = { pkgs, ... }: {
        packages.nix-sync-lock-from-nixos = pkgs.callPackage ./package.nix {};
    };
}
