{ ... }: {
    flake.modules.nixos.pipewire = {
        services.pipewire = {
            enable = true;
            pulse.enable = true;
        };
    };
}
