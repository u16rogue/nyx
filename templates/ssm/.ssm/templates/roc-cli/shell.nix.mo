{{! THIS WAS WRITTEN BY A CLANKER }}
{ mkShellNoCC, callPackage, curl, ... }: mkShellNoCC {
    inputsFrom = [ (callPackage ./package.nix {}) ];
    packages = [
        curl
    ];
}
