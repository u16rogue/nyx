{ writeShellApplication, coreutils, curl, jq, ... }: writeShellApplication {
    name = "repo-init";
    runtimeInputs = [ coreutils curl jq ];
    text = builtins.readFile ./repo-init;
}
