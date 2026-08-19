{ writeShellApplication, coreutils, rage, ... }: writeShellApplication {
    name = "nix-pkgvercmp";
    runtimeInputs = [ coreutils rage ];
    text = builtins.readFile ./nyx;
}
