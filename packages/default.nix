let
    entries = builtins.readDir ./.;

    packages = builtins.filter
        (name:
            entries.${name} == "directory"
            && builtins.pathExists (./. + "/${name}/flake-part.nix"))
        (builtins.attrNames entries);

    imports = builtins.map
        (name: ./. + "/${name}/flake-part.nix")
        packages;
in {
    inherit imports;
}
