{
    flake.modules.nixos.pipewire = { lib, ... }: {
        services.pipewire = {
            enable = true;
            alsa.enable = true;
            pulse.enable = true;
            wireplumber.enable = lib.mkDefault true;
        };
        security.rtkit.enable = true;
    };
}
