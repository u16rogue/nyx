{ inputs, pkgs, kitty, kitty-themes, nerd-fonts, writeText, makeFontsConf, ... }: let
    config_file = writeText "kitty.conf" (builtins.replaceStrings
        [ "@kitty_theme@" ]
        [ "${kitty-themes}/share/kitty-themes/themes/Catppuccin-Mocha.conf" ]
        (builtins.readFile ./config.conf));
in inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = kitty;
    env.FONTCONFIG_FILE = makeFontsConf { fontDirectories = [ nerd-fonts.comic-shanns-mono ]; };
    flags."--config" = config_file;
}
