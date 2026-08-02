{ writeShellApplication, coreutils, jq, ... }: writeShellApplication {
    name = "nix-pkgvercmp";
    runtimeInputs = [ coreutils jq ];
    text = builtins.readFile ./nix-pkgvercmp;
}
