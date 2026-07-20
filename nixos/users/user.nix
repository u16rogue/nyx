{ config, self, ... }: let
    username = "user";
in {
    flake.modules.nixos.users.${username} = { pkgs, ... }: {
        users.users.${username} = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            shell = self.packages.${pkgs.system}.fish;
            packages = [
                config.users.users.user.shell
            ];
        };
    };
}
