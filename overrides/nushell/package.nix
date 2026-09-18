{ inputs, pkgs, nushell, ... }: inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = nushell;
    flags."--config" = ./config.nu;
}
