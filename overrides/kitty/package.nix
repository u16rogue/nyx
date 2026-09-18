{ inputs, pkgs, kitty, ... }: let
    config_file = pkgs.writeText "kitty.conf" (builtins.replaceStrings
        [ "@kitty_theme@" ]
        [ "${pkgs.kitty-themes}/share/kitty-themes/themes/Catppuccin-Mocha.conf" ]
        (builtins.readFile ./config.conf));
in inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = kitty;
    env.FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.nerd-fonts.comic-shanns-mono ]; };
    flags."--config" = config_file;
}
