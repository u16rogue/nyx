{
    flake.modules.nixos.no-sleep = {
        systemd.targets = {
            sleep.enable = false;
            suspend.enable = false;
            hibernate.enable = false;
            hybrid-sleep.enable = false;
        };
    };
}


