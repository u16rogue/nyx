{
    flake.modules.nixos.pipewire = { pkgs, ... }: {
        services.pipewire = {
            enable = true;
            pulse.enable = true;
        };

        environment.systemPackages = [ pkgs.wiremix ];
    };
}
