{ writeNuShellApplication, git, gnupg, ... }: writeNuShellApplication {
    name = "git-log";
    runtimeInputs = [ git gnupg ];
    text = builtins.readFile ./git-log.nu;
}
