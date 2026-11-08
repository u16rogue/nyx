{
    inputs, lib, vimUtils, vimPlugins, wrapNeovimUnstable, neovim-unwrapped, ripgrep, fd,
    ...
}: wrapNeovimUnstable neovim-unwrapped {
    viAlias = true;
    vimAlias = true;
    plugins = with vimPlugins; [
        catppuccin-nvim nvim-web-devicons bufferline-nvim bufdelete-nvim nvim-tree-lua
        telescope-nvim telescope-fzf-native-nvim telescope-ui-select-nvim plenary-nvim gitsigns-nvim
        nvim-treesitter-context nvim-ts-autotag rainbow-delimiters-nvim indent-blankline-nvim
        nvim-lspconfig blink-cmp
        treesj vim-easy-align nvim-surround
        # Grammars for files found in any project; language grammars come from the project devshell.
        # Neovim itself bundles c, lua, markdown, markdown_inline, query, vim and vimdoc.
        (nvim-treesitter.withPlugins (p: with p; [
            bash diff gitcommit json make nix regex toml yaml
        ]))
    ]
    # Plugins missing from nixpkgs: add `inputs.<name> = { url = "github:owner/repo"; flake = false; };` to flake.nix and list <name> here.
    ++ map (name: vimUtils.buildVimPlugin {
        pname = name;
        version = inputs.${name}.shortRev or "dirty";
        src = inputs.${name};
    }) [];
    luaRcContent = ''
        vim.opt.runtimepath:prepend("${lib.fileset.toSource { root = ./.; fileset = ./lua; }}")
        vim.opt.runtimepath:append("${vimPlugins.nvim-treesitter}/runtime")
    '' + builtins.readFile ./init.lua;
    # Telescope's finders, appended to PATH so a devshell's copy wins. No language servers:
    # projects bring their own.
    wrapperArgs = [ "--suffix" "PATH" ":" (lib.makeBinPath [ ripgrep fd ]) ];
}
