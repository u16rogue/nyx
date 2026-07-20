{ ... }: {
    perSystem = { pkgs, ... }: {
        packages.nix-sync-lock-from-nixos = import ./package.nix { inherit pkgs; };
    };
}
