{
    flake.modules.nixos.pipewire = { pkgs, ... }: {
        services.pipewire = {
            enable = true;
            alsa.enable = true;
            pulse.enable = true;
        };
        security.rtkit.enable = true;
        environment.systemPackages = [ pkgs.wiremix ];
    };
}
