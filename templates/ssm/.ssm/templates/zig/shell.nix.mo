{{! THIS WAS WRITTEN BY A CLANKER }}
{ mkShellNoCC, callPackage, linkFarm, vimPlugins, zon2nix, zls_0_17, ... }: mkShellNoCC {
    inputsFrom = [ (callPackage ./package.nix {}) ];
    packages = [
        zon2nix
        # editor, zls has to match package.nix's zig
        zls_0_17
        # tree-sitter grammars, <pkg>/share/nvim/site/parser reaches neovim's runtimepath through XDG_DATA_DIRS
        (linkFarm "nvim-grammars" (map (lang: {
            name = "share/nvim/site/parser/${lang}.so";
            path = "${vimPlugins.nvim-treesitter.grammarPlugins.${lang}}/parser/${lang}.so";
        }) [ "zig" ]))
    ];
}
