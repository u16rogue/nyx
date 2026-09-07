{ inputs, pkgs, overridesOpts ? {}, ... }: let
    _ = {
    } // overridesOpts;
in (inputs.nvf.lib.neovimConfiguration {
    inherit pkgs;
    modules = [
        { config = import ./config.nvf.nix; }
    ];
}).neovim
