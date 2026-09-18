{ inputs, pkgs, tmux, ... }: inputs.wrappers.lib.wrapPackage {
    inherit pkgs;
    package = tmux;
    flags."-f" = ./tmux.conf;
}
