{ ... }: {
    perSystem = { pkgs, ... }: {
        packages.nix-gc = import ./package.nix { inherit pkgs; };
    };
}
