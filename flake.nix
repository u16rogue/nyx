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
        nvf = { # neovim
            url = "github:notashelf/nvf";
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
                ];
                shellHook = /*bash*/ ''
                    export NIX_FRAGMENT="default"
                    export PATH="$PATH:$PWD/_nyx:$PWD/templates"
                '';
            };
        };
    });
}
