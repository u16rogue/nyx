{ writeShellApplication, coreutils, rage, jq, ... }: writeShellApplication {
    name = "nyx";
    runtimeInputs = [ coreutils rage jq ];
    text = builtins.readFile ./nyx;
}
