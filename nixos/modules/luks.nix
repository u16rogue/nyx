{ ... }: {
    flake.modules.nixos.luks = {
        boot.initrd.kernelModules = [ "cryptd" ];
    };
}
