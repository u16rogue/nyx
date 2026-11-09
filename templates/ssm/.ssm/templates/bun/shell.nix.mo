{{! CLANKER EDITED: added the editor's grammars, removed typescript-language-server as bun init's typescript 7 is its own language server (`tsc --lsp`, see .nvim.lua) }}
{ mkShellNoCC, callPackage, linkFarm, vimPlugins, ... }: mkShellNoCC {
    inputsFrom = [ (callPackage ./package.nix {}) ];
    packages = [
        # editor: tree-sitter grammars, <pkg>/share/nvim/site/parser reaches neovim's runtimepath through XDG_DATA_DIRS
        (linkFarm "nvim-grammars" (map (lang: {
            name = "share/nvim/site/parser/${lang}.so";
            path = "${vimPlugins.nvim-treesitter.grammarPlugins.${lang}}/parser/${lang}.so";
        }) [ "typescript" "javascript" "tsx" ]))
    ];
}
