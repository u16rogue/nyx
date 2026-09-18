{ inputs, pkgs, ... }: (inputs.nvf.lib.neovimConfiguration {
    inherit pkgs;
    modules = [
        { config = import ./config.nvf.nix; }
    ];
}).neovim
