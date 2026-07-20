{ ... }: {
    perSystem = { pkgs, ... }: {
        packages.nix-develop = import ./package.nix { inherit pkgs; };
    };
}
