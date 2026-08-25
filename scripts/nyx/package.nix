{ writeShellApplication, coreutils, openssh, rage, ... }: writeShellApplication {
    name = "nyx";
    runtimeInputs = [ coreutils openssh rage ];
    text = builtins.readFile ./nyx;
}
