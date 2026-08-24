{ wrapPackage, pkgs, nushell, overridesOpts ? {}, ... }:
let
    finalOpts = {
        configFile = ./config.nu;
    } // overridesOpts;
in wrapPackage {
    inherit pkgs;
    package = nushell;
    flags = {
        "--config" = finalOpts.configFile;
    };
}
