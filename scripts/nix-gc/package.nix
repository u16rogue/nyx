{ writeShellApplication, ... }: writeShellApplication {
    name = "nix-gc";
    runtimeInputs = [];
    text = builtins.readFile ./nix-gc;
}
