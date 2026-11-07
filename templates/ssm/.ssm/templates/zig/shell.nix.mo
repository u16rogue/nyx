{{! THIS WAS WRITTEN BY A CLANKER }}
{ mkShellNoCC, callPackage, zon2nix, ... }: mkShellNoCC {
    inputsFrom = [ (callPackage ./package.nix {}) ];
    packages = [
        zon2nix
    ];
}
