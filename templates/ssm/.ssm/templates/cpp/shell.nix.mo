{{! CLANKER EDITED: the dev-cpp devshell packages on top of the package's inputs, plus the editor grammars (clangd is in clang-tools) }}
{ mkShellNoCC, callPackage, clang, clang-tools, pkgsCross, linkFarm, vimPlugins, ... }: mkShellNoCC {
    inputsFrom = [ (callPackage ./package.nix {}) ];
    packages = [
        clang
        clang-tools
        pkgsCross.mingwW64.buildPackages.gcc
        # editor: tree-sitter grammars, <pkg>/share/nvim/site/parser reaches neovim's runtimepath
        # through XDG_DATA_DIRS. neovim bundles the c grammar
        (linkFarm "nvim-grammars" (map (lang: {
            name = "share/nvim/site/parser/${lang}.so";
            path = "${vimPlugins.nvim-treesitter.grammarPlugins.${lang}}/parser/${lang}.so";
        }) [ "cpp" "cmake" ]))
    ];
}
