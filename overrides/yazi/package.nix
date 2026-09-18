{ inputs, pkgs, yazi, ... }: inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = yazi;
    env.YAZI_CONFIG_HOME = ./config;
}
