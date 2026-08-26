{ lib, ... }: {
    perSystem = { pkgs, ... }: {
        packages = (lib.pipe (builtins.readDir ./.) [
            (lib.filterAttrs (filename: filetype: (filetype == "directory" && builtins.pathExists (./. + "/${filename}/package.nix"))))
            (lib.mapAttrs (filename: filetype: (
                pkgs.callPackage (./. + "/${filename}/package.nix") {}
            )))
        ]);
    };
}
