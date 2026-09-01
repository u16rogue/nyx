{ writeShellApplication, coreutils, jq, openssh, rage, ... }: writeShellApplication {
    name = "nyx";
    runtimeInputs = [ coreutils jq openssh rage ];
    text = builtins.readFile ./nyx;
}
