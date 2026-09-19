{
    flake.modules.nixos.systemd-boot = { lib, ... }: {
        boot.loader.systemd-boot.enable = true;
        boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
    };
}
