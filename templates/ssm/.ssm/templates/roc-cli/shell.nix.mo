{{! THIS WAS WRITTEN BY A CLANKER }}
{ mkShellNoCC, callPackage, curl, linkFarm, vimPlugins, ... }: mkShellNoCC {
    # the language server is `roc experimental-lsp`, roc comes from the package
    inputsFrom = [ (callPackage ./package.nix {}) ];
    packages = [
        curl
        # editor: tree-sitter grammars, <pkg>/share/nvim/site/parser reaches neovim's runtimepath through XDG_DATA_DIRS
        (linkFarm "nvim-grammars" (map (lang: {
            name = "share/nvim/site/parser/${lang}.so";
            path = "${vimPlugins.nvim-treesitter.grammarPlugins.${lang}}/parser/${lang}.so";
        }) [ "roc" ]))
    ];
}
