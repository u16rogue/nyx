{ pkgs, ... }: pkgs.writeShellApplication {
    name = "nix-gc";
    runtimeInputs = [
        pkgs.nix
        pkgs.sudo
    ];
    text = builtins.readFile ./nix-gc;
}
