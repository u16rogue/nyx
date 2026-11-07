{ mkShellNoCC, callPackage, ... }: mkShellNoCC {
    inputsFrom = [ (callPackage ./package.nix {}) ];
    packages = [];
}
