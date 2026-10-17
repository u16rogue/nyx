{ inputs, pkgs, nushell, ... }: inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = nushell;
    flags."--config" = "${./config.nu}";
    flags."--env-config" = pkgs.writeText "env.nu" "";
}
