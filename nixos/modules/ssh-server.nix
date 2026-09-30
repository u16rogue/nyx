{
    flake.modules.nixos.ssh-server = { lib, ... }: {
        services.openssh = {
            enable = true;
            hostKeys = [{
                path = "/etc/ssh/ssh_host_ed25519_key";
                type = "ed25519";
            }];
            settings = {
                PermitRootLogin = lib.mkDefault "no";
                PasswordAuthentication = lib.mkDefault false;
                KbdInteractiveAuthentication = lib.mkDefault false;
                X11Forwarding = lib.mkDefault false;
            };
        };
    };
}
