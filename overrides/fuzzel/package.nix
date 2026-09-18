{ inputs, pkgs, fuzzel, ... }: inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = fuzzel;
    env.FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.comfortaa ]; };
    flags."--config" = ./config.ini;
}
