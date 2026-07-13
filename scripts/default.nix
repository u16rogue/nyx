{ pkgs, ... }: [
    (import ./mkignore/package.nix { inherit pkgs; })
    (import ./nix-develop/package.nix { inherit pkgs; })
    (import ./nix-gc/package.nix { inherit pkgs; })
    (import ./nix-sync-lock-from-nixos/package.nix { inherit pkgs; })
    (import ./nix-pkgvercmp/package.nix { inherit pkgs; })
    (import ./tmuxss/package.nix { inherit pkgs; })
    (import ./git-cans/package.nix { inherit pkgs; })

    (pkgs.writeShellScriptBin "git-macs" /*bash*/ ''
        ${pkgs.git}/bin/git add . && ${pkgs.git}/bin/git commit -S -m "$1"
    '')
]
