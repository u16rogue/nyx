{{! THIS WAS WRITTEN BY A CLANKER }}
{ mkShellNoCC, callPackage, linkFarm, vimPlugins, lua5_4, ... }: mkShellNoCC {
    # lua, tl and cyan come from the package
    inputsFrom = [ (callPackage ./package.nix {}) ];
    packages = [
        # editor
        lua5_4.pkgs.teal-language-server
        # tree-sitter grammars, <pkg>/share/nvim/site/parser reaches neovim's runtimepath through XDG_DATA_DIRS
        (linkFarm "nvim-grammars" (map (lang: {
            name = "share/nvim/site/parser/${lang}.so";
            path = "${vimPlugins.nvim-treesitter.grammarPlugins.${lang}}/parser/${lang}.so";
        }) [ "teal" ]))
    ];
}
