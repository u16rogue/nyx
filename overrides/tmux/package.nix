{ inputs, pkgs, tmux, tmuxPlugins, writeText, ... }: inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = tmux;
    flags."-f" = writeText "tmux.conf" (builtins.replaceStrings
        [ "@tmuxPlugins.catppuccin@" ]
        [ "${tmuxPlugins.catppuccin}/share/tmux-plugins/catppuccin/catppuccin.tmux" ]
        (builtins.readFile ./tmux.conf)
    );
}
