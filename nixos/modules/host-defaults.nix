# Use this module instead of the nixosSystem builder @ `nixos/default.nix` when it is host specific optional. Something that will give you the thought "yeah i might have a system that will use a different value"
{ lib, ... }: {
    flake.modules.nixos.host-defaults = {
        nixpkgs.config.allowUnfree = lib.mkDefault true;
        time.timeZone = lib.mkDefault "Asia/Taipei";
        networking.networkmanager.enable = lib.mkDefault true;
        boot.loader.systemd-boot.enable = lib.mkDefault true;
        boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
        users.mutableUsers = lib.mkDefault false;
        networking.firewall.enable = lib.mkDefault true;
        nix.settings.experimental-features = [ "nix-command" "flakes" "pipe-operators" ];
    };
}
