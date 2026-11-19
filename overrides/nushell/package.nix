{ inputs, pkgs, nushell, writeText, ... }: inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = nushell;
    flags."--config" = "${./config.nu}";
    flags."--env-config" = writeText "env.nu" "";
}
