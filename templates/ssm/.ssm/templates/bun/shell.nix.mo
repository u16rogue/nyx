{{! CLANKER EDITED: added the editor's language server and grammars }}
{ mkShellNoCC, callPackage, linkFarm, vimPlugins, typescript-language-server, ... }: mkShellNoCC {
    inputsFrom = [ (callPackage ./package.nix {}) ];
    packages = [
        # editor, ts_ls uses the project's typescript from node_modules
        typescript-language-server
        # tree-sitter grammars, <pkg>/share/nvim/site/parser reaches neovim's runtimepath through XDG_DATA_DIRS
        (linkFarm "nvim-grammars" (map (lang: {
            name = "share/nvim/site/parser/${lang}.so";
            path = "${vimPlugins.nvim-treesitter.grammarPlugins.${lang}}/parser/${lang}.so";
        }) [ "typescript" "javascript" "tsx" ]))
    ];
}
