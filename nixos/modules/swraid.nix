{ lib, ... }: {
    flake.modules.nixos.swraid = {
        boot.initrd.kernelModules = [ "dm-raid" ];
        boot.swraid = {
            enable = true;
            mdadmConf = lib.mkDefault "MAILADDR user@example.com";
        };
    };
}
