{
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
        flake-parts.url = "github:hercules-ci/flake-parts";
        wrappers = {
            url = "github:lassulus/wrappers";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        nixpak = {
            url = "github:nixpak/nixpak";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        disko = {
            url = "github:nix-community/disko";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        preservation = {
            url = "github:nix-community/preservation";
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
        perSystem = { self', config, pkgs, ... }: {
            devShells.default = pkgs.mkShellNoCC {
                packages = [];
                shellHook = /*bash*/ ''
                    export NIX_FRAGMENT="default"
                    if [[ -f "$PWD/.devshellshook.sh" ]]; then
                        source "$PWD/.devshellshook.sh"
                    elif command -v "sbx-shell" &> /dev/null; then
                        exec sbx-shell
                    fi
                '';
            };
        };
    });
}
