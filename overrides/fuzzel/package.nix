{ inputs, pkgs, fuzzel, comfortaa, makeFontsConf, ... }: inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = fuzzel;
    env.FONTCONFIG_FILE = makeFontsConf { fontDirectories = [ comfortaa ]; };
    flags."--config" = "${./config.ini}";
}
