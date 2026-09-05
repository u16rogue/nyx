{ wrapPackage, pkgs, ghostty, overridesOpts ? {}, ... }: let
    final_opts = {
        config_file = ./config.ghostty;
    } // overridesOpts;
    config_file = pkgs.writeText "config.ghostty" (builtins.readFile final_opts.config_file);
in wrapPackage {
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
