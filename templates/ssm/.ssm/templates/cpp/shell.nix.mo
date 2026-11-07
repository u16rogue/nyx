{{! CLANKER EDITED: the dev-cpp devshell packages on top of the package's inputs }}
{ mkShellNoCC, callPackage, clang, clang-tools, pkgsCross, ... }: mkShellNoCC {
    inputsFrom = [ (callPackage ./package.nix {}) ];
    packages = [
        clang
        clang-tools
        pkgsCross.mingwW64.buildPackages.gcc
    ];
}
