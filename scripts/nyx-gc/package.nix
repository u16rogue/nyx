{ writeShellApplication, callPackage, nix, ... }: writeShellApplication {
    name = "nyx-gc";
    # sudo comes from the host's setuid wrapper
    runtimeInputs = [ nix (callPackage ../sbx-shell/package.nix {}) (callPackage ../nyx-efsp/package.nix {}) ];
    text = builtins.readFile ./nyx-gc;
}
