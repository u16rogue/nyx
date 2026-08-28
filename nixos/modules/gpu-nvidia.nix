{ ... }: {
    flake.modules.nixos.gpu-nvidia = { config, ... }: {
        hardware.graphics.enable = true; # TODO: decide whether this should be defined by the module instead of the host
        hardware.nvidia = {
           modesetting.enable = true;
           open = true;
           package = config.boot.kernelPackages.nvidiaPackages.latest;
        };
        services.xserver.videoDrivers = [ "nvidia" ];
    };
}
