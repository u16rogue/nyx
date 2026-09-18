{ inputs, pkgs, ghostty, ... }: let
    config_file = ./config.ghostty;
in inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = ghostty;
    env.FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.nerd-fonts.comic-shanns-mono ]; };
    wrapper = { exePath, envString, ... }: /*bash*/ ''
        # ghostty actions workaround since +action are required to be second parameter
        ${envString}
        if [[ "''${1:-}" == "+validate-config" ]]; then
            exec ${exePath} "$@" --config-file=${config_file}
        elif [[ "''${1:-}" == +* ]]; then
            exec ${exePath} "$@"
        fi
        exec ${exePath} --config-file=${config_file} "$@"
    '';
}
