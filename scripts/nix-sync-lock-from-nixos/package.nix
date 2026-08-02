{ writeShellApplication, coreutils, jq, ... }: writeShellApplication {
    name = "nix-sync-lock-from-nixos";
    runtimeInputs = [ coreutils jq ];
    text = builtins.readFile ./nix-sync-lock-from-nixos;
}
