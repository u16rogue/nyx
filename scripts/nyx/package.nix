{ writeShellApplication, coreutils, jq, openssh, rage, util-linux, ... }: writeShellApplication {
    name = "nyx";
    runtimeInputs = [ coreutils jq openssh rage util-linux ];
    text = builtins.readFile ./nyx;
}
