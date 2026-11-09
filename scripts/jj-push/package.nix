{ writeShellApplication, coreutils, git, jq, jujutsu, ... }: writeShellApplication {
    name = "jj-push";
    runtimeInputs = [ coreutils git jq jujutsu ];
    text = builtins.readFile ./jj-push;
}
