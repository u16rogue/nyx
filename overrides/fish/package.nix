{ wrapPackage, pkgs, fish, writeText, overridesOpts ? {}, ... }: let
    final_opts = {
        config_file = ./config.fish;
    } // overridesOpts;
in wrapPackage {
    inherit pkgs;
    package = fish;
    flags = {
        "--init-command" = "source ${writeText "config.fish" (builtins.readFile final_opts.config_file)}";
    };
}
