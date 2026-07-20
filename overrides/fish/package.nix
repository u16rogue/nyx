{ inputs, pkgs, ... }: inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = pkgs.fish;
    flags = {
        "--init-command" = "source ${pkgs.writeText "config.fish" (builtins.readFile ./config.fish)}";
    };
}
