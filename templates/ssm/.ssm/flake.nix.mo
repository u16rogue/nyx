{{! CLANKER EDITED: inputs, nixConfig and overlays are filled in by the subproject templates (_ssm.sh), outputs use an overlayed nixpkgs, the devshell frags carry the nix/bash/lua language servers }}
{
    # `ssm add` appends to the inputs, subprojects, overlays and nixConfig lists,
    # keep their `<name> = {` / `<name> = [` openers on their own line
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
        {{#nixpkgs_pin}}
        nixpkgs-pin.url = "github:nixos/nixpkgs/{{nixpkgs_pin}}";
        {{/nixpkgs_pin}}
        {{#use_flakeparts}}
        flake-parts.url = "github:hercules-ci/flake-parts";
        {{/use_flakeparts}}
        {{#flake_inputs}}
        {{.}}
        {{/flake_inputs}}
    };

    {{#flake_has_nixconfig}}
    nixConfig = {
        extra-substituters = [
            {{#flake_substituters}}
            "{{.}}"
            {{/flake_substituters}}
        ];
        extra-trusted-public-keys = [
            {{#flake_trusted_keys}}
            "{{.}}"
            {{/flake_trusted_keys}}
        ];
    };

    {{/flake_has_nixconfig}}
    {{#use_flakeparts}}
    outputs = inputs@{ flake-parts, ... }: flake-parts.lib.mkFlake { inherit inputs; } ({ lib, ... }:
    let
        overlays = [
            {{#flake_overlays}}
            {{.}}
            {{/flake_overlays}}
        ];
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
        perSystem = { pkgs, system, ... }:
        let
            shells = callEach pkgs "shell.nix";
        in {
            _module.args.pkgs = import inputs.nixpkgs { inherit system overlays; };
            packages = callEach pkgs "package.nix";
            devShells = shells // {
            {{#flake_devshell_frags}}
                {{.}} = pkgs.mkShellNoCC {
                    inputsFrom = lib.attrValues shells;
                    # editor: nix (flake.nix, shell.nix), bash (./do) and lua (.nvim.lua) servers
                    packages = with pkgs; [ nil bash-language-server shellcheck lua-language-server ];
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
        overlays = [
            {{#flake_overlays}}
            {{.}}
            {{/flake_overlays}}
        ];
        perSystem = attr: lib.genAttrs systems (system: attr { pkgs = import nixpkgs { inherit system overlays; }; inherit system; });
        subprojects = [
            {{#subprojects}}
            ./{{.}}
            {{/subprojects}}
        ];
        callEach = pkgs: file: lib.pipe subprojects [
            (lib.filter (path: builtins.pathExists (path + "/${file}")))
            (map (path: lib.nameValuePair (baseNameOf path) (pkgs.callPackage (path + "/${file}") {})))
            lib.listToAttrs
        ];
    in {
        description = "{{flake_description}}";
        packages = perSystem ({ pkgs, ... }: callEach pkgs "package.nix");
        devShells = perSystem ({ pkgs, ... }: let shells = callEach pkgs "shell.nix"; in shells // {
        {{#flake_devshell_frags}}
            {{.}} = pkgs.mkShellNoCC {
                inputsFrom = lib.attrValues shells;
                # editor: nix (flake.nix, shell.nix), bash (./do) and lua (.nvim.lua) servers
                packages = with pkgs; [ nil bash-language-server shellcheck lua-language-server ];
                shellHook = /*bash*/ ''export NIX_FRAGMENT="{{.}}"'';
            };
        {{/flake_devshell_frags}}
        });
    };
    {{/use_flakeparts}}
}
