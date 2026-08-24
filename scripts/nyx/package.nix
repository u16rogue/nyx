{ writeShellApplication, coreutils, rage, ... }: writeShellApplication {
    name = "nyx";
    runtimeInputs = [ coreutils rage ];
    text = builtins.readFile ./nyx;
}
