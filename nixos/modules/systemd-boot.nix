{ lib, ... }: {
    flake.modules.nixos.systemd-boot = {
        boot.loader.systemd-boot.enable = true;
        boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
    };
}
