{ inputs, pkgs, ... }: inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = pkgs.nushell;
    flags = {
        "--config" = builtins.toString (pkgs.writeText "config.nu" (builtins.readFile ./config.nu));
    };
}
