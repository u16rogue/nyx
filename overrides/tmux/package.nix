{ inputs, pkgs, tmux, ... }: inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = tmux;
    flags."-f" = pkgs.writeText "tmux.conf" (builtins.replaceStrings
        [ "@tmuxPlugins.catppuccin@" ]
        [ "${pkgs.tmuxPlugins.catppuccin}/share/tmux-plugins/catppuccin/catppuccin.tmux" ]
        (builtins.readFile ./tmux.conf)
    );
}
