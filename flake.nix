{
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
        nixpkgs-opencode.url = "github:nixos/nixpkgs/0bb2eedc20e4739f29e8045034f2828ad7054f8f"; # TODO: remove once nixos-unstable includes nixpkgs c399e1b ("opencode: fix hash")

        flake-parts.url = "github:hercules-ci/flake-parts";
        preservation.url = "github:nix-community/preservation";
        wrappers = {
            url = "github:lassulus/wrappers";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        nixpak = {
            url = "github:nixpak/nixpak";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        jail-nix = {
            url = "sourcehut:~alexdavid/jail.nix";
        };
        disko = {
            url = "github:nix-community/disko";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        ragenix = {
            url = "github:yaxitech/ragenix";
            inputs.nixpkgs.follows = "nixpkgs";
        };
    };

    outputs = inputs@{ self, nixpkgs, ... }: inputs.flake-parts.lib.mkFlake { inherit inputs; } ({ config, ... }: {
        flake.nyx = config.nyx; # export `nyx` options

        imports = [
            inputs.flake-parts.flakeModules.modules
            ./templates
            ./overrides
            ./scripts
            ./nixos
        ];

        systems = [ "x86_64-linux" ];
        perSystem = { self', config, pkgs, system, ... }: {
            _module.args.pkgs = import nixpkgs {
                inherit system;
                overlays = [(final: prev: {
                    opencode = inputs.nixpkgs-opencode.legacyPackages.${prev.stdenv.hostPlatform.system}.opencode;
                })];
            };

            devShells.default = pkgs.mkShellNoCC {
                packages = with pkgs; [
                    jujutsu # git
                    rage    # secrets
                    gum     # used by ssm
                    # AI-assisted: editor, the servers are enabled in .nvim.lua
                    nil lua-language-server bash-language-server shellcheck
                    # tree-sitter grammars, <pkg>/share/nvim/site/parser reaches neovim's runtimepath through XDG_DATA_DIRS
                    (pkgs.linkFarm "nvim-grammars" (map (lang: {
                        name = "share/nvim/site/parser/${lang}.so";
                        path = "${pkgs.vimPlugins.nvim-treesitter.grammarPlugins.${lang}}/parser/${lang}.so";
                    }) [ "fish" "kdl" "nu" ]))
                ];
                shellHook = let
                    # AI-assisted: lua-language-server definitions, one per Lua config so they're separate workspaces
                    hyprland-luarc = pkgs.writeText "hyprland-luarc.json" (builtins.toJSON {
                        runtime.version = "Lua 5.5";
                        workspace = { checkThirdParty = false; library = [ "${pkgs.hyprland}/share/hypr/stubs" ]; };
                    });
                    neovim-luarc = pkgs.writeText "neovim-luarc.json" (builtins.toJSON {
                        runtime = {
                            version = "LuaJIT";
                            path = [ "?.lua" "?/init.lua" "lua/?.lua" "lua/?/init.lua" ]; # require() also searches lua/, like neovim's runtimepath does
                        };
                        workspace = {
                            checkThirdParty = false;
                            useGitIgnore = false; # the allowlist .gitignore (`**` + `!...`) would hide lua/ from it
                            library = [ "${pkgs.neovim-unwrapped}/share/nvim/runtime/lua" "\${3rd}/luv/library" ] ++ map (p: "${p.plugin or p}/lua") self'.packages.neovim.plugins;
                        };
                    });
                in /*bash*/ ''
                    export NIX_FRAGMENT="default"
                    export PATH="$PATH:$PWD/_nyx:$PWD/templates"
                    if [ -d "$PWD/overrides" ]; then
                        ln -sfn ${hyprland-luarc} "$PWD/overrides/hyprland/.luarc.json"
                        ln -sfn ${neovim-luarc} "$PWD/overrides/neovim/.luarc.json"
                    fi
                '';
            };
        };
    });
}
