{ inputs, lib, ... }: {
    perSystem = { pkgs, ... }: {
        packages = (lib.pipe (builtins.readDir ./.) [
            (lib.filterAttrs (name: value: (value == "directory" && builtins.pathExists (./. + "/${name}/package.nix"))))
            (lib.mapAttrs (name: value: pkgs.callPackage (./. + "/${name}/package.nix") {
                wrapPackage = inputs.wrappers.lib.wrapPackage;
            }))
        ]);
    };
}
