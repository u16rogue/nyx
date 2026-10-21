{ coreutils, curl, jq, writeShellApplication, ... }: writeShellApplication {
    name = "nyx-what-version";
    runtimeInputs = [ coreutils curl jq ];
    text = builtins.readFile ./nyx-what-version;
}
