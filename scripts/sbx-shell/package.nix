{ writeShellApplication, bubblewrap, coreutils, glibc, util-linux, ... }: writeShellApplication {
    name = "sbx-shell";
    runtimeInputs = [ bubblewrap coreutils glibc util-linux ];
    text = builtins.readFile ./sbx-shell;
}
