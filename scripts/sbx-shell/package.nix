{ writeShellApplication, bubblewrap, coreutils, glibc, util-linux, nix, which, xdg-dbus-proxy, ... }: writeShellApplication {
    name = "sbx-shell";
    runtimeInputs = [ bubblewrap coreutils glibc util-linux nix which xdg-dbus-proxy ];
    text = builtins.readFile ./sbx-shell;
}
