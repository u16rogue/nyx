{ util-linux, writeShellApplication, ... }: writeShellApplication {
    name = "nyx-tty-display";
    runtimeInputs = [ util-linux ];
    text = builtins.readFile ./nyx-tty-display;
}
