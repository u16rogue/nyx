{ inputs, pkgs, fish, ... }: inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = fish;
    flags = {
        "--no-config" = true;
        "--init-command" = "source ${./config.fish}";
    };
}
