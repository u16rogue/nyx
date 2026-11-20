{
    flake.modules.nixos.networkmanager = { lib, ... }: {
        networking.networkmanager.enable = true;
        networking.modemmanager.enable = lib.mkOverride 900 false;
    };
}
