{ wrapPackage, pkgs, fish, writeText, overridesOpts ? {}, ... }:
let
    finalOpts = {
        configFile = ./config.fish;
    } // overridesOpts;
in wrapPackage {
    inherit pkgs;
    package = fish;
    flags = {
        "--init-command" = "source ${writeText "config.fish" (builtins.readFile finalOpts.configFile)}";
    };
}
