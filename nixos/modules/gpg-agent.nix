{
    flake.modules.nixos.gpg-agent = { lib, pkgs, ... }: {
        programs.gnupg.agent = {
            enable = true;
            pinentryPackage = lib.mkDefault pkgs.pinentry-curses;
            enableSSHSupport = lib.mkDefault true;
        };
    };
}
