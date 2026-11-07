{{! THIS WAS WRITTEN BY A CLANKER }}
{ mkShellNoCC, callPackage, ... }: mkShellNoCC {
    inputsFrom = [ (callPackage ./package.nix {}) ];
    packages = [];
}
