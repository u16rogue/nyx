{ wrapPackage, pkgs, nushell, ... }: wrapPackage {
    inherit pkgs;
    package = nushell;
    flags = {
        "--config" = ./config.nu;
    };
}
