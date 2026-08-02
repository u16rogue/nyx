{ writeShellApplication, coreutils, ... }: writeShellApplication {
    name = "nix-develop";
    runtimeInputs = [ coreutils ];
    text = builtins.readFile ./nix-develop;
}
