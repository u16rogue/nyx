{ mkShellNoCC, callPackage, stdenv, clippy, rustfmt, rust-analyzer, linkFarm, vimPlugins, ... }: mkShellNoCC {
    inputsFrom = [ (callPackage ./package.nix {}) ];
    packages = [
        # rustc links through cc, inputsFrom doesn't carry package.nix's stdenv
        stdenv.cc
        clippy
        rustfmt
        # editor, the wrapper brings the std sources (RUST_SRC_PATH) of nixpkgs' rustc
        rust-analyzer
        # tree-sitter grammars, <pkg>/share/nvim/site/parser reaches neovim's runtimepath through XDG_DATA_DIRS
        (linkFarm "nvim-grammars" (map (lang: {
            name = "share/nvim/site/parser/${lang}.so";
            path = "${vimPlugins.nvim-treesitter.grammarPlugins.${lang}}/parser/${lang}.so";
        }) [ "rust" ]))
    ];
}
