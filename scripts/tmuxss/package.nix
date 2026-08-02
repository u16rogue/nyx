{ coreutils, writeShellApplication, ... }: writeShellApplication {
    name = "tmuxss";
    runtimeInputs = [ coreutils ];
    text = builtins.readFile ./tmuxss;
}
