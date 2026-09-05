{ wrapPackage, pkgs, nushell, overridesOpts ? {}, ... }: let
    final_opts = {
        config_file = ./config.nu;
    } // overridesOpts;
in wrapPackage {
    inherit pkgs;
    package = nushell;
    flags = {
        "--config" = final_opts.config_file;
    };
}
