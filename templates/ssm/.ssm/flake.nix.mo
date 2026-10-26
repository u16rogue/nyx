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
    outputs = inputs@{ flake-parts, ... }: flake-parts.lib.mkFlake { inherit inputs; } {
        flake.description = "{{flake_description}}";
        imports = [];
        systems = [ {{#flake_systems}}"{{.}}" {{/flake_systems}}];
        perSystem = { pkgs, ... }: {
            devShells.default = pkgs.mkShellNoCC {
                packages = [];
                shellHook = /*bash*/ ''export NIX_FRAGMENT="default"'';
            };
        };
    };
    {{/use_flakeparts}}
    {{^use_flakeparts}}
    outputs = inputs@{ ... }: let
        systems = [ {{#flake_systems}}"{{.}}" {{/flake_systems}}];
        perSystem = attr: builtins.listToAttrs (builtins.map (system: { name = system; value = (attr { pkgs = inputs.nixpkgs.legacyPackages."${system}"; inherit system; }); }) systems);
    in {
        description = "{{flake_description}}";
        packages = perSystem ({ pkgs, ... }: {
        });
        devShells = perSystem ({ pkgs, ... }: {
        {{#flake_devshell_frags}}
            {{.}} = pkgs.mkShellNoCC {
                packages = [];
                shellHook = /*bash*/ ''export NIX_FRAGMENT="{{.}}"'';
            };
        {{/flake_devshell_frags}}
        });
    };
    {{/use_flakeparts}}
}
