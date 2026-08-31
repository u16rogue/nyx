{
    flake.modules.nixos.gnupg = { pkgs, ... }: {
        services.pcscd.enable = true;
        programs.gnupg.agent = {
             enable = true;
             pinentryPackage = pkgs.pinentry-curses;
             enableSSHSupport = true;
        };
    };
}
