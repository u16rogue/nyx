{
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
        {{#nixpkgs_pin}}
        nixpkgs-pin.url = "github:nixos/nixpkgs/{{nixpkgs_pin}}";
        {{/nixpkgs_pin}}
        {{#use_flakeparts}}
        flake-parts.url = "github:hercules-ci/flake-parts";
        {{/use_flakeparts}}
    };

    {{#use_flakeparts}}
    outputs = inputs@{ flake-parts, ... }: flake-parts.lib.mkFlake { inherit inputs; } ({ lib, ... }:
    let
        subprojects = [
            {{#subprojects}}
            ./{{.}}
            {{/subprojects}}
        ];
        # `callEach` picks the sub projects that provide `file`, named after their directory
        callEach = pkgs: file: lib.pipe subprojects [
            (lib.filter (path: builtins.pathExists (path + "/${file}")))
            (map (path: lib.nameValuePair (baseNameOf path) (pkgs.callPackage (path + "/${file}") {})))
            lib.listToAttrs
        ];
    in {
        flake.description = "{{flake_description}}";
        imports = [];
        systems = [ {{#flake_systems}}"{{.}}" {{/flake_systems}}];
        perSystem = { pkgs, ... }:
        let
            shells = callEach pkgs "shell.nix";
        in {
            packages = callEach pkgs "package.nix";
            devShells = shells // {
            {{#flake_devshell_frags}}
                {{.}} = pkgs.mkShellNoCC {
                    inputsFrom = lib.attrValues shells;
                    packages = [];
                    shellHook = /*bash*/ ''export NIX_FRAGMENT="{{.}}"'';
                };
            {{/flake_devshell_frags}}
            };
        };
    });
    {{/use_flakeparts}}
    {{^use_flakeparts}}
    outputs = inputs@{ nixpkgs, ... }: let
        inherit (nixpkgs) lib;
        systems = [ {{#flake_systems}}"{{.}}" {{/flake_systems}}];
        perSystem = attr: lib.genAttrs systems (system: attr { pkgs = nixpkgs.legacyPackages.${system}; inherit system; });

        subprojects = [
            {{#subprojects}}
            ./{{.}}
            {{/subprojects}}
        ];
        # `callEach` picks the sub projects that provide `file`, named after their directory
        callEach = pkgs: file: lib.pipe subprojects [
            (lib.filter (path: builtins.pathExists (path + "/${file}")))
            (map (path: lib.nameValuePair (baseNameOf path) (pkgs.callPackage (path + "/${file}") {})))
            lib.listToAttrs
        ];
    in {
        description = "{{flake_description}}";
        packages = perSystem ({ pkgs, ... }: callEach pkgs "package.nix");
        devShells = perSystem ({ pkgs, ... }: let
            shells = callEach pkgs "shell.nix";
        in shells // {
        {{#flake_devshell_frags}}
            {{.}} = pkgs.mkShellNoCC {
                inputsFrom = lib.attrValues shells;
                packages = [];
                shellHook = /*bash*/ ''export NIX_FRAGMENT="{{.}}"'';
            };
        {{/flake_devshell_frags}}
        });
    };
    {{/use_flakeparts}}
}
