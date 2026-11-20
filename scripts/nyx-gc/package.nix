{ writeShellApplication, callPackage, nix, ... }: writeShellApplication {
    name = "nyx-gc";
    # sudo comes from the host's setuid wrapper and nyx-efsp, once it exists, from the host's PATH
    runtimeInputs = [ nix (callPackage ../sbx-shell/package.nix {}) ];
    text = builtins.readFile ./nyx-gc;
}
