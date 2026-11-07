{{! CLANKER EDITED: added the editor's language servers and grammars }}
{ mkShellNoCC, callPackage, linkFarm, vimPlugins,
  svelte-language-server, typescript-language-server, vscode-langservers-extracted, ... }: mkShellNoCC {
    inputsFrom = [ (callPackage ./package.nix {}) ];
    packages = [
        # editor, ts_ls uses the project's typescript from node_modules. html/css/json servers
        svelte-language-server
        typescript-language-server
        vscode-langservers-extracted
        # tree-sitter grammars, <pkg>/share/nvim/site/parser reaches neovim's runtimepath through XDG_DATA_DIRS
        (linkFarm "nvim-grammars" (map (lang: {
            name = "share/nvim/site/parser/${lang}.so";
            path = "${vimPlugins.nvim-treesitter.grammarPlugins.${lang}}/parser/${lang}.so";
        }) [ "svelte" "typescript" "javascript" "html" "css" ]))
    ];
}
