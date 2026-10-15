{ writeShellApplication, bubblewrap, coreutils, glibc, util-linux, nix, which, ... }: writeShellApplication {
    name = "sbx-shell";
    runtimeInputs = [ bubblewrap coreutils glibc util-linux nix which ];
    text = builtins.readFile ./sbx-shell;
}
