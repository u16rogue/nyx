{
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
        nixpkgs-host-pin.url = "github:nixos/nixpkgs/{{nyx_host_rev}}";
        {{#use_flakeparts}}
        flake-parts.url = "github:hercules-ci/flake-parts";
        {{/use_flakeparts}}
    };

    {{#use_flakeparts}}
    outputs = inputs@{ flake-parts, ... }: flake-parts.lib.mkFlake { inherit inputs; } {
        flake.description = "{{flake_description}}";
        imports = [];
        systems = [ {{#d_nixfsystems}}"{{.}}" {{/d_nixfsystems}}];
        perSystem = { pkgs, ... }: {
            devShells.default = pkgs.mkShellNoCC {
                packages = [];
                shellHook = /*bash*/ ''export NIX_FRAGMENT="default"'';
            };
        };
    };
    {{/use_flakeparts}}
    {{^use_flakeparts}}
    outputs = inputs@{ ... }: {
        description = "{{flake_description}}";
        {{#d_nixfsystems}}
        devShells."{{.}}" = {
        {{#d_nixfdevshellfrags}}
            {{.}} = pkgs.mkShellNoCC {
                packages = [];
                shellHook = /*bash*/ ''export NIX_FRAGMENT="{{.}}"'';
            };
        {{/d_nixfdevshellfrags}}
        };
        {{/d_nixfsystems}}
    };
    {{/use_flakeparts}}
}
