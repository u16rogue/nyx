{ writeShellApplication, coreutils, ... }: writeShellApplication {
    name = "nyx-efsp";
    runtimeInputs = [ coreutils ];
    text = builtins.readFile ./nyx-efsp;
}
