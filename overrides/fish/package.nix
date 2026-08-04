{ pkgs, fish, writeText, wrapPackage, ... }: wrapPackage {
    inherit pkgs;
    package = fish;
    flags = {
        "--init-command" = "source ${writeText "config.fish" (builtins.readFile ./config.fish)}";
    };
}
