{
    flake.modules.nixos.lid-switch-ignore = {
        services.logind.settings.Login = {
            HandleLidSwitch = "ignore";
            HandleLidSwitchExternalPower = "ignore";
            HandleLidSwitchDocked = "ignore";
        };
    };
}
