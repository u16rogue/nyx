{ writeShellApplication, ... }: writeShellApplication {
    name = "git-cans";
    runtimeInputs = [];
    text = builtins.readFile ./git-cans;
}
